#
# Simple tests for the components produced by buildrump.sh
# Should make using these tests not depend on ------"-----
#

testcommon='#include <sys/types.h>
#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

static void
die(const char *reason)
{

	fprintf(stderr, "%s\\n", reason);
	exit(1);
}
'
doremote ()
{

	echo Remote communication

	sockname=mysocket
	export RUMP_SERVER="unix://${sockname}"

	echo ${testcommon} > simpleserver.c
	cat >> simpleserver.c << EOF
#include <rump/rump.h>

int
main()
{

	unsetenv("RUMP_VERBOSE");
	if (rump_daemonize_begin() != 0)
		die("daemonize init");
        rump_init();
	if (rump_init_server("${RUMP_SERVER}") != 0)
		die("server init");
	if (rump_daemonize_done(0) != 0)
		die("daemonize fini");
	pause();
	return 0;
}
EOF

	echo ${testcommon} > simpleclient.c
	cat >> simpleclient.c << EOF
#include <sys/types.h>
#include <rump/rumpclient.h>
#include <rump/rump_syscalls.h>

int
main()
{

	rumpclient_init();
	if (rump_sys_getpid() < 2)
		die("something went wrong! (\"what\" left as an exercise)");
	rump_sys_reboot(0, NULL);
	return 0;
}
EOF


	set -x
	cc -g -o simpleserver simpleserver.c -I${DESTDIR}/include	\
	    -Wl,--no-as-needed -Wl,--whole-archive -lrump -lrumpuser	\
	    -Wl,--no-whole-archive ${EXTRA_CFLAGS} -lpthread		\
	    ${EXTRA_RUMPUSER} -L${DESTDIR}/lib -Wl,-R${DESTDIR}/lib

	# XXX: some systems don't have all of the librumpclient pthread
	# dependencies in libc, so always link in libpthread, although
	# it wouldn't be required on systems such as NetBSD
	cc -g -o simpleclient simpleclient.c -I${DESTDIR}/include	\
	    -lrumpclient ${EXTRA_RUMPCLIENT} ${EXTRA_CFLAGS}		\
	    -L${DESTDIR}/lib -Wl,-R${DESTDIR}/lib
	set +x
	echo Running ...
	./simpleserver || die simpleserver failed
	./simpleclient || die simpleclient failed

	echo Done
}

dofs ()
{

	echo VFS test

	echo ${testcommon} > fstest.c
	cat >> fstest.c << EOF
#include <rump/rump.h>
#include <rump/rump_syscalls.h>

int
main()
{
	char buf[8192];
	int fd;

	setenv("RUMP_VERBOSE", "1", 1);
        rump_init();
	if (rump_sys_mkdir("/kern", 0755) == -1)
		die("mkdir /kern");
	if (rump_sys_mount("kernfs", "/kern", 0, NULL, 0) == -1)
		die("mount kernfs");
	if ((fd = rump_sys_open("/kern/version", 0)) == -1)
		die("open /kern/version");
	printf("\nReading version info from /kern:\n", buf);
	if (rump_sys_read(fd, buf, sizeof(buf)) <= 0)
		die("read version");
	printf("\n%s", buf);
	rump_sys_reboot(0, NULL);

	return 0;
}
EOF

	set -x
	cc -g -o fstest fstest.c -I${DESTDIR}/include -Wl,--no-as-needed \
	    -Wl,--whole-archive -lrumpfs_kernfs -lrumpvfs -lrump 	 \
	    -lrumpuser -Wl,--no-whole-archive ${EXTRA_CFLAGS} -lpthread	 \
	    ${EXTRA_RUMPUSER} -L${DESTDIR}/lib -Wl,-R${DESTDIR}/lib
	set +x
	./fstest || die fstest failed

	echo Done
}

alltests ()
{

	IFS=' '
	cd ${OBJDIR}
	doremote
	dofs
}

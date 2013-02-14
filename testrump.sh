#
# Simple tests for the components produced by buildrump.sh
# Should make using these tests not depend on ------"-----
#

testcommon='#include <sys/types.h>
#include <inttypes.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

static void
die(const char *fmt, ...)
{
	va_list va;

	va_start(va, fmt);
	vfprintf(stderr, fmt, va);
	va_end(va);
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

donet ()
{

	echo Networking test

	echo ${testcommon} > nettest.c
	cat >> nettest.c <<EOF
#include <sys/types.h>

#include <netinet/in.h>
#include <arpa/inet.h>

#include <errno.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

#include <rump/rump.h>
#include <rump/rump_syscalls.h>
#include <rump/netconfig.h>

#define CONNPORT 135

#define NOFAIL(a) do {int rv=a; if(rv==-1) die("%s: %d",#a,errno);} while (0)

static void
server(void)
{
	struct sockaddr_in sin;
	int slen = sizeof(sin);
	int s, s2;

	rump_init();

	/* configure interface using the portable interfaces */
	NOFAIL(rump_pub_netconfig_ifcreate("shmif0"));
	NOFAIL(rump_pub_netconfig_ifsetlinkstr("shmif0", "busmem"));
	NOFAIL(rump_pub_netconfig_ipv4_ifaddr("shmif0",
	    "1.0.0.1", "255.255.255.0"));

	/* socket, bind, listen, accept.  standard sockets programming */
	NOFAIL(s = rump_sys_socket(RUMP_PF_INET, RUMP_SOCK_STREAM, 0));
	memset(&sin, 0, sizeof(sin));
	sin.sin_family = RUMP_AF_INET;
	sin.sin_port = htons(CONNPORT);
	sin.sin_addr.s_addr = INADDR_ANY;
	NOFAIL(rump_sys_bind(s, (struct sockaddr *)&sin, slen));
	NOFAIL(rump_sys_listen(s, 37));

#define TESTSTR "You feel like you've been here before --More--\n"
	NOFAIL(s2 = rump_sys_accept(s, (struct sockaddr *)&sin, &slen));
	rump_sys_write(s2, TESTSTR, sizeof(TESTSTR));
}

static void
client(void)
{
	struct sockaddr_in sin;
	char buf[1024];
	ssize_t nn;
	int s;

	/* configure networking using the portable interfaces */
	NOFAIL(rump_pub_netconfig_ifcreate("shmif0"));
	NOFAIL(rump_pub_netconfig_ifcreate("shmif0"));
	NOFAIL(rump_pub_netconfig_ifsetlinkstr("shmif0", "busmem"));
	NOFAIL(rump_pub_netconfig_ipv4_ifaddr("shmif0",
	    "1.0.0.2", "255.255.255.0"));

	/* socket, connect.  standard sockets programming */
	NOFAIL(s = rump_sys_socket(RUMP_PF_INET, RUMP_SOCK_STREAM, 0));
	memset(&sin, 0, sizeof(sin));
	sin.sin_family = RUMP_AF_INET;
	sin.sin_port = htons(CONNPORT);
	sin.sin_addr.s_addr = inet_addr("1.0.0.1");
	NOFAIL(rump_sys_connect(s, (struct sockaddr *)&sin, sizeof(sin)));

	if ((nn = rump_sys_read(s, buf, sizeof(buf))) <= 0)
		die("reading socket failed");

	if (strcmp(buf, TESTSTR) != 0)
		die("didn't receive what was expected");
}

int
main(int argc, char *argv[])
{

	/*
	 * Bootstrap rump kernel.  it's so cheap that we might as well
	 * do it here before checking the args.
	 */
	rump_init();

	if (argc != 2)
		die("need role");
	if (strcmp(argv[1], "server") == 0)
		server();
	else if (strcmp(argv[1], "client") == 0)
		client();
	else
		die("invalid role");
	return 0;
}
EOF

	set -x
	cc -g -o nettest nettest.c -I${DESTDIR}/include -Wl,--no-as-needed \
	    -Wl,--whole-archive -lrumpnet_shmif -lrumpnet_config	\
	    -lrumpnet_netinet -lrumpnet_net -lrumpnet -lrump 	 	\
	    -lrumpuser -Wl,--no-whole-archive ${EXTRA_CFLAGS} -lpthread	 \
	    ${EXTRA_RUMPUSER} -L${DESTDIR}/lib -Wl,-R${DESTDIR}/lib
	set +x
	./nettest server &
	./nettest client || die nettest client failed
}

alltests ()
{

	IFS=' '
	cd ${OBJDIR}
	doremote
	donet
	dofs
}

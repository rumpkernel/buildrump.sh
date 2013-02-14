#
# Simple tests for the components produced by buildrump.sh
# Should make using these tests not depend on ------"-----
#

TESTDIR=${BRDIR}/tests
TESTOBJ=${OBJDIR}/brtests

doremote ()
{

	echo Remote communication

	sockname=${TESTOBJ}/mysocket
	export RUMP_SERVER="unix://${sockname}"

	set -x
	cc -g -o ${TESTOBJ}/simpleserver ${TESTDIR}/simpleserver.c	\
	    -I${DESTDIR}/include					\
	    -Wl,--no-as-needed -Wl,--whole-archive -lrump -lrumpuser	\
	    -Wl,--no-whole-archive ${EXTRA_CFLAGS} -lpthread		\
	    ${EXTRA_RUMPUSER} -L${DESTDIR}/lib -Wl,-R${DESTDIR}/lib

	# XXX: some systems don't have all of the librumpclient pthread
	# dependencies in libc, so always link in libpthread, although
	# it wouldn't be required on systems such as NetBSD
	cc -g -o ${TESTOBJ}/simpleclient ${TESTDIR}/simpleclient.c	\
	    -I${DESTDIR}/include					\
	    -lrumpclient ${EXTRA_RUMPCLIENT} ${EXTRA_CFLAGS}		\
	    -L${DESTDIR}/lib -Wl,-R${DESTDIR}/lib
	set +x
	echo Running ...
	${TESTOBJ}/simpleserver "${RUMP_SERVER}" || die simpleserver failed
	${TESTOBJ}/simpleclient || die simpleclient failed

	echo Done
}

dofs ()
{

	echo VFS test

	set -x
	cc -g -o ${TESTOBJ}/fstest ${TESTDIR}/fstest.c			\
	    -I${DESTDIR}/include -Wl,--no-as-needed 			\
	    -Wl,--whole-archive -lrumpfs_kernfs -lrumpvfs -lrump 	\
	    -lrumpuser -Wl,--no-whole-archive ${EXTRA_CFLAGS} -lpthread	\
	    ${EXTRA_RUMPUSER} -L${DESTDIR}/lib -Wl,-R${DESTDIR}/lib
	set +x
	${TESTOBJ}/fstest || die fstest failed

	echo Done
}

donet ()
{

	echo Networking test

	set -x
	cc -g -o ${TESTOBJ}/nettest ${TESTDIR}/nettest.c		\
	    -I${DESTDIR}/include -Wl,--no-as-needed 			\
	    -Wl,--whole-archive -lrumpnet_shmif -lrumpnet_config	\
	    -lrumpnet_netinet -lrumpnet_net -lrumpnet -lrump 	 	\
	    -lrumpuser -Wl,--no-whole-archive ${EXTRA_CFLAGS} -lpthread	\
	    ${EXTRA_RUMPUSER} -L${DESTDIR}/lib -Wl,-R${DESTDIR}/lib
	set +x
	${TESTOBJ}/nettest server &
	${TESTOBJ}/nettest client || die nettest client failed
}

alltests ()
{

	mkdir -p ${TESTOBJ}
	doremote
	donet
	dofs
}

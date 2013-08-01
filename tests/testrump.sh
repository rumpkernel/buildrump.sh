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
	${CC} -g -o ${TESTOBJ}/simpleserver ${TESTDIR}/simpleserver.c	\
	    -I${DESTDIR}/include					\
	    ${AS_NEEDED} -Wl,--whole-archive -lrump -lrumpuser		\
	    -Wl,--no-whole-archive ${EXTRA_CFLAGS} -lpthread		\
	    ${EXTRA_RUMPUSER} -L${DESTDIR}/lib -Wl,-R${DESTDIR}/lib

	# XXX: some systems don't have all of the librumpclient pthread
	# dependencies in libc, so always link in libpthread, although
	# it wouldn't be required on systems such as NetBSD
	${CC} -g -o ${TESTOBJ}/simpleclient ${TESTDIR}/simpleclient.c	\
	    -I${DESTDIR}/include					\
	    -lrumpclient ${EXTRA_RUMPCLIENT} ${EXTRA_CFLAGS}		\
	    -L${DESTDIR}/lib -Wl,-R${DESTDIR}/lib
	set +x

	./simpleserver "${RUMP_SERVER}" || die simpleserver failed
	./simpleclient || die simpleclient failed

	echo Done
}

dokernfs ()
{

	echo VFS test

	set -x
	${CC} -g -o ${TESTOBJ}/fstest ${TESTDIR}/fstest.c		\
	    -I${DESTDIR}/include ${AS_NEEDED} 				\
	    -Wl,--whole-archive -lrumpfs_kernfs -lrumpvfs -lrump 	\
	    -lrumpuser -Wl,--no-whole-archive ${EXTRA_CFLAGS} -lpthread	\
	    ${EXTRA_RUMPUSER} -L${DESTDIR}/lib -Wl,-R${DESTDIR}/lib
	set +x

	./fstest || die fstest failed

	echo Done
}

dosysvbfs ()
{

	echo VFS test with actual fs

	set -x
	${CC} -g -o ${TESTOBJ}/fstest2 ${TESTDIR}/fstest2.c		\
	    -I${DESTDIR}/include ${AS_NEEDED} 				\
	    -Wl,--whole-archive -lrumpfs_sysvbfs -lrumpdev_disk		\
	    -lrumpdev -lrumpvfs -lrump -lrumpuser			\
	    -Wl,--no-whole-archive ${EXTRA_CFLAGS} -lpthread	\
	    ${EXTRA_RUMPUSER} -L${DESTDIR}/lib -Wl,-R${DESTDIR}/lib
	set +x

	./fstest2 ${TESTDIR}/sysvbfs_le.img || die fstest2 failed

	echo Done
}

donet ()
{

	echo Networking test

	set -x
	${CC} -g -o ${TESTOBJ}/nettest_simple ${TESTDIR}/nettest_simple.c\
	    -I${DESTDIR}/include ${AS_NEEDED} 				\
	    -Wl,--whole-archive -lrumpnet_shmif -lrumpnet_config	\
	    -lrumpnet_netinet -lrumpnet_net -lrumpnet -lrump 	 	\
	    -lrumpuser -Wl,--no-whole-archive ${EXTRA_CFLAGS} -lpthread	\
	    ${EXTRA_RUMPUSER} -L${DESTDIR}/lib -Wl,-R${DESTDIR}/lib
	set +x

	rm -f busmem
	./nettest_simple server || die nettest server failed
	./nettest_simple client || die nettest client failed

	echo Done
}

donetrouted ()
{

	echo Routed networking test

	set -x
	${CC} -g -o ${TESTOBJ}/nettest_routed ${TESTDIR}/nettest_routed.c\
	    -I${DESTDIR}/include ${AS_NEEDED} 				\
	    -Wl,--whole-archive -lrumpnet_shmif -lrumpnet_config	\
	    -lrumpnet_netinet -lrumpnet_net -lrumpnet -lrump 	 	\
	    -lrumpuser -Wl,--no-whole-archive ${EXTRA_CFLAGS} -lpthread	\
	    ${EXTRA_RUMPUSER} -L${DESTDIR}/lib -Wl,-R${DESTDIR}/lib
	set +x

	rm -f net1 net2
	./nettest_routed server || die nettest server failed
	./nettest_routed router unix://${TESTOBJ}/routerctrl || die router fail
	./nettest_routed client || die nettest client failed

	# "code reuse ;)"
	export RUMP_SERVER="unix://${TESTOBJ}/routerctrl"
	./simpleclient || die failed to reboot router

	echo Done
}

alltests ()
{

	echo Running simple tests

	if ! ${NATIVEBUILD}; then
		echo '>>
		echo '>> WARNING!  Running tests on non-native build!'
		echo '>> This may not work correctly!'
		echo '>>'
	fi

	[ -z "${LD_FLAVOR}" ] && probeld
	[ ${LD_FLAVOR} = 'sun' ] || AS_NEEDED='-Wl,--no-as-needed'

	mkdir -p ${TESTOBJ}
	cd ${TESTOBJ}
	dokernfs
	dosysvbfs
	doremote
	donet
	donetrouted

	echo
	echo Success
}

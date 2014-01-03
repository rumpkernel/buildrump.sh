#
# Simple tests for the components produced by buildrump.sh
# Should make using these tests not depend on ------"-----
#

TESTDIR=${BRDIR}/tests
TESTOBJ=${OBJDIR}/brtests

dosimpleclient ()
{

	echo Remote communication
	export RUMP_SERVER="unix://mysocket"
	${DESTDIR}/bin/rump_server "${RUMP_SERVER}" || die rump_server failed
	./simpleclient || die simpleclient failed
	unset RUMP_SERVER
	echo Done
}

doinit ()
{

	echo bootstrap test
	${TO}/init || die init failed
	echo Done
}

dofstest ()
{

	echo VFS test
	${TO}/fstest || die fstest failed
	echo Done
}

dofstest_img ()
{

	echo VFS test with actual fs
	./fstest2 ${TESTDIR}/fstest_img || die fstest2 failed
	echo Done
}

donettest_simple ()
{

	echo Networking test
	rm -f busmem
	./nettest_simple server || die nettest server failed
	./nettest_simple client || die nettest client failed
}

donettest_simple6 ()
{

	echo IPv6 networking test
	rm -f busmem
	./nettest_simple6 server6 || die nettest server6 failed
	./nettest_simple6 client6 || die nettest client6 failed
	echo Done
}

donettest_routed ()
{

	echo Routed networking test

	rm -f net1 net2
	./nettest_routed server || die nettest server failed
	./nettest_routed router unix://routerctrl || die router fail
	./nettest_routed client || die nettest client failed

	# "code reuse ;)"
	export RUMP_SERVER="unix://routerctrl"
	${TESTOBJ}/simpleclient/simpleclient || die failed to reboot router

	echo Done
}

ALLTESTS="init fstest fstest_img simpleclient
	nettest_simple nettest_simple6 nettest_routed"

alltests ()
{

	echo Running simple tests

	if ! ${NATIVEBUILD}; then
		echo '>>'
		echo '>> WARNING!  Running tests on non-native build!'
		echo '>> This may not work correctly!'
		echo '>>'
	fi

	mkdir -p ${TESTOBJ} || die cannot create object directory

	failed=0
	extradep=${TESTOBJ}/.testrumpdepend
	touch ${extradep}
	for test in ${ALLTESTS}; do
		TO=${TESTOBJ}/${test}
		(
			cd ${TESTDIR}/${test}
			${RUMPMAKE} MAKEOBJDIR=${TO} obj || exit 1
			${RUMPMAKE} MAKEOBJDIR=${TO} DPSRCS=${extradep} \
			     dependall || exit 1
		) && ( cd ${TO} ; do${test} )
		failed=$(( ${failed} + $? ))
	done
	[ ${failed} -ne 0 ] && die "FAILED ${failed} tests!"

	echo
	echo Success
}

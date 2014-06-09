#
# Simple tests for the components produced by buildrump.sh
# Should make using these tests not depend on ------"-----
#

TESTDIR=${BRDIR}/tests
TESTOBJ=${OBJDIR}/brtests

dosimpleclient ()
{

	printf 'Remote communication ... '
	export RUMP_SERVER="unix://mysocket"
	${DESTDIR}/bin/rump_server "${RUMP_SERVER}" || die rump_server failed
	./simpleclient || die simpleclient failed
	unset RUMP_SERVER
	echo done
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

	printf 'VFS test with actual file system ... '
	./fstest2 ${TESTDIR}/fstest_img || die fstest2 failed
	echo done
}

donettest_simple ()
{

	printf 'IPv4 networking test ... '
	rm -f busmem
	./nettest_simple server || die nettest server failed
	./nettest_simple client || die nettest client failed
	echo done
}

donettest_simple6 ()
{

	printf 'IPv6 networking test ... '
	rm -f busmem
	./nettest_simple6 server6 || die nettest server6 failed
	./nettest_simple6 client6 || die nettest client6 failed
	echo done
}

donettest_routed ()
{

	printf 'Routed IPv4 networking test ... '

	rm -f busmem1 busmem2
	./nettest_routed server || die nettest server failed
	./nettest_routed router unix://routerctrl || die router fail
	./nettest_routed client || die nettest client failed

	# "code reuse ;)"
	export RUMP_SERVER="unix://routerctrl"
	${TESTOBJ}/simpleclient/simpleclient || die failed to reboot router
	echo done
}

donettest_routed6 ()
{

	printf 'Routed IPv6 networking test ... '

	rm -f busmem1 busmem2
	./nettest_routed6 server6 || die nettest server failed
	./nettest_routed6 router6 unix://routerctrl || die router fail
	./nettest_routed6 client6 || die nettest client failed

	# "code reuse ;)"
	export RUMP_SERVER="unix://routerctrl"
	${TESTOBJ}/simpleclient/simpleclient || die failed to reboot router
	echo done
}

dodynamic ()
{

	printf 'Dynamic loading of components ... '
	./dynamic
	rv=$?
	if [ ${rv} -eq 37 ]; then
		printf 'component load failed, skipping test\n'
	elif [ ${rv} -ne 0 ]; then
		die dynamic test failed
	else
		echo done
	fi
}

ALLTESTS="init fstest fstest_img simpleclient
	nettest_simple nettest_simple6 nettest_routed nettest_routed6
	dynamic"

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

	pkill -TERM -P $$

	[ ${failed} -ne 0 ] && die "FAILED ${failed} tests!"

	echo
	echo Success
}

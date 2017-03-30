RUMPKERN_CPPFLAGS="-D__linux__ -DCONFIG_LKL"

checkcheckout ()
{

	[ -f "${LKL_SRCDIR}/arch/lkl/Makefile" ] || \
	    die "Cannot find ${LKL_SRCDIR}/arch/lkl/Makefile!"

	[ ! -z "${TARBALLMODE}" ] && return

	if ! ${BRDIR}/checkout.sh checkcheckout ${LKL_SRCDIR} \
	    && ! ${TITANMODE}; then
		die 'revision mismatch, run checkout (or -H to override)'
	fi
}

makebuild ()
{
	set -e
	echo "=== Linux build LKLSRC=${LKL_SRCDIR} ==="
	cd ${LKL_SRCDIR}
	LKL_VERBOSE="V=0"
	if [ ${NOISE} -gt 1 ] ; then
		LKL_VERBOSE="V=1"
	fi

	LKL_CROSS=$(${CC} -dumpmachine)
	if [ ${LKL_CROSS} = "$(gcc -dumpmachine)" ]
	then
		LKL_CROSS=
	else
		LKL_CROSS=${LKL_CROSS}-
	fi

	LKL_EXT_OPT=${LKL_EXT_OPT:-}

	export LKL_VERBOSE
	export LKL_CROSS
	export LKL_EXT_OPT

	# need proper RUMP_PREFIX and RUMP_INCLUDE configuration from caller
	if [ -z "${RUMP_PREFIX:-}" ]; then
		echo "No RUMP_PREFIX env configured. Use the default one."
		export RUMP_PREFIX=${SRCDIR}/sys/rump
	fi

	mkdir -p ${OBJDIR}/linux

	cd tools/lkl
	rm -f ${OBJDIR}/linux/tools/lkl/lib/lkl.o
	make CROSS_COMPILE=${LKL_CROSS} ${LKL_EXT_OPT} -j ${JNUM} ${LKL_VERBOSE} O=${OBJDIR}/linux

	cd ../../
	make CROSS_COMPILE=${LKL_CROSS} ${LKL_EXT_OPT} headers_install ARCH=lkl O=${DESTDIR}/ \
	     PREFIX=/ INSTALL_HDR_PATH=${DESTDIR}/ ${LKL_VERBOSE}

	set +e
}

makeinstall ()
{
	set -e
	# XXX for app-tools
	mkdir -p ${DESTDIR}/bin/
	mkdir -p ${DESTDIR}/include/rumprun

	# need proper RUMP_PREFIX and RUMP_INCLUDE configuration from caller
	make CROSS_COMPILE=${LKL_CROSS} ${LKL_EXT_OPT} headers_install libraries_install DESTDIR=${DESTDIR}\
	     -C ./tools/lkl/ O=${OBJDIR}/linux  PREFIX=/ ${LKL_VERBOSE}
	# XXX: for netconfig.h
	mkdir -p ${DESTDIR}/include/rump/
	cp -pf ${BRDIR}/brlib/libnetconfig/rump/netconfig.h ${DESTDIR}/include/rump/

	set +e
}

#
# install kernel headers.
# Note: Do _NOT_ do this unless you want to install a
#       full rump kernel application stack
#
makekernelheaders ()
{
	return
}

maketests ()
{
	printf 'SKIP: Linux test currently not implemented yet ... \n'
	return
	printf 'Linux test ... \n'
	make -C ${LKL_SRCDIR}/tools/lkl test O=${OBJDIR}/linux || die LKL test failed
}

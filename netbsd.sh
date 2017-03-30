RUMPKERN_CPPFLAGS="-D__NetBSD__"

checkcheckout ()
{

	[ -x "${SRCDIR}/build.sh" ] || die "Cannot find ${SRCDIR}/build.sh!"

	[ ! -z "${TARBALLMODE}" ] && return

	if ! ${BRDIR}/checkout.sh checkcheckout ${SRCDIR} \
	    && ! ${TITANMODE}; then
		die 'revision mismatch, run checkout (or -H to override)'
	fi
}

# create the makefiles used for building
mkmakefile ()
{

	makefile=$1
	shift
	exec 3>&1 1>${makefile}
	printf '# GENERATED FILE, MIGHT I SUGGEST NOT EDITING?\n'
	printf 'SUBDIR='
	for dir in $*; do
		case ${dir} in
		/*)
			printf ' %s' ${dir}
			;;
		*)
			printf ' %s' ${SRCDIR}/${dir}
			;;
		esac
	done

	printf '\n.include <bsd.subdir.mk>\n'
	exec 1>&3 3>&-
}

domake ()
{

	mkfile=${1}; shift
	mktarget=${1}; shift

	[ ! -x ${RUMPMAKE} ] && die "No rumpmake (${RUMPMAKE}). Forgot tools?"
	${RUMPMAKE} $* -j ${JNUM} -f ${mkfile} ${mktarget}
	[ $? -eq 0 ] || die "make $mkfile $mktarget"
}

makebuild ()
{

	checkcheckout

	# ensure we're in SRCDIR, in case "tools" wasn't run
	cd ${SRCDIR}

	targets="obj includes dependall install"

	#
	# Building takes 4 passes, just like when
	# building NetBSD the regular way.  The passes are:
	# 1) obj
	# 2) includes
	# 3) dependall
	# 4) install
	#

	DIRS_first='lib/librumpuser'
	DIRS_second='lib/librump'
	DIRS_third="lib/librumpdev lib/librumpnet lib/librumpvfs
	    sys/rump/dev sys/rump/fs sys/rump/kern sys/rump/net
	    sys/rump/include ${BRDIR}/brlib"

	# sys/rump/share was added to ${SRCDIR} 11/2014
	[ -d ${SRCDIR}/sys/rump/share ] \
	    && appendvar DIRS_second ${SRCDIR}/sys/rump/share

	if [ ${MACHINE} = "i386" -o ${MACHINE} = "amd64" \
	     -o ${MACHINE#evbearm} != ${MACHINE} \
	     -o ${MACHINE#evbppc} != ${MACHINE} ]; then
		DIRS_emul=sys/rump/kern/lib/libsys_linux
	fi
	${SYS_SUNOS} && appendvar DIRS_emul sys/rump/kern/lib/libsys_sunos
	if ${HIJACK}; then
		DIRS_final="lib/librumphijack"
	else
		DIRS_final=
	fi

	DIRS_third="${DIRS_third} ${DIRS_emul}"

	if ${KERNONLY}; then
		mkmakefile ${OBJDIR}/Makefile.all \
		    sys/rump ${DIRS_emul} ${BRDIR}/brlib
	else
		DIRS_third="lib/librumpclient ${DIRS_third}"

		mkmakefile ${OBJDIR}/Makefile.first ${DIRS_first}
		mkmakefile ${OBJDIR}/Makefile.second ${DIRS_second}
		mkmakefile ${OBJDIR}/Makefile.third ${DIRS_third}
		mkmakefile ${OBJDIR}/Makefile.final ${DIRS_final}
		mkmakefile ${OBJDIR}/Makefile.all \
		    ${DIRS_first} ${DIRS_second} ${DIRS_third} ${DIRS_final}
	fi

	# try to minimize the amount of domake invocations.  this makes a
	# difference especially on systems with a large number of slow cores
	for target in ${targets}; do
		if [ ${target} = "dependall" ] && ! ${KERNONLY}; then
			domake ${OBJDIR}/Makefile.first ${target}
			domake ${OBJDIR}/Makefile.second ${target}
			domake ${OBJDIR}/Makefile.third ${target}
			domake ${OBJDIR}/Makefile.final ${target}
		else
			domake ${OBJDIR}/Makefile.all ${target}
		fi
	done

	if ! ${KERNONLY}; then
		mkmakefile ${OBJDIR}/Makefile.utils \
		    usr.bin/rump_server usr.bin/rump_allserver \
		    usr.bin/rump_wmd
		for target in ${targets}; do
			domake ${OBJDIR}/Makefile.utils ${target}
		done
	fi
}

makeinstall ()
{

	# ensure we run this in a directory that does not have a
	# Makefile that could confuse rumpmake
	stage=$(cd ${BRTOOLDIR} && ${RUMPMAKE} -V '${BUILDRUMP_STAGE}')
	(cd ${stage}/usr ; tar -cf - .) | (cd ${DESTDIR} ; tar -xf -)

}

#
# install kernel headers.
# Note: Do _NOT_ do this unless you want to install a
#       full rump kernel application stack
#
makekernelheaders ()
{

	dodirs=$(cd ${SRCDIR}/sys && \
	    ${RUMPMAKE} -V '${SUBDIR:Narch:Nmodules:Ncompat:Nnetnatm}' includes)
	# missing some architectures
	appendvar dodirs arch/amd64/include arch/i386/include arch/x86/include
	appendvar dodirs arch/arm/include arch/arm/include/arm32
	appendvar dodirs arch/evbarm64/include arch/aarch64/include
	appendvar dodirs arch/evbppc/include arch/powerpc/include
	appendvar dodirs arch/evbmips/include arch/mips/include
	appendvar dodirs arch/riscv/include
	for dir in ${dodirs}; do
		(cd ${SRCDIR}/sys/${dir} && ${RUMPMAKE} obj)
		(cd ${SRCDIR}/sys/${dir} && ${RUMPMAKE} includes)
	done
	# create machine symlink
	(cd ${SRCDIR}/sys/arch && ${RUMPMAKE} NOSUBDIR=1 includes)
}

maketests ()
{

	if ${KERNONLY}; then
		diagout 'Kernel-only; skipping tests (no hypervisor)'
	else
		. ${BRDIR}/tests/testrump.sh
		alltests
	fi
}

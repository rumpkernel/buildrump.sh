#! /usr/bin/env sh
#
# Copyright (c) 2013 Antti Kantee <pooka@iki.fi>
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS
# OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.
#

#
# This script will build rump kernel components and the hypervisor
# for a non-NetBSD target.  It will install the components as libraries
# to rump/lib and headers to rump/include.  For information on how to
# convert the installed files into running rump kernels, see the examples
# and tests directories.
#

# defaults
OBJDIR=./obj
DESTDIR=./rump
SRCDIR=./src
JNUM=4

#
# NetBSD source timestamp minimum requirement
NBSRC_DATE=20130515
NBSRC_SUB=1

#
# support routines
#

# the parrot routine
die ()
{

	echo '>> ERROR:' >&2
	echo ">> $*" >&2
	exit 1
}

helpme ()
{

	exec 1>&2
	echo "Usage: $0 [-h] [options] [command] [command...]"
	printf "supported options:\n"
	printf "\t-d: location for headers/libs.  default: PWD/rump\n"
	printf "\t-o: location for build-time files.  default: PWD/obj\n"
	printf "\t-T: location for tools+rumpmake.  default: PWD/obj/tooldir\n"
	printf "\t-s: location of source tree.  default: PWD/src\n"
	printf "\n"
	printf "\t-j: value of -j specified to make.  default: ${JNUM}\n"
	printf "\t-q: quiet build, less compiler output.  default: noisy\n"
	printf "\t-r: release build (no -g, DIAGNOSTIC, etc.).  default: no\n"
	printf "\t-V: specify -V arguments to NetBSD build (expert-only)\n"
	printf "\t-D: increase debugginess.  default: -O2 -g\n"
	printf "\t-32: build 32bit binaries (if supported).  default: from cc\n"
	printf "\t-64: build 64bit binaries (if supported).  default: from cc\n"
	echo
	printf "supported commands (none supplied => checkout+fullbuild):\n"
	printf "\tcheckoutgit:\tfetch NetBSD sources to srcdir from github\n"
	printf "\tcheckoutcvs:\tfetch NetBSD sources to srcdir from anoncvs\n"
	printf "\tcheckout:\talias for checkoutgit\n"
	printf "\ttools:\t\tbuild necessary tools to tooldir\n"
	printf "\tbuild:\t\tbuild rump kernel components\n"
	printf "\tinstall:\tinstall rump kernel components into destdir\n"
	printf "\ttests:\t\trun tests to verify installation is functional\n"
	printf "\tfullbuild:\talias for \"tools build install tests\"\n"
	printf "\tsetupdest:\tcreate destdirs (implicit for \"install\")\n"
	exit 1
}

#
# toolchain creation helper routines
#

appendmkconf ()
{
	[ ! -z "${1}" ] && echo "${2}${3}=${1}" >> "${BRTOOLDIR}/mk.conf"
}

#
# Not all platforms have  the same set of crt files.  for some
# reason unbeknownst to me, if the file does not exist,
# at least gcc --print-file-name just echoes the input parameter.
# Try to detect this and tell the NetBSD makefiles that the crtfile
# in question should be left empty.
chkcrt ()
{
	tst=`${CC} --print-file-name=${1}.o`
	up=`echo ${1} | tr [a-z] [A-Z]`
	[ -z "${tst%${1}.o}" ] && echo "_GCC_CRT${up}=" >>"${BRTOOLDIR}/mk.conf"
}

#
# Create tools and wrappers.  This step needs to be run at least once
# and is always run by default, but you might want to skip it for:
# 1) iteration speed on a slow-ish host
# 2) making manual modification to the tools for testing and avoiding
#    the script nuke them on the next iteration
#
# external toolchain links are created in the format that
# build.sh expects.
#
probeld ()
{

	if ${CC} -Wl,--version 2>&1 | grep -q 'GNU ld' ; then
		LD_FLAVOR=GNU
	elif ${CC} -Wl,--version 2>&1 | grep -q 'Solaris Link Editor' ; then
		LD_FLAVOR=sun
	else
		die 'GNU or Solaris ld required'
	fi
}

maketools ()
{

	#
	# Perform various checks and set values
	#

	# Check for variant of compiler.
	# XXX: why can't all cc's that are gcc actually tell me
	#      that they're gcc with cc --version?!?
	ccver=$(${CC} --version)
	if echo ${ccver} | grep -q 'Free Software Foundation'; then
		CC_FLAVOR=gcc
	elif echo ${ccver} | grep -q clang; then
		CC_FLAVOR=clang
		LLVM='-V HAVE_LLVM=1'
	else
		die Unsupported \${CC} "(`type ${CC}`)"
	fi

	#
	# Check for ld because we need to make some adjustments based on it
	probeld

	# Check for GNU ar
	if ! ${AR} --version 2>/dev/null | grep -q 'GNU ar' ; then
		die Need GNU ar "(`type ${AR}`)"
	fi

	cd ${OBJDIR}
	#
	# Try to test if cc supports -Wno-unused-but-set-variable.
	# This is a bit tricky since apparently gcc doesn't tell it
	# doesn't support it unless there is some other error to complain
	# about as well.  So we try compiling a broken source file...
	echo 'no you_shall_not_compile' > broken.c
	${CC} -Wno-unused-but-set-variable broken.c > broken.out 2>&1
	if ! grep -q Wno-unused-but-set-variable broken.out ; then
		W_UNUSED_BUT_SET=-Wno-unused-but-set-variable
	fi
	rm -f broken.c broken.out

	#
	# Check if the linker supports all the features of the rump kernel
	# component ldscript used for linking shared libraries.
	# If not, build only static rump kernel components.
	if [ ${LD_FLAVOR} = 'GNU' ]; then
		echo 'SECTIONS { } INSERT AFTER .data' > ldscript.test
		echo 'int main(void) {return 0;}' > test.c
		if ! $CC test.c -Wl,-T ldscript.test > /dev/null 2>&1 ; then
			# We know that older versions of NetBSD
			# work without an ldscript
			if [ "${TARGET}" = netbsd ]; then
				LDSCRIPT='-V RUMP_LDSCRIPT=no'
			else
				BUILDSHARED='-V NOPIC=1'
			fi
		fi
		rm -f test.c a.out ldscript.test
	fi

	#
	# Check if the target supports posix_memalign()
	printf '#include <stdlib.h>\nmain(){posix_memalign(NULL,0,0);}\n'>test.c
	${CC} test.c >/dev/null 2>&1 && POSIX_MEMALIGN='-DHAVE_POSIX_MEMALIGN'
	rm -f test.c a.out

	#
	# Create external toolchain wrappers.
	mkdir -p ${BRTOOLDIR}/bin || die "cannot create ${BRTOOLDIR}/bin"
	for x in CC AR NM OBJCOPY; do
		# ok, it's not really --netbsd, but let's make-believe!
		if [ ${x} = CC ]; then
			lcx=${CC_FLAVOR}
		else
			lcx=$(echo ${x} | tr '[A-Z]' '[a-z]')
		fi
		tname=${BRTOOLDIR}/bin/${MACH_ARCH}--netbsd${TOOLABI}-${lcx}

		eval tool=\${${x}}
		type ${tool} >/dev/null 2>&1 \
		    || die Cannot find \$${x} at \"${tool}\".
		printf 'Tool %s \t: %s\n' ${x} ${tool}

		exec 3>&1 1>${tname}
		printf '#!/bin/sh\n\n'

		# Make the compiler wrapper mangle arguments suitable for ld.
		# Messy to plug it in here, but ...
		if [ ${x} = 'CC' -a ${LD_FLAVOR} = 'sun' ]; then
			printf 'for x in $*; do\n'
        		printf '\t[ "$x" = "-Wl,-x" ] && continue\n'
	        	printf '\t[ "$x" = "-Wl,--warn-shared-textrel" ] '
			printf '&& continue\n\tnewargs="${newargs} $x"\n'
			printf 'done\nexec %s ${newargs}\n' ${tool}
		else
			printf 'exec %s $*\n' ${tool}
		fi
		exec 1>&3 3>&-
		chmod 755 ${tname}
	done

	cat > "${BRTOOLDIR}/mk.conf" << EOF
NOGCCERROR=1
BUILDRUMP_CPPFLAGS=-I${DESTDIR}/include
CPPFLAGS+=\${BUILDRUMP_CPPFLAGS}
CPPFLAGS+=${POSIX_MEMALIGN}
LIBDO.pthread=_external
RUMPKERN_UNDEF=${RUMPKERN_UNDEF}
INSTPRIV=-U
CFLAGS+=\${BUILDRUMP_CFLAGS}
AFLAGS+=\${BUILDRUMP_AFLAGS}
EOF

	appendmkconf "${W_UNUSED_BUT_SET}" "CFLAGS" +
	appendmkconf "${EXTRA_LDFLAGS}" "LDFLAGS" +
	appendmkconf "${EXTRA_CFLAGS}" "BUILDRUMP_CFLAGS"
	appendmkconf "${EXTRA_AFLAGS}" "BUILDRUMP_AFLAGS"
	appendmkconf "${RUMP_DIAGNOSTIC}" "RUMP_DIAGNOSTIC"
	appendmkconf "${RUMP_DEBUG}" "RUMP_DEBUG"
	appendmkconf "${RUMP_LOCKDEBUG}" "RUMP_LOCKDEBUG"
	appendmkconf "${DBG}" "DBG"
	for x in ${EXTRA_RUMPUSER}; do
		appendmkconf "${x#-l}" "RUMPUSER_EXTERNAL_DPLIBS" +
	done
	for x in ${EXTRA_RUMPCLIENT}; do
		appendmkconf "${x#-l}" "RUMPCLIENT_EXTERNAL_DPLIBS" +
	done
	[ ${LD_FLAVOR} = 'sun' ] && appendmkconf 'yes' 'HAVE_SUN_LD'

	chkcrt begins
	chkcrt ends
	chkcrt i
	chkcrt n

	# skip the zlib tests run by "make tools", since we don't need zlib
	# and it's only required by one tools autoconf script.  Of course,
	# the fun bit is that autoconf wants to use -lz internally,
	# so we provide some foo which macquerades as libz.a.
	export ac_cv_header_zlib_h=yes
	echo 'int gzdopen(int); int gzdopen(int v) { return 0; }' > fakezlib.c
	${HOST_CC:-cc} -o libz.a -c fakezlib.c

	# Run build.sh.  Use some defaults.
	# The html pages would be nice, but result in too many broken
	# links, since they assume the whole NetBSD man page set to be present.
	cd ${SRCDIR}
	env CFLAGS= HOST_LDFLAGS=-L${OBJDIR} ./build.sh -m ${MACHINE} -u \
	    -D ${OBJDIR}/dest -w ${RUMPMAKE} \
	    -T ${BRTOOLDIR} -j ${JNUM} \
	    ${LLVM} ${BEQUIET} ${BUILDSHARED} ${BUILDSTATIC} ${SOFTFLOAT} \
	    ${LDSCRIPT} \
	    -V EXTERNAL_TOOLCHAIN=${BRTOOLDIR} -V TOOLCHAIN_MISSING=yes \
	    -V TOOLS_BUILDRUMP=yes \
	    -V MKGROFF=no \
	    -V MKARZERO=no \
	    -V NOPROFILE=1 \
	    -V NOLINT=1 \
	    -V USE_SSP=no \
	    -V MKHTML=no -V MKCATPAGES=yes \
	    -V SHLIBINSTALLDIR=/usr/lib \
	    -V TOPRUMP="${SRCDIR}/sys/rump" \
	    -V MAKECONF="${BRTOOLDIR}/mk.conf" \
	    -V MAKEOBJDIR="\${.CURDIR:C,^(${SRCDIR}|${BRDIR}),${OBJDIR},}" \
	    ${BUILDSH_VARGS} \
	  tools
	[ $? -ne 0 ] && die build.sh tools failed
	unset ac_cv_header_zlib_h
}

makebuild ()
{

	targets=$*

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
	DIRS_third="lib/librumpclient lib/librumpdev lib/librumpnet
	    lib/librumpvfs sys/rump/dev sys/rump/fs sys/rump/kern sys/rump/net
	    sys/rump/include ${BRDIR}/brlib"

	if [ ${TARGET} = "linux" ]; then
		DIRS_final="lib/librumphijack"
		DIRS_third="${DIRS_third} sys/rump/kern/lib/libsys_linux"
	fi

	if [ ${TARGET} = "sunos" ]; then
		DIRS_third="${DIRS_third} sys/rump/kern/lib/libsys_sunos"
	fi

	mkmakefile ${OBJDIR}/Makefile.first ${DIRS_first}
	mkmakefile ${OBJDIR}/Makefile.second ${DIRS_second}
	mkmakefile ${OBJDIR}/Makefile.third ${DIRS_third}
	mkmakefile ${OBJDIR}/Makefile.final ${DIRS_final}
	mkmakefile ${OBJDIR}/Makefile.all \
	    ${DIRS_first} ${DIRS_second} ${DIRS_third} ${DIRS_final}

	# try to minimize the amount of domake invocations.  this makes a
	# difference especially on systems with a large number of slow cores
	for target in ${targets}; do
		if [ ${target} = "dependall" ]; then
			domake ${OBJDIR}/Makefile.first ${target}
			domake ${OBJDIR}/Makefile.second ${target}
			domake ${OBJDIR}/Makefile.third ${target}
			domake ${OBJDIR}/Makefile.final ${target}
		else
			domake ${OBJDIR}/Makefile.all ${target}
		fi
	done
}

evaltools ()
{

	# check for crossbuild
	: ${CC:=cc}
	nativebuild=true
	[ ${CC} != 'cc' -a ${CC} != 'gcc' -a ${CC} != 'clang' ] \
	    && nativebuild=false
	type ${CC} > /dev/null 2>&1 \
	    || die cannot find \$CC: \"${CC}\".  check env.

	# Check the arch we're building for so as to work out the necessary
	# NetBSD machine code we need to use.  Use ${CC} -v instead
	# of -dumpmachine since at least older versions of clang don't
	# support -dumpmachine ... yay!

	# first check "${CC} -v" ... just in case it fails, we want a
	# sensible return value instead of it being lost in the pipeline
	# (this is easier than adjusting IFS)
	${CC} -v >/dev/null 2>&1 || \
	    die Cannot run \"${CC} -v\". Check that \"${CC}\" is a compiler

	# then actually process the output of ${CC} -v
	cc_target=$(LC_ALL=C ${CC} -v 2>&1 | sed -n 's/^Target: //p' )
	[ -z "${cc_target}" ] && die failed to probe target of \"${CC}\"
	MACH_ARCH=$(echo ${cc_target} | sed 's/-.*//' )

	if ${nativebuild}; then
		: ${AR:=ar}
		: ${NM:=nm}
		: ${OBJCOPY:=objcopy}
	else
		: ${AR:=${cc_target}-ar}
		: ${NM:=${cc_target}-nm}
		: ${OBJCOPY:=${cc_target}-objcopy}
	fi

	# Try to figure out the target system we're building for.
	case ${cc_target} in
	*-linux*)
		TARGET=linux
		;;
	*-dragonflybsd)
		TARGET=dragonfly
		;;
	*-freebsd)
		TARGET=freebsd
		;;
	*-netbsd*)
		TARGET=netbsd
		;;
	*-sun-solaris*)
		TARGET=sunos
		;;
	*-pc-cygwin)
		TARGET=cygwin
		;;
	*)
		TARGET=unknown
		;;
	esac
}

parseargs ()
{

	DBG='-O2 -g'
	ANYTARGETISGOOD=false
	NOISE=2
	debugginess=0
	BRDIR=$(dirname $0)
	THIRTYTWO=false
	SIXTYFOUR=false

	while getopts '3:6:d:DhHj:o:qrs:T:V:' opt; do
		case "$opt" in
		3)
			[ ${OPTARG} != '2' ] \
			    && die 'invalid option. did you mean -32?'
			${SIXTYFOUR} && die 32+64 given.  Want a 48bit build?
			THIRTYTWO=true
			;;
		6)
			[ ${OPTARG} != '4' ] \
			    && die 'invalid option. did you mean -64?'
			${THIRTYTWO} && die 32+64 given.  Want a 48bit build?
			SIXTYFOUR=true
			;;
		j)
			JNUM=${OPTARG}
			;;
		d)
			DESTDIR=${OPTARG}
			;;
		D)
			[ ! -z "${RUMP_DIAGNOSTIC}" ] \
			    && die Cannot specify releasy debug

			debugginess=$((debugginess+1))
			[ ${debugginess} -gt 0 ] && DBG='-O0 -g'
			[ ${debugginess} -gt 1 ] && RUMP_DEBUG=1
			[ ${debugginess} -gt 2 ] && RUMP_LOCKDEBUG=1
			;;
		H)
			ANYTARGETISGOOD=true
			;;
		q)
			# build.sh handles value going negative
			NOISE=$((NOISE-1))
			;;
		o)
			OBJDIR=${OPTARG}
			;;
		r)
			[ ${debugginess} -gt 0 ] \
			    && die Cannot specify debbuggy release
			RUMP_DIAGNOSTIC=no
			DBG=''
			;;
		s)
			SRCDIR=${OPTARG}
			;;
		T)
			BRTOOLDIR=${OPTARG}
			;;
		V)
			BUILDSH_VARGS="${BUILDSH_VARGS} -V ${OPTARG}"
			;;
		-)
			break
			;;
		h|\?)
			helpme
			;;
		esac
	done
	shift $((${OPTIND} - 1))

	BEQUIET="-N${NOISE}"
	[ -z "${BRTOOLDIR}" ] && BRTOOLDIR=${OBJDIR}/tooldir

	#
	# Determine what which parts we should execute.
	#
	allcmds='checkout checkoutcvs checkoutgit tools build install
	    tests fullbuild setupdest'
	fullbuildcmds="tools build install tests"

	for cmd in ${allcmds}; do
		eval do${cmd}=false
	done
	if [ $# -ne 0 ]; then
		for arg in $*; do
			while true ; do
				for cmd in ${allcmds}; do
					if [ "${arg}" = "${cmd}" ]; then
						eval do${cmd}=true
						break 2
					fi
				done
				die "Invalid arg $arg"
			done
		done
	else
		docheckoutgit=true
		dofullbuild=true
	fi
	if ${dofullbuild} ; then
		for cmd in ${fullbuildcmds}; do
			eval do${cmd}=true
		done
	fi

	if ${docheckoutcvs} ; then
		docheckout=true
		checkoutstyle=cvs
	fi
	if ${docheckout} || ${docheckoutgit} ; then
		docheckout=true
		checkoutstyle=git
	fi
}

abspath ()
{

	curdir=`pwd -P`
	eval cd \${${1}}
	eval ${1}=`pwd -P`
	cd ${curdir}
}

resolvepaths ()
{

	# resolve critical directories
	abspath BRDIR

	mkdir -p ${OBJDIR} || die cannot create ${OBJDIR}
	mkdir -p ${DESTDIR} || die cannot create ${DESTDIR}
	mkdir -p ${BRTOOLDIR} || die "cannot create ${BRTOOLDIR} (tooldir)"

	abspath DESTDIR
	abspath OBJDIR
	abspath BRTOOLDIR
	abspath SRCDIR

	RUMPMAKE="${BRTOOLDIR}/rumpmake"
}

checksrcversion ()
{

	[ ! -f "${SRCDIR}/build.sh" -o ! -f "${SRCDIR}/sys/rump/Makefile" ] && \
	    die \"${SRCDIR}\" is not a NetBSD source tree.  try -h

	# check if NetBSD src is new enough
	oIFS="${IFS}"
	IFS=':'
	exec 3>&2 2>/dev/null
	ver="`sed -n 's/^BUILDRUMP=//p' < ${SRCDIR}/sys/rump/VERSION`"
	exec 2>&3 3>&-
	set ${ver} 0
	[ "1${1}" -lt "1${NBSRC_DATE}" -o \
	    \( "1${1}" -eq "1${NBSRC_DATE}" -a "1${2}" -lt "1${NBSRC_SUB}" \) ]\
	    && die "Update NetBSD src (${SRCDIR}) to ${NBSRC_DATE}:${NBSRC_SUB}"
	IFS="${oIFS}"
}

check64 ()
{

	${SIXTYFOUR} \
	    && die Do not know how to do a 64bit build for \"${MACH_ARCH}\"
}

evaltarget ()
{

	case ${TARGET} in
	"dragonfly")
		RUMPKERN_UNDEF='-U__DragonFly__'
		;;
	"freebsd")
		RUMPKERN_UNDEF='-U__FreeBSD__'
		;;
	"linux")
		RUMPKERN_UNDEF='-Ulinux -U__linux -U__linux__ -U__gnu_linux__'
		EXTRA_RUMPUSER='-ldl -lrt'
		EXTRA_RUMPCLIENT='-lpthread -ldl'
		;;
	"netbsd")
		# what do you expect? ;)
		;;
	"sunos")
		RUMPKERN_UNDEF='-U__sun__ -U__sun -Usun'
		EXTRA_RUMPUSER='-lsocket -lrt -ldl -lnsl'
		EXTRA_RUMPCLIENT='-lsocket -ldl -lnsl'

		# I haven't managed to get static libs to work on Solaris,
		# so just be happy with shared ones
		BUILDSTATIC='-V NOSTATICLIB=1'
		;;
	"cygwin")
		BUILDSHARED='-V NOPIC=1'
		target_notsupp='yes'
		;;
	"unknown"|*)
		target_notsupp='yes'
		;;
	esac

	if [ "${target_notsupp}" = 'yes' ]; then
		${ANYTARGETISGOOD} || die unsupported target OS: ${TARGET}
	fi

	# decide 32/64bit build.  step one: probe compiler default
	if ${CC} -E -dM - < /dev/null | grep -q __LP64__; then
		ccdefault=64
	else
		ccdefault=32
	fi

	# step 2: if the user specified 32/64, try to establish if it will work
	if ${THIRTYTWO} && [ "${ccdefault}" -ne 32 ] ; then
		echo 'int main() {return 0;}' | ${CC} -m32 -o /dev/null -x c - \
		    ${EXTRA_RUMPUSER} > /dev/null 2>&1
		[ $? -eq 0 ] || ${ANYTARGETISGOOD} || \
		    die 'Gave -32, but probe shows it will not work.  Try -H?'
	elif ${SIXTYFOUR} && [ "${ccdefault}" -ne 64 ] ; then
		echo 'int main() {return 0;}' | ${CC} -m64 -o /dev/null -x c - \
		    ${EXTRA_RUMPUSER} > /dev/null 2>&1
		[ $? -eq 0 ] || ${ANYTARGETISGOOD} || \
		    die 'Gave -64, but probe shows it will not work.  Try -H?'
	else
		# not specified.  use compiler default
		if [ "${ccdefault}" -eq 64 ]; then
			SIXTYFOUR=true
		else
			THIRTYTWO=true
		fi
	fi

	TOOLABI=''
	case ${MACH_ARCH} in
	"x86_64")
		if ${THIRTYTWO} ; then
			MACHINE="i386"
			MACH_ARCH="i486"
			TOOLABI="elf"
			EXTRA_CFLAGS='-D_FILE_OFFSET_BITS=64 -m32'
			EXTRA_LDFLAGS='-m32'
			EXTRA_AFLAGS='-D_FILE_OFFSET_BITS=64 -m32'
		else
			MACHINE="amd64"
		fi
		;;
	"i386"|"i486"|"i586"|"i686")
		check64
		MACHINE="i386"
		MACH_ARCH="i486"
		TOOLABI="elf"
		;;
	"arm"|"armv6l")
		check64
		MACHINE="evbarm"
		MACH_ARCH="arm"
		TOOLABI="elf"
		# XXX: assume at least armv6k due to armv6 inaccuracy in NetBSD
		EXTRA_CFLAGS='-march=armv6k'
		EXTRA_AFLAGS='-march=armv6k'

		# force hardfloat, default (soft) doesn't work on all targets
		SOFTFLOAT='-V MKSOFTFLOAT=no'
		;;
	"sparc")
		if ${THIRTYTWO} ; then
			MACHINE="sparc"
			MACH_ARCH="sparc"
			TOOLABI="elf"
			EXTRA_CFLAGS='-D_FILE_OFFSET_BITS=64'
			EXTRA_AFLAGS='-D_FILE_OFFSET_BITS=64'
		else
			MACHINE="sparc64"
			MACH_ARCH="sparc64"
			EXTRA_CFLAGS='-m64'
			EXTRA_LDFLAGS='-m64'
			EXTRA_AFLAGS='-m64'
		fi
		;;
	esac
	[ -z "${MACHINE}" ] && die script does not know machine \"${MACH_ARCH}\"
}

setupdest ()
{

	# set up $dest via symlinks.  this is easier than trying to teach
	# the NetBSD build system that we're not interested in an extra
	# level of "usr"
	mkdir -p ${DESTDIR}/include/rump || die create ${DESTDIR}/include/rump
	mkdir -p ${DESTDIR}/lib || die create ${DESTDIR}/lib
	mkdir -p ${OBJDIR}/dest/usr/share/man \
	    || die create ${OBJDIR}/dest/usr/share/man
	ln -sf ${DESTDIR}/include ${OBJDIR}/dest/usr/
	ln -sf ${DESTDIR}/lib ${OBJDIR}/dest/usr/
	for man in cat man ; do 
		for x in 1 2 3 4 5 6 7 8 9 ; do
			mkdir -p ${DESTDIR}/share/man/${man}${x} \
			    || die create ${DESTDIR}/share/man/${man}${x}
			ln -sf ${DESTDIR}/share/man/${man}${x} \
			    ${OBJDIR}/dest/usr/share/man/
		done
	done
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

	printf '\n\n.include <bsd.subdir.mk>\n'
	exec 1>&3 3>&-
}

domake ()
{

	[ ! -x ${RUMPMAKE} ] && die "No rumpmake (${RUMPMAKE}). Forgot tools?"
	${RUMPMAKE} -j ${JNUM} -f ${1} ${2}
	[ $? -eq 0 ] || die "make $1 $2"
}

###
###
### BEGIN SCRIPT
###
###

evaltools
parseargs $*

${docheckout} && { ${BRDIR}/checkout.sh ${checkoutstyle} ${SRCDIR} || exit 1; }

evaltarget

resolvepaths

if ${dobuild} || ${doinstall}; then
	# install uses src tree Makefiles
	checksrcversion

	# build implies we need a dest
	dosetupdest=true
fi
${dosetupdest} && setupdest

${dotools} && maketools

targets=''
${dobuild} && targets="obj includes dependall"
${doinstall} && targets="${targets} install"
[ ! -z "${targets}" ] && makebuild ${targets}

if ${dotests}; then
	. ${BRDIR}/tests/testrump.sh
	alltests
fi

exit 0

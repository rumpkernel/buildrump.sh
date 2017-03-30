#! /usr/bin/env sh
#
# Copyright (c) 2013, 2014, 2015 Antti Kantee <pooka@rumpkernel.org>
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

set -u

#
# scrub necessary parts of the env
BUILDRUMP_CPPCACHE=
CCWRAPPER_MANGLE=

# defaults, can be overriden by probes
RUMP_VIRTIF=no
HIJACK=false
SYS_SUNOS=false
NEED_LDSCRIPT=false
TARBALLMODE=

# empty before proven contentful
EXTRA_CFLAGS=
EXTRA_LDFLAGS=
EXTRA_AFLAGS=
EXTRA_CPPFLAGS=
EXTRA_CWARNFLAGS=
EXTRA_RUMPUSER=
EXTRA_RUMPCOMMON=
EXTRA_RUMPCLIENT=
RUMPKERN_UNDEF=
BUILDSH_VARGS=

#
# support routines
#

helpme ()
{

	echo "Usage: $0 [-h] [options] [command] [command...]"
	printf "supported options:\n"
	printf "\t-d: location for headers/libs.  default: PWD/rump\n"
	printf "\t-o: location for build-time files.  default: PWD/obj\n"
	printf "\t-T: location for tools+rumpmake.  default: PWD/obj/tooldir\n"
	printf "\t-s: location of source tree.  default: PWD/src\n"
	echo
	printf "\t-j: value of -j specified to make.  default: ${JNUM}\n"
	printf "\t-q: quiet build, less compiler output.  default: noisy\n"
	printf "\t-r: release build (no -g, DIAGNOSTIC, etc.).  default: no\n"
	printf "\t-D: increase debugginess.  default: -O2 -g\n"
	printf "\t-k: only kernel (no POSIX hypercalls).  default: all\n"
	printf "\t-l: choose a rumpkernel: netbsd or linux.  default: netbsd\n"
	echo
	printf "\t-H: ignore diagnostic checks (expert-only).  default: no\n"
	printf "\t-V: specify -V arguments to NetBSD build (expert-only)\n"
	printf "\t-F: specify build flags with -F XFLAGS=value\n"
	printf "\t    possible values for XFLAGS:\n"
	printf "\t    CFLAGS, AFLAGS, LDFLAGS, ACFLAGS, ACLFLAGS,\n"
	printf "\t    CPPFLAGS, CWARNFLAGS, DBG\n"
	echo
	printf "supported commands (default => checkout+fullbuild+tests):\n"
	printf "\tcheckoutgit:\tfetch NetBSD sources to srcdir from github\n"
	printf "\tcheckoutcvs:\tfetch NetBSD sources to srcdir from anoncvs\n"
	printf "\tcheckout:\talias for checkoutgit\n"
	printf "\ttools:\t\tbuild necessary tools to tooldir\n"
	printf "\tbuild:\t\tbuild everything related to rump kernels\n"
	printf "\tinstall:\tinstall rump kernel components into destdir\n"
	printf "\ttests:\t\trun tests to verify installation is functional\n"
	printf "\tfullbuild:\talias for \"tools build install\"\n"
	exit 1
}

DIAGOUT=echo
diagout ()
{

	if [ "${1:-}" != '-r' ]; then
		${DIAGOUT} -n '>> '
	else
		shift
	fi
	${DIAGOUT} $*
}

#
# toolchain creation helper routines
#

printoneconfig ()
{

	[ -z "${2}" ] || printf "%-5s %-18s: %s\n" "${1}" "${2}" "${3}"
}

appendmkconf ()
{
	if [ ! -z "${2}" ]; then
		# cheat a bit: output BUILDRUMP_CFLAGS/AFLAGS without
		# the prefix as the name so to as not confuse the user
		# (the reason why it's BUILDRUMP_CFLAGS instead of
		# CFLAGS is so that we get the flags right for
		# the RUMPCOMP_USER case)
		case $3 in
		'BUILDRUMP_CFLAGS'|'BUILDRUMP_AFLAGS')
			name=${3#BUILDRUMP_}
			;;
		*)
			name=${3}
		esac

		val=${2# }
		printoneconfig "${1}" "${name}" "${val}"
		echo "${3}${4:-}=${val}" >> "${MKCONF}"
	fi
}

appendvar_fs ()
{
	vname="${1}"
	fs="${2}"
	shift 2
	if [ -z "$(eval echo \${${vname}:-})" ]; then
		eval ${vname}="\${*}"
	else
		eval ${vname}="\"\${${vname}}"\${fs}"\${*}\""
	fi
}

appendvar ()
{

	vname="$1"
	shift
	appendvar_fs "${vname}" ' ' $*
}

#
# Not all platforms have  the same set of crt files.  for some
# reason unbeknownst to me, if the file does not exist,
# at least gcc --print-file-name just echoes the input parameter.
# Try to detect this and tell the NetBSD makefiles that the crtfile
# in question should be left empty.
chkcrt ()
{
	tst=`${CC} --print-file-name=crt${1}.o`
	up=`echo ${1} | tr [a-z] [A-Z]`
	[ -z "${tst%crt${1}.o}" ] \
	    && echo "_GCC_CRT${up}=" >>"${MKCONF}"
}

probeld ()
{

	linkervers=$(LANG=C ${CC} ${EXTRA_LDFLAGS} -Wl,--version 2>&1)
	if echo ${linkervers} | grep -q 'GNU ld' ; then
		LD_FLAVOR=GNU
		LD_AS_NEEDED='-Wl,--no-as-needed'
	elif echo ${linkervers} | grep -q 'GNU gold' ; then
		LD_FLAVOR=gold
		LD_AS_NEEDED='-Wl,--no-as-needed'
	elif echo ${linkervers} | grep -q 'Solaris Link Editor' ; then
		LD_FLAVOR=sun
		SHLIB_MKMAP=no
		appendvar_fs CCWRAPPER_MANGLE : '-Wl,-x'
	else
		diagout 'output from linker:'
		diagout -r ${linkervers}
		die 'GNU or Solaris ld required'
	fi

	# use traditional link sets for freestanding targets,
	# use __attribute__((constructor)) elsewhere
	if ${KERNONLY}; then
		LDSCRIPT='no'
	elif ! ${NEED_LDSCRIPT}; then
		LDSCRIPT='ctor'
	fi
}

# Check if $NM outputs the format we except, i.e. if symbols
# are the alone in the last whitespace-separated column.
# GNU and OpenBSD nm do this, e.g. Solaris does not.
probenm ()
{

	echo 'void testsym(void); void testsym(void) {return;}' \
	    | ${CC} ${EXTRA_CFLAGS} -x c -c - -o ${OBJDIR}/probenm.o
	lastfield=$(${NM} -go ${OBJDIR}/probenm.o | awk '/testsym/{print $NF}')
	if [ "${lastfield}" != 'testsym' ]; then
		diagout nm: expected \"testsym\", got \"${lastfield}\"
		die incompatible output from probing \"${NM}\"
	fi
	rm -f ${OBJDIR}/probenm.o
}

# For ar, we just check the --version.  Works so far.  If it breaks,
# need to start building archives ...
probear ()
{

	# Check for GNU/BSD ar
	if ! ${AR} -V 2>/dev/null | egrep '(GNU|BSD) ar' > /dev/null ; then
		die Need GNU or BSD ar "(`type ${AR}`)"
	fi
}

#
# Check if cpp defines $1 (with any value).
# If $# > 1, use the remaining args as args to cc.
#
cppdefines ()
{

	var=${1}
	shift
	if [ $# -eq 0 ]; then
		if [ -z "${BUILDRUMP_CPPCACHE}" ]; then
			BUILDRUMP_CPPCACHE=$(${CC} ${EXTRA_CPPFLAGS} \
			    ${EXTRA_CFLAGS} -E -Wp,-dM - < /dev/null)
		fi
		cpplist="${BUILDRUMP_CPPCACHE}"
	else
		cpplist=$(${CC} ${EXTRA_CPPFLAGS} ${EXTRA_CFLAGS} \
		    -E -Wp,-dM "$@" - < /dev/null)
	fi
	(
	    IFS=' '
	    echo ${cpplist} | awk '$2 == "'$var'"{exit 37}'
	    exit $?
	)
	[ $? -eq 37 ]
	return
}

# check if C snippet given as first argument will build
# arguments [2..n] are passed to the compiler
doesitbuild ()
{

	theprog="${1}"
	shift

	warnflags="-Wmissing-prototypes -Wstrict-prototypes -Wimplicit -Werror"
	printf "${theprog}" \
	    | ${CC} ${warnflags} ${EXTRA_LDFLAGS} ${EXTRA_CFLAGS}	\
		-x c - -o /dev/null $* > /dev/null 2>&1
}

doesitbuild_host ()
{

	theprog="${1}"
	shift

	printf "${theprog}" \
	    | ${HOST_CC} -Wall -Werror -x c - -o /dev/null $* > /dev/null 2>&1
}

# like doesitbuild, except with c++
doesitcxx ()
{

	${HAVECXX} || die internal error: doesitcxx called without cxx

	theprog="${1}"
	shift

	printf "${theprog}" \
	    | ${CXX} -Werror ${EXTRA_LDFLAGS} ${EXTRA_CFLAGS}	\
		-x c++ - -o /dev/null $* > /dev/null 2>&1
}

checkcompiler ()
{

	# Iron out the clang version differences.
	if [ "${CC_FLAVOR}" = 'clang' ]; then
		doesitbuild 'int main(void) {return 0;}\n' -c \
			-Wtautological-pointer-compare
		if [ $? -ne 0 ]; then
			appendvar_fs CCWRAPPER_MANGLE : \
				"-Wno-error=tautological-pointer-compare -Wno-error=tautological-compare"
		fi
	fi

	if ! ${KERNONLY}; then
		doesitbuild 'int main(void) {return 0;}\n' \
		    ${EXTRA_RUMPUSER} ${EXTRA_RUMPCOMMON}
		[ $? -eq 0 ] || ${TITANMODE} || \
		    die 'Probe cannot build a binary'
	fi
}

probe_rumpuserbits ()
{

	# Do we need -lrt for time related stuff?
	# Old glibc and Solaris need it, but newer glibc and most
	# other systems do not need or have librt.
	for l in '' '-lrt' ; do
		doesitbuild '#include <time.h>\n
		    int main(void) {
			struct timespec ts;
			return clock_gettime(CLOCK_REALTIME, &ts);}' $l
		if [ $? -eq 0 ]; then
			EXTRA_RUMPUSER="$l"
			break
		fi
	done

	# Do we need -lpthread for threads?
	# Most systems do, but Android does not have it at all and
	# Musl does not require it
	doesitbuild '#include <pthread.h>\n
		#include <stddef.h>\n
		static void *t(void *arg) {return NULL;}\n
		int main(void)\n
		{pthread_t p;return pthread_create(&p,NULL,t,NULL);}\n'
	if [ $? -eq 0 ]; then
		appendvar_fs CCWRAPPER_MANGLE : '-lpthread'
	fi

	[ -x ${SRCDIR}/lib/librumpuser/configure ] \
	    || die 'librumpuser configure script missing (source dir too old)'

	if [ ! -f ${BRTOOLDIR}/autoconf/rumpuser_config.h ]; then
		diagout '>> running librumpuser configure script'
		diagout
		mkdir -p ${BRTOOLDIR}/autoconf
		( export CFLAGS="${EXTRA_CFLAGS}"
		  export LDFLAGS="${EXTRA_LDFLAGS}"
		  export CPPFLAGS="${EXTRA_CPPFLAGS}"
		  cd ${BRTOOLDIR}/autoconf \
		    && ${SRCDIR}/lib/librumpuser/configure \
		      $( ! ${NATIVEBUILD} && echo --host ${CC_TARGET} ) )
		[ $? -eq 0 ] || die configure script failed
	fi

	echo "CPPFLAGS+=-DRUMPUSER_CONFIG=yes" >> "${MKCONF}"
	echo "CPPFLAGS+=-I${BRTOOLDIR}/autoconf" >> "${MKCONF}"
}

writeproberes ()
{

	probevars='
		HAVE_LLVM
		HAVE_PCC
		MACHINE
		MACHINE_GNU_ARCH
	'

	for x in ${probevars}; do
		printf 'BUILDRUMP_%s="%s"\n' ${x} $(eval echo \${${x}:-})
	done
}

WRAPPERBODY='int
main(int argc, const char *argv[])
{
	int i, j, k;

	for (i = 1; i < argc; i++) {
		for (j = 0; j < sizeof(mngl_from)/sizeof(mngl_from[0]); j++) {
			if (strcmp(argv[i], mngl_from[j]) == 0) {
				if (strlen(mngl_to[j]) == 0) {
					for (k = i; k < argc; k++) {
						argv[k] = argv[k+1];
					}
					argv[k] = '\0';
					argc--;
				} else {
					argv[i] = mngl_to[j];
				}
				break;
			}
		}
	}
'

maketoolwrapper ()
{

	musthave=$1
	tool=$2

	eval evaldtool=\${${tool}}
	fptool=$(which ${evaldtool})
	if [ ! -x ${fptool} ]; then
		if ! ${musthave}; then
			return
		else
			die Internal error: mandatory tool ${tool} not found
		fi
	fi

	# ok, it's not really --netbsd, but let's make-believe!
	if [ ${tool} = CC ]; then
		lcx=${CC_FLAVOR}
	elif [ ${tool} = CXX ]; then
		case ${CC_FLAVOR} in
		gcc)
			lcx=c++
			;;
		clang)
			lcx=clang++
			;;
		esac
	else
		lcx=$(echo ${tool} | tr '[A-Z]' '[a-z]')
	fi
	tname=${BRTOOLDIR}/bin/${MACHINE_GNU_ARCH}--netbsd${TOOLABI}-${lcx}

	printoneconfig 'Tool' "${tool}" "${fptool}"

	# Mangle wrapper arguments from what NetBSD does to what the
	# toolchain we use supports.  In case we need mangling, do it
	# with a C wrapper to preserve all quoting etc. (couldn't
	# figure out how to get that right with a shell.
	if [ "${tool}" != 'CC' -a "${tool}" != 'CXX' \
	    -o -z "${CCWRAPPER_MANGLE}" ]; then
		printf '#!/bin/sh\n' > ${tname}
		printf 'exec %s "$@"\n' ${fptool} >> ${tname}
	else
		rm -f ${OBJDIR}/wrapper.c
		exec 3>&1 1>${OBJDIR}/wrapper.c
		printf '#include <inttypes.h>\n'
		printf '#include <string.h>\n'
		printf '#include <unistd.h>\n\n'
		printf 'static const char *mngl_from[] = {\n'
		(
			IFS=:
			for xf in ${CCWRAPPER_MANGLE}; do
				IFS=' '
				set -- ${xf}
				printf '\t"%s",\n' ${1}
			done
		)
		printf '};\nstatic const char *mngl_to[] ={\n'
		(
			IFS=:
			for xf in ${CCWRAPPER_MANGLE}; do
				IFS=' '
				set -- ${xf}
				printf '\t"%s",\n' ${2:-}
			done
		)
		printf '};\n\n'
		( IFS=' ' printf '%s' "${WRAPPERBODY}" )
		printf '\targv[0] = "%s";\n' ${fptool}
		printf '\texecvp(argv[0], (void *)(uintptr_t)argv);\n'
		printf '\treturn 0;\n}\n'
		exec 1>&3 3>&-

		${HOST_CC} ${OBJDIR}/wrapper.c -o ${tname} \
		    || die failed to build wrapper for ${tool}
		rm -f ${OBJDIR}/wrapper.c
	fi
	chmod 755 ${tname}
}

#
# Create tools and wrappers.  This step needs to be run at least once.
# The routine is run if the "tools" argument is specified.
#
# You might want to skip it because:
# 1) iteration speed on a slow-ish host
# 2) making manual modifications to the tools for testing and avoiding
#    the script nuking them on the next iteration
#
# external toolchain links are created in the format that
# build.sh expects.
#
maketools ()
{

	checkcheckout

	probeld
	probenm
	probear
	${HAVECXX} && probecxx

	cd ${OBJDIR}

	# Create mk.conf.  Create it under a temp name first so as to
	# not affect the tool build with its contents
	MKCONF="${BRTOOLDIR}/mk.conf.building"
	> "${MKCONF}"
	mkconf_final="${BRTOOLDIR}/mk.conf"
	> ${mkconf_final}

	# nuke fakelibz (compat for old libz hack, the following line can
	# be removed e.g. in 2017)
	rm -f ${OBJDIR}/libz.a

	# We now require a host zlib for tools.  nb. we explicitly whine
	# about this one here since the NetBSD tools build process gets
	# very confused if you start the build, it bombs, you add zlib,
	# and retry.
	doesitbuild_host '#include <zlib.h>
#include <stdlib.h>
int main() {gzopen(NULL, NULL); return 0;}' -lz \
	    || die 'Host zlib (libz, -lz) required, please install one!'

	${KERNONLY} || probe_rumpuserbits

	checkcompiler

	#
	# Create external toolchain wrappers.
	mkdir -p ${BRTOOLDIR}/bin || die "cannot create ${BRTOOLDIR}/bin"
	for x in CC AR NM OBJCOPY; do
		maketoolwrapper true $x
	done
	for x in AS LD OBJDUMP RANLIB READELF SIZE STRINGS STRIP; do
		maketoolwrapper false $x
	done
	${HAVECXX} && maketoolwrapper false CXX

	# create a cpp wrapper, but run it via cc -E
	if [ "${CC_FLAVOR}" = 'clang' ]; then
		cppname=clang-cpp
	else
		cppname=cpp
	fi
	# NB: we need rumpmake to build libbmk_*, but rumpmake needs --netbsd TOOLTUPLES
	tname=${BRTOOLDIR}/bin/${MACHINE_GNU_ARCH}--netbsd${TOOLABI}-${cppname}
	printf '#!/bin/sh\n\nexec %s -E -x c "${@}"\n' ${CC} > ${tname}
	chmod 755 ${tname}

	for x in 1 2 3; do
		! ${HOST_CC} -o ${BRTOOLDIR}/bin/brprintmetainfo \
		    -DSTATHACK${x} ${BRDIR}/brlib/utils/printmetainfo.c \
		    >/dev/null 2>&1 || break
	done
	[ -x ${BRTOOLDIR}/bin/brprintmetainfo ] \
	    || die failed to build brprintmetainfo

	${HOST_CC} -o ${BRTOOLDIR}/bin/brrealpath \
	    ${BRDIR}/brlib/utils/realpath.c || die failed to build brrealpath

	cat >> "${MKCONF}" << EOF
BUILDRUMP_IMACROS=${BRIMACROS}
.if \${BUILDRUMP_SYSROOT:Uno} == "yes"
BUILDRUMP_CPPFLAGS=--sysroot=\${BUILDRUMP_STAGE} -isystem =/usr/include
.else
BUILDRUMP_CPPFLAGS=-I\${BUILDRUMP_STAGE}/usr/include
.endif
BUILDRUMP_CPPFLAGS+=${EXTRA_CPPFLAGS}
LIBDO.pthread=_external
INSTPRIV=-U
AFLAGS+=-Wa,--noexecstack
MKPROFILE=no
MKARZERO=no
USE_SSP=no
MKHTML=no
MKCATPAGES=yes
MKNLS=no
RUMP_NPF_TESTING?=no
RUMPRUN=yes
EOF

	if ! ${KERNONLY}; then
		# queue.h is not available on all systems, but we need it for
		# the hypervisor build.  So, we make it available in tooldir.
		mkdir -p ${BRTOOLDIR}/compat/include/sys \
		    || die create ${BRTOOLDIR}/compat/include/sys
		cp -p ${SRCDIR}/sys/sys/queue.h ${BRTOOLDIR}/compat/include/sys
		echo "CPPFLAGS+=-I${BRTOOLDIR}/compat/include" >> "${MKCONF}"
	fi

	printoneconfig 'Cmd' "SRCDIR" "${SRCDIR}"
	printoneconfig 'Cmd' "DESTDIR" "${DESTDIR}"
	printoneconfig 'Cmd' "OBJDIR" "${OBJDIR}"
	printoneconfig 'Cmd' "BRTOOLDIR" "${BRTOOLDIR}"

	appendmkconf 'Cmd' "${RUMP_DIAGNOSTIC:-}" "RUMP_DIAGNOSTIC"
	appendmkconf 'Cmd' "${RUMP_DEBUG:-}" "RUMP_DEBUG"
	appendmkconf 'Cmd' "${RUMP_LOCKDEBUG:-}" "RUMP_LOCKDEBUG"
	appendmkconf 'Cmd' "${DBG:-}" "DBG"
	printoneconfig 'Cmd' "make -j[num]" "-j ${JNUM}"

	if ${KERNONLY}; then
		appendmkconf Cmd yes RUMPKERN_ONLY
	fi

	if ${KERNONLY} && ! cppdefines ${RUMPKERN_CPPFLAGS}; then
		appendmkconf 'Cmd' "${RUMPKERN_CPPFLAGS}" 'CPPFLAGS' +
		appendmkconf 'Probe' "${RUMPKERN_UNDEF}" 'CPPFLAGS' +
	else
		appendmkconf 'Probe' "${RUMPKERN_UNDEF}" "RUMPKERN_UNDEF"
	fi
	appendmkconf 'Probe' "${RUMP_CURLWP:-}" 'RUMP_CURLWP' ?
	appendmkconf 'Probe' "${CTASSERT:-}" "CPPFLAGS" +
	appendmkconf 'Probe' "${RUMP_VIRTIF:-}" "RUMP_VIRTIF"
	appendmkconf 'Probe' "${EXTRA_CWARNFLAGS}" "CWARNFLAGS" +
	appendmkconf 'Probe' "${EXTRA_LDFLAGS}" "LDFLAGS" +
	appendmkconf 'Probe' "${EXTRA_CPPFLAGS}" "CPPFLAGS" +
	appendmkconf 'Probe' "${EXTRA_CFLAGS}" "BUILDRUMP_CFLAGS"
	appendmkconf 'Probe' "${EXTRA_AFLAGS}" "BUILDRUMP_AFLAGS"
	_tmpvar=
	for x in ${EXTRA_RUMPUSER} ${EXTRA_RUMPCOMMON}; do
		appendvar _tmpvar "${x#-l}"
	done
	appendmkconf 'Probe' "${_tmpvar}" "RUMPUSER_EXTERNAL_DPLIBS" +
	_tmpvar=
	for x in ${EXTRA_RUMPCLIENT} ${EXTRA_RUMPCOMMON}; do
		appendvar _tmpvar "${x#-l}"
	done
	appendmkconf 'Probe' "${_tmpvar}" "RUMPCLIENT_EXTERNAL_DPLIBS" +
	appendmkconf 'Probe' "${LDSCRIPT:-}" "RUMP_LDSCRIPT"
	appendmkconf 'Probe' "${SHLIB_MKMAP:-}" 'SHLIB_MKMAP'
	appendmkconf 'Probe' "${SHLIB_WARNTEXTREL:-}" "SHLIB_WARNTEXTREL"
	appendmkconf 'Probe' "${MKSTATICLIB:-}"  "MKSTATICLIB"
	appendmkconf 'Probe' "${MKPIC:-}"  "MKPIC"
	appendmkconf 'Probe' "${MKSOFTFLOAT:-}"  "MKSOFTFLOAT"
	appendmkconf 'Probe' $(${HAVECXX} && echo yes || echo no) _BUILDRUMP_CXX

	printoneconfig 'Mode' "${TARBALLMODE}" 'yes'

	rm -f ${BRTOOLDIR}/toolchain-conf.mk
	exec 3>&1 1>${BRTOOLDIR}/toolchain-conf.mk
	printf 'BUILDRUMP_TOOL_CFLAGS=%s\n' "${EXTRA_CFLAGS}"
	printf 'BUILDRUMP_TOOL_CXXFLAGS=%s\n' "${EXTRA_CFLAGS}"
	printf 'BUILDRUMP_TOOL_CPPFLAGS=%s %s %s\n' \
	    "${RUMPKERN_CPPFLAGS}" "${EXTRA_CPPFLAGS}" "${RUMPKERN_UNDEF}"
	exec 1>&3 3>&-

	chkcrt begins
	chkcrt ends
	chkcrt i
	chkcrt n

	# add vars from env last (so that they can be used for overriding)
	cat >> "${MKCONF}" << EOF
CPPFLAGS+=\${BUILDRUMP_CPPFLAGS}
CFLAGS+=\${BUILDRUMP_CFLAGS}
AFLAGS+=\${BUILDRUMP_AFLAGS}
LDFLAGS+=\${BUILDRUMP_LDFLAGS}
EOF

	if ! ${KERNONLY}; then
		echo >> "${MKCONF}"
		cat >> "${MKCONF}" << EOF
# Support for NetBSD Makefiles which use <bsd.prog.mk>
# It's mostly a question of erasing dependencies that we don't
# expect to see
.ifdef PROG
LIBCRT0=
LIBCRTBEGIN=
LIBCRTEND=
LIBCRTI=
LIBC=

LDFLAGS+= -L\${BUILDRUMP_STAGE}/usr/lib -Wl,-R${DESTDIR}/lib
LDADD+= ${EXTRA_RUMPCOMMON} ${EXTRA_RUMPUSER} ${EXTRA_RUMPCLIENT}
EOF
		appendmkconf 'Probe' "${LD_AS_NEEDED}" LDFLAGS +
		echo '.endif # PROG' >> "${MKCONF}"
	fi

	# Run build.sh.  Use some defaults.
	# The html pages would be nice, but result in too many broken
	# links, since they assume the whole NetBSD man page set to be present.
	cd ${SRCDIR}

	# create user-usable wrapper script
	makemake ${BRTOOLDIR}/rumpmake ${BRTOOLDIR}/dest makewrapper

	# create wrapper script to be used during buildrump.sh, plus tools
	makemake ${RUMPMAKE} ${OBJDIR}/dest.stage tools

	# Just set no MSI in imacros universally now.
	# Need to:
	#   a) migrate more defines there
	#   b) set no MSI only when necessary
	printf '#define NO_PCI_MSI_MSIX\n' > ${BRIMACROS}.building

	# tool build done.  flip mk.conf name so that it gets picked up
	omkconf="${MKCONF}"
	MKCONF="${mkconf_final}"
	mv "${omkconf}" "${MKCONF}"
	unset omkconf mkconf_final

	# set new BRIMACROS only if the contents change (avoids
	# full rebuild, since every file in the rump kernel depends on the
	# contents of BRIMACROS
	if ! diff "${BRIMACROS}" "${BRIMACROS}.building" > /dev/null 2>&1; then
		mv "${BRIMACROS}.building" "${BRIMACROS}"
	fi
}

makemake ()
{

	wrapper=$1
	stage=$2
	cmd=$3

	CFLAGS= HOST_LDFLAGS=-L${OBJDIR} ./build.sh \
	    -m ${MACHINE} -u \
	    -D ${stage} -w ${wrapper} \
	    -T ${BRTOOLDIR} -j ${JNUM} \
	    ${HAVE_LLVM:+-V HAVE_LLVM=${HAVE_LLVM}} \
	    ${HAVE_PCC:+-V HAVE_PCC=${HAVE_PCC}} \
	    ${BEQUIET} \
	    -E -Z S \
	    -V EXTERNAL_TOOLCHAIN=${BRTOOLDIR} -V TOOLCHAIN_MISSING=yes \
	    -V TOOLS_BUILDRUMP=yes \
	    -V MKGROFF=no \
	    -V MKLINT=no \
	    -V MKZFS=no \
	    -V MKDYNAMICROOT=no \
	    -V MKDTRACE=no -V MKCTF=no \
	    -V MKPIE=no \
	    -V TOPRUMP="${SRCDIR}/sys/rump" \
	    -V MAKECONF="${mkconf_final}" \
	    -V MAKEOBJDIR="\${.CURDIR:C,^(${SRCDIR}|${BRDIR}),${OBJDIR},}" \
	    -V BUILDRUMP_STAGE=${stage} \
	    ${BUILDSH_VARGS} \
	${cmd}
	[ $? -ne 0 ] && die build.sh ${cmd} failed
}

settool ()
{

	tool=$1
	crossnames=$2
	eval evaldtool=\${${tool}:-}

	if [ -n "${evaldtool}" ]; then
		# if it's set in the env, we require it to exist
		if ! type ${evaldtool} > /dev/null; then
			die ${tool} set in env but not found
		fi
	else
		# else, set a default value, existence to be checked
		# and consequences evaluated later
		lcname=$(echo ${tool} | tr '[A-Z]' '[a-z]')
		if ${crossnames}; then
			eval ${tool}=${CC_TARGET}-${lcname}
		else
			eval ${tool}=${lcname}
		fi
	fi
}

evaltoolchain ()
{

	# is the compiler which targets the host "cc" or something else
	: ${HOST_CC:=cc}
	type ${HOST_CC} >/dev/null 2>&1 \
	    || die '${HOST_CC}' not found "(tried \"${HOST_CC}\")"

	# target compiler
	: ${CC:=cc}
	type ${CC} > /dev/null 2>&1 \
	    || die cannot find \$CC: \"${CC}\".  check env.

	# check that compiler want to compile at all
	doesitbuild 'int main(void) { return 0; }' -c \
	    || die simple cc test failed using: ${CC} ${EXTRA_CFLAGS}

	# check for crossbuild
	if ${KERNONLY}; then
		NATIVEBUILD=false
	else
		printf 'int main(void) { return 0; }' \
		    | ${CC} ${EXTRA_CFLAGS} ${EXTRA_LDFLAGS} -x c - \
			-o ${OBJDIR}/canrun > /dev/null 2>&1
		[ $? -eq 0 ] && ${OBJDIR}/canrun
		if [ $? -eq 0 ]; then
			NATIVEBUILD=true
			diagout NATIVE build environment probed
		else
			NATIVEBUILD=false
			diagout CROSS build environment probed
		fi
		rm -f ${OBJDIR}/canrun
	fi

	# Check for variant of compiler.
	# XXX: why can't all cc's that are gcc actually tell me
	#      that they're gcc with cc --version?!?
	unset HAVE_LLVM HAVE_PCC
	ccver=$(${CC} --version)
	if echo ${ccver} | grep -q 'Free Software Foundation'; then
		CC_FLAVOR=gcc
	elif echo ${ccver} | grep -q clang; then
		CC_FLAVOR=clang
		HAVE_LLVM=yes
	elif echo ${ccver} | grep -q pcc; then
		CC_FLAVOR=pcc
		HAVE_PCC=yes
	else
		die Unsupported \${CC} "(`type ${CC}`)"
	fi

	# See if we have a c++ compiler.  If CXX is not set,
	# try to guess what it could be.  In the latter case, do
	# not treat a missing c++ compiler as an error.
	if [ -n "${CXX:-}" ]; then
		type ${CXX} > /dev/null 2>&1 \
		    || die \$CXX set \(${CXX}\) but not found
		HAVECXX=true
	else
		cxxguess=
		case ${CC} in
		*gcc*)
			cxxguess=$(echo $CC | sed 's/gcc$/g++/')
			;;
		*clang*)
			cxxguess=$(echo $CC | sed 's/clang$/clang++/')
			;;
		*cc)
			cxxguess=$(echo $CC | sed 's/cc$/c++/')
			;;
		esac
		if [ -n "${cxxguess}" ] && type ${cxxguess} >/dev/null 2>&1
		then
			CXX=${cxxguess}
			HAVECXX=true
		else
			HAVECXX=false
		fi
	fi

	# Check the arch we're building for so as to work out the necessary
	# NetBSD machine code we need to use.  First try -dumpmachine,
	# and if that works, be happy with it.  Not all compilers support
	# it (e.g. older versions of clang), so if that doesn't work,
	# try parsing the output of -v
	if ! CC_TARGET=$(${CC} -dumpmachine 2>/dev/null) ; then
		# first check "${CC} -v" ... just in case it fails, we want a
		# sensible return value instead of it being lost in the pipeline
		# (this is easier than adjusting IFS)
		if ${CC} -v >/dev/null 2>&1 ; then
			# then actually process the output of ${CC} -v
			CC_TARGET=$(LC_ALL=C ${CC} -v 2>&1 \
			    | sed -n 's/^Target: //p' )
			[ -z "${CC_TARGET}" ] \
			    && die failed to probe target of \"${CC}\"
		else
			# this might be pcc
			${CC} -v 2>&1 | grep pcc > /dev/null || \
			    die \"${CC} -v failed\". Check \"${CC}\"
			CC_TARGET=$(${CC} -v 2>&1 \
			    | sed -n -e 's/^pcc.*for //' -e 's/,.*//p' )
		fi
	fi
	MACHINE_GNU_ARCH=$(echo ${CC_TARGET} | sed 's/-.*//' )

	#
	# Try to figure out if we're using the native toolchain or
	# a cross one.  Assume that a native cc doesn't have '-'
	# in its name.  We use this information in the step below
	# where we guess toolchain defaults.
	#
	basecc="$(basename ${CC})"
	if [ "${basecc}" = "${basecc#*-*-}" ]; then
		crosstools=false
	else
		crosstools=true
	fi

	# Set names of tools we're going to use.  try to guess them
	# for common scenarios.  Since a native (wrt to the host)
	# toolchain may not be available in tuple form, treat that
	# as a special case.
	#
	# Note: most of these are not required for rump kernels.
	# See below for that list.   However, we still handle the
	# tools here for the benefit of people wanting to use
	# buildrump.sh as the basis of a cross toolchain for further
	# rump kernel development and integration (see rumprun for
	# an example of this)
	for x in AR AS CPP LD NM OBJCOPY OBJDUMP RANLIB READELF \
	    SIZE STRINGS STRIP; do
		settool ${x} ${crosstools}
	done

	# check that we are in posesssion of the
	# mandatory tools for building rump kernels
	for tool in AR NM OBJCOPY; do
		eval t=\${${tool}:-}
		type ${t} > /dev/null || die cannot find \$${tool} "(${t})"
	done

	case ${CC_TARGET} in
	*-linux*)
		if [ ${RUMPKERNEL} != "linux" ]; then
			RUMPKERN_UNDEF='-Ulinux -U__linux -U__linux__ -U__gnu_linux__'
		fi
		cppdefines _BIG_ENDIAN \
		    && appendvar RUMPKERN_UNDEF -U_BIG_ENDIAN
		cppdefines _LITTLE_ENDIAN \
		    && appendvar RUMPKERN_UNDEF -U_LITTLE_ENDIAN
		;;
	*-gnu*)
		RUMPKERN_UNDEF='-U__GNU__'
		cppdefines _BIG_ENDIAN \
		    && appendvar RUMPKERN_UNDEF -U_BIG_ENDIAN
		cppdefines _LITTLE_ENDIAN \
		    && appendvar RUMPKERN_UNDEF -U_LITTLE_ENDIAN
		;;
	*-dragonflybsd)
		RUMPKERN_UNDEF='-U__DragonFly__'
		;;
	*-openbsd*)
		RUMPKERN_UNDEF='-U__OpenBSD__'
		appendvar EXTRA_CWARNFLAGS -Wno-format
		;;
	*-freebsd*)
		RUMPKERN_UNDEF='-U__FreeBSD__'
		;;
	*-sun-solaris*|*-pc-solaris*)
		RUMPKERN_UNDEF='-U__sun__ -U__sun -Usun'
		;;
	esac

	if ! cppdefines __ELF__; then
		${TITANMODE} || die ELF required as target object format
	fi

	if cppdefines __LP64__; then
		THIRTYTWO=false
	else
		THIRTYTWO=true
	fi

	# At least gcc on Ubuntu wants to set -D_FORTIFY_SOURCE=2
	# when compiling with -O2 ...  While we have nothing against
	# ssp, we don't want things to conflict with what the NetBSD
	# build imagines is going on.  Therefore, force-disable that
	# helpful default flag.
	if cppdefines _FORTIFY_SOURCE -O2; then
		appendvar EXTRA_CFLAGS -U_FORTIFY_SOURCE
	fi

	# The compiler cannot do %zd/u warnings if the NetBSD kernel
	# uses the different flavor of size_t (int vs. long) than what
	# the compiler was built with.  Probing is not entirely easy
	# since we need to testbuild kernel code, not host code,
	# and we're only setting up the build now.  So we just
	# disable format warnings on all 32bit targets.
	${THIRTYTWO} && appendvar EXTRA_CWARNFLAGS -Wno-format

	# Check if cpp supports __COUNTER__.  If not, override CTASSERT
	# to avoid line number conflicts
	doesitbuild 'int a = __COUNTER__;\n' -c
	[ $? -eq 0 ] || CTASSERT="-D'CTASSERT(x)='"

	# linker supports --warn-shared-textrel
	doesitbuild 'int main(void) {return 0;}' -Wl,--warn-shared-textrel
	[ $? -ne 0 ] && SHLIB_WARNTEXTREL=no
}

# Figure out what we need for the target platform
evalplatform ()
{

	case ${CC_TARGET} in
	*-netbsd*)
		RUMP_VIRTIF=yes
		HIJACK=true
		NEED_LDSCRIPT=true
		;;
	*-dragonflybsd)
		RUMP_VIRTIF=yes
		;;
	*-linux*)
		EXTRA_RUMPCOMMON='-ldl'
		EXTRA_RUMPCLIENT='-lpthread'
		doesitbuild '#include <linux/if_tun.h>' -c && RUMP_VIRTIF=yes
		cppdefines '__ANDROID__' || HIJACK=true
		;;
	*-gnu*)
		EXTRA_RUMPCOMMON='-ldl'
		EXTRA_RUMPCLIENT='-lpthread'
		appendvar EXTRA_CFLAGS -DMAXHOSTNAMELEN=256 -DPATH_MAX=1024
		;;
	*-openbsd*)
		EXTRA_RUMPCLIENT='-lpthread'
		;;
	*-freebsd*)
		EXTRA_RUMPCLIENT='-lpthread'
		;;
	*-sun-solaris*|*-pc-solaris*)
		EXTRA_RUMPCOMMON='-lsocket -ldl -lnsl'
		# I haven't managed to get static libs to work on Solaris,
		# so just be happy with shared ones
		MKSTATICLIB=no
		SYS_SUNOS=true
		;;
	*-pc-cygwin)
		MKPIC=no
		target_supported=false
		;;
	*-apple-darwin*)
		diagout Mach-O object format used by OS X is not yet supported
		target_supported=false
		;;
	*)
		target_supported=false
		;;
	esac

	if ! ${target_supported:-true}; then
		${TITANMODE} || die unsupported target: ${CC_TARGET}
	fi

	# does target support __thread.  if yes, optimize curlwp
	doesitbuild '__thread int lanka; int main(void) {return lanka;}\n'
	[ $? -eq 0 ] && RUMP_CURLWP=__thread
}

# ARM targets require a few extra checks
probearm ()
{

	# NetBSD/evbarm is softfloat by default, but force the NetBSD
	# build to use hardfloat if the compiler defaults to VFP.
	# This is because the softfloat env is not always functional
	# in case hardfloat is the compiler default.
	if cppdefines __VFP_FP__; then
		hf=hf
	else
		hf=
	fi

	# check for big endian
	if cppdefines '__ARMEL__'; then
		MACHINE="evbearm${hf}-el"
		MACHINE_GNU_ARCH="arm"
	else
		MACHINE="evbearm${hf}-eb"
		MACHINE_GNU_ARCH="armeb"
	fi

	TOOLABI="elf-eabi${hf}"
}

probecxx ()
{

	# require a C++11 compiler
	if ! doesitcxx 'int i;' -c -std=c++11 ; then
		HAVECXX=false
		return
	fi

	# if cxx doesn't support -cxx-isystem, map it to -isystem
	if ! doesitcxx 'int i;' -c -cxx-isystem /; then
		appendvar_fs CCWRAPPER_MANGLE : '-cxx-isystem -isystem'
	fi
}

# aarch64 requires a few checks
probeaarch64 ()
{

	# check for big endian
	if cppdefines '__AARCH64EL__'; then
		MACHINE="evbarm64-el"
		MACHINE_GNU_ARCH="aarch64"
	else
		MACHINE="evbarm64-eb"
		MACHINE_GNU_ARCH="aarch64_be"
	fi

	TOOLABI=""

	# the NetBSD aarch64 port uses long long for int64_t
	appendvar EXTRA_CWARNFLAGS -Wno-format
}

# MIPS requires a few extra checks
probemips ()
{

	# set env vars that NetBSD expects for the different MIPS ABIs
	if cppdefines '_ABIO32'; then
		appendvar EXTRA_CFLAGS -D__mips_o32
		appendvar EXTRA_AFLAGS -D__mips_o32
	elif cppdefines '_ABIN32'; then
		appendvar EXTRA_CFLAGS -D__mips_n32
		appendvar EXTRA_AFLAGS -D__mips_n32
		${TITANMODE} || die MIPS n32 ABI not yet working, use -mabi=32
	elif cppdefines '_ABI64'; then
		appendvar EXTRA_CFLAGS -D__mips_n64
		appendvar EXTRA_AFLAGS -D__mips_n64
	else die unknown MIPS ABI
	fi

	# NetBSD/evbmips is softfloat by default
	# but we can detect if this is correct
	if cppdefines '__mips_hard_float'; then
		MKSOFTFLOAT=no
	fi

	# MIPS builds need to be position independent;
	# NetBSD hosts do this anyway but others may need forcing
	appendvar EXTRA_CFLAGS -fPIC
	appendvar EXTRA_AFLAGS -fPIC
}

probex86 ()
{

	# we probably should unconditionally wipe out -mno-avx for userspace ...
	doesitbuild 'int i;' -c -mno-avx \
	    || appendvar_fs CCWRAPPER_MANGLE : '-mno-avx'
}

evalmachine ()
{

	TOOLABI=''
	case ${MACHINE_GNU_ARCH} in
	"amd64"|"x86_64")
		probex86
		if ${THIRTYTWO} ; then
			MACHINE="i386"
			MACHINE_GNU_ARCH="i486"
			TOOLABI="elf"
		else
			MACHINE="amd64"
			MACHINE_GNU_ARCH="x86_64"
		fi
		;;
	"i386"|"i486"|"i586"|"i686")
		probex86
		MACHINE="i386"
		MACHINE_GNU_ARCH="i486"
		TOOLABI="elf"
		;;
	arm*)
		probearm
		;;
	aarch64*)
		probeaarch64
		;;
	"sparc"|"sparc64")
		if ${THIRTYTWO} ; then
			MACHINE="sparc"
			MACHINE_GNU_ARCH="sparc"
			TOOLABI="elf"
		else
			MACHINE="sparc64"
			MACHINE_GNU_ARCH="sparc64"
		fi
		;;
	"mipsel"|"mips64el")
		if ${THIRTYTWO} ; then
			MACHINE="evbmips-el"
			MACHINE_GNU_ARCH="mipsel"
		else
			MACHINE="evbmips64-el"
			MACHINE_GNU_ARCH="mips64el"
		fi
		probemips
		;;
	"mips"|"mipseb"|"mips64"|"mips64eb")
		if ${THIRTYTWO} ; then
			MACHINE="evbmips-eb"
			MACHINE_GNU_ARCH="mipseb"
		else
			MACHINE="evbmips64-eb"
			MACHINE_GNU_ARCH="mips64"
		fi
		probemips
		;;
	"powerpc"|"ppc64"|"powerpc64"|"powerpc64le")
		if ${THIRTYTWO} ; then
			MACHINE="evbppc"
			MACHINE_GNU_ARCH="powerpc"
		else
			MACHINE="evbppc64"
			MACHINE_GNU_ARCH="powerpc64"
			appendvar EXTRA_CWARNFLAGS -Wno-format
		fi
		;;
	"alpha")
		MACHINE="alpha"
		MACHINE_GNU_ARCH="alpha"
		;;
	"riscv"|"riscv64")
		if ${THIRTYTWO} ; then
			MACHINE="riscv"
			MACHINE_GNU_ARCH="riscv32"
		else
			MACHINE="riscv"
			MACHINE_GNU_ARCH="riscv64"
			appendvar EXTRA_CWARNFLAGS -Wno-format
		fi
		;;
	esac
	[ -z "${MACHINE}" ] \
	    && die script does not know machine \"${MACHINE_GNU_ARCH}\"
}

parseargs ()
{

	DBG='-O2 -g'
	TITANMODE=false
	NOISE=2
	debugginess=0
	KERNONLY=false
	RUMPKERNEL=netbsd
	OBJDIR=./obj
	DESTDIR=./rump
	SRCDIR=./src
	LKL_SRCDIR=./linux
	JNUM=4

	while getopts 'd:DhHj:kl:o:qrs:T:V:F:' opt; do
		case "$opt" in
		d)
			DESTDIR=${OPTARG}
			;;
		D)
			[ ! -z "${RUMP_DIAGNOSTIC:-}" ] \
			    && die Cannot specify releasy debug

			debugginess=$((debugginess+1))
			# use -O1 as the minimal supported compiler
			# optimization level.  -O0 is just too broken
			# for too many compilers and platforms
			[ ${debugginess} -gt 0 ] && DBG='-O1 -g'
			[ ${debugginess} -gt 1 ] && RUMP_DEBUG=1
			[ ${debugginess} -gt 2 ] && RUMP_LOCKDEBUG=1
			;;
		F)
			ARG=${OPTARG#*=}
			case ${OPTARG} in
				CFLAGS\=*)
					appendvar EXTRA_CFLAGS "${ARG}"
					;;
				AFLAGS\=*)
					appendvar EXTRA_AFLAGS "${ARG}"
					;;
				LDFLAGS\=*)
					appendvar EXTRA_LDFLAGS "${ARG}"
					;;
				ACFLAGS\=*)
					appendvar EXTRA_CFLAGS "${ARG}"
					appendvar EXTRA_AFLAGS "${ARG}"
					;;
				ACLFLAGS\=*)
					appendvar EXTRA_CFLAGS "${ARG}"
					appendvar EXTRA_AFLAGS "${ARG}"
					appendvar EXTRA_LDFLAGS "${ARG}"
					;;
				CPPFLAGS\=*)
					appendvar EXTRA_CPPFLAGS "${ARG}"
					;;
				DBG\=*)
					appendvar F_DBG "${ARG}"
					;;
				CWARNFLAGS\=*)
					appendvar EXTRA_CWARNFLAGS "${ARG}"
					;;
				*)
					die Unknown flag: ${OPTARG}
					;;
			esac
			;;
		H)
			TITANMODE=true
			;;
		j)
			JNUM=${OPTARG}
			;;
		k)
			KERNONLY=true
			;;
		l)
			RUMPKERNEL=${OPTARG}
			;;
		o)
			OBJDIR=${OPTARG}
			;;
		q)
			# build.sh handles value going negative
			NOISE=$((NOISE-1))
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
			appendvar BUILDSH_VARGS -V ${OPTARG}
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

	# load rump kernel specific scripts
	if [ ${RUMPKERNEL} != "netbsd" -a ${RUMPKERNEL} != "linux" ]; then
	    echo '>> ERROR:'
	    echo '>> -l option (RUMPKERNEL) must be netbsd or linux'
	    exit 1
	fi
	. ${BRDIR}/${RUMPKERNEL}.sh

	DBG="${F_DBG:-${DBG}}"

	BEQUIET="-N${NOISE}"
	[ -z "${BRTOOLDIR:-}" ] && BRTOOLDIR=${OBJDIR}/tooldir

	#
	# Determine what which parts we should execute.
	#
	allcmds='checkout checkoutcvs checkoutgit probe tools build install
	    tests fullbuild kernelheaders'
	fullbuildcmds="tools build install"

	# for compat, so that previously valid invocations don't
	# produce an error
	allcmds="${allcmds} setupdest"

	for cmd in ${allcmds}; do
		eval do${cmd}=false
	done
	ncmds=0
	if [ $# -ne 0 ]; then
		for arg in $*; do
			while true ; do
				for cmd in ${allcmds}; do
					if [ "${arg}" = "${cmd}" ]; then
						eval do${cmd}=true
						ncmds=$((${ncmds}+1))
						break 2
					fi
				done
				die "Invalid arg $arg"
			done
		done
	else
		[ -z "${TARBALLMODE}" ] && docheckoutgit=true
		dofullbuild=true
		dotests=true
	fi
	if ${dofullbuild} ; then
		for cmd in ${fullbuildcmds}; do
			eval do${cmd}=true
		done
	fi

	if ${doprobe}; then
		[ ${ncmds} -ne 1 ] && die probe works alone
		DIAGOUT=:
	fi

	if ${docheckout} || ${docheckoutgit} ; then
		docheckout=true
		checkoutstyle=git
	fi
	if ${docheckoutcvs} ; then
		docheckout=true
		checkoutstyle=cvs
	fi
	if ${docheckout} && [ ${RUMPKERNEL} = "linux" ] ; then
		docheckout=true
		checkoutstyle=linux-git
	fi

	# sanity checks
	if [ ! -z "${TARBALLMODE}" ]; then
		${docheckout} && \
		    die 'Checkout not possible in tarball mode, fetch repo'
		[ -d "${SRCDIR}" ] || die 'Sources not found from tarball'
	fi
}

abspath ()
{

	curdir=`pwd -P`
	eval cd \${${1}}
	[ $? -ne 0 ] && die Failed to resolve path "${1}"
	eval ${1}=`pwd -P`
	cd ${curdir}
}

resolvepaths ()
{

	# check if we're running from a tarball, i.e. is checkout possible
	if [ ! -f "${BRDIR}/checkout.sh" -a -f "${BRDIR}/tarup-gitdate" ]; then
		TARBALLMODE='Run from tarball'
	fi

	# resolve critical directories
	abspath BRDIR

	mkdir -p ${BRTOOLDIR} || die "cannot create ${BRTOOLDIR} (tooldir)"

	abspath BRTOOLDIR
	abspath SRCDIR
	[ "${RUMPKERNEL}" = "linux" ] && abspath LKL_SRCDIR

	RUMPMAKE="${BRTOOLDIR}/bin/brrumpmake"
	BRIMACROS="${BRTOOLDIR}/include/opt_buildrump.h"

	mkdir -p ${OBJDIR} || die cannot create ${OBJDIR}
	abspath OBJDIR

	mkdir -p ${DESTDIR} || die cannot create ${DESTDIR}
	abspath DESTDIR

	# Create bounce directory used as the install target.  The
	# purpose of this is to strip the "usr/" pathname component
	# that is hardcoded by NetBSD Makefiles.
	mkdir -p ${BRTOOLDIR}/dest || die "cannot create ${BRTOOLDIR}/dest"
	rm -f ${BRTOOLDIR}/dest/usr
	ln -s ${DESTDIR} ${BRTOOLDIR}/dest/usr

	# mini-mtree
	dstage=${OBJDIR}/dest.stage/usr
	for dir in ${dstage}/bin ${dstage}/include/rump ${dstage}/lib; do
		mkdir -p ${dir} || die "Cannot create ${dir}"
	done
	for man in cat man ; do
		for x in 1 2 3 4 5 6 7 8 9 ; do
			mkdir -p ${dstage}/share/man/${man}${x} \
			    || die create ${dstage}/share/man/${man}${x}
		done
	done
}



###
###
### BEGIN SCRIPT
###
###

BRDIR=$(dirname $0)
. ${BRDIR}/subr.sh

# check that env is clean
for var in CFLAGS AFLAGS LDFLAGS; do
	[ -n "$(eval echo \${${var}:-})" ] \
	    && die unset \"${var}\" from environment, use -F instead
done

parseargs "$@"

${docheckout} && { ${BRDIR}/checkout.sh ${checkoutstyle} ${SRCDIR} ${LKL_SRCDIR} || exit 1; }

if ${doprobe} || ${dotools} || ${dobuild} || ${dokernelheaders} \
    || ${doinstall} || ${dotests}; then
	${doprobe} || resolvepaths

	evaltoolchain
	evalmachine

	${KERNONLY} || evalplatform

	export RUMPKERNEL
	${doprobe} && writeproberes
	${dotools} && maketools
	${dobuild} && makebuild
	${dokernelheaders} && makekernelheaders
	${doinstall} && makeinstall

	${dotests} && maketests
fi

diagout buildrump.sh ran successfully
exit 0

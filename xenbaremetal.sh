#!/bin/sh

# build script for bare metal and Xen.  Obeys the following
# env variables:
#
#	BUILDXENMETAL_MKCONF:	extra contents for mk.conf
#	BUILDXENMETAL_PCI_P:	predicate for building PCI drivers
#	BUILDXENMETAL_PCI_ARGS:	extra build args to PCI build
#

STDJ='-j4'
: ${RUMPSRC=./rumpsrc}
: ${BUILDRUMP:=./buildrump.sh}

while getopts '?qs:' opt; do
	case "$opt" in
	's')
		RUMPSRC=${OPTARG}
		;;
	'q')
		BUILD_QUIET=${BUILD_QUIET:=-}q
		;;
	'?')
		exit 1
	esac
done
shift $((${OPTIND} - 1))

# the buildxen.sh is not as forgiving as I am
set -e

. ${BUILDRUMP}/subr.sh

if git submodule status ${RUMPSRC} | grep -q '^-' ; then
	git submodule update --init --recursive ${RUMPSRC}
fi
[ "$1" = "justcheckout" ] && { echo ">> $0 done" ; exit 0; }

# build tools
${BUILDRUMP}/buildrump.sh ${BUILD_QUIET} ${STDJ} -k \
    -V MKPIC=no -s ${RUMPSRC} -T rumptools -o rumpobj -N \
    -V RUMP_KERNEL_IS_LIBC=1 -V BUILDRUMP_SYSROOT=yes "$@" tools

[ -n "${BUILDXENMETAL_MKCONF}" ] \
    && echo "${BUILDXENMETAL_MKCONF}" >> rumptools/mk.conf

RUMPMAKE=$(pwd)/rumptools/rumpmake
MACHINE=$(${RUMPMAKE} -f /dev/null -V '${MACHINE}')
[ -z "${MACHINE}" ] && die could not figure out target machine

# build rump kernel
${BUILDRUMP}/buildrump.sh ${BUILD_QUIET} ${STDJ} -k \
    -V MKPIC=no -s ${RUMPSRC} -T rumptools -o rumpobj -N \
    -V RUMP_KERNEL_IS_LIBC=1 -V BUILDRUMP_SYSROOT=yes "$@" \
    build kernelheaders install

LIBS="$(stdlibs ${RUMPSRC})"
if [ "$(${RUMPMAKE} -f rumptools/mk.conf -V '${_BUILDRUMP_CXX}')" = 'yes' ]
then
	LIBS="${LIBS} $(stdlibsxx ${RUMPSRC})"
fi

usermtree rump
userincludes ${RUMPSRC} ${LIBS}

for lib in ${LIBS}; do
	makeuserlib ${lib}
done

eval ${BUILDXENMETAL_PCI_P} && makepci ${RUMPSRC} ${BUILDXENMETAL_PCI_ARGS}
exit 0

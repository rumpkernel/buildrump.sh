#!/bin/sh
#
# This script will build rump kernel components and the hypervisor
# on a non-NetBSD host and hopefully leave you with a usable installation.
# This is a very preliminary version, much of the stuff is currently
# hardcoded etc.
#
# requires -current [at least] as of 20121114
#

# the bass
die ()
{

	echo $* >&2
	exit 1
}

uname2machine ()
{

	case $1 in
	"x86_64")
		rv="amd64"
		;;
	default)
		rv=${1}
	esac

	echo ${rv}
}

# use same machine as host.
#
# XXX: differences in uname output?
MACH=`uname -m`

MYTOOLDIR=rump/tools

#
# create links to an external toolchain in the format that
# build.sh expects.
#
# TODO?: don't hardcore this based on PATH
#
TOOLS='gcc cpp ar as ld nm objcopy objdump ranlib size strip'
maketoolchain ()
{

	mkdir -p ${MYTOOLDIR}/bin || die "cannot create ${MYTOOLDIR}"
	for x in ${TOOLS}; do
		tool=`which ${x}`
		[ $? -ne 0 ] && die "could not find ${x}"

		# ok, it's not really --netbsd, but let's make-believe!
		ln -sf ${tool} ${MYTOOLDIR}/bin/${MACH}--netbsd-${x}
	done
}


maketoolchain

export EXTERNAL_TOOLCHAIN="`pwd`/${MYTOOLDIR}"
export TOOLCHAIN_MISSING=yes

cat > "${MYTOOLDIR}/mk.conf" << EOF
CFLAGS+=-Wno-unused-but-set-variable
CPPFLAGS+=-I`pwd`/rump/usr/include
LIBDO.pthread=_external
EOF

machine=`uname2machine ${MACH}`
./build.sh -m ${machine} -j16 -U -u -D rump -T rump/tools \
    -V MKGROFF=no \
    -V EXTERNAL_TOOLCHAIN=${EXTERNAL_TOOLCHAIN} \
    -V NOPROFILE=1 \
    -V NOLINT=1 \
    -V USE_SSP=no \
    -V MAKECONF="`pwd`/${MYTOOLDIR}/mk.conf" \
    tools

RUMPTOOLS="`pwd`/rump/tools"
RUMPMAKE="${RUMPTOOLS}/bin/nbmake-${machine}"

cd etc
${RUMPMAKE} distrib-dirs || die "distrib-dirs"

cd ../sys/rump
${RUMPMAKE} obj || die "sys/rump obj"
${RUMPMAKE} dependall || die "sys/rump dependall"
${RUMPMAKE} install || die "sys/rump install"

cd include
${RUMPMAKE} includes || die "sys/rump/includes includes"

cd ../../../lib/librumpuser
${RUMPMAKE} includes || die "lib/librumpuser includes"
${RUMPMAKE} dependall || die "lib/librumpuser dependall"
${RUMPMAKE} install || die "lib/librumpuser install"

#
# aaaand perform a very simple test
#
cd ../../rump
cat > test.c << EOF
#include <sys/types.h>
#include <inttypes.h>
#include <rump/rump.h>

int
main()
{

        rump_init();
}
EOF

cc test.c -Iusr/include -lrump  -lrumpuser -ldl -Lusr/lib -Wl,-Rusr/lib
RUMP_VERBOSE=1 ./a.out

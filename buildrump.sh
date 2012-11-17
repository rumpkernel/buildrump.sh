#!/bin/sh
#
# This script will build rump kernel components and the hypervisor
# on a non-NetBSD host and hopefully leave you with a usable installation.
# This is a very preliminary version, much of the stuff is currently
# hardcoded etc.
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
	"i686")
		rv="i386"
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
		# ok, it's not really --netbsd, but let's make-believe!
		tname=${MYTOOLDIR}/bin/${MACH}--netbsd-${x}
		[ -f ${tname} ] && continue

		printf '#!/bin/sh\nexec %s $*\n' ${x} > ${tname}
		chmod 755 ${tname}
	done
}

[ ! -f build.sh ] && die script must be run from the top level nbsrc dir
srcdir=`pwd`

maketoolchain

export EXTERNAL_TOOLCHAIN="`pwd`/${MYTOOLDIR}"
export TOOLCHAIN_MISSING=yes

cat > "${MYTOOLDIR}/mk.conf" << EOF
CFLAGS+=-Wno-unused-but-set-variable
CPPFLAGS+=-I`pwd`/rump/usr/include
LIBDO.pthread=_external
EOF

machine=`uname2machine ${MACH}`
./build.sh -m ${machine} -j16 -U -u -D rump -O obj -T rump/tools \
    -V MKGROFF=no \
    -V EXTERNAL_TOOLCHAIN=${EXTERNAL_TOOLCHAIN} \
    -V NOPROFILE=1 \
    -V NOLINT=1 \
    -V USE_SSP=no \
    -V MAKECONF="`pwd`/${MYTOOLDIR}/mk.conf" \
    tools

RUMPTOOLS="`pwd`/rump/tools"
RUMPMAKE="${RUMPTOOLS}/bin/nbmake-${machine}"

domake ()
{

	cd ${1}
	if [ -z "${2}" ] ; then
		${RUMPMAKE} -j8 obj || die "make $1 obj"
		${RUMPMAKE} -j8 dependall || die "make $1 dependall"
		${RUMPMAKE} -j8 install || die "make $1 install"
	else
		${RUMPMAKE} -j8 $2 || die "make $1 $2"
	fi
	cd ${srcdir}
}

domake etc distrib-dirs

domake sys/rump/include includes
domake sys/rump
[ "`uname`" = "Linux" ] && domake sys/rump/kern/lib/libsys_linux

domake lib/librumpuser includes
domake lib/librumpuser

# DONE
echo
echo done building.  bootstrapping a simple rump kernel for testing purposes.
echo


#
# aaaand perform a very simple test
#
cd rump
cat > test.c << EOF
#include <sys/types.h>
#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>
#include <rump/rump.h>
#include <rump/rump_syscalls.h>

static void
die(const char *reason)
{

	fprintf(stderr, "%s\n", reason);
	exit(1);
}

int
main()
{
	char buf[8192];
	int fd;

	setenv("RUMP_VERBOSE", "1", 1);
        rump_init();
	if (rump_sys_mkdir("/kern", 0755) == -1)
		die("mkdir /kern");
	if (rump_sys_mount("kernfs", "/kern", 0, NULL, 0) == -1)
		die("mount kernfs");
	if ((fd = rump_sys_open("/kern/version", 0)) == -1)
		die("open /kern/version");
	if (rump_sys_read(fd, buf, sizeof(buf)) <= 0)
		die("read version");
	printf("\nReading version info from /kern:\n\n%s", buf);
}
EOF

cc test.c -Iusr/include -Wl,--no-as-needed -lrumpfs_kernfs -lrumpvfs -lrump  -lrumpuser -ldl -Lusr/lib -Wl,-Rusr/lib
RUMP_VERBOSE=1 ./a.out

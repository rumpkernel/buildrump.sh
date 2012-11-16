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
		# ok, it's not really --netbsd, but let's make-believe!
		tname=${MYTOOLDIR}/bin/${MACH}--netbsd-${x}
		[ -f ${tname} ] && continue

		printf '#!/bin/sh\nexec %s $*\n' ${x} > ${tname}
		chmod 755 ${tname}
	done
}


maketoolchain

# set the path to the real compiler
workaround_ccache ()
{
	CCACHE_CC="failed" 
	REALCC="$(LANG=C gcc -v 2>&1  |grep Target|cut -f2 -d:|sed -e 's/^ //g')-gcc"
	for directory_in_path in $(echo $PATH|sed -e 's/:/\n/g'); 
		do [ -f ${directory_in_path}/${REALCC} ] && \
			[  $(basename $(readlink -f ${directory_in_path}/${REALCC})) != 'ccache' ] && \
				 export CCACHE_CC="${directory_in_path}/${REALCC}" && echo "ccache detected: $CCACHE_CC is the real compiler" && \
		break; done
	[ $CCACHE_CC == "failed" ] && die "ccache detected but we failed to find the real compiler"

}

# detect if we are using ccache so we can fix the env
current_gcc_real_name=$(basename $(readlink -f `which gcc`))
[ $current_gcc_real_name == "ccache" ] && workaround_ccache


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
	printf("\nRead version info from /kern:\n\n%s", buf);
}
EOF

cc test.c -Iusr/include -Wl,--no-as-needed -lrumpfs_kernfs -lrumpvfs -lrump  -lrumpuser -ldl -Lusr/lib -Wl,-Rusr/lib
RUMP_VERBOSE=1 ./a.out

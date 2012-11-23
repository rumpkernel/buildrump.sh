#! /usr/bin/env sh
#
# This script will build rump kernel components and the hypervisor
# on a non-NetBSD host and hopefully leave you with a usable installation.
# This is a very preliminary version, much of the stuff is currently
# hardcoded etc.
#

OBJDIR=`pwd`/obj
DESTDIR=${OBJDIR}/rump
MYTOOLDIR=${DESTDIR}/tools
SRCDIR=${NETBSDSRCDIR:-`pwd`}

# the bass
die ()
{

	echo $* >&2
	exit 1
}

[ ! -f "${SRCDIR}/build.sh" ] && die script must be run from the top level nbsrc dir or \$NETBSDSRCDIR should be set

hostos=`uname -s`
binsh=sh
case ${hostos} in
"FreeBSD")
	RUMPKERN_UNDEF='-U__FreeBSD__'
	;;
"Linux")
	RUMPKERN_UNDEF='-Ulinux -U__linux -U__linux__ -U__gnu_linux__'
	EXTRA_RUMPUSER='-ldl'
	;;
"SunOS")
	RUMPKERN_UNDEF='-U__sun__ -U__sun -Usun'
	EXTRA_RUMPUSER='-lsocket -lrt -ldl'
	binsh=/usr/xpg4/bin/sh

	# do some random test to check for gnu foolchain
	if ! ar --version 2>/dev/null | grep -q 'GNU ar' ; then
		die Need GNU toolchain in PATH, `which ar` is not
	fi
	;;
*)
	die unsupported host OS: ${hostos}
	;;
esac

mach_arch=`uname -m`
case ${mach_arch} in
"amd64")
	machine="amd64"
	mach_arch="x86_64"
	;;
"x86_64")
	machine="amd64"
	;;
"i686")
	machine="i386"
	;;
"sun4v")
	machine="sparc64"
	mach_arch="sparc64"
	# assume gcc.  i'm not going to start trying to
	# remember what the magic incantation for sunpro was
	EXTRA_CFLAGS='-m64'
	EXTRA_LDFLAGS='-m64'
	EXTRA_AFLAGS='-m64'
	;;
esac

#
# create links to an external toolchain in the format that
# build.sh expects.
#
# TODO?: don't hardcore this based on PATH
# TODO2: cpp missing
# XXX: why can't all cc's that are gcc actually tell me
#      that they're gcc with cc --version?!?
#
TOOLS='ar as ld nm objcopy objdump ranlib size strip'
if cc --version | grep -q 'Free Software Foundation'; then
	CC=gcc
elif cc --version | grep -q clang; then
	CC=clang
	LLVM='-V HAVE_LLVM=1'
else
	die Unsupported cc "(`which cc`)"
fi

#
# Try to test if cc supports -Wno-unused-but-set-variable.
# This is a bit tricky since apparently gcc doesn't tell it
# doesn't support it unless there is some other error to complain
# about as well.  So we try compiling a broken source file...
mkdir -p $OBJDIR || die cannot create obj
cd $OBJDIR
echo 'no you_shall_not_compile' > broken.c
${CC} -Wno-unused-but-set-variable broken.c > broken.out 2>&1
if ! grep -q Wno-unused-but-set-variable broken.out ; then
	W_UNUSED_BUT_SET=-Wno-unused-but-set-variable
fi
rm -f broken.c broken.out
cd ${SRCDIR}

mkdir -p ${MYTOOLDIR}/bin || die "cannot create ${MYTOOLDIR}"
for x in ${CC} ${TOOLS}; do
	# ok, it's not really --netbsd, but let's make-believe!
	tname=${MYTOOLDIR}/bin/${mach_arch}--netbsd-${x}
	[ -f ${tname} ] && continue

	printf '#!/bin/sh\nexec %s $*\n' ${x} > ${tname}
	chmod 755 ${tname}
done

export EXTERNAL_TOOLCHAIN="${MYTOOLDIR}"
export TOOLCHAIN_MISSING=yes

cat > "${MYTOOLDIR}/mk.conf" << EOF
CPPFLAGS+=-I$DESTDIR/usr/include
LIBDO.pthread=_external
RUMPKERN_UNDEF=${RUMPKERN_UNDEF}
EOF
appendmkconf () {
	[ ! -z "${1}" ] && echo "${2}+=${1}" >> "${MYTOOLDIR}/mk.conf"
}
appendmkconf "${W_UNUSED_BUT_SET}" "CFLAGS"
appendmkconf "${EXTRA_CFLAGS}" "CFLAGS"
appendmkconf "${EXTRA_LDFLAGS}" "LDFLAGS"
appendmkconf "${EXTRA_AFLAGS}" "AFLAGS"

tst=`cc --print-file-name=crtbeginS.o`
[ -z "${tst%crtbeginS.o}" ] && echo '_GCC_CRTBEGINS=' >> "${MYTOOLDIR}/mk.conf"
tst=`cc --print-file-name=crtendS.o`
[ -z "${tst%crtendS.o}" ] && echo '_GCC_CRTENDS=' >> "${MYTOOLDIR}/mk.conf"

${binsh} build.sh -m ${machine} -j16 -U -u -D ${DESTDIR} -O ${OBJDIR} -T ${MYTOOLDIR} \
    ${LLVM} \
    -V MKGROFF=no \
    -V EXTERNAL_TOOLCHAIN=${EXTERNAL_TOOLCHAIN} \
    -V NOPROFILE=1 \
    -V NOLINT=1 \
    -V USE_SSP=no \
    -V MAKECONF="${MYTOOLDIR}/mk.conf" \
    tools

RUMPTOOLS="${MYTOOLDIR}"
RUMPMAKE="${RUMPTOOLS}/bin/nbmake-${machine}"

domake ()
{

	cd ${1}
	${RUMPMAKE} -j8 obj || die "make $1 obj"
	if [ -z "${2}" ] ; then
		${RUMPMAKE} -j8 dependall || die "make $1 dependall"
		${RUMPMAKE} -j8 install || die "make $1 install"
	else
		${RUMPMAKE} -j8 $2 || die "make $1 $2"
	fi
	cd ${SRCDIR}
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
cd ${DESTDIR}
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

# should do this properly
${CC} test.c -Iusr/include -Wl,--no-as-needed -lrumpfs_kernfs -lrumpvfs -lrump  -lrumpuser ${EXTRA_CFLAGS} ${EXTRA_RUMPUSER} -Lusr/lib -Wl,-Rusr/lib
./a.out

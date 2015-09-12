# Subroutines required by packages which build on top of buildrump.sh
#
# WARNING!  These interfaces are not guaranteed to be stable.  If you
# want to depend on their continued semantics, copypaste.
#

# the parrot routine
die ()
{

	echo '>> ERROR:' >&2
	echo ">> $*" >&2
	exit 1
}

_checkrumpmake ()
{

	[ -n "${RUMPMAKE}" ] || die 'routine requires $RUMPMAKE to be set'
	[ -e "${RUMPMAKE}" ] || die ${RUMPMAKE} is not an executable
}

# adhoc "mtree" required for installaling a subset of userspace
# headers and libraries.  maybe we can migrate to a proper use of
# NetBSD's mtree at some point?
#
# XXX: hardcoded base paths
usermtree ()
{

	destbase=$1

	INCSDIRS='adosfs altq arpa c++ c++/experimental c++/ext crypto
	    dev filecorefs fs i386 isofs miscfs
	    msdosfs net net80211 netatalk netbt netinet netinet6 netipsec
	    netisdn netkey netmpls netnatm netsmb nfs ntfs openssl pcap
	    ppath prop protocols rpc rpcsvc rumprun ssp sys ufs uvm x86'
	for dir in ${INCSDIRS}; do
		mkdir -p ${destbase}/include/$dir
	done
	mkdir -p ${destbase}/lib/pkgconfig
}

# echo names of normal libs (including optional prefix)
stdlibs ()
{

	prefix=${1:+${1}/}
	liblibs='libc libcrypt libipsec libkvm libm libnpf libpci libprop
	    libpthread librmt libutil liby libz'
	extralibs='external/bsd/flex/lib
	    crypto/external/bsd/openssl/lib/libcrypto
	    crypto/external/bsd/openssl/lib/libdes
	    crypto/external/bsd/openssl/lib/libssl
	    external/bsd/libpcap/lib'
	for lib in ${liblibs}; do
		echo ${prefix}lib/${lib}
	done
	for lib in ${extralibs}; do
		echo ${prefix}${lib}
	done
}

stdlibsxx ()
{
	prefix=${1:+${1}/}
	echo ${prefix}external/bsd/libc++
}

makeuserlib ()
{

	_checkrumpmake

	lib=$1
	objarg=${2:+MAKEOBJDIR=${2}}

	( cd ${lib}
		${RUMPMAKE} ${objarg} obj
		${RUMPMAKE} MKMAN=no MKLINT=no MKPROFILE=no MKYP=no	\
		    MKNLS=no NOGCCERROR=1 HAVE_LIBGCC_EH=yes		\
		    ${objarg} ${STDJ} dependall
		${RUMPMAKE} MKMAN=no MKLINT=no MKPROFILE=no MKYP=no	\
		    ${objarg} ${STDJ} install
	)
}

userincludes ()
{

	_checkrumpmake

	rumpsrc=$1
	shift

	echo '>> installing userspace headers'
	( cd ${rumpsrc}/include && ${RUMPMAKE} obj && ${RUMPMAKE} includes )
	for lib in $*; do 
		( cd ${lib} && ${RUMPMAKE} obj )
		( cd ${lib} && ${RUMPMAKE} includes )
	done
	echo '>> done installing headers'
}

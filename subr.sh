# Subroutines required by packages which build on top of buildrump.sh
#
# WARNING!  These interfaces are not guaranteed to be stable.  If you
# want to depend on their continued semantics, copypaste.
#

# adhoc "mtree" required for installaling a subset of userspace
# headers and libraries.  maybe we can migrate to a proper use of
# NetBSD's mtree at some point?
#
# XXX: hardcoded base paths
usermtree ()
{

	destbase=$1

	INCSDIRS='adosfs altq arpa crypto dev filecorefs fs i386 isofs miscfs
	    msdosfs net net80211 netatalk netbt netinet netinet6 netipsec
	    netisdn netkey netmpls netnatm netsmb nfs ntfs openssl pcap
	    ppath prop protocols rpc rpcsvc ssp sys ufs uvm x86'
	for dir in ${INCSDIRS}; do
		mkdir -p ${destbase}/include/$dir
	done
	mkdir -p ${destbase}/lib/pkgconfig
}

# echo names of normal libs (including optional prefix)
stdlibs ()
{

	prefix=${1:+${1}/}
	liblibs='libc libcrypt libipsec libm libnpf libpci libprop
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

makeuserlib ()
{

	rumpmake=$1
	lib=$2
	shift; shift

	( cd ${lib}
		${rumpmake} obj
		${rumpmake} MKMAN=no MKLINT=no MKPROFILE=no MKYP=no \
		    NOGCCERROR=1 ${STDJ} "$@" dependall
		${rumpmake} MKMAN=no MKLINT=no MKPROFILE=no MKYP=no "$@" install
	)
}

userincludes ()
{

	rumpmake=$1
	rumpsrc=$2
	shift 2

	echo '>> installing userspace headers'
	( cd ${rumpsrc}/include && ${rumpmake} obj && ${rumpmake} includes )
	for lib in $*; do 
		( cd ${lib} && ${rumpmake} obj )
		( cd ${lib} && ${rumpmake} includes )
	done
	echo '>> done installing headers'
}

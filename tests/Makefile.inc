DBG=	-O2 -g
NOMAN=	should be yesman

LDADD+=		-Wl,--whole-archive ${RUMPLIBS} -Wl,--no-whole-archive
CPPFLAGS+=	-I${.CURDIR}/../common

# link sysproxy if it's a separate component (historic compat)
RUMPTOP=${TOPRUMP}
.include "${RUMPTOP}/kern/Makefile.rumpkerncomp"
RUMPKERN_SYSPROXY= ${RUMPKERNCOMPS:Msysproxy:S/sysproxy/-lrumpkern_sysproxy/}

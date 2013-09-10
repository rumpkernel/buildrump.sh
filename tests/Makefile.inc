DBG=	-O2 -g
NOMAN=	should be yesman

LDADD+=		-Wl,--whole-archive ${RUMPLIBS} -Wl,--no-whole-archive
CPPFLAGS+=	-I${.CURDIR}/../common

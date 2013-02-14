LIB=	rumpnet_config

SRCS=	netconfig.c netconfig_if_wrappers.c

# I wonder when this hack comes back to bite me
INCS=	rump/netconfig.h
INCSDIR=/usr/include

CPPFLAGS+= -I${RUMPTOP}/librump/rumpkern

.include <bsd.lib.mk>
.include <bsd.klinks.mk>

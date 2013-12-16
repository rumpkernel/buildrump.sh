LIB=	rumpnet_config

SRCS=	netconfig.c netconfig_if_wrappers.c

SRCS+=	inet_pton6.c

# DHCP support
SRCS+=	dhcp_bpf.c dhcp_common.c dhcp_configure.c dhcp_dhcp.c	\
	dhcp_if-bsd.c dhcp_main.c dhcp_net.c

# I wonder when this hack comes back to bite me
INCS=	rump/netconfig.h
INCSDIR=/usr/include

CPPFLAGS+= -I${RUMPTOP}/librump/rumpkern -I${.CURDIR}

.include <bsd.lib.mk>
.include <bsd.klinks.mk>

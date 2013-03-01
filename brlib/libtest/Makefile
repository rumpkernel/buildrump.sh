LIB=	rump_justtesting

SRCS=	test.c

CPPFLAGS+= -I${RUMPTOP}/librump/rumpkern

SHLIB_MAJOR=0
SHLIB_MINOR=0

RUMPCOMP_USER= #build rumpcomp_user.c as a hypercall module

.include <bsd.lib.mk>
.include <bsd.klinks.mk>

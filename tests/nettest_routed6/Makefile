.PATH: ${.CURDIR}/../nettest_routed

PROG= nettest_routed6
SRCS= nettest_routed.c

RUMPLIBS= -lrumpnet_shmif -lrumpnet_config -lrumpnet_netinet6 -lrumpnet_net
RUMPLIBS+=-lrumpnet ${RUMPKERN_SYSPROXY} -lrump -lrumpuser

CLEANFILES+= busmem1 busmem2

.include <bsd.prog.mk>

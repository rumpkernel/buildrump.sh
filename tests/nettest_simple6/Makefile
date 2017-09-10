.PATH: ${.CURDIR}/../nettest_simple

PROG= nettest_simple6
SRCS= nettest_simple.c

RUMPLIBS= -lrumpnet_shmif -lrumpnet_config -lrumpnet_netinet6 -lrumpnet_net
RUMPLIBS+=-lrumpnet ${RUMPKERN_SYSPROXY} -lrump -lrumpuser -lrumpdev -lrumpvfs

CLEANFILES+= busmem

.include <bsd.prog.mk>

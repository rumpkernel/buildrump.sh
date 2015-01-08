PROG= nettest_simple

RUMPLIBS= -lrumpnet_shmif -lrumpnet_config -lrumpnet_netinet -lrumpnet_net
RUMPLIBS+=-lrumpnet ${RUMPKERN_SYSPROXY} -lrump -lrumpuser

CLEANFILES+= busmem

.include <bsd.prog.mk>

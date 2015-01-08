PROG= nettest_routed

RUMPLIBS= -lrumpnet_shmif -lrumpnet_config -lrumpnet_netinet -lrumpnet_net
RUMPLIBS+=-lrumpnet ${RUMPKERN_SYSPROXY} -lrump -lrumpuser

CLEANFILES+= busmem1 busmem2

.include <bsd.prog.mk>

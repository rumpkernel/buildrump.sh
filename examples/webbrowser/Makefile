# For the old Makefile.static behavior, use:
#	rumpmake LDSTATIC=-static

PROG=	webbrowser webbrowser.sockin

LDADD.webbrowser+= -Wl,--whole-archive					\
	    -lrumpnet_virtif -lrumpnet_config -lrumpdev_bpf		\
	    -lrumpnet_netinet -lrumpnet_net -lrumpnet -lrump -lrumpuser	\
	-Wl,--no-whole-archive

LDADD.webbrowser.sockin+= -Wl,--whole-archive				\
	    -lrumpnet_sockin -lrumpnet -lrump -lrumpuser		\
	-Wl,--no-whole-archive

NOMAN=	I am too old to come up with NOMAN jokes anymore

.include <bsd.prog.mk>

#include "common.c"

#include <netinet/in.h>
#include <arpa/inet.h>

#include <errno.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

#include <rump/rump.h>
#include <rump/rump_syscalls.h>
#include <rump/netconfig.h>

#define CONNPORT 135

#define NOFAIL(a) do {int rv=a; if(rv==-1) die("%s: %d\n",#a,errno);} while (0)

static void
server_common(void (*ifconf)(void),
	int family, struct sockaddr *sa, unsigned slen)
{
	int s, s2;

	rump_daemonize_begin();
	rump_init();
	ifconf();

	NOFAIL(s = rump_sys_socket(family, RUMP_SOCK_STREAM, 0));

	NOFAIL(rump_sys_bind(s, sa, slen));
	NOFAIL(rump_sys_listen(s, 37));

	/* delay detach from console until we have a listening sucket */
	rump_daemonize_done(0);

#define TESTSTR "You feel like you've been here before --More--\n"
	NOFAIL(s2 = rump_sys_accept(s, sa, &slen));
	rump_sys_write(s2, TESTSTR, sizeof(TESTSTR));
}

static void
server_v4(void)
{
	struct sockaddr_in sin;
	unsigned int slen = sizeof(sin);

	memset(&sin, 0, sizeof(sin));
	sin.sin_family = RUMP_AF_INET;
	sin.sin_port = htons(CONNPORT);
	sin.sin_addr.s_addr = INADDR_ANY;

	server_common(config_server,
	    RUMP_PF_INET, (struct sockaddr *)&sin, sizeof(sin));
}

static void
server_v6(void)
{
	struct sockaddr_in6 sin6; /* XXX */
	unsigned int slen = sizeof(sin6);

	memset(&sin6, 0, sizeof(sin6));
	sin6.sin6_family = RUMP_AF_INET6;
	sin6.sin6_port = htons(CONNPORT);
	sin6.sin6_addr = in6addr_any;

	server_common(config_server6,
	    RUMP_PF_INET6, (struct sockaddr *)&sin6, sizeof(sin6));
}

static void
client_common(void (*ifconf)(void),
	int family, struct sockaddr *sa, unsigned slen)
{
	char buf[1024];
	ssize_t nn;
	int s;

	rump_init();
	ifconf();

	NOFAIL(s = rump_sys_socket(family, RUMP_SOCK_STREAM, 0));
	NOFAIL(rump_sys_connect(s, sa, slen));

	if ((nn = rump_sys_read(s, buf, sizeof(buf))) <= 0)
		die("reading socket failed");

	if (strcmp(buf, TESTSTR) != 0)
		die("didn't receive what was expected");
}

static void
client_v4(void)
{
	struct sockaddr_in sin;

	/* socket, connect.  standard sockets programming */
	memset(&sin, 0, sizeof(sin));
	sin.sin_family = RUMP_AF_INET;
	sin.sin_port = htons(CONNPORT);
	sin.sin_addr.s_addr = inet_addr("1.0.0.1");

	client_common(config_client,
	    RUMP_PF_INET, (struct sockaddr *)&sin, sizeof(sin));
}

static void
client_v6(void)
{
	struct sockaddr_in6 sin6;

	/* socket, connect.  standard sockets programming */
	memset(&sin6, 0, sizeof(sin6));
	sin6.sin6_family = RUMP_AF_INET6;
	sin6.sin6_port = htons(CONNPORT);
	inet_pton(AF_INET6, "2013::1", &sin6.sin6_addr);

	client_common(config_client6,
	    RUMP_PF_INET6, (struct sockaddr *)&sin6, sizeof(sin6));
}

/* give the router a controlsocket so that it can easily be halted */
static void
router(const char *ctrlsock)
{

	rump_daemonize_begin();
	rump_init();
	if (rump_init_server(ctrlsock) != 0)
		die("init server failed");
	config_router();
	rump_daemonize_done(0);
	pause();
}

int
main(int argc, char *argv[])
{


	if (argc < 2)
		die("need role");
	if (strcmp(argv[1], "server") == 0)
		server_v4();
	else if (strcmp(argv[1], "server6") == 0)
		server_v6();
	else if (strcmp(argv[1], "client") == 0)
		client_v4();
	else if (strcmp(argv[1], "client6") == 0)
		client_v6();
	else if (strcmp(argv[1], "router") == 0)
		router(argv[2]);
	else
		die("invalid role");
	return 0;
}

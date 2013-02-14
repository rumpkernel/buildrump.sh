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

#define NOFAIL(a) do {int rv=a; if(rv==-1) die("%s: %d",#a,errno);} while (0)

static void
server(void)
{
	struct sockaddr_in sin;
	int slen = sizeof(sin);
	int s, s2;

	/* configure interface using the portable interfaces */
	NOFAIL(rump_pub_netconfig_ifcreate("shmif0"));
	NOFAIL(rump_pub_netconfig_ifsetlinkstr("shmif0", "busmem"));
	NOFAIL(rump_pub_netconfig_ipv4_ifaddr("shmif0",
	    "1.0.0.1", "255.255.255.0"));

	/* socket, bind, listen, accept.  standard sockets programming */
	NOFAIL(s = rump_sys_socket(RUMP_PF_INET, RUMP_SOCK_STREAM, 0));
	memset(&sin, 0, sizeof(sin));
	sin.sin_family = RUMP_AF_INET;
	sin.sin_port = htons(CONNPORT);
	sin.sin_addr.s_addr = INADDR_ANY;
	NOFAIL(rump_sys_bind(s, (struct sockaddr *)&sin, slen));
	NOFAIL(rump_sys_listen(s, 37));

#define TESTSTR "You feel like you've been here before --More--\n"
	NOFAIL(s2 = rump_sys_accept(s, (struct sockaddr *)&sin, &slen));
	rump_sys_write(s2, TESTSTR, sizeof(TESTSTR));
}

static void
client(void)
{
	struct sockaddr_in sin;
	char buf[1024];
	ssize_t nn;
	int s;

	/* configure networking using the portable interfaces */
	NOFAIL(rump_pub_netconfig_ifcreate("shmif0"));
	NOFAIL(rump_pub_netconfig_ifcreate("shmif0"));
	NOFAIL(rump_pub_netconfig_ifsetlinkstr("shmif0", "busmem"));
	NOFAIL(rump_pub_netconfig_ipv4_ifaddr("shmif0",
	    "1.0.0.2", "255.255.255.0"));

	/* socket, connect.  standard sockets programming */
	NOFAIL(s = rump_sys_socket(RUMP_PF_INET, RUMP_SOCK_STREAM, 0));
	memset(&sin, 0, sizeof(sin));
	sin.sin_family = RUMP_AF_INET;
	sin.sin_port = htons(CONNPORT);
	sin.sin_addr.s_addr = inet_addr("1.0.0.1");
	NOFAIL(rump_sys_connect(s, (struct sockaddr *)&sin, sizeof(sin)));

	if ((nn = rump_sys_read(s, buf, sizeof(buf))) <= 0)
		die("reading socket failed");

	if (strcmp(buf, TESTSTR) != 0)
		die("didn't receive what was expected");
}

int
main(int argc, char *argv[])
{

	/*
	 * Bootstrap rump kernel.  it's so cheap that we might as well
	 * do it here before checking the args.
	 */
	rump_init();

	if (argc != 2)
		die("need role");
	if (strcmp(argv[1], "server") == 0)
		server();
	else if (strcmp(argv[1], "client") == 0)
		client();
	else
		die("invalid role");
	return 0;
}

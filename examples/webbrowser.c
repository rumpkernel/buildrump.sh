/*
 * Hah, made you look!  Maybe this is not a browser, but it can fetch one
 * web page using a tcp/ip service provided by a local rump kernel.
 *
 * Build with:
 *  -I${RD}/include -L${RD}/lib -Wl,-R${RD}/lib -lrumpnet_virtif	\
 *    -lrumpnet_config -lrumpdev_bpf -lrumpnet_netinet -lrumpnet_net	\
 *    -lrumpnet -lrump -lrumpuser -lpthread -ldl
 *
 * Where RD is the destination directory you gave to buildrump.sh
 * (it's ./rump by default).
 *
 * For configuring the host, see:
 *  https://github.com/anttikantee/buildrump.sh/wiki/virtif-networking-howtos
 */

#include <sys/types.h>

#include <assert.h>
#include <err.h>
#include <netdb.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include <rump/rump.h>
#include <rump/netconfig.h>
#include <rump/rump_syscalls.h>

#include <netinet/in.h>

#define DESTHOST "www.netbsd.org"

int
main()
{
	struct sockaddr_in sin;
	char buf[65535];
	struct hostent *hp;
	ssize_t nn;
	ssize_t off;
	int s;

	hp = gethostbyname(DESTHOST);
	if (!hp || hp->h_addrtype != AF_INET)
		errx(1, "failed to resolve \"%s\"", DESTHOST);

	rump_init();
	rump_pub_netconfig_ifcreate("virt0");
	rump_pub_netconfig_dhcp_ipv4_oneshot("virt0");

	s = rump_sys_socket(PF_INET, SOCK_STREAM, 0);
	if (s == -1)
		err(1,"socket");
	
	memset(&sin, 0, sizeof(sin));
	sin.sin_family = AF_INET;
#if 0
	sin.sin_len = sizeof(sin);
#endif
	sin.sin_port = htons(80);
	memcpy(&sin.sin_addr, hp->h_addr, sizeof(sin.sin_addr));

	if (rump_sys_connect(s, (struct sockaddr *)&sin, sizeof(sin)) == -1)
		err(1, "connect");
	printf("connected\n");

#define WANTHTML "GET / HTTP/1.1\nHost: www.netbsd.org\n\n"
	nn = rump_sys_write(s, WANTHTML, sizeof(WANTHTML)-1);
	printf("write rv %zd\n", nn);

	for (;;) {
		nn = rump_sys_read(s, buf, sizeof(buf)-1);
		if (nn == -1)
			errx(1, "read failed: %zd", nn);
		if (nn == 0)
			break;
		
		buf[nn] = '\0';
		printf("%s", buf);
	}

	return 0;
}

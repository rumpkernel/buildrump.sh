#include <sys/types.h>

#include <dlfcn.h>
#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>

#include <rump/rump.h>
#include <rump/rump_syscalls.h>

#include "common.c"

int
main()
{
	int rv;
	int s;

	/* use this as a "do we have dynamic libs" test */
	if (dlopen("librumpnet.so", RTLD_LAZY | RTLD_GLOBAL) == NULL)
		return 37;

	/* if the above worked, these should too */
	if (dlopen("librumpnet_net.so", RTLD_LAZY | RTLD_GLOBAL) == NULL)
		die("dlopen rumpnet_net");
	if (dlopen("librumpnet_netinet.so", RTLD_LAZY | RTLD_GLOBAL) == NULL)
		die("dlopen rumpnet_netinet");

	rv = rump_init();
	if (rv)
		die("rump_init failed");

	if ((s = rump_sys_socket(RUMP_PF_INET, RUMP_SOCK_DGRAM, 0)) == -1)
		die("cannot open socket");

	return 0;
}

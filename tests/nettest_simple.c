#include <sys/types.h>

#include <inttypes.h>

#include <rump/rump.h>
#include <rump/netconfig.h>

static void
config_server(void)
{

	/* configure interface using the portable interfaces */
	rump_pub_netconfig_ifcreate("shmif0");
	rump_pub_netconfig_ifsetlinkstr("shmif0", "busmem");
	rump_pub_netconfig_ipv4_ifaddr("shmif0", "1.0.0.1", "255.255.255.0");
}


static void
config_client(void)
{

	/* configure networking using the portable interfaces */
	rump_pub_netconfig_ifcreate("shmif0");
	rump_pub_netconfig_ifsetlinkstr("shmif0", "busmem");
	rump_pub_netconfig_ipv4_ifaddr("shmif0", "1.0.0.2", "255.255.255.0");
}

static void
config_router(void)
{

	/* nada */
}

#include "nettest_base.c"

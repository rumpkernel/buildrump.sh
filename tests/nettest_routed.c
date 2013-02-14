#include <sys/types.h>

#include <rump/rump.h>
#include <rump/netconfig.h>

/* A very simple network with three nodes, one of which is the DFZ ;) */

static void
config_server(void)
{

	/* configure interface using the portable interfaces */
	rump_pub_netconfig_ifcreate("shmif0");
	rump_pub_netconfig_ifsetlinkstr("shmif0", "net1");
	rump_pub_netconfig_ipv4_ifaddr("shmif0", "1.0.0.1", "255.255.255.0");

	rump_pub_netconfig_ipv4_gw("1.0.0.2");
}


static void
config_client(void)
{

	/* configure networking using the portable interfaces */
	rump_pub_netconfig_ifcreate("shmif0");
	rump_pub_netconfig_ifsetlinkstr("shmif0", "net2");
	rump_pub_netconfig_ipv4_ifaddr("shmif0", "1.0.1.1", "255.255.255.0");

	rump_pub_netconfig_ipv4_gw("1.0.1.2");
}

static void
config_router(void)
{

	/* configure networking using the portable interfaces */
	rump_pub_netconfig_ifcreate("shmif0");
	rump_pub_netconfig_ifsetlinkstr("shmif0", "net1");
	rump_pub_netconfig_ipv4_ifaddr("shmif0", "1.0.0.2", "255.255.255.0");

	rump_pub_netconfig_ifcreate("shmif1");
	rump_pub_netconfig_ifsetlinkstr("shmif1", "net2");
	rump_pub_netconfig_ipv4_ifaddr("shmif1", "1.0.1.2", "255.255.255.0");
}

#include "nettest_base.c"

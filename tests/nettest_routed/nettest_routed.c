#include <sys/types.h>

#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>

#include <rump/rump.h>
#include <rump/netconfig.h>

/* A very simple network with three nodes, one of which is the DFZ ;) */

#define NOFAIL_RV(a) do{int rv=a;if(rv){printf("%s:%d",#a,rv);abort();}}while(0)

static void
config_server(void)
{
	int rv;

	/* configure interface using the portable interfaces */
	NOFAIL_RV(rump_pub_netconfig_ifcreate("shmif0"));
	NOFAIL_RV(rump_pub_netconfig_ifsetlinkstr("shmif0", "busmem1"));
	NOFAIL_RV(rump_pub_netconfig_ipv4_ifaddr("shmif0",
	    "1.0.0.1", "255.255.255.0"));

	NOFAIL_RV(rump_pub_netconfig_ipv4_gw("1.0.0.2"));
}

static void
config_server6(void)
{
	int rv;

	/* configure networking using the portable interfaces */
	NOFAIL_RV(rump_pub_netconfig_ifcreate("shmif0"));
	NOFAIL_RV(rump_pub_netconfig_ifsetlinkstr("shmif0", "busmem1"));
	NOFAIL_RV(rump_pub_netconfig_ipv6_ifaddr("shmif0", "2001::1", 64));

	NOFAIL_RV(rump_pub_netconfig_ipv6_gw("2001::2"));
}

static void
config_client(void)
{
	int rv;

	/* configure networking using the portable interfaces */
	NOFAIL_RV(rump_pub_netconfig_ifcreate("shmif0"));
	NOFAIL_RV(rump_pub_netconfig_ifsetlinkstr("shmif0", "busmem2"));
	NOFAIL_RV(rump_pub_netconfig_ipv4_ifaddr("shmif0",
	    "1.0.1.1", "255.255.255.0"));

	NOFAIL_RV(rump_pub_netconfig_ipv4_gw("1.0.1.2"));
}

static void
config_client6(void)
{
	int rv;

	/* configure networking using the portable interfaces */
	NOFAIL_RV(rump_pub_netconfig_ifcreate("shmif0"));
	NOFAIL_RV(rump_pub_netconfig_ifsetlinkstr("shmif0", "busmem2"));
	NOFAIL_RV(rump_pub_netconfig_ipv6_ifaddr("shmif0", "2002::1", 64));

	NOFAIL_RV(rump_pub_netconfig_ipv6_gw("2002::2"));
}

static void
config_router(void)
{
	int rv;

	/* configure networking using the portable interfaces */
	NOFAIL_RV(rump_pub_netconfig_ifcreate("shmif0"));
	NOFAIL_RV(rump_pub_netconfig_ifsetlinkstr("shmif0", "busmem1"));
	NOFAIL_RV(rump_pub_netconfig_ipv4_ifaddr("shmif0",
	    "1.0.0.2", "255.255.255.0"));

	NOFAIL_RV(rump_pub_netconfig_ifcreate("shmif1"));
	NOFAIL_RV(rump_pub_netconfig_ifsetlinkstr("shmif1", "busmem2"));
	NOFAIL_RV(rump_pub_netconfig_ipv4_ifaddr("shmif1",
	    "1.0.1.2", "255.255.255.0"));
}

static void
config_router6(void)
{
	extern int rumpns_ip6_forwarding;
	int rv;

	/* configure networking using the portable interfaces */
	NOFAIL_RV(rump_pub_netconfig_ifcreate("shmif0"));
	NOFAIL_RV(rump_pub_netconfig_ifsetlinkstr("shmif0", "busmem1"));
	NOFAIL_RV(rump_pub_netconfig_ipv6_ifaddr("shmif0", "2001::2", 64));
	NOFAIL_RV(rump_pub_netconfig_ifup("shmif0"));

	NOFAIL_RV(rump_pub_netconfig_ifcreate("shmif1"));
	NOFAIL_RV(rump_pub_netconfig_ifsetlinkstr("shmif1", "busmem2"));
	NOFAIL_RV(rump_pub_netconfig_ipv6_ifaddr("shmif1", "2002::2", 64));
	NOFAIL_RV(rump_pub_netconfig_ifup("shmif1"));

	/* turn ipv6 forwarding on the easy way */
	rumpns_ip6_forwarding = 1;
}

#include "nettest_base.c"

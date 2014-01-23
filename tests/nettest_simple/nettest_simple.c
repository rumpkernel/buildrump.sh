#include <sys/types.h>

#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>

#include <rump/rump.h>
#include <rump/netconfig.h>

#define NOFAIL_RV(a) do{int rv=a;if(rv){printf("%s:%d",#a,rv);abort();}}while(0)

static void
config_server(void)
{

	/* configure interface using the portable interfaces */
	NOFAIL_RV(rump_pub_netconfig_ifcreate("shmif0"));
	NOFAIL_RV(rump_pub_netconfig_ifsetlinkstr("shmif0", "busmem"));
	NOFAIL_RV(rump_pub_netconfig_ipv4_ifaddr("shmif0",
	    "1.0.0.1", "255.255.255.0"));
}

static void
config_server6(void)
{

	/* configure interface using the portable interfaces */
	NOFAIL_RV(rump_pub_netconfig_ifcreate("shmif0"));
	NOFAIL_RV(rump_pub_netconfig_ifsetlinkstr("shmif0", "busmem"));
	NOFAIL_RV(rump_pub_netconfig_ipv6_ifaddr("shmif0", "2001::1", 64));
}


static void
config_client(void)
{

	/* configure networking using the portable interfaces */
	NOFAIL_RV(rump_pub_netconfig_ifcreate("shmif0"));
	NOFAIL_RV(rump_pub_netconfig_ifsetlinkstr("shmif0", "busmem"));
	NOFAIL_RV(rump_pub_netconfig_ipv4_ifaddr("shmif0",
	    "1.0.0.2", "255.255.255.0"));
}

static void
config_client6(void)
{

	/* configure networking using the portable interfaces */
	NOFAIL_RV(rump_pub_netconfig_ifcreate("shmif0"));
	NOFAIL_RV(rump_pub_netconfig_ifsetlinkstr("shmif0", "busmem"));
	NOFAIL_RV(rump_pub_netconfig_ipv6_ifaddr("shmif0", "2001::2", 64));
}

static void
config_router(void)
{

	/* nada */
}

static void
config_router6(void)
{

	/* nada */
}

#include "nettest_base.c"

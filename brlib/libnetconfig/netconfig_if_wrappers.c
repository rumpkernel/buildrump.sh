/*	$NetBSD: makerumpif.sh,v 1.9 2015/04/23 10:50:00 pooka Exp $	*/

/*
 * Automatically generated.  DO NOT EDIT.
 * from: ;
 * by:   NetBSD: makerumpif.sh,v 1.9 2015/04/23 10:50:00 pooka Exp 
 */

#include <sys/cdefs.h>
#include <sys/systm.h>

#include <rump/rump.h>
#include <rump/netconfig.h>

#include "rump_private.h"
#include "netconfig_if_priv.h"

void __dead rump_netconfig_unavailable(void);
void __dead
rump_netconfig_unavailable(void)
{

	panic("netconfig interface unavailable");
}

int
rump_pub_netconfig_ifcreate(const char *arg1)
{
	int rv;

	rump_schedule();
	rv = rump_netconfig_ifcreate(arg1);
	rump_unschedule();

	return rv;
}

int
rump_pub_netconfig_ifup(const char *arg1)
{
	int rv;

	rump_schedule();
	rv = rump_netconfig_ifup(arg1);
	rump_unschedule();

	return rv;
}

int
rump_pub_netconfig_ifsetlinkstr(const char *arg1, const char *arg2)
{
	int rv;

	rump_schedule();
	rv = rump_netconfig_ifsetlinkstr(arg1, arg2);
	rump_unschedule();

	return rv;
}

int
rump_pub_netconfig_ifdown(const char *arg1)
{
	int rv;

	rump_schedule();
	rv = rump_netconfig_ifdown(arg1);
	rump_unschedule();

	return rv;
}

int
rump_pub_netconfig_ifdestroy(const char *arg1)
{
	int rv;

	rump_schedule();
	rv = rump_netconfig_ifdestroy(arg1);
	rump_unschedule();

	return rv;
}

int
rump_pub_netconfig_bradd(const char *arg1, const char *arg2)
{
	int rv;

	rump_schedule();
	rv = rump_netconfig_bradd(arg1, arg2);
	rump_unschedule();

	return rv;
}

int
rump_pub_netconfig_brdel(const char *arg1, const char *arg2)
{
	int rv;

	rump_schedule();
	rv = rump_netconfig_brdel(arg1, arg2);
	rump_unschedule();

	return rv;
}

int
rump_pub_netconfig_ipv4_ifaddr(const char *arg1, const char *arg2, const char *arg3)
{
	int rv;

	rump_schedule();
	rv = rump_netconfig_ipv4_ifaddr(arg1, arg2, arg3);
	rump_unschedule();

	return rv;
}

int
rump_pub_netconfig_ipv4_ifaddr_cidr(const char *arg1, const char *arg2, int arg3)
{
	int rv;

	rump_schedule();
	rv = rump_netconfig_ipv4_ifaddr_cidr(arg1, arg2, arg3);
	rump_unschedule();

	return rv;
}

int
rump_pub_netconfig_ipv6_ifaddr(const char *arg1, const char *arg2, int arg3)
{
	int rv;

	rump_schedule();
	rv = rump_netconfig_ipv6_ifaddr(arg1, arg2, arg3);
	rump_unschedule();

	return rv;
}

int
rump_pub_netconfig_ipv4_gw(const char *arg1)
{
	int rv;

	rump_schedule();
	rv = rump_netconfig_ipv4_gw(arg1);
	rump_unschedule();

	return rv;
}

int
rump_pub_netconfig_ipv6_gw(const char *arg1)
{
	int rv;

	rump_schedule();
	rv = rump_netconfig_ipv6_gw(arg1);
	rump_unschedule();

	return rv;
}

int
rump_pub_netconfig_dhcp_ipv4_oneshot(const char *arg1)
{
	int rv;

	rump_schedule();
	rv = rump_netconfig_dhcp_ipv4_oneshot(arg1);
	rump_unschedule();

	return rv;
}

int
rump_pub_netconfig_auto_ipv6(const char *arg1)
{
	int rv;

	rump_schedule();
	rv = rump_netconfig_auto_ipv6(arg1);
	rump_unschedule();

	return rv;
}

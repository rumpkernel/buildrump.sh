/*	$NetBSD: makerumpif.sh,v 1.9 2015/04/23 10:50:00 pooka Exp $	*/

/*
 * Automatically generated.  DO NOT EDIT.
 * from: ;
 * by:   NetBSD: makerumpif.sh,v 1.9 2015/04/23 10:50:00 pooka Exp 
 */

int rump_pub_netconfig_ifcreate(const char *);
int rump_pub_netconfig_ifup(const char *);
int rump_pub_netconfig_ifsetlinkstr(const char *, const char *);
int rump_pub_netconfig_ifdown(const char *);
int rump_pub_netconfig_ifdestroy(const char *);
int rump_pub_netconfig_bradd(const char *, const char *);
int rump_pub_netconfig_brdel(const char *, const char *);
int rump_pub_netconfig_ipv4_ifaddr(const char *, const char *, const char *);
int rump_pub_netconfig_ipv4_ifaddr_cidr(const char *, const char *, int);
int rump_pub_netconfig_ipv6_ifaddr(const char *, const char *, int);
int rump_pub_netconfig_ipv4_gw(const char *);
int rump_pub_netconfig_ipv6_gw(const char *);
int rump_pub_netconfig_dhcp_ipv4_oneshot(const char *);
int rump_pub_netconfig_auto_ipv6(const char *);

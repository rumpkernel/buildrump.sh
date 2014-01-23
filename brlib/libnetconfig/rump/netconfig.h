/*	$NetBSD: makerumpif.sh,v 1.6 2013/02/14 10:54:54 pooka Exp $	*/

/*
 * Automatically generated.  DO NOT EDIT.
 * from: ;
 * by:   NetBSD: makerumpif.sh,v 1.6 2013/02/14 10:54:54 pooka Exp 
 */

int rump_pub_netconfig_ifcreate(const char *);
int rump_pub_netconfig_ifup(const char *);
int rump_pub_netconfig_ifsetlinkstr(const char *, const char *);
int rump_pub_netconfig_ifdown(const char *);
int rump_pub_netconfig_ifdestroy(const char *);
int rump_pub_netconfig_ipv4_ifaddr(const char *, const char *, const char *);
int rump_pub_netconfig_ipv6_ifaddr(const char *, const char *, int);
int rump_pub_netconfig_ipv4_gw(const char *);
int rump_pub_netconfig_ipv6_gw(const char *);
int rump_pub_netconfig_dhcp_ipv4_oneshot(const char *);

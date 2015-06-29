/*	$NetBSD: makerumpif.sh,v 1.9 2015/04/23 10:50:00 pooka Exp $	*/

/*
 * Automatically generated.  DO NOT EDIT.
 * from: ;
 * by:   NetBSD: makerumpif.sh,v 1.9 2015/04/23 10:50:00 pooka Exp 
 */

#ifndef _RUMP_PRIF_NETCONFIG_H_
#define _RUMP_PRIF_NETCONFIG_H_

int rump_netconfig_ifcreate(const char *);
typedef int (*rump_netconfig_ifcreate_fn)(const char *);
int rump_netconfig_ifup(const char *);
typedef int (*rump_netconfig_ifup_fn)(const char *);
int rump_netconfig_ifsetlinkstr(const char *, const char *);
typedef int (*rump_netconfig_ifsetlinkstr_fn)(const char *, const char *);
int rump_netconfig_ifdown(const char *);
typedef int (*rump_netconfig_ifdown_fn)(const char *);
int rump_netconfig_ifdestroy(const char *);
typedef int (*rump_netconfig_ifdestroy_fn)(const char *);
int rump_netconfig_bradd(const char *, const char *);
typedef int (*rump_netconfig_bradd_fn)(const char *, const char *);
int rump_netconfig_brdel(const char *, const char *);
typedef int (*rump_netconfig_brdel_fn)(const char *, const char *);
int rump_netconfig_ipv4_ifaddr(const char *, const char *, const char *);
typedef int (*rump_netconfig_ipv4_ifaddr_fn)(const char *, const char *, const char *);
int rump_netconfig_ipv4_ifaddr_cidr(const char *, const char *, int);
typedef int (*rump_netconfig_ipv4_ifaddr_cidr_fn)(const char *, const char *, int);
int rump_netconfig_ipv6_ifaddr(const char *, const char *, int);
typedef int (*rump_netconfig_ipv6_ifaddr_fn)(const char *, const char *, int);
int rump_netconfig_ipv4_gw(const char *);
typedef int (*rump_netconfig_ipv4_gw_fn)(const char *);
int rump_netconfig_ipv6_gw(const char *);
typedef int (*rump_netconfig_ipv6_gw_fn)(const char *);
int rump_netconfig_dhcp_ipv4_oneshot(const char *);
typedef int (*rump_netconfig_dhcp_ipv4_oneshot_fn)(const char *);
int rump_netconfig_auto_ipv6(const char *);
typedef int (*rump_netconfig_auto_ipv6_fn)(const char *);

#endif /* _RUMP_PRIF_NETCONFIG_H_ */

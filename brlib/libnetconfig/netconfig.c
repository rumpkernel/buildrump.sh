/*-
 * Copyright (c) 2013 Antti Kantee <pooka@iki.fi>
 *
 * Permission to use, copy, modify, and/or distribute this software for
 * any purpose with or without fee is hereby granted, provided that the
 * above copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */

#include <sys/param.h>
#include <sys/socketvar.h>

#include <net/if.h>

#include <netinet/in.h>

#include <netinet6/in6.h>

#include "rump_private.h"
#include "netconfig_if_priv.h"

static struct socket *in4so;
static struct socket *in6so;
//static struct socket *rtso;

int
rump_netconfig_ifcreate(const char *ifname)
{
	struct ifreq ifr;

	memset(&ifr, 0, sizeof(ifr));
	strlcpy(ifr.ifr_name, ifname, sizeof(ifr.ifr_name));
	return ifioctl(in4so, SIOCIFCREATE, &ifr, curlwp);
}

static void
addup(short *fp)
{

	*fp |= IFF_UP;
}

static void
remup(short *fp)
{

	*fp &= ~IFF_UP;
}

static int
chflag(const char *ifname, void (*edflag)(short *))
{
	struct ifreq ifr;
	int rv;

	memset(&ifr, 0, sizeof(ifr));
	strlcpy(ifr.ifr_name, ifname, sizeof(ifr.ifr_name));
	if ((rv = ifioctl(in4so, SIOCGIFFLAGS, &ifr, curlwp)) != 0)
		return rv;
	edflag(&ifr.ifr_flags);

	return ifioctl(in4so, SIOCSIFFLAGS, &ifr, curlwp);
}

int
rump_netconfig_ifup(const char *ifname)
{
		
	return chflag(ifname, addup);
}

int
rump_netconfig_ifdown(const char *ifname)
{

	return chflag(ifname, remup);
}

int
rump_netconfig_ifsetlinkstr(const char *ifname, const char *linkstr)
{
	struct ifdrv ifd;

	memset(&ifd, 0, sizeof(ifd));
	strlcpy(ifd.ifd_name, ifname, sizeof(ifd.ifd_name));
	ifd.ifd_cmd = 0;
	ifd.ifd_data = __UNCONST(linkstr);
	ifd.ifd_len = strlen(linkstr)+1;

	return ifioctl(in4so, SIOCSLINKSTR, &ifd, curlwp);
}

int
rump_netconfig_ifdestroy(const char *ifname)
{
	struct ifreq ifr;

	memset(&ifr, 0, sizeof(ifr));
	strlcpy(ifr.ifr_name, ifname, sizeof(ifr.ifr_name));
	return ifioctl(in4so, SIOCIFDESTROY, &ifr, curlwp);
}

int
rump_netconfig_ipv4_ifaddr(const char *ifname, const char *addr,
	const char *mask)
{
	struct ifaliasreq ia;
	struct sockaddr_in *sin;
	in_addr_t m_addr;

	memset(&ia, 0, sizeof(ia));
	strlcpy(ia.ifra_name, ifname, sizeof(ia.ifra_name));

	sin = (struct sockaddr_in *)&ia.ifra_addr;
	sin->sin_family = AF_INET;
	sin->sin_len = sizeof(*sin);
	sin->sin_addr.s_addr = inet_addr(addr);

	sin = (struct sockaddr_in *)&ia.ifra_mask;
	sin->sin_family = AF_INET;
	sin->sin_len = sizeof(*sin);
	m_addr = inet_addr(mask);
	sin->sin_addr.s_addr = m_addr;

	sin = (struct sockaddr_in *)&ia.ifra_broadaddr;
	sin->sin_family = AF_INET;
	sin->sin_len = sizeof(*sin);
	sin->sin_addr.s_addr = ~m_addr;

	return ifioctl(in4so, SIOCAIFADDR, &ia, curlwp);
}

int
rump_netconfig_ipv6_ifaddr(const char *ifname, const char *addr, int mask)
{

	panic("IPv6 is TODO");
}

int
rump_netconfig_ipv4_gw(const char *gwaddr)
{

	panic("default route configuration TODO");
}

RUMP_COMPONENT(RUMP_COMPONENT_NET_IFCFG)
{
	int rv;

	if ((rv = socreate(AF_INET, &in4so, SOCK_DGRAM, 0, curlwp, NULL)) != 0)
		panic("netconfig socreate in4: %d", rv);
	if ((rv = socreate(AF_INET6, &in6so, SOCK_DGRAM, 0, curlwp, NULL)) != 0)
		panic("netconfig socreate in6: %d", rv);
}

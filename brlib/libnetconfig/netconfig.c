/*-
 * Copyright (c) 2013 Antti Kantee <pooka@iki.fi>
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS
 * OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#include <sys/param.h>
#include <sys/kernel.h>
#include <sys/socketvar.h>

#include <net/if.h>
#include <net/route.h>

#include <netinet/in.h>

#include <netinet6/in6.h>

#include "rump_private.h"
#include "netconfig_if_priv.h"

static struct socket *in4so;
static struct socket *in6so;
static struct socket *rtso;

#define CHECKDOMAIN(dom) if (!(dom)) return EAFNOSUPPORT

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
	int rv;

	CHECKDOMAIN(in4so);

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

	rv = ifioctl(in4so, SIOCAIFADDR, &ia, curlwp);
	/*
	 * small pause so that we can assume interface is usable when
	 * we return (ARPs have trickled through, etc.)
	 */
	kpause("ramasee", false, mstohz(50), NULL);
	return rv;
}

int
rump_netconfig_ipv6_ifaddr(const char *ifname, const char *addr, int mask)
{

	CHECKDOMAIN(in6so);

	panic("IPv6 is TODO");
}

int
rump_netconfig_ipv4_gw(const char *gwaddr)
{
	struct rt_msghdr rtm, *rtmp;
	struct sockaddr_in sin;
	struct mbuf *m;
	int off, rv;

	CHECKDOMAIN(in4so);

	memset(&rtm, 0, sizeof(rtm));
	rtm.rtm_type = RTM_ADD;
	rtm.rtm_flags = RTF_UP | RTF_STATIC | RTF_GATEWAY;
	rtm.rtm_version = RTM_VERSION;
	rtm.rtm_seq = 2;
	rtm.rtm_addrs = RTA_DST | RTA_GATEWAY | RTA_NETMASK;

	m = m_gethdr(M_WAIT, MT_DATA);
	m->m_pkthdr.len = 0;
	m_copyback(m, 0, sizeof(rtm), &rtm);
	off = sizeof(rtm);

	/* dest */
	memset(&sin, 0, sizeof(sin));
	sin.sin_family = AF_INET;
	sin.sin_len = sizeof(sin);
	m_copyback(m, off, sin.sin_len, &sin);
	RT_ADVANCE(off, (struct sockaddr *)&sin);

	/* gw */
	sin.sin_addr.s_addr = inet_addr(gwaddr);
	m_copyback(m, off, sin.sin_len, &sin);
	RT_ADVANCE(off, (struct sockaddr *)&sin);

	/* mask */
	sin.sin_addr.s_addr = 0;
	m_copyback(m, off, sin.sin_len, &sin);
	RT_ADVANCE(off, (struct sockaddr *)&sin);

	m = m_pullup(m, sizeof(*rtmp));
	rtmp = mtod(m, struct rt_msghdr *);
	m->m_pkthdr.len = rtmp->rtm_msglen = off;

	solock(rtso);
	rv = rtso->so_proto->pr_output(m, rtso);
	sounlock(rtso);

	return rv;
}

RUMP_COMPONENT(RUMP_COMPONENT_NET_IFCFG)
{
	int rv;

	socreate(PF_INET, &in4so, SOCK_DGRAM, 0, curlwp, NULL);
	socreate(PF_INET6, &in6so, SOCK_DGRAM, 0, curlwp, NULL);

	if (!in4so && !in6so)
		panic("netconfig: missing both inet and inet6");
	if ((rv = socreate(PF_ROUTE, &rtso, SOCK_RAW, 0, curlwp, NULL)) != 0)
		panic("netconfig socreate route: %d", rv);
}

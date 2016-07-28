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
#include <net/if_dl.h>
#include <net/if_ether.h>
#include <net/if_bridgevar.h>
#include <net/if_types.h>
#include <net/route.h>

#include <netinet/in.h>
#include <netinet/icmp6.h>

#include <netinet6/in6.h>
#include <netinet6/in6_var.h>
#include <netinet6/ip6_var.h>
#include <netinet6/nd6.h>
#include <netinet6/scope6_var.h>

#include "rump_private.h"

#include "netconfig_if_priv.h"
#include "netconfig_private.h"

static struct socket *in4so;
static struct socket *in6so;
static struct socket *rtso;

#define CHECKDOMAIN(dom) if (!(dom)) return EAFNOSUPPORT

static int
wrapifioctl(struct socket *so, u_long cmd, void *data)
{
	int rv;

	KERNEL_LOCK(1, NULL);
	rv = ifioctl(so, cmd, data, curlwp);
	KERNEL_UNLOCK_ONE(NULL);

	return rv;
}

int
rump_netconfig_ifcreate(const char *ifname)
{
	struct ifreq ifr;

	memset(&ifr, 0, sizeof(ifr));
	strlcpy(ifr.ifr_name, ifname, sizeof(ifr.ifr_name));
	return wrapifioctl(in4so, SIOCIFCREATE, &ifr);
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
	if ((rv = wrapifioctl(in4so, SIOCGIFFLAGS, &ifr)) != 0)
		return rv;
	edflag(&ifr.ifr_flags);

	return wrapifioctl(in4so, SIOCSIFFLAGS, &ifr);
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

	return wrapifioctl(in4so, SIOCSLINKSTR, &ifd);
}

int
rump_netconfig_ifdestroy(const char *ifname)
{
	struct ifreq ifr;

	memset(&ifr, 0, sizeof(ifr));
	strlcpy(ifr.ifr_name, ifname, sizeof(ifr.ifr_name));
	return wrapifioctl(in4so, SIOCIFDESTROY, &ifr);
}

/*
 * network bridge manipulation (bridge is created with ifbridge)
 */

static int
brioctl(const char *bridgename, const char *ifname, unsigned long op)
{
	struct ifdrv ifd;
	struct ifbreq req;

	memset(&req, 0, sizeof(req));
	strlcpy(req.ifbr_ifsname, ifname, sizeof(req.ifbr_ifsname));

	memset(&ifd, 0, sizeof(ifd));
	strlcpy(ifd.ifd_name, bridgename, sizeof(ifd.ifd_name));
	ifd.ifd_cmd = op;
	ifd.ifd_len = sizeof(req);
	ifd.ifd_data = &req;


	return wrapifioctl(in4so, SIOCSDRVSPEC, &ifd);
}

int
rump_netconfig_bradd(const char *bridgename, const char *ifname)
{

	return brioctl(bridgename, ifname, BRDGADD);
}

int
rump_netconfig_brdel(const char *bridgename, const char *ifname)
{

	return brioctl(bridgename, ifname, BRDGDEL);
}

static int
cfg_ipv4(const char *ifname, const char *addr, in_addr_t m_addr)
{
	struct ifaliasreq ia;
	struct sockaddr_in *sin;
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
	sin->sin_addr.s_addr = m_addr;

	sin = (struct sockaddr_in *)&ia.ifra_broadaddr;
	sin->sin_family = AF_INET;
	sin->sin_len = sizeof(*sin);
	sin->sin_addr.s_addr = inet_addr(addr) | ~m_addr;

	rv = wrapifioctl(in4so, SIOCAIFADDR, &ia);
	/*
	 * small pause so that we can assume interface is usable when
	 * we return (ARPs have trickled through, etc.)
	 */
	if (rv == 0)
		kpause("ramasee", false, mstohz(50), NULL);
	return rv;
}

int
rump_netconfig_ipv4_ifaddr(const char *ifname, const char *addr,
	const char *mask)
{

	return cfg_ipv4(ifname, addr, inet_addr(mask));
}

int
rump_netconfig_ipv4_ifaddr_cidr(const char *ifname, const char *addr,
	int mask)
{

	if (mask < 0 || mask > 32)
		return EINVAL;
	return cfg_ipv4(ifname, addr, htonl(~0U<<(32-mask)));
}

int
rump_netconfig_ipv6_ifaddr(const char *ifname, const char *addr, int prefixlen)
{
	struct sockaddr_in6 *sin6;
	struct in6_aliasreq ia;
	int rv;

	CHECKDOMAIN(in6so);

	/* pfft, you do the bitnibbling */
	if (prefixlen % 8)
		return EINVAL;

	memset(&ia, 0, sizeof(ia));
	strlcpy(ia.ifra_name, ifname, sizeof(ia.ifra_name));

	ia.ifra_lifetime.ia6t_pltime = ND6_INFINITE_LIFETIME;
	ia.ifra_lifetime.ia6t_vltime = ND6_INFINITE_LIFETIME;

	sin6 = (struct sockaddr_in6 *)&ia.ifra_addr;
	sin6->sin6_family = AF_INET6;
	sin6->sin6_len = sizeof(*sin6);
	netconfig_inet_pton6(addr, &sin6->sin6_addr);

	sin6 = (struct sockaddr_in6 *)&ia.ifra_prefixmask;
	sin6->sin6_family = AF_INET6;
	sin6->sin6_len = sizeof(*sin6);
	memset(&sin6->sin6_addr, 0, sizeof(sin6->sin6_addr));
	memset(&sin6->sin6_addr, 0xff, prefixlen / 8);

	rv = wrapifioctl(in6so, SIOCAIFADDR_IN6, &ia);
	/*
	 * small pause so that we can assume interface is usable when
	 * we return (ARPs have trickled through, etc.)
	 */
	if (rv == 0)
		kpause("ramasee", false, mstohz(50), NULL);
	return rv;
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
#if __NetBSD_Prereq__(7,99,26)
	rv = rtso->so_proto->pr_usrreqs->pr_send(rtso, m, NULL, NULL, curlwp);
#else
	rv = rtso->so_proto->pr_output(m, rtso);
#endif
	sounlock(rtso);

	return rv;
}

int
rump_netconfig_ipv6_gw(const char *gwaddr)
{
	struct rt_msghdr rtm, *rtmp;
	struct sockaddr_in6 sin6;
	struct mbuf *m;
	int off, rv;

	CHECKDOMAIN(in6so);

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
	memset(&sin6, 0, sizeof(sin6));
	sin6.sin6_family = AF_INET6;
	sin6.sin6_len = sizeof(sin6);
	m_copyback(m, off, sin6.sin6_len, &sin6);
	RT_ADVANCE(off, (struct sockaddr *)&sin6);

	/* gw */
	netconfig_inet_pton6(gwaddr, &sin6.sin6_addr);
	m_copyback(m, off, sin6.sin6_len, &sin6);
	RT_ADVANCE(off, (struct sockaddr *)&sin6);

	/* mask */
	memset(&sin6.sin6_addr, 0, sizeof(sin6.sin6_addr));
	m_copyback(m, off, sin6.sin6_len, &sin6);
	off = m->m_pkthdr.len;

	m = m_pullup(m, sizeof(*rtmp));
	rtmp = mtod(m, struct rt_msghdr *);
	rtmp->rtm_msglen = off;

	solock(rtso);
#if __NetBSD_Prereq__(7,99,26)
	rv = rtso->so_proto->pr_usrreqs->pr_send(rtso, m, NULL, NULL, curlwp);
#else
	rv = rtso->so_proto->pr_output(m, rtso);
#endif
	sounlock(rtso);

	return rv;
}

/* Perform IPv6 autoconfiguration for the specified interface.
 * This function sets the kernel to accept IPv6 RAs on all interfaces,
 * brings the interface up and sends a single IPv6 RS packet to the
 * all-routers multicast address from the specified interface. No attempt is
 * made to check whether or not this actually provoked an RA in response.
 */

int
rump_netconfig_auto_ipv6(const char *ifname)
{
	struct ifnet *ifp;
	int ifindex;
	struct socket *rsso = NULL;
	int rv = 0;
	int hoplimit = 255;
	struct mbuf *m_nam = NULL,
		    *m_outbuf = NULL;
	struct sockaddr_in6 *sin6;
	char *buf;
	struct nd_router_solicit rs;
	struct nd_opt_hdr opt;

	ifp = ifunit(ifname);
	if (ifp == NULL) {
		rv = ENXIO;
		goto out;
	}
	if (ifp->if_sadl->sdl_type != IFT_ETHER) {
		rv = EINVAL;
		goto out;
	}

	rv = socreate(PF_INET6, &rsso, SOCK_RAW, IPPROTO_ICMPV6, curlwp, NULL);
	if (rv != 0)
		goto out;
	ifindex = ifp->if_index;
	rv = so_setsockopt(curlwp, rsso, IPPROTO_IPV6, IPV6_MULTICAST_IF,
			&ifindex, sizeof ifindex);
	if (rv != 0)
		goto out;
	rv = so_setsockopt(curlwp, rsso, IPPROTO_IPV6, IPV6_MULTICAST_HOPS,
			&hoplimit, sizeof hoplimit);
	if (rv != 0)
		goto out;

	m_nam = m_get(M_WAIT, MT_SONAME);
	sin6 = mtod(m_nam, struct sockaddr_in6 *);
	sin6->sin6_len = m_nam->m_len = sizeof (*sin6);
	sin6->sin6_family = AF_INET6;
	netconfig_inet_pton6("ff02::2", &sin6->sin6_addr);

#define rslen (sizeof rs + sizeof opt + ETHER_ADDR_LEN)
	CTASSERT(rslen <= MCLBYTES);
	m_outbuf = m_gethdr(M_WAIT, MT_DATA);
	m_clget(m_outbuf, M_WAIT);
	m_outbuf->m_pkthdr.len = m_outbuf->m_len = rslen;


#if __NetBSD_Prereq__(7,99,31)
	m_set_rcvif(m_outbuf, NULL);
#else
	m_outbuf->m_pkthdr.rcvif = NULL;
#endif

#undef rslen
	buf = mtod(m_outbuf, char *);
	memset(&rs, 0, sizeof rs);
	rs.nd_rs_type = ND_ROUTER_SOLICIT;
	memset(&opt, 0, sizeof opt);
	opt.nd_opt_type = ND_OPT_SOURCE_LINKADDR;
	opt.nd_opt_len = 1; /* units of 8 octets */
	memcpy(buf, &rs, sizeof rs);
	buf += sizeof rs;
	memcpy(buf, &opt, sizeof opt);
	buf += sizeof opt;
	memcpy(buf, CLLADDR(ifp->if_sadl), ETHER_ADDR_LEN);

	ip6_accept_rtadv = 1;
	rv = rump_netconfig_ifup(ifname);
	if (rv != 0)
		goto out;
#if __NetBSD_Prereq__(7,99,12)
	rv = (*rsso->so_send)(rsso, (struct sockaddr *)sin6, NULL, m_outbuf,
			NULL, 0, curlwp);
#else
	rv = (*rsso->so_send)(rsso, m_nam, NULL, m_outbuf, NULL, 0, curlwp);
#endif
	if (rv == 0)
		/* *(so_send)() takes ownership of m_outbuf on success */
		m_outbuf = NULL;
	else
		goto out;

	rv = 0;
out:
	if (m_nam)
		m_freem(m_nam);
	if (m_outbuf)
		m_freem(m_outbuf);
	if (rsso)
		soclose(rsso);
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

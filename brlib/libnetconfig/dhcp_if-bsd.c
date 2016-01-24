/* 
 * dhcpcd - DHCP client daemon
 * Copyright (c) 2013 Antti Kantee <pooka@iki.fi>
 * Copyright (c) 2006-2010 Roy Marples <roy@marples.name>
 * All rights reserved

 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#include <sys/ioctl.h>
#include <sys/param.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/socket.h>
#include <sys/socketvar.h>
#include <sys/sysctl.h>

#include <net/if.h>
#include <net/if_dl.h>
#include <net/route.h>
#include <netinet/in.h>

#include <net80211/ieee80211_ioctl.h>

#include <rump/rump.h>

#include "dhcp_common.h"
#include "dhcp_configure.h"
#include "dhcp_dhcp.h"
#include "dhcp_if-options.h"
#include "dhcp_net.h"

/* FIXME: Why do we need to check for sa_family 255 */
#define COPYOUT(sin, sa)						      \
	sin.s_addr = ((sa) != NULL) ?					      \
	    (((struct sockaddr_in *)(void *)sa)->sin_addr).s_addr : 0

static struct socket *routeso;

int
if_init(struct interface *iface)
{
	/* BSD promotes secondary address by default */
	return 0;
}

int
if_conf(struct interface *iface)
{
	/* No extra checks needed on BSD */
	return 0;
}

int
init_sockets(void)
{
	int error;

	if ((error = socreate(PF_INET, &socket_afnet, SOCK_DGRAM, 0,
	    curlwp, NULL)) != 0)
		return error;
	if ((error = socreate(PF_ROUTE, &routeso, SOCK_RAW, 0,
	    curlwp, NULL)) != 0)
		return error;
	return 0;
}

int
getifssid(const char *ifname, char *ssid)
{
	struct ifreq ifr;
	struct ieee80211_nwid nwid;
	int error;

	memset(&ifr, 0, sizeof(ifr));
	strlcpy(ifr.ifr_name, ifname, sizeof(ifr.ifr_name));
	memset(&nwid, 0, sizeof(nwid));
	ifr.ifr_data = (void *)&nwid;
	if ((error = ifioctl(socket_afnet,
	    SIOCG80211NWID, &ifr, curlwp)) == 0) {
		memcpy(ssid, nwid.i_nwid, nwid.i_len);
		ssid[nwid.i_len] = '\0';
	}

	return error;
}

int
if_address(const struct interface *iface, const struct in_addr *address,
    const struct in_addr *netmask, const struct in_addr *broadcast,
    int action)
{
	int retval;
	struct ifaliasreq ifa;
	union {
		struct sockaddr *sa;
		struct sockaddr_in *sin;
	} _s;

	memset(&ifa, 0, sizeof(ifa));
	strlcpy(ifa.ifra_name, iface->name, sizeof(ifa.ifra_name));

#define ADDADDR(_var, _addr) {						      \
		_s.sa = &_var;						      \
		_s.sin->sin_family = AF_INET;				      \
		_s.sin->sin_len = sizeof(*_s.sin);			      \
		memcpy(&_s.sin->sin_addr, _addr, sizeof(_s.sin->sin_addr));   \
	}

	ADDADDR(ifa.ifra_addr, address);
	ADDADDR(ifa.ifra_mask, netmask);
	if (action >= 0 && broadcast) {
		ADDADDR(ifa.ifra_broadaddr, broadcast);
	}
#undef ADDADDR

	if (action < 0)
		retval = ifioctl(socket_afnet, SIOCDIFADDR, &ifa, curlwp);
	else
		retval = ifioctl(socket_afnet, SIOCAIFADDR, &ifa, curlwp);
	return retval;
}

/* ARGSUSED4 */
int
if_route(const struct interface *iface, const struct in_addr *dest,
    const struct in_addr *net, const struct in_addr *gate,
    int metric, int action)
{
	int error;

	union sockunion {
		struct sockaddr sa;
		struct sockaddr_in sin;
#ifdef INET6
		struct sockaddr_in6 sin6;
#endif
		struct sockaddr_dl sdl;
		struct sockaddr_storage ss;
	} su;
	struct rtm 
	{
		struct rt_msghdr hdr;
		char buffer[sizeof(su) * 4];
	} rtm;
	char *bp = rtm.buffer, *p;
	size_t l;
	struct mbuf *m;

#define ADDSU(_su) {							      \
		l = RT_ROUNDUP(_su.sa.sa_len);				      \
		memcpy(bp, &(_su), l);					      \
		bp += l;						      \
	}
#define ADDADDR(_a) {							      \
		memset (&su, 0, sizeof(su));				      \
		su.sin.sin_family = AF_INET;				      \
		su.sin.sin_len = sizeof(su.sin);			      \
		memcpy (&su.sin.sin_addr, _a, sizeof(su.sin.sin_addr));	      \
		ADDSU(su);						      \
	}

	memset(&rtm, 0, sizeof(rtm));
	rtm.hdr.rtm_version = RTM_VERSION;
	rtm.hdr.rtm_seq = 1;
	if (action == 0)
		rtm.hdr.rtm_type = RTM_CHANGE;
	else if (action > 0)
		rtm.hdr.rtm_type = RTM_ADD;
	else {
		rtm.hdr.rtm_type = RTM_DELETE;
		/* shortcircuit a bit for now */
		return 0;
	}
	rtm.hdr.rtm_flags = RTF_UP;
	/* None interface subnet routes are static. */
	if (gate->s_addr != INADDR_ANY ||
	    net->s_addr != iface->net.s_addr ||
	    dest->s_addr != (iface->addr.s_addr & iface->net.s_addr))
		rtm.hdr.rtm_flags |= RTF_STATIC;
	rtm.hdr.rtm_addrs = RTA_DST | RTA_GATEWAY;
	if (dest->s_addr == gate->s_addr && net->s_addr == INADDR_BROADCAST)
		rtm.hdr.rtm_flags |= RTF_HOST;
	else {
		rtm.hdr.rtm_addrs |= RTA_NETMASK;
		if (rtm.hdr.rtm_flags & RTF_STATIC)
			rtm.hdr.rtm_flags |= RTF_GATEWAY;
		if (action >= 0)
			rtm.hdr.rtm_addrs |= RTA_IFA;
	}

	ADDADDR(dest);
	if (rtm.hdr.rtm_flags & RTF_HOST ||
	    !(rtm.hdr.rtm_flags & RTF_STATIC))
	{
		/* Make us a link layer socket for the host gateway */
		memset(&su, 0, sizeof(su));
		memcpy(&su.sdl, iface->ifp->if_sadl, sizeof(su.sdl));
		ADDSU(su);
	} else {
		ADDADDR(gate);
	}

	if (rtm.hdr.rtm_addrs & RTA_NETMASK) {
		/* Ensure that netmask is set correctly */
		memset(&su, 0, sizeof(su));
		su.sin.sin_family = AF_INET;
		su.sin.sin_len = sizeof(su.sin);
		memcpy(&su.sin.sin_addr, &net->s_addr, sizeof(su.sin.sin_addr));
		p = su.sa.sa_len + (char *)&su;
		for (su.sa.sa_len = 0; p > (char *)&su;)
			if (*--p != 0) {
				su.sa.sa_len = 1 + p - (char *)&su;
				break;
			}
		ADDSU(su);
	}

	if (rtm.hdr.rtm_addrs & RTA_IFA)
		ADDADDR(&iface->addr);

	m = m_gethdr(M_WAIT, MT_DATA);
	m->m_pkthdr.len = rtm.hdr.rtm_msglen = l = bp - (char *)&rtm;
	m->m_len = 0;
	m_copyback(m, 0, l, &rtm);

	/* XXX: no check */
	solock(routeso);
#if __NetBSD_Prereq__(7,99,26)
	error = routeso->so_proto->pr_usrreqs->pr_send(routeso,
	    m, NULL, NULL, curlwp);
#else
	error = routeso->so_proto->pr_output(m, routeso);
#endif
	sounlock(routeso);

	return error;
}

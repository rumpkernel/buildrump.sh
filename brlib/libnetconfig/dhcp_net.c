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

#include <sys/param.h>
#include <sys/cprng.h>
#include <sys/ioctl.h>
#include <sys/kmem.h>
#include <sys/param.h>
#include <sys/socket.h>
#include <sys/time.h>

#include <net/if.h>
#include <net/if_arp.h>
#include <net/if_dl.h>
#include <net/if_types.h>
#include <netinet/in_systm.h>
#include <netinet/in.h>
#include <netinet/ip.h>
#include <netinet/udp.h>
#include <net/if_media.h>

#include "dhcp_common.h"
#include "dhcp_dhcp.h"
#include "dhcp_if-options.h"
#include "dhcp_net.h"

static char hwaddr_buffer[(HWADDR_LEN * 3) + 1];

struct socket *socket_afnet;

int
inet_ntocidr(struct in_addr address)
{
	int cidr = 0;
	uint32_t mask = htonl(address.s_addr);

	while (mask) {
		cidr++;
		mask <<= 1;
	}
	return cidr;
}

int
inet_cidrtoaddr(int cidr, struct in_addr *addr)
{
	int ocets;

	if (cidr < 1 || cidr > 32) {
		return EINVAL;
	}
	ocets = (cidr + 7) / 8;

	addr->s_addr = 0;
	if (ocets > 0) {
		memset(&addr->s_addr, 255, (size_t)ocets - 1);
		memset((unsigned char *)&addr->s_addr + (ocets - 1),
		    (256 - (1 << (32 - cidr) % 8)), 1);
	}

	return 0;
}

uint32_t
get_netmask(uint32_t addr)
{
	uint32_t dst;

	if (addr == 0)
		return 0;

	dst = htonl(addr);
	if (IN_CLASSA(dst))
		return ntohl(IN_CLASSA_NET);
	if (IN_CLASSB(dst))
		return ntohl(IN_CLASSB_NET);
	if (IN_CLASSC(dst))
		return ntohl(IN_CLASSC_NET);

	return 0;
}

char *
hwaddr_ntoa(const unsigned char *hwaddr, size_t hwlen)
{
	char *p = hwaddr_buffer;
	size_t i;

	for (i = 0; i < hwlen && i < HWADDR_LEN; i++) {
		if (i > 0)
			*p ++= ':';
		p += snprintf(p, 3, "%.2x", hwaddr[i]);
	}

	*p ++= '\0';

	return hwaddr_buffer;
}

size_t
hwaddr_aton(unsigned char *buffer, const char *addr)
{
	char c[3];
	const char *p = addr;
	unsigned char *bp = buffer;
	size_t len = 0;

	c[2] = '\0';
	while (*p) {
		c[0] = *p++;
		c[1] = *p++;
		/* Ensure that digits are hex */
		if (isxdigit((unsigned char)c[0]) == 0 ||
		    isxdigit((unsigned char)c[1]) == 0)
		{
			return EINVAL;
		}
		/* We should have at least two entries 00:01 */
		if (len == 0 && *p == '\0') {
			return EINVAL;
		}
		/* Ensure that next data is EOL or a seperator with data */
		if (!(*p == '\0' || (*p == ':' && *(p + 1) != '\0'))) {
			return EINVAL;
		}
		if (*p)
			p++;
		if (bp)
			*bp++ = (unsigned char)strtoll(c, NULL, 16);
		len++;
	}
	return len;
}

int
init_interface(const char *ifname, struct interface **ifacep)
{
	struct ifnet *ifp;
	struct ifreq ifr;
	struct interface *iface = NULL;
	int error;

	ifp = ifunit(ifname);
	if (!ifp)
		return EXDEV;

	memset(&ifr, 0, sizeof(ifr));
	strlcpy(ifr.ifr_name, ifname, sizeof(ifr.ifr_name));
	if ((error = ifioctl(socket_afnet, SIOCGIFFLAGS, &ifr, curlwp)) != 0)
		goto eexit;

	iface = kmem_zalloc(sizeof(*iface), KM_SLEEP);
	strlcpy(iface->name, ifname, sizeof(iface->name));
	iface->ifp = ifp;
	iface->flags = ifr.ifr_flags;
	/* We reserve the 100 range for virtual interfaces, if and when
	 * we can work them out. */
	iface->metric = 200 + iface->ifp->if_index;
	if (getifssid(ifname, iface->ssid) == 0) {
		iface->wireless = 1;
		iface->metric += 100;
	}

	if (ifioctl(socket_afnet, SIOCGIFMTU, &ifr, curlwp) != 0)
		goto eexit;
	/* Ensure that the MTU is big enough for DHCP */
	if (ifr.ifr_mtu < MTU_MIN) {
		ifr.ifr_mtu = MTU_MIN;
		strlcpy(ifr.ifr_name, ifname, sizeof(ifr.ifr_name));
		if ((error = ifioctl(socket_afnet,
		    SIOCSIFMTU, &ifr, curlwp)) != 0)
			goto eexit;
	}

	/* 0 is a valid fd, so init to -1 */
	iface->raw_fd = -1;
	iface->udp_fd = -1;
	iface->arp_fd = -1;

 eexit:
	if (error) {
		kmem_free(iface, sizeof(*iface));
		iface = NULL;
	}

	*ifacep = iface;
	return error;
}

int
carrier_status(struct interface *iface)
{
	int ret;
	struct ifreq ifr;
	struct ifmediareq ifmr;

	memset(&ifr, 0, sizeof(ifr));
	strlcpy(ifr.ifr_name, iface->name, sizeof(ifr.ifr_name));

	if ((ret = ifioctl(socket_afnet, SIOCGIFFLAGS, &ifr, curlwp)) != 0)
		return ret;
	iface->flags = ifr.ifr_flags;

	ret = -1;
	memset(&ifmr, 0, sizeof(ifmr));
	strlcpy(ifmr.ifm_name, iface->name, sizeof(ifmr.ifm_name));
	if (ifioctl(socket_afnet, SIOCGIFMEDIA, &ifmr, curlwp) == 0 &&
	    ifmr.ifm_status & IFM_AVALID)
		ret = (ifmr.ifm_status & IFM_ACTIVE) ? 1 : 0;
	if (ret != 0)
		ret = (ifr.ifr_flags & IFF_RUNNING) ? 1 : 0;
	return ret;
}

void
up_interface(struct interface *iface)
{

	if_up(iface->ifp);
}

int
do_address(const char *ifname,
    struct in_addr *addr, struct in_addr *net, struct in_addr *dst, int act)
{
	const struct sockaddr_in *a, *n, *d;
	struct ifnet *ifp = ifunit(ifname);
	struct ifaddr *ifa;
	int retval;

	if (ifp == NULL)
		return 0;

	retval = 0;
	IFADDR_FOREACH(ifa, ifp) {
		if (ifa->ifa_addr->sa_family != AF_INET)
			continue;

		a = (const struct sockaddr_in *)(void *)ifa->ifa_addr;
		n = (const struct sockaddr_in *)(void *)ifa->ifa_netmask;
		if (ifa->ifa_flags & IFF_POINTOPOINT)
			d = (const struct sockaddr_in *)(void *)
			    ifa->ifa_dstaddr;
		else
			d = NULL;
		if (act == 1) {
			addr->s_addr = a->sin_addr.s_addr;
			net->s_addr = n->sin_addr.s_addr;
			if (dst) {
				if (ifa->ifa_flags & IFF_POINTOPOINT)
					dst->s_addr = d->sin_addr.s_addr;
				else
					dst->s_addr = INADDR_ANY;
			}
			retval = 1;
			break;
		}
		if (addr->s_addr == a->sin_addr.s_addr &&
		    (net == NULL || net->s_addr == n->sin_addr.s_addr))
		{
			retval = 1;
			break;
		}
	}

	return retval;
}

int
do_mtu(const char *ifname, short int mtu)
{
	struct ifreq ifr;

	memset(&ifr, 0, sizeof(ifr));
	strlcpy(ifr.ifr_name, ifname, sizeof(ifr.ifr_name));
	ifr.ifr_mtu = mtu;
	if (ifioctl(socket_afnet, mtu ? SIOCSIFMTU : SIOCGIFMTU, &ifr, curlwp))
		return -1;
	return ifr.ifr_mtu;
}

void
free_routes(struct rt *routes)
{
	struct rt *r;

	while (routes) {
		r = routes->next;
		kmem_free(routes, sizeof(*r));
		routes = r;
	}
}

struct udp_dhcp_packet
{
	struct ip ip;
	struct udphdr udp;
	struct dhcp_message dhcp;
};
const size_t udp_dhcp_len = sizeof(struct udp_dhcp_packet);

static uint16_t
checksum(const void *data, uint16_t len)
{
	const uint8_t *addr = data;
	uint32_t sum = 0;

	while (len > 1) {
		sum += addr[0] * 256 + addr[1];
		addr += 2;
		len -= 2;
	}

	if (len == 1)
		sum += *addr * 256;

	sum = (sum >> 16) + (sum & 0xffff);
	sum += (sum >> 16);

	sum = htons(sum);

	return ~sum;
}

ssize_t
make_udp_packet(uint8_t **packet, const uint8_t *data, size_t length,
    struct in_addr source, struct in_addr dest)
{
	struct udp_dhcp_packet *udpp;
	struct ip *ip;
	struct udphdr *udp;

	udpp = kmem_zalloc(sizeof(*udpp), KM_SLEEP);
	ip = &udpp->ip;
	udp = &udpp->udp;

	/* OK, this is important :)
	 * We copy the data to our packet and then create a small part of the
	 * ip structure and an invalid ip_len (basically udp length).
	 * We then fill the udp structure and put the checksum
	 * of the whole packet into the udp checksum.
	 * Finally we complete the ip structure and ip checksum.
	 * If we don't do the ordering like so then the udp checksum will be
	 * broken, so find another way of doing it! */

	memcpy(&udpp->dhcp, data, length);

	ip->ip_p = IPPROTO_UDP;
	ip->ip_src.s_addr = source.s_addr;
	if (dest.s_addr == 0)
		ip->ip_dst.s_addr = INADDR_BROADCAST;
	else
		ip->ip_dst.s_addr = dest.s_addr;

	udp->uh_sport = htons(DHCP_CLIENT_PORT);
	udp->uh_dport = htons(DHCP_SERVER_PORT);
	udp->uh_ulen = htons(sizeof(*udp) + length);
	ip->ip_len = udp->uh_ulen;
	udp->uh_sum = checksum(udpp, sizeof(*udpp));

	ip->ip_v = IPVERSION;
	ip->ip_hl = sizeof(*ip) >> 2;
	ip->ip_id = cprng_fast32() & UINT16_MAX;
	ip->ip_ttl = IPDEFTTL;
	ip->ip_len = htons(sizeof(*ip) + sizeof(*udp) + length);
	ip->ip_sum = checksum(ip, sizeof(*ip));

	*packet = (uint8_t *)udpp;
	return sizeof(*ip) + sizeof(*udp) + length;
}

ssize_t
get_udp_data(const uint8_t **data, const uint8_t *udp)
{
	struct udp_dhcp_packet packet;

	memcpy(&packet, udp, sizeof(packet));
	*data = udp + offsetof(struct udp_dhcp_packet, dhcp);
	return ntohs(packet.ip.ip_len) -
	    sizeof(packet.ip) -
	    sizeof(packet.udp);
}

int
valid_udp_packet(const uint8_t *data, size_t data_len, struct in_addr *from)
{
	struct udp_dhcp_packet packet;
	uint16_t bytes, udpsum;

	if (data_len < sizeof(packet.ip)) {
		if (from)
			from->s_addr = INADDR_ANY;
		return EINVAL;
	}
	memcpy(&packet, data, MIN(data_len, sizeof(packet)));
	if (from)
		from->s_addr = packet.ip.ip_src.s_addr;
	if (data_len > sizeof(packet)) {
		return EINVAL;
	}
	if (checksum(&packet.ip, sizeof(packet.ip)) != 0) {
		return EINVAL;
	}

	bytes = ntohs(packet.ip.ip_len);
	if (data_len < bytes) {
		return EINVAL;
	}
	udpsum = packet.udp.uh_sum;
	packet.udp.uh_sum = 0;
	packet.ip.ip_hl = 0;
	packet.ip.ip_v = 0;
	packet.ip.ip_tos = 0;
	packet.ip.ip_len = packet.udp.uh_ulen;
	packet.ip.ip_id = 0;
	packet.ip.ip_off = 0;
	packet.ip.ip_ttl = 0;
	packet.ip.ip_sum = 0;
	if (udpsum && checksum(&packet, bytes) != udpsum) {
		return EINVAL;
	}

	return 0;
}

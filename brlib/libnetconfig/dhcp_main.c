/*	$NetBSD: main.c,v 1.3 2011/09/16 15:39:28 joerg Exp $	*/

/*-
 * Copyright (c) 2011, 2013 Antti Kantee.  All Rights Reserved.
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
#include <sys/cprng.h>
#include <sys/ioctl.h>
#include <sys/kernel.h>
#include <sys/kmem.h>
#include <sys/poll.h>
#include <sys/socket.h>
#include <sys/socketvar.h>
#include <sys/sysctl.h>

#include <net/if.h>
#include <net/if_dl.h>

#include <rump/rump.h>

#include "dhcp_configure.h"
#include "dhcp_dhcp.h"
#include "dhcp_net.h"
#include "rump_private.h"
#include "rumpkern_if_priv.h"
#include "netconfig_if_priv.h"

struct interface *ifaces;

int
get_hwaddr(struct interface *iface)
{
	struct if_laddrreq iflr;
	struct sockaddr_dl *sdl;
	struct socket *slink;
	int error;

	memset(&iflr, 0, sizeof(iflr));
	strlcpy(iflr.iflr_name, iface->name, sizeof(iflr.iflr_name));
	iflr.addr.ss_family = AF_LINK;

	sdl = satosdl(&iflr.addr);
	sdl->sdl_alen = ETHER_ADDR_LEN;

	if ((error = socreate(AF_LINK, &slink, SOCK_DGRAM, 0,
	    curlwp, NULL)) != 0)
		return error;

	if ((error = ifioctl(slink, SIOCGLIFADDR, &iflr, curlwp)) != 0) {
		soclose(slink);
		return error;
	}

	/* XXX: is that the right way to copy the link address? */
	memcpy(iface->hwaddr, sdl->sdl_data+strlen(iface->name), ETHER_ADDR_LEN);
	iface->hwlen = ETHER_ADDR_LEN;
	iface->family = ARPHRD_ETHER;

	soclose(slink);
	return 0;
}

static int
send_discover(struct interface *iface)
{
	struct dhcp_message *dhcp;
	uint8_t *udp;
	ssize_t mlen, ulen;
	struct in_addr ia;
	int error;

	memset(&ia, 0, sizeof(ia));

	mlen = make_message(&dhcp, iface, DHCP_DISCOVER);
	ulen = make_udp_packet(&udp, (void *)dhcp, mlen, ia, ia);
	if ((error = dhcp_send_raw_packet(iface, ETHERTYPE_IP, udp, ulen)) != 0)
		printf("dhcp: sending discover failed\n");
	return error;
}

static int
send_request(struct interface *iface)
{
	struct dhcp_message *dhcp;
	uint8_t *udp;
	ssize_t mlen, ulen;
	struct in_addr ia;
	int error;

	memset(&ia, 0, sizeof(ia));

	mlen = make_message(&dhcp, iface, DHCP_REQUEST);
	ulen = make_udp_packet(&udp, (void *)dhcp, mlen, ia, ia);
	if ((error = dhcp_send_raw_packet(iface, ETHERTYPE_IP, udp, ulen)) != 0)
		printf("dhcp: sending discover failed\n");
	return error;
}

/* wait for 5s by default */
#define RESPWAIT 5
static bool
get_network(struct interface *iface, uint8_t *raw,
	const struct dhcp_message **dhcpp)
{
	struct pollfd pfd;
	const struct dhcp_message *dhcp;
	const uint8_t *data;
	ssize_t n;

	pfd.fd = iface->raw_fd;
	pfd.events = POLLIN;

	for (;;) {
		register_t rv[2];
		struct timespec ts;

		ts.tv_sec = RESPWAIT;
		ts.tv_nsec = 0;

		if (pollcommon(rv, &pfd, 1, &ts, NULL) != 0 || rv[0] != 1) {
			printf("dhcp get: timed out waiting for response.\n");
			return false;
		}
			
		if ((n = dhcp_get_raw_packet(iface, ETHERTYPE_IP,
		    raw, udp_dhcp_len)) < 1)
			continue;

		if (valid_udp_packet(raw, n, NULL) != 0) {
			printf("dhcp get: invalid packet received. retrying\n");
			continue;
		}

		n = get_udp_data(&data, raw);
		if ((size_t)n > sizeof(*dhcp)) {
			printf("dhcp get: invalid packet size. retrying\n");
			continue;
		}
		dhcp = (const void *)data;

		/* XXX: what if packet is too small? */

		/* some sanity checks */
		if (dhcp->cookie != htonl(MAGIC_COOKIE)) {
			/* ignore */
			continue;
		}

		if (iface->state->xid != dhcp->xid) {
			printf("dhcp get: invalid transaction. retrying\n");
			continue;
		}

		break;
	}

	*dhcpp = dhcp;
	return true;
}

static bool
get_offer(struct interface *iface)
{
	const struct dhcp_message *dhcp;
	uint8_t *raw;
	uint8_t type;

	raw = kmem_alloc(udp_dhcp_len, KM_SLEEP);
	if (!get_network(iface, raw, &dhcp))
		return false;

	get_option_uint8(&type, dhcp, DHO_MESSAGETYPE);
	switch (type) {
	case DHCP_OFFER:
		if (get_option_addr(&iface->state->lease.server,
		    dhcp, DHO_SERVERID) != 0)
			iface->state->lease.server.s_addr = INADDR_ANY;
		break;
	case DHCP_NAK:
		printf("dhcp: got NAK from dhcp server\n");
		return false;
	default:
		printf("dhcp: didn't receive offer\n");
		return false;
	}

	iface->state->offer = kmem_alloc(sizeof(*iface->state->offer),
	    KM_SLEEP);
	memcpy(iface->state->offer, dhcp, sizeof(*iface->state->offer));
	iface->state->lease.addr.s_addr = dhcp->yiaddr;
	iface->state->lease.cookie = dhcp->cookie;
	kmem_free(raw, udp_dhcp_len);

	return true;
}

static bool
get_ack(struct interface *iface)
{
	const struct dhcp_message *dhcp;
	uint8_t *raw;
	uint8_t type;

	raw = kmem_alloc(udp_dhcp_len, KM_SLEEP);
	get_network(iface, raw, &dhcp);
	get_option_uint8(&type, dhcp, DHO_MESSAGETYPE);
	if (type != DHCP_ACK) {
		printf("dhcp: didn't receive ack\n");
		return false;
	}

	iface->state->new = iface->state->offer;
	get_lease(&iface->state->lease, iface->state->new);
	kmem_free(raw, udp_dhcp_len);

	return true;
}

/* since we do essentially mi_switch() here, cannot use curlwp directly */
#define mycurlwp curcpu()->ci_curlwp

/*
 * release our called.  called at reboot-time.  we use the original
 * proc/lwp context here to avoid having to open new file descriptors.
 */
static void
send_release(void *arg)
{
	struct interface *iface = ifaces;
	struct dhcp_message *dhcp;
	uint8_t *udp;
	ssize_t mlen, ulen;
	struct in_addr ia;
	struct lwp *origlwp = mycurlwp;

	rump__lwproc_lwphold();
	rump_lwproc_switch(arg);

	memset(&ia, 0, sizeof(ia));

	mlen = make_message(&dhcp, iface, DHCP_RELEASE);
	ulen = make_udp_packet(&udp, (void *)dhcp, mlen, ia, ia);
	dhcp_send_raw_packet(iface, ETHERTYPE_IP, udp, ulen);

	/* give it a chance to fly (rump kernel will exit) */
	kpause("dhcprel", false, 1, NULL);

	/* release the DHCP process */
	rump_lwproc_releaselwp();

	rump_lwproc_switch(origlwp);
	rump__lwproc_lwprele();
}

/*
 * Configure an address for one interface.  Not very robust and
 * does not clean up after itself.
 */
#define MAXTRIES 10
int
rump_netconfig_dhcp_ipv4_oneshot(const char *ifname)
{
	struct interface *iface;
	struct if_options *ifo;
	struct lwp *origlwp = mycurlwp;
	int error, tries = 0;
	bool rv;

	/*
	 * first, create ourselves a new process context, since we're
	 * going to be opening file descriptors
	 */
	rump__lwproc_lwphold();
	rump_lwproc_rfork(RUMP_RFCFDG);

	if ((error = init_sockets()) != 0) {
		printf("failed to init sockets\n");
		goto out;
	}

	if ((error = init_interface(ifname, &iface)) != 0) {
		printf("cannot init %s (%d)\n", ifname, error);
		goto out;
	}
	rump_netconfig_ifup(ifname);
	ifaces = iface;
	if ((error = dhcp_open_socket(iface, ETHERTYPE_IP)) != 0)
		panic("failed to open socket: %d", error);

	up_interface(iface);

	iface->state = kmem_zalloc(sizeof(*iface->state), KM_SLEEP);
	iface->state->options = ifo
	    = kmem_zalloc(sizeof(*iface->state->options), KM_SLEEP);
	iface->state->xid = cprng_fast32();

	strlcpy(ifo->hostname, hostname, sizeof(ifo->hostname));
	ifo->options = DHCPCD_GATEWAY | DHCPCD_HOSTNAME;

	if ((error = get_hwaddr(iface)) != 0) {
		printf("failed to get hwaddr for %s\n", iface->name);
		goto out;
	}

	for (rv = false; !rv && tries < MAXTRIES; tries++) {
		if (send_discover(iface) != 0) {
			kpause("dhcpdis", false, hz, NULL);
			continue;
		}
		rv = get_offer(iface);
	}
	if (!rv) {
		error = EADDRNOTAVAIL; /* heh heh heh */
		goto out;
	}

	for (rv = false, tries = 0; !rv && tries < MAXTRIES; tries++) {
		if (send_request(iface) != 0) {
			kpause("dhcpreq", false, hz, NULL);
			continue;
		}

		rv = get_ack(iface);
	}
	if (!rv) {
		error = EADDRNOTAVAIL; /* hoh hoh hoh */
		goto out;
	}

	error = configure(iface);
	if (!error)
		shutdownhook_establish(send_release, mycurlwp);
 out:
	rump_lwproc_switch(origlwp);
	rump__lwproc_lwprele();
	return error;
}

/*
 * dhcpcd - DHCP client daemon
 * Copyright (c) 2013 Antti Kantee <pooka@iki.fi>
 * Copyright (c) 2006-2008 Roy Marples <roy@marples.name>
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
#include <sys/conf.h>
#include <sys/ioctl.h>
#include <sys/fcntl.h>
#include <sys/file.h>
#include <sys/filedesc.h>
#include <sys/kmem.h>
#include <sys/lwp.h>
#include <sys/proc.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/uio.h>

#include <net/bpf.h>
#include <net/if.h>

#include "dhcp_common.h"
#include "dhcp_dhcp.h"
#include "dhcp_net.h"
#include "dhcp_bpf-filter.h"

int
dhcp_open_socket(struct interface *iface, int protocol)
{
	struct lwp *l = curlwp;
	struct file *fp;
	devmajor_t bpfmajor;
	struct ifreq ifr;
	int buf_len = 0;
	struct bpf_program pf;
	int flags, indx = -1;
	int error, fd;

	/* open bpf withouth going through vfs */
	bpfmajor = devsw_name2chr("bpf", NULL, 0);
	if (bpfmajor == NODEVMAJOR) {
		return EXDEV;
	}
	if ((error = cdev_open(makedev(bpfmajor, 0),
	    FREAD|FWRITE, S_IFCHR, curlwp)) != 0) {
		if (error == EMOVEFD && l->l_dupfd >= 0) {
			error = fd_dupopen(l->l_dupfd,
			    &indx, FREAD|FWRITE, error);
			if (error == 0)
				fd = indx;
		}
		if (error)
			return error;
	} else {
		panic("bpf changed?");
	}

	if ((fp = fd_getfile(fd)) == NULL)
		panic("file descriptor mismatch");

	memset(&ifr, 0, sizeof(ifr));
	strlcpy(ifr.ifr_name, iface->name, sizeof(ifr.ifr_name));
	if ((error = fp->f_ops->fo_ioctl(fp, BIOCSETIF, &ifr)) != 0)
		goto eexit;

	/* Get the required BPF buffer length from the kernel. */
	if ((error = fp->f_ops->fo_ioctl(fp, BIOCGBLEN, &buf_len)) != 0)
		goto eexit;
	if (iface->buffer_size != (size_t)buf_len) {
		if (iface->buffer_size)
			kmem_free(iface->buffer, iface->buffer_size);
		iface->buffer_size = buf_len;
		iface->buffer = kmem_alloc(buf_len, KM_SLEEP);
		iface->buffer_len = iface->buffer_pos = 0;
	}

	flags = 1;
	if ((error = fp->f_ops->fo_ioctl(fp, BIOCIMMEDIATE, &flags)) != 0)
		goto eexit;

	/* Install the DHCP filter */
	if (protocol == ETHERTYPE_ARP) {
		pf.bf_insns = UNCONST(arp_bpf_filter);
		pf.bf_len = arp_bpf_filter_len;
		iface->arp_fd = fd;
	} else {
		pf.bf_insns = UNCONST(dhcp_bpf_filter);
		pf.bf_len = dhcp_bpf_filter_len;
		iface->raw_fd = fd;
	}
	error = fp->f_ops->fo_ioctl(fp, BIOCSETF, &pf);

 eexit:
	if (error) {
		kmem_free(iface->buffer, iface->buffer_size);
		iface->buffer = NULL;
		iface->buffer_len = 0;
		iface->buffer_size = 0;
		fd_close(fd);
	} else {
		fd_putfile(fd);
	}
	return error;
}

int
dhcp_send_raw_packet(const struct interface *iface, int protocol,
    const void *data, ssize_t len)
{
	struct uio uio;
	struct iovec iov[2];
	struct file *fp;
	struct ether_header hw;
	int error;
	int fd;

	memset(&hw, 0, ETHER_HDR_LEN);
	memset(&hw.ether_dhost, 0xff, ETHER_ADDR_LEN);
	hw.ether_type = htons(protocol);
	iov[0].iov_base = &hw;
	iov[0].iov_len = ETHER_HDR_LEN;
	iov[1].iov_base = UNCONST(data);
	iov[1].iov_len = len;

	uio.uio_iov = iov;
	uio.uio_iovcnt = 2;
	uio.uio_rw = UIO_WRITE;
	uio.uio_vmspace = curproc->p_vmspace;
	uio.uio_resid = ETHER_HDR_LEN + len;

	if (protocol == ETHERTYPE_ARP)
		fd = iface->arp_fd;
	else
		fd = iface->raw_fd;

	if ((fp = fd_getfile(fd)) == NULL)
		panic("send_raw_pcaket: fd mismatch");

	error = fp->f_ops->fo_write(fp, 0, &uio, fp->f_cred, 0);

	fd_putfile(fd);
	return error;
}

/* BPF requires that we read the entire buffer.
 * So we pass the buffer in the API so we can loop on >1 packet. */
ssize_t
dhcp_get_raw_packet(struct interface *iface, int protocol,
    void *data, ssize_t len)
{
	struct file *fp;
	int fd = -1;
	struct bpf_hdr packet;
	ssize_t bytes;
	const unsigned char *payload;
	struct uio uio;
	int error;

	if (protocol == ETHERTYPE_ARP)
		fd = iface->arp_fd;
	else
		fd = iface->raw_fd;

	fp = fd_getfile(fd);
	for (;;) {
		if (iface->buffer_len == 0) {
			struct iovec iov;

			iov.iov_base = iface->buffer;
			iov.iov_len = iface->buffer_size;

			uio.uio_iov = &iov;
			uio.uio_iovcnt = 1;
			uio.uio_resid = iface->buffer_size;
			uio.uio_rw = UIO_READ;
			uio.uio_vmspace = curproc->p_vmspace;

			error = fp->f_ops->fo_read(fp, 0, &uio, fp->f_cred, 0);
			bytes = iface->buffer_size - uio.uio_resid;
			if (error != 0) {
				bytes = -1;
				break;
			} else if ((size_t)bytes < sizeof(packet)) {
				bytes = -1;
				break;
			}
			iface->buffer_len = bytes;
			iface->buffer_pos = 0;
		}
		bytes = -1;
		memcpy(&packet, iface->buffer + iface->buffer_pos,
		    sizeof(packet));
		if (packet.bh_caplen != packet.bh_datalen)
			goto next; /* Incomplete packet, drop. */
		if (iface->buffer_pos + packet.bh_caplen + packet.bh_hdrlen >
		    iface->buffer_len)
			goto next; /* Packet beyond buffer, drop. */
		payload = iface->buffer + packet.bh_hdrlen + ETHER_HDR_LEN;
		bytes = packet.bh_caplen - ETHER_HDR_LEN;
		if (bytes > len)
			bytes = len;
		memcpy(data, payload, bytes);
next:
		iface->buffer_pos += BPF_WORDALIGN(packet.bh_hdrlen +
		    packet.bh_caplen);
		if (iface->buffer_pos >= iface->buffer_len)
			iface->buffer_len = iface->buffer_pos = 0;
		if (bytes != -1)
			break;
	}
	fd_putfile(fd);

	return bytes;
}

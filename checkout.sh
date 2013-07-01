#! /usr/bin/env sh
#
# Copyright (c) 2013 Antti Kantee <pooka@iki.fi>
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS
# OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.
#

# Fetches NetBSD source tree from anoncvs.netbsd.org

# for fetching the sources
NBSRC_CVSDATE="20130515 2200UTC"
NBSRC_CVSFLAGS="-z3 \
    -d ${BUILDRUMP_CVSROOT:-:pserver:anoncvs@anoncvs.netbsd.org:/cvsroot}"

# Cherry-pick patches are not in $NBSRC_CVSDATE
# the format is "date1:dir1 dir2 dir3 ...;date2:dir 4..."
NBSRC_EXTRA='20130601 2100UTC:
    src/sys/rump/net/lib/libvirtif
    src/sys/rump/librump/rumpkern/rump.c
    src/sys/rump/net/lib/libnet
    src/sys/rump/net/lib/libnetinet
    src/sys/rump/include/rump
    src/sys/netinet/portalgo.c;
	20130610 1500UTC:
    src/sys/rump/librump/rumpvfs/rumpfs.c
    src/sys/rump/net/lib/libshmif;
	20130623 1930UTC:
    src/sys/rump/net/lib/libsockin;
	20130630 1715UTC:
    src/sys/rump/librump/rumpnet/net_stub.c
    src/sys/rump/net/lib/libnetinet/component.c'

die ()
{

	echo ">> $*"
	exit 1
}

checkoutcvs ()
{

	: ${CVS:=cvs}
	if ! type ${CVS} >/dev/null 2>&1 ;then
		echo '>> Need cvs for checkout-cvs functionality'
		echo '>> Set $CVS or ensure that cvs is in PATH'
		die \"${CVS}\" not found
	fi

	# squelch .cvspass whine
	export CVS_PASSFILE=/dev/null

	# we need listsrcdirs
	echo ">> Fetching the list of files we need to checkout ..."
	${CVS} ${NBSRC_CVSFLAGS} co -p -D "${NBSRC_CVSDATE}" \
	    src/sys/rump/listsrcdirs > listsrcdirs 2>/dev/null \
	    || die listsrcdirs checkout failed

	# trick cvs into "skipping" the module name so that we get
	# all the sources directly into $SRCDIR
	rm -f src
	ln -s . src

	# now, do the real checkout
	echo ">> Fetching the necessary subset of NetBSD source tree to:"
	echo "   "`pwd -P`
	echo '>> This will take a few minutes and requires ~200MB of disk space'
	sh listsrcdirs -c | xargs ${CVS} ${NBSRC_CVSFLAGS} co -P \
	    -D "${NBSRC_CVSDATE}" || die checkout failed

	IFS=';'
	for x in ${NBSRC_EXTRA}; do
		IFS=':'
		set -- ${x}
		unset IFS
		date=${1}
		dirs=${2}
		${CVS} ${NBSRC_CVSFLAGS} co -P -D "${date}" ${dirs} || die co2
	done

	# remove the symlink used to trick cvs
	rm -f src
	rm -f listsrcdirs
}

[ $# -ne 2 ] && die Invalid usage.  Run this script via buildrump.sh
[ "${1}" = "cvs" ] || die Invalid usage.  Run this script via buildrump.sh
SRCDIR=${2}

mkdir -p ${SRCDIR} || die cannot access ${SRCDIR}
cd ${SRCDIR}

checkoutcvs

echo '>> checkout done'

exit 0

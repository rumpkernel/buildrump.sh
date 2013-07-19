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

# Fetches subset of the NetBSD source tree relevant for buildrump.sh

#
#	NOTE!
#
# DO NOT CHANGE THE VALUES WITHOUT UPDATING THE GIT REPO!
#
# The procedure is:
# 1) change the cvs tags, commit the change, DO NOT PUSH
# 2) run "./checkout.sh githubdate rumpkernel-netbsd-src"
# 3) push rumpkernel-netbsd-src
# 4) push buildrump.sh
#
NBSRC_CVSDATE="20130719 1145UTC"
NBSRC_CVSFLAGS="-z3 \
    -d ${BUILDRUMP_CVSROOT:-:pserver:anoncvs@anoncvs.netbsd.org:/cvsroot}"

# Cherry-pick patches are not in $NBSRC_CVSDATE
# the format is "date1:dir1 dir2 dir3 ...;date2:dir 4..."
NBSRC_EXTRA=''

GITREPO='https://github.com/anttikantee/rumpkernel-netbsd-src'
GITREPOPUSH='git@github.com:anttikantee/rumpkernel-netbsd-src'
GITREVFILE='.srcgitrev'

die ()
{

	echo ">> $*"
	exit 1
}

checkoutcvs ()
{

	echo ">> Fetching NetBSD sources to ${SRCDIR} using cvs"

	: ${CVS:=cvs}
	if ! type ${CVS} >/dev/null 2>&1 ;then
		echo '>> Need cvs for checkoutcvs functionality'
		echo '>> Set $CVS or ensure that cvs is in PATH'
		die \"${CVS}\" not found
	fi

	mkdir -p ${SRCDIR} || die cannot access ${SRCDIR}
	cd ${SRCDIR} || die cannot access ${SRCDIR}

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

	# One silly workaround for case-insensitive file systems and cvs.
	# Both src/lib/libc/{DB,db} exist.  While the former is empty,
	# since DB exists when db is checked out, they go into the same
	# place.  So in case "DB" exists, rename it to "db" after cvs
	# is done with its business.
	[ -d lib/libc/DB ] && \
	    { mv lib/libc/DB lib/libc/db.tmp ; mv lib/libc/db.tmp lib/libc/db ;}

	# remove the symlink used to trick cvs
	rm -f src
	rm -f listsrcdirs
}

# Check out sources via git.  If there's already a git repo in the
# destination directory, assume that it's the correct repo.
checkoutgit ()
{

	echo ">> Fetching NetBSD sources to ${SRCDIR} using git"

	[ -e "${SRCDIR}" -a ! -e "${SRCDIR}/.git" ] && \
	    die Not a git repository: ${SRCDIR}

	gitrev=$(cat ${BRDIR}/${GITREVFILE})
	[ $? -eq 0 ] || die Cannot determine relevant git revision
	if [ -d ${SRCDIR}/.git ] ; then
		cd ${SRCDIR}
		[ -z "$(${GIT} status --porcelain)" ] \
		    || die "Cloned repo in ${SRCDIR} is not clean, aborting."
		${GIT} fetch origin master || die Failed to update git repo
	else
		${GIT} clone -n ${GITREPO} ${SRCDIR} || die Clone failed
		cd ${SRCDIR}
	fi

	${GIT} checkout ${gitrev} || \
	    die 'Could not checkout correct git revision. Wrong repo?'
}

# do a cvs checkout and push the results into the github mirror
githubdate ()
{

	[ -z "$(${GIT} status --porcelain | grep 'M checkout.sh')" ] \
	    || die checkout.sh contains uncommitted changes!
	gitrev=$(${GIT} rev-parse HEAD)

	[ -e ${SRCDIR} ] && die Error, ${SRCDIR} exists

	set -e

	${GIT} clone -n -b netbsd-cvs ${GITREPOPUSH} ${SRCDIR}

	echo '>> checking out source tree via anoncvs'
	# checkoutcvs does cd to SRCDIR
	curdir="$(pwd)"
	checkoutcvs

	echo '>> adding files to the "netbsd-cvs" branch'
	${GIT} add -A
	echo '>> committing'
	${GIT} commit -m "NetBSD cvs for buildrump.sh git rev ${gitrev}"
	echo '>> merging "netbsd-cvs" to "master"'
	${GIT} checkout master
	${GIT} merge netbsd-cvs
	gitsrcrev=$(${GIT} rev-parse HEAD)
	cd "${curdir}"
	echo ${gitsrcrev} > ${GITREVFILE}
	${GIT} commit -m "Source for buildrump.sh git rev ${gitrev}" \
	    ${GITREVFILE}

	set +e
}

setgit ()
{

	: ${GIT:=git}
	if ! type ${GIT} >/dev/null 2>&1 ;then
		echo '>> Need git for checkoutgit functionality'
		echo '>> Set $GIT or ensure that git is in PATH'
		die \"${GIT}\" not found
	fi
}

[ $# -ne 2 ] && die Invalid usage.  Run this script via buildrump.sh
BRDIR=$(dirname $0)
SRCDIR=${2}

case "${1}" in
cvs)
	checkoutcvs
	echo '>> checkout done'
	;;
git)
	setgit
	checkoutgit
	echo '>> checkout done'
	;;
githubdate)
	[ $(dirname $0) != '.' ] && die Script must be run as ./checkout.sh
	setgit
	githubdate
	echo '>>'
	echo '>> Update done'
	echo '>>'
	echo ">> REMEMBER TO PUSH ${SRCDIR}"
	echo '>>'
	;;
*)
	die Invalid usage.  Run this script via buildrump.sh
	;;
esac

exit 0

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
# (also, do not update NBSRC_CVSDATE for just a small fix, it
# causes changes to all CVS/Entries files)
#
# The procedure is:
# 1) change the cvs tags, commit the change, DO NOT PUSH
# 2) run "./checkout.sh githubdate rumpkernel-netbsd-src"
# 3) push rumpkernel-netbsd-src
# 4) push buildrump.sh
#
# The rationale for the procedure is to prevent "race conditions"
# where cvs/git can offer different checkouts and also to make sure
# that once buildrump.sh is published, the NetBSD sources will be
# available via git.
#
: ${BUILDRUMP_CVSROOT:=:pserver:anoncvs@anoncvs.netbsd.org:/cvsroot}
NBSRC_CVSDATE="20140526 1100UTC"
NBSRC_CVSFLAGS="-z3 -d ${BUILDRUMP_CVSROOT}"

# If set, timestamp for src/sys/rump/listsrcdir.  If unset,
# NBSRC_CVSDATE is used.
NBSRC_LISTDATE="20140708 1431UTC"

# Cherry-pick patches are not in $NBSRC_CVSDATE
# the format is "date1:dir1 dir2 dir3 ...;date2:dir 4..."
NBSRC_EXTRA='
    20140528 2100UTC:
	src/sys/rump/librump/rumpkern/emul.c
        src/sys/rump/net/lib/libshmif/if_shmem.c
        src/sys/rump/librump/rumpvfs/rumpfs.c
	src/sys/rump/dev/lib/libmiiphy/Makefile;
    20140613 1600UTC:
	src/lib/librumpvfs/rump_etfs.3
	src/sys/rump/include/rump/rump.h
	src/sys/rump/include/rump/rump_syscalls.h
	src/sys/rump/librump/rumpvfs/rumpfs.c
	src/sys/rump/librump/rumpdev/rump_dev.c;
    20140615 1440UTC:
	src/tools/Makefile
	src/lib/librumpuser/rumpuser_sp.c;
    20140620 1300UTC:
	src/sys/rump/librump/rumpvfs/devnodes.c
	src/sys/rump/Makefile.rump
	src/sys/rump/README.compileopts;
    20140622 2030UTC:
        src/lib/librumpuser/rumpuser_pth.c
        src/sys/rump/librump/rumpkern/intr.c;
    20140629 1140UTC:
	src/sys/rump/librump/rumpkern/rump.c'

GITREPO='https://github.com/rumpkernel/rumpkernel-netbsd-src'
GITREPOPUSH='git@github.com:rumpkernel/rumpkernel-netbsd-src'
GITREVFILE='.srcgitrev'

die ()
{

	echo '>>'
	echo ">> $*"
	echo '>>'
	exit 1
}

checkoutcvs ()
{

	# checkout or export
	case $1 in
	checkout)
		op=checkout
		prune=-P
		;;
	export)
		op=export
		prune=''
		;;
	*)
		die invalid cvs style $1
	esac
	shift

	case $1 in
	-r|-D)
		NBSRC_CVSPARAM=$1
		shift
		NBSRC_CVSREV=$*
		NBSRC_CVSLISTREV=$*
		NBSRC_EXTRA=''
		;;
	HEAD)
		NBSRC_CVSPARAM=''
		NBSRC_CVSREV=''
		NBSRC_CVSLISTREV=''
		NBSRC_EXTRA=''
		;;
	'')
		NBSRC_CVSPARAM=-D
		NBSRC_CVSREV="${NBSRC_CVSDATE}"
		NBSRC_CVSLISTREV="${NBSRC_LISTDATE:-${NBSRC_CVSDATE}}"
		;;
	*)
		die 'Invalid parameters to checkoutcvs'
		;;
	esac
		

	echo ">> Fetching NetBSD sources to ${SRCDIR} using CVS"
	echo ">> BUILDRUMP_CVSROOT is \"${BUILDRUMP_CVSROOT}\""

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
	${CVS} ${NBSRC_CVSFLAGS} co -p \
	    ${NBSRC_CVSPARAM} ${NBSRC_CVSLISTREV:+"${NBSRC_CVSLISTREV}"} \
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
	sh listsrcdirs -c | xargs ${CVS} ${NBSRC_CVSFLAGS} ${op} ${prune} \
	    ${NBSRC_CVSPARAM} ${NBSRC_CVSREV:+"${NBSRC_CVSREV}"} \
	      || die checkout failed

	IFS=';'
	for x in ${NBSRC_EXTRA}; do
		IFS=':'
		set -- ${x}
		unset IFS
		date=${1}
		dirs=${2}
		rm -rf ${dirs}
		${CVS} ${NBSRC_CVSFLAGS} ${op} ${prune} -D "${date}" ${dirs} \
		    || die subset updates failed
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

	${GIT} checkout -q ${gitrev} || \
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

	# checkoutcvs does cd to SRCDIR
	curdir="$(pwd)"
	checkoutcvs export

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

checkcheckout ()
{

	# if it's not a git repo, don't bother
	if [ ! -e "${SRCDIR}/.git" ]; then
		echo '>>'
		echo ">> NOTICE: Not a git repo in ${SRCDIR}"
		echo '>> Cannot verify repository version.  Proceeding ...'
		echo '>>'
		return 0
	fi

	setgit

	# if it's a git repo of the wrong version, issue an error
	# (caller can choose to ignore it if they so desire)
	gitrev_wanted=$(cat ${BRDIR}/${GITREVFILE})
	gitrev_actual=$( (cd ${SRCDIR} && ${GIT} rev-parse HEAD))
	if [ "${gitrev_wanted}" != "${gitrev_actual}" ]; then
		echo '>>'
		echo ">> ${SRCDIR} contains the wrong repo revision"
		echo '>> Did you forget to run checkout?'
		echo '>>'
		return 1
	fi

	# if it's an unclean git repo, issue a warning
	if [ ! -z "$( (cd ${SRCDIR} && ${GIT} status --porcelain))" ]; then
		echo '>>'
		echo ">> WARNING: repository in ${SRCDIR} is not clean"
		echo '>>'
		return 0
	fi

	return 0
}

listdates ()
{

	echo '>> Base date for NetBSD sources:'
	echo '>>' ${NBSRC_CVSDATE}
	[ -z "${NBSRC_EXTRA}" ] || printf '>>\n>> Overrides:\n'
	IFS=';'
	for x in ${NBSRC_EXTRA}; do
		IFS=':'
		set -- ${x}
		unset IFS
		date=${1}
		dirs=${2}
		echo '>>'
		echo '>> Date: ' ${date}
		echo '>> Files:' ${dirs}
	done
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

[ "$1" = "listdates" ] && { listdates ; exit 0; }

[ $# -lt 2 ] && die Invalid usage.  Run this script via buildrump.sh
BRDIR=$(dirname $0)
SRCDIR=${2}

case "${1}" in
cvs)
	shift ; shift
	checkoutcvs checkout $*
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
checkcheckout)
	checkcheckout
	exit $?
	;;
*)
	die Invalid command \"$1\".  Run this script via buildrump.sh
	;;
esac

exit 0

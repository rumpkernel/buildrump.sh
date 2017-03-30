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
# 2) run "./checkout.sh githubdate src-netbsd"
# 3) push src-netbsd
# 4) push buildrump.sh
#
# The rationale for the procedure is to prevent "race conditions"
# where cvs/git can offer different checkouts and also to make sure
# that once buildrump.sh is published, the NetBSD sources will be
# available via git.
#
NBSRC_CVSDATE="20160728 1100UTC"
NBSRC_CVSFLAGS="-z3"

# If set, timestamp for src/sys/rump/listsrcdir.  If unset,
# NBSRC_CVSDATE is used.
#NBSRC_LISTDATE="20150615 1130UTC"

# Cherry-pick patches are not in $NBSRC_CVSDATE
# the format is "date1:dir1 dir2 dir3 ...;date2:dir 4..."
#
# EXAMPLE='
#   20151111 1111UTC:
#	src/sys/rump'
#
NBSRC_EXTRA_sys=''

NBSRC_EXTRA_posix=''

NBSRC_EXTRA_usr=''

GITREPO='https://github.com/rumpkernel/src-netbsd'
GITREPOPUSH='git@github.com:rumpkernel/src-netbsd'
GITREPO_LKL='https://github.com/libos-nuse/lkl-linux'
GITREVFILE='.srcgitrev'

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

	what=$1
	shift

	case $1 in
	-r|-D)
		NBSRC_CVSPARAM=$1
		shift
		NBSRC_CVSREV=$*
		NBSRC_CVSLISTREV=$*
		extrasrc=''
		;;
	HEAD)
		NBSRC_CVSPARAM=''
		NBSRC_CVSREV=''
		NBSRC_CVSLISTREV=''
		extrasrc=''
		;;
	'')
		NBSRC_CVSPARAM=-D
		NBSRC_CVSREV="${NBSRC_CVSDATE}"
		NBSRC_CVSLISTREV="${NBSRC_LISTDATE:-${NBSRC_CVSDATE}}"
		eval extrasrc="\${NBSRC_EXTRA_${what}}"
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

	# squelch .cvspass whine
	export CVS_PASSFILE=/dev/null

	# we need listsrcdirs
	echo ">> Fetching the list of files we need to checkout ..."
	${CVS} ${NBSRC_CVSFLAGS} -d ${BUILDRUMP_CVSROOT} co -p \
	    ${NBSRC_CVSPARAM} ${NBSRC_CVSLISTREV:+"${NBSRC_CVSLISTREV}"} \
	    src/sys/rump/listsrcdirs > listsrcdirs 2>/dev/null \
	      || die listsrcdirs checkout failed

	# trick cvs into "skipping" the module name so that we get
	# all the sources directly into $SRCDIR
	rm -f src
	ln -s . src

	# now, do the real checkout
	echo ">> Fetching the \"${what}\" subset of NetBSD source tree to: $(pwd -P)"
	sh listsrcdirs -c ${what} | xargs ${CVS} ${NBSRC_CVSFLAGS} \
	    -d ${BUILDRUMP_CVSROOT} ${op} \
	    ${prune} ${NBSRC_CVSPARAM} ${NBSRC_CVSREV:+"${NBSRC_CVSREV}"} \
	      || die checkout failed

	IFS=';'
	[ -z "${extrasrc}" ] || echo ">> Fetching extra files for \"${what}\""
	for x in ${extrasrc}; do
		IFS=':'
		set -- ${x}
		unset IFS
		date=${1}
		dirs=${2}
		rm -rf ${dirs}
		${CVS} ${NBSRC_CVSFLAGS} -d ${BUILDRUMP_CVSROOT} \
		    ${op} ${prune} -D "${date}" ${dirs} \
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
		${GIT} fetch origin buildrump-src || die Failed to fetch repo
	else
		${GIT} clone -n ${GITREPO} ${SRCDIR} || die Clone failed
		cd ${SRCDIR}
	fi

	${GIT} checkout -q ${gitrev} || \
	    die 'Could not checkout correct git revision. Wrong repo?'
}

# Check out Linux (LKL) sources.
LKL_REV=rump-hypcall-upstream
checkoutgitlinux ()
{

	echo ">> Fetching Linux/LKL sources to ${LKL_SRCDIR} using git"

	if [ -e "${LKL_SRCDIR}" -a ! -e "${LKL_SRCDIR}/.git" ]; then
		echo '>>'
		echo ">> NOTICE: Not a buildrump.sh-based git repo in ${LKL_SRCDIR}"
		echo '>> Cannot verify repository version.  Proceeding ...'
		echo '>>'
		return 0
	fi

	gitrev=${LKL_REV}
	[ $? -eq 0 ] || die Cannot determine relevant git revision
	if [ -e ${LKL_SRCDIR}/.git ] ; then
		cd ${LKL_SRCDIR}
#		[ -z "$(${GIT} status --porcelain)" ] \
#		    || die "Cloned repo in ${LKL_SRCDIR} is not clean, aborting."
		${GIT} fetch origin ${LKL_REV} || die Failed to fetch repo
	else
		${GIT} clone -n ${GITREPO_LKL} ${LKL_SRCDIR} || die Clone failed
		cd ${LKL_SRCDIR}
	fi

	${GIT} checkout -q ${gitrev} || \
	    die 'Could not checkout correct git revision. Wrong repo?'
}

hubdateonebranch ()
{

	exportname=${1}
	branchbase=${2}

	git checkout ${branchbase}-src-clean
	rm -rf *
	checkoutcvs export ${exportname}
	echo ">> adding files to the \"${branchbase}-src-clean\" branch"
	${GIT} add -A

	if [ -z "$(${GIT} status --porcelain)" ]; then
		echo ">> no changes to \"${branchbase}\""
	else
		echo '>> committing'
		${GIT} commit -m "NetBSD src for \"${branchbase}\", checkout.sh rev ${gitrev}"
	fi
	echo ">> merging \"${branchbase}-src-clean\" to \"${branchbase}-src\""
	${GIT} checkout ${branchbase}-src

	# Historically, it was possible to have merge conflicts at this
	# point.  Since our tree should now be 100% the same as upstream,
	# merge conflicts should be impossible.  Nevertheless, preserve the
	# old code.
	if ! ${GIT} merge --no-edit ${branchbase}-src-clean; then
		echo '>> MERGE CONFLICT!'
		echo '>> YOU ARE PROBABLY DOING SOMETHING WRONG!'
		echo '>>'
		echo '>> Merge manually and commit in another terminal.'
		echo '>> Press enter to continue'
		read jooei
		if [ ! -z "$(${GIT} status --porcelain)" ]; then
			echo '>> Merge conflicts still present.  Aborting'
			exit 1
		fi
	fi
}

# do a cvs checkout and push the results into the github mirror
githubdate ()
{

	curdir="$(pwd)"

	[ -z "$(${GIT} status --porcelain | grep 'M checkout.sh')" ] \
	    || die checkout.sh contains uncommitted changes!
	gitrev=$(${GIT} rev-parse HEAD)

	[ -e ${SRCDIR} ] && die Error, ${SRCDIR} exists

	set -e

	${GIT} clone ${GITREPOPUSH} ${SRCDIR}
	cd ${SRCDIR} || die cannot access srcdir

	# handle basic branches
	hubdateonebranch posix posix
	hubdateonebranch sys kernel
	hubdateonebranch usr user

	${GIT} checkout appstack-src
	${GIT} merge --no-edit kernel-src user-src

	${GIT} checkout all-src
	${GIT} merge --no-edit kernel-src user-src posix-src

	# buildrump-src revision gets embedded in buildrump.sh
	${GIT} checkout buildrump-src
	${GIT} merge --no-edit kernel-src posix-src
	gitsrcrev=$(${GIT} rev-parse HEAD)

	${GIT} checkout master

	# finally, embed revision in $GITREVFILE in buildrump.sh
	cd "${curdir}"
	echo ${gitsrcrev} > ${GITREVFILE}
	${GIT} commit -m "Source for buildrump.sh git rev ${gitrev}" \
	    ${GITREVFILE}

	set +e
}

checkcheckout ()
{

	# if it's not a git repo, don't bother
	if [ ! -e "${SRCDIR}/.buildrumpsh-repo" -o ! -d "${SRCDIR}/.git" ]; then
		echo '>>'
		echo ">> NOTICE: Not a buildrump.sh-based git repo in ${SRCDIR}"
		echo '>> Cannot verify repository version.  Proceeding ...'
		echo '>>'
		return 0
	fi

	setgit || return 0

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

	[ -z "${1}" ] && die $0 requires a parameter
	eval extrasrc="\${NBSRC_EXTRA_${1}}"

	echo '>> Base date for NetBSD sources:'
	echo '>>' ${NBSRC_CVSDATE}
	[ -z "${extrasrc}" ] || printf '>>\n>> Overrides:\n'
	IFS=';'
	for x in ${extrasrc}; do
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
	type ${GIT} >/dev/null 2>&1 || return 1
}

[ "$1" = "listdates" ] && { listdates ; exit 0; }

BRDIR=$(dirname $0)
. ${BRDIR}/subr.sh

[ $# -lt 2 ] && die Invalid usage.  Run this script via buildrump.sh
SRCDIR=${2}
LKL_SRCDIR=${3}

# default to the most secure source for githubdate
if [ -z "${BUILDRUMP_CVSROOT}" ]; then
	case "${1}" in
	githubdate)
		BUILDRUMP_CVSROOT=cvs.netbsd.org:/cvsroot
		;;
	*)
		BUILDRUMP_CVSROOT=:pserver:anoncvs@anoncvs.netbsd.org:/cvsroot
		;;
	esac
fi

case "${1}" in
cvs|cvsbuildrump)
	shift ; shift
	mkdir -p ${SRCDIR} || die cannot create srcdir
	cd ${SRCDIR} || die cannot access srcdir
	checkoutcvs checkout sys $*
	checkoutcvs checkout posix $*
	echo '>> checkout done'
	;;
cvsappstack)
	shift ; shift
	mkdir -p ${SRCDIR} || die cannot create srcdir
	cd ${SRCDIR} || die cannot access srcdir
	checkoutcvs checkout sys $*
	checkoutcvs checkout usr $*
	echo '>> checkout done'
	;;
cvsall)
	shift ; shift
	mkdir -p ${SRCDIR} || die cannot create srcdir
	cd ${SRCDIR} || die cannot access srcdir
	checkoutcvs checkout sys $*
	checkoutcvs checkout usr $*
	checkoutcvs checkout posix $*
	echo '>> checkout done'
	;;
git)
	setgit || die "require working git"
	checkoutgit
	echo '>> checkout done'
	;;
linux-git)
	setgit || die "require working git"
	curdir="$(pwd)"
	# XXX: currently linux build requires src-netbsd
	checkoutgit
	cd "${curdir}"
	checkoutgitlinux
	cd "${curdir}"
	echo '>> checkout done'
	;;
githubdate)
	[ $(dirname $0) != '.' ] && die Script must be run as ./checkout.sh
	setgit || die "require working git"
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

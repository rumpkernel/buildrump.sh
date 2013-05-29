#! /usr/bin/env sh
#
# Copyright (c) 2013 
# Jens Staal <staal1978@gmail.com>
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

# This script will generate a tar.bz2 archive of the current git checkout
# The "version number" of the tarball is in unix time format 

DEST=buildrump

echo "Detecting buildrump.sh git revision"

_revision=$(git rev-parse HEAD)
_date=$(git show -s --format="%ci" ${_revision})
#incremental "version number" in unix time format
_time_unix=$(git show -s --format="%ct" ${_revision})

if [ -z "${_revision}" ]
then
  echo "Error: git revision could not be detected"
  exit
else
  echo "buildrump.sh git revision is ${_revision}"
fi

if ! mkdir "${DEST}"; then
	echo "Error: failed to create directory \"${DEST}\""
	exit 1
fi

echo "Checking out cvs sources"

./buildrump.sh -s ${DEST}/src checkout

echo "Checkout done"

echo "Generating temporary directory to be compressed"

#directories
cp -r {brlib,examples,tests} "${DEST}/"

#directories that should be empty
mkdir -p "${DEST}"/{obj,rump}

#files
cp {AUTHORS,buildrump.sh,LICENSE,tarup.sh} "${DEST}"/

echo ${_revision} > "${DEST}/gitrevision"
echo ${_date} > "${DEST}/revisiondate"

echo "Compressing sources to a snapshot release"

tar -cjf buildrump-${_time_unix}.tar.bz2 "${DEST}"

echo "Removing temporary directory"
rm -rf "${DEST}"

echo "Congratulations! Your archive should be
      at buildrump-${_time_unix}.tar.bz2"

#! /usr/bin/env sh
#
# Copyright (c) 2013 
# Jens Staal <staal1978@gmail.com>
#
#######################################
# This work 'as-is' we provide.       #
# No warranty express or implied.     #
#     We've done our best,            #
#     to debug and test.              #
# Liability for damages denied.       #
#                                     #
# Permission is granted hereby,       #
# to copy, share, and modify.         #
#     Use as is fit,                  #
#     free or for profit.             #
# These rights, on this notice, rely. #
#######################################

echo "Detecting buildrump.sh git revision"

_revision=$(git rev-parse HEAD)
_dest=$(dirname $PWD)

if [ ${_revision} ]
then
  echo "buildrump.sh git revision is ${_revision}"
else
  echo "Error: git revision could not be detected"
  exit
fi

echo "Checking out cvs sources"

./buildrump.sh checkout

echo "Checkout done"

echo "Compressing sources to a snapshot release"

tar -cjf ${_dest}/buildrump-${_revision}.tar.bz2 * 

echo "Congratulations! our archive should be
      at ${_dest}/buildrump-${_revision}.tar.bz2"
      
      

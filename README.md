Building NetBSD-based rump kernels on non-NetBSD
================================================

This repo contains support scripts for building rump kernels for
non-NetBSD hosts.  The goal is to eventually get everything from here
into the NetBSD build.sh script, but we're starting out elsewhere to
facilitate quick modifications before things stabilize.


Instructions
============

Drop the buildrump.sh script into the top level of the NetBSD source tree
and run it as ./buildrump.sh.  Wait some moments.  If all goes well, you
will have a rump kernel, the hypervisor and necessary headers in ./rump

For now it's a good idea to use a NetBSD-current with at least
the same timestamp as the script.

Dependencies
------------

Since the script plugs into NetBSD's build.sh, there are practically
zero dependencies.  The things I had to install are:

- cc
- zlib
- something for getting the NetBSD source tree (I used cvs)


Tested hosts
============

This script has been tested on the following platforms (uname -a):

- Linux Ubuntu-1210-quantal-64-minimal 3.5.0-18-generic #29-Ubuntu SMP Fri Oct 19 10:26:51 UTC 2012 x86_64 x86_64 x86_64 GNU/Linux (with thanks to Zafer Aydogan for providing access)

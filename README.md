Building NetBSD-based rump kernels on non-NetBSD
================================================

This repo contains support scripts for building rump kernels for
non-NetBSD hosts.  The goal is to eventually get everything from here
into the NetBSD build.sh script, but we're starting out elsewhere to
facilitate quick modifications before things stabilize.

For more information on rump kernels, see http://www.NetBSD.org/docs/rump/


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


Tested configurations
=====================

The script supports both gcc and clang as the host target compiler.
It has been tested to work with GNU binutils.

The following platforms have been tested:

- Linux
    - Linux Ubuntu-1210-quantal-64-minimal 3.5.0-18-generic #29-Ubuntu SMP Fri Oct 19 10:26:51 UTC 2012 x86_64 x86_64 x86_64 GNU/Linux (with thanks to Zafer Aydogan for providing access, amd64)
    - Linux Gallifrey 2.6.35.14-106.fc14.x86_64 #1 SMP Wed Nov 23 13:07:52 UTC 2011 x86_64 x86_64 x86_64 GNU/Linux (with seLinux in permissive mode, amd64)
    - Linux vyrnwy 3.6.2-1.fc16.x86_64 #1 SMP Wed Oct 17 05:30:01 UTC 2012 x86_64 x86_64 x86_64 GNU/Linux (Fedora release 16 with read-only /usr/src via NFS)

- Solaris
    - SunOS hutcs 5.10 Generic_142900-15 sun4v sparc SUNW,T5240 Solaris (needs xpg4/bin/sh, sparc64)

- DragonFly BSD
    - DragonFly  3.2-RELEASE DragonFly v3.2.1.9.g80b03f-RELEASE #2: Wed Oct 31 20:17:57 PDT 2012     root@pkgbox32.dragonflybsd.org:/usr/obj/build/home/justin/src/sys/GENERIC  i386

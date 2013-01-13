Building NetBSD-based rump kernels on non-NetBSD
================================================

The buildrump.sh script builds NetBSD kernel drivers on non-NetBSD hosts
and thus enables running them.  This portability is achieved by running
the drivers in rump kernels on the target host.

For more information on rump kernels, see http://www.NetBSD.org/docs/rump/


Instructions
============

Get NetBSD src, e.g. `cvs -z3 -d anoncvs@anoncvs.netbsd.org:/cvsroot co
-P src`.  If your source tree is too old, the script will complain.
Generally speaking, for now you need a recent NetBSD-current.

Run the script and specify the NetBSD source directory with `-s`.  Use `-h`
to see other options.

After a successful build, the script will run a simple test program.
The final output should be something like the following:

	[...]
	NetBSD 6.99.16 (RUMP-ROAST) #0: Sun Jan 13 23:27:47 EET 2013
		pooka@golem:/var/tmp/pooka/obj/lib/librump
	rump kernel halting...
	syncing disks... done
	unmounting file systems...
	unmounted kernfs on /kern type kernfs
	unmounted rumpfs on / type rumpfs
	unmounting done
	halted
	
	Success.
	$ 


Dependencies
------------

The toolchain in PATH is used to produce the target binaries (support
for cross-compilation may be added at a later date).  The script builds
other necessary tools out of the NetBSD source tree using `build.sh`.
In addition from what is expected to be present on a bare-bones host
(`sh`, `rm`, etc.), the following software is required:

- cc (gcc or clang)
- binutils (ld, objcopy, etc.)
- zlib

GNU ld is necessary since the NetBSD kernel Makefiles depend on
its command line syntax.


Tested configurations
=====================

The following platforms have been tested:

- Linux
    - Linux Ubuntu-1210-quantal-64-minimal 3.5.0-18-generic #29-Ubuntu SMP Fri Oct 19 10:26:51 UTC 2012 x86_64 x86_64 x86_64 GNU/Linux (with thanks to Zafer Aydogan for providing access, amd64)
    - Linux Gallifrey 2.6.35.14-106.fc14.x86_64 #1 SMP Wed Nov 23 13:07:52 UTC 2011 x86_64 x86_64 x86_64 GNU/Linux (with seLinux in permissive mode, amd64)
    - Linux vyrnwy 3.6.2-1.fc16.x86_64 #1 SMP Wed Oct 17 05:30:01 UTC 2012 x86_64 x86_64 x86_64 GNU/Linux (Fedora release 16 with read-only /usr/src via NFS)
    - Linux golden-valley 3.2.27-18-ARCH+ #1 PREEMPT Fri Dec 21 14:18:42 UTC 2012 armv6l GNU/Linux (Raspberry Pi, evbarm)

- DragonFly BSD
    - DragonFly  3.2-RELEASE DragonFly v3.2.1.9.g80b03f-RELEASE #2: Wed Oct 31 20:17:57 PDT 2012     root@pkgbox32.dragonflybsd.org:/usr/obj/build/home/justin/src/sys/GENERIC  i386

- FreeBSD
    - FreeBSD frab 9.1-PRERELEASE FreeBSD 9.1-PRERELEASE #5 r243866: Wed Dec  5 02:15:02 CET 2012     root@vetinari:/usr/obj/usr/src/sys/RINCEWIND  amd64 (static rump kernel components, with thanks to Philip for test host access)

- Solaris
    - SunOS hutcs 5.10 Generic_142900-15 sun4v sparc SUNW,T5240 Solaris (needs xpg4/bin/sh, sparc64)

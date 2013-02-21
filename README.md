Running NetBSD-based rump kernels on non-NetBSD
================================================

The buildrump.sh script builds NetBSD kernel drivers such as file systems
and the TCP/IP stack for non-NetBSD targets.  The drivers can be run
in rump kernels on the target host.  The script and the resulting rump
kernel components can/should be run as an unprivileged user, i.e. no
root account is required.

For more information on rump kernels, see http://www.NetBSD.org/docs/rump/


Instructions
============

Get a copy of the NetBSD source tree.  The easiest way is to fetch
the entire tree, e.g. using anoncvs:
`env CVS_RSH=ssh cvs -z3 -d anoncvs@anoncvs.netbsd.org:/cvsroot co -P src`.
The minimum necessary subset of the NetBSD source tree is documented in
a script available from the NetBSD repository at src/sys/rump/listsrcdirs.

Run the `buildrump.sh` script and specify the NetBSD source directory
with `-s`.  Use `-h` to see other options.

After a successful build, the script will run some simple tests to
check that e.g. file systems and the TCP/IP stack work correctly.
If the tests are successful, the final output is:

	[...]
	rump kernel halting...
	syncing disks... done
	unmounting file systems...
	unmounted kernfs on /kern type kernfs
	unmounted rumpfs on / type rumpfs
	unmounting done
	halted
	Done
	
	Success
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


Running / Using
---------------

The build script creates a few simple tests into the object directory
(default: obj) to check that the build result is functional.  These
tests are good places to start modying or running as single-step in
a debugger.


Tested hosts
============

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

- NetBSD
    - NetBSD pain-rustique.localhost 5.1_STABLE NetBSD 5.1_STABLE (PAIN-RUSTIQUE) #5: Wed Feb 16 13:34:14 CET 2011  pooka@pain-rustique.localhost:/objs/kobj.i386/PAIN-RUSTIQUE i386

- Solaris
    - SunOS hutcs 5.10 Generic_142900-15 sun4v sparc SUNW,T5240 Solaris (needs xpg4/bin/sh, sparc64)

There is also initial support for Cygwin, but it will not work
out-of-the-box.

Running NetBSD's Rump Kernels On Any Host
=========================================

The buildrump.sh script builds unmodified NetBSD kernel drivers such
as file systems and the TCP/IP stack as components for hosts such as
Linux and other BSDs.  These components can be linked in a variety
of configurations to form *rump kernels*, which provide services to
applications directly on the host.  The benefits of this approach include
avoiding the overhead of OS virtualization.  Also, root privileges are
not mandated.

For more information on rump kernels, see http://www.NetBSD.org/docs/rump/

See also the [wiki](http://github.com/anttikantee/buildrump.sh/wiki/TODO) for
a short-term TODO list.


Instructions
============

Clone the repository and run:

- `./buildrump.sh checkout fullbuild`

You will now find the kernel drivers and necessary headers in `./rump`
ready for use.  Examples on how to use the resulting drivers are available
in the `tests` and `examples` directories.

It is not necessary to read this document further unless you are
interested in details.


The long(er) version
--------------------

The `checkout` command above will fetch the necessary subset of the
NetBSD source tree from anoncvs.netbsd.org into `./src`.  You are also
free to use any other method for fetching NetBSD sources, though the
only officially supported way is to let the script handle the checkout.

The script will then proceed to build the necessary set of tools for
building rump kernels for the current host, after which it will build
the rump kernels.

After a successful build, the script will run some simple tests to
check that e.g. file systems and the TCP/IP stack work correctly.
If everything was successfully completed, the final output is:

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

To learn more about command line parameters, run the buildrump.sh
script with the `-h` flag.


Packages
--------

Some operating systems provide rump kernels as a package:

* [Arch Linux](http://aur.archlinux.org/packages/netbsd-rump-cvs/)
* [Void Linux](http://github.com/xtraeme/xbps-packages/blob/master/srcpkgs/netbsd-rumpkernel/template)


Build dependencies
==================

The toolchain in PATH is used to produce the target binaries (support
for cross-compilation may be added at a later date).  The script builds
other necessary tools out of the NetBSD source tree using `build.sh`.
In addition from what is expected to be present on a bare-bones host
(`sh`, `rm`, etc.), the following software is required during the build
process:

- cc (gcc or clang)
- ld (GNU or Solaris ld required)
- binutils (objcopy, etc.)
- zlib
- cvs (required only for "checkout")


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
    - SunOS hutcs 5.10 Generic_142900-15 sun4v sparc SUNW,T5240 Solaris (needs xpg4/bin/sh, sparc64 in 64bit mode, sparc in 32bit mode)
    - SunOS pkgsrc-dev 5.11 joyent_20120126T071347Z i86pc i386 i86pc (with thanks to Jonathan for test host access, amd64 in 64bit mode, i386 in 32bit mode)

There is also initial support for Cygwin, but it will not work
out-of-the-box due to object format issues (ELF vs. PE-COFF).
Mac OS X is likely to require support for its linker.

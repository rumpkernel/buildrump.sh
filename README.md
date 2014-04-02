Tools for building Rump Kernels [![Build Status](https://travis-ci.org/rumpkernel/buildrump.sh.png?branch=master)](https://travis-ci.org/rumpkernel/buildrump.sh)
===============================

The `buildrump.sh` script builds unmodified NetBSD kernel drivers such
as file systems and the TCP/IP stack as components which can be linked
to form *rump kernels*.  These lightweight rump kernels run on
top of a high-level hypercall interface which is straightforward to
implement for most environments.  This repository includes the hypercall
implementation for running in userspace on POSIX hosts, with alternative
implementations such as for the
[Xen hypervisor](https://github.com/rumpkernel/rumpuser-xen/)
and the [Linux kernel](https://github.com/rumpkernel/rumpuser-linuxkernel)
being hosted elsewhere.

In other words, rump kernels enable embedding unmodified kernel drivers
in various environments and using the drivers as services.  Some examples
of how to use these services are as follows:

* [fs-utils](https://github.com/stacktic/fs-utils) uses file
  system drivers to provide applications for accessing file system images
* TCP/IP stack for the [DPDK](https://github.com/rumpkernel/dpdk-rumptcpip)
  and [netmap](https://github.com/rumpkernel/netmap-rumptcpip)
  userspace packet processing frameworks
* [ljsyscall](https://github.com/justincormack/ljsyscall) provides
  a Lua interface to rump kernels, allowing easy access from applications
  written in Lua
* [rumpuser-xen](https://github.com/rumpkernel/rumpuser-xen) enables
  running applications as standalone Xen DomU's (includes libc support)

Rump kernels address the part of the software stack typically handled
by an OS kernel.  For running unmodified userspace applications
against system call services provided by rump kernels, see
[rumprun](https://github.com/justincormack/rumprun/).

For full details on rump kernels, go to http://www.rumpkernel.org/.
For a video overview including various demos, watch the
[FOSDEM 2013 presentation](http://video.fosdem.org/2013/maintracks/K.1.105/The_Anykernel_and_Rump_Kernels.webm).

Discuss buildrump.sh on rumpkernel-users@lists.sourceforge.net
([subscribe](https://lists.sourceforge.net/lists/listinfo/rumpkernel-users)
before posting), or join __#rumpkernel__ on __irc.freenode.net__.

Running `buildrump.sh` requires a network connection for fetching NetBSD
kernel driver source code.  Self-contained archives can be created using
the `tarup.sh` script, and snapshots are available for download from
[here](http://sourceforge.net/projects/rumpkernel/).

Installation Instructions
=========================

The easiest way to install rump kernel components is to use a binary
package for your OS/distribution/architecture.  These packages will also
install the POSIX hypercall implementation.

* Void Linux: `xbps-install -S netbsd-rumpkernel`
* Arch Linux: [pacman](https://build.opensuse.org/package/binaries/home:staal1978/rump?repository=Arch_Extra) (OBS), [AUR](https://aur.archlinux.org/packages/netbsd-rump-git/) 
* OpenSUSE Linux:
12.3 [RPM](https://build.opensuse.org/package/binaries/home:staal1978/rump?repository=openSUSE_12.3) (OBS)
|| Tumbleweed [RPM](https://build.opensuse.org/package/binaries/home:staal1978/rump?repository=openSUSE_Factory) (OBS)
|| Factory [RPM](https://build.opensuse.org/package/binaries/home:staal1978/rump?repository=openSUSE_Factory) (OBS)
|| SLE_11_SP2 [RPM](https://build.opensuse.org/package/binaries/home:staal1978/rump?repository=SLE_11_SP2) (OBS)
* Fedora Linux:
17 [RPM](https://build.opensuse.org/package/binaries/home:staal1978/rump?repository=Fedora_17) (OBS)
|| 18 [RPM](https://build.opensuse.org/package/binaries/home:staal1978/rump?repository=Fedora_18) (OBS)
|| RHEL 6 [RPM](https://build.opensuse.org/package/binaries/home:staal1978/rump?repository=RedHat_RHEL-6) (OBS)
|| CentOS 6 [RPM](https://build.opensuse.org/package/binaries/home:staal1978/rump?repository=CentOS_CentOS-6) (OBS)
* Mandriva Linux 2011: [RPM](https://build.opensuse.org/package/binaries/home:staal1978/rump?repository=Mandriva_2011) (OBS)
* Debian Linux:
7 [DEB](https://build.opensuse.org/package/binaries/home:staal1978/rump?repository=Debian_7.0) (OBS)
* Ubuntu Linux:
13.04 [DEB](https://build.opensuse.org/package/binaries/home:staal1978/rump?repository=xUbuntu_13.04) (OBS)
|| 13.10 [DEB](https://build.opensuse.org/package/binaries/home:staal1978/rump?repository=xUbuntu_13.10) (OBS)
* NetBSD: pkgsrc/misc/rump
* DragonFly BSD: pkgsrc/misc/rump
* Solaris: pkgsrc/misc/rump

The links for some of packages are provided by the
[openSUSE Build Service](https://build.opensuse.org/package/show?package=rump&project=home%3Astaal1978). 
You can download and install the packages manually, but it is highly recommended to add the OBS repositories for the right distro and architecture to the package manager. This way, updates and dependencies will be automatically resolved for other packages depending on rump kernels.


Building from Source Code
=========================

Building from source may be necessary of there are no binary packages
for your systems, or if you wish to make source level modifications to the
rump kernel components.

Build dependencies
------------------

The following are required for building from source:

- cc (gcc and clang are known to work)
- ld (GNU or Solaris ld required)
- binutils (ar, nm, objcopy)

The short version
-----------------

Clone the repository and run:

- `./buildrump.sh`

You will now find the kernel drivers and necessary headers in `./rump`
ready for use.  Examples on how to use the resulting drivers are available
in the `tests` and `examples` directories.

The long(er) version
--------------------

When run without parameters, `buildrump.sh` implicitly assumes that the
given commands were `checkout fullbuild tests`.  You can override this
default by giving explicit commands.

The `checkout` command will fetch the necessary subset of the NetBSD
source tree from github into `./src` (the location can be changed using
the `-s` parameter).  You are free to use any method for fetching NetBSD
sources, though the only officially supported way is to use the `checkout`
command.  Note that the NetBSD sources and their timestamps may vary from
one buildrump.sh revision to another.  By default, the script checks that
you have the appropriate set of sources even if you do not run `checkout`.

The `fullbuild` command will then instruct the script to to build the
necessary set of tools for building rump kernels, e.g. the BSD version
of `make`, after which it will build the rump kernels.  By default,
`cc` from path is used along with other host tools such as `nm`.
Crosscompilation is documented further below.

If the command `tests` is given, the script will run simple tests
to check that e.g. file systems and the TCP/IP stack work correctly.
If everything was successfully completed, the final output from the
script is "buildrump.sh ran successfully".  Note that `tests` cannot be
run when `buildrump.sh` is used with a crosscompiler or in kernel-only
mode (see below).

To learn more about command line parameters, run the buildrump.sh
script with the `-h` flag.

Crosscompiling
--------------

If the environment variable `$CC` is set, its value is used as the compiler
instead of `cc`.  This allows not only to select between compiling with
gcc or clang, but also allows to specify a crosscompiler.  If `$CC` is set
and does not contain the value `cc`, `gcc`, or `clang` the script assumes
a crosscompiler and will by default use tools with names based on the
target of `$CC` with the format `target-tool` (e.g. `target-nm`).

Crosscompiling for an ARM system might look like this (first command
is purely informational):

	$ arm-linux-gnueabihf-gcc -dumpmachine
	arm-linux-gnueabihf
	$ env CC=arm-linux-gnueabihf-gcc ./buildrump.sh [params]

Since the target is `arm-linux-gnueabihf`, `arm-linux-gnueabihf-nm` etc.
must be found from `$PATH`.  The assumption is that the crosscompiler
can find the target platform headers and libraries which are required
for building the hypercall library.  You can override the defaults
by setting `$AR`, `$NM` and/or `$OBJCOPY` in the environment before
running the script.

Kernel-only mode
----------------

If the `-k` kernel-only parameter is specified, the script will
omit building the POSIX hypercall implementation.  This is useful if
you are developing your own hypercall layer implementation.  See the
[rumpuser-xen](https://github.com/rumpkernel/rumpuser-xen) repository
for the canonical example of using `-k`.


Tested hosts
============

Continuous testing on Linux/amd64 + gcc/clang is done by
[Travis CI](https://travis-ci.org/rumpkernel/buildrump.sh)
for every commit.  [![Build Status](https://travis-ci.org/rumpkernel/buildrump.sh.png?branch=master)](https://travis-ci.org/rumpkernel/buildrump.sh)

There is a broader platform CI testing for Linux _x86_ (32/64bit), _ARM_, _PowerPC_ (32/64bit), _MIPS_ (o32 ABI) and NetBSD _x86_ (32/64bit), and FreeBSD and OpenBSD _x86_ (64 bit) [using buildbot](http://build.myriabit.eu:8011/waterfall). 

Tested machine architectures include _x86_ (32/64bit), _ARM_, _PowerPC_
(32/64bit), _MIPS_ (32bit) and _UltraSPARC_ (32/64bit).

Examples of hosts buildrump.sh has manually been tested on are
as follows:

- Linux
    - Linux Gallifrey 2.6.35.14-106.fc14.x86_64 #1 SMP Wed Nov 23 13:07:52 UTC 2011 x86_64 x86_64 x86_64 GNU/Linux (with seLinux in permissive mode, __amd64__)
    - Linux vyrnwy 3.6.2-1.fc16.x86_64 #1 SMP Wed Oct 17 05:30:01 UTC 2012 x86_64 x86_64 __x86_64__ GNU/Linux (Fedora release 16 with read-only /usr/src via NFS)
    - Linux void-rpi 3.6.11_1 #1 PREEMPT Tue Feb 19 17:40:24 CET 2013 armv6l GNU/Linux (Void, __Raspberry Pi, evbarm__)
    - Linux braniac 3.9.9-1-ARCH #1 SMP PREEMPT Wed Jul 3 22:45:16 CEST 2013 x86_64 GNU/Linux (Arch Linux, __amd64__, gcc 4.8.1)
    - Linux pike 3.6.7-4.fc17.ppc64 #1 SMP Thu Dec 6 06:41:58 MST 2012 ppc64 ppc64 ppc64 GNU/Linux (Fedora, __ppc64__)
    - Linux 172-29-171-95.dal-ebis.ihost.com 2.6.32-358.el6.ppc64 #1 SMP Tue Jan 29 11:43:27 EST 2013 ppc64 ppc64 ppc64 GNU/Linux (RHEL6, __ppc64__, 64 and 32 bit builds, IBM Virtual Loaner Program)
    - Linux fuloong 3.11.6-gnu #8 PREEMPT Mon Oct 28 23:28:22 GMT 2013 mips64 ICT Loongson-2 V0.3 FPU V0.1 lemote-fuloong-2f-box GNU/Linux (Gentoo, __mips o32 le__)
    - Linux ubnt 2.6.32.13-UBNT #1 SMP Wed Oct 24 01:08:06 PDT 2012 mips64 GNU/Linux (__mips o32 be__)

- Android
    - Android 4.2.2 kernel 3.4.5 ARMv7 Processor rev 2 (v7l) (__arm__)

- DragonFly BSD
    - DragonFly  3.2-RELEASE DragonFly v3.2.1.9.g80b03f-RELEASE #2: Wed Oct 31 20:17:57 PDT 2012     root@pkgbox32.dragonflybsd.org:/usr/obj/build/home/justin/src/sys/GENERIC  __i386__

- FreeBSD
    - FreeBSD frab 9.1-PRERELEASE FreeBSD 9.1-PRERELEASE #5 r243866: Wed Dec  5 02:15:02 CET 2012     root@vetinari:/usr/obj/usr/src/sys/RINCEWIND  __amd64__ (static rump kernel components, with thanks to Philip for test host access)

- NetBSD
    - NetBSD pain-rustique.localhost 5.1_STABLE NetBSD 5.1_STABLE (PAIN-RUSTIQUE) #5: Wed Feb 16 13:34:14 CET 2011  pooka@pain-rustique.localhost:/objs/kobj.i386/PAIN-RUSTIQUE __i386__

- OpenBSD
    - OpenBSD openbsd.myriabit.eu 5.4 GENERIC#37 __amd64__

- Solaris
    - SunOS hutcs 5.10 Generic_142900-15 sun4v sparc SUNW,T5240 Solaris (needs xpg4/bin/sh, __sparc64__ in 64bit mode, __sparc__ in 32bit mode)
    - SunOS pkgsrc-dev 5.11 joyent_20120126T071347Z i86pc i386 i86pc (with thanks to Jonathan for test host access, __amd64__ in 64bit mode, __i386__ in 32bit mode)

There is also initial support for Cygwin, but it will not work
out-of-the-box due to object format issues (ELF vs. PE-COFF).
Mac OS X is likely to require support for its linker.


Tips for advanced users
=========================

- Place your buildtools in a separate directory, e.g. `$HOME/rumptools`
  using `./buildrump.sh -T $HOME/rumptools fullbuild`.  Put that directory in
  `$PATH`.  You can now do fast build iteration for kernel components by
  going to the appropriate directory and running `rumpmake dependall &&
  rumpmake install`.

- You can list the NetBSD source dates used by `./buildrump.sh checkout`
  by running `./checkout.sh listdates`.

- Assuming you have a commit bit to NetBSD, you can use HEAD from NetBSD
  src and be able to commit your changes to NetBSD from src with the
  following setup:

  - `BUILDRUMP_CVSROOT=dev@cvs.netbsd.org:/cvsroot ./checkout.sh cvs nbcvs HEAD`
  - `./buildrump.sh -s nbcvs fullbuild`

  Of course, replace `dev` with your NetBSD account name.  Equally
  "of course", this operating mode is not officially supported by
  buildrump.sh.  However, if you run into problems that will affect
  buildrump.sh after the checkout date is bumped, report the problems
  using your discretion.

- You can override the compiler optimization flags by setting
  `BUILDRUMP_DBG` in the env before running the script.  For example,
  `BUILDRUMP_DBG=-Os ./buildrump.sh` will build with `-Os` instead of
  the default `-O2 -g`.

Running NetBSD's Rump Kernels On Any Host
=========================================

The buildrump.sh script builds unmodified NetBSD kernel drivers such
as file systems and the TCP/IP stack as components for hosts such as
Linux and other BSDs.  These components can be linked in a variety
of configurations to form *rump kernels*, which provide services to
applications directly on the host.  The benefits of this approach include
avoiding the overhead of OS virtualization.  Also, root privileges are
not mandated.

An example use case is [fs-utils](http://github.com/stacktic/fs-utils)
which uses rump kernels to access file system images.  Another example
is using the TCP/IP stack in conjunction with the Data Plane Development
Kit, available [here](http://github.com/anttikantee/dpdk-rumptcpip).
For more information on rump kernels, see http://www.NetBSD.org/docs/rump/


Installation Instructions
=========================

The easiest way to install rump kernel components is to use a binary
package for your OS/distribution/architecture.

* Void Linux: `xbps-install -S netbsd-rumpkernel`
* Arch Linux: [pacman](https://build.opensuse.org/package/binaries?package=rump&project=home%3Astaal1978&repository=Arch_Core) (OBS), [AUR](https://aur.archlinux.org/packages/netbsd-rump-cvs/) 
* OpenSUSE Linux:
12.3 [RPM](https://build.opensuse.org/package/binaries?package=rump&project=home%3Astaal1978&repository=openSUSE_12.3) (OBS)
|| Tumbleweed [RPM](https://build.opensuse.org/package/binaries?package=rump&project=home%3Astaal1978&repository=openSUSE_Factory) (OBS)
|| Factory [RPM](https://build.opensuse.org/package/binaries?package=rump&project=home%3Astaal1978&repository=openSUSE_Factory) (OBS)
|| SLE_11_SP2 [RPM](https://build.opensuse.org/package/binaries?package=rump&project=home%3Astaal1978&repository=SLE_11_SP2) (OBS)
* Fedora Linux:
17 [RPM](https://build.opensuse.org/package/binaries?package=rump&project=home%3Astaal1978&repository=Fedora_17) (OBS)
|| 18 [RPM](https://build.opensuse.org/package/binaries?package=rump&project=home%3Astaal1978&repository=Fedora_18) (OBS)
|| RHEL 6 [RPM](https://build.opensuse.org/package/binaries?package=rump&project=home%3Astaal1978&repository=RedHat_RHEL-6) (OBS)
|| CentOS 6 [RPM](https://build.opensuse.org/package/binaries?package=rump&project=home%3Astaal1978&repository=CentOS_CentOS-6) (OBS)
* Mandriva Linux 2011: [RPM](https://build.opensuse.org/package/binaries?package=rump&project=home%3Astaal1978&repository=Mandriva_2011) (OBS)
* NetBSD: pkgsrc/misc/rump
* DragonFly BSD: pkgsrc/misc/rump
* Solaris: pkgsrc/misc/rump

The links for some of packages are provided by the
[openSUSE Build Service](https://build.opensuse.org/package/show?package=rump&project=home%3Astaal1978). 
You can download and install the packages manually, but it is highly recommended to add the OBS repositories for the right distro and architecture to the package manager. This way, updates and dependencies will be automatically resolved other packages depending on rump kernels.


Building from Source Code
=========================

Building from source may be necessary of there are no binary packages
for your systems, or if you wish to source level modifications to the
rump kernel components.

Build dependencies
------------------

The following are required for building from source:

- cc (gcc and clang are known to work)
- ld (GNU or Solaris ld required)
- binutils (ar, nm, objcopy)
- cvs (required only for "checkout")

The short version
-----------------

Clone the repository and run:

- `./buildrump.sh checkout fullbuild`

You will now find the kernel drivers and necessary headers in `./rump`
ready for use.  Examples on how to use the resulting drivers are available
in the `tests` and `examples` directories.

The long(er) version
--------------------

The `checkout` command above will fetch the necessary subset of the
NetBSD source tree from anoncvs.netbsd.org into `./src`.  You are also
free to use any other method for fetching NetBSD sources, though the
only officially supported way is to let the script handle the checkout.

The script will then proceed to build the necessary set of tools for
building rump kernels, e.g. the BSD version of `make`, after which it
will build the rump kernels.  By default, `cc` from path is used along
with other host tools such as `nm`.  Crosscompilation is documented
further below.

If the command `tests` or `fullbuild` is given, the script will run simple
tests to check that e.g. file systems and the TCP/IP stack work correctly.
If everything was successfully completed, the final output from the
script is "Success".

To learn more about command line parameters, run the buildrump.sh
script with the `-h` flag.

Crosscompiling
--------------

If the environment variable `$CC` is set, its value is used as the compiler
instead of `cc`.  This allows not only to select between compiling with
gcc or clang, but also allows to specify a crosscompiler.  If `$CC` is set
and does not contain the value `cc`, `gcc`, or `clang` the script assumes
a crosscompiler and will use tools with names based on the target of
`$CC` with the format `target-tool` (e.g. `target-nm`).

Crosscompiling for an ARM system might look like this (first command
is purely informational):

	$ arm-linux-gnueabihf-gcc -dumpmachine
	arm-linux-gnueabihf
	$ env CC=arm-linux-gnueabihf-gcc ./buildrump.sh [params]

Since the target is `arm-linux-gnueabihf`, `arm-linux-gnueabihf-nm` etc.
must be found from `$PATH`.  The assumption is that the crosscompiler
can find the target platform headers and libraries which are required
for building the hypervisor.


Tested hosts
============

examples of hosts buildrump.sh has been tested on:

- Linux
    - Linux Ubuntu-1210-quantal-64-minimal 3.5.0-18-generic #29-Ubuntu SMP Fri Oct 19 10:26:51 UTC 2012 x86_64 x86_64 x86_64 GNU/Linux (with thanks to Zafer Aydogan for providing access, amd64)
    - Linux Gallifrey 2.6.35.14-106.fc14.x86_64 #1 SMP Wed Nov 23 13:07:52 UTC 2011 x86_64 x86_64 x86_64 GNU/Linux (with seLinux in permissive mode, amd64)
    - Linux vyrnwy 3.6.2-1.fc16.x86_64 #1 SMP Wed Oct 17 05:30:01 UTC 2012 x86_64 x86_64 x86_64 GNU/Linux (Fedora release 16 with read-only /usr/src via NFS)
    - Linux golden-valley 3.2.27-18-ARCH+ #1 PREEMPT Fri Dec 21 14:18:42 UTC 2012 armv6l GNU/Linux (Arch, Raspberry Pi, evbarm)
    - Linux void-rpi 3.6.11_1 #1 PREEMPT Tue Feb 19 17:40:24 CET 2013 armv6l GNU/Linux (Void, Raspberry Pi, evbarm)

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

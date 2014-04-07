Tools for building Rump Kernels [![Build Status](https://travis-ci.org/rumpkernel/buildrump.sh.png?branch=master)](https://travis-ci.org/rumpkernel/buildrump.sh)
===============================

The _buildrump.sh_ script is a tool for (cross-)building kernel drivers as
[rump kernels](http://www.rumpkernel.org/) for a variety of platforms, for
example a POSIX-type userspace.  There are practically no dependencies
apart from a working toolchain.  When invoked without parameters,
buildrump.sh will download the necessary source code, build the kernel
drivers, and run a number of tests:

```
./buildrump.sh
```

See [the wiki](http://wiki.rumpkernel.org/Repo:-buildrump.sh) for more
information and further instructions.

Tools for building Rump Kernels [![Build Status](https://travis-ci.org/rumpkernel/buildrump.sh.png?branch=master)](https://travis-ci.org/rumpkernel/buildrump.sh)
===============================

The _buildrump.sh_ script is a tool for (cross-)building
[rump kernels](http://rumpkernel.org/) for a variety of platforms.
The purpose is to make it easy to build rump kernels on any host for
virtually any target.  There are practically no dependencies apart from a
(cross-)working toolchain.  When invoked without parameters, buildrump.sh
will download the necessary source code, build the kernel drivers for
POSIX'y userspace, and run a number of tests.

```
./buildrump.sh
```

See [the wiki](http://wiki.rumpkernel.org/Repo:-buildrump.sh) for more
information and further instructions.

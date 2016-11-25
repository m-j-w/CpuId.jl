# *CpuId* — Ask your CPU what it can do for you.

_Status: Experimental._

[![Build Status](https://travis-ci.org/m-j-w/CpuId.jl.svg?branch=master)](https://travis-ci.org/m-j-w/CpuId.jl)
[![Build Status](https://ci.appveyor.com/api/projects/status/q34wl2a441dy87gy?svg=true)](https://ci.appveyor.com/project/m-j-w/cpuid-jl)
[![codecov](https://codecov.io/gh/m-j-w/CpuId.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/m-j-w/CpuId.jl)

Expected to work at least on Julia 0.6, Linux with Intel compatible CPUs.


## Motivation

Besides the obvious reason to gather information for diagnostics, the CPU
provides valuable information when aiming at increasing the efficiency of code.
Such usecases could be to taylor the size of working sets of data according to
the available cache sizes, to detect when the code is executed in a virtual
machine (hypervisor), or to determine the size of the largest SIMD registers
available.  This information is obtained by directly querying the CPU through
the `cpuid` assembly instruction.  A comprehensive overview of the `cpuid`
instruction is found at [sandpile.org](http://www.sandpile.org/x86/cpuid.htm).

Same information may of course be collected from various sources from Julia
itself or from the operating system, e.g. on Linux from `/proc/cpuinfo`.
However, the `cpuid` instruction should be perfectly portable and efficient.


## Installation and Usage

*CpuId* is not yet a registered package. Clone the repository from the REPL:

    Julia> Pkg.clone("https://github.com/m-j-w/CpuId.jl")


## Features

See the diagnostic summary by typing

    julia> using CpuId
    julia> cpuinfo()

       Cpuid Property   Value
      ╾───────────────╌─────────────────────────────────────────────────────╼
       Brand            Intel(R) Xeon(R) CPU E3-1225 v5 @ 3.30GHz
       Vendor           Intel
       Model            Dict(:Family=>6,:Stepping=>3,:CpuType=>0,:Model=>94)
       Clock Freq.      3300 / 3700 MHz (base/max)
                        100 MHz bus frequency
       Address Size     48 bits virtual, 39 bits physical
       SIMD             max. vector size: 32 bytes = 256 bits
       Data cache       level 1:3 : (32, 256, 8192) kbytes
                        64 byte cache line size
       Hypervised       false


This initial release covers a selection of basic functionality:

 - `cpubrand()`, `cpumodel()`, `cpuvendor()` allow the identification of the
     CPU.
 - `address_size()` and `physical_address_size()` return the number of bits used
     in pointers.  Useful when stealing a few bits from a pointer.
 - `cachelinesize()` gives the size in bytes of one cache line, which is
     typically 64 bytes.
 - `cachesize()` returns a tuple with the sizes of the data caches in bytes.
 - `cpu_base_frequency()`, `cpu_max_frequency()`, `cpu_bus_frequency()` give -
     if supported by the CPU, the base, maximum and bus clock frequencies.
 - `hypervised()` returns true when the CPU indicates that a hypervisor is
     running the operating system, aka a virtual machine.
 - `simdbits()` and `simdbytes()` return the size of the largest SIMD register
     available on the executing CPU.
 - `cpuinfo()` generates the summary shown above (markdown string).


## Limitations

The behaviour on non-Intel CPUs is unknown; a crash of Julia is likely.

There are plenty of different CPUs, and in particular the `cpuid` instruction
has numerous corner cases, which this package does not address, yet.  In systems
having multiple processor packets (independent sockets holding a processor), the
`cpuid` instruction may give only information with respect to the current
physical and logical core that is executing the program code.


## Terms of usage

This Julia package *CpuId* is published as open source and licensed under the
MIT "Expat" License.  See accompanying file ['LICENSE.md'](./LICENSE.md) for
details.


**Contributions welcome!**

You're welcome to report successful usage or issues on GitHub, and to open pull
requests to extend the current functionality.


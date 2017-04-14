# CPU, what can you do?

*CpuId* is a package for the Julia programming language that enables you to
query the availability of specific CPU features with minimal run-time cost
using the assembly instruction `cpuid`.

[![Build Status](https://travis-ci.org/m-j-w/CpuId.jl.svg?branch=master)](https://travis-ci.org/m-j-w/CpuId.jl)
[![Build Status](https://ci.appveyor.com/api/projects/status/q34wl2a441dy87gy?svg=true)](https://ci.appveyor.com/project/m-j-w/cpuid-jl)
[![codecov](https://codecov.io/gh/m-j-w/CpuId.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/m-j-w/CpuId.jl)

_Status: considered a pre-beta version, ready for you to try out._

[![CpuId](http://pkg.julialang.org/badges/CpuId_0.5.svg)](http://pkg.julialang.org/?pkg=CpuId)
[![CpuId](http://pkg.julialang.org/badges/CpuId_0.6.svg)](http://pkg.julialang.org/?pkg=CpuId)

Works on Julia 0.5 and 0.6, on Linux, Mac and Windows with Intel compatible CPUs.


## Motivation

Besides the obvious reason to gather information for diagnostics, the CPU
provides valuable information when aiming at increasing the efficiency of code.
Such use-cases could be to tailor the size of working sets of data according to
the available cache sizes, to detect when the code is executed in a virtual
machine (hypervisor), or to determine the size of the largest SIMD registers
available to choose the best algorithm for the current hardware.

This information is obtained by directly querying the CPU through the `cpuid`
assembly instruction which operates only using CPU register.  In fact,
determining simple boolean feature flags through `cpuid` can be even faster
than accessing a global variable in Julia, in particular if caches are cold.
Also, this provides a portable way to adapt code to unknown hardware if Julia
code is compiled into a static system image (sysimg), where constant globals are
not an option.

Same information may of course be collected from various sources, from Julia
itself or from the operating system, e.g. on Linux from `/proc/cpuinfo`.  See
below for a few [alternatives](#alternatives).  However, the `cpuid` instruction
is perfectly portable and highly efficient.

The full documentation is found in Intel's 4670 page combined [Architectures
Software Devleoper Manual](
http://www.intel.com/content/www/us/en/architecture-and-technology/64-ia-32-architectures-software-developer-manual-325462.html).
A more practical and concise overview of the `cpuid` instruction is found at
[sandpile.org](http://www.sandpile.org/x86/cpuid.htm).


## Installation and Usage

*CpuId* is a registered Julia package; use the package manager to install:

    Julia> Pkg.add("CpuId")

Or, if you're keen to get some intermediate updates, clone from GitHub
[master branch](https://github.com/m-j-w/CpuId.jl/tree/master):

    Julia> Pkg.clone("https://github.com/m-j-w/CpuId.jl")


## Features

See the diagnostic summary on your CPU by typing

```
julia> using CpuId
julia> cpuinfo()

   Cpu Property         Value
  ╾───────────────────╌────────────────────────────────────────────────────────────╼
   Brand                Intel(R) Xeon(R) CPU E3-1225 v5 @ 3.30GHz
   Vendor               :Intel
   Architecture         :Skylake
   Model                Family: 6, Model: 94, Stepping: 3, Type: 0
   Cores                4 physical cores, 4 logical cores (on executing CPU)
                        No Hyperthreading detected
   Clock Frequencies    3300 / 3700 MHz (base/max), 100 MHz bus
   Data Cache           Level 1:3 : (32, 256, 8192) kbytes
                        64 byte cache line size
   Address Size         48 bits virtual, 39 bits physical
   SIMD                 256 bit = 32 byte max. SIMD vector size
   Time Stamp Counter   TSC is accessible via `rdtsc`
                        TSC runs at constant rate (invariant from clock frequency)
   Perf. Monitoring     Performance Monitoring Counters (PMC) available via `rdpmc`
                        Instruction Based Sampling (IBS) is not supported
   Hypervisor           No
```

This release covers a selection of fundamental and higher level functionality:

 - `cpuinfo()` generates the summary shown above (markdown string).
 - `cpubrand()`, `cpumodel()`, `cpuvendor()` allow the identification of the
     CPU.
 - `cpuarchitecture()` tries to infer the microarchitecture, currently only of
     Intel CPUs.
 - `cpucores()` and `cpucores_total()` to determine the number of physical and
     logical cores on the currently executing CPU, which typically share L3
     caches and main memory bandwidth.  If the result of both functions is
     equal, then the CPU does *not* use of hyperthreading.
 - `address_size()` and `physical_address_size()` return the number of bits used
     in pointers.  Useful when stealing a few bits from a pointer.
 - `cachelinesize()` gives the size in bytes of one cache line, which is
     typically 64 bytes.
 - `cachesize()` returns a tuple with the sizes of the data caches in bytes.
 - `cpu_base_frequency()`, `cpu_max_frequency()`, `cpu_bus_frequency()` give -
     if supported by the CPU, the base, maximum and bus clock frequencies.
     Use `has_cpu_frequencies()` to check whether this property is supported.
 - `hypervised()` returns true when the CPU indicates that a hypervisor is
     running the operating system, aka a virtual machine.  In that case,
     `hvvendor()` may be invoked to get the, well, hypervisor vendor, and
     `hvversion()` returns a dictionary of additional version tags.
     `hvversiontable()` generates a markdown summary of same dictionary.
 - `simdbits()` and `simdbytes()` return the size of the largest SIMD register
     available on the executing CPU.
 - `cpucycle()` and `cpucycle_id()` let you directly get the CPU's time stamp
     counter, which is increased for every CPU clock cycle. This is a method to
     perform low overhead micro-benchmarking; though, technically, this uses the
     `rdtsc` and `rdtscp` instructions rather than `cpuid`.
 - `cpufeature(::Symbol)` permits asking for the availability of a specific
     feature, and `cpufeaturetable()` gives a complete overview of all detected
     features with a brief explanation, as shown below.

```
julia> cpufeaturetable()

   Cpu Feature   Description
  ╾────────────╌───────────────────────────────────────────────────────────────╼
   3DNowP        3D Now PREFETCH and PREFETCHW instructions
   ACPI          Thermal monitor and software controlled clock facilities (MSR)
   ADX           Intel ADX (Multi-Precision Add-Carry Instruction Extensions)
   AES           AES encryption instruction set
   AHF64         LAHF and SAHF in PM64
   APIC          APIC on-chip (Advanced Programmable Interrupt Controller)
   AVX           256bit Advanced Vector Extensions, AVX
   AVX2          SIMD 256bit Advanced Vector Extensions 2
   BMI1          Bit Manipulation Instruction Set 1
   BMI2          Bit Manipulation Instruction Set 2
   CLFLUSH       CLFLUSHOPT Instructions
   CLFSH         CLFLUSH instruction (SSE2)
   CMOV          Conditional move CMOV and FCMOV instructions
   CX16          CMPXCHG16B instruction
   CX8           CMPXCHG8 instruction (64bit compare and exchange)
   ...
```

## Background

The `cpuid` instruction is a generic way provided by the CPU vendor to obtain
basic hardware information.  It provides data in form of boolean bit fields,
integer fields and strings, all packed in the returned CPU registers EAX, EBX,
ECX and EDX. Which information is returned is determined by the so called leaf,
which is defined by setting the input register EAX to a specific 32 bit integer
value before executing the instruction.  The extent and kind of information
obtainable via this facility has changed quite a lot over the past decade and
still evolves with every CPU generation.  Thus, not all information is available
on every CPU model, and certainly everything is vendor dependent.

This Julia package also provides the `cpucycle()` function which allows getting
the currently time stamp counter (TSC), which is determined by emitting
a `rdtsc` instruction.  Similarly to `cpuid`, it only requires CPU registers and
is thus, if inlined, probably the lowest overhead method to perform
micro-benchmarking.


## Limitations

The behaviour on non-Intel CPUs is currently unknown; though technically a crash
of Julia could be expected, theoretically, a rather large list of CPUs support
the `cpuid` instruction. Tip: Just try it and report back.

There are plenty of different CPUs, and in particular the `cpuid` instruction
has numerous corner cases, which this package does not address, yet.

Moreover, the `cpuid` instruction can only provide information for the executing
physical CPU, called a package.  To obtain information on all packages, and all
physical and logical cores, the executing program must be pinned sequentially to
each and every core, and gather its properties. This is how `libuv`, `hwloc` or
the operating system obtain that kind information.

In most situations, this is not really required.  Even on machines with multiple
CPUs, the CPUs are typically of the same model.  Furthermore, it is in most
cases only relevant for the currently running process whether that it is
sharing its cache, rather than knowing all the details about other CPUs in the
machine.

Finally, quite a bit of the really interesting information that the CPU collects
is stored in the so called machine specific registers (MSR) or control registers
(CR), which require special 'ring 0' program execution privileges, and which are
not available through the `cpuid` instruction.  For instance the actual CPU
clock frequencies are stored there.Typically, only the kernel and root have
these privileges, but not normal user processes and threads.

#### Specific limitations

- Why aren't all infos available that are seen e.g. in `/proc/cpuinfo`?
    Many of those features, flags and properties reside in the so called machine
    specific registers (MSR), which are only accessible to privileged programs
    running in the so called *ring 0*, such as the Linux kernel itself. Thus,
    short answer: You're not allowed to.

- The results obtained by `CpuId` functions are inconsistent with my hardware!
    Try other programs whether they give the same information or differ. If they
    differ, then you found a bug.  See below for some
    [alternatives](#alternatives), in particular the Linux command line tool
    *cpuid*.

- My hypervisor is not detected!
    Either you're not really running a hypervisor, e.g. *Bash on Windows* is
    _not_ a virtual machine, or there is a feature missing. Raise an issue on
    GitHub.

- When running a hypervisor the presented information is wrong!
    Yeah, well, hypervisor vendors are free to provide the `cpuid` information
    by intercepting calls to that instruction.  Not all vendors comply, and some
    even permit the user to change what is reported.  Thus, expect some
    surprises when a hypervisor is detected.

- `cpucycles()` invokes `rdtsc`; that is not `cpuid`!
    True, but who cares. Both are valuable when diagnosing performance issues
    and trying to perform micro benchmarks based on specific hardware features.


## Alternatives

**Production-ready alternatives:**
On Linux, most of the information may be obtained by reading from the `/proc`
tree, in particular `/proc/cpuinfo`, which eventually also invokes the `cpuid`
instruction.  Type `man 4 cpuid` to get a brief description of this kernel
driver.

On many Linux distributions, there is also the command line tool [cpuid](
http://www.etallen.com/cpuid.html), which essentially does exactly the same.  On
Ubuntu, you would install it using `sudo apt install cpuid`, then use it to show
a summary by simply typing `cpuid`.

Then, of course, there are a few functions in Julia Base. These are
`Base.Sys.cpu_info()`, and `Base.Sys.cpu_summary()`, as well as the global
variables `Base.Sys.CPU_CORES`, and `Base.Sys.cpu_name`.  These are mostly
provided by wrapping *libuv*.  In particular `CPU_CORES` is the reason for this
module: It's intrinsically unclear whether that number includes hyperthreading
cores, or whether it is referring to real physical cores of the current machine.

The Julia package [Hwloc.jl](https://github.com/JuliaParallel/Hwloc.jl) provides
similar and more information primarily directed towards the topology of your
CPUs, viz.  number of CPU packages, physical & logical cores and associated
caches, along with a number of features to deal with thread affinity. However,
it also pulls in additional external binary dependencies in that it relies on
[hwloc](https://www.open-mpi.org/projects/hwloc/), which also implies quite some
computational overhead. Whether this is an issue in the first place depends much
on your use-case.

**The difference:**

*CpuId* takes a different approach in that it talks directly to the CPU. For
instance, asking the CPU for its number of cores or whether it supports AVX2 can
be achieved in probably 250..500 CPU cycles, thanks to Julia's JIT-compilation
approach and inlining. For comparison, 100..200 CPU cycles is roughly loading
one integer from main memory, or one or two integer divisions.  Calling any
external library function is at least one order more cycles. This allows moving
such feature checks much closer or even directly in a hot zone (which, however,
might also hint towards a questionable coding pattern).  Also, *CpuId* gives
additional feature checks, such as whether your executing on a virtual machine,
which again may or may not influence how you set up your high performance
computing tasks in a more general way.  Finally, the `cpuid(...)` function
exposes this low-level interface to the users, enabling them to make equally
fast and reliable run-time feature checks on new or other hardware.


## Terms of usage

This Julia package *CpuId* is published as open source and licensed under the
[MIT "Expat" License](./LICENSE.md).


**Contributions welcome!**

Show that you like this package by giving it a GitHub star. Thanks!  You're also
highly welcome to report successful usage or any issues via GitHub, and to open
pull requests to extend the current functionality.


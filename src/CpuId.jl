#=--- CpuId / CpuId.jl ----------------------------------------------------=#

"""
# Module CpuId

Query information about and directly from your CPU.
"""
module CpuId

export cpuvendor, cpubrand, cpumodel, cachesize, cachelinesize,
       simdbytes, simdbits, address_size, physical_address_size,
       cpu_base_frequency, cpu_max_frequency, cpu_bus_frequency,
       has_cpu_frequencies, hypervised, hvvendor, hvversion,
       hvversiontable, cpucores, cpucores_total, cpucycle, cpucycle_id,
       cpuinfo, cpufeature, cpufeatures, cpufeaturedesc, cpufeaturetable,
       cpuarchitecture

using Base.Markdown: MD

# Particular feature flag query is also externalized due to largeness of dicts.
include("cpufeature.jl")

# The low-level assembly functions are confined to a helper module.
include("CpuInstructions.jl")

using .CpuInstructions: cpuid, rdtsc, rdtscp


"""
Helper function, tagged noinline to not have detrimental effect on
performance.
"""
@noinline _throw_unsupported_leaf(leaf) =
    error("This CPU does not provide information on cpuid leaf 0x$(hex(leaf, sizeof(leaf))).")


"""
Helper function to convert 32 bit registers directly to a Julia string.
"""
@inline __regs_to_string{N}(regs::NTuple{N,UInt32}) =
    unsafe_string(Ptr{UInt8}(pointer_from_objref(regs)), sizeof(regs))

"""
Helper function to convert 32 bit registers directly to a Julia string.
The tuple is guaranteed to be zero terminated.
"""
@inline __regs_to_string_zero{N}(regs::NTuple{N,UInt32}) =
    unsafe_string(Ptr{UInt8}(pointer_from_objref(regs)))


"""
    hasleaf(leaf::UInt32) ::Bool

Helper function (not exported) to test whether the CPU claims to provide the
given leaf in a `cpuid` instruction call.

Note: It appears LLVM really know its gear: If this function is inlined, and
      just-in-time compiled, then this test is eliminated completly if the
      executing machine does support this feature. Yeah!
"""
@inline function hasleaf(leaf::UInt32) ::Bool
    eax, ebx, ecx, edx = cpuid(leaf & 0xffff_0000)
    eax >= leaf
end


"""
    cpucycle()

Read the CPU's [Time Stamp Counter, TSC](https://en.wikipedia.org/wiki/Time_Stamp_Counter),
directly with a `rdtsc` instruction.  This counter is increased for every CPU
cycle, until reset.  This function has, when inlined, practically no overhead
and is, thus, probably the fasted methods to exactly count how many cycles the
CPU has spent working since last read.

Note, the TSC runs at a constant rate if `hasfeature(:TSCINV)==true`;
otherwise, it is tied to the current CPU clock frequency.

Hint: This function is extremely efficient when inlined into your own code.
      Convince yourself by typing `@code_native CpuId.cpucycle()`.
      To use this for benchmarking, simply subtract the results of two calls.
      The result is the actual CPU clock cycles spent, independent of the
      current (and possible non-constant) CPU clock frequency.
"""
function cpucycle end


"""
    cpucycle_id()

Read the CPU's [Time Stamp Counter, TSC](https://en.wikipedia.org/wiki/Time_Stamp_Counter),
and executing CPU id directly with a `rdtscp` instruction.  This function is
similar to the `cpucycle()`, but uses an instruction that also allows to
detect if the code has been moved to a different executing CPU.  See also the
comments for `cpucycle()` which equally apply.
"""
function cpucycle_id end


"""
    cpumodel()

Obtain the CPU model information as a Dict of pairs of
`:Stepping`, `:Model`, `:Family` and `:CpuType`.
"""
function cpumodel() ::Dict{Symbol, UInt8}
    #  Stepping:    0: 3
    #  Model:       4: 7
    #  Family:      8:11
    #  Processor:  12:13
    #  Ext.Model:  16:19
    #  Ext.Family: 20:27
    eax, ebx, ecx, edx = cpuid(0x01)
    Dict( :Family    => UInt8((eax & 0x0000_0F00 >> 8)
                             +(eax & 0x0FF0_0000 >> (20-4)))
        , :Model     => UInt8((eax & 0x0000_00F0 >> 4)
                             +(eax & 0x000F_0000 >> (16-4)))
        , :Stepping  =>  UInt8(eax & 0x0000_000F)
        , :CpuType   =>  UInt8(eax & 0x0000_3000 >> 12))
end


"""
    hypervised()

Check whether the CPU reports to run a hypervisor context, that is,
whether the current process runs in a virtual machine.

A positive answer may indicate that other information reported by the CPU
is fake, such as number of physical and logical cores.  This is because
the hypervisor is free to decide which information to pass.
"""
function hypervised() ::Bool
    # alternative: 0x8000_000a, eax bit 8 set if hv present.
    eax, ebx, ecx, edx = cpuid(0x01)
    ((ecx >> 31) & one(UInt32)) != zero(UInt32)
end


"""
    hvvendorstring()

Determine the hypervisor vendor string as provided by the cpu by executing a
`cpuid` instruction.  Note, this string has a fixed length of 12 characters.
Use `hvvendor()` if you prefer getting a parsed Julia symbol.  If the CPU is
not running a hypervisor, an string of undefined content will be returned.
"""
function hvvendorstring()
    eax, ebx, ecx, edx = cpuid(0x4000_0000)
    __regs_to_string( (ebx, ecx, edx) )
end


"""
    hvversion()

Get a dictionary with additional information of the running hypervisor.  The
dictionary is empty if no hypervisor is detected, and only tags that are
provided by the hypervisor are included.
"""
function hvversion()

    d = Dict{Symbol,Any}()
    !hypervised() && return d

    d[:vendor] = hvvendor()

    # Signature and version info appear to be vendor specific.
    # The following only works well for Microsoft hypervisor.

    leaf = 0x4000_0001
    if hasleaf(leaf)
        eax, ebx, ecx, edx = cpuid(leaf)
        eax != 0x00 && (d[:signature] = __regs_to_string( (eax, ) ))
    end

    leaf = 0x4000_0002
    if hasleaf(leaf)
        eax, ebx, ecx, edx = cpuid(leaf)
        if eax != 0x00 && ebx != 0x00
            d[:build] = Int(eax)
            d[:major] = Int((ebx >> 16) & 0xffff)
            d[:minor] = Int( ebx        & 0xffff)
        end
        if ecx != 0x00 && edx != 0x00
            d[:servicepack]   = Int(ecx)
            d[:servicebranch] = Int((edx >> 24) & 0x0000_00ff)
            d[:servicenumber] = Int( edx        & 0x00ff_ffff)
        end
    end

    # VmWare seems to provide frequency information, but nothing else valuable

    leaf = 0x4000_0010
    if hasleaf(leaf)
        eax, ebx, ecx, edx = cpuid(leaf)
        eax != 0x00 && (d[:tscfreq] = Int(eax))
        ebx != 0x00 && (d[:busfreq] = Int(ebx))
    end

    d
end


"""
    hvversiontable() ::Base.Markdown.MD

Generate a markdown table of all the detected/available/supported tags of a
running hypervisor.  If not running a hypervisor, an empty markdown string is
returned.
"""
function hvversiontable()
    d = hvversion()
    isempty(d) && return Base.Markdown.MD()

    md = "| Hypervisor | Value |\n|:------|:------|\n"

    haskey(d, :vendor) &&
        (md *= string( "| Vendor      | '", d[:vendor], "' |\n"))

    haskey(d, :signature) &&
        (md *= string( "| Signature   | '", d[:signature], "' |\n"))

    haskey(d, :major) &&
        (md *= string( "| Version     | major = '", d[:major], "', minor = '",
                      d[:minor], "', build = '", d[:build], "',  |\n"))

    haskey(d, :servicepack) &&
        (md *= string( "| Servicepack | servicepack = '", d[:servicepack],
                                    "', servicebranch = '", d[:servicebranch],
                                    "', servicenumber = '", d[:servicenumber],
                                    "',  |\n"))

    haskey(d, :tscfreq) &&
        (md *= string( "| Frequencies | TSC = ", d[:tscfreq] ÷ 1000,
                       " MHz, bus = ", d[:busfreq] ÷ 1000, " MHz |\n"))

    Base.Markdown.parse(md)
end


"""
    cpuvendorstring()

Determine the cpu vendor string as provided by the cpu by executing a
`cpuid` instruction.  Note, this string has a fixed length of 12 characters.
Use `cpuvendor()` if you prefer getting a parsed Julia symbol.
"""
function cpuvendorstring()
    eax, ebx, ecx, edx = cpuid(0x00)
    __regs_to_string( (ebx, edx, ecx) )
end


"Map vendor string of type 'char[12]' provided by `cpuid, eax=0x0` to a Julia symbol."
const _cpuid_vendor_id = Dict(
    "AMDisbetter!" => :AMD,
    "AuthenticAMD" => :AMD,
    "CentaurHauls" => :Centaur,
    "CyrixInstead" => :Cyrix,
    "GenuineIntel" => :Intel,
    "Geode by NSC" => :NSC,
    "NexGenDriven" => :NexGen,
    "RiseRiseRise" => :Rise,
    "SiS SiS SiS " => :SiS,
    "TransmetaCPU" => :Transmeta,
    "GenuineTMx86" => :Transmeta,
    "UMC UMC UMC " => :UMC,
    "VIA VIA VIA " => :VIA,
    "Vortex86 SoC" => :Vortex,
    # Hypervisors
    "KVMKVMKVM\0\0\0" => :KVM,   # KVM actually appends null characters...
    "Microsoft Hv" => :Microsoft,
    "prl hyperv  " => :Parallels,
    "VMwareVMware" => :VMware,
    "XenVMMXenVMM" => :Xen,
)


"""
    cpuvendor()

Determine the cpu vendor as a Julia symbol.  In case the CPU vendor
identification is unknown `:Unknown` is returned (then also consider raising
an issue on Github).
"""
cpuvendor() = get(_cpuid_vendor_id, cpuvendorstring(), :Unknown)


"""
    hvvendor()

Determine the hypervisor vendor as a Julia symbol or `:NoHypervisor` if not
running a hypervisor. In case the hypervisor vendor identification is unknown
`:Unknown` is returned (then also consider raising an issue on Github).
"""
hvvendor() = hypervised() ?
                get(_cpuid_vendor_id, hvvendorstring(), :Unknown) :
                :NoHypervisor


"""
    cpubrand()

Determine the cpu brand as a string as provided by the CPU through executing
the `cpuid` instruction.  This function throws if no CPU grand information is
available form the CPU.
"""
function cpubrand() ::String

    leaf = 0x8000_0004
    hasleaf(leaf) || _throw_unsupported_leaf(leaf)

    # Extract the information from leaf 0x8000_0002..0x8000_0004
    __regs_to_string_zero( (cpuid(0x8000_0002)...,
                            cpuid(0x8000_0003)...,
                            cpuid(0x8000_0004)...,
                            0x0000_0000) )
end


"""
    cpuarchitecture()

This function tries to infer the CPU microarchitecture with a call to the
`cpuid` instruction.  For now, only Intel CPUs are suppored according to the
following table.  Others are identified as `:Unknown`.

Table C-1 of Intel's Optimization Reference Manual:

| Family_Model                     | Microarchitecture   |
| :------------------------------- | :------------------ |
| 06_4EH, 06_5EH                   | Skylake             |
| 06_3DH, 06_47H, 06_56H           | Broadwell           |
| 06_3CH, 06_45H, 06_46H, 06_3FH   | Haswell             |
| 06_3AH, 06_3EH                   | Ivy Bridge          |
| 06_2AH, 06_2DH                   | Sandy Bridge        |
| 06_25H, 06_2CH, 06_2FH           | Westmere            |
| 06_1AH, 06_1EH, 06_1FH, 06_2EH   | Nehalem             |
| 06_17H, 06_1DH                   | Enhanced Intel Core |
| 06_0FH                           | Intel Core          |
"""
function cpuarchitecture() ::Symbol

    # See also the C++ library VC++ which has quite good detection.
    # https://github.com/VcDevel/Vc/blob/master/cmake/OptimizeForArchitecture.cmake
    #
    # See also Table 35-1 in Intel's Architectures Software Developer Manual.

    cpumod = cpumodel()
    family = cpumod[:Family]
    model  = cpumod[:Model]

    # Xeon Phi family 0x07, model 0x01
    family == 0x07 && return :XeonPhi

    if family == 0x06
        return (model == 0x4e || model == 0x5e) ? :Skylake :
               (model == 0x3d || model == 0x47 || model == 0x56) ? :Broadwell :
               (model == 0x3c || model == 0x45 || model == 0x46 || model == 0x3f) ?  :Haswell :
               (model == 0x3a || model == 0x3e) ? :IvyBridge :
               (model == 0x2a || model == 0x2d) ? :SandyBridge :
               (model == 0x25 || model == 0x2c || model == 0x2f) ? :Westmere :
               (model == 0x1a || model == 0x1e || model == 0x1f || model == 0x2e) ?  :Nehalem :
               (model == 0x17 || model == 0x1d) ?  :EnhancedIntelCore :
               (model == 0x0f || model == 0x1d) ?  :IntelCore : :UnknownIntel
    end

    return :Unknown
end


"""
    cachelinesize()

Query the CPU about the L1 data cache line size in bytes.  This is typically
64 byte.  Returns zero if cache line size information is not available from
the CPU.
"""
function cachelinesize() ::Int

    # If the extended leaf is not available, same information
    # should be available through leaf 0x01, ebx[15:8]

    leaf = 0x8000_0006
    hasleaf(leaf) || return 0

    eax, ebx, ecx, edx = cpuid(leaf)
    (ecx & 0xff) % Int
end


"""
    simdbytes()

Query the CPU on the maximum supported SIMD vector size in bytes, or
`sizeof(Int)` if no SIMD capability is reported by the invoked `cpuid`
instruction.
"""
@inline function simdbytes() ::Int

    simd = 0

    if hasleaf(0x0000_0007)
        eax, ebx, ecx, edx = cpuid(0x07)
        simd = ebx & (1<<16) != 0 ? 512 ÷ 8 :  # AVX512F instruction set
               ebx & (1<< 5) != 0 ? 256 ÷ 8 : 0   # AVX2
    end

    if simd == 0
        eax, ebx, ecx, edx = cpuid(0x01)
        simd = ecx & (1<<28) != 0 ? 256 ÷ 8 :     # AVX
            edx & (1<<26) != 0 ? 128 ÷ 8 :     # SSE2
            edx & (1<<25) != 0 ? 128 ÷ 8 :     # SSE
            edx & (1<<23) != 0 ?  64 ÷ 8 :     # MMX
            sizeof(Int)
    end

    simd
end


"""
    simdbits()

Query the CPU on the maximum supported SIMD vector size in bits, or
`sizeof(Int)` in bits if no SIMD capability is reported by the invoked `cpuid`
instruction.
"""
@inline simdbits() = simdbytes() * 8


"""
    cpucores()

Determine the number of physical cores on the current executing CPU by
invoking a `cpuid` instruction.  On systems with multiple CPUs, this only
gives information on the single CPU that is executing the code.
Returns zero if querying this feature is not supported, which may also be due
to a running hypervisor (as observed on hvvendor() == :Microsoft).

Also, this function does not take logical cores (aka hyperthreading) into
account, but determines the true number of physical cores, which typically
also share L3 caches and main memory bandwidth.

See also the Julia global variable `Base.Sys.CPU_CORES`, which gives the total
count of all cores on the machine.
"""
function cpucores() ::Int

    leaf = 0x0000_000b
    hasleaf(leaf) || return zero(UInt32)

    # The number of cores reported by cpuid is actually already the total
    # number of cores at that level, including all of the lower levels.
    # Thus, we need to find the highest level...which is 0x02 == "Core"
    # on ecx[15:08] per the specs, and divide it by the number of
    # 0x01 == "SMT" logical cores.

    sl = zero(UInt32)
    nc = zero(UInt32) # "Core" count
    nl = zero(UInt32) # "SMT" count
    while (true)
        # ebx[15:0] must be non-zero according to manual
        eax, ebx, ecx, edx = cpuid(leaf, 0x00, sl)
        ebx & 0xffff == 0x0000 && break
        sl += one(UInt32)
        lt = ((ecx >> 8) & 0xff) & 0x03
        # Let's assume for now there's only one valid entry for each level
        lt == 0x01 && ( nl = ebx & 0xffff; continue )
        lt == 0x02 && ( nc = ebx & 0xffff; continue )
        # others are invalid and shouldn't be considered..
    end
    # we need nonzero values of nc and nl
    (nl == 0x00) ? nc : nc ÷ nl
end


"""
    cpucores_total()

Determine the number of logical cores on the current executing CPU by
invoking a `cpuid` instruction.  On systems with multiple CPUs, this only
gives information on the single CPU that is executing the code.
Returns zero if querying this feature is not supported, which may also be due
to a running hypervisor (as observed on hvvendor() == :Microsoft).

In contrast to `cpucores()`, this function also takes logical cores aka
hyperthreading into account.  For practical purposes, only I/O intensive code
should make use of these total number of cores; memory or computation bound
code will not benefit, but rather experience a detrimental effect.

See also the Julia global variable `Base.Sys.CPU_CORES`, which gives the total
count of all cores on the machine.  Thus, `Base.Sys.CPU_CORES ÷
CpuId.cpucores_total()` gives you the number of CPUs (packages) in your
system.
"""
function cpucores_total() ::Int

    leaf = 0x0000_000b
    hasleaf(leaf) || return zero(UInt32)

    # The number of cores reported by cpuid is actually already the total
    # number of cores at that level, including all of the lower levels.
    # Thus, we only need to find the highest level...which is 0x02 == "Core"
    # on ecx[15:08] per the specs.

    sl = zero(UInt32)
    nc = zero(UInt32)
    while (true)
        # ebx[15:0] must be non-zero according to manual
        eax, ebx, ecx, edx = cpuid(leaf, 0x00, sl)
        ebx & 0xffff == 0x0000 && break
        sl += one(UInt32)
        lt = (ecx >> 8) & 0xff  # level type, 0x01 == "SMT", 0x02 == "Core", other are invalid.
        # Let's assume for now there's only one valid entry for each level
        lt != 0x02 && continue
        nc = ebx & 0xffff
    end
    nc
end


"""
    address_size()

Determine the maximum virtual address size supported by this CPU as
reported by the `cpuid` instructions.

This information may be used to determine the number of high bits that can be
used in a pointer for tagging;  viz. `sizeof(Int) - address_size() ÷ 8`,
which gives on most 64 bit Intel machines 2 bytes = 16 bit for other purposes.
"""
function address_size() ::Int

    leaf = 0x8000_0008
    hasleaf(leaf) || _throw_unsupported_leaf(leaf)

    eax, ebx, ecx, edx = cpuid(leaf)
    (eax & 0xff00) >> 8
end


"""
    physical_address_size()

Determine the maximum phyiscal addresses size supported by this CPU as
reported by the `cpuid` instructions.  Prefer to make use of `address_size`
for practical purposes; use this only for diagnostic issues, such as
determining the theoretical maximum memory size.
"""
function physical_address_size() ::Int

    leaf = 0x8000_0008
    hasleaf(leaf) || _throw_unsupported_leaf(leaf)

    eax, ebx, ecx, edx = cpuid(leaf)
    eax & 0xff
end


"""
    cachesize()
    cachesize(lvl::Integer)

Obtain information on the CPU's *data* cache sizes.

Determine the data cache size for each cache level as reported by the CPU
using a set of calls to the `cpuid` instruction.  Returns a tuple with the
tuple indices matching the cache levels; sizes are given in bytes.

If given an integer, then the data cache size of the respective cache level
will be returned.  This is significantly faster than the tuple version above.

Note that these are total cache sizes, where some cache levels are typically
shared by multiple cpu cores, the higher cache levels may include lower levels.
To print the cache levels in kbyte, use e.g. `CpuId.cachesize() .÷ 1024`.
"""
function cachesize end


"""
Helper function that performs the actual computation of the cache size with
register values retrieved from `cpuid` on leaf 0x04.

> Cache size information on leaf 0x04 is computed with
>     size in bytes = (ways+1) * (partitions+1) * (linesize+1) * (sets+1)
> where
>     ways = ebx[22:31], partitions = ebx[12:21], linesize = ebx[0:11]
>     sets = ecx[:]
"""
@inline function __datacachesize(eax::UInt32, ebx::UInt32, ecx::UInt32) ::UInt32
    (1 + (ebx>>22) & 0x03ff ) *    # ways
    (1 + (ebx>>12) & 0x03ff ) *    # partitions
    (1 +  ebx      & 0x0fff ) *    # linesize
    (1 +  ecx )                    # sets
end


function cachesize()

    # TODO: This is awkwardly slow and requires some rework.
    #       Potential approach: Recurse to the last found cache level, there
    #       allocate a small array, then fill the array when leaving each
    #       recursion level.

    leaf = 0x0000_0004
    hasleaf(leaf) || return ()

    # Called recursively until the first level gives zero cache size

    function cachesize_level(l::UInt32)
        eax, ebx, ecx, edx = cpuid(0x04, 0x00, l)
        # if eax is zero in the lowest 5 bits, we've reached the sentinel.
        eax & 0x1f == 0 && return ()
        # could do a sanity check: cache level reported in eax bits 5:7
        # if lowest bit on eax is zero, then its not a data cache
        eax & 0x01 == 0 && return cachesize_level(l + one(UInt32))
        # otherwise this should be a valid data or shared cache level
        (signed(__datacachesize(eax, ebx, ecx)), cachesize_level(l + one(UInt32))...)
    end

    (cachesize_level(zero(UInt32))...)
end

@inline cachesize(lvl::Integer) = cachesize(UInt32(lvl))

@inline function cachesize(lvl::UInt32) ::Int

    lvl == 0 && return 0

    leaf = 0x0000_0004
    hasleaf(leaf) || _throw_unsupported_leaf(leaf)

    # Loop over all subleafs of leaf 0x04 until the cache level bits say
    # we've reached to target level, then check whether it's a data cache or
    # shared cache.

    # Assuming cache enumeration is linear, it is sufficient to start at
    # sub-leaf 'lvl'. This should limit looping to at most two iterations.
    # Though it might fail... Let's see if there are bug reports for weird
    # architectures.
    sl = lvl - one(UInt32)

    while (true)
        eax, ebx, ecx, edx = cpuid(leaf, zero(UInt32), sl)
        # still at a valid cache level ?
        eax & 0x1f == 0 && return 0
        # is this a data cache or shared cache level, eax[0:4]?
        # and is it the correct level, eax[5:7]?
        (eax & 0x01 == 0x01) && ((eax >> 5) & 0x07) == lvl &&
            return __datacachesize(eax, ebx, ecx)
        sl += one(UInt32)
    end
end


"""
    has_cpu_frequencies()

Determine whether the CPU provides clock frequency information.  If true, then
`cpu_base_frequency()`, `cpu_max_frequency()` and `cpu_bus_frequency()` should
be expected to return sensible information.
"""
function has_cpu_frequencies() ::Bool

    leaf = 0x0000_0016
    hasleaf(leaf) || return false

    # frequencies are provided if any of the bits in question are non-zero
    eax, ebx, ecx = cpuid(leaf)
    (eax & 0xffff) != zero(UInt32) ||
    (ebx & 0xffff) != zero(UInt32) ||
    (ecx & 0xffff) != zero(UInt32)
end


"""
    cpu_base_frequency()

Determine the CPU nominal base frequency in MHz as reported directly from the
CPU through a `cpuid` instruction call.  Returns zero if the CPU doesn't
provide base frequency information.

The actual cpu frequency might be lower due to throttling, or higher due to
frequency boosting (see `cpu_max_frequency`).
"""
function cpu_base_frequency() ::Int

    leaf = 0x0000_0016
    hasleaf(leaf) || return 0

    eax, ebx, ecx, edx = cpuid(leaf)
    eax & 0xffff
end


"""
    cpu_max_frequency()

Determine the maximum CPU frequency in MHz as reported directly from the CPU
through a `cpuid` instrauction call.  The maximum frequency typically refers
to the CPU's boost frequency.  Returns zero if the CPU doesn't provide maximum
frequency information.
"""
function cpu_max_frequency() ::Int

    leaf = 0x0000_0016
    hasleaf(leaf) || return 0

    eax, ebx, ecx, edx = cpuid(leaf)
    ebx & 0xffff
end


"""
    cpu_bus_frequency()

Determine the bus CPU frequency in MHz as reported directly from the CPU through
a `cpuid` instrauction call.  Returns zero if the CPU doesn't
provide bus frequency information.
"""
function cpu_bus_frequency() ::Int

    leaf = 0x0000_0016
    hasleaf(leaf) || return 0

    eax, ebx, ecx, edx = cpuid(leaf)
    ecx & 0xffff
end


"""
    cpuinfo()

Generate a markdown table with the results of all of the CPU querying
functions provided by the module `CpuId`.  Intended to give a quick overview
for diagnostic purposes e.g. in log files.
"""
function cpuinfo()

    # This code truly sucks...

    Base.Markdown.parse("""
| `Cpuid` Property | Value                                          |
|:-------------|:---------------------------------------------------|
| Brand        | $(CpuId.cpubrand())                                |
| Vendor       | $(CpuId.cpuvendor())                               |
| Architecture | $(CpuId.cpuarchitecture())                         |
| Model        | $(CpuId.cpumodel())                                |
| Cores        | $(CpuId.cpucores()) physical cores, $(CpuId.cpucores_total()) logical cores (on executing CPU) |
|              | $(CpuId.cpucores() == CpuId.cpucores_total() ? "No" : "") Hyperthreading detected  |
| Address Size | $(CpuId.address_size()) bits virtual, $(CpuId.physical_address_size()) bits physical |
| SIMD         | max. vector size: $(CpuId.simdbytes()) bytes = $(CpuId.simdbits()) bits    |
| Data cache   | level $(1:length(CpuId.cachesize())) : $(map(x->div(x,1024), CpuId.cachesize())) kbytes |
|              | $(CpuId.cachelinesize()) byte cache line size      | """ *
    ( has_cpu_frequencies() ?
"\n| Clock Freq.  | $(CpuId.cpu_base_frequency()) / $(CpuId.cpu_max_frequency()) MHz (base/max frequency) |
|              | $(CpuId.cpu_bus_frequency()) MHz bus frequency     | " : "") *
"\n| TSC       | Time Stamp Counter is " * (cpufeature(:TSC) ? "" : "not ") * "accessible by user code |" *
"\n|           | " * (cpufeature(:TSCINV) ? "TSC runs at constant rate (invariant from clock frequency)" :
                                          "TSC increased at every clock cycle (non-invariant TSC)")* " |" *
"\n| Hypervisor     |" * (CpuId.hypervised() ?  " Yes, $(CpuId.hvvendor()) " : " No ") * " |")
end


"""
Enables and disables a few functions depending on whether the features are
actually available.  This should overcome a potential efficiency issue when
calling those functions in a hot zone.
"""
function __init__()
    # Do we have priviledged access to `rdtsc` instructions?
    if (cpufeature(:TSC))
        eval(:(cpucycle()    = rdtsc()))
    else
        eval(:(cpucycle()    = zero(UInt64)))
    end
    if (cpufeature(:RDTSCP))
        eval(:(cpucycle_id() = rdtscp()))
    else
        eval(:(cpucycle_id() = (zero(UInt64),zero(UInt64))))
    end
end


end # module CpuId

#=--- end of file ---------------------------------------------------------=#

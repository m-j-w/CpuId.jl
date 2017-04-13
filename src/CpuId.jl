"""
# Module CpuId

Query information about and directly from your CPU.
"""
module CpuId

export cpuvendor, cpubrand, cpumodel, cachesize, cachelinesize,
       simdbytes, simdbits, address_size, physical_address_size,
       cpu_base_frequency, cpu_max_frequency, cpu_bus_frequency,
       has_cpu_frequencies, hypervised, hvvendor, cpuinfo


"""
    cpuid(eax, ebx, ecx, edx)

Invoke the cpu's hardware instruction `cpuid` with the values of the arguments
stored as registers EAX, EBX, ECX, EDX, respectively. Returns a tuple
of the response of same registers.  Input values may be given as individaul
`UInt32` arguments, or as a tuple of the same.  Unspecified arguments are
assumed zero.

This function is primarily intended as a low-level interface to the CPU.

Note: Expected to work on all CPUs that implement the assembly instruction
      `cpuid`, which is at least Intel and AMD.
"""
function cpuid end

@inline cpuid(eax, ebx = 0, ecx = 0, edx = 0) = cpuid(map(UInt32, (eax, ebx, ecx, edx)))
@inline cpuid(;eax = 0, ebx = 0, ecx = 0, edx = 0) = cpuid(eax, ebx, ecx, edx)

# Variant for input registers provided as a 4-tuple
using Base: llvmcall
@inline cpuid(exx::Tuple{UInt32,UInt32,UInt32,UInt32}) =
    llvmcall("""
        ; load the values from the tuple
        %2 = extractvalue [4 x i32] %0, 0
        %3 = extractvalue [4 x i32] %0, 1
        %4 = extractvalue [4 x i32] %0, 2
        %5 = extractvalue [4 x i32] %0, 3
        ; call 'cpuid' with those pointers being loaded into registers EAX, EBX, ECX, EDX
        %6 = tail call { i32, i32, i32, i32 } asm "cpuid", "={ax},={bx},={cx},={dx},0,1,2,3,~{dirflag},~{fpsr},~{flags}"(i32 %2, i32 %3, i32 %4, i32 %5) #7
        ; retrieve the result values and convert to vector [4 x i32]
        %7  = extractvalue { i32, i32, i32, i32 } %6, 0
        %8  = extractvalue { i32, i32, i32, i32 } %6, 1
        %9  = extractvalue { i32, i32, i32, i32 } %6, 2
        %10 = extractvalue { i32, i32, i32, i32 } %6, 3
        ; return the values as a new tuple
        %11 = insertvalue [4 x i32] undef, i32  %7, 0
        %12 = insertvalue [4 x i32]  %11 , i32  %8, 1
        %13 = insertvalue [4 x i32]  %12 , i32  %9, 2
        %14 = insertvalue [4 x i32]  %13 , i32 %10, 3
        ret [4 x i32] %14"""
    # llvmcall requires actual types, rather than the usual (...) tuple
    , NTuple{4,UInt32}, Tuple{NTuple{4,UInt32}}
    , exx)


"""
    cpumodel()

Obtain the CPU model information as a Dict of pairs of
`:Stepping`, `:Model`, `:Family` and `:CpuType`.
"""
function cpumodel()
    #  Stepping:    0: 3
    #  Model:       4: 7
    #  Family:      8:11
    #  Processor:  12:13
    #  Ext.Model:  16:19
    #  Ext.Family: 20:27
    eax, ebx, ecx, edx = cpuid(1)
    Dict( :Family    => Int((eax & 0x0000_0F00 >> 8)
                           +(eax & 0x0FF0_0000 >> (20-4)))
        , :Model     => Int((eax & 0x0000_00F0 >> 4)
                           +(eax & 0x000F_0000 >> (16-4)))
        , :Stepping  =>  Int(eax & 0x0000_000F)
        , :CpuType   =>  Int(eax & 0x0000_3000 >> 12))
end

"""
    hypervised()

Check whether the CPU reports to run a hypervisor context, that is,
whether the current process runs in a virtual machine.

A positive answer may indicate that other information reported by the CPU
is erroneous, such as number of physical and logical cores.
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
not running a hypervisor, an empty string will be returned.
"""
function hvvendorstring()
    eax, ebx, ecx, edx = cpuid(0x4000_0000)
    transcode(String, reinterpret(UInt8, [ebx, ecx, edx]))
end


"""
    cpuvendorstring()

Determine the cpu vendor string as provided by the cpu by executing a
`cpuid` instruction.  Note, this string has a fixed length of 12 characters.
Use `cpuvendor()` if you prefer getting a parsed Julia symbol.
"""
function cpuvendorstring()
    eax, ebx, ecx, edx = cpuid(0x00)
    transcode(String, reinterpret(UInt8, [ebx, edx, ecx]))
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
    "KVMKVMKVM"    => :KVM,
    "Microsoft Hv" => :Microsoft,
    "prl hyperv  " => :Parallels,
    "VMwareVMware" => :VMware,
    "XenVMMXenVMM" => :Xen,
)


"""
    cpuvendor()

Determine the cpu vendor as a Julia symbol.
"""
cpuvendor() = get(_cpuid_vendor_id, cpuvendorstring(), :Unknown)


"""
    hvvendor()

Determine the hypervisor vendor as a Julia symbol or `:Unknown` if not running
a hypervisor.
"""
hvvendor() = get(_cpuid_vendor_id, hvvendorstring(), :Unknown)


"""
    cpubrand()

Determine the cpu brand as a string as provided by the CPU through executing
the `cpuid` instruction.
"""
function cpubrand()

    @noinline _throw_unsupported_leaf(leaf) =
            error("This cpu does not provide information on leaf $(leaf).")

    # Check availability of cpu brand information feature
    eax, ebx, ecx, edx = cpuid(0x8000_0000)
    eax < 0x8000_0004 && _throw_unsupported_leaf(0x8000_0004)

    # Extract the information from leaf 0x8000_0002..0x8000_0004
    s = ""
    for leaf = 0x8000_0002:0x8000_0004
        eax, ebx, ecx, edx = cpuid(leaf)
        s *= transcode(String, reinterpret(UInt8, [eax, ebx, ecx, edx]))
    end
    # strip leading and trailing blanks and zero character(s)
    strip(strip(s),'\0')
end


"""
    cachelinesize()

Query the CPU about the L1 data cache line size in bytes.
This is typically 64 byte.
"""
function cachelinesize()

    @noinline _throw_cachelinesize_error() =
            error("This CPU doesn't support cache line size information.")

    eax, ebx, ecx, edx = cpuid(0x8000_0000)
    eax < 0x8000_0006 && _throw_cachelinesize_error()

    eax, ebx, ecx, edx = cpuid(0x8000_0006)
    (ecx & 0xff) % Int
end


"""
    simdbytes()

Query the CPU on the maximum supported SIMD vector size in bytes, or
`sizeof(Int)` if no SIMD capability is reported by the invoked `cpuid`
instruction.
"""
@inline function simdbytes()

    eax, ebx, ecx, edx = cpuid(0x07)
    simd = ebx & (1<<16) != 0 ? 512 ÷ 8 :     # AVX512F instruction set
           ebx & (1<< 5) != 0 ? 256 ÷ 8 : 0   # AVX2
    simd != 0 && return simd

    eax, ebx, ecx, edx = cpuid(0x01)
    simd = ecx & (1<<28) != 0 ? 256 ÷ 8 :     # AVX
           edx & (1<<26) != 0 ? 128 ÷ 8 :     # SSE2
           edx & (1<<25) != 0 ? 128 ÷ 8 :     # SSE
           edx & (1<<23) != 0 ?  64 ÷ 8 :     # MMX
           sizeof(Int)
end


"""
    simdbits()

Query the CPU on the maximum supported SIMD vector size in bits, or
`sizeof(Int)` in bits if no SIMD capability is reported by the invoked `cpuid`
instruction.
"""
@inline simdbits() = simdbytes() * 8


"""
    address_size()

Determine the maximum virtual address size supported by this CPU as
reported by the `cpuid` instructions.

This information may be used to determine the number of high bits that can be
used in a pointer for tagging;  viz. `sizeof(Int) - address_size() ÷ 8`,
which gives on most 64 bit Intel machines 2 bytes = 16 bit for other purposes.
"""
function address_size() ::Int
    eax, ebx, ecx, edx = cpuid(0x8000_0008)
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
    eax, ebx, ecx, edx = cpuid(0x8000_0008)
    eax & 0xff
end

"""
    cachesize()

Determine the data cache size for each cache level as reported by the CPU
using a set of calls to the `cpuid` instruction.  Returns a tuple with the
tuple indices matching the cache levels; sizes are given in bytes.

Note that these are total cache sizes, where some cache levels are typically
shared by multiple cpu cores, the higher cache levels may include lower levels.
To print the cache levels in kbyte, use e.g. `CpuId.cachesize() .÷ 1024`.
"""
function cachesize()

    @noinline _throw_unsupported_leaf(leaf) =
            error("This cpu does not provide information on leaf $(leaf).")

    # Do we have a leaf 4?
    eax, ebx, ecx, edx = cpuid(0x00)
    eax < 0x04 && _throw_unsupported_leaf(0x04)

    # Cache size information on leaf 0x04 is computed with
    #  size in bytes = (ways+1) * (partitions+1) * (linesize+1) * (sets+1)
    #  ways = ebx[22:31], partitions = ebx[12:21], linesize = ebx[0:11]
    #  sets = ecx[:]

    # Called recursively until the first level gives zero cache size

    function cachesize_level(l::UInt32 = zero(UInt32))
        eax, ebx, ecx, edx = cpuid(0x04, 0x00, l)
        # --- appveyor ---
        # if eax is zero in the lowest 5 bits, we've reached the sentinel.
        eax & 0x1f == 0 && return ()
        # could do a sanity check: cache level reported in eax bits 5:7
        # if lowest bit on eax is zero, then its not a data cache
        eax & 0x01 == 0 && return cachesize_level(l + one(UInt32))
        # otherwise this should be a valid data or shared cache level
        s = (1 + (ebx>>22) & 0x03ff ) *    # ways
            (1 + (ebx>>12) & 0x03ff ) *    # partitions
            (1 +  ebx      & 0x0fff ) *    # linesize
            (1 +  ecx )                    # sets
        (signed(s), cachesize_level(l + one(UInt32))...)
    end

    (cachesize_level()...)
end


"""
    has_cpu_frequencies()

Determine whether the CPU provides clock frequency information.  If true, then
`cpu_base_frequency()`, `cpu_max_frequency()` and `cpu_bus_frequency()` should
be expected to return sensible information.
"""
function has_cpu_frequencies() ::Bool
    eax, ebx, ecx, edx = cpuid(0x00)
    eax >= 0x16
end


"""
    cpu_base_frequency()

Determine the CPU base frequency in MHz as reported directly from the CPU
through a `cpuid` instruction call.  The actual cpu frequency might be lower
due to throttling, or higher due to frequency boosting.
"""
function cpu_base_frequency() ::Int

    # Do we have a leaf 16?
    eax, ebx, ecx, edx = cpuid(0x00)
    eax < 0x16 && return -1

    eax, ebx, ecx, edx = cpuid(0x16)
    eax & 0xffff
end


"""
    cpu_max_frequency()

Determine the maximum CPU frequency in MHz as reported directly from the CPU
through a `cpuid` instrauction call.  Returns minus one if the CPU doesn't
support this query.
"""
function cpu_max_frequency() ::Int

    # Do we have a leaf 16?
    eax, ebx, ecx, edx = cpuid(0x00)
    eax < 0x16 && return -1

    eax, ebx, ecx, edx = cpuid(0x16)
    ebx & 0xffff
end


"""
    cpu_bus_frequency()

Determine the bus CPU frequency in MHz as reported directly from the CPU through
a `cpuid` instrauction call.
"""
function cpu_bus_frequency() ::Int

    # Do we have a leaf 16?
    eax, ebx, ecx, edx = cpuid(0x00)
    eax < 0x16 && return -1

    eax, ebx, ecx, edx = cpuid(0x16)
    ecx & 0xffff
end

using Base.Markdown: MD, @md_str

"""
    cpuinfo()

Generate a markdown table with the results of all of the CPU querying
functions provided by the module `CpuId`.  Intended to give a quick overview
for diagnostic purposes e.g. in log files.
"""
function cpuinfo()
    Base.Markdown.parse("""
| `Cpuid` Property | Value                                          |
|:-------------|:---------------------------------------------------|
| Brand        | $(CpuId.cpubrand())                                |
| Vendor       | $(CpuId.cpuvendor())                               |
| Model        | $(CpuId.cpumodel())                                |
| Address Size | $(CpuId.address_size()) bits virtual, $(CpuId.physical_address_size()) bits physical |
| SIMD         | max. vector size: $(CpuId.simdbytes()) bytes = $(CpuId.simdbits()) bits    |
| Data cache   | level $(1:length(CpuId.cachesize())) : $(map(x->div(x,1024), CpuId.cachesize())) kbytes |
|              | $(CpuId.cachelinesize()) byte cache line size      | """ *
    ( has_cpu_frequencies() ?
"\n| Clock Freq.  | $(CpuId.cpu_base_frequency()) / $(CpuId.cpu_max_frequency()) MHz (base/max) |
|              | $(CpuId.cpu_bus_frequency()) MHz bus frequency     | " : "") *
"\n| Hypervisor   |" * (CpuId.hypervised() ?  " Yes, $(CpuId.hvvendor()) " : " No ") * " |")
end


end # module CpuId

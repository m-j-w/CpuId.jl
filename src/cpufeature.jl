#=--- CpuId / cpufeature.jl -----------------------------------------------=#

#
# Functions to query single bit feature flags.
#


"""
Tuple of cpuid leaf in eax, result register and bit, and a descriptive
string.  Sources are Wikipedia and sandpile.org.
"""
const __cpufeaturemap = Dict{Symbol, Tuple{UInt32, Symbol, UInt32, String}}(
    :SSE3          => (0x0000_0001, :ECX , 0  , "128bit Streaming SIMD Extensions 3"),
    :PCLMUL        => (0x0000_0001, :ECX , 1  , "PCLMULQDQ support"),
    :DTES64        => (0x0000_0001, :ECX , 2  , "64bit debug store"),
    :MON           => (0x0000_0001, :ECX , 3  , "MONITOR and MWAIT instructions"),
    :DSCPL         => (0x0000_0001, :ECX , 4  , "CPL qualified debug store"),
    :VMX           => (0x0000_0001, :ECX , 5  , "Virtual machine extensions"),
    :SMX           => (0x0000_0001, :ECX , 6  , "Safer mode instructions"),
    :EST           => (0x0000_0001, :ECX , 7  , "Enhanced SpeedStep"),
    :TM2           => (0x0000_0001, :ECX , 8  , "Thermal monitor 2"),
    :SSSE3         => (0x0000_0001, :ECX , 9  , "128bit Supplemental Streaming SIMD Extension 3"),
    :CNXT          => (0x0000_0001, :ECX , 10 , "L1 context ID"),
    :SDBG          => (0x0000_0001, :ECX , 11 , "Silicon debug interface"),
    :FMA3          => (0x0000_0001, :ECX , 12 , "Fused multiply-add using three operands"),
    :CX16          => (0x0000_0001, :ECX , 13 , "CMPXCHG16B instruction"),
    :XTPR          => (0x0000_0001, :ECX , 14 , "disabling sending of task priority messages"),
    :PDCM          => (0x0000_0001, :ECX , 15 , "Perfmon and debug capabilities"),
     #:reserved    => (0x0000_0001, :ECX , 16 , ""),
    :PCID          => (0x0000_0001, :ECX , 17 , "Process context identifiers"),
    :DCA           => (0x0000_0001, :ECX , 18 , "Direct cache access for DMA writes"),
    :SSE41         => (0x0000_0001, :ECX , 19 , "128bit Streaming SIMD Extensions 4.1"),
    :SSE42         => (0x0000_0001, :ECX , 20 , "128bit Streaming SIMD Extensions 4.2"),
    :X2APIC        => (0x0000_0001, :ECX , 21 , "x2APIC support"),
    :MOVBE         => (0x0000_0001, :ECX , 22 , "MOVBE instruction"),
    :POPCNT        => (0x0000_0001, :ECX , 23 , "POPCNT instruction"),
    :TSCDL         => (0x0000_0001, :ECX , 24 , "APIC one-shot operation using TSC deadline value"),
    :AES           => (0x0000_0001, :ECX , 25 , "AES encryption instruction set"),
    :XSAVE         => (0x0000_0001, :ECX , 26 , "XSAVE, XRESTOR, XSETBV, XGETBV"),
    :OSXSV         => (0x0000_0001, :ECX , 27 , "XSAVE enabled by OS"),
    :AVX           => (0x0000_0001, :ECX , 28 , "256bit Advanced Vector Extensions, AVX"),
    :F16C          => (0x0000_0001, :ECX , 29 , "half-precision float support"),
    :RDRND         => (0x0000_0001, :ECX , 30 , "On-chip random number generator"),
    :HYPVS         => (0x0000_0001, :ECX , 31 , "Running on hypervisor"),
    # See Intel dev manual table 3-11
    :FPU           => (0x0000_0001, :EDX , 0  , "Onboard x87 FPU"),
    :VME           => (0x0000_0001, :EDX , 1  , "Virtual 8086 mode enhancements"),
    :DE            => (0x0000_0001, :EDX , 2  , "Debugging extensions"),
    :PSE           => (0x0000_0001, :EDX , 3  , "Page size extensions"),
    :TSC           => (0x0000_0001, :EDX , 4  , "Time stamp counter"),
    :MSR           => (0x0000_0001, :EDX , 5  , "Model Specific Registers, RDMSR and WRMSR instructions"),
    :PAE           => (0x0000_0001, :EDX , 6  , "Physical address extension"),
    :MCE           => (0x0000_0001, :EDX , 7  , "Machine check exception"),
    :CX8           => (0x0000_0001, :EDX , 8  , "CMPXCHG8 instruction (64bit compare and exchange)"),
    :APIC          => (0x0000_0001, :EDX , 9  , "APIC on-chip (Advanced Programmable Interrupt Controller)"),
     #:reserved    => (0x0000_0001, :EDX , 10 , ""),
    :SEP           => (0x0000_0001, :EDX , 11 , "SYSENTER and SYSEXIT instructions"),
    :MTRR          => (0x0000_0001, :EDX , 12 , "Memory Type Range Registers"),
    :PGE           => (0x0000_0001, :EDX , 13 , "Page global bit"),
    :MCA           => (0x0000_0001, :EDX , 14 , "Machine Check Architecture (MSR)"),
    :CMOV          => (0x0000_0001, :EDX , 15 , "Conditional move CMOV and FCMOV instructions"),
    :PAT           => (0x0000_0001, :EDX , 16 , "Page attribute table"),
    :PSE36         => (0x0000_0001, :EDX , 17 , "36bit page size extension"),
    :PSN           => (0x0000_0001, :EDX , 18 , "Processor serial number (only available on Pentium III)"),
    :CLFSH         => (0x0000_0001, :EDX , 19 , "CLFLUSH instruction (SSE2)"),
     #:reserved    => (0x0000_0001, :EDX , 20 , ""),
    :DS            => (0x0000_0001, :EDX , 21 , "Debug store to save trace of executed jumps"),
    :ACPI          => (0x0000_0001, :EDX , 22 , "Thermal monitor and software controlled clock facilities (MSR)"),
    :MMX           => (0x0000_0001, :EDX , 23 , "64bit Multimedia Streaming Extensions"),
    :FXSR          => (0x0000_0001, :EDX , 24 , "FXSAVE, FXRSTOR instructions"),
    :SSE           => (0x0000_0001, :EDX , 25 , "128bit Streaming SIMD Extensions 1"),
    :SSE2          => (0x0000_0001, :EDX , 26 , "128bit Streaming SIMD Extensions 2"),
    :SS            => (0x0000_0001, :EDX , 27 , "Self Snoop"),
    :HTT           => (0x0000_0001, :EDX , 28 , "Max APIC IDs reserved field is valid"),
    :TM            => (0x0000_0001, :EDX , 29 , "Thermal monitor with automatic thermal control"),
    :IA64          => (0x0000_0001, :EDX , 30 , "IA64 processor emulating x86"),
    :PBE           => (0x0000_0001, :EDX , 31 , "Pending break enable wakeup support"),
     #
    :FSGS          => (0x0000_0007, :EBX , 0  , "Access to base of %fs and %gs"),
    :TSCADJ        => (0x0000_0007, :EBX , 1  , "IA32_TSC_ADJUST"),
    :SGX           => (0x0000_0007, :EBX , 2  , "Software Guard Extensions"),
    :BMI1          => (0x0000_0007, :EBX , 3  , "Bit Manipulation Instruction Set 1"),
    :HLE           => (0x0000_0007, :EBX , 4  , "Transactional Synchronization Extensions"),
    :AVX2          => (0x0000_0007, :EBX , 5  , "SIMD 256bit Advanced Vector Extensions 2"),
    :SMEP          => (0x0000_0007, :EBX , 7  , "Supervisor-Mode Execution Prevention"),
    :BMI2          => (0x0000_0007, :EBX , 8  , "Bit Manipulation Instruction Set 2"),
    :ERMS          => (0x0000_0007, :EBX , 9  , "Enhanced REP MOVSB/STOSB"),
    :INVPCID       => (0x0000_0007, :EBX , 10 , "INVPCID instruction"),
    :RTM           => (0x0000_0007, :EBX , 11 , "Transactional Synchronization Extensions"),
    :PQM           => (0x0000_0007, :EBX , 12 , "Platform Quality of Service Monitoring"),
    :FPDPR         => (0x0000_0007, :EBX , 13 , "FPU CS and FPU DS deprecated"),
    :MPX           => (0x0000_0007, :EBX , 14 , "Intel MPX (Memory Protection Extensions)"),
    :PQE           => (0x0000_0007, :EBX , 15 , "Platform Quality of Service Enforcement"),
    :AVX512F       => (0x0000_0007, :EBX , 16 , "AVX-512 Foundation"),
    :AVX512DQ      => (0x0000_0007, :EBX , 17 , "AVX-512 Doubleword and Quadword Instructions"),
    :RDSEED        => (0x0000_0007, :EBX , 18 , "RDSEED instruction"),
    :ADX           => (0x0000_0007, :EBX , 19 , "Intel ADX (Multi-Precision Add-Carry Instruction Extensions)"),
    :SMAP          => (0x0000_0007, :EBX , 20 , "Supervisor Mode Access Prevention"),
    :AVX512IFMA    => (0x0000_0007, :EBX , 21 , "AVX-512 Integer Fused Multiply-Add Instructions"),
    :PCOMMIT       => (0x0000_0007, :EBX , 22 , "PCOMMIT instruction"),
    :CLFLUSH       => (0x0000_0007, :EBX , 23 , "CLFLUSHOPT Instructions"),
    :CLWB          => (0x0000_0007, :EBX , 24 , "CLWB instruction"),
    :IPT           => (0x0000_0007, :EBX , 25 , "Intel Processor Trace"),
    :AVX512PF      => (0x0000_0007, :EBX , 26 , "AVX-512 Prefetch Instructions"),
    :AVX512ER      => (0x0000_0007, :EBX , 27 , "AVX-512 Exponential and Reciprocal Instructions"),
    :AVX512CD      => (0x0000_0007, :EBX , 28 , "AVX-512 Conflict Detection Instructions"),
    :SHA           => (0x0000_0007, :EBX , 29 , "Intel SHA extensions"),
    :AVX512BW      => (0x0000_0007, :EBX , 30 , "AVX-512 Byte and Word Instructions"),
    :AVX512VL      => (0x0000_0007, :EBX , 31 , "AVX-512 Vector Length Extensions"),
    :PREFTCHWT1    => (0x0000_0007, :ECX , 0  , "PREFETCHWT1 instruction"),
    :AVX512VBMI    => (0x0000_0007, :ECX , 1  , "AVX-512 Vector Bit Manipulation Instructions"),
    :UMIP          => (0x0000_0007, :ECX , 2  , "User-mode Instruction Prevention"),
    :PKU           => (0x0000_0007, :ECX , 3  , "Memory Protection Keys for User-mode pages"),
    :OSPKE         => (0x0000_0007, :ECX , 4  , "PKU enabled by OS"),
    :RDPID         => (0x0000_0007, :ECX , 22 , "Read Processor ID"),
    :SGXLC         => (0x0000_0007, :ECX , 30 , "SGX Launch Configuration"),
    :AVX512VNNIW   => (0x0000_0007, :EDX , 2  , "AVX-512 Neural Network Instructions"),
    :AVX512FMAPS   => (0x0000_0007, :EDX , 3  , "AVX-512 Multiply Accumulation Single precision"),
    :AHF64         => (0x8000_0001, :ECX , 0  , "LAHF and SAHF in PM64"),
    :CMPLEG        => (0x8000_0001, :ECX , 1  , "HTT or CMP flag"),
    :SVM           => (0x8000_0001, :ECX , 2  , "VMRUN, VMCALL, VMLOAD and VMSAVE etc."),
    :EXTAPIC       => (0x8000_0001, :ECX , 3  , "Extended APIC space"),
    :CR8D          => (0x8000_0001, :ECX , 4  , "MOV from and to CR8D"),
    :LZCNT         => (0x8000_0001, :ECX , 5  , "LZCNT instruction"),
    :SSE4A         => (0x8000_0001, :ECX , 6  , "Streaming SIMD extensions 4A"),
    :SSEMISALIGN   => (0x8000_0001, :ECX , 7  , "Misaligned SSE"),
    Symbol("3DNowP")=>(0x8000_0001, :ECX , 8  , "3D Now PREFETCH and PREFETCHW instructions"),
    :OSVW          => (0x8000_0001, :ECX , 9  , "Operating-system-visible workaround"),
    :IBS           => (0x8000_0001, :ECX , 10 , "Instruction Based Sampling (IBS)"),
    :XOP           => (0x8000_0001, :ECX , 11 , "XOP"),
    :SKINIT        => (0x8000_0001, :ECX , 12 , "SKINIT, STGI, DEV"),
    :WDT           => (0x8000_0001, :ECX , 13 , "Watch dog timer"),
     #:reserved    => (0x8000_0001, :ECX , 14 , ""),
    :LWP           => (0x8000_0001, :ECX , 15 , "LWP"),
    :FMA4          => (0x8000_0001, :ECX , 16 , "4-operand fused multiply add instruction"),
    :TCE           => (0x8000_0001, :ECX , 17 , "Translation cache extension"),
     #:reserved    => (0x8000_0001, :ECX , 18 , ""),
    :NODEID        => (0x8000_0001, :ECX , 19 , "Node ID (MSR)"),
     #:reserved    => (0x8000_0001, :ECX , 20 , ""),
    :TBM           => (0x8000_0001, :ECX , 21 , "TBM"),
    :TOPX          => (0x8000_0001, :ECX , 22 , "Topology extensions on 0x8000'001D to 0x8000'001E"),
    :PCXCORE       => (0x8000_0001, :ECX , 23 , "Core performance counter extensions"),
    :PCXNB         => (0x8000_0001, :ECX , 24 , "NB performance counter extensions"),
     #:reserved    => (0x8000_0001, :ECX , 25 , ""),
    :DBX           => (0x8000_0001, :ECX , 26 , "Data breakpoint extensions"),
    :PERFTSC       => (0x8000_0001, :ECX , 27 , "Performance TSC"),
    :PCXL2I        => (0x8000_0001, :ECX , 28 , "L2I performance counter extensions"),
    :MONX          => (0x8000_0001, :ECX , 29 , "MONITORX/MWAITX instructions"),
     #:reserved    => (0x8000_0001, :ECX , 30 , ""),
     #:reserved    => (0x8000_0001, :ECX , 31 , ""),
    :FPU_          => (0x8000_0001, :EDX , 0  , "FPU"),
    :VME_          => (0x8000_0001, :EDX , 1  , "CR4"),
    :DE_           => (0x8000_0001, :EDX , 2  , "MOV from and to DR4 and DR5"),
    :PSE_          => (0x8000_0001, :EDX , 3  , "PSE"),
    :TSC_          => (0x8000_0001, :EDX , 4  , "RSC, RDTSC, CR4.TSC"),
    :MSR_          => (0x8000_0001, :EDX , 5  , "RDMSR and WDMSR"),
    :PAE_          => (0x8000_0001, :EDX , 6  , "PDPTE 64bit"),
    :MCE_          => (0x8000_0001, :EDX , 7  , "MCE (MSR)"),
    :CX8_          => (0x8000_0001, :EDX , 8  , "CMPXCHG8B"),
    :APIC_         => (0x8000_0001, :EDX , 9  , "APIC"),
     #:reserved    => (0x8000_0001, :EDX , 10 , ""),
    :SYSCALL       => (0x8000_0001, :EDX , 11 , "SYSCALL and SYSRET"),
    :MTRR_         => (0x8000_0001, :EDX , 12 , "MTRR (MSR)"),
    :PGE_          => (0x8000_0001, :EDX , 13 , "PDE and PTE"),
    :MCA_          => (0x8000_0001, :EDX , 14 , "MCA"),
    :CMOV_         => (0x8000_0001, :EDX , 15 , "CMOVxx"),
    :PAT_          => (0x8000_0001, :EDX , 16 , "FCMOVxx"),
    :PSE36_        => (0x8000_0001, :EDX , 17 , "4 MB PDE bits 16..13"),
     #:reserved    => (0x8000_0001, :EDX , 18 , ""),
    :MP            => (0x8000_0001, :EDX , 19 , "MP capable"),
    :NX            => (0x8000_0001, :EDX , 20 , "NXE"),
     #:reserved    => (0x8000_0001, :EDX , 21 , ""),
    :MMXEXT_       => (0x8000_0001, :EDX , 22 , "MMX-SSE (AMD specific)"),
    :MMX_          => (0x8000_0001, :EDX , 23 , "64bit Streaming SIMD extensions (MMX)"),
    :FXSR_         => (0x8000_0001, :EDX , 24 , "AMD and Cyrix specific"),
    :FFXSR         => (0x8000_0001, :EDX , 25 , "FFXSR"),
    :PG1G          => (0x8000_0001, :EDX , 26 , "PG1G"),
    :RDTSCP        => (0x8000_0001, :EDX , 27 , "RDTSCP instruction"),
     #:reserved    => (0x8000_0001, :EDX , 28 , ""),
    :LM_           => (0x8000_0001, :EDX , 29 , "AMD64 long mode"),
    Symbol("3DNowEXT")=>(0x8000_0001,:EDX, 30 , "AMD 3DNow! (extended)"),
    Symbol("3DNow")=> (0x8000_0001, :EDX , 31 , "AMD 3DNow!"),
    :TS            => (0x8000_0007, :EDX , 0  , "Temperature sensor"),
    :FID           => (0x8000_0007, :EDX , 1  , "Frequency ID control"),
    :VID           => (0x8000_0007, :EDX , 2  , "Voltage ID control"),
    :TTP           => (0x8000_0007, :EDX , 3  , "Thermal trip"),
    :TM            => (0x8000_0007, :EDX , 4  , "Thermal monitoring"),
    :STC           => (0x8000_0007, :EDX , 5  , "Software thermal control"),
    :MUL100        => (0x8000_0007, :EDX , 6  , "100 MHz multiplier steps"),
    :HWPS          => (0x8000_0007, :EDX , 7  , "Hardware P-state support"),
    :TSCINV        => (0x8000_0007, :EDX , 8  , "Invariant TSC"),
    :CPB           => (0x8000_0007, :EDX , 9  , "Core performance boost"),
    :EFRO          => (0x8000_0007, :EDX , 10 , "Read-only MPERF/APERF"),
    :PFI           => (0x8000_0007, :EDX , 11 , "Processor feedback interface"),
    :PA            => (0x8000_0007, :EDX , 12 , "Processor accumulator"),
    :FP128         => (0x8000_001a, :EAX , 0  , "1x128 bit instead of 2x 64-bit processing"),
    :MOVU          => (0x8000_001a, :EAX , 1  , "prefer unaligned MOV over MOVL/MOVH"),
    :FP256         => (0x8000_001a, :EAX , 2  , "1x256 bit instead of 2x128-bit processing"),
)


"""
    _FeatureTest( cpuidleaf::Integer, register::Symbol, featureBit::Integer )

Internal helper function.

Query the 'cpuid' assembly instruction for cpu features on leaf 1,
Eax=0x01, and retrieve a boolean of whether bit number 'featuerBit'
is set in the result 'register' as one of ':ECX' or ':EDX'.

Example: Check for SSE capabilities, input: EAX=1, Output in EDX, Bit 25
```julia
_FeatureTest(:Edx, 25) == true
```
"""
@inline function __detectfeature(leaf::UInt32, r::Symbol, f::UInt32, desc) ::Bool
    eax, ebx, ecx, edx = CpuId.cpuid(leaf)
    (( r == :EAX ? eax :
       r == :EBX ? ebx :
       r == :ECX ? ecx :
       r == :EDX ? edx : zero(UInt32) )
     >> f ) & one(UInt32) != zero(UInt32)
end


"""
    cpufeature( feature::Symbol ) ::Bool

Query the cpu whether it supports the given feature.
Valid symbols are listed in `CpuId.__cpufeaturemap`.
"""
function cpufeature(feat::Symbol) ::Bool
    global __cpufeaturemap
    @noinline _throw_error() =
            error("'$feat' is not known to be a valid `cpuid` feature flag. Have you mistyped?")
    !(feat in keys(__cpufeaturemap)) && _throw_error()
    x = get(__cpufeaturemap, feat, nothing)
    __detectfeature(x...)
end


"""
    cpufeaturedesc( feature::Symbol ) ::String

Get the textual description of a feature flag symbol.
Throws if the feature flag is unknown.
"""
function cpufeaturedesc(feat::Symbol) ::String
    global __cpufeaturemap
    @noinline _throw_error() =
            error("'$feat' is not known to be a valid `cpuid` feature flag. Have you mistyped?")
    !(feat in keys(__cpufeaturemap)) && _throw_error()
    get(__cpufeaturemap, feat, "")[4]
end


"""
    cpufeatures() ::Vector{Symbol}

Get a list of symbols of all cpu supported features.  Might be extensive and
not exactly useful other than for testing purposes.  Also, this implementation
is not efficient since each feature is queried independently.
"""
cpufeatures() = Symbol[f for f in keys(__cpufeaturemap) if cpufeature(f)] |> sort


"""
    cpufeaturetable() ::Base.Markdown.MD

Generate a markdown table of all the detected/available/supported CPU features
along with some textural description.
"""
function cpufeaturetable() ::Base.Markdown.MD
    tbl = Base.Markdown.Table([["Cpu Feature", "Description"]], [:l, :l])
    for f in cpufeatures()
        push!(tbl.rows, [string(f), cpufeaturedesc(f)])
    end
    Base.Markdown.MD(tbl)
end


#=--- end of file ---------------------------------------------------------=#

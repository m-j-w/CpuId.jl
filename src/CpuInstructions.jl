#=--- CpuId / CpuInstructions.jl ------------------------------------------=#

"""
# Module 'CpuInstructions'

The module 'CpuInstructions' is part of the package 'CpuId', and provides a
selection of wrapped low-level assembly functions to diagnose potential
computational efficiency issues.

Though primarily intended as a helper module to 'CpuId', the functions may be
used directly in other code e.g. for benchmarking purposes.  Just include the
file directly, or copy & paste.
"""
module CpuInstructions

export cpuid, rdtsc, rdtscp

using Base: llvmcall

"""
    cpuid( [leaf], [subleaf]) ::NTuple{4, UInt32}

Invoke the cpu's hardware instruction `cpuid` with the values of the arguments
stored as registers *EAX = leaf*, *ECX = subleaf*, respectively. Returns a
tuple of the response of registers EAX, EBX, ECX, EDX.  Input values may be
given as individual `UInt32` arguments, or converted from any `Integer`.
Unspecified arguments are assumed zero.

This function is primarily intended as a low-level interface to the CPU.

Note: Expected to work on all CPUs that implement the assembly instruction
      `cpuid`, which is at least Intel and AMD.
"""
function cpuid end

# Convenience function allowing passing other than UInt32 values
@inline cpuid( leaf   ::Integer=zero(UInt32)
             , subleaf::Integer=zero(UInt32)) = cpuid(UInt32(leaf), UInt32(subleaf))

# Low level cpuid call, taking eax=leaf and ecx=subleaf,
# returning eax, ebx, ecx, edx as NTuple(4,UInt32)
@inline cpuid(leaf::UInt32, subleaf::UInt32) =
    llvmcall("""
        ; leaf = %0, subleaf = %1, %2 is some label
        ; call 'cpuid' with arguments loaded into registers EAX = leaf, ECX = subleaf
        %3 = tail call { i32, i32, i32, i32 } asm sideeffect "cpuid",
             "={ax},={bx},={cx},={dx},{ax},{cx},~{dirflag},~{fpsr},~{flags}"
             (i32 %0, i32 %1) #2
        ; retrieve the result values and convert to vector [4 x i32]
        %4 = extractvalue { i32, i32, i32, i32 } %3, 0
        %5 = extractvalue { i32, i32, i32, i32 } %3, 1
        %6 = extractvalue { i32, i32, i32, i32 } %3, 2
        %7 = extractvalue { i32, i32, i32, i32 } %3, 3
        ; return the values as a new tuple
        %8  = insertvalue [4 x i32] undef, i32 %4, 0
        %9  = insertvalue [4 x i32]   %8 , i32 %5, 1
        %10 = insertvalue [4 x i32]   %9 , i32 %6, 2
        %11 = insertvalue [4 x i32]  %10 , i32 %7, 3
        ret [4 x i32] %11"""
    # llvmcall requires actual types, rather than the usual (...) tuple
    , NTuple{4,UInt32}, Tuple{UInt32,UInt32}
    , leaf, subleaf)

@inline rdtsc() =
    llvmcall("""
        %1 = tail call { i32, i32 } asm sideeffect "rdtsc", "={ax},={dx},~{dirflag},~{fpsr},~{flags}"() #2
        %2 = extractvalue { i32, i32 } %1, 0
        %3 = extractvalue { i32, i32 } %1, 1
        %4 = zext i32 %2 to i64
        %5 = zext i32 %3 to i64
        %6 = shl nuw i64 %5, 32
        %7 = or i64 %6, %4
        ret i64 %7
    """
    , UInt64, Tuple{})


@inline rdtscp() =
    llvmcall("""
        %1 = tail call { i64, i64, i64 } asm sideeffect "rdtscp", "={ax},={dx},={cx},~{dirflag},~{fpsr},~{flags}"() #2
        %2 = extractvalue { i64, i64, i64 } %1, 0
        %3 = extractvalue { i64, i64, i64 } %1, 1
        %4 = extractvalue { i64, i64, i64 } %1, 2
        %5 = shl i64 %3, 32
        %6 = or i64 %5, %2
        %7 = insertvalue [2 x i64] undef, i64  %6, 0
        %8 = insertvalue [2 x i64]  %7  , i64  %4, 1
        ret [ 2 x i64 ] %8
    """
    , Tuple{UInt64,UInt64}, Tuple{})


end # module CpuInstructions

#=--- end of file ---------------------------------------------------------=#

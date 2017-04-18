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
@inline cpuid(exx::Tuple{UInt32,UInt32,UInt32,UInt32}) =
    llvmcall("""
        ; load the values from the tuple
        %2 = extractvalue [4 x i32] %0, 0
        %3 = extractvalue [4 x i32] %0, 1
        %4 = extractvalue [4 x i32] %0, 2
        %5 = extractvalue [4 x i32] %0, 3
        ; call 'cpuid' with those pointers being loaded into registers EAX, EBX, ECX, EDX
        %6 = tail call { i32, i32, i32, i32 } asm sideeffect "cpuid", "={ax},={bx},={cx},={dx},0,1,2,3,~{dirflag},~{fpsr},~{flags}"(i32 %2, i32 %3, i32 %4, i32 %5) #7
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

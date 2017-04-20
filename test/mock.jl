#=--- CpuId / test / mock.jl ----------------------------------------------=#

#
# This file contains a number of cpuid dumps from known CPUs.
# These dumps are used to test the analysis function of CpuId.jl.
#

using CpuId

import CpuId: cpuid


"""
Entry for mocking `cpuid`, maps input and output of the `cpuid` instruction
on a known CPU; viz. `(eax, ecx) -> (eax, ebx, ecx, edx)`.
"""
const _mockdb_entry = Dict{ NTuple{2,UInt32}, NTuple{4,UInt32} }


"""
List of cpuid dumps.
Each entry is represented by a dictionary which maps input and output of the
`cpuid` instruction on a known CPU; viz. `(eax, ecx) -> (eax, ebx, ecx, edx)`.
"""
const _mockdb = _mockdb_entry[]


"""
Temporarily overwrite the low-level cpuid function, to return pre-recorded results.
"""
function mock_cpuid(idx::Integer)
    global _mockdb
    _fake_cpuid(eax=0, ebx=0, ecx=0, edx=0)::NTuple{4,UInt32} =
        get( _mockdb[idx], (UInt32(eax), UInt32(ecx))
           , (zero(UInt32), zero(UInt32), zero(UInt32), zero(UInt32),) )

    CpuId.cpuid(exx::NTuple{4,UInt32}) = _fake_cpuid(exx...)
end


"""
Dump a table of cpuid answers for mocking.  Ouput in a copy & paste ready format.
"""
function dump_cpuid_table()

    println("Dump of all cpuid leafs, used for mocking 'cpuid'...\n")

    println("# ", strip(CpuId.cpubrand()), " with",
            CpuId.hypervised() ? " "*string(CpuId.hvvendor()) : "out", " hypervisor" )
    println("push( _mockdb, Dict(")

    for minleaf in [0x0000_0000,0x4000_0000,0x8000_0000]
        # get the maximum leaf
        maxleaf = first(CpuId.cpuid(minleaf))
        maxleaf < minleaf && continue
        for leaf in minleaf:maxleaf
            println("    (",(leaf, 0x0000_0000), " => ", CpuId.cpuid(leaf), "),")
        end
    end

    # Now add the ones with sub-leaves
    # TODO: This is should be a little bit more precise.

    leaf = 0x0000_0004
    if CpuId.hasleaf(leaf)
        for subleaf in 0x0000_0001:0x0000_000f
            eax, ebx, ecx, edx = CpuId.cpuid(leaf, 0x00, subleaf)
            println("    (",(leaf, subleaf), " => ", (eax, ebx, ecx, edx), "),")
            eax & 0x1f == 0 && break
        end
    end

    leaf = 0x0000_000b
    if CpuId.hasleaf(leaf)
        for subleaf in 0x0000_0001:0x0000_000f
            eax, ebx, ecx, edx = CpuId.cpuid(leaf, 0x00, subleaf)
            println("    (",(leaf, subleaf), " => ", (eax, ebx, ecx, edx), "),")
            ebx & 0xffff == 0x0000 && break
        end
    end

    println("  ))\n\nDone.\n")

end

#=--- end of file ---------------------------------------------------------=#

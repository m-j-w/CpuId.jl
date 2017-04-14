using Base.Test

@testset "ReturnTypes" begin

    using CpuId

    # Moved upwards temporarily for better diagnostics
    println(cpuinfo())
    println(cpufeaturetable())
    println(hvversiontable())


    println('\n', "Hypervisor extended version tags:\n", hvversion(), '\n')

    println("Maximum available leafs:")
    println("0x00000000 : ", CpuId.cpuid(0x0000_0000))
    println("0x40000000 : ", CpuId.cpuid(0x4000_0000))
    println("0x80000000 : ", CpuId.cpuid(0x8000_0000))
    println()

    println("Query hypervisor information:")
    for r in 0x4000_0000:0x4000_0006
        println("0x", hex(r), " : ", CpuId.cpuid(r))
    end
    println()

    println("Legacy cache 0x02 information:")
    println("0x00000002 : ", CpuId.cpuid(0x02))
    println()

    println("Raw CPU topology information:")
    for r in 0:6
        println("0x0000000b, subleaf ", r, " : ", CpuId.cpuid(0x0b, 0x00, r))
    end
    println()

    # Can't do real testing on results when target machine is unknown.
    # Thus, let's simply check whether the result types are correct,
    # which also fails if a test throws.

    @test isa( CpuId.cpuid(), NTuple{4, UInt32} )
    @test isa( CpuId.cpuid(0x00), NTuple{4, UInt32} )
    @test isa( CpuId.cpuid(0x00, 0x00), NTuple{4, UInt32} )
    @test isa( CpuId.cpuid(0x00, 0x00, 0x00), NTuple{4, UInt32} )
    @test isa( CpuId.cpuid(0x00, 0x00, 0x00, 0x00), NTuple{4, UInt32} )
    @test isa( CpuId.cpuid(eax=0x00), NTuple{4, UInt32} )
    @test isa( CpuId.cpuid(eax=0x00, ebx=0x00), NTuple{4, UInt32} )
    @test isa( CpuId.cpuid(eax=0x00, ecx=0x00, edx=0x00), NTuple{4, UInt32} )
    @test isa( CpuId.cpuid(eax=0x00, ebx=0x00, ecx=0x00, edx=0x00), NTuple{4, UInt32} )

    # LLVM eliminates calls to hasleaf(...) if the executing machine supports
    # that leaf.  Thus test whether the reverse actually throws...
    function test_nonexisting_leaf()
        leaf = 0x8000_008f
        CpuId.hasleaf(leaf) || CpuId._throw_unsupported_leaf(leaf)
        CpuId.cpuid(leaf)
    end
    @test_throws ErrorException test_nonexisting_leaf()

    @test isa( CpuId.cpucycle()       , UInt64 )
    @test isa( CpuId.cpucycle_id()    , Tuple{UInt64, UInt64} )

    @test isa( address_size()         , Integer )
    @test isa( physical_address_size(), Integer )
    @test isa( cachelinesize()        , Integer )
    @test isa( cachesize()            , Tuple )
    for i in 0:5
        @test isa( cachesize(i)       , Integer )
    end
    @test isa( cpuarchitecture()      , Symbol )
    @test isa( cpubrand()             , String )
    @test isa( cpumodel()             , Dict )
    @test isa( cpuvendor()            , Symbol )
    @test isa( CpuId.cpuvendorstring(), String )
    @test isa( hypervised()           , Bool )
    @test isa( hvvendor()             , Symbol )
    @test isa( CpuId.hvvendorstring() , String )
    @test isa( hvversion()            , Dict{Symbol,Any} )
    @test isa( hypervised()           , Bool )
    @test isa( simdbits()             , Integer )
    @test isa( simdbytes()            , Integer )
    if CpuId.hasleaf(0x0000_000b)
        @test isa( cpucores()         , Integer )
        @test isa( cpucores_total()   , Integer )
    else
        @test_throws ErrorException cpucores()
        @test_throws ErrorException cpucores_total()
    end
    @test isa( has_cpu_frequencies()  , Bool )
    @test isa( cpu_base_frequency()   , Integer )
    @test isa( cpu_bus_frequency()    , Integer )
    @test isa( cpu_max_frequency()    , Integer )
    @test isa( cpuinfo()              , Base.Markdown.MD )
    @test isa( cpufeaturetable()      , Base.Markdown.MD )
    @test isa( hvversiontable()       , Base.Markdown.MD )

    @test isa( cpucycle()             , UInt64 )
    @test isa( cpucycle_id()          , Tuple{UInt64,UInt64} )

    # Check if trailing null characters are correctly identified
    # as hypervisor vendor KVM
    @test get( CpuId._cpuid_vendor_id, "KVMKVMKVM\0\0\0", :Unknown) === :KVM

    # Accessing `rdtsc` and `rdtscp` gives a low-level exception, crashing
    # Julia, and thus cannot be tested if not available.
    #if (CpuId.cpufeature(:TSC) == false)
    #    @test_throws Exception CpuId.CpuInstructions.rdtsc()
    #end
    #if (CpuId.cpufeature(:RDTSCP) == false)
    #    @test_throws Exception CpuId.CpuInstructions.rdtscp()
    #end

end

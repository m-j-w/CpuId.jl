using Base.Test

@testset "ReturnTypes" begin

    using CpuId

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

    @test isa( address_size()         , Integer )
    @test isa( cachelinesize()        , Integer )
    @test isa( cachesize()            , Tuple )
    @test isa( cpubrand()             , String )
    @test isa( cpumodel()             , Dict )
    @test isa( cpuvendor()            , Symbol )
    @test isa( hypervised()           , Bool )
    @test isa( physical_address_size(), Integer )
    @test isa( simdbits()             , Integer )
    @test isa( simdbytes()            , Integer )
    @test isa( has_cpu_frequencies()  , Bool )
    @test isa( cpu_base_frequency()   , Integer )
    @test isa( cpu_bus_frequency()    , Integer )
    @test isa( cpu_max_frequency()    , Integer )
    @test isa( cpuinfo()              , Base.Markdown.MD )

    println(cpuinfo())

end

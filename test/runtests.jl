using Base.Test

@testset "ReturnTypes" begin

    using CpuId

    # Can't do real testing on results when target machine is unknown.
    # Thus, let's simply check whether the result types are correct,
    # which also fails if a test throws.

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
    @test isa( cpuinfo()              , Base.Markdown.MD )

    eax, ebx, ecx, edx = CpuId.cpuid(0x00)
    if eax >= 0x16
        @test isa( cpu_base_frequency(), Integer )
        @test isa( cpu_bus_frequency() , Integer )
        @test isa( cpu_max_frequency() , Integer )
    else
        @test_throws ErrorException cpu_base_frequency()
        @test_throws ErrorException cpu_bus_frequency()
        @test_throws ErrorException cpu_max_frequency()
    end

    println(cpuinfo())

end

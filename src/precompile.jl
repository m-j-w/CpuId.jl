using PrecompileTools: @compile_workload

@compile_workload begin
    cacheinclusive()
    cachelinesize()
    cachesize()
    cpucores()
end

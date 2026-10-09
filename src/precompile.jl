using PrecompileTools: @compile_workload

# The workload executes `cpuid`, which exists only on x86; elsewhere, all leaves
# appear to be missing (see CpuInstructions.jl). Even on x86, virtualized or
# emulated CPUs (e.g., some CI hypervisors or Rosetta 2) may not expose every
# leaf. The queried functions throw in these cases, which would make the
# precompilation of CpuId fail. Thus, ignore these errors, since the aim is only
# to compile the methods.
@static if Sys.ARCH in (:x86, :x86_64, :i686)
    @compile_workload begin
        for f in (cacheinclusive, cachelinesize, cachesize, cpucores)
            try
                f()
            catch
            end
        end
    end
end

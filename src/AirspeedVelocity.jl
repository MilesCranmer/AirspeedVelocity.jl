module AirspeedVelocity

using Pkg: PackageSpec
using Pkg: Pkg

function _get_benchmark_script(package_name)
    # Create temp env, add package, and get path to benchmark script.
    @info "Downloading package's latest benchmark script, assuming it is in benchmark/benchmarks.jl"
    tmp_env = mktempdir()
    to_exec = quote
        using Pkg
        Pkg.add(PackageSpec(; name=$package_name); io=devnull)
        using $(Symbol(package_name)): $(Symbol(package_name))
        root_dir = dirname(dirname(pathof($(Symbol(package_name)))))
        open(joinpath($tmp_env, "package_path.txt"), "w") do io
            write(io, root_dir)
        end
    end
    path_getter = joinpath(tmp_env, "path_getter.jl")
    open(path_getter, "w") do io
        println(io, to_exec)
    end
    run(`julia --project="$tmp_env" "$path_getter"`)

    benchmark_script = joinpath(
        readchomp(joinpath(tmp_env, "package_path.txt")), "benchmark", "benchmarks.jl"
    )
    if !isfile(benchmark_script)
        @error "Could not find benchmark script at $benchmark_script. Please specify the `benchmark_script` manually."
    end
    @info "Found benchmark script at $benchmark_script."

    return benchmark_script
end

function _benchmark(
    spec::PackageSpec;
    output_dir::String=".",
    benchmark_script::String=nothing,
    tune::Bool=false,
    exeflags::Cmd=``,
)
    package_name = spec.name
    package_rev = spec.rev
    spec_str = string(package_name) * "@" * string(package_rev)
    tmp_env = mktempdir()
    Pkg.activate(tmp_env; io=devnull)
    Pkg.add(
        [spec, PackageSpec(; name="BenchmarkTools"), PackageSpec(; name="JSON3")];
        io=devnull,
    )
    to_exec = quote
        using BenchmarkTools: run, BenchmarkGroup
        using JSON3: write

        # Include benchmark, defining SUITE:
        include($benchmark_script)
        # Assert that SUITE is defined:
        if !isdefined(Main, :SUITE)
            @error "Benchmark script $bench_path did not define SUITE."
        end
        if !(typeof(SUITE) <: BenchmarkGroup)
            @error "Benchmark script $bench_path did not define SUITE as a BenchmarkGroup."
        end
        if $tune
            @info "Tuning benchmarks for " * $spec_str * "."
            tune!(SUITE)
        end
        @info "Running benchmarks for " * $spec_str * "."
        results = run(SUITE; verbose=true)
        @info "Finished benchmarks for " * $spec_str * "."
        open(joinpath($output_dir, "results_" * $spec_str * ".json"), "w") do io
            write(io, write(results))
        end
    end
    runner_filename = joinpath(tmp_env, "runner.jl")
    open(runner_filename, "w") do io
        println(io, string(to_exec))
    end
    run(`julia --project="$tmp_env" $exeflags "$runner_filename"`)
    return nothing
end

function benchmark(
    package_spec::PackageSpec;
    output_dir::String=".",
    benchmark_script::Union{String,Nothing}=nothing,
    tune::Bool=false,
    exeflags::Cmd=``,
)
    if benchmark_script === nothing
        benchmark_script = _get_benchmark_script(package_name)
    end
    return _benchmark(package_spec; output_dir, benchmark_script, tune, exeflags)
end
function benchmark(
    package_specs::Vector{PackageSpec};
    output_dir::String=".",
    benchmark_script::Union{String,Nothing}=nothing,
    tune::Bool=false,
    exeflags::Cmd=``,
)
    if benchmark_script === nothing
        benchmark_script = _get_benchmark_script(package_name)
    end
    for spec in package_specs
        benchmark(spec; output_dir, benchmark_script, tune, exeflags)
    end
end

function benchmark(
    package_name::String,
    revs::Vector{String};
    output_dir::String=".",
    benchmark_script::Union{String,Nothing}=nothing,
    tune::Bool=false,
    exeflags::Cmd=``,
)
    return _benchmark(
        [PackageSpec(; name=package_name, rev=rev) for rev in revs];
        output_dir=output_dir,
        benchmark_script=benchmark_script,
        tune=tune,
        exeflags=exeflags,
    )
end
function benchmark(
    package_name::String,
    rev::String;
    output_dir::String=".",
    benchmark_script::Union{String,Nothing}=nothing,
    tune::Bool=false,
    exeflags::Cmd=``,
)
    return benchmark(
        package_name,
        [rev];
        output_dir=output_dir,
        benchmark_script=benchmark_script,
        tune=tune,
        exeflags=exeflags,
    )
end

end

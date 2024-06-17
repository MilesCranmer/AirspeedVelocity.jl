module BenchPkg

using ..TableUtils: create_table, format_memory
using ..Utils: benchmark, get_package_name_defaults, parse_rev, load_results
using Comonicon
using Comonicon: @main

"""
    benchpkg [package_name] [-r --rev <arg>]
                            [--url <arg>]
                            [--path <arg>]
                            [-o, --output-dir <arg>]
                            [-e, --exeflags <arg>]
                            [-a, --add <arg>]
                            [-s, --script <arg>]
                            [--bench-on <arg>]
                            [-f, --filter <arg>]
                            [--nsamples-load-time <arg>]
                            [--tune]

Benchmark a package over a set of revisions.

# Arguments

- `package_name`: Name of the package. If not given, the package is assumed to be
  the current directory.

# Options

- `-r, --rev <arg>`: Revisions to test (delimit by comma). Use `dirty` to
  benchmark the current state of the package at `path` (and not a git commit).
  The default is `dirty,{DEFAULT}`.
- `--url <arg>`: URL of the package.
- `--path <arg>`: Path of the package. The default is `.` if other arguments are not given.
- `-o, --output-dir <arg>`: Where to save the JSON results. The default is `.`.
- `-e, --exeflags <arg>`: CLI flags for Julia (default: none).
- `-a, --add <arg>`: Extra packages needed (delimit by comma).
- `-s, --script <arg>`: The benchmark script. Default: `benchmark/benchmarks.jl` downloaded from `stable`.
- `--bench-on <arg>`: If the script is not set, this specifies the revision at which
  to download `benchmark/benchmarks.jl` from the package.
- `-f, --filter <arg>`: Filter the benchmarks to run (delimit by comma).
- `--nsamples-load-time <arg>`: Number of samples to take when measuring load time of
    the package (default: 5). (This means starting a Julia process for each sample.)
- `--dont-print`: Don't print the table.

# Flags

- `--tune`: Whether to run benchmarks with tuning (default: false).

"""
@main function benchpkg(
    package_name::String="";
    rev::String="dirty,{DEFAULT}",
    output_dir::String=".",
    script::String="",
    exeflags::String="",
    add::String="",
    tune::Bool=false,
    url::String="",
    path::String="",
    bench_on::String="",
    filter::String="",
    nsamples_load_time::Int=5,
    dont_print::Bool=false,
)
    revs = convert(Vector{String}, split(rev, ","))
    Base.filter!(!isempty, revs)

    filtered = convert(Vector{String}, split(filter, ","))
    Base.filter!(x -> length(x) > 0, filtered)

    @assert length(revs) > 0 "No revisions specified."
    @assert nsamples_load_time > 0 "nsamples_load_time must be positive."

    package_name, url, path = get_package_name_defaults(package_name, url, path)

    if path != ""
        revs = map(Base.Fix2(parse_rev, path), revs)
    else
        if any(==("{DEFAULT}"), revs)
            error("You must explicitly set `--revs` for this set of options.")
        end
    end

    _script = if bench_on == "dirty" && path != "" && script == ""
        bench_on = nothing
        joinpath(path, "benchmark", "benchmarks.jl")
    else
        script
    end

    benchmark(
        package_name,
        revs;
        output_dir=output_dir,
        script=(length(_script) > 0 ? _script : nothing),
        tune=tune,
        exeflags=(length(exeflags) > 0 ? `$(Cmd(split(exeflags, " ") .|> String))` : ``),
        extra_pkgs=convert(Vector{String}, split(add, ",")),
        url=(length(url) > 0 ? url : nothing),
        path=(length(path) > 0 ? path : nothing),
        benchmark_on=(length(bench_on) > 0 ? bench_on : nothing),
        filter_benchmarks=filtered,
        nsamples_load_time=nsamples_load_time,
    )

    if !dont_print
        combined_results = load_results(package_name, revs; input_dir=output_dir)
        println(
            create_table(combined_results; add_ratio_col=length(revs) == 2, key="median")
        )
    end

    return nothing
end

end # module AirspeedVelocity.BenchPkg

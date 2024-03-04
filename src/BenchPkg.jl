module BenchPkg

using ..Utils: benchmark
using Comonicon

"""
    benchpkg package_name [-r --rev <arg>] [-o, --output-dir <arg>]
                          [-s, --script <arg>] [-e, --exeflags <arg>]
                          [-a, --add <arg>] [--tune]
                          [--url <arg>] [--path <arg>]
                          [--bench-on <arg>] [--nsamples-load-time <arg>]
                          [--use-manifest]

Benchmark a package over a set of revisions.

# Arguments

- `package_name`: Name of the package.

# Options

- `-r, --rev <arg>`: Revisions to test (delimit by comma).
- `-o, --output-dir <arg>`: Where to save the JSON results.
- `-s, --script <arg>`: The benchmark script. Default: `benchmark/benchmarks.jl` downloaded from `stable`.
- `-e, --exeflags <arg>`: CLI flags for Julia (default: none).
- `-a, --add <arg>`: Extra packages needed (delimit by comma).
- `--url <arg>`: URL of the package.
- `--path <arg>`: Path of the package.
- `--bench-on <arg>`: If the script is not set, this specifies the revision at which
  to download `benchmark/benchmarks.jl` from the package.
- `--nsamples-load-time <arg>`: Number of samples to take when measuring load time of
    the package (default: 5). (This means starting a Julia process for each sample.)

# Flags

- `--tune`: Whether to run benchmarks with tuning (default: false).
- `--use-manifest`: Whether to use Manifest.toml when benchmarking (default: false)

"""
@main function benchpkg(
    package_name::String;
    rev::String,
    output_dir::String=".",
    script::String="",
    exeflags::String="",
    add::String="",
    tune::Bool=false,
    url::String="",
    path::String="",
    bench_on::String="",
    nsamples_load_time::Int=5,
    use_manifest::Bool=false
)
    revs = convert(Vector{String}, split(rev, ","))
    # Filter empty strings:
    revs = filter(x -> length(x) > 0, revs)
    @assert length(revs) > 0 "No revisions specified."
    @assert nsamples_load_time > 0 "nsamples_load_time must be positive."
    benchmark(
        package_name,
        revs;
        output_dir=output_dir,
        script=(length(script) > 0 ? script : nothing),
        tune=tune,
        exeflags=(length(exeflags) > 0 ? `$(Cmd(split(exeflags, " ") .|> String))` : ``),
        extra_pkgs=convert(Vector{String}, split(add, ",")),
        url=(length(url) > 0 ? url : nothing),
        path=(length(path) > 0 ? path : nothing),
        benchmark_on=(length(bench_on) > 0 ? bench_on : nothing),
        nsamples_load_time=nsamples_load_time,
        use_manifest
    )

    return nothing
end

end # module AirspeedVelocity.BenchPkg

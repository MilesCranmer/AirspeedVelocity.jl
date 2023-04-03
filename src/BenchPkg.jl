module BenchPkg

using ..Utils: benchmark
using Comonicon

"""
    benchpkg package_name [-r --rev <arg>] [-o, --output-dir <arg>]
                          [-s, --script <arg>] [-e, --exeflags <arg>]
                          [-a, --add <arg>] [-t, --tune]
                          [-u, --url <arg>]

Benchmark a package over a set of revisions.

# Arguments

- `package_name`: Name of the package.

# Options

- `-r, --rev <arg>`: Revisions to test (delimit by comma).
- `-o, --output-dir <arg>`: Where to save the JSON results.
- `-s, --script <arg>`: The benchmark script. Default: `benchmark/benchmarks.jl` downloaded from `stable`.
- `-e, --exeflags <arg>`: CLI flags for Julia (default: none).
- `-a, --add <arg>`: Extra packages needed (delimit by comma).
- `-u, --url <arg>`: URL of the package.
- `--bench-on <arg>`: If the script is not set, this specifies the revision of `benchmarks.jl`.

# Flags

- `-t, --tune`: Whether to run benchmarks with tuning (default: false).

"""
@main function benchpkg(
    package_name::String;
    rev::String,
    output_dir::String = ".",
    script::String = "",
    exeflags::String = "",
    add::String = "",
    tune::Bool = false,
    url::String="",
    bench_on::String="",
)
    revs = convert(Vector{String}, split(rev, ","))
    # Filter empty strings:
    revs = filter(x -> length(x) > 0, revs)
    @assert length(revs) > 0 "No revisions specified."
    benchmark(
        package_name,
        revs;
        output_dir = output_dir,
        script = (length(script) > 0 ? script : nothing),
        tune = tune,
        exeflags = (length(exeflags) > 0 ? `$exeflags` : ``),
        extra_pkgs = convert(Vector{String}, split(add, ",")),
        url = (length(url) > 0 ? url : nothing),
        benchmark_on = (length(bench_on) > 0 ? bench_on : nothing),
    )

    return nothing
end

end # module AirspeedVelocity.BenchPkg
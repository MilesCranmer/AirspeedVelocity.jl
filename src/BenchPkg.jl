module BenchPkg

using ..Utils: benchmark
using Comonicon

"""
    benchpkg package_name [-r --rev <arg>] [-o, --output_dir <arg>] [-s, --script <arg>] [-e, --exeflags <arg>] [-a, --add <arg>] [-t, --tune]

Benchmark a package over a set of revisions.

# Arguments

- `package_name`: Name of the package.

# Options

- `-r, --rev <arg>`: Revisions to test (delimit by comma).
- `-o, --output_dir <arg>`: Where to save the JSON results.
- `-s, --script <arg>`: The benchmark script. Default: `{PACKAGE_SRC_DIR}/benchmark/benchmarks.jl`.
- `-e, --exeflags <arg>`: CLI flags for Julia (default: none).
- `-a, --add <arg>`: Extra packages needed (delimit by comma).

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
    )

    return nothing
end

end # module AirspeedVelocity.BenchPkg

module BenchPkgTable

using ..TableUtils: create_table, format_memory
using ..Utils: load_results
using Comonicon
using Comonicon: @main

"""
    benchpkgtable package_name [-r --rev <arg>] [-i --input-dir <arg>]
                               [--ratio] [--mode <arg>]

Print a table of the benchmarks of a package as created with `benchpkg`.

# Arguments

- `package_name`: Name of the package.

# Options

- `-r, --rev <arg>`: Revisions to test (delimit by comma).
- `-i, --input-dir <arg>`: Where the JSON results were saved (default: ".").

# Flags

- `--ratio`: Whether to include the ratio (default: false). Only applies when
    comparing two revisions.
- `--mode`: Table mode(s). Valid values are "time" (default), to print the
    benchmark time, or "memory", to print the allocation and memory usage.
    Both options can be passed, if delimited by comma.
"""
@main function benchpkgtable(
    package_name::String;
    rev::String,
    input_dir::String=".",
    ratio::Bool=false,
    mode::String="time",
)
    revs = convert(Vector{String}, split(rev, ","))
    # Filter empty strings:
    revs = filter(x -> length(x) > 0, revs)
    @assert length(revs) > 0 "No revisions specified."
    combined_results = load_results(package_name, revs; input_dir=input_dir)

    modes = split(mode, ",")
    for m in modes
        println(create_table(combined_results; add_ratio_col=ratio, key=translate_mode(m)))
    end

    return nothing
end

translate_mode(s) = s == "time" ? "median" : s

end # AirspeedVelocity.BenchPkgTable

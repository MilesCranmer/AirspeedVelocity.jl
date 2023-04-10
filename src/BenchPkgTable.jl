module BenchPkgTable

using ..TableUtils: create_table
using ..Utils: load_results
using Comonicon

"""
    benchpkgtable package_name [-r --rev <arg>] [-i --input-dir <arg>]
                               [--ratio]

Print a table of the benchmarks of a package as created with `benchpkg`.

# Arguments

- `package_name`: Name of the package.

# Options

- `-r, --rev <arg>`: Revisions to test (delimit by comma).
- `-i, --input-dir <arg>`: Where the JSON results were saved (default: ".").

# Flags

- `--ratio`: Whether to include the ratio (default: false). Only applies when
    comparing two revisions.
"""
@main function benchpkgtable(
    package_name::String; rev::String, input_dir::String=".", ratio::Bool=false
)
    revs = convert(Vector{String}, split(rev, ","))
    # Filter empty strings:
    revs = filter(x -> length(x) > 0, revs)
    @assert length(revs) > 0 "No revisions specified."
    combined_results = load_results(package_name, revs; input_dir=input_dir)

    return println(create_table(combined_results; add_ratio_col=ratio))
end

end # AirspeedVelocity.BenchPkgTable

module BenchPkgTable

using ..TableUtils: create_table, format_memory
using ..Utils: get_package_name_defaults, parse_rev, load_results
using Comonicon

"""
    benchpkgtable [package_name] [-r --rev <arg>]
                                 [-i --input-dir <arg>]
                                 [--ratio]
                                 [--mode <arg>]
                                 [--url <arg>]
                                 [--path <arg>]

Print a table of the benchmarks of a package as created with `benchpkg`.

# Arguments

- `package_name`: Name of the package.

# Options

- `-r, --rev <arg>`: Revisions to test (delimit by comma).
  The default is `{DEFAULT},dirty`, which will attempt to find the default branch
  of the package.
- `-i, --input-dir <arg>`: Where the JSON results were saved (default: ".").
- `--url <arg>`: URL of the package. Only used to get the package name.
- `--path <arg>`: Path of the package. The default is `.` if other arguments are not given.
   Only used to get the package name.

# Flags

- `--ratio`: Whether to include the ratio (default: false). Only applies when
    comparing two revisions.
- `--mode`: Table mode(s). Valid values are "time" (default), to print the
    benchmark time, or "memory", to print the allocation and memory usage.
    Both options can be passed, if delimited by comma.
"""
Comonicon.@main function benchpkgtable(
    package_name::String="";
    rev::String="dirty,{DEFAULT}",
    input_dir::String=".",
    ratio::Bool=false,
    mode::String="time",
    url::String="",
    path::String="",
)
    revs = convert(Vector{String}, split(rev, ","))
    Base.filter!(!isempty, revs)

    @assert length(revs) > 0 "No revisions specified."

    package_name, url, path = get_package_name_defaults(package_name, url, path)

    if path != ""
        revs = map(Base.Fix2(parse_rev, path), revs)
    else
        if any(==("{DEFAULT}"), revs)
            error("You must explicitly set `--revs` for this set of options.")
        end
    end

    combined_results = load_results(package_name, revs; input_dir=input_dir)

    modes = split(mode, ",")
    for m in modes
        println(create_table(combined_results; add_ratio_col=ratio, key=translate_mode(m)))
    end

    return nothing
end

translate_mode(s) = s == "time" ? "median" : s

end # AirspeedVelocity.BenchPkgTable

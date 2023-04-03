module BenchPkgPlot

import ..Utils: get_spec_str
using Statistics: mean, median, std, quantile
using JSON3
using Plots
using Plots.Measures
using Pkg: PackageSpec
using OrderedCollections: OrderedDict
using Comonicon

function compute_summary_statistics(times)
    d = Dict("mean" => mean(times), "median" => median(times))
    d = if length(times) > 1
        merge(
            d,
            Dict(
                "std" => std(times),
                "25" => quantile(times, 0.25),
                "75" => quantile(times, 0.75),
            ),
        )
    else
        d
    end
    return d
end

# Now, we want to create a plot for each key, over the different revisions,
# ordered by the order in which they were passed:
function create_line_plot(data, names, title)
    medians = [d["median"] for d in data]

    # Default unit of time is ns. Let's find one of
    # {ns, μs, ms, s} that is most appropriate
    # (i.e., log10(median / unit) should be closest to 0)
    units = [1e9, 1e6, 1e3, 1, 1.0 / (60 * 60)] ./ 1e9
    units_names = ["ns", "μs", "ms", "s", "h"]
    unit_choice = argmin(abs.(log10.(median(medians) .* units)))
    unit = units[unit_choice]
    unit_name = units_names[unit_choice]

    medians = medians .* unit
    errors = if "75" in keys(first(data))
        lower_errors = [d["median"] - d["25"] for d in data] .* unit
        upper_errors = [d["75"] - d["median"] for d in data] .* unit
        hcat(lower_errors', upper_errors')
    else
        nothing
    end
    plot_xticks = 1:length(names)

    p = plot(
        plot_xticks,
        medians;
        yerror = errors,
        linestyle = :solid,
        marker = :circle,
        legend = false,
    )
    scatter!(plot_xticks, medians; yerror = errors)
    xticks!(plot_xticks, names)
    title!(title)
    xlabel!("Revisions")
    ylabel!("Value [$unit_name]")
    return p
end

function combined_plots(combined_results::OrderedDict; npart = 10)
    # Creating and saving plots
    plots = []
    names = collect(keys(combined_results))

    @info "Creating all plots."
    for key in keys(combined_results[first(names)])
        push!(
            plots,
            create_line_plot([combined_results[name][key] for name in names], names, key),
        )
    end

    @info "Partitioning and combining plots."
    partitions = [(i, min(i + npart - 1, length(plots))) for i = 1:npart:length(plots)]
    return [
        let npart = i2 - i1 + 1
            plot(
                plots[i1:i2]...;
                layout = (npart, 1),
                size = (800, 250 * npart),
                left_margin = 20mm,
            )
        end for (i1, i2) in partitions
    ]
end

function _flatten_results!(d::OrderedDict, results::Dict{String,Any}, prefix)
    if "times" in keys(results)
        d[prefix] = compute_summary_statistics(results["times"])
    elseif "data" in keys(results)
        for (key, value) in results["data"]
            next_prefix = if length(prefix) == 0
                key
            else
                prefix * "/" * key
            end
            _flatten_results!(d, value, next_prefix)
        end
    else
        @error "Unexpected results format. Expected 'times' or 'data' key in results."
    end
    return nothing
end
function flatten_results(results::Dict{String,Any})
    d = OrderedDict{String,Any}()
    _flatten_results!(d, results, "")
    # Sort by key:
    return sort(d)
end

function load_results(specs::Vector{PackageSpec}; input_dir::String = ".")
    combined_results = OrderedDict{String,OrderedDict}()
    for spec in specs
        spec_str = get_spec_str(spec)
        results_filename = joinpath(input_dir, "results_" * spec_str * ".json")
        @info "Loading results from $results_filename"
        results = open(results_filename, "r") do io
            JSON3.read(io, Dict{String,Any})
        end
        @info "Flattening results."
        combined_results[spec.rev] = flatten_results(results)
    end

    # Assert all keys are the same in each value:
    keys_set = Set{String}()
    for (_, results) in combined_results
        keys_set = union(keys_set, keys(results))
    end
    for (name, results) in combined_results
        if keys_set != Set(keys(results))
            missing_keys = setdiff(keys_set, keys(results))
            @error "Results for $name are missing keys $missing_keys and have extra keys $extra_keys."
        end
    end

    return combined_results
end

function load_results(package_name::String, revs::Vector{String}; input_dir::String = ".")
    specs = [PackageSpec(; name = package_name, rev = rev) for rev in revs]
    return load_results(specs; input_dir = input_dir)
end

"""
    benchpkgplot package_name [-r --rev <arg>] [-i --input_dir <arg>]
                            [-o --output_dir <arg>] [-n --npart <arg>]
                            [-f --format <arg>]

Plot the benchmarks of a package as created with `benchpkg`.

# Arguments

- `package_name`: Name of the package.

# Options

- `-r, --rev <arg>`: Revisions to test (delimit by comma).
- `-i, --input_dir <arg>`: Where the JSON results were saved (default: ".").
- `-o, --output_dir <arg>`: Where to save the plots results (default: ".").
- `-n, --npart <arg>`: Max number of plots per page (default: 10).
- `-f, --format <arg>`: File type to save the plots as (default: "png").
"""
@main function benchpkgplot(
    package_name::String;
    rev::String,
    input_dir::String = ".",
    output_dir::String = ".",
    npart::Int = 10,
    format::String = "png",
)
    revs = convert(Vector{String}, split(rev, ","))
    # Filter empty strings:
    revs = filter(x -> length(x) > 0, revs)
    @assert length(revs) > 0 "No revisions specified."
    combined_results = load_results(package_name, revs; input_dir = input_dir)

    plots = combined_plots(combined_results; npart = npart)
    @info "Saving plots."
    if length(plots) == 1
        savefig(p, joinpath(output_dir, "plot_$(first(revs).name).$(format))"))
    else
        for (i, (rev, p)) in enumerate(zip(revs, plots))
            savefig(p, joinpath(output_dir, "plot_$(package_name)_$i.$(format)"))
        end
    end

    return nothing
end

end # AirspeedVelocity.BenchPkgPlot

module PlotUtils

import ..Utils: get_spec_str, get_reasonable_unit
using Statistics: median
using JSON3: JSON3
using Plots: plot, scatter!, xticks!, title!, xlabel!, ylabel!
using Plots.Measures: mm
using Pkg: PackageSpec
using OrderedCollections: OrderedDict

# Now, we want to create a plot for each key, over the different revisions,
# ordered by the order in which they were passed:
function create_line_plot(data, names, title)
    centers = [d["mean_logspace"] for d in data]

    # Default unit of time is ns. Let's find one of
    # {ns, μs, ms, s} that is most appropriate
    # (i.e., log10(median / unit) should be closest to 0)
    unit, unit_name = get_reasonable_unit(centers)

    centers = centers .* unit
    errors = if "standard_error_logspace_up" in keys(first(data))
        lower_errors = [d["standard_error_logspace_down"] for d in data] .* unit
        upper_errors = [d["standard_error_logspace_up"] for d in data] .* unit
        hcat(lower_errors', upper_errors')
    else
        nothing
    end
    plot_xticks = 1:length(names)

    p = plot(
        plot_xticks, centers; yerror=errors, linestyle=:solid, marker=:circle, legend=false, yscale=:log10
    )
    scatter!(plot_xticks, centers; yerror=errors, yscale=:log10)
    xticks!(plot_xticks, names)
    title!(title)
    xlabel!("Revision")
    ylabel!("Duration [$unit_name]")

    return p
end

"""
    combined_plots(combined_results::OrderedDict; npart=10)

Create a combined plot of the results loaded from the `load_results` function.
The function partitions the plots into smaller groups of size `npart` (defaults to 10)
and combines the plots in each group vertically. It returns an array of combined plots.

# Arguments
- `combined_results::OrderedDict`: Data to be plotted, obtained from the `load_results` function.
- `npart::Int=10`: Max plots to be combined in a single vertical group. Default is 10.

# Returns
- `Array{Plots.Plot{Plots.GRBackend},1}`: An array of combined Plots objects, with each element
  representing a group of up to `npart` vertical plots.
"""
function combined_plots(combined_results::OrderedDict; npart=10)
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
    partitions = [(i, min(i + npart - 1, length(plots))) for i in 1:npart:length(plots)]

    return [
        let npart = i2 - i1 + 1
            plot(
                plots[i1:i2]...;
                layout=(npart, 1),
                size=(800, 250 * npart),
                left_margin=20mm,
                bottom_margin=10mm,
            )
        end for (i1, i2) in partitions
    ]
end

end # AirspeedVelocity.PlotUtils

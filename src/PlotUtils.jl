module PlotUtils

import ..Utils: get_spec_str, get_reasonable_unit
using Statistics: median
using JSON3: JSON3
using PlotlyLight: Plot, Config
using Pkg: PackageSpec
using OrderedCollections: OrderedDict

# Now, we want to create a plot for each key, over the different revisions,
# ordered by the order in which they were passed:
function create_line_plot(data, names, title)
    medians = [d["median"] for d in data]

    # Default unit of time is ns. Let's find one of
    # {ns, μs, ms, s} that is most appropriate
    # (i.e., log10(median / unit) should be closest to 0)
    unit, unit_name = get_reasonable_unit(medians)

    medians = medians .* unit

    lower = minimum(medians)
    upper = maximum(medians)

    pdata = Config(;
        x=names,
        y=medians,
        type="scatter",
        mode="lines+markers",
        marker=(symbol="circle",),
        showlegend=false,
    )

    if "75" in keys(first(data))
        lower_errors = [d["median"] - d["25"] for d in data] .* unit
        upper_errors = [d["75"] - d["median"] for d in data] .* unit
        if maximum(upper_errors .+ medians) > upper
            upper = maximum(upper_errors .+ medians)
        end
        if minimum(medians .- lower_errors) < lower
            lower = minimum(medians .- lower_errors)
        end

        pdata.error_y = Config(;
            type="data", symmetric=false, array=upper_errors, arrayminus=lower_errors
        )
    end

    between = upper - lower

    p = Plot(
        pdata,
        Config(;
            xaxis=(title="Revision",),
            yaxis=(
                title="Duration [$unit_name]",
                range=[lower - 0.1 * between, upper + 0.1 * between],
            ),
            annotations=[
                Config(;
                    text=title,
                    xref="paper",
                    x=0.5,
                    xanchor="center",
                    yref="paper",
                    y=1.0,
                    yanchor="bottom",
                    showarrow=false,
                    font=(size=16,),
                ),
            ],
        ),
    )

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
- `Array{Plotly.Plot,1}`: An array of combined Plots objects, with each element
  representing a group of up to `npart` vertical plots.
"""
function combined_plots(combined_results::OrderedDict; npart=10)
    # Creating and saving plots
    plots = []
    names = collect(keys(combined_results))

    @info "Creating all plots."
    for key in keys(combined_results[first(names)])
        p = create_line_plot([combined_results[name][key] for name in names], names, key)
        push!(plots, p)
    end

    @info "Partitioning and combining plots."
    partitions = [(i, min(i + npart - 1, length(plots))) for i in 1:npart:length(plots)]

    return [
        let npart = i2 - i1 + 1
            all_data = Config[]

            layout = Config(; annotations=Config[])

            for (i, p) in enumerate(plots[i1:i2])
                data = p.data[1]

                (i == 1) && (layout["xaxis1"] = p.layout.xaxis)
                # layout["xaxis$(i)"].anchor = "y$(i)"
                layout["yaxis$(i)"] = p.layout.yaxis
                # layout["yaxis$(i)"].anchor = "x$(i)"

                data.xaxis = "x1"
                data.yaxis = "y$(i)"

                push!(all_data, data)

                top = layout["yaxis$(i)"].range[2]
                bot = layout["yaxis$(i)"].range[1]
                between = top - bot
                push!(
                    layout.annotations,
                    Config(;
                        text=p.layout.annotations[1].text,
                        xref="paper",
                        x=0.5,
                        xanchor="center",
                        yref="y$(i)",
                        y=top - 0.05 * between,
                        yanchor="bottom",
                        showarrow=false,
                        font=(size=16,),
                    ),
                )
            end

            layout.width = 800
            layout.height = 250 * npart
            layout.grid = Config(; rows=npart, columns=1) #, roworder="bottom to top")

            Plot(all_data, layout)
        end for (i1, i2) in partitions
    ]
end

end # AirspeedVelocity.PlotUtils

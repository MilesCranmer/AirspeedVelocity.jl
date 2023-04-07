module TableUtils

using ..Utils: get_reasonable_unit
using OrderedCollections: OrderedDict
using Printf: @sprintf
using PrettyTables: pretty_table, tf_markdown

function format_time(val::Dict)
    unit, unit_name = get_reasonable_unit([val["mean_logspace"]])
    if haskey(val, "standard_error_logspace")
        "\$" * @sprintf(
            "%.3g^{+%.1g}_{-%.1g}",
            val["mean_logspace"] * unit,
            val["standard_error_logspace_up"] * unit,
            val["standard_error_logspace_down"] * unit,
        ) * "\$ " * unit_name
    else
        "\$" * @sprintf("%.3g", val["mean_logspace"] * unit) * "\$ " * unit_name
    end
end
function format_time(val::Number)
    unit, unit_name = get_reasonable_unit([val])
    @sprintf("%.3g %s", val * unit, unit_name)
end

"""
    create_table(combined_results::OrderedDict; kws...)

Create a markdown table of the results loaded from the `load_results` function.
If there are two results for a given benchmark, will have an additional column
for the comparison, assuming the first revision is one to compare against.

"""
function create_table(
    combined_results::OrderedDict; add_ratio_col=true, pretty_table_kws=nothing
)
    if pretty_table_kws === nothing
        pretty_table_kws = (backend=Val(:text), tf=tf_markdown)
    end
    num_revisions = length(combined_results)
    num_cols = 1 + num_revisions

    headers = [[""]; keys(combined_results) .|> string]
    cutoff = 14
    headers = [
        if length(head) <= cutoff
            head
        else
            head[1:cutoff] * "..."
        end for head in headers
    ]

    data = Vector{String}[]

    # Each benchmark:
    for (_, result) in combined_results
        push!(data, keys(result) .|> string)
        break
    end

    # Data:
    for (_, result) in combined_results
        col = []
        for row in data[1]
            val = result[row]
            push!(col, format_time(val))
        end
        push!(data, col)
    end

    if num_revisions == 2 && add_ratio_col
        col = []
        for row in data[1]
            ratio = (/)([val[row]["mean_logspace"] for val in values(combined_results)]...)
            push!(col, @sprintf("%.3g", ratio))
        end
        push!(data, col)
        push!(headers, "t[$(headers[2])]/t[$(headers[3])]")
        num_cols += 1
    end

    mdata = hcat(data...)
    # With headers and data, let's make a markdown table with PrettyTables:
    return pretty_table(
        String,
        mdata;
        alignment=[:r, fill(:c, num_cols - 1)...],
        header=headers,
        pretty_table_kws...,
    )
end

end # AirspeedVelocity.TableUtils

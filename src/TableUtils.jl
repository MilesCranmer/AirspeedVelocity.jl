module TableUtils

using ..Utils: get_reasonable_unit
using OrderedCollections: OrderedDict
using Printf: @sprintf

function format_time(val::Dict)
    unit, unit_name = get_reasonable_unit([val["median"]])
    if haskey(val, "75")
        @sprintf(
            "%.3g ± %.2g %s",
            val["median"] * unit,
            (val["75"] - val["25"]) * unit,
            unit_name
        )
    else
        @sprintf("%.3g %s", val["median"] * unit, unit_name)
    end
end
function format_time(val::Number)
    unit, unit_name = get_reasonable_unit([val])
    @sprintf("%.3g %s", val * unit, unit_name)
end
function format_time(::Missing)
    return ""
end

"""
    create_table(combined_results::OrderedDict; kws...)

Create a markdown table of the results loaded from the `load_results` function.
If there are two results for a given benchmark, will have an additional column
for the comparison, assuming the first revision is one to compare against.

"""
function create_table(combined_results::OrderedDict; add_ratio_col=true)
    num_revisions = length(combined_results)
    num_cols = 1 + num_revisions
    # Order keys based on first result:
    all_keys = keys(first(values(combined_results)))

    # But, make sure we have all keys:
    for extra_key in union([keys(v) for v in values(combined_results)]...)
        if !in(extra_key, all_keys)
            push!(all_keys, extra_key)
        end
    end

    headers = String["", (keys(combined_results) .|> string)...]

    # Cutoff headers if needed:
    cutoff = 14
    headers = String[
        if length(head) <= cutoff
            head
        else
            first(head, cutoff) * "..."
        end for head in headers
    ]

    data_columns = Vector{String}[]

    for result in values(combined_results)
        col = String[]
        for row in all_keys
            val = get(result, row, missing)
            push!(col, format_time(val))
        end
        push!(data_columns, col)
    end

    if num_revisions == 2 && add_ratio_col
        col = String[]
        for row in data_columns[1]
            if all(r -> haskey(r, row), values(combined_results))
                ratio = (/)([val[row]["median"] for val in values(combined_results)]...)
                push!(col, @sprintf("%.3g", ratio))
            else
                push!(col, "")
            end
        end
        push!(data_columns, col)
        push!(headers, "t[$(headers[2])]/t[$(headers[3])]")
        num_cols += 1
    end

    mdata = hcat(all_keys .|> string, data_columns...)
    # With headers and data, let's make a markdown table
    return markdown_table(; data=mdata, header=headers)
end

function markdown_table(; data::AbstractMatrix, header::AbstractVector)
    @assert size(data, 2) == length(header)
    col_widths = [max(length(head), 4) for head in header]
    for row in eachrow(data)
        for (i, val) in enumerate(row)
            col_widths[i] = max(col_widths[i], length(string(val)))
        end
    end
    # GitHub-style markdown table:
    io = IOBuffer()
    # println(io, "| $(join(header, " | ")) |")
    print(io, "|")
    for (i, head) in enumerate(header)
        print(io, " $(head) " * " "^(col_widths[i] - length(head)) * "|")
    end
    println(io)

    # First column left-aligned:
    print(io, "|:---" * "-"^(col_widths[1] - 2) * "|")
    # Rest are centered:
    for (i, head) in enumerate(header)
        i == 1 && continue
        print(io, ":---" * "-"^(col_widths[i] - 3) * ":|")
    end

    println(io)
    for row in eachrow(data)
        # println(io, "| $(join(row, " | ")) |")
        print(io, "|")
        for (i, val) in enumerate(row)
            print(io, " $(val) " * " "^(col_widths[i] - length(string(val))) * "|")
        end
        println(io)
    end
    return take!(io) |> String
end

end # AirspeedVelocity.TableUtils

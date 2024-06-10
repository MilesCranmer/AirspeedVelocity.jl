module TableUtils

using ..Utils:
    get_reasonable_time_unit, get_reasonable_allocs_unit, get_reasonable_memory_unit
using OrderedCollections: OrderedDict
using Printf: @sprintf

function format_time(val::Dict)
    unit, unit_name = get_reasonable_time_unit([val["median"]])
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
    unit, unit_name = get_reasonable_memory_unit([val])
    @sprintf("%.3g %s", val * unit, unit_name)
end
function format_time(::Missing)
    return ""
end

function format_memory(val::Dict)
    allocs, memory = get(val, "allocs", nothing), get(val, "memory", nothing)
    if !isnothing(allocs) && !isnothing(memory)
        allocs_unit, allocs_unit_name = get_reasonable_allocs_unit(val["allocs"])
        memory_unit, memory_unit_name = get_reasonable_memory_unit(val["memory"])
        @sprintf(
            "%.3g %s allocs: %.3g %s",
            allocs * allocs_unit,
            allocs_unit_name,
            memory * memory_unit,
            memory_unit_name
        )
    else
        ""
    end
end
function format_memory(::Missing)
    return ""
end

function default_formatter(key)
    if key ∉ ("median", "memory")
        error("Unknown ratio column: $key")
    end

    if key == "memory"
        return format_memory
    else # if key == "median"
        return format_time
    end
end

"""
    create_table(combined_results::OrderedDict; kws...)

Create a markdown table of the results loaded from the `load_results` function.
If there are two results for a given benchmark, will have an additional column
for the comparison, assuming the first revision is one to compare against.

The `formatter` keyword argument generates the column value. It defaults to 
`TableUtils.format_time`, which prints the median time ± the interquantile range.
`TableUtils.format_memory` is also available to print the number of allocations
and the allocated memory.
"""
function create_table(
    combined_results::OrderedDict;
    key="median",
    add_ratio_col=true,
    formatter=default_formatter(key),
)
    num_revisions = length(combined_results)
    num_cols = 1 + num_revisions
    # Order keys based on first result:
    all_keys = [keys(first(values(combined_results)))...]

    # But, make sure we have all keys:
    for extra_key in union([keys(v) for v in values(combined_results)]...)
        if !in(extra_key, all_keys)
            push!(all_keys, extra_key)
        end
    end

    # Always put `time_to_load` at bottom:
    if in("time_to_load", all_keys)
        deleteat!(all_keys, findfirst(==("time_to_load"), all_keys))
        push!(all_keys, "time_to_load")
    end

    headers = String["", string.(keys(combined_results))...]

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
            push!(col, formatter(val))
        end
        push!(data_columns, col)
    end

    if num_revisions == 2 && add_ratio_col
        col = String[]
        for row in all_keys
            if all(r -> haskey(r, row), values(combined_results))
                ratio = (/)([val[row][key] for val in values(combined_results)]...)
                push!(col, @sprintf("%.3g", ratio))
            else
                push!(col, "")
            end
        end
        push!(data_columns, col)
        push!(headers, "$(headers[2])/$(headers[3])")
        num_cols += 1
    end

    mdata = hcat(string.(all_keys), data_columns...)
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
        print(io, "|")
        for (i, val) in enumerate(row)
            print(io, " $(val) " * " "^(col_widths[i] - length(string(val))) * "|")
        end
        println(io)
    end
    return String(take!(io))
end

end # AirspeedVelocity.TableUtils

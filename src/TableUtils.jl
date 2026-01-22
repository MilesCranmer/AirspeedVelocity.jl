module TableUtils

using ..Utils:
    get_reasonable_time_unit,
    get_reasonable_allocs_unit,
    get_reasonable_memory_unit,
    get_time_unit_scale
using OrderedCollections: OrderedDict
using Printf: @sprintf

"""
    format_time(val::Dict; time_unit=nothing)

Format a time value with optional fixed unit. When `time_unit` is `nothing`,
the unit is automatically chosen based on the magnitude.
Valid time units: "ns", "μs", "ms", "s", "h" (and `:us` is accepted as an alias for `"μs"`).
"""
function format_time(val::Dict; time_unit::Union{Nothing,Symbol}=nothing)
    if time_unit === nothing
        unit, unit_name = get_reasonable_time_unit([val["median"]])
    else
        unit, unit_name = get_time_unit_scale(time_unit)
    end
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

function format_time(::Missing; time_unit::Union{Nothing,Symbol}=nothing)
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

"""
    create_table(combined_results::OrderedDict; kws...)

Create a markdown table of the results loaded from the `load_results` function.
If there are two results for a given benchmark, will have an additional column
for the comparison, assuming the first revision is one to compare against.

The `formatter` keyword argument generates the column value. By default, the table
formats time as the median ± the interquantile range, and formats memory as the number
of allocations and allocated memory.

The `time_unit` keyword argument can be used to specify a fixed time unit for
all benchmark results. Valid values are: `:ns`, `Symbol("μs")`, `:ms`, `:s`, `:h` (and `:us` is accepted as an alias for `Symbol("μs")`).
If not specified (default), the unit is automatically chosen based on the magnitude
of the value. The `time_to_load` benchmark always uses auto-detection regardless
of this setting.
"""
function create_table(
    combined_results::OrderedDict;
    key="median",
    add_ratio_col=true,
    time_unit::Union{Nothing,Symbol}=nothing,
    formatter=nothing,
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
            if formatter !== nothing
                push!(col, formatter(val))
            else
                if key == "memory"
                    push!(col, format_memory(val))
                elseif key == "median"
                    effective_time_unit = row == "time_to_load" ? nothing : time_unit
                    push!(col, format_time(val; time_unit=effective_time_unit))
                else
                    error("Unknown ratio column: $key")
                end
            end
        end
        push!(data_columns, col)
    end

    if num_revisions == 2 && add_ratio_col
        col = String[]
        results = collect(values(combined_results))

        for benchmark_name in all_keys
            if !all(haskey(r, benchmark_name) for r in results)
                push!(col, "")
                continue
            end

            stats = [r[benchmark_name] for r in results]

            if !all(haskey(s, key) for s in stats)
                push!(col, "")
                continue
            end

            vals = [s[key] for s in stats]

            @assert length(vals) == 2
            ratio = vals[1] / vals[2]

            compute_ratio_err =
                all(haskey(s, "25") && haskey(s, "75") for s in stats) && key == "median"
            ratio_err = if compute_ratio_err
                errs = [max(0.0, s["75"] - s["25"]) for s in stats]
                abs(ratio) * sqrt((errs[1] / vals[1])^2 + (errs[2] / vals[2])^2)
            else
                NaN
            end
            string_ratio = join((
                isfinite(ratio) ? @sprintf("%.3g", ratio) : "",
                isfinite(ratio_err) ? @sprintf(" ± %.2g", ratio_err) : "",
            ))

            push!(col, string_ratio)
        end
        push!(data_columns, col)
        push!(headers, "$(headers[2]) / $(headers[3])")
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

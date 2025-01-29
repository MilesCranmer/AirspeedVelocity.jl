module Utils

using Pkg: PackageSpec
using Pkg: Pkg
using TOML: parsefile
using JSON3: JSON3
using FilePathsBase: isabspath, absolute, PosixPath
using OrderedCollections: OrderedDict
using Statistics: mean, median, quantile, std
using DispatchDoctor: @unstable

function get_spec_str(spec::PackageSpec)
    package_name = spec.name
    package_rev = spec.rev
    package_rev = replace(package_rev, "/" => "_")
    return string(package_name) * "@" * string(package_rev)
end

function get_reasonable_unit(value, units)
    unit_choice = argmin(abs.(log10.(value .* getindex.(units, 1))))
    unit, unit_name = units[unit_choice]
    return unit, unit_name
end

function get_reasonable_time_unit(quantities::AbstractArray)
    units = [(1.0, "ns"), (1e-3, "μs"), (1e-6, "ms"), (1e-9, "s"), (1e-9 / 3600, "h")]
    return get_reasonable_unit(median(quantities), units)
end

function get_reasonable_memory_unit(memory)
    units = [(1.0, "B"), (1 / 1024, "kB"), (1 / 1024^2, "MB"), (1 / 1024^3, "GB")]
    return get_reasonable_unit(memory, units)
end

function get_reasonable_allocs_unit(allocs)
    units = [(1.0, ""), (1e-3, "k"), (1e-6, "M"), (1e-9, "G")]
    return get_reasonable_unit(allocs, units)
end

function _get_script(;
    package_name::String,
    benchmark_on::Union{Nothing,String}=nothing,
    url::Union{Nothing,String}=nothing,
    path::Union{Nothing,String}=nothing,
)::Tuple{String,Union{String,Nothing}}
    # Create temp env, add package, and get path to benchmark script.
    @info "Downloading package's latest benchmark script, assuming it is in benchmark/benchmarks.jl"
    if benchmark_on !== nothing
        @info "Downloading from $benchmark_on."
    end
    tmp_env = mktempdir()
    to_exec = quote
        ENV["JULIA_PKG_PRECOMPILE_AUTO"] = 0
        using Pkg
        Pkg.add(
            PackageSpec(; name=$package_name, rev=$benchmark_on, url=$url, path=$path);
            io=devnull,
        )
        using $(Symbol(package_name)): $(Symbol(package_name))
        root_dir = dirname(dirname(pathof($(Symbol(package_name)))))
        open(joinpath($tmp_env, "package_path.txt"), "w") do io
            write(io, root_dir)
        end
    end
    path_getter = joinpath(tmp_env, "path_getter.jl")
    open(path_getter, "w") do io
        println(io, to_exec)
    end
    run(`julia --project="$tmp_env" --startup-file=no "$path_getter"`)

    root_dir = readchomp(joinpath(tmp_env, "package_path.txt"))
    script = joinpath(root_dir, "benchmark", "benchmarks.jl")
    if !isfile(script)
        @error "Could not find benchmark script at $script. Please specify the `script` manually."
    else
        @info "Found benchmark script at $script."
    end
    maybe_project_toml = joinpath(root_dir, "benchmark", "Project.toml")
    project_toml = if isfile(maybe_project_toml)
        @info "Found Project.toml at $maybe_project_toml."
        maybe_project_toml
    else
        nothing
    end

    return script, project_toml
end

function parse_package_spec(specifier::AbstractString)
    return only(
        Pkg.REPLMode.parse_package(
            [Pkg.REPLMode.QString(specifier, false)], nothing; add_or_dev=true
        ),
    )
end

function _benchmark(
    spec::PackageSpec;
    output_dir::String,
    script::String,
    tune::Bool,
    exeflags::Cmd,
    extra_pkgs::Vector{String},
    filter_benchmarks::Vector{String},
    project_toml::Union{Nothing,String},
    nsamples_load_time::Int,
)
    cur_dir = pwd()
    # Make sure paths are absolute, otherwise weird
    # behavior inside process:
    if !isabspath(output_dir)
        output_dir = string(absolute(PosixPath(output_dir)))
    end
    if !isabspath(script)
        script = string(absolute(PosixPath(script)))
    end
    if spec.path !== nothing && !isabspath(spec.path)
        spec.path = string(absolute(PosixPath(spec.path)))
    end
    spec_str = get_spec_str(spec)
    old_project = Pkg.project().path
    tmp_env = mktempdir()
    @info "    Creating temporary environment at $tmp_env."
    if project_toml !== nothing
        @info "    Copying $project_toml to environment."
        cp(project_toml, joinpath(tmp_env, "Project.toml"))
        chmod(joinpath(tmp_env, "Project.toml"), 0o644)
    end
    Pkg.activate(tmp_env; io=devnull)
    @info "    Adding packages."
    # Filter out empty strings from extra_pkgs:
    extra_pkgs = filter(x -> x != "", extra_pkgs)
    pkgs = ["BenchmarkTools", "JSON3", "Pkg", "TOML", extra_pkgs...]
    # Add extra packages. A "dirty" rev means we want to benchmark the local
    # version of the package at `path`.
    Pkg.add([parse_package_spec(pkg) for pkg in pkgs]; io=devnull)
    if spec.rev == "dirty"
        Pkg.develop(; path=spec.path, io=devnull)
    else
        Pkg.add(spec; io=devnull)
    end
    Pkg.precompile()
    Pkg.activate(old_project; io=devnull)
    results_filename = joinpath(output_dir, "results_" * spec_str * ".json")
    to_exec = quote
        using BenchmarkTools: @benchmarkable, run, tune!, BenchmarkGroup
        using JSON3: JSON3
        using Pkg: Pkg

        cd($cur_dir)
        # Include benchmark, defining SUITE:
        @info "    [runner] Loading benchmark script: " * $script * "."
        cur_project = Pkg.project().path

        #! format: off
        const _airspeed_velocity_extra_suite = BenchmarkGroup()
        if isempty($filter_benchmarks) || any(x -> contains(x, "time_to_load"), $filter_benchmarks)
            _airspeed_velocity_extra_suite["time_to_load"] = @benchmarkable(
                @eval(using $(Symbol(spec.name)): $(Symbol(spec.name)) as _AirspeedVelocityTestImport),
                evals=1,
                samples=1,
            )
        end
        const _airspeed_velocity_extra_results = run(_airspeed_velocity_extra_suite)
        #! format: on

        # Safely include, via module:
        module AirspeedVelocityRunner
            import $(Symbol(spec.name)): $(Symbol(spec.name)) as _AirspeedVelocityTestImport2
            import TOML: parsefile as toml_parsefile
            const PACKAGE_VERSION = let
                try
                    project = toml_parsefile(
                        joinpath(pkgdir(_AirspeedVelocityTestImport2), "Project.toml"),
                    )
                    VersionNumber(project["version"])
                catch
                    @warn "Failed to create `PACKAGE_VERSION`"
                    VersionNumber("0.0.0")
                end
            end

            # Included benchmark script:
            include($script)
        end

        using .AirspeedVelocityRunner: AirspeedVelocityRunner

        # Assert that SUITE is defined:
        if !isdefined(AirspeedVelocityRunner, :SUITE)
            @error "    [runner] Benchmark script " * $script * " did not define SUITE."
        end
        const filtered_suite = AirspeedVelocityRunner.SUITE

        if !(typeof(filtered_suite) <: BenchmarkGroup)
            @error "    [runner] Benchmark script " *
                $script *
                " did not define SUITE as a BenchmarkGroup."
        end
        # Assert that `include` did not change environments:
        if Pkg.project().path != cur_project
            @error "    [runner] Benchmark script " *
                $script *
                " changed the active environment. " *
                "This is not allowed, as it will " *
                "cause the benchmark to produce incorrect results."
        end

        # Recursively filter the suite to `filter_benchmarks`:
        function filter_suite!(f, suite, prefix="")
            filter!(suite.data) do (k, v)
                name = prefix * "/" * string(k)
                if v isa BenchmarkGroup
                    filter_suite!(f, v, name)
                else
                    f(name)
                end
            end
            return !isempty(suite.data)
        end

        if !isempty($filter_benchmarks)
            filter_suite!(
                name -> any(x -> contains(name, x), $filter_benchmarks), filtered_suite
            )
        end

        if $tune
            @info "    [runner] Tuning benchmarks."
            tune!(filtered_suite)
        end
        @info "    [runner] Running benchmarks for " * $spec_str * "."
        @info "-"^80
        results = run(filtered_suite; verbose=true)
        @info "-"^80
        @info "    [runner] Finished benchmarks for " * $spec_str * "."
        # Combine extra results:
        for (k, v) in _airspeed_velocity_extra_results.data
            results.data[k] = v
        end
        open($results_filename * ".tmp", "w") do io
            JSON3.write(io, results)
        end
        @info "    [runner] Benchmark results saved at " * $results_filename
    end
    runner_filename = joinpath(tmp_env, "runner.jl")
    open(runner_filename, "w") do io
        s = string(to_exec)
        s2 = split(s, "\n")
        s3 = s2[2:(end - 1)]
        s4 = join(s3, "\n")
        write(io, s4)
    end
    @info "    Launching benchmark runner."
    run(`julia --project="$tmp_env" --startup-file=no $exeflags "$runner_filename"`)
    # Return results from JSON file:
    @info "    Benchmark runner exited."
    @info "    Reading results."
    results = open(results_filename * ".tmp", "r") do io
        JSON3.read(io, Dict{String,Any})
    end
    if nsamples_load_time > 1 && haskey(results["data"], "time_to_load")
        @info "    Running additional time-to-load tests."
        load_times = results["data"]["time_to_load"]["times"]
        exe_string = "start=time_ns(); redirect_stdout(devnull) do; @eval using $(spec.name); end; stop=time_ns(); println(stop-start)"
        cmd =
            io -> pipeline(
                `julia --project="$tmp_env" --startup-file=no $exeflags -e "$exe_string"`;
                stdout=io,
            )
        for i in 2:nsamples_load_time
            @info "    Running time-to-load test $(i)/nsamples_load_time."
            io = IOBuffer()
            run(cmd(io))
            push!(load_times, parse(Float64, String(take!(io))))
        end
        @info "    Done time-to-load tests."
    end
    # Write to results file:
    open(results_filename, "w") do io
        JSON3.write(io, results)
    end
    @info "    Finished."
    return results
end

"""
    benchmark(package_name::String, rev::Union{String,Vector{String}}; output_dir::String=".", script::Union{String,Nothing}=nothing, tune::Bool=false, exeflags::Cmd=``, extra_pkgs::Vector{String}=String[])

Run benchmarks for a given Julia package.

This function runs the benchmarks specified in the `script` for the package defined by the `package_spec`. If `script` is not provided, the function will use the default benchmark script located at `{PACKAGE_SRC_DIR}/benchmark/benchmarks.jl`.

The benchmarks are run using the `SUITE` variable defined in the benchmark script, which should be of type BenchmarkTools.BenchmarkGroup. The benchmarks can be run with or without tuning depending on the value of the `tune` argument.

The results of the benchmarks are saved to a JSON file named `results_packagename@rev.json` in the specified `output_dir`.

# Arguments
- `package_name::String`: The name of the package for which to run the benchmarks.
- `rev::Union{String,Vector{String}}`: The revision of the package for which to run the benchmarks. You can also pass a vector of revisions to run benchmarks for multiple versions of a package.
- `output_dir::String="."`: The directory where the benchmark results JSON file will be saved (default: current directory).
- `script::Union{String,Nothing}=nothing`: The path to the benchmark script file. If not provided, the default script at `{PACKAGE}/benchmark/benchmarks.jl` will be used.
- `tune::Bool=false`: Whether to run benchmarks with tuning (default: false).
- `exeflags::Cmd=```: Additional execution flags for running the benchmark script (default: empty).
- `extra_pkgs::Vector{String}=String[]`: Additional packages to add to the benchmark environment.
- `url::Union{String,Nothing}=nothing`: URL of the package.
- `path::Union{String,Nothing}=nothing`: Path to the package.
- `benchmark_on::Union{String,Nothing}=nothing`: If the benchmark script file is to be downloaded, this specifies the revision to use.
- `filter_benchmarks::Vector{String}=String[]`: Filter the benchmarks to run (default: all).
- `nsamples_load_time::Int=5`: Number of samples to take for the time-to-load benchmark.
"""
function benchmark(
    package_name::String,
    revs::Vector{String};
    output_dir::String=".",
    script::Union{String,Nothing}=nothing,
    tune::Bool=false,
    exeflags::Cmd=``,
    extra_pkgs::Vector{String}=String[],
    url::Union{String,Nothing}=nothing,
    path::Union{String,Nothing}=nothing,
    benchmark_on::Union{String,Nothing}=nothing,
    filter_benchmarks::Vector{String}=String[],
    nsamples_load_time::Int=5,
)
    if "dirty" in revs && isnothing(path)
        @error "You must specify a `path` when using the `dirty` revision."
    end
    return benchmark(
        [PackageSpec(; name=package_name, rev=rev, url=url, path=path) for rev in revs];
        output_dir=output_dir,
        script=script,
        tune=tune,
        exeflags=exeflags,
        extra_pkgs=extra_pkgs,
        benchmark_on=benchmark_on,
        filter_benchmarks=filter_benchmarks,
        nsamples_load_time=nsamples_load_time,
    )
end
function benchmark(
    package_name::String,
    rev::String;
    output_dir::String=".",
    script::Union{String,Nothing}=nothing,
    tune::Bool=false,
    exeflags::Cmd=``,
    extra_pkgs::Vector{String}=String[],
    url::Union{String,Nothing}=nothing,
    path::Union{String,Nothing}=nothing,
    benchmark_on::Union{String,Nothing}=nothing,
    filter_benchmarks::Vector{String}=String[],
    nsamples_load_time::Int=5,
)
    return benchmark(
        package_name,
        [rev];
        output_dir=output_dir,
        script=script,
        tune=tune,
        exeflags=exeflags,
        extra_pkgs=extra_pkgs,
        url=url,
        path=path,
        benchmark_on=benchmark_on,
        filter_benchmarks=filter_benchmarks,
        nsamples_load_time=nsamples_load_time,
    )
end

"""
    benchmark(package_specs::Union{PackageSpec,Vector{PackageSpec}}; output_dir::String=".", script::Union{String,Nothing}=nothing, tune::Bool=false, exeflags::Cmd=``, extra_pkgs::Vector{String}=String[])

Run benchmarks for a given Julia package.

This function runs the benchmarks specified in the `script` for the package defined by the `package_spec`. If `script` is not provided, the function will use the default benchmark script located at `{PACKAGE_SRC_DIR}/benchmark/benchmarks.jl`.

The benchmarks are run using the `SUITE` variable defined in the benchmark script, which should be of type BenchmarkTools.BenchmarkGroup. The benchmarks can be run with or without tuning depending on the value of the `tune` argument.

The results of the benchmarks are saved to a JSON file named `results_packagename@rev.json` in the specified `output_dir`.

# Arguments
- `package::Union{PackageSpec,Vector{PackageSpec}}`: The package specification containing information about the package for which to run the benchmarks. You can also pass a vector of package specifications to run benchmarks for multiple versions of a package.
- `output_dir::String="."`: The directory where the benchmark results JSON file will be saved (default: current directory).
- `script::Union{String,Nothing}=nothing`: The path to the benchmark script file. If not provided, the default script at `{PACKAGE}/benchmark/benchmarks.jl` will be used.
- `tune::Bool=false`: Whether to run benchmarks with tuning (default: false).
- `exeflags::Cmd=```: Additional execution flags for running the benchmark script (default: empty).
- `extra_pkgs::Vector{String}=String[]`: Additional packages to add to the benchmark environment.
- `benchmark_on::Union{String,Nothing}=nothing`: If the benchmark script file is to be downloaded, this specifies the revision to use.
- `filter_benchmarks::Vector{String}=String[]`: Filter the benchmarks to run (default: all).
- `nsamples_load_time::Int=5`: Number of samples to take for the time-to-load benchmark.
"""
function benchmark(
    package_specs::Vector{PackageSpec};
    output_dir::String=".",
    script::Union{String,Nothing}=nothing,
    tune::Bool=false,
    exeflags::Cmd=``,
    extra_pkgs=String[],
    filter_benchmarks::Vector{String}=String[],
    benchmark_on::Union{String,Nothing}=nothing,
    project_toml::Union{String,Nothing}=nothing,
    nsamples_load_time::Int=5,
)
    script, project_toml = if script === nothing
        package_name = first(package_specs).name
        if !all(p -> p.name == package_name, package_specs)
            @error "All package specifications must have the same package name if you do not specify a `script`."
        end

        _get_script(;
            package_name,
            benchmark_on,
            first(package_specs).url,
            first(package_specs).path,
        )
    else
        (script, project_toml)
    end
    results = Dict{String,Any}()
    for spec in package_specs
        results[spec.name * "@" * spec.rev] = benchmark(
            spec;
            output_dir,
            script,
            tune,
            exeflags,
            extra_pkgs,
            filter_benchmarks,
            project_toml,
            nsamples_load_time,
        )
    end
    return results
end
function benchmark(
    package_spec::PackageSpec;
    output_dir::String=".",
    script::Union{String,Nothing}=nothing,
    tune::Bool=false,
    exeflags::Cmd=``,
    extra_pkgs=String[],
    filter_benchmarks::Vector{String}=String[],
    benchmark_on::Union{String,Nothing}=nothing,
    project_toml::Union{String,Nothing}=nothing,
    nsamples_load_time::Int=5,
)
    script, project_toml = if script === nothing
        _get_script(;
            package_name=package_spec.name,
            benchmark_on,
            package_spec.url,
            package_spec.path,
        )
    else
        (script, project_toml)
    end
    @info "Running benchmarks for " * package_spec.name * "@" * package_spec.rev * ":"
    return _benchmark(
        package_spec;
        output_dir,
        script,
        tune,
        exeflags,
        extra_pkgs,
        filter_benchmarks,
        project_toml,
        nsamples_load_time,
    )
end

@unstable function compute_summary_statistics(results)
    times = results["times"]
    d = Dict(
        "mean" => mean(times),
        "median" => median(times),
        "memory" => get(results, "memory", nothing),
        "allocs" => get(results, "allocs", nothing),
    )
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

function _flatten_results!(d::OrderedDict, results::Dict{String,Any}, prefix)
    if "times" in keys(results)
        d[prefix] = compute_summary_statistics(results)
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
    return d
end
function flatten_results(results::Dict{String,Any})
    d = OrderedDict{String,Any}()
    _flatten_results!(d, results, "")
    # Sort by key:
    return sort(d)
end

"""
    load_results(specs::Vector{PackageSpec}; input_dir::String=".")

Load the results from JSON files for each PackageSpec in the `specs` vector. The function assumes
that the JSON files are located in the `input_dir` directory and are named as "results_{s}.json"
where `s` is equal to `PackageName@Rev`.

The function returns a combined OrderedDict, to be input to the `combined_plots` function.

# Arguments
- `specs::Vector{PackageSpec}`: Vector of each package revision to be loaded (as `PackageSpec`).
- `input_dir::String="."`: Directory where the results. Default is current directory.

# Returns
- `OrderedDict{String,OrderedDict}`: Combined results ready to be passed
  to the `combined_plots` function.
"""
function load_results(specs::Vector{PackageSpec}; input_dir::String=".")
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
            @warn "Results for $name missing keys $missing_keys."
        end
    end

    return combined_results
end

function load_results(package_name::String, revs::Vector{String}; input_dir::String=".")
    specs = [PackageSpec(; name=package_name, rev=rev) for rev in revs]
    return load_results(specs; input_dir=input_dir)
end

"""
Fill in the package name, URL, and path based on the context.
"""
function get_package_name_defaults(package_name::String, url::String, path::String)
    if url != ""
        path != "" && error("You cannot specify both a URL and a path.")
        package_name == "" && error("You must specify a package name if passing the URL.")
    end

    if package_name == "" && url == "" && path == ""
        path = "."
    end

    if path != ""
        toml_path = joinpath(path, "Project.toml")
        toml = parsefile(toml_path)
        package_name = toml["name"]::String
    end

    return (package_name, url, path)
end

"""
Fill in the default branch if needed.
"""
parse_rev(rev::String, path::String) = rev == "{DEFAULT}" ? default_branch() : rev

const DEFAULT_BRANCH_NAMES = [
    "main", "master", "trunk", "dev", "devel", "develop", "default"
]
function default_branch()
    # See if we can determine the default branch locally:
    default_branches = [
        line for line in eachline(`git branch --format="%(refname:short)"`) if
        line ∈ DEFAULT_BRANCH_NAMES
    ]
    length(default_branches) == 1 && return only(default_branches)

    # If not, try to get it from the remote:
    cmd = `git remote show origin`
    # Execute the command and capture the output
    output = try
        read(cmd, String)
    catch
        throw_default_branch_error(default_branches, false)
    end
    # Parse the output to find the default branch
    default_branch_line = match(r"HEAD branch: (\w+)", output)
    default_branch_line === nothing && throw_default_branch_error(default_branches, true)
    return String(default_branch_line.captures[1])::String
end

function throw_default_branch_error(branches, cmd_succeeded)
    branch_detail = if isempty(branches)
        "none of $(join(DEFAULT_BRANCH_NAMES, ", ")) found"
    else
        "couldn't decide which of $(join(branches, ", ")) is the default"
    end
    remote_detail = if cmd_succeeded
        "the result of `git remote show origin` didn't specify the a HEAD branch"
    else
        "`git remote show origin` failed"
    end
    return error(
        """
        Unable to determine the default branch locally ($branch_detail).
        Also unnable to determine the default branch by querying the remote ($remote_detail).
        You can typically bypass this error by specifying the version manually (i.e. pass `-rev=...` to the CLI)
        """,
    )
end

end # module AirspeedVelocity.Utils

# API

## Creating benchmarks

From the command line:

```@docs
benchpkg
```

Or, directly from Julia:

```@docs
benchmark(package_name::String, rev::Vector{String}; output_dir::String=".", script::Union{String,Nothing}=nothing, tune::Bool=false, exeflags::Cmd=``, extra_pkgs::Vector{String}=String[])
```

```@docs
benchmark(package_specs::Vector{PackageSpec}; output_dir::String = ".", script::Union{String,Nothing} = nothing, tune::Bool = false, exeflags::Cmd = ``, extra_pkgs = String[])
```

## Loading and visualizing benchmarks

From the command line:

```@docs
benchpkgtable
benchpkgplot
```

```@docs
load_results(specs::Vector{PackageSpec}; input_dir::String=".")
```

```@docs
combined_plots(combined_results::OrderedDict; npart=10)
```

```@docs
create_table(combined_results::OrderedDict; kws...)
```

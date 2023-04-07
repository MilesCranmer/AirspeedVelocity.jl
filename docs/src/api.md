# API

## Creating benchmarks

```@docs
benchmark(package_name::String, rev::Vector{String}; output_dir::String=".", script::Union{String,Nothing}=nothing, tune::Bool=false, exeflags::Cmd=``, extra_pkgs::Vector{String}=String[])
```

```@docs
benchmark(package_specs::Vector{PackageSpec}; output_dir::String = ".", script::Union{String,Nothing} = nothing, tune::Bool = false, exeflags::Cmd = ``, extra_pkgs = String[])
```

## Loading benchmarks

```@docs
load_results(specs::Vector{PackageSpec}; input_dir::String=".")
```

```@docs
combined_plots(combined_results::OrderedDict; npart=10)
```

```@docs
create_table(combined_results::OrderedDict; kws...)
```

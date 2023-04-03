# API

```@docs
benchmark(package_name::String, rev::Vector{String}; output_dir::String=".", script::Union{String,Nothing}=nothing, tune::Bool=false, exeflags::Cmd=``, extra_pkgs::Vector{String}=String[])
```

```@docs
benchmark(package_specs::Vector{PackageSpec}; output_dir::String = ".", script::Union{String,Nothing} = nothing, tune::Bool = false, exeflags::Cmd = ``, extra_pkgs = String[])
```
# API

```@docs
benchmark(package_name::String, rev::Union{String,Vector{String}}; output_dir::String=".", benchmark_script::Union{String,Nothing}=nothing, tune::Bool=false, exeflags::Cmd=``)
benchmark(package::Union{PackageSpec,Vector{PackageSpec}}; output_dir::String=".", benchmark_script::Union{String,Nothing}=nothing, tune::Bool=false, exeflags::Cmd=``)
```

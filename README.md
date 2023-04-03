# AirspeedVelocity

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://MilesCranmer.github.io/AirspeedVelocity.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://MilesCranmer.github.io/AirspeedVelocity.jl/dev/)
[![Build Status](https://github.com/MilesCranmer/AirspeedVelocity.jl/actions/workflows/CI.yml/badge.svg?branch=master)](https://github.com/MilesCranmer/AirspeedVelocity.jl/actions/workflows/CI.yml?query=branch%3Amaster)
[![Coverage](https://coveralls.io/repos/github/MilesCranmer/AirspeedVelocity.jl/badge.svg?branch=master)](https://coveralls.io/github/MilesCranmer/AirspeedVelocity.jl?branch=master)

AirspeedVelocity.jl strives to make it easy to benchmark Julia packages over their lifetime.
It is inspired by [asv](https://asv.readthedocs.io/en/stable/).


### Motivation

*Why not [PkgBenchmark.jl](https://github.com/JuliaCI/PkgBenchmark.jl)?*

PkgBenchmark.jl is a thin wrapper of BenchmarkTools and Git, which might be enough for most users.
However, for me it was a bit too thin – this package tries to do more, and do it automatically (including plot generation, similar to `asv`),
especially for common workflows.

This package allows you to:

- Generate benchmarks directly from the terminal with an easy-to-use CLI
- Query many commits/tags/branches at a time, rather than requiring separate calls for each revision
- Plot those benchmarks, automatically flattening your benchmark suite into a list of plots with generated titles,
  with the x-axis showing revisions.
  
This package also freezes the benchmark script,
so there is no worry about the old history overwriting the benchmark.

# Installation

You can install the CLI with:

```bash
julia -e 'using Pkg; \
          Pkg.add(url="https://github.com/MilesCranmer/AirspeedVelocity.jl.git"); \
          Pkg.build("AirspeedVelocity")'
```

This will install two executables at `~/.julia/bin` - make sure to have it on your `PATH`.

# Examples

You may then use the CLI to generate benchmarks for any package with, e.g.,

```bash
benchpkg Transducers --rev='v0.4.65,v0.4.70,master' --add='BangBang,ArgCheck,Referenceables,SplitApplyCombine'
```

which will download `benchmark/benchmarks.jl` of `Transducers.jl`,
run the benchmarks for all revisions given (`v0.4.65`, `v0.4.70`, and `master`),
and then save the JSON results in the current directory.
Here, we also specify additional packages needed
inside the benchmarks.

You can generate plots of the revisions with:

```bash
benchpkgplot Transducers --rev='v0.4.65,v0.4.70,master' --npart=10
```

which will generate a png file of plots, showing the change with each revision.
The `--npart` flag specifies the maximum number of plots per page; if there are more
than `npart` plots, they will be split into multiple images.


You can also provide a custom benchmark.
For example, let's say you have a file `script.jl`, defining
a benchmark for `SymbolicRegression.jl`:

```julia
using BenchmarkTools, SymbolicRegression
const SUITE = BenchmarkGroup()
SUITE["eval_tree_array"] = begin
    b = BenchmarkGroup()
    options = Options(; binary_operators=[+, -, *], unary_operators=[cos])
    tree = Node(; feature=1) + cos(3.2f0 * Node(; feature=2))
    X = randn(Float32, 2, 10)
    f() = eval_tree_array(tree, X, options)
    b["10"] = @benchmarkable f() evals=1 samples=100

    X2 = randn(Float32, 2, 20)
    f2() = eval_tree_array(tree, X2, options)
    b["20"] = @benchmarkable f2() evals=1 samples=100
    b
end
```

we can run this benchmark over the history of `SymbolicRegression.jl` with:

```bash
benchpkg SymbolicRegression -r v0.15.3,v0.16.2 -s script.jl -o results/ --exeflags="--threads=4 -O3"
```

where we have also specified the output directory and extra flags to pass to the
`julia` executable. We can also now visualize this:

```bash
benchpkgplot SymbolicRegression -r v0.15.3,v0.16.2 -i results/ -o plots/ --format=pdf
```


# Usage

The CLI is documented as:

```
    benchpkg package_name [-r --rev <arg>] [-o, --output_dir <arg>]
                          [-s, --script <arg>] [-e, --exeflags <arg>]
                          [-a, --add <arg>] [-t, --tune]
                          [-u, --url <arg>]

Benchmark a package over a set of revisions.

# Arguments

- `package_name`: Name of the package.

# Options

- `-r, --rev <arg>`: Revisions to test (delimit by comma).
- `-o, --output_dir <arg>`: Where to save the JSON results.
- `-s, --script <arg>`: The benchmark script. Default: `{PACKAGE_SRC_DIR}/benchmark/benchmarks.jl`.
- `-e, --exeflags <arg>`: CLI flags for Julia (default: none).
- `-a, --add <arg>`: Extra packages needed (delimit by comma).
- `-u, --url <arg>`: URL of the package.

# Flags

- `-t, --tune`: Whether to run benchmarks with tuning (default: false).

```

For plotting, you can use the `benchpkgplot` function:

```
    benchpkgplot package_name [-r --rev <arg>] [-i --input_dir <arg>]
                              [-o --output_dir <arg>] [-n --npart <arg>]
                              [-f --format <arg>]

Plot the benchmarks of a package as created with `benchpkg`.

# Arguments

- `package_name`: Name of the package.

# Options

- `-r, --rev <arg>`: Revisions to test (delimit by comma).
- `-i, --input_dir <arg>`: Where the JSON results were saved (default: ".").
- `-o, --output_dir <arg>`: Where to save the plots results (default: ".").
- `-n, --npart <arg>`: Max number of plots per page (default: 10).
- `-f, --format <arg>`: File type to save the plots as (default: "png").
```

If you prefer to use the Julia API, you can use the `benchmark` function for generating data:

```julia
benchmark(package::Union{PackageSpec,Vector{PackageSpec}}; output_dir::String=".", script::Union{String,Nothing}=nothing, tune::Bool=false, exeflags::Cmd=``)
benchmark(package_name::String, rev::Union{String,Vector{String}}; output_dir::String=".", script::Union{String,Nothing}=nothing, tune::Bool=false, exeflags::Cmd=``)
```

These output a `Dict` containing the combined results of the benchmarks,
and also output a JSON file in the `output_dir` for each revision.

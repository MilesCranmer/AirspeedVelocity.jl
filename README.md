# AirspeedVelocity

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://MilesCranmer.github.io/AirspeedVelocity.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://MilesCranmer.github.io/AirspeedVelocity.jl/dev/)
[![Build Status](https://github.com/MilesCranmer/AirspeedVelocity.jl/actions/workflows/CI.yml/badge.svg?branch=master)](https://github.com/MilesCranmer/AirspeedVelocity.jl/actions/workflows/CI.yml?query=branch%3Amaster)
[![Coverage](https://coveralls.io/repos/github/MilesCranmer/AirspeedVelocity.jl/badge.svg?branch=master)](https://coveralls.io/github/MilesCranmer/AirspeedVelocity.jl?branch=master)

## Installation

You can install the CLI with:

```bash
julia -e '\
    using Pkg; \
    Pkg.add(url="https://github.com/MilesCranmer/AirspeedVelocity.jl.git"); \
    Pkg.build("AirspeedVelocity")'
```

You may then use the CLI with, e.g.,

```bash
benchpkg Convex v0.15.1 v0.15.2 v0.15.3 master
```

which will download `benchmark/benchmarks.jl` of `Convex.jl`,
run the benchmarks for all revisions given,
and then save the JSON results in the current directory.

You can also provide have to provide `script.jl`,
in which case the file `benchmark/benchmarks.jl`
of the package will be used. For example, let's say you have a file
`script.jl`:

```julia
using BenchmarkTools, SymbolicRegression
const SUITE = BenchmarkGroup()
SUITE["eval_tree_array"] = begin
    tree = Node(; feature=1) + cos(3.2f0 * Node(; feature=2))
    X = randn(Float32, 2, 1_000)
    options = Options(; binary_operators=[+, -, *], unary_operators=[cos])
    f() = eval_tree_array(tree, X, options)
    @benchmarkable f() evals=1 samples=100
end
```

we can run this benchmark over the history of `SymbolicRegression.jl` with:

```bash
benchpkg SymbolicRegression v0.15.3 v0.16.2 -s script.jl -o results/
```

where we have also specified the output directory.

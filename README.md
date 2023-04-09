# AirspeedVelocity.jl

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://MilesCranmer.github.io/AirspeedVelocity.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://MilesCranmer.github.io/AirspeedVelocity.jl/dev/)
[![Build Status](https://github.com/MilesCranmer/AirspeedVelocity.jl/actions/workflows/CI.yml/badge.svg?branch=master)](https://github.com/MilesCranmer/AirspeedVelocity.jl/actions/workflows/CI.yml?query=branch%3Amaster)
[![Coverage](https://coveralls.io/repos/github/MilesCranmer/AirspeedVelocity.jl/badge.svg?branch=master)](https://coveralls.io/github/MilesCranmer/AirspeedVelocity.jl?branch=master)

AirspeedVelocity.jl strives to make it easy to benchmark Julia packages over their lifetime.
It is inspired by [asv](https://asv.readthedocs.io/en/stable/).

This package allows you to:

- Generate benchmarks directly from the terminal with an easy-to-use CLI.
- Compare many commits/tags/branches at once.
- Plot those benchmarks, automatically flattening your benchmark suite into a list of plots with generated titles.
- Run as a GitHub action to create benchmark comparisons for every submitted PR (in a bot comment).
  
This package also freezes the benchmark script at a particular revision,
so there is no worry about the old history overwriting the benchmark.

## Installation

You can install the CLI with:

```bash
julia -e 'using Pkg; Pkg.add("AirspeedVelocity"); Pkg.build("AirspeedVelocity")'
```

This will install two executables at `~/.julia/bin` - make sure to have it on your `PATH`.

## Examples

You may then use the CLI to generate benchmarks for any package with, e.g.,

```bash
benchpkg Transducers \
    --rev=v0.4.20,v0.4.70,master \
    --bench-on=v0.4.20
```

which will benchmark `Transducers.jl`,
at the revisions `v0.4.20`, `v0.4.70`, and `master`,
using the benchmark script `benchmark/benchmarks.jl` as it was defined at `v0.4.20`,
and then save the JSON results in the current directory.

We can then generate plots of the revisions with:

```bash
benchpkgplot Transducers \
    --rev=v0.4.20,v0.4.70,master \
    --format=pdf \
    --npart=5
```

which will generate a pdf file for each set of 5 plots,
showing the change with each revision:

<img width="877" alt="Screenshot 2023-04-03 at 10 36 16 AM" src="https://user-images.githubusercontent.com/7593028/229543368-14b1da88-8315-437b-b38f-fff143f26e3a.png">

You can also provide a custom benchmark.
For example, let's say you have a file `script.jl`, defining
a benchmark for `SymbolicRegression.jl` (we always need to define
the `SUITE` variable as a `BenchmarkGroup`):

```julia
using BenchmarkTools, SymbolicRegression
const SUITE = BenchmarkGroup()

# Create hierarchy of benchmarks:
SUITE["eval_tree_array"] = BenchmarkGroup()

options = Options(; binary_operators=[+, -, *], unary_operators=[cos])
tree = Node(; feature=1) + cos(3.2f0 * Node(; feature=2))


for n in [10, 20]
    SUITE["eval_tree_array"][n] = @benchmarkable(
        eval_tree_array($tree, X, $options),
        evals=10,
        samples=1000,
        X=randn(Float32, 2, $n),
    )
end

```

Inside this script, we will also have access to the `PACKAGE_VERSION` constant,
to allow for different behavior depending on tag.
We can run this benchmark over the history of `SymbolicRegression.jl` with:

```bash
benchpkg SymbolicRegression \
    -r v0.15.3,v0.16.2 \
    -s script.jl \
    -o results/ \
    --exeflags="--threads=4 -O3"
```

where we have also specified the output directory and extra flags to pass to the
`julia` executable. We can also now visualize this:

```bash
benchpkgplot SymbolicRegression \
    -r v0.15.3,v0.16.2 \
    -i results/ \
    -o plots/
```

## Usage

For running benchmarks, you can use the `benchpkg` command, which is
built into the `~/.julia/bin` folder:

```text
    benchpkg package_name [-r --rev <arg>] [-o, --output-dir <arg>]
                          [-s, --script <arg>] [-e, --exeflags <arg>]
                          [-a, --add <arg>] [--tune]
                          [--url <arg>] [--path <arg>]
                          [--bench-on <arg>]

Benchmark a package over a set of revisions.

# Arguments

- `package_name`: Name of the package.

# Options

- `-r, --rev <arg>`: Revisions to test (delimit by comma).
- `-o, --output-dir <arg>`: Where to save the JSON results.
- `-s, --script <arg>`: The benchmark script. Default: `benchmark/benchmarks.jl` downloaded from `stable`.
- `-e, --exeflags <arg>`: CLI flags for Julia (default: none).
- `-a, --add <arg>`: Extra packages needed (delimit by comma).
- `--url <arg>`: URL of the package.
- `--path <arg>`: Path of the package.
- `--bench-on <arg>`: If the script is not set, this specifies the revision at which
  to download `benchmark/benchmarks.jl` from the package.

# Flags

- `--tune`: Whether to run benchmarks with tuning (default: false).
```

For plotting, you can use the `benchpkgplot` function:

```text
    benchpkgplot package_name [-r --rev <arg>] [-i --input-dir <arg>]
                              [-o --output-dir <arg>] [-n --npart <arg>]
                              [--format <arg>]

Plot the benchmarks of a package as created with `benchpkg`.

# Arguments

- `package_name`: Name of the package.

# Options

- `-r, --rev <arg>`: Revisions to test (delimit by comma).
- `-i, --input-dir <arg>`: Where the JSON results were saved (default: ".").
- `-o, --output-dir <arg>`: Where to save the plots results (default: ".").
- `-n, --npart <arg>`: Max number of plots per page (default: 10).
- `--format <arg>`: File type to save the plots as (default: "png").
```

If you prefer to use the Julia API, you can use the `benchmark` function for generating data.
The API is given [here](https://astroautomata.com/AirspeedVelocity.jl/dev/api/).

## Using in CI

You can use this package in GitHub actions to benchmark every PR submitted to your package,
by copying the example: [`.github/workflows/benchmark_pr.yml`](https://github.com/MilesCranmer/AirspeedVelocity.jl/blob/master/.github/workflows/benchmark_pr.yml).

Every time a PR is submitted to your package, this workflow will run
and generate plots of the performance of the PR against the default branch,
as well as a markdown table, showing whether the PR improves or worsens performance:

![Screenshot from 2023-04-07 08-00-36](https://user-images.githubusercontent.com/7593028/230605635-a9201ce3-c4bf-4bc6-a672-f6997bc605c8.png)

## Related packages

Also be sure to check out [PkgBenchmark.jl](https://github.com/JuliaCI/PkgBenchmark.jl).
PkgBenchmark.jl is a simple wrapper of BenchmarkTools.jl to interface it with Git, and
is a good choice for building custom analysis workflows.

However, for me this wrapper is a bit too thin, which is why I created this package.
AirspeedVelocity.jl tries to have more features and workflows readily-available.
It also emphasizes a CLI (though there is a Julia API), as my subjective view
is that this is more suitable for interacting side-by-side with `git`.

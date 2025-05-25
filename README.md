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
- Run in CI with a one‑line GitHub Action that comments benchmark results on every PR.
  
This package also freezes the benchmark script at a particular revision,
so there is no worry about the old history overwriting the benchmark.

https://github.com/MilesCranmer/AirspeedVelocity.jl/assets/7593028/f27b04ef-8491-4f49-a312-4df0fae00598

- [AirspeedVelocity.jl](#airspeedvelocityjl)
  - [Installation](#installation)
  - [Examples](#examples)
  - [Using in CI](#using-in-ci)
    - [Copy-and-paste GitHub Action](#copy-and-paste-githubaction)
    - [Multiple Julia versions](#multiple-julia-versions)
    - [CLI Parameters](#cli-parameters)
  - [Further examples](#further-examples)
  - [CLI Reference](#cli-reference)
    - [`benchpkg`](#benchpkg)
    - [`benchpkgtable`](#benchpkgtable)
    - [`benchpkgplot`](#benchpkgplot)
  - [Related packages](#related-packages)

## Installation

You can install the CLI with:

```bash
julia -e 'using Pkg; Pkg.activate(temp=true); Pkg.add("AirspeedVelocity"); Pkg.build("AirspeedVelocity")'
```

This will install two executables at `~/.julia/bin` - make sure to have it on your `PATH`.

## Examples

You may use the CLI to generate benchmarks for any package with, e.g.,

```bash
benchpkg
```

This will benchmark the package defined in the current directory at the current dirty state, against the default branch (i.e., `main` or `master`), over all benchmarks defined in `benchmark/benchmarks.jl` using BenchmarkTools.jl. You should have a `const SUITE = BenchmarkGroup()` defined in this file, which you have added benchmarks to.

This will then print a markdown table of the results while also saving the JSON results to the current directory.

See the [further examples](#further-examples) for more details.

## Using in CI

### Copy-and-paste GitHub Action

Add `.github/workflows/benchmark.yml` to your package:

```yaml
name: Benchmark this PR
on:
  pull_request_target:
    branches: [ master ]  # change to your default branch
permissions:
  pull-requests: write    # action needs to post a comment

jobs:
  bench:
    runs-on: ubuntu-latest
    steps:
      - uses: MilesCranmer/AirspeedVelocity.jl@action-v1
        with:
          julia-version: '1'
```

The workflow runs AirspeedVelocity, then posts a comment titled **Benchmark Results (Julia v1)** with separate, collapsible tables for runtime and memory.  
### Multiple Julia versions

```yaml
strategy:
  matrix:
    julia: ['1', '1.10']

steps:
  - uses: MilesCranmer/AirspeedVelocity.jl@action-v1
    with:
      julia-version: ${{ matrix.julia }}
```

Each matrix leg writes its own comment.

### CLI Parameters

| Input           | Default          | What it does                               |
|-----------------|------------------|--------------------------------------------|
| `julia-version` | `"1"`            | Julia version to install                   |
| `tune`          | `"false"`        | `--tune` to tune benchmarks first          |
| `mode`          | `"time,memory"`  | Which tables to generate (`time`, `memory`)|
| `enable-plots`  | `"false"`        | Upload PNG plots as artifact               |
| `filter`        | `""`             | `--filter` list for `benchpkg`             |
| `exeflags`      | `""`             | `--exeflags` for Julia runner              |

## Further examples


You can configure all options with the CLI flags. For example, to benchmark
the registered package `Transducers.jl` at the revisions `v0.4.20`, `v0.4.70`, and `master`,
you can use:

```bash
benchpkg Transducers \
    --rev=v0.4.20,v0.4.70,master \
    --bench-on=v0.4.20
```

This will further use the benchmark script `benchmark/benchmarks.jl` as it was defined at `v0.4.20`,
and then save the JSON results in the current directory.

We can explicitly view the results of the benchmark as a table with `benchpkgtable`:

```bash
benchpkgtable Transducers \
    --rev=v0.4.20,v0.4.70,master
```

We can also generate plots of the revisions with:

```bash
benchpkgplot Transducers \
    --rev=v0.4.20,v0.4.70,master \
    --format=pdf \
    --npart=5
```

which will generate a pdf file for each set of 5 plots,
showing the change with each revision:

![runtime_at_versions](https://user-images.githubusercontent.com/7593028/229543368-14b1da88-8315-437b-b38f-fff143f26e3a.png)

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
        setup=(X=randn(Float32, 2, $n))
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

## CLI Reference

### `benchpkg`

For running benchmarks, you can use the `benchpkg` command, which is
built into the `~/.julia/bin` folder:

```markdown
    benchpkg [package_name] [-r --rev <arg>]
                            [--url <arg>]
                            [--path <arg>]
                            [-o, --output-dir <arg>]
                            [-e, --exeflags <arg>]
                            [-a, --add <arg>]
                            [-s, --script <arg>]
                            [--bench-on <arg>]
                            [-f, --filter <arg>]
                            [--nsamples-load-time <arg>]
                            [--tune]
                            [--dont-print]

Benchmark a package over a set of revisions.

#### Arguments

- `package_name`: Name of the package. If not given, the package is assumed to be
  the current directory.

#### Options

- `-r, --rev <arg>`: Revisions to test (delimit by comma). Use `dirty` to
  benchmark the current state of the package at `path` (and not a git commit).
  The default is `{DEFAULT},dirty`, which will attempt to find the default branch
  of the package.
- `--url <arg>`: URL of the package.
- `--path <arg>`: Path of the package. The default is `.` if other arguments are not given.
- `-o, --output-dir <arg>`: Where to save the JSON results. The default is `.`.
- `-e, --exeflags <arg>`: CLI flags for Julia (default: none).
- `-a, --add <arg>`: Extra packages needed (delimit by comma).
- `-s, --script <arg>`: The benchmark script. Default: `benchmark/benchmarks.jl` downloaded from `stable`.
- `--bench-on <arg>`: If the script is not set, this specifies the revision at which
  to download `benchmark/benchmarks.jl` from the package.
- `-f, --filter <arg>`: Filter the benchmarks to run (delimit by comma).
- `--nsamples-load-time <arg>`: Number of samples to take when measuring load time of
    the package (default: 5). (This means starting a Julia process for each sample.)
- `--dont-print`: Don't print the table.

#### Flags

- `--tune`: Whether to run benchmarks with tuning (default: false).
```

### `benchpkgtable`

You can also just generate a table from stored JSON results:

```markdown
    benchpkgtable [package_name] [-r --rev <arg>]
                                 [-i --input-dir <arg>]
                                 [--ratio]
                                 [--mode <arg>]
                                 [--url <arg>]
                                 [--path <arg>]

Print a table of the benchmarks of a package as created with `benchpkg`.

#### Arguments

- `package_name`: Name of the package.

#### Options

- `-r, --rev <arg>`: Revisions to test (delimit by comma).
  The default is `{DEFAULT},dirty`, which will attempt to find the default branch
  of the package.
- `-i, --input-dir <arg>`: Where the JSON results were saved (default: ".").
- `--url <arg>`: URL of the package. Only used to get the package name.
- `--path <arg>`: Path of the package. The default is `.` if other arguments are not given.
   Only used to get the package name.

#### Flags

- `--ratio`: Whether to include the ratio (default: false). Only applies when
    comparing two revisions.
- `--mode`: Table mode(s). Valid values are "time" (default), to print the
    benchmark time, or "memory", to print the allocation and memory usage.
    Both options can be passed, if delimited by comma.
```

### `benchpkgplot`

For plotting, you can use the `benchpkgplot` function:

```markdown
    benchpkgplot package_name [-r --rev <arg>]
                              [-i --input-dir <arg>]
                              [-o --output-dir <arg>]
                              [-n --npart <arg>]
                              [--format <arg>]

Plot the benchmarks of a package as created with `benchpkg`.

#### Arguments

- `package_name`: Name of the package.

#### Options

- `-r, --rev <arg>`: Revisions to test (delimit by comma).
- `-i, --input-dir <arg>`: Where the JSON results were saved (default: ".").
- `-o, --output-dir <arg>`: Where to save the plots results (default: ".").
- `-n, --npart <arg>`: Max number of plots per page (default: 10).
- `--format <arg>`: File type to save the plots as (default: "png").
```

If you prefer to use the Julia API, you can use the `benchmark` function for generating data.
The API is given [here](https://astroautomata.com/AirspeedVelocity.jl/dev/api/).

## Related packages

Also be sure to check out [PkgBenchmark.jl](https://github.com/JuliaCI/PkgBenchmark.jl).
PkgBenchmark.jl is a simple wrapper of BenchmarkTools.jl to interface it with Git, and
is a good choice for building custom analysis workflows.

However, for me this wrapper is a bit too thin, which is why I created this package.
AirspeedVelocity.jl tries to have more features and workflows readily-available.
It also emphasizes a CLI (though there is a Julia API), as my subjective view
is that this is more suitable for interacting side-by-side with `git`.

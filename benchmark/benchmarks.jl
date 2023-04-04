# This "benchmark" is only a demo; it is not a real benchmark.
using BenchmarkTools
using AirspeedVelocity

const SUITE = BenchmarkGroup()

SUITE["main"] = BenchmarkGroup()

SUITE["main"]["get_script"] = @benchmarkable _get_script(;
    package_name="Convex", benchmark_on="v0.13.1"
) evals = 1 samples = 5

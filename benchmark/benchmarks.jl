# This "benchmark" is only a demo; it is not a real benchmark.
using BenchmarkTools

const SUITE = BenchmarkGroup()

SUITE["main"] = BenchmarkGroup()

SUITE["main"]["random_sleep"] = @benchmarkable sleep(t) setup = (t = rand()) evals = 1 samples =
    2

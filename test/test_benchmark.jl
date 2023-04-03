using AirspeedVelocity
using Test

tmp = mktempdir()
script = joinpath(tmp, "bench.jl")
open(script, "w") do io
    write(
        io,
        """

using BenchmarkTools
using SymbolicRegression

const SUITE = BenchmarkGroup()
SUITE["eval_tree_array"] = begin
    options = Options(; binary_operators=[+, -, *], unary_operators=[cos])
    x, y = Node(; feature=1), Node(; feature=2)
    tree = x + cos(3.2f0 * y)

    X = randn(Float32, 2, 1_000)
    f() = eval_tree_array(tree, X, options)
    @benchmarkable f() evals=1 samples=100
end

    """,
    )
end

results = benchmark("SymbolicRegression", ["v0.15.3", "v0.16.2"]; script=script)
@test length(results) == 2
@test "SymbolicRegression@v0.15.3" in keys(results)
@test "SymbolicRegression@v0.16.2" in keys(results)
@test length(results["SymbolicRegression@v0.15.3"]["data"]["eval_tree_array"]["times"]) ==
    100
@test length(results["SymbolicRegression@v0.16.2"]["data"]["eval_tree_array"]["times"]) ==
    100

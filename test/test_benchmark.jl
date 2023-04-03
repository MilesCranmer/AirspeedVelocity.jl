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
    b = BenchmarkGroup()
    options = Options(; binary_operators=[+, -, *], unary_operators=[cos])
    x, y = Node(; feature=1), Node(; feature=2)
    tree = x + cos(3.2f0 * y)

    X = randn(Float32, 2, 10)
    f() = eval_tree_array(tree, X, options)
    b["eval_10"] = @benchmarkable f() evals=1 samples=100

    X2 = randn(Float32, 2, 20)
    f2() = eval_tree_array(tree, X2, options)
    f2() # warmup
    b["eval_20"] = @benchmarkable f2() evals=1 samples=100

    b
end

    """,
    )
end

results = benchmark("SymbolicRegression", ["v0.15.3", "v0.16.2"]; script=script)
@test length(results) == 2
@test "SymbolicRegression@v0.15.3" in keys(results)
@test "SymbolicRegression@v0.16.2" in keys(results)
@test length(
    results["SymbolicRegression@v0.15.3"]["data"]["eval_tree_array"]["data"]["eval_10"]["times"],
) == 100
@test length(
    results["SymbolicRegression@v0.16.2"]["data"]["eval_tree_array"]["data"]["eval_10"]["times"],
) == 100

# Create plots:
combined_results = load_results("SymbolicRegression", ["v0.15.3", "v0.16.2"])
plots = combined_plots(combined_results; npart=1)
@test length(plots) == 2
plots = combined_plots(combined_results; npart=2)
@test length(plots) == 1

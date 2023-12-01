using AirspeedVelocity
using OrderedCollections: OrderedDict
using Test
import Base: isapprox

function Base.isapprox(s1::String, s2::String)
    return replace(s1, r"\s+" => "") == replace(s2, r"\s+" => "")
end

@testset "Test run benchmarking" begin
    tmp = mktempdir(; cleanup=false)
    script = joinpath(tmp, "bench.jl")
    open(script, "w") do io
        write(
            io,
            """
        using BenchmarkTools
        using SymbolicRegression

        @assert PACKAGE_VERSION in (v"0.15.3", v"0.16.2")

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

    # Ensure Transducers.jl has its Project.toml copied:
    tmp2 = mktempdir(; cleanup=false)
    script = joinpath(tmp2, "bench.jl")
    open(script, "w") do io
        write(io, """
            using BenchmarkTools
            using Transducers

            const SUITE = BenchmarkGroup()
            function f()
                return 1:3 |> Map(x -> 2x) |> collect
            end
            SUITE["simple"] = @benchmarkable f()
        """ |> s -> replace(s, r"^\s+" => ""))
    end

    # Test with CLI version:
    results_dir = mktempdir(; cleanup=false)
    benchpkg(
        "Transducers";
        rev="v0.4.50,v0.4.70",
        script=script,
        tune=true,
        output_dir=string(results_dir),
    )
    @test isfile(joinpath(results_dir, "results_Transducers@v0.4.50.json"))
    @test isfile(joinpath(results_dir, "results_Transducers@v0.4.70.json"))
end

@testset "Test plot results" begin
    # Create plots:
    combined_results = load_results("SymbolicRegression", ["v0.15.3", "v0.16.2"])
    plots = combined_plots(combined_results; npart=1)
    @test length(plots) == 3
    plots = combined_plots(combined_results; npart=2)
    @test length(plots) == 2
end

@testset "Test getting script" begin
    script_path, project_toml = AirspeedVelocity.Utils._get_script(;
        package_name="Convex", benchmark_on="v0.13.1"
    )

    script_downloaded = open(script_path, "r") do io
        read(io, String)
    end

    # Compare against truth:
    truth = """
    using Pkg
    tempdir = mktempdir()
    Pkg.activate(tempdir)
    Pkg.develop(PackageSpec(path=joinpath(@__DIR__, "..")))
    Pkg.add(["BenchmarkTools", "PkgBenchmark", "MathOptInterface"])
    Pkg.resolve()

    using Convex: Convex, ProblemDepot
    using BenchmarkTools
    using MathOptInterface
    const MOI = MathOptInterface
    const MOIU = MOI.Utilities

    const SUITE = BenchmarkGroup()

    problems =  [   
                    "constant_fix!_with_complex_numbers",
                    "affine_dot_multiply_atom",
                    "affine_hcat_atom",
                    "affine_trace_atom",
                    "exp_entropy_atom",
                    "exp_log_perspective_atom",
                    "socp_norm_2_atom",
                    "socp_quad_form_atom",
                    "socp_sum_squares_atom",
                    "lp_norm_inf_atom",
                    "lp_maximum_atom",
                    "sdp_and_exp_log_det_atom",
                    "sdp_norm2_atom",
                    "sdp_lambda_min_atom",
                    "sdp_sum_largest_eigs",
                    "mip_integer_variables",
                ]

    SUITE["formulation"] = ProblemDepot.benchmark_suite(problems) do problem
        model = MOIU.MockOptimizer(MOIU.Model{Float64}())
        Convex.load_MOI_model!(model, problem)
    end
    """
    @test script_downloaded ≈ truth
end

@testset "Test table generation" begin
    combined_results = OrderedDict(
        "v1" => OrderedDict(
            "bench1" => Dict("median" => 1.2e9, "75" => 1.3e9, "25" => 1.1e9),
            "bench2" => Dict("median" => 0.2e6, "75" => 0.3e6, "25" => 0.1e6),
        ),
        "v2" => OrderedDict(
            "bench1" => Dict("median" => 1.2e10, "75" => 1.3e10, "25" => 1.1e10),
            "bench2" => Dict("median" => 0.2e5, "75" => 0.3e5, "25" => 0.1e5),
        ),
    )

    truth = """
    |        | v1           | v2         | t[v1]/t[v2] |
    |:-------|:------------:|:----------:|:-----------:|
    | bench1 | 1.2 ± 0.2 s  | 12 ± 2 s   | 0.1         |
    | bench2 | 0.2 ± 0.2 ms | 20 ± 20 μs | 10          |
    """
    @test truth ≈ create_table(combined_results)

    tempdir = mktempdir()
    results_fname = joinpath(tempdir, "results_TestPackage@v1.json")

    open(results_fname, "w") do io
        write(
            io,
            """{"tags":[],"data":{"findall":{"tags":[],"data":{"base": {"times":[1, 2, 3]},"xf-array":{"times":[5, 5, 5, 5, 5]},"xf-iter":{"times":[9, 9, 10, 11, 11]}}}}}""",
        )
    end

    original_stdout = stdout

    (rd, wr) = redirect_stdout()
    benchpkgtable("TestPackage"; rev="v1", input_dir=tempdir)
    redirect_stdout(original_stdout)

    close(wr)
    s = read(rd, String)

    truth = """
    |                  | v1        |
    |:-----------------|:---------:|
    | findall/base     | 2 ± 1 ns  |
    | findall/xf-array | 5 ± 0 ns  |
    | findall/xf-iter  | 10 ± 2 ns |"""

    @test truth ≈ s
end

@testset "Test Manifest.toml being used" begin
    # Ensure AirspeedVelocity-ManifestTest.jl has its Manifest.toml copied:
    # Test with CLI version:
    @test nothing === benchpkg(
        "AirspeedVelocity_ManifestTest";
        rev="main",
        url="https://github.com/Zentrik/AirspeedVelocity_ManifestTest",
        use_manifest=true
    )
end
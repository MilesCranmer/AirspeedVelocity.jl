using AirspeedVelocity
using Aqua
using Test

@testset "Aqua tests" begin
    Aqua.test_all(AirspeedVelocity)
end
@testset "AirspeedVelocity.jl" begin
    include("test_benchmark.jl")
end

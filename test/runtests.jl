using Test
using Preferences: set_preferences!

set_preferences!("AirspeedVelocity", "instability_check" => "warn")

using AirspeedVelocity

@testset "AirspeedVelocity.jl" begin
    include("test_benchmark.jl")
end

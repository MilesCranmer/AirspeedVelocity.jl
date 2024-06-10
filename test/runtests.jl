using Test
using Preferences: set_preferences!

set_preferences!(
    "AirspeedVelocity",
    "instability_check" => "error",
    "instability_check_codegen_level" => "min";
    force=true,
)

using AirspeedVelocity

@testset "AirspeedVelocity.jl" begin
    include("test_benchmark.jl")
end

using Test
using Preferences: set_preferences!

set_preferences!(
    "AirspeedVelocity",
    "instability_check" => "error",
    "instability_check_codegen_level" => "min",
    "instability_check_union_limit" => 2;
    force=true,
)

using AirspeedVelocity

@testset "AirspeedVelocity.jl" begin
    include("test_benchmark.jl")
end

module AirspeedVelocity

include("Utils.jl")
using .Utils: benchmark
export benchmark

include("BenchPkg.jl")
import .BenchPkg: benchpkg
export benchpkg

end # module AirspeedVelocity

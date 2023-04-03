module AirspeedVelocity

include("Utils.jl")
using .Utils: benchmark
export benchmark

include("BenchPkg.jl")
import .BenchPkg: benchpkg
export benchpkg

include("Plot.jl")
import .BenchPkgPlot: load_results, benchpkgplot, combined_plots
export load_results, benchpkgplot, combined_plots

end # module AirspeedVelocity

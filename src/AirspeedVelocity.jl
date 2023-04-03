module AirspeedVelocity

include("Utils.jl")
using .Utils: benchmark
export benchmark

include("PlotUtils.jl")
using .PlotUtils: load_results, combined_plots
export load_results, combined_plots

include("BenchPkg.jl")
import .BenchPkg: benchpkg
export benchpkg

include("BenchPkgPlot.jl")
import .BenchPkgPlot: benchpkgplot
export benchpkgplot

end # module AirspeedVelocity

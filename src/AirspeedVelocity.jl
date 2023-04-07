module AirspeedVelocity

include("Utils.jl")
using .Utils: benchmark, load_results 
export benchmark, load_results

include("PlotUtils.jl")
using .PlotUtils: combined_plots
export combined_plots

include("BenchPkg.jl")
import .BenchPkg: benchpkg
export benchpkg

include("BenchPkgPlot.jl")
import .BenchPkgPlot: benchpkgplot
export benchpkgplot

end # module AirspeedVelocity

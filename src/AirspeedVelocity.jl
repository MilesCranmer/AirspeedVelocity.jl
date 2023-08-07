module AirspeedVelocity

include("Utils.jl")
include("PlotUtils.jl")
include("BenchPkg.jl")
include("BenchPkgPlot.jl")
include("TableUtils.jl")
include("BenchPkgTable.jl")

import Reexport: @reexport

@reexport import .Utils: benchmark, load_results
@reexport import .PlotUtils: combined_plots
@reexport import .BenchPkg: benchpkg
@reexport import .BenchPkgPlot: benchpkgplot
@reexport import .TableUtils: create_table
@reexport import .BenchPkgTable: benchpkgtable

end # module AirspeedVelocity

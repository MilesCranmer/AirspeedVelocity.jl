module AirspeedVelocity

using DispatchDoctor: @stable, @unstable, register_macro!, DontPropagateMacro
using REPL: REPL

@stable default_mode = "disable" begin
    include("Utils.jl")
    using .Utils: benchmark, load_results
    export benchmark, load_results

    include("PlotUtils.jl")
    using .PlotUtils: combined_plots
    export combined_plots

    @unstable include("BenchPkg.jl")
    import .BenchPkg: benchpkg
    export benchpkg

    @unstable include("BenchPkgPlot.jl")
    import .BenchPkgPlot: benchpkgplot
    export benchpkgplot

    include("TableUtils.jl")
    import .TableUtils: create_table
    export create_table

    @unstable include("BenchPkgTable.jl")
    import .BenchPkgTable: benchpkgtable
    export benchpkgtable
end
end # module AirspeedVelocity

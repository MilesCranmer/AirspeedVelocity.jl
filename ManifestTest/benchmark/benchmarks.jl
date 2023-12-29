using Example, BenchmarkTools

@assert Example.ManifestTestPkg()

const SUITE = BenchmarkGroup()
function f()
    @assert Example.ManifestTestPkg()
end
SUITE["simple"] = @benchmarkable f()
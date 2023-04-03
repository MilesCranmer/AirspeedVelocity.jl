using AirspeedVelocity
using Documenter

DocMeta.setdocmeta!(
    AirspeedVelocity,
    :DocTestSetup,
    :(using AirspeedVelocity);
    recursive = true,
)

makedocs(;
    modules = [AirspeedVelocity],
    authors = "Miles Cranmer <miles.cranmer@gmail.com>",
    repo = "https://github.com/MilesCranmer/AirspeedVelocity.jl/blob/{commit}{path}#{line}",
    sitename = "AirspeedVelocity.jl",
    format = Documenter.HTML(;
        prettyurls = get(ENV, "CI", "false") == "true",
        canonical = "https://MilesCranmer.github.io/AirspeedVelocity.jl",
        edit_link = "master",
        assets = String[],
    ),
    pages = ["Home" => "index.md"],
)

deploydocs(; repo = "github.com/MilesCranmer/AirspeedVelocity.jl", devbranch = "master")

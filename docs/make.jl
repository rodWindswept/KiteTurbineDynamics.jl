using Documenter
using KiteTurbineDynamics

makedocs(;
    modules=[KiteTurbineDynamics],
    authors="Rod Read <rod@windswept.energy>",
    sitename="KiteTurbineDynamics.jl",
    format=Documenter.HTML(; prettyurls=get(ENV, "CI", "false") == "true"),
    pages=["Home" => "index.md", "API" => "api.md"],
    # The package has a large, mostly-undocumented public surface today.
    # warnonly keeps the build green while docstrings are filled in incrementally.
    warnonly=true,
)

# Uncomment and set the repo once a GitHub remote exists:
# deploydocs(;
#     repo      = "github.com/OWNER/KiteTurbineDynamics.jl",
#     devbranch = "main",
# )

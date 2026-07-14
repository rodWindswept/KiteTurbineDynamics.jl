# scripts/builders_util.jl — shim (promoted to src/builders_util.jl)
# All builder functions are now part of KiteTurbineDynamics.
# Existing `include("builders_util.jl")` calls keep working.
include(joinpath(@__DIR__, "..", "src", "builders_util.jl"))

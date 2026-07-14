# scripts/hunt_kmppt_bisect.jl — shim (promoted to src/control_map_hunt.jl)
# The ControlMapHunt module now lives in src/. Existing `include()` calls keep working.
include(joinpath(@__DIR__, "..", "src", "control_map_hunt.jl"))

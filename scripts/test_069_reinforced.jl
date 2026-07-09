#!/usr/bin/env julia
# Quick single-wind hunt + structural check for λ=0.69 Reinforced at 11 m/s.
using KiteTurbineDynamics, Printf
include(joinpath(@__DIR__, "hunt_kmppt_bisect.jl"))
using .ControlMapHunt
import KiteTurbineDynamics: SpokeParams

println("=== λ=0.69 Reinforced — Single-wind hunt + structural check, 11 m/s ===\n")

# Run a control map hunt at 11 m/s only, max power mode
OUT_DIR = joinpath(@__DIR__, "results", "control_maps")
mkpath(OUT_DIR)

ControlMapHunt.hunt_control_map(
    ControlMapHunt.v10_tight_builder(r_bottom_scale=1.30, tether_diameter=0.004, blade_scale=0.69),
    50000.0, [11.0];
    out_dir=OUT_DIR, name="gate1_069_reinforced_11ms", lift_device=nothing,
    verbose=true, max_power=true)

# Now read back the result and run structural
csv_path = joinpath(OUT_DIR, "gate1_069_reinforced_11ms_maxpower_summary.csv")
if isfile(csv_path)
    df = CSV.read(csv_path, DataFrame)
    println("\n--- Hunt result ---")
    println(df)
end

println("\nDone.")

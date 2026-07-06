#!/usr/bin/env julia
# Quick edge-expansion: one point at k=2.0 for R3
include(joinpath(@__DIR__, "hunt_kmppt_bisect.jl"))
using .ControlMapHunt
using KiteTurbineDynamics
using Printf

const OUT_DIR = joinpath(@__DIR__, "results", "control_maps")

lift = KiteTurbineDynamics.rotary_lifter_default()
builder_r3 = ControlMapHunt.v10_tight_builder(blade_scale=0.69)
wind = 15.0
k = 2.0

println("R3 edge expansion: k=$(k)")
println("  code_state: $(ControlMapHunt.GIT_HASH)")
t0 = time()
slices = ControlMapHunt.run_verify_timeseries(
    builder_r3, wind, k; verbose=false, lift_device=lift)
s = slices[end]
elapsed = round(time() - t0, digits=0)

@printf("  P=%.1f kW  ω=%.0f rpm  FoS=%.2f  cm=%.1f°  fail=%d/21  (%ds)\n",
    s.P_kw, s.ω_rpm, s.min_fos, s.collapse_margin_deg, s.n_failing, elapsed)

# Read existing CSV, find peak
csv_path = joinpath(OUT_DIR, "k_refine_R3.csv")
existing = [(k, s.P_kw)]
if isfile(csv_path)
    for line in eachline(csv_path)
        startswith(line, "#") && continue
        parts = split(line, ",")
        length(parts) >= 3 || continue
        kx = tryparse(Float64, parts[1])
        px = tryparse(Float64, parts[2])
        if kx !== nothing && px !== nothing && abs(kx - k) > 0.01
            push!(existing, (kx, px))
        end
    end
end

# Append
open(csv_path, "a") do io
    write(io, @sprintf("%.14f,%.14f,%.14f,%.14f,%.14f,%.14f,%.14f,%.14f,%d\n",
        k, s.P_kw, s.ω_rpm, s.min_fos, s.collapse_margin_deg,
        s.max_twist_deg, s.T_max_kN, s.P_aero_kw, s.n_failing))
end

# Find peak across all points
sort!(existing, by=x -> x[1])
println("\nR3 full sweep (all points):")
for (kx, px) in existing
    marker = abs(kx - k) < 0.01 ? " ← NEW" : ""
    println(@sprintf("  k=%.2f  P=%.1f kW%s", kx, px, marker))
end

i_peak = argmax([x[2] for x in existing])
k_peak, P_peak = existing[i_peak]
println(@sprintf("\n  → Peak at k=%.2f  P=%.1f kW", k_peak, P_peak))

if i_peak == 1
    println("  Peak at K_MIN=2.0 — floor reached, ACCEPTING.")
else
    println("  Peak interior — converged.")
end

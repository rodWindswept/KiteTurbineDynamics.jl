#!/usr/bin/env julia
# R2 edge expansion: Reinforced @ 15 m/s — peak at k_low=12.94, expand downward
include(joinpath(@__DIR__, "hunt_kmppt_bisect.jl"))
using .ControlMapHunt
using KiteTurbineDynamics
using Printf

const OUT_DIR = joinpath(@__DIR__, "results", "control_maps")

lift = KiteTurbineDynamics.rotary_lifter_default()
builder_r2 = ControlMapHunt.v10_tight_builder(
    r_bottom_scale=1.30, tether_diameter=0.004, blade_scale=1.0)
wind = 15.0

# Sample downward from 12.94: next grid point is 6.23, extend to 3.0
ks_new = [6.23, 3.0]  # grid points below

println("R2 edge expansion: Reinforced @ $(wind) m/s")
println("  code_state: $(ControlMapHunt.GIT_HASH)")

csv_path = joinpath(OUT_DIR, "k_refine_R2.csv")

for k in ks_new
    t0 = time()
    println("  k=$(k) …")
    slices = ControlMapHunt.run_verify_timeseries(
        builder_r2, wind, k; verbose=false, lift_device=lift)
    s = slices[end]
    elapsed = round(time() - t0, digits=0)
    @printf("  P=%.1f kW  ω=%.0f rpm  FoS=%.2f  cm=%.1f°  fail=%d/21  (%ds)\n",
        s.P_kw, s.ω_rpm, s.min_fos, s.collapse_margin_deg, s.n_failing, elapsed)

    open(csv_path, "a") do io
        write(io, @sprintf("%.14f,%.14f,%.14f,%.14f,%.14f,%.14f,%.14f,%.14f,%d\n",
            k, s.P_kw, s.ω_rpm, s.min_fos, s.collapse_margin_deg,
            s.max_twist_deg, s.T_max_kN, s.P_aero_kw, s.n_failing))
    end
end

# Read all points and find peak
all_pts = Tuple{Float64,Float64,Float64}[]
for line in eachline(csv_path)
    startswith(line, "#") && continue
    parts = split(line, ",")
    length(parts) >= 3 || continue
    kx = tryparse(Float64, parts[1])
    px = tryparse(Float64, parts[2])
    fx = tryparse(Float64, parts[4])
    if kx !== nothing && px !== nothing && fx !== nothing
        push!(all_pts, (kx, px, fx))
    end
end
sort!(all_pts, by=x -> x[1])

println("\nR2 full sweep:")
for (kx, px, fx) in all_pts
    println(@sprintf("  k=%.2f  P=%.1f kW  FoS=%.2f", kx, px, fx))
end

i_peak = argmax([x[2] for x in all_pts])
k_peak, P_peak, FoS_peak = all_pts[i_peak]
println(@sprintf("\n  → Peak at k=%.2f  P=%.1f kW  FoS=%.2f", k_peak, P_peak, FoS_peak))

if i_peak == 1
    println("  Peak at floor — expand further or accept")
else
    println("  Peak interior ✓")
end

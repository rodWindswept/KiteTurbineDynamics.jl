#!/usr/bin/env julia --project=.
#= preflight_length_clearance_betz.jl — pre-campaign feasibility sweep.
For each rung: is the mass_scale tether length actually viable?
  1. Hub height from L × sin(elev)
  2. Lowest-rotor tip ground clearance (ring z × sin(elev) − r_tip)
  3. Betz budget vs rated power (does the swept area deliver the rung?)
Run BEFORE choosing tether length / launching any rung campaign. =#

using KiteTurbineDynamics, Printf
include(joinpath(@__DIR__, "compute_seeds.jl"))

const ELEV = π / 6          # 30° — fixed in SystemParams
const V_RATED = 11.0        # m/s
const GROUND_OFFSET = 1.0   # m — bearing/ground station offset above deck

println("Pre-flight: length × clearance × Betz budget per rung")
println("─"^95)
println("Rung   Tether   Hub h   n_lines  r_rotor  lowest-ring  tip clearance  Betz budget  verdict")
println("─"^95)

for kw in [5.0, 7.0, 10.0, 15.0, 25.0, 35.0, 50.0]
    pw = kw * 1000.0
    p = mass_scale(params_10kw(), 10.0, kw)
    x = seed_genome(kw)
    n_lines = round(Int, clamp(x[8], 3, 16))

    # Rotor radius the BEM model requires for this power
    r_rotor = try
        KiteTurbineDynamics.BEM.rotor_radius_for_power(pw, V_RATED, n_lines)
    catch
        NaN
    end

    # Ring positions along the shaft (ground→hub)
    zs, radii, _ = ring_spacing_v4(
        x[5], x[6], p.tether_length, x[7]; density_profile=x[9])

    # Lowest ring with a rotor: assume ground-adjacent ring carries the
    # lowest expansion rotor; tip = ring height − rotor tip radius
    z_lowest = zs[1]
    tip_clearance = GROUND_OFFSET + z_lowest * sin(ELEV) - r_rotor

    # Betz budget: swept area of hub rotor at rated wind
    A_hub = π * r_rotor^2
    betz = 0.593 * 0.5 * p.rho * A_hub * V_RATED^3 / 1000.0

    hub_h = p.tether_length * sin(ELEV)
    problems = String[]
    tip_clearance < 2.0 && push!(problems, "LOW CLEARANCE")
    betz < 0.8 * kw && push!(problems, "BETZ < 0.8×target")
    isnan(r_rotor) && push!(problems, "BEM FAIL")
    verdict = isempty(problems) ? "✓" : "✗ " * join(problems, " + ")

    @printf("%3.0fkW  %6.1f m  %5.1f m   %4d   %6.2f   %7.2f     %8.2f      %7.1f    %s\n",
        kw, p.tether_length, hub_h, n_lines, r_rotor, z_lowest, tip_clearance, betz, verdict)
end
println("─"^95)
println("Hub height = L·sin(30°) (no bearing offset). Tip clearance = ground offset + z_lowest·sin(30°) − r_rotor.")

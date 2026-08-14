#!/usr/bin/env julia --project=.
#= preflight_winner.jl — run the length/clearance/Betz pre-flight on a
specific genome (default: 5kW campaign winner island_1_best.csv). =#

using KiteTurbineDynamics, Printf
include(joinpath(@__DIR__, "compute_seeds.jl"))

const ELEV = π / 6
const V_RATED = 11.0
const GROUND_OFFSET = 1.0

for (label, path, kw) in [
    ("5kW WINNER", joinpath(@__DIR__, "results", "v12_5kw_coldstart", "island_1_best.csv"), 5.0),
    ("5kW SEED",   nothing, 5.0),
]
    pw = kw * 1000.0
    p = mass_scale(params_10kw(), 10.0, kw)
    x = path !== nothing ?
        [parse(Float64, s) for s in split(strip(read(path, String)), ",")] :
        seed_genome(kw)
    n_lines = round(Int, clamp(x[8], 3, 16))
    x[10] = clamp(x[10], 0.0, Float64(N_VALID_MASKS))

    r_rotor = KiteTurbineDynamics.BEM.rotor_radius_for_power(pw, V_RATED, n_lines)
    dec = design_from_vector_v10(x, PROFILE_ELLIPTICAL, p; power_W=pw)
    zs = dec.zs

    z_low = Inf; r_tip_low = 0.0
    for rotor in dec.rotors
        zr = zs[clamp(rotor.ring_idx, 1, length(zs))]
        if zr < z_low
            z_low = zr
            r_tip_low = rotor.blade_tip_radius
        end
    end
    clearance = GROUND_OFFSET + z_low * sin(ELEV) - r_tip_low
    A_hub = π * r_rotor^2
    betz = 0.593 * 0.5 * p.rho * A_hub * V_RATED^3 / 1000.0

    println("$label:")
    @printf("  tether=%.1f m  hub_h=%.1f m  n_lines=%d  rings=%d  n_active=%d  r_hub=%.2f m\n",
        p.tether_length, p.tether_length*sin(ELEV), dec.design.n_lines,
        dec.n_rings, dec.n_active, dec.design.r_hub)
    @printf("  lowest active z=%.2f m  tip clearance=%.2f m  Betz=%.1f kW (%.1f× target)\n",
        z_low, clearance, betz, betz/kw)
    ok = clearance >= 2.0 && betz >= 0.8*kw
    println("  verdict: ", ok ? "✓ PASS" : "✗ FAIL", "\n")
end

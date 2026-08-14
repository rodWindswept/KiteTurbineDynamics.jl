#!/usr/bin/env julia --project=.
#= preflight2.jl — refined pre-flight: use the actual rotor mask decode to
find the lowest ACTIVE rotor ring, compute its tip clearance, and report
Betz budget. Corrects preflight_length_clearance_betz.jl's ground-ring
assumption. =#

using KiteTurbineDynamics, Printf
include(joinpath(@__DIR__, "compute_seeds.jl"))

const ELEV = π / 6
const V_RATED = 11.0
const GROUND_OFFSET = 1.0

println("Rung   Tether   Hub h   n_lines  r_rotor  rings  lowest active z  tip clearance  Betz  verdict")
println("─"^100)
for kw in [5.0, 7.0, 10.0, 15.0, 25.0]
    pw = kw * 1000.0
    p = mass_scale(params_10kw(), 10.0, kw)
    x = seed_genome(kw)
    n_lines = round(Int, clamp(x[8], 3, 16))
    x[10] = clamp(x[10], 0.0, Float64(N_VALID_MASKS))

    r_rotor = KiteTurbineDynamics.BEM.rotor_radius_for_power(pw, V_RATED, n_lines)

    dec = design_from_vector_v10(x, PROFILE_ELLIPTICAL, p; power_W=pw)
    zs = dec.zs
    rotors = dec.rotors

    # Lowest active rotor: the rotor whose ring is closest to ground.
    # RotorSpecV10 carries ring_idx (1-based into zs, ground→hub).
    z_lowest = Inf
    r_tip_low = 0.0
    for rotor in rotors
        zr = zs[clamp(rotor.ring_idx, 1, length(zs))]
        if zr < z_lowest
            z_lowest = zr
            r_tip_low = rotor.blade_tip_radius
        end
    end
    if z_lowest == Inf
        z_lowest = zs[1]
        r_tip_low = r_rotor
    end

    tip_clearance = GROUND_OFFSET + z_lowest * sin(ELEV) - r_tip_low
    A_hub = π * r_rotor^2
    betz = 0.593 * 0.5 * p.rho * A_hub * V_RATED^3 / 1000.0
    hub_h = p.tether_length * sin(ELEV)

    problems = String[]
    tip_clearance < 2.0 && push!(problems, "LOW CLEARANCE")
    betz < 0.8 * kw && push!(problems, "BETZ<0.8×")
    verdict = isempty(problems) ? "✓" : "✗ " * join(problems, " + ")

    @printf("%3.0fkW  %6.1f m  %5.1f m   %4d   %6.2f   %4d     %8.2f        %8.2f     %6.1f   %s\n",
        kw, p.tether_length, hub_h, n_lines, r_rotor, dec.n_rings, z_lowest,
        tip_clearance, betz, verdict)
end
println("─"^100)
println("Lowest active z = shaft position of the lowest rotor-bearing ring (0=ground, L=hub).")

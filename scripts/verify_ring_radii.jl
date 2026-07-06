#!/usr/bin/env julia
# scripts/verify_ring_radii.jl
# One-shot: build all three Gate 1 systems, print per-expansion-rotor geometry,
# recompute Mach at recorded Gate 1 ω values, and reconcile the handover's 1.2-1.7 claim.
#
# Output: machine-readable table for audit. No interpretation layer.

using Printf
include(joinpath(@__DIR__, "hunt_kmppt_bisect.jl"))
using .ControlMapHunt
using KiteTurbineDynamics: RingNode

const a_sound = 340.0

for (label, fn, gate1_omegas) in [
    ("V10 Tight λ=1.0",
     ControlMapHunt.v10_tight_builder(blade_scale=1.0),
     [104.6, 146.5, 189.5, 156.8, 185.6, 321.6]),   # Gate 1 ω_rpm per wind
    ("V10 Reinforced",
     ControlMapHunt.v10_tight_builder(r_bottom_scale=1.30, tether_diameter=0.004, blade_scale=1.0),
     [99.9, 137.3, 172.2, 158.3, 185.7, 213.0]),
    ("λ=0.69",
     ControlMapHunt.v10_tight_builder(blade_scale=0.69),
     [143.4, 176.7, 170.9, 207.0, 243.2, 279.5]),
]
    sys, u0, p, _ = Base.invokelatest(fn)

    println("\n" * "="^85)
    println("$label  n_rings=$(length(sys.ring_ids))  n_exp=$(length(sys.expansion_rotors))")
    println("="^85)

    # ── Per-expansion-rotor geometry ───────────────────────────────────
    println("  ring_idx  ring_radius  blade_span  r_tip  (RingNode.radius + 0.7*span)")
    r_tip_max = 0.0
    for er in sys.expansion_rotors
        ri = er.ring_idx
        nid = sys.ring_ids[ri]
        if nid === nothing || nid == 0
            println("  $ri  (no node)")
            continue
        end
        node = sys.nodes[nid]
        ring_r = (node::RingNode).radius
        span = er.blade_tip_radius - er.blade_hub_radius
        r_tip = ring_r + 0.7 * span
        if r_tip > r_tip_max
            r_tip_max = r_tip
        end
        @printf("  %8d  %11.3f  %10.4f  %6.3f\n", ri, ring_r, span, r_tip)
    end

    # ── Mach at recorded Gate 1 ω values ─────────────────────────────
    winds = [5, 7, 9, 11, 13, 15]
    println("\n  Wind  ω_rpm  ω_rad/s  Mach@r_tip_max=$(round(r_tip_max;digits=2))m")
    for (i, w) in enumerate(winds)
        ω_rpm = gate1_omegas[i]
        ω_rad = ω_rpm * 2π / 60
        mach = ω_rad * r_tip_max / a_sound
        @printf("  %4d  %6.1f   %7.3f   %.3f\n", w, ω_rpm, ω_rad, mach)
    end

    # Tripwire: reproduce handover claim of Mach 1.2-1.7 at 260-376 rpm
    ω_kref = [260.0, 376.0]  # approximate k-refinement range
    println("\n  Tripwire: handover claimed Mach 1.2-1.7 at 260-376 rpm")
    for ω in ω_kref
        mach = ω * (2π/60) * r_tip_max / a_sound
        @printf("  ω=%4.0f rpm  r_tip=%.2f  Mach=%.2f  expected 1.2-1.7 → %s\n",
            ω, r_tip_max, mach,
            (1.2 <= mach <= 1.7) ? "MATCH" : "MISMATCH")
    end
end
println()

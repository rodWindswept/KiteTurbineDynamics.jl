# scratch/diag_twist_saturation.jl
#
# Purpose (2026-09-13, DSH session): diagnose why the two non-seed cases in
# test_settle_preload_consistency.jl report `segment_twist_deg[1] == 90.00`
# EXACTLY.  `_matched_place_twist` (src/initialization.jl:1145) does
#
#     sinΔα = τ_carry · chord / (n_lines · T_s · r_a · r_b)
#     Δα    = asin(clamp(sinΔα, -1, 1))
#
# so a demanded sinΔα > 1 is silently truncated to the 90° collapse cliff.  That
# is the forbidden "silent truncation" pattern of physics-topology.md §6
# (`initialization.jl:987` is the same defect, recorded there).
#
# The test's gate is `segment_twist_deg[1] > 30.0`, which 90.0 passes — so the
# suite is green over a saturated state.  This probe measures the demand ratio
#
#     demand_1 = τ_gen · chord_1 / (n_lines · T_1 · r_a · r_b),   τ_gen = k·ω²
#
# for the BOTTOM segment (ring 1 is the ground/PTO ring, so segment 1 must carry
# the full generator load; expansion injections all sit above it).  demand > 1
# means the design point is past the torsional realisability cliff and the
# initialiser should RAISE, not clamp.
#
# Self-checking: asserts (a) the unwrapped twist equals π/2 for the cases it
# claims are saturated, and (b) `capture_extended.segment_torque[1]` reproduces
# the transmission law at the placed state — so the probe's own arithmetic is
# validated against the kernel instrument before its verdict is trusted.

using Test, KiteTurbineDynamics, LinearAlgebra

include(joinpath(@__DIR__, "..", "test", "test_settle_preload_consistency.jl"))

const CASES = [
    ("campaign seed  (nothing, nothing)", nothing, nothing),
    ("4 lines / 3 rotors  (4, 3.0)", 4, 3.0),
    ("6 lines / 1 rotor   (6, 1.0)", 6, 1.0),
]

println("\n=== segment-1 torsional demand vs the 90° cliff ===")
for (label, nl, rc) in CASES
    sys, pc, u, intended, ef = settled_case(nl, rc)
    N, Nr = sys.n_total, sys.n_ring
    n_lines = pc.n_lines

    alpha = u[(6N + 1):(6N + Nr)]
    ω = u[6N + Nr + 1]
    τ_gen = sys.k_mppt_ref[] * ω^2

    # Segment 1 geometry, exactly as `capture_extended.segment_torque` computes it
    # (the instrument fixed 2026-09-13), so this is the same chord law.
    ga, gb = sys.ring_ids[1], sys.ring_ids[2]
    na = sys.nodes[ga]::RingNode
    nb = sys.nodes[gb]::RingNode
    r_a = isempty(sys.expansion_rotors) ? na.radius : sys.effective_radii[1]
    r_b = isempty(sys.expansion_rotors) ? nb.radius : sys.effective_radii[2]
    ca = u[(3 * (ga - 1) + 1):(3 * ga)]
    cb = u[(3 * (gb - 1) + 1):(3 * gb)]
    sd = normalize(u[(3 * (sys.rotor.node_id - 1) + 1):(3 * sys.rotor.node_id)])
    L_ax = dot(cb .- ca, sd)
    dα = alpha[2] - alpha[1]                      # UNWRAPPED
    chord = sqrt(max(L_ax^2 + r_a^2 + r_b^2 - 2 * r_a * r_b * cos(dα), 1e-12))

    T1 = intended[1]                              # prescribed tension, per line
    τ_max = n_lines * T1 * r_a * r_b / chord      # sin Δα = 1
    demand = τ_gen / τ_max
    sin_demand = τ_gen * chord / (n_lines * T1 * r_a * r_b)

    # (b) validate the arithmetic against the kernel's own torque instrument.
    τ_measured = ef.segment_torque[1]
    τ_law = n_lines * ef.segment_tension[1] * r_a * r_b * sin(abs(dα)) / chord
    @assert isapprox(τ_measured, τ_law; rtol=1e-9) "probe arithmetic does not reproduce capture_extended"

    saturated = abs(sin_demand - 1.0) < 1e-9 || sin_demand > 1.0
    # (a) the claimed saturation must be visible as an exact 90° unwrapped step.
    saturated && @assert isapprox(dα, π / 2; atol=1e-9) "demand=$sin_demand but Δα=$(rad2deg(dα))° is not π/2"

    println("\n--- $label  (n_lines=$n_lines, n_ring=$Nr, n_exp=$(length(sys.expansion_rotors)))")
    println("    ω = ", round(ω; digits=4), " rad/s   τ_gen = k·ω² = ", round(τ_gen; digits=2), " N·m")
    println("    seg1: r_a = ", round(r_a; digits=3), " r_b = ", round(r_b; digits=3),
            "  L_ax = ", round(L_ax; digits=4), "  chord = ", round(chord; digits=4))
    println("    seg1: T_1 = ", round(T1; digits=2), " N/line   τ_max(sin=1) = ", round(τ_max; digits=2), " N·m")
    println("    seg1: demanded sinΔα = ", round(sin_demand; digits=4),
            "   →  Δα = ", round(rad2deg(dα); digits=4), "°")
    println("    VERDICT: ", saturated ?
        "*** SILENTLY SATURATED at the 90° cliff — demand exceeds realisability ***" :
        "within the cliff (sinΔα < 1)")
    println("    cross-check: capture_extended τ_1 = ", round(τ_measured; digits=2), " N·m")
end
println("\n=== done ===")

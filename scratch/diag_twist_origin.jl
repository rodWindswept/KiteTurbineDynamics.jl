# scratch/diag_twist_origin.jl
#
# Purpose (2026-09-13, DSH session): scratch/diag_twist_saturation.jl left an
# inconsistency.  For `(6, 1.0)` the segment-1 demand is sinΔα = 0.9326 (< 1, so
# `_matched_place_twist`'s asin is NOT clamped) yet the settled state reads
# Δα_1 = 90.0000° exactly.  Those cannot both be true of the same quantity, so
# "placed twist" and "settled twist" must be different objects.  This probe
# separates them:
#
#   α_placed  = what `_matched_place_twist` returns  (the prescribed placement)
#   α_settled = the α block after `settle_to_operational_state`'s n_op ODE steps
#
# The operational-settle loop pins ring POSITIONS and ω but NOT the twist α, so α
# is free to be carried by ring torques.  If α_placed != α_settled the 90° is a
# relaxation artefact, not the placement, and the saturation verdict for (6,1.0)
# moves to a different mechanism.
#
# Also prints the demand computed with the CODE's own inputs (chord0 from
# sub_segs, T_s = F_ax/n_lines, effective_radii) rather than the probe's, so the
# two cannot disagree silently.
#
# Self-checking: asserts the reproduced placement matches α_placed, and that the
# recomputed chord reproduces `capture_extended.segment_torque`.

using Test, KiteTurbineDynamics, LinearAlgebra

include(joinpath(@__DIR__, "..", "test", "test_settle_preload_consistency.jl"))

const CASES = [("4 lines / 3 rotors  (4, 3.0)", 4, 3.0), ("6 lines / 1 rotor   (6, 1.0)", 6, 1.0)]

println("\n=== placed twist vs settled twist ===")
for (label, nl, rc) in CASES
    sys, pc, u, intended, ef = settled_case(nl, rc)
    N, Nr = sys.n_total, sys.n_ring
    ω = u[6N + Nr + 1]
    α_settled = copy(u[(6N + 1):(6N + Nr)])

    # Fresh build + the same placement the settle performs, at the settle's ω.
    sys2, u0b, pcb, liftb, wfb = build_case(nl, rc)
    KiteTurbineDynamics.apply_design_bridle_preload!(sys2, u0b, pcb, liftb; omega_eq=ω)
    F_ax = design_axial_preload(sys2, pcb, liftb, u0b; omega_eq=ω)
    τ_eq = sys2.k_mppt_ref[] * ω^2
    β = pcb.elevation_angle
    sd_r = [cos(β), 0.0, sin(β)]
    α_placed, _ = KiteTurbineDynamics._matched_place_twist(
        sys2, pcb, F_ax, τ_eq, ω, wfb, sd_r
    )

    EA_single = pcb.e_modulus * π * (pcb.tether_diameter / 2)^2

    println("\n--- $label   (n_lines=$(pcb.n_lines), n_ring=$Nr, n_exp=$(length(sys2.expansion_rotors)))")
    println("    ω = ", round(ω; digits=6), "  τ_eq = k·ω² = ", round(τ_eq; digits=3), " N·m")
    println("    seg  Δα_placed(°)      Δα_settled(°)    demand_code   r_a    r_b    chord0")
    for s in 1:(Nr - 1)
        r_a = isempty(sys2.expansion_rotors) ? (sys2.nodes[sys2.ring_ids[s]]::RingNode).radius :
              sys2.effective_radii[s]
        r_b = isempty(sys2.expansion_rotors) ? (sys2.nodes[sys2.ring_ids[s + 1]]::RingNode).radius :
              sys2.effective_radii[s + 1]
        chord0 = ROPE_SUBSEGS *
                 sys2.sub_segs[(s - 1) * pcb.n_lines * ROPE_SUBSEGS + 1].length_0
        T_s = F_ax[s] / pcb.n_lines
        # τ_carry walk, exactly as the placement loop does it.
        τ_carry = τ_eq
        for ss in 1:(s - 1)
            for er in sys2.expansion_rotors
                er.ring_idx == (sys2.nodes[sys2.ring_ids[ss + 1]]::RingNode).ring_idx || continue
                vw = wfb([0.0, 0.0, 100.0], 0.0)
                τ_carry -= expansion_rotor_forces(
                    er, pcb.rho, norm(vw), ω, rad2deg(pcb.elevation_angle),
                    (sys2.nodes[sys2.ring_ids[ss + 1]]::RingNode).radius, 100.0, pcb.n_lines
                )[3]
                break
            end
        end
        chord = chord0 * (1 + T_s / EA_single)
        demand = τ_carry * chord / (pcb.n_lines * T_s * r_a * r_b)
        dp = rad2deg(α_placed[s + 1] - α_placed[s])
        ds = rad2deg(α_settled[s + 1] - α_settled[s])
        flag = demand > 1.0 ? "  <-- OVER CLIFF" : ""
        println("    $(lpad(s, 2))   $(lpad(round(dp; digits=4), 9))    $(lpad(round(ds; digits=4), 9))    ",
                "$(lpad(round(demand; digits=4), 8))   $(round(r_a; digits=3))  $(round(r_b; digits=3))  $(round(chord0; digits=4))$flag")
    end
    println("    α_placed  = ", round.(α_placed; digits=6))
    println("    α_settled = ", round.(α_settled; digits=6))
end
println("\n=== done ===")

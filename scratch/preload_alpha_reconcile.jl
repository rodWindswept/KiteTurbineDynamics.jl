# scratch/preload_alpha_reconcile.jl
#
# READ-ONLY. Reconciles three disagreeing numbers for the FIRST segment twist of
# the campaign seed, all of which are currently claimed in the committed record:
#
#   (a) `capture_extended(...).segment_twist_deg[1]` reported 51.94 deg
#       (handover 2026-09-11 §3.1 "NEW" column);
#   (b) a direct `_matched_place_twist(sys, p, design_axial_preload(...), ...)`
#       returns 90.00 deg, which is the asin-clamp CEILING;
#   (c) the alpha actually STORED in the settled state vector, which is what the
#       ODE and every downstream consumer sees.
#
# It also checks whether the torque balance is realisable at all: the closed form
# needs sin(dA) <= 1, i.e.
#     T_s >= tau * chord / (n_lines * r_a * r_b).
# If that fails, `asin(clamp(...))` returns 90 deg and the twist is a silent
# truncation -- structurally the same class of defect as the tau_carry<=0 no-op.
#
#   scripts/ktd-julia scratch/preload_alpha_reconcile.jl

using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "test", "test_settle_preload_consistency.jl"))

function main()
    sys, u0, p, lift, wf = build_case(nothing, nothing)
    N, Nr = sys.n_total, sys.n_ring
    n_seg = Nr - 1

    u = settle_to_operational_state(sys, u0, p, 60.0;
        lift_device=lift, wind_fn=wf, n_op=2_000)

    omega_state = u[6N + Nr + 1]
    k = sys.k_mppt_ref[]
    τ_eq = k * omega_state^2
    @printf("k_mppt_ref = %.9f   omega_state[1] = %.9f   tau_eq = %.9f\n", k, omega_state, τ_eq)
    @printf("K_MPPT_5KW_HONEST = %.9f\n", K_MPPT_5KW_HONEST)

    # (c) what the state actually holds
    alpha_state = collect(u[(6N + 1):(6N + Nr)])
    @printf("\n(c) alpha STORED in the settled state (deg):\n    %s\n",
        join([@sprintf("%8.3f", rad2deg(a)) for a in alpha_state], ""))

    # (a) what capture_extended reports
    ef = KiteTurbineDynamics.capture_extended(u, sys, p, 0.0, wf, lift)
    @printf("\n(a) capture_extended segment_twist_deg (WRAPPED to (-180,180]):\n    %s\n",
        join([@sprintf("%8.3f", t) for t in ef.segment_twist_deg], ""))

    # (b) what a direct call returns now, with the function's own inputs
    F = design_axial_preload(sys, p, lift)
    sd = [cos(p.elevation_angle), 0.0, sin(p.elevation_angle)]
    alpha_calc, _ = KiteTurbineDynamics._matched_place_twist(sys, p, F, τ_eq, omega_state, wf, sd)
    @printf("\n(b) _matched_place_twist(design_axial_preload, tau_eq=%.6f) (deg):\n    %s\n",
        τ_eq, join([@sprintf("%8.3f", rad2deg(a)) for a in alpha_calc], ""))

    # does the stored alpha match the direct call? (sanity: same tau_eq?)
    @printf("\n    max|alpha_state - alpha_calc| = %.6e rad\n",
        maximum(abs.(alpha_state .- alpha_calc)))

    # what tau_eq would the stored alpha imply?
    @printf("    stored sum(alpha) = %.4f deg ; direct sum = %.4f deg\n",
        rad2deg(sum(alpha_state)), rad2deg(sum(alpha_calc)))

    # ── realisability floor, per segment ────────────────────────────────────────
    EA = p.e_modulus * π * (p.tether_diameter / 2)^2
    println("\nRealisability: sin(dA) = tau*chord/(n_lines*T_s*r_a*r_b) must be <= 1")
    @printf("  %4s %10s %10s %10s %12s %12s %10s\n",
        "seg", "r_a", "r_b", "T_s_N", "chord_m", "sin(dA)", "verdict")
    for s in 1:n_seg
        ga, gb = sys.ring_ids[s], sys.ring_ids[s + 1]
        ra = isempty(sys.expansion_rotors) ? (sys.nodes[ga]::RingNode).radius :
             sys.effective_radii[s]
        rb = isempty(sys.expansion_rotors) ? (sys.nodes[gb]::RingNode).radius :
             sys.effective_radii[s + 1]
        chord0 = ROPE_SUBSEGS *
                 sys.sub_segs[(s - 1) * p.n_lines * ROPE_SUBSEGS + 1].length_0
        Ts = F[s] / p.n_lines
        chord = chord0 * (1 + Ts / EA)
        sinv = τ_eq * chord / (p.n_lines * Ts * ra * rb)
        @printf("  %4d %10.5f %10.5f %10.3f %12.6f %12.6f %10s\n",
            s, ra, rb, Ts, chord, sinv, sinv > 1.0 ? "CLAMPED" : "ok")
    end

    # the minimum tension that WOULD be realisable on seg 1
    ga = sys.ring_ids[1]
    ra1 = isempty(sys.expansion_rotors) ? (sys.nodes[ga]::RingNode).radius :
          sys.effective_radii[1]
    gb = sys.ring_ids[2]
    rb1 = isempty(sys.expansion_rotors) ? (sys.nodes[gb]::RingNode).radius :
          sys.effective_radii[2]
    chord01 = ROPE_SUBSEGS * sys.sub_segs[1].length_0
    T_floor1 = τ_eq * chord01 / (p.n_lines * ra1 * rb1)
    @printf("\n  seg 1 needs T_s >= %.3f N for sin(dA) <= 1; design has %.3f N (%.1f%%)\n",
        T_floor1, F[1] / p.n_lines, 100 * (F[1] / p.n_lines) / T_floor1)
    println()
end

main()

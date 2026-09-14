# scratch/diag_reseed_chain.jl
#
# Purpose (2026-09-13, DSH session): scratch/derive_lift_chain_constants.jl showed
# the lift-chain DESIGN constants are radius-independent (bearing offset 3.9898 m
# for the old seed vs 3.9897 m for the candidate) and that the candidate's bridle
# chain is TAUT (430.2 N) after `settle_to_equilibrium`.  Yet
# `settle_to_operational_state` with the candidate reports bridle = 0.000 N.
#
# So the disconnection happens inside the OPERATIONAL settle, not from the
# constants.  This probe measures the chain at each stage of that path for the
# candidate, to localise it:
#   (1) the design split `lift_chain_design`  -> T_cyan, T_bridle, gap, cosθ
#   (2) the cut bridle rest lengths           -> L0 vs the design gap
#   (3) after `settle_to_operational_state`   -> achieved bridle tension
#
# Self-checking: asserts the design split is finite and that T_bridle > 0 before
# interpreting the achieved tension (a zero T_bridle would mean the clamp, not a
# settle problem).

using Test, KiteTurbineDynamics, LinearAlgebra
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "test", "settle_case_builders.jl"))

const NEW_SEED = [2.6, 0.5751086853804245, 2.0, 6.0, 0.0, 3.0, 11.0, 11.0, 0.8, 0.8]

function build_for(x10)
    p = params_5kw_188()
    x = copy(x10)
    x[4] = Float64(round(Int, clamp(x[4], 3, 16)))
    x[6] = Float64(round(Int, clamp(x[6], 1, 3)))
    dec = KiteTurbineDynamics.design_from_vector_v10(x, PROFILE_ELLIPTICAL, p;
        power_W=5000.0, cylinder_cone=true, rotor_count_mode=true, power_split=0.6,
        cone_slope_deg=22.0, rotor_spacing_frac=0.8,
        blocking_factor=BLOCKING_WIND_FACTOR_5KW)
    cfg = ObjectiveConfig(; power_W=5000.0, v_rated=11.0, p_floor_kw=5.0,
        p_ceiling_kw=5.0, fos_target=2.5, fos_hard=2.5, min_wall_m=2e-3,
        t_over_D=0.055, rotor_count_mode=true, power_split=0.6,
        blocking_factor=BLOCKING_WIND_FACTOR_5KW, k_mppt=K_MPPT_5KW_HONEST)
    sizing = size_beams_closed_form(dec, p, cfg)
    sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(dec, 1.0,
        K_MPPT_5KW_HONEST; tether_diameter=p.tether_diameter, base_params=p,
        min_wall_m=2e-3, beam_sizing=sizing)
    sys.k_mppt_ref[] = K_MPPT_5KW_HONEST
    lift = sized_lifter_for(sys, pc; margin=1.5, v_ref=11.0, const_tension=true)
    wf = (r, t) -> [11.0 * (max(r[3], 1.0) / p.h_ref)^(1 / 7), 0.0, 0.0]
    return sys, u0, pc, lift, wf
end

pos(u, gid) = u[(3 * (gid - 1) + 1):(3 * gid)]

function bridle_total(u, sys, p, N, Nr)
    hub, bear = sys.rotor.node_id, sys.bearing_id
    pp1, pp2 = KiteTurbineDynamics._tilted_ring_basis(u, sys, hub, Nr)
    node = sys.nodes[hub]::RingNode
    R = isempty(sys.expansion_rotors) ? node.radius : sys.effective_radii[node.ring_idx]
    tot = 0.0
    for ss in sys.sub_segs
        na, nb = ss.end_a.node_id, ss.end_b.node_id
        ((na == hub && nb == bear) || (na == bear && nb == hub)) || continue
        ring_end = ss.end_a.is_ring ? ss.end_a : ss.end_b
        pa = attachment_point(pos(u, hub), R, u[6N + Nr], ring_end.line_idx,
                              p.n_lines, pp1, pp2)
        L = norm(pos(u, bear) .- pa)
        tot += ss.EA * max(0.0, (L - ss.length_0) / ss.length_0)
    end
    return tot, R
end

for (name, x10) in (("OLD (control)", [2.4, 0.5751086853804245, 2.0, 6.0, 0.0, 3.0, 0.0, 0.0, 0.7, 0.7]),
                    ("NEW (candidate)", NEW_SEED))
    sys, u0, pc, lift, wf = build_for(x10)
    N, Nr = sys.n_total, sys.n_ring
    hub_i = sys.rotor.node_id
    hub_pos = pos(u0, hub_i)

    ω = 12.983466
    d = KiteTurbineDynamics.lift_chain_design(sys, pc, lift, hub_pos; omega_eq=ω)
    @assert isfinite(d.T_bridle) && isfinite(d.gap)
    @assert d.T_bridle > 0.0 "T_bridle clamped to 0 — that alone would explain a slack cone"

    # Cut the bridles, then read back what L0 the code chose vs the design gap.
    KiteTurbineDynamics.apply_design_bridle_preload!(sys, u0, pc, lift; omega_eq=ω)
    L0s = Float64[]
    for ss in sys.sub_segs
        na, nb = ss.end_a.node_id, ss.end_b.node_id
        ((na == hub_i && nb == sys.bearing_id) || (na == sys.bearing_id && nb == hub_i)) || continue
        push!(L0s, ss.length_0)
    end

    u = settle_to_operational_state(sys, copy(u0), pc, 60.0;
        lift_device=lift, wind_fn=wf, n_op=2_000)
    br, R = bridle_total(u, sys, pc, N, Nr)
    sh = [cos(pc.elevation_angle), 0.0, sin(pc.elevation_angle)]
    off = dot(pos(u, sys.bearing_id) .- pos(u, hub_i), sh)
    cy = norm(pos(u, sys.sky_anchor_id) .- pos(u, sys.bearing_id))

    println("\n--- ", name, "  (r_hub=", round(R; digits=3), " m, n_rings=", Nr, ")")
    println("    (1) design split: T_cyan=", round(d.T_cyan; digits=1),
            " N  T_bridle=", round(d.T_bridle; digits=1),
            " N/line  gap=", round(d.gap; digits=4), " m  cosθ=", round(d.cosθ; digits=4))
    println("    (2) cut bridle L0 = ", length(L0s) == 0 ? "NONE FOUND" :
            string(round(minimum(L0s); digits=4), " .. ", round(maximum(L0s); digits=4)),
            " (n=", length(L0s), ")  vs design gap ", round(d.gap; digits=4))
    println("    (3) after operational settle: bridle=", round(br; digits=2),
            " N   bearing offset=", round(off; digits=4), " m   cyan=", round(cy; digits=4), " m")
end
println("\n=== done ===")

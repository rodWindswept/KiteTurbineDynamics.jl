# scratch/diag_lift_line_switch.jl
#
# Purpose (2026-09-14, DSH session): the re-seed candidate
#   [2.6, 0.5751, 2.0, 6.0, 0.0, 3.0, 11.0, 11.0, 0.8, 0.8]
# disconnects the lift chain during `settle_to_operational_state`: bridle tension
# ends at 0.000 N and the cyan line ends 0.23 m SHORTER than its own rest length,
# so the sky anchor has fallen.  The proposed cause - the lift line's hard on/off
# switch in `src/ring_forces.jl` (the lift force is applied only while the kite is
# at least 99% of the line length away from the sky anchor, and ZERO otherwise) -
# was NOT measured.  This probe measures it.
#
# Method: `settle_to_operational_state` takes its relaxation length as a parameter
# (`n_op`), so calling it with growing values gives a trajectory through the SAME
# settle with no re-implementation and no physics change.  At each point we read:
#   * the sky anchor's height projected on the shaft axis,
#   * the kite-to-sky-anchor distance against the 0.99 x line-length threshold,
#   * whether the lift line is therefore engaged,
#   * the bridle tension.
#
# Self-checking: asserts the state is finite at every point, and that the longest
# relaxation reproduces the bridle tension measured independently by
# `test/test_settle_validity.jl` (0.000 N) - so the trajectory is the real settle.

using Test, KiteTurbineDynamics, LinearAlgebra
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "test", "settle_case_builders.jl"))

const OLD_SEED = [2.4, 0.5751086853804245, 2.0, 6.0, 0.0, 3.0, 0.0, 0.0, 0.7, 0.7]
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
    return tot
end

println("\n=== lift-line switch through the operational settle ===")
for (name, x10) in (("OLD (control, bank 0)", OLD_SEED), ("NEW (candidate, bank 11)", NEW_SEED))
    println("\n--- ", name)
    println("    n_op     sky offset   |kite-sky|   0.99*L   lift on?   bridle")
    for n_op in (0, 50, 200, 500, 1000, 2000)
        sys, u0, pc, lift, wf = build_for(x10)
        N, Nr = sys.n_total, sys.n_ring
        u = settle_to_operational_state(sys, copy(u0), pc, 60.0;
            lift_device=lift, wind_fn=wf, n_op=n_op)
        @assert all(isfinite, u) "non-finite state at n_op=$n_op"
        sh = [cos(pc.elevation_angle), 0.0, sin(pc.elevation_angle)]
        sky_off = dot(pos(u, sys.sky_anchor_id) .- pos(u, sys.rotor.node_id), sh)
        d = norm(pos(u, sys.kite.node_id) .- pos(u, sys.sky_anchor_id))
        thr = 0.99 * lift.line_length
        br = bridle_total(u, sys, pc, N, Nr)
        println("    ", lpad(n_op, 5), "   ", lpad(round(sky_off; digits=4), 9),
                "   ", lpad(round(d; digits=4), 9), "   ", lpad(round(thr; digits=4), 8),
                "   ", lpad(d >= thr ? "YES" : "no", 7), "   ", round(br; digits=2))
    end
end
println("\n=== done ===")

# scratch/hermes_probe_divergence.jl
#
# INDEPENDENT REVIEW PROBE (Hermes, 2026-09-14).  Not part of the DSH work.
#
# Question.  Handover 2026-09-14 section 6.4 reports that the re-seed candidate's
# lift chain strengthens up to 1000 relaxation steps (bridle 646 N) and then
# "collapses between 1000 and 2000 steps" (bridle 0.000 N, sky anchor down
# 0.25 m).  It calls this "a LATE DIVERGENCE in the relaxation".
#
# Two readings are possible and they lead to different work:
#   (a) PHYSICAL: the chain creeps out of equilibrium, so the settle needs a real
#       equilibrium solve (the recorded priority item 1).
#   (b) NUMERICAL: the operational settle steps explicitly with
#       `dt = stable_dt_for_system(sys, p)`, which is derived ONLY from the
#       shortest rope SUB-SEGMENT length.  It does not evaluate the 0.3 kg
#       bearing (mass 0.3) and sky-anchor nodes hanging on 500 kN/m lines with
#       500 N.s/m dampers, whose stability limit is a separate and much tighter
#       number.  A few steps of blow-up would look exactly like a "late
#       divergence" in a coarse n_op scan.
#
# Method.  `settle_to_operational_state` takes its relaxation length as a
# parameter, so a scan in `n_op` walks ONE trajectory (the loop is a fixed point
# iteration over the same code path).  This probe walks it finely between 1000
# and 2000 steps and prints the sky-anchor offset, the bridle tension, and the
# largest node speed.  A blow-up inside a few steps means (b).  A smooth decay
# over hundreds of steps means (a).

using Test, KiteTurbineDynamics, LinearAlgebra
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "test", "settle_case_builders.jl"))

const NEW_SEED = [2.6, 0.5751086853804245, 2.0, 6.0, 0.0, 3.0, 11.0, 11.0, 0.8, 0.8]

function build_for(x10)
    p = params_5kw_188()
    x = copy(x10)
    dec = KiteTurbineDynamics.design_from_vector_v10(
        x,
        PROFILE_ELLIPTICAL,
        p;
        power_W=5000.0,
        cylinder_cone=true,
        rotor_count_mode=true,
        power_split=0.6,
        cone_slope_deg=22.0,
        rotor_spacing_frac=0.8,
        blocking_factor=BLOCKING_WIND_FACTOR_5KW,
    )
    cfg = ObjectiveConfig(;
        power_W=5000.0,
        v_rated=11.0,
        p_floor_kw=5.0,
        p_ceiling_kw=5.0,
        fos_target=2.5,
        fos_hard=2.5,
        min_wall_m=2e-3,
        t_over_D=0.055,
        rotor_count_mode=true,
        power_split=0.6,
        blocking_factor=BLOCKING_WIND_FACTOR_5KW,
        k_mppt=K_MPPT_5KW_HONEST,
    )
    sizing = size_beams_closed_form(dec, p, cfg)
    sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(
        dec,
        1.0,
        K_MPPT_5KW_HONEST;
        tether_diameter=p.tether_diameter,
        base_params=p,
        min_wall_m=2e-3,
        beam_sizing=sizing,
    )
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
        pa = attachment_point(
            pos(u, hub), R, u[6N + Nr], ring_end.line_idx, p.n_lines, pp1, pp2
        )
        L = norm(pos(u, bear) .- pa)
        tot += ss.EA * max(0.0, (L - ss.length_0) / ss.length_0)
    end
    return tot
end

"Largest node speed, and the speed of the light lift-chain nodes on their own."
function speeds(u, sys, N)
    v = [norm(u[(3N + 3 * (g - 1) + 1):(3N + 3 * g)]) for g in 1:N]
    return maximum(v), v[sys.bearing_id], v[sys.sky_anchor_id]
end

println("\n=== the candidate's settle trajectory, walked finely in n_op ===")
println("  n_op | sky offset | bridle N | max speed | bearing v | sky v | cyan len")
for n_op in (0, 800, 1000, 1100, 1200, 1300, 1400, 1600, 1800, 2000)
    sys, u0, pc, lift, wf = build_for(NEW_SEED)
    N, Nr = sys.n_total, sys.n_ring
    u = settle_to_operational_state(
        sys, copy(u0), pc, 60.0; lift_device=lift, wind_fn=wf, n_op=n_op
    )
    @assert all(isfinite, u) "non-finite state at n_op=$n_op"
    sh = [cos(pc.elevation_angle), 0.0, sin(pc.elevation_angle)]
    sky_off = dot(pos(u, sys.sky_anchor_id) .- pos(u, sys.rotor.node_id), sh)
    br = bridle_total(u, sys, pc, N, Nr)
    vmax, vb, vs = speeds(u, sys, N)
    # cyan (sky <-> bearing) length
    cl = 0.0
    for ss in sys.sub_segs
        na, nb = ss.end_a.node_id, ss.end_b.node_id
        if (na == sys.sky_anchor_id && nb == sys.bearing_id) ||
            (na == sys.bearing_id && nb == sys.sky_anchor_id)
            cl = norm(pos(u, ss.end_b.node_id) .- pos(u, ss.end_a.node_id))
        end
    end
    println(
        "  ",
        lpad(n_op, 4),
        " | ",
        lpad(round(sky_off; digits=4), 10),
        " | ",
        lpad(round(br; digits=2), 8),
        " | ",
        lpad(round(vmax; digits=4), 9),
        " | ",
        lpad(round(vb; digits=4), 9),
        " | ",
        lpad(round(vs; digits=4), 5),
        " | ",
        round(cl; digits=4),
    )
end

println("\n  dt actually used by the settle:")
sys, _, pc, _, _ = build_for(NEW_SEED)
println("  stable_dt_for_system = ", KiteTurbineDynamics.stable_dt_for_system(sys, pc))
println(
    "  bridle EA = ",
    sys.sub_segs[end - pc.n_lines].EA,
    ", bearing mass = ",
    (sys.nodes[sys.bearing_id]).mass,
    " -> k/L mode estimate:",
)
EA = sys.sub_segs[end - pc.n_lines].EA
L0 = sys.sub_segs[end - pc.n_lines].length_0
m = (sys.nodes[sys.bearing_id]).mass
k_cyan = 500_000.0 / 5.0
k_bridle = pc.n_lines * (EA / L0)
w_eff = sqrt((k_cyan + k_bridle) / m)
println(
    "  k_cyan = ",
    round(k_cyan; digits=1),
    "  k_bridle_total = ",
    round(k_bridle; digits=1),
    "  omega_eff = ",
    round(w_eff; digits=1),
    " rad/s  ->  explicit-Euler dt limit ~ ",
    round(2.0 / w_eff; sigdigits=3),
    " s",
)
println("\n=== done ===")

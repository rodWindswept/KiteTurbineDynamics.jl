# scratch/hermes_probe_backline_diff.jl
#
# INDEPENDENT REVIEW PROBE (Hermes, 2026-09-14).  Not part of the DSH work.
#
# Differential test.  `scratch/hermes_probe_backline.jl` showed that the back
# line's tension-only gate (`b_dist > back_L0 + 1e-6`, ring_forces.jl:541) closes
# during the CANDIDATE's operational settle at n_op ~ 1300-1700 with the shipped
# bearing_offset (3.99), and never closes with the pre-commit value (6.0).  The
# candidate's bridle cone collapses to 0.000 N over exactly those steps.
#
# A coincidence in time is not causation.  This probe prints the same end state
# twice so the two runs can be compared with only the ONE constant changed:
#
#   run 1: src/ring_forces.jl bearing_offset = BEARING_OFFSET_DESIGN  (3.99)
#   run 2: src/ring_forces.jl bearing_offset = 6.0                    (pre-commit)
#
# If the chain holds at 6.0 and collapses at 3.99, the rest-length change caused
# it.  If it collapses at both, the back line is exonerated.

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

function chain(u, sys, p, N, Nr)
    hub, bear, sky = sys.rotor.node_id, sys.bearing_id, sys.sky_anchor_id
    pp1, pp2 = KiteTurbineDynamics._tilted_ring_basis(u, sys, hub, Nr)
    node = sys.nodes[hub]::RingNode
    R = isempty(sys.expansion_rotors) ? node.radius : sys.effective_radii[node.ring_idx]
    br = 0.0
    for ss in sys.sub_segs
        na, nb = ss.end_a.node_id, ss.end_b.node_id
        ((na == hub && nb == bear) || (na == bear && nb == hub)) || continue
        re = ss.end_a.is_ring ? ss.end_a : ss.end_b
        pa = attachment_point(pos(u, hub), R, u[6N + Nr], re.line_idx, p.n_lines, pp1, pp2)
        br += ss.EA * max(0.0, (norm(pos(u, bear) .- pa) - ss.length_0) / ss.length_0)
    end
    cy = 0.0
    for ss in sys.sub_segs
        na, nb = ss.end_a.node_id, ss.end_b.node_id
        ((na == sky && nb == bear) || (na == bear && nb == sky)) || continue
        cy =
            ss.EA *
            max(0.0, (norm(pos(u, sky) .- pos(u, bear)) - ss.length_0) / ss.length_0)
    end
    return br, cy
end

println("\n=== candidate settle: chain state vs the back-line constant ===")
println("   n_op | sky offset | bridle N | cyan N | cyan len")
for n_op in (1000, 1400, 2000)
    sys, u0, pc, lift, wf = build_for(NEW_SEED)
    N, Nr = sys.n_total, sys.n_ring
    u = settle_to_operational_state(
        sys, copy(u0), pc, 60.0; lift_device=lift, wind_fn=wf, n_op=n_op
    )
    sh = [cos(pc.elevation_angle), 0.0, sin(pc.elevation_angle)]
    sky_off = dot(pos(u, sys.sky_anchor_id) .- pos(u, sys.rotor.node_id), sh)
    br, cy = chain(u, sys, pc, N, Nr)
    cl = norm(pos(u, sys.sky_anchor_id) .- pos(u, sys.bearing_id))
    println(
        "  ",
        lpad(n_op, 5),
        " | ",
        lpad(round(sky_off; digits=4), 10),
        " | ",
        lpad(round(br; digits=2), 8),
        " | ",
        lpad(round(cy; digits=2), 6),
        " | ",
        round(cl; digits=4),
    )
end
back_ax = nothing
println("\n=== done ===")

# scratch/hermes_probe_backline.jl
#
# INDEPENDENT REVIEW PROBE (Hermes, 2026-09-14).  Not part of the DSH work.
#
# Finding under test.  Commit 039a44f changed, in `src/ring_forces.jl:521`,
#
#     bearing_offset = 6.0      ->   bearing_offset = BEARING_OFFSET_DESIGN  (3.99)
#
# The back line's design rest length is built from that number:
#
#     L_axis_design   = tether_length + bearing_offset + cyan_L0
#     back_L0_design  = |design sky position - back anchor|
#     back_L0         = back_L0_design + payout
#
# so the commit SHORTENED the back-line rest length by ~2 m along the shaft.  The
# back line is TENSION-ONLY and gated on `b_dist > back_L0 + 1e-6`
# (ring_forces.jl:541).  A shorter rest length moves the gate from "slack by
# ~1 m" onto the boundary, so the back line can now engage during the settle and
# pull the sky anchor DOWN — which is the signature the DSH measured for the
# candidate (sky -0.25 m, cyan line 4.7675 m against its 5.0 m rest length,
# bridle 0.000 N).
#
# This probe prints the gate margin through the settle for both machines, at both
# constants, so the difference is measured rather than argued.

using Test, KiteTurbineDynamics, LinearAlgebra
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "test", "settle_case_builders.jl"))

const OLD_SEED = [2.4, 0.5751086853804245, 2.0, 6.0, 0.0, 3.0, 0.0, 0.0, 0.7, 0.7]
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

"Back-line gate margin `b_dist - back_L0` for a given bearing_offset constant."
function backline_margin(u, sys, p, bearing_offset; cyan_L0=5.0)
    back_ax = p.tether_length * cos(p.elevation_angle) + p.back_anchor_fwd_x
    sky = pos(u, sys.sky_anchor_id)
    b_dx = sqrt((sky[1] - back_ax)^2 + sky[2]^2)
    b_dz = sky[3]
    b_dist = sqrt(b_dx^2 + b_dz^2)
    L_axis_design = p.tether_length + bearing_offset + cyan_L0
    dsx = L_axis_design * cos(p.elevation_angle)
    dsz = L_axis_design * sin(p.elevation_angle)
    back_L0_design = sqrt((dsx - back_ax)^2 + dsz^2)
    back_L0 = back_L0_design + p.backline_payout
    return b_dist - back_L0, b_dist, back_L0
end

println("\n=== back-line gate through the settle (margin > 0 => TAUT => force applied) ===")
for (name, x10) in
    (("OLD (control, bank 0)", OLD_SEED), ("NEW (candidate, bank 11)", NEW_SEED))
    println("\n--- ", name)
    println("   n_op | sky offset | margin @3.99 (shipped) | margin @6.00 (pre-commit)")
    for n_op in (0, 1000, 1200, 1400, 1600, 1800, 2000)
        sys, u0, pc, lift, wf = build_for(x10)
        N, Nr = sys.n_total, sys.n_ring
        u = settle_to_operational_state(
            sys, copy(u0), pc, 60.0; lift_device=lift, wind_fn=wf, n_op=n_op
        )
        @assert all(isfinite, u) "non-finite state at n_op=$n_op"
        sh = [cos(pc.elevation_angle), 0.0, sin(pc.elevation_angle)]
        sky_off = dot(pos(u, sys.sky_anchor_id) .- pos(u, sys.rotor.node_id), sh)
        m_new, _, L_new = backline_margin(u, sys, pc, 3.99)
        m_old, _, L_old = backline_margin(u, sys, pc, 6.0)
        println(
            "  ",
            lpad(n_op, 5),
            " | ",
            lpad(round(sky_off; digits=4), 10),
            " | ",
            lpad(round(m_new; digits=5), 10),
            m_new > 1e-6 ? " TAUT" : " slack",
            " | ",
            lpad(round(m_old; digits=5), 10),
            m_old > 1e-6 ? " TAUT" : " slack",
        )
    end
end
println("\n=== done ===")

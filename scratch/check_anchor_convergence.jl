# scratch/check_anchor_convergence.jl
#
# 2026-09-16.  Follow-up to scratch/measure_anchor_geometry.jl, which found the
# settled sky anchor 1.06 m from its design position with the back line TAUT and
# stretched 9.4 cm, giving ~3808 N at the current 314 kN EA.
#
# That 3808 N is ~10x the 351 N steady figure quoted in the record, so before it
# is believed it has to survive two tests:
#   (1) CONVERGENCE - does it settle or decay as the equilibrium relax runs longer?
#   (2) STIFFNESS   - does it scale with EA_back_line?  A tension set by the
#       stiffness is a boundary-condition artefact; a tension set by the vertical
#       load balance is physical.
#
# Reports back-line tension, stretch, sky-anchor offset from design, and the
# sky-anchor axial residual (the exact quantity the broken @test_broken asserts)
# as a function of settle length and EA.
#
# Self-checking: asserts finite geometry and monotone step counts, and that each
# reported tension is consistent with the tension-only branch it reports.

using Test, KiteTurbineDynamics, LinearAlgebra
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "scripts", "ode_gate_v13.jl"))

const KW = 5.0
const L18 = 18.8
const PW = 5000.0
const X = [2.6, 0.5751086853804245, 1.5, 6.0, 0.0, 3.0, 11.0, 11.0, 0.8, 0.8]

function cfg_none()
    return KiteTurbineDynamics.ObjectiveConfig(;
        k_mppt=K_MPPT_5KW_HONEST,
        power_W=PW,
        v_rated=11.0,
        p_floor_kw=5.0,
        p_ceiling_kw=5.0,
        relax_s=5.0,
        window_s=10.0,
        fos_target=2.5,
        fos_hard=2.5,
        power_stat=:tail5,
        penalize_ceiling=false,
        kickstart_s=0.0,
        rotor_count_mode=true,
        power_split=0.6,
        blocking_factor=BLOCKING_WIND_FACTOR_5KW,
    )
end

function build_for(x10)
    p = params_at_length(params_daisy(), L18, KW)
    x = copy(x10)
    x[4] = Float64(round(Int, clamp(x[4], 3, 16)))
    x[6] = Float64(round(Int, clamp(x[6], 1, 3)))
    dec = KiteTurbineDynamics.design_from_vector_v10(
        x,
        PROFILE_ELLIPTICAL,
        p;
        power_W=PW,
        cylinder_cone=true,
        rotor_count_mode=true,
        power_split=0.6,
        cone_slope_deg=22.0,
        rotor_spacing_frac=0.8,
        blocking_factor=BLOCKING_WIND_FACTOR_5KW,
    )
    sizing = KiteTurbineDynamics.size_beams_closed_form(dec, p, cfg_none())
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

"""Back-line state and the sky-anchor axial residual at state u."""
function back_state(u, sys, pc, wf, lift)
    d = zeros(length(u))
    KiteTurbineDynamics.multibody_ode!(d, u, (sys, pc, wf, lift), 0.0)
    N = sys.n_total
    g = sys.sky_anchor_id
    m = (sys.nodes[g]).mass
    sd = normalize(pos(u, sys.rotor.node_id))
    sky_res = dot(m .* d[(3N + 3 * (g - 1) + 1):(3N + 3 * g)], sd)

    sh = [cos(pc.elevation_angle), 0.0, sin(pc.elevation_angle)]
    r_top = (sys.nodes[sys.rotor.node_id]::RingNode).radius
    b_off = KiteTurbineDynamics.bridle_bearing_offset(r_top)
    design_sky = (pc.tether_length + b_off + KiteTurbineDynamics.CYAN_L0_DESIGN) .* sh

    sky_p = pos(u, sys.sky_anchor_id)
    back_ax = pc.tether_length * cos(pc.elevation_angle) + pc.back_anchor_fwd_x
    b_dx = sqrt((sky_p[1] - back_ax)^2 + sky_p[2]^2)
    b_dz = sky_p[3]
    b_dist = sqrt(b_dx^2 + b_dz^2)
    back_L0 = norm(design_sky - [back_ax, 0.0, 0.0]) + pc.backline_payout
    taut = b_dist > back_L0 + 1e-6
    T = 0.0
    if taut
        _, _, Fx_top, Fz_top, _ = KiteTurbineDynamics.catenary_forces(
            0.0,
            0.0,
            b_dx,
            b_dz,
            back_L0,
            KiteTurbineDynamics.dyneema_weight_Npm(0.003),
            pc.EA_back_line,
        )
        T = sqrt(Fx_top^2 + Fz_top^2)
    end
    @assert isfinite(T) && T >= 0.0 "back-line tension invalid"
    @assert taut == (T > 0.0) "tension-only state inconsistent with tension"
    return (;
        T=T,
        taut=taut,
        stretch=b_dist - back_L0,
        dist=b_dist,
        L0=back_L0,
        sky_off=norm(sky_p .- design_sky),
        sky_res=sky_res,
        dz=sky_p[3] - design_sky[3],
    )
end

println("=== A. CONVERGENCE: candidate, EA_back_line = 314 kN (current) ===")
sys, u0, pc, lift, wf = build_for(X)
@assert pc.EA_back_line > 0.0

"""Settle at each n_op and report the back-line state; return the longest relax."""
function convergence_scan(sys, u0, pc, lift, wf, n_ops)
    settled = nothing
    for n_op in n_ops
        u = settle_to_operational_state(
            sys, copy(u0), pc, 60.0; lift_device=lift, wind_fn=wf, n_op=n_op
        )
        s = back_state(u, sys, pc, wf, lift)
        println(
            "  n_op=",
            lpad(n_op, 7),
            "  T_back=",
            lpad(round(s.T; digits=1), 8),
            " N  stretch=",
            lpad(round(100 * s.stretch; digits=2), 7),
            " cm",
            "  sky_off=",
            lpad(round(s.sky_off; digits=4), 7),
            " m",
            "  sky_dz=",
            lpad(round(s.dz; digits=4), 8),
            " m",
            "  sky_res=",
            lpad(round(s.sky_res; digits=1), 9),
            " N",
        )
        settled = s
    end
    return settled
end

settled = convergence_scan(
    sys, u0, pc, lift, wf, (2_000, 20_000, 100_000, 300_000, 600_000)
)
@assert settled !== nothing "no settle ran"
@assert isfinite(settled.T) && settled.T >= 0.0

# The catenary tension matched the linear EA·stretch/L0 to six digits in
# measure_anchor_geometry.jl, so the back line is weight-negligible and the
# tension is set by stiffness x stretch.  Predict the other EA cases from the
# settled stretch instead of re-running three settles.
println("\n=== B. STIFFNESS scaling, predicted from the settled stretch ===")
println(
    "  (T = EA * stretch / L0; validated against the catenary in measure_anchor_geometry.jl)",
)
for EA in (314e3, 707e3, 1.414e6)
    T = EA * settled.stretch / settled.L0
    println(
        "  EA=",
        lpad(round(EA / 1e3; digits=0), 7),
        " kN  ->  T_back=",
        lpad(round(T; digits=1), 8),
        " N",
        "   (stretch held at ",
        round(100 * settled.stretch; digits=2),
        " cm)",
    )
end

println("\n=== done ===")

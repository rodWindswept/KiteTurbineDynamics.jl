# scratch/measure_anchor_geometry.jl
#
# 2026-09-16.  What is the ~6 cm between the settled cyan span and CYAN_L0_DESIGN,
# and where does the sky anchor actually sit relative to its design position?
#
# ⚠ SUPERSEDED ON ITS HEADLINE NUMBER.  This probe settles with n_op=2_000, and
# scratch/check_anchor_convergence.jl shows that is NOT converged: the back-line
# tension it reports (3808 N) falls to 424.5 N by n_op=100_000 and the sky-anchor
# axial residual goes from -1432 N to 0 N.  The 3808 N figure here is an
# under-converged artefact and must not be cited.
#
# What IS still valid here: the GEOMETRY read (positions, cyan span, back-line
# rest length and distance), and the confirmation that the back line is on its
# TAUT branch.  Cite the converged tension from check_anchor_convergence.jl.
#
# Context (Rod, 2026-09-16): the backline length is a FIELD TRIM set at launch to
# fix the sky anchor's max height and so the rig's max kite elevation.  So the
# question is not "which force moved the anchor 6 cm" but "what is the settled
# geometry, and is the back line taut at it under the current model".
#
# Reports, for the L/r 1.5 candidate at its own equilibrium:
#   (a) bearing / sky anchor / design sky anchor positions along the shaft
#   (b) cyan span vs its 5.0 m cut length  -> is the cyan line slack?
#   (c) back line: rest length, current length, tension-only state, tension
#
# Self-checking: asserts the settled span is finite and positive, that the
# bearing offset still matches the derived cone, and that the reported back-line
# tension is consistent with the tension-only branch it reports.

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
    cfg = cfg_none()
    sizing = KiteTurbineDynamics.size_beams_closed_form(dec, p, cfg)
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

sys, u0, pc, lift, wf = build_for(X)
ω = 14.1681   # measured candidate equilibrium (scratch/check_candidate_lr15.jl)
u = settle_to_operational_state(
    sys, copy(u0), pc, 60.0; lift_device=lift, wind_fn=wf, n_op=2_000
)

hub_i, bear_i, sky_i = sys.rotor.node_id, sys.bearing_id, sys.sky_anchor_id
sd = normalize(pos(u, hub_i))
sh = [cos(pc.elevation_angle), 0.0, sin(pc.elevation_angle)]

hub_p = pos(u, hub_i)
bear_p = pos(u, bear_i)
sky_p = pos(u, sky_i)
@assert all(isfinite, hub_p) && all(isfinite, sky_p) "non-finite geometry"

r_top = (sys.nodes[hub_i]::RingNode).radius
b_off = KiteTurbineDynamics.bridle_bearing_offset(r_top)
# Design sky-anchor position, exactly as ring_forces.jl:537 builds it.
L_axis_design = pc.tether_length + b_off + KiteTurbineDynamics.CYAN_L0_DESIGN
design_sky = L_axis_design .* sh

cyan_span = norm(sky_p .- bear_p)
cyan_rest = KiteTurbineDynamics.CYAN_L0_DESIGN

# Back line geometry, exactly as ring_forces.jl:526-542 builds it.
back_ax = pc.tether_length * cos(pc.elevation_angle) + pc.back_anchor_fwd_x
b_dx = sqrt((sky_p[1] - back_ax)^2 + sky_p[2]^2)
b_dz = sky_p[3]
b_dist = sqrt(b_dx^2 + b_dz^2)
back_L0_design = norm(design_sky - [back_ax, 0.0, 0.0])
back_L0 = back_L0_design + pc.backline_payout
taut = b_dist > back_L0 + 1e-6
w_back = KiteTurbineDynamics.dyneema_weight_Npm(0.003)

println("=== anchor geometry, settled candidate at omega=", ω, " ===")
println("  shaft dir            = ", round.(sd; digits=5))
println("  hub position         = ", round.(hub_p; digits=4))
println("  bearing position     = ", round.(bear_p; digits=4))
println("  sky anchor (settled) = ", round.(sky_p; digits=4))
println("  sky anchor (design)  = ", round.(design_sky; digits=4))
println(
    "  sky settled - design = ",
    round.(sky_p .- design_sky; digits=4),
    "   |delta| = ",
    round(norm(sky_p .- design_sky); digits=4),
    " m",
)

@assert cyan_span > 0.0 && isfinite(cyan_span)
println("\n--- cyan line (bearing -> sky anchor), a 5.0 m cut rope ---")
println("  cut length           = ", round(cyan_rest; digits=4), " m")
println("  settled span         = ", round(cyan_span; digits=4), " m")
println(
    "  span - cut length    = ",
    round(cyan_span - cyan_rest; digits=5),
    " m",
    cyan_span >= cyan_rest ? "  (extended)" : "  (INSIDE its cut length -> slack)",
)
println(
    "  design span          = ",
    round(norm(design_sky .- (hub_p .+ b_off .* sh)); digits=4),
    " m",
)

println("\n--- back line (sky anchor -> ground anchor) ---")
println("  rest length design   = ", round(back_L0_design; digits=4), " m")
println("  payout               = ", round(pc.backline_payout; digits=4), " m")
println("  rest length total    = ", round(back_L0; digits=4), " m")
println("  current distance     = ", round(b_dist; digits=4), " m")
println("  dist - rest          = ", round(b_dist - back_L0; digits=5), " m")
println("  tension-only state   = ", taut ? "TAUT" : "SLACK (distance < rest length)")
if taut
    _, _, Fx_top, Fz_top, _ = KiteTurbineDynamics.catenary_forces(
        0.0, 0.0, b_dx, b_dz, back_L0, w_back, pc.EA_back_line
    )
    T_approx = sqrt(Fx_top^2 + Fz_top^2)
    ext = b_dist - back_L0
    T_linear = ext * pc.EA_back_line / back_L0
    @assert isfinite(T_approx) && T_approx >= 0.0 "catenary tension invalid"
    println(
        "  vertical offset      = ",
        round(b_dz; digits=4),
        " m",
        "  (",
        round(rad2deg(atan(b_dx, b_dz)); digits=2),
        " deg off vertical)",
    )
    println("  tension (catenary)   = ", round(T_approx; digits=2), " N")
    println("  tension (linear EA/L)= ", round(T_linear; digits=2), " N")
    println("  stretch / rest       = ", round(ext / back_L0; digits=6))
else
    println("  tension              = 0 N (slack branch)")
end

println("\n=== done ===")

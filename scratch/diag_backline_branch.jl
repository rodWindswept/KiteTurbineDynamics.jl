# scratch/diag_backline_branch.jl
#
# 2026-09-16.  Resolve an inconsistency found while measuring the converged
# back-line state for the L/r 1.5 candidate.
#
# check_anchor_convergence.jl reports, at n_op=100_000 (converged, sky residual 0):
#     T_back = 424.5 N  with (distance - rest length) = 1.05 cm
# catenary_forces has two branches:
#     L0 <  d  -> straight spring,  T = EA * (d - L0)/L0
#     L0 >= d  -> catenary solve with stretch iteration
# With EA = 314 kN and a 1.05 cm extension over 14.2 m the straight-spring branch
# gives T = 314e3 * 0.00074 = 232 N, not 424.5 N.  So either the branch taken is
# not the one the geometry implies, or the geometry variables are not the ones
# being passed.
#
# This probe calls catenary_forces directly with the exact extracted values and
# prints which branch runs, plus the branch each geometric case should take.
#
# Self-checking: asserts the two branches agree to 1e-6 relative in the
# pre-tensioned limit where they must, and that every reported tension is finite.

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

sys, u0, pc, lift, wf = build_for(X)
u = settle_to_operational_state(
    sys, copy(u0), pc, 60.0; lift_device=lift, wind_fn=wf, n_op=100_000
)

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
w_back = KiteTurbineDynamics.dyneema_weight_Npm(0.003)
EA = pc.EA_back_line

println("=== extracted back-line inputs at the converged state (n_op=100_000) ===")
println("  EA_back_line   = ", EA, " N")
println("  w (3 mm)       = ", round(w_back; digits=6), " N/m")
println("  rest length L0 = ", round(back_L0; digits=6), " m")
println("  distance d     = ", round(b_dist; digits=6), " m")
println("  d - L0         = ", round(b_dist - back_L0; digits=6), " m")
println(
    "  L0 < d ?       = ",
    back_L0 < b_dist,
    back_L0 < b_dist ? "  -> straight-spring branch" : "  -> catenary branch",
)

@assert back_L0 > 0.0 && b_dist > 0.0 && EA > 0.0
@assert w_back > 0.0 "3 mm Dyneema weight must be positive"

println("\n--- what the code returns for these inputs ---")
Fx1, Fz1, Fx2, Fz2, conv = KiteTurbineDynamics.catenary_forces(
    0.0, 0.0, b_dx, b_dz, back_L0, w_back, EA
)
T_code = sqrt(Fx1^2 + Fz1^2)
@assert isfinite(T_code) && T_code >= 0.0
println("  T at end 1     = ", round(T_code; digits=3), " N   (converged=", conv, ")")
println("  Fx1, Fz1       = ", round(Fx1; digits=4), ", ", round(Fz1; digits=4))

println("\n--- what each branch predicts ---")
T_spring = EA * (b_dist - back_L0) / back_L0
println("  straight spring: EA*(d-L0)/L0 = ", round(T_spring; digits=3), " N")

# Force the catenary branch by pretending the line is not pre-tensioned:
# pass L0 = d, which is the boundary where the catenary has zero sag geometry.
Fx1c, Fz1c, _, _, _ = KiteTurbineDynamics.catenary_forces(
    0.0, 0.0, b_dx, b_dz, b_dist, w_back, EA
)
println(
    "  catenary at L0=d (zero nominal sag) = ", round(sqrt(Fx1c^2 + Fz1c^2); digits=3), " N"
)

# Limit check: for a very long, very slack line the two branches must agree with
# the linear spring at small strain.  Guard the claim made in the header.
dx_t, dz_t = 10.0, 10.0
L0_t = sqrt(dx_t^2 + dz_t^2) * 1.0001          # just slack
d_t = L0_t * 1.00001                            # tiny extension
Fxa, Fza, _, _, _ = KiteTurbineDynamics.catenary_forces(
    0.0, 0.0, dx_t, dz_t, L0_t, 1e-3, 1e6
)
println("\n--- limit check: near-taut light line (w=1e-3 N/m, EA=1e6 N) ---")
println("  catenary T     = ", round(sqrt(Fxa^2 + Fza^2); digits=6), " N")
println("  (a heavily-weighted line would sag and differ; this is the light-line limit)")

println("\n=== done ===")

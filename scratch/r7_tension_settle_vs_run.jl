# scratch/r7_tension_settle_vs_run.jl — is the settle's AXIAL PRELOAD too high?
#
# Hypothesis (from the staged-prototype baseline): the settle's twist chain is
# already a torque equilibrium for rings 1..7 (|τ_res| ≈ 0), and the first
# segment carries the same torque as the running state (~380 N·m) but at 6.6°
# instead of 48.8°.  For a fixed torque τ ≈ n·T·r²·sin(Δα)/chord, an 7x twist
# ratio at equal torque implies the running line TENSION is ~7x lower than the
# settle's.  This script measures both.
using KiteTurbineDynamics, Printf, LinearAlgebra
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))

function params_5kw_188()
    p2 = params_daisy()
    geo = GeometrySpec(p2.elevation_angle, p2.lifter_elevation, p2.rotor_radius,
        18.8, p2.trpt_hub_radius, p2.trpt_rL_ratio, p2.n_lines, p2.n_rings, p2.n_blades)
    mat = MaterialSpec(p2.tether_diameter, p2.e_modulus, p2.m_ring, p2.m_blade)
    aero = AeroSpec(p2.rho, p2.v_wind_ref, p2.h_ref, p2.cp)
    ctrl = ControlSpec(p2.i_pto, p2.k_mppt, p2.p_rated_w, p2.β_min, p2.β_max, p2.β_rate_max, p2.kp_elev)
    back = BackLineSpec(p2.EA_back_line, p2.c_back_line, p2.back_anchor_fwd_x, p2.backline_payout)
    return override_params(mass_scale(SystemParams(geo, mat, aero, ctrl, back), 1.5, 5.0);
                           tether_length=18.8)
end

p = params_5kw_188()
x = seed_genome(5.0)
x[4] = Float64(round(Int, clamp(x[4], 3, 16)))
x[6] = Float64(round(Int, clamp(x[6], 1, 3)))
dec = KiteTurbineDynamics.design_from_vector_v10(x, PROFILE_ELLIPTICAL, p; power_W=5000.0,
    cylinder_cone=true, rotor_count_mode=true, power_split=0.6, cone_slope_deg=22.0,
    rotor_spacing_frac=0.8, blocking_factor=BLOCKING_WIND_FACTOR_5KW)
cfg = ObjectiveConfig(; power_W=5000.0, v_rated=11.0, p_floor_kw=5.0, p_ceiling_kw=5.0,
    fos_target=2.5, fos_hard=2.5, min_wall_m=2e-3, t_over_D=0.055,
    rotor_count_mode=true, power_split=0.6, blocking_factor=BLOCKING_WIND_FACTOR_5KW,
    k_mppt=K_MPPT_5KW_HONEST)
sizing = size_beams_closed_form(dec, p, cfg)
sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(dec, 1.0, K_MPPT_5KW_HONEST;
    tether_diameter=p.tether_diameter, base_params=p, min_wall_m=2e-3, beam_sizing=sizing)
sys.k_mppt_ref[] = K_MPPT_5KW_HONEST
lift = sized_lifter_for(sys, pc; margin=1.5, v_ref=11.0, const_tension=true)
wf = (r, t) -> [11.0 * (max(r[3], 1.0) / p.h_ref)^(1 / 7), 0.0, 0.0]
dt = KiteTurbineDynamics.stable_dt_for_system(sys, pc)
N = sys.n_total
Nr = sys.n_ring

u = settle_to_operational_state(sys, copy(u0), pc, 60.0;
    lift_device=lift, wind_fn=wf, n_op=150_000)

# Design preload the settle *intended* (same expression as initialization.jl).
EA_tot = pc.n_lines * pc.e_modulus * π * (pc.tether_diameter / 2)^2
T_cyan_des = design_preload_from_sky_anchor(pc, lift)
βr = pc.elevation_angle
vr = pc.v_wind_ref
thrust_r = 0.5 * pc.rho * vr^2 * π * pc.rotor_radius^2 * 0.8 * cos(βr)^2
F_aero_z_r = thrust_r * sin(βr) + (pc.n_blades * pc.m_blade + sys.kite.mass) * (-9.81)
F_top_ax_r = max(F_aero_z_r / sin(βr) + T_cyan_des, 20.0)

function tensions(u)
    ef = KiteTurbineDynamics.capture_extended(u, sys, pc, 0.0, wf, lift)
    return ef.segment_tension, ef.segment_twist_deg, ef.segment_torque
end

function report(tag, u)
    T, tw, tq = tensions(u)
    α = [u[6N + r] for r in 1:Nr]
    hub_pos = u[(3 * (sys.rotor.node_id - 1) + 1):(3 * sys.rotor.node_id)]
    sd = norm(hub_pos) > 0.1 ? hub_pos ./ norm(hub_pos) : [cos(βr), 0.0, sin(βr)]
    lat = maximum(norm(u[(3 * (gid - 1) + 1):(3 * gid)] .-
                      dot(u[(3 * (gid - 1) + 1):(3 * gid)], sd) .* sd)
                 for gid in sys.ring_ids)
    ω_g = u[6N + Nr + 1]
    ω_h = u[6N + 2 * Nr]
    # generator power from the ground-ring torque balance proxy k·ω² · ω - rope drag
    P_gen = 1e-3 * K_MPPT_5KW_HONEST * ω_g^3
    @printf("%-10s Δα_tot=%7.2f°  first-seg=%6.2f°  ω_gnd=%5.2f  P_gen≈%5.2f kW  T=%s\n",
        tag, (α[end] - α[1]) * 180 / π, tw[1], ω_g, P_gen,
        join(round.(T, digits=0), ","))
end

@printf("design axial preload F_top = %.1f N  (T_cyan_des = %.1f N, EA_tot = %.3e N)\n",
    F_top_ax_r, T_cyan_des, EA_tot)
@printf("settle min|segment tension| = %.1f N\n\n", minimum(tensions(u)[1]))

report("settle", u)
for k in 1:6
    run_canonical_sim!(u, sys, pc, wf, round(Int, 10.0 / dt), dt;
        lift_device=lift, lin_damp=0.05)
    report("t=$(10k)s", u)
end

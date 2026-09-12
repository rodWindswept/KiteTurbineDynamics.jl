# scratch/diag_reds_window_probe.jl — why do test_settle_lowk_honest A3 and
# test_physics_path_ode P1 reject after the 2026-09-11 settle fix?
#
# Builds the EXACT genome/config of those tests (X_SEED with the stale 14-D
# index clamps), settles with the evaluator's own n_op, then runs the cold
# window in 1 s chunks printing the evaluator's own per-sample quantities:
#   P_kw (capture_extended.base.P_kw), FoS_min, and twist_collapse_check.
using KiteTurbineDynamics, Printf, LinearAlgebra
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))

const KW = 5.0
const PW = KW * 1000.0
const V_RATED = 11.0
const LENGTH = 18.8

lift_for(sys, p) = KiteTurbineDynamics.sized_lifter_for(
    sys, p; margin=1.5, v_ref=V_RATED, const_tension=true)

function params_at_length(L::Float64)
    p2 = params_daisy()
    geo = GeometrySpec(p2.elevation_angle, p2.lifter_elevation, p2.rotor_radius,
        L, p2.trpt_hub_radius, p2.trpt_rL_ratio, p2.n_lines, p2.n_rings, p2.n_blades)
    mat = MaterialSpec(p2.tether_diameter, p2.e_modulus, p2.m_ring, p2.m_blade)
    aero = AeroSpec(p2.rho, p2.v_wind_ref, p2.h_ref, p2.cp)
    ctrl = ControlSpec(p2.i_pto, p2.k_mppt, p2.p_rated_w, p2.β_min, p2.β_max, p2.β_rate_max, p2.kp_elev)
    back = BackLineSpec(p2.EA_back_line, p2.c_back_line, p2.back_anchor_fwd_x, p2.backline_payout)
    scaled = mass_scale(SystemParams(geo, mat, aero, ctrl, back), 1.5, KW)
    return override_params(scaled; tether_length=L)
end

P_BASE = params_at_length(LENGTH)

# EXACT test_settle_lowk_honest seed_genome_x() — note xr[8]/xr[10] are legacy
# 14-D indices applied to the canonical 10-D genome.
function seed_genome_x()
    seed_v = seed_genome(KW)
    lo, hi = tight_bounds(seed_v, KW)
    xr = clamp.(copy(seed_v), lo, hi)
    xr[8] = Float64(round(Int, clamp(xr[8], 3, 16)))
    xr[10] = Float64(round(Int, clamp(xr[10], 1, 3)))
    return xr
end

X_SEED = seed_genome_x()
@printf("X_SEED (test)      = %s\n", join(round.(X_SEED, digits=4), ", "))
@printf("seed_genome(5.0)   = %s\n", join(round.(seed_genome(KW), digits=4), ", "))

cfg = ObjectiveConfig(;
    power_W=PW, v_rated=V_RATED, p_floor_kw=5.0, p_ceiling_kw=5.0,
    relax_s=5.0, window_s=20.0, fos_target=2.5, fos_hard=2.5,
    power_stat=:tail5, penalize_ceiling=false, kickstart_s=0.0,
    k_mppt=K_MPPT_5KW_HONEST, tether_diameter=P_BASE.tether_diameter,
    rotor_count_mode=true, power_split=0.6,
    blocking_factor=BLOCKING_WIND_FACTOR_5KW,
)

dec = KiteTurbineDynamics.design_from_vector_v10(
    X_SEED, PROFILE_ELLIPTICAL, P_BASE;
    power_W=PW, v_rated=V_RATED, cylinder_cone=true,
    rotor_count_mode=true, power_split=0.6, cone_slope_deg=22.0,
    rotor_spacing_frac=0.8, blocking_factor=BLOCKING_WIND_FACTOR_5KW,
    beam_t_over_D=cfg.t_over_D,
)
sizing = KiteTurbineDynamics.size_beams_closed_form(dec, P_BASE, cfg)
sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(
    dec, 1.0, K_MPPT_5KW_HONEST;
    tether_diameter=cfg.tether_diameter, base_params=P_BASE,
    min_wall_m=cfg.min_wall_m, beam_sizing=sizing)
sys.k_mppt_ref[] = K_MPPT_5KW_HONEST
lift_dev = lift_for(sys, pc)
wf(pos, t) = [KiteTurbineDynamics.WIND_MS * (max(pos[3], 1.0) / P_BASE.h_ref)^(1 / 7), 0.0, 0.0]
N = sys.n_total
Nr = sys.n_ring
dt = KiteTurbineDynamics.stable_dt_for_system(sys, pc)

u = settle_to_operational_state(sys, copy(u0), pc, 60.0; wind_fn=wf, lift_device=lift_dev)
@printf("settle: w_gnd=%.4f rad/s  k*w^3=%.3f kW  dt=%.3e\n",
    u[6 * N + Nr + 1], 1e-3 * K_MPPT_5KW_HONEST * u[6 * N + Nr + 1]^3, dt)

function twist_row(tag, u)
    tr = KiteTurbineDynamics.twist_collapse_check(u, sys)
    ef = KiteTurbineDynamics.capture_extended(u, sys, pc, 0.0, wf, lift_dev)
    fos_min, _ = KiteTurbineDynamics.min_airborne_fos(ef.ring_fos)
    @printf("  %-6s P=%7.3f kW  FoS=%7.3f  max_ratio=%6.3f  worst_seg=%d  crossed=%s\n",
        tag, ef.base.P_kw, fos_min, tr.max_ratio, tr.worst_seg, tr.crossed)
    flush(stdout)
    return tr
end

# per-segment table at settle
begin
    tr = twist_row("t=0", u)
    α = u[(6 * N + 1):(6 * N + Nr)]
    ef = KiteTurbineDynamics.capture_extended(u, sys, pc, 0.0, wf, lift_dev)
    println("  seg  Δα(deg)  δα*_maxR(deg)  ratio   T_line(N)")
    for s in 1:(Nr - 1)
        r_i = (sys.nodes[sys.ring_ids[s]]::RingNode).radius
        r_ip1 = (sys.nodes[sys.ring_ids[s + 1]]::RingNode).radius
        r_seg = max(r_i, r_ip1)
        p_i = u[(3 * (sys.ring_ids[s] - 1) + 1):(3 * sys.ring_ids[s])]
        p_ip1 = u[(3 * (sys.ring_ids[s + 1] - 1) + 1):(3 * sys.ring_ids[s + 1])]
        L_seg = norm(p_ip1 - p_i)
        dastar = rad2deg(2 * asin(min(L_seg / sqrt(2 * (L_seg^2 + 2 * r_seg^2)), 1.0)))
        da = abs(rad2deg(α[s + 1] - α[s]))
        @printf("  %3d  %8.3f  %12.3f  %6.3f  %9.2f\n",
            s, da, dastar, da / dastar, ef.segment_tension[s])
    end
    flush(stdout)
end

# Run the cold window in 1 s chunks.
println("\nwindow (evaluator cold path):")
for c in 1:25
    run_canonical_sim!(u, sys, pc, wf, round(Int, 1.0 / dt), dt;
        lift_device=lift_dev, lin_damp=0.05)
    tr = KiteTurbineDynamics.twist_collapse_check(u, sys)
    ef = KiteTurbineDynamics.capture_extended(u, sys, pc, float(c), wf, lift_dev)
    fos_min, _ = KiteTurbineDynamics.min_airborne_fos(ef.ring_fos)
    @printf("  t=%2ds P=%7.3f kW  FoS=%7.3f  max_ratio=%6.3f  worst=%d  crossed=%s  w_gnd=%.3f\n",
        c, ef.base.P_kw, fos_min, tr.max_ratio, tr.worst_seg, tr.crossed, u[6 * N + Nr + 1])
    flush(stdout)
end
println("DONE")

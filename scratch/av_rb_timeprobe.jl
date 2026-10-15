#!/usr/bin/env julia --project=.
# av_rb_timeprobe.jl — wall-rate estimate before the rope-break placement runs.
# Read-only w.r.t. src/. No figure or draft bytes touched.
using KiteTurbineDynamics, Printf, LinearAlgebra
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))

const KW = 5.0
const PW = KW * 1000.0
const V_RATED = 11.0
const RELAX_S = 10.0
const WINDOW_S = 40.0
const MIN_WALL_M = 2.0e-3
const LENGTH = 18.8

const REPO = dirname(@__DIR__)
const WINNER = joinpath(
    REPO, "scripts", "results", "v13_5kw_masslift_len18.8_rotorcount_bankderate2",
    "island_3", "best_vector.csv",
)

lift_for(sys, p) = KiteTurbineDynamics.sized_lifter_for(
    sys, p; margin=1.5, v_ref=V_RATED, const_tension=true)

function params_at_length(L::Float64)
    p2 = params_daisy()
    geo = GeometrySpec(
        p2.elevation_angle, p2.lifter_elevation, p2.rotor_radius,
        L, p2.trpt_hub_radius, p2.trpt_rL_ratio, p2.n_lines, p2.n_rings, p2.n_blades,
    )
    mat = MaterialSpec(p2.tether_diameter, p2.e_modulus, p2.m_ring, p2.m_blade)
    aero = AeroSpec(p2.rho, p2.v_wind_ref, p2.h_ref, p2.cp)
    ctrl = ControlSpec(
        p2.i_pto, p2.k_mppt, p2.p_rated_w, p2.β_min, p2.β_max, p2.β_rate_max, p2.kp_elev,
    )
    back = BackLineSpec(
        p2.EA_back_line, p2.c_back_line, p2.back_anchor_fwd_x, p2.backline_payout,
    )
    scaled = mass_scale(SystemParams(geo, mat, aero, ctrl, back), 1.5, KW)
    return override_params(scaled; tether_length=L)
end

x = [parse(Float64, tok) for tok in split(strip(read(WINNER, String)), ",")]
xr = copy(x)
xr[4] = Float64(round(Int, clamp(xr[4], 3, 16)))
xr[6] = Float64(round(Int, clamp(xr[6], 1, 3)))
p_base = params_at_length(LENGTH)
cfg = ObjectiveConfig(;
    power_W=PW, v_rated=V_RATED,
    p_floor_kw=5.0, p_ceiling_kw=5.0,
    relax_s=RELAX_S, window_s=WINDOW_S,
    fos_target=2.5, fos_hard=2.5,
    power_stat=:tail5, penalize_ceiling=false,
    kickstart_s=0.0,
    k_mppt=K_MPPT_5KW_HONEST,
    tether_diameter=p_base.tether_diameter,
    rotor_count_mode=true,
    power_split=0.6,
    cone_slope_deg=22.0,
    rotor_spacing_frac=0.8,
    blocking_factor=BLOCKING_WIND_FACTOR_5KW,
    min_wall_m=MIN_WALL_M,
)

x_canon = KiteTurbineDynamics.canonical_v10(xr)
result = KiteTurbineDynamics.design_from_vector_v10(
    x_canon, PROFILE_ELLIPTICAL, p_base;
    power_W=cfg.power_W, v_rated=cfg.v_rated,
    cylinder_cone=true,
    rotor_count_mode=cfg.rotor_count_mode,
    power_split=cfg.power_split,
    cone_slope_deg=cfg.cone_slope_deg,
    rotor_spacing_frac=cfg.rotor_spacing_frac,
    blocking_factor=cfg.blocking_factor,
    beam_t_over_D=cfg.t_over_D,
)
sizing = KiteTurbineDynamics.size_beams_closed_form(result, p_base, cfg)
k_mppt = clamp(cfg.k_mppt, 0.01, 1e6)
sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(
    result, 1.0, k_mppt;
    tether_diameter=cfg.tether_diameter,
    base_params=p_base,
    min_wall_m=cfg.min_wall_m,
    beam_sizing=sizing,
)
wf = function (pos, t)
    z = max(pos[3], 1.0)
    return [KiteTurbineDynamics.wind_at_altitude(p_base.v_wind_ref, p_base.h_ref, z), 0.0, 0.0]
end
lift_dev = lift_for(sys, pc)

t0 = time()
u_settled = KiteTurbineDynamics.settle_to_equilibrium(sys, u0, pc; wind_fn=wf, lift_device=lift_dev)
settle_wall = round(time() - t0, digits=1)
ω_eq = sizing.omega_eq
N = sys.n_total
Nr = sys.n_ring
u_settled[(6N + Nr + 1):(6N + 2Nr)] .= ω_eq
for ri in 1:Nr
    gid = sys.ring_ids[ri]
    pos = u_settled[(3 * (gid - 1) + 1):(3 * gid)]
    r = norm(pos)
    if r > 0.01
        tang = [-pos[2], pos[1], 0.0]
        tang ./= norm(tang)
        vx_idx = 3N + 3 * (gid - 1) + 1
        u_settled[vx_idx:(vx_idx + 2)] .= (ω_eq * r) .* tang
    end
end
sys.k_mppt_ref[] = k_mppt

dt = KiteTurbineDynamics.stable_dt_for_system(sys, pc)
n = 30_000
t0 = time()
KiteTurbineDynamics.run_canonical_sim!(
    u_settled, sys, pc, wf, n, dt;
    lift_device=lift_dev, lin_damp=0.05, breaks_enabled=false,
)
wall = time() - t0
rate = n / wall
full = (RELAX_S + WINDOW_S) / dt
@printf("settle wall = %.1f s | dt = %.8f | %d steps wall = %.1f s | rate = %.0f steps/s\n", settle_wall, dt, n, wall, rate)
@printf("full run = %.0f steps | est wall = %.1f min per full run\n", full, full / rate / 60)

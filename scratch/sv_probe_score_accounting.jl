# sv_probe_score_accounting.jl — software-validator, 2026-10-02
#
# DECIDES: (a) which fitness function the campaign actually scored with, and what
# that implies; (b) whether the recorded fitness decomposes into mass + the
# documented charges, so the "score is kg-equivalent mass" reading can be trusted.
#
# Findings this closes: `run_v13_5kw_masslift.jl:265` calls
# `appropriate_mass_fitness`, NOT the `mass_min_fitness` its own comment at :149
# names.  `mass_min_fitness` (objective_v12.jl:89-97) returns bare `mass`;
# `v12_fitness` (:29) is the only function that reads `cfg.penalize_ceiling`
# (:44); `appropriate_mass_fitness` (:145-168) charges
# `5.0·max(P−5.0,0)² + 20·(2.5/FoS)²` unconditionally.
#
# MIRRORS the runner's cfg and decode kwargs (run_v13_5kw_masslift.jl:151-172,
# 250-268), including `tether_diameter = p_base.tether_diameter` (scaled) — the
# scratch v13_cfg helper leaves the 0.003 default and builds a different machine.
#
# USAGE: scripts/ktd-julia scratch/sv_probe_score_accounting.jl

using KiteTurbineDynamics, Printf
const KTD = KiteTurbineDynamics

const ROOT = dirname(@__DIR__)
include(joinpath(ROOT, "scripts", "compute_seeds.jl"))

const KW = 5.0
const PW = KW * 1000.0
const V_RATED = 11.0
const L18 = 18.8

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

lift_for(sys, p) = KTD.sized_lifter_for(sys, p; margin=1.5, v_ref=V_RATED, const_tension=true)

p = params_at_length(L18)
cfg = KTD.ObjectiveConfig(;
    k_mppt=K_MPPT_5KW_HONEST, power_W=PW, v_rated=V_RATED,
    p_floor_kw=5.0, p_ceiling_kw=5.0, relax_s=10.0, window_s=40.0,
    fos_target=2.5, fos_hard=2.5, power_stat=:tail5, penalize_ceiling=false,
    kickstart_s=0.0, rotor_count_mode=true, power_split=0.6, cone_slope_deg=22.0,
    rotor_spacing_frac=0.8, blocking_factor=BLOCKING_WIND_FACTOR_5KW,
    tether_diameter=p.tether_diameter)

const CSV = joinpath(ROOT, "scripts", "results",
    "v13_5kw_masslift_len18.8_rotorcount_bankderate", "best_vector.csv")
x = [parse(Float64, s) for s in split(strip(read(CSV, String)), ",")]
xr = copy(x)
xr[4] = Float64(round(Int, clamp(xr[4], 3, 16)))
xr[6] = Float64(round(Int, clamp(xr[6], 1, 3)))

@printf("=== score accounting — %s ===\n", basename(dirname(CSV)))
@printf("  cfg: p_floor=%.2f p_ceiling=%.2f penalize_ceiling=%s power_stat=%s window=%.0f s tether_d=%.6f\n",
    cfg.p_floor_kw, cfg.p_ceiling_kw, cfg.penalize_ceiling, cfg.power_stat, cfg.window_s,
    cfg.tether_diameter)
@printf("  weights: W_OVERPOWER=%.2f  W_TWIST=%.2f  W_UTILISATION=%.2f\n",
    KTD.W_OVERPOWER_KG_PER_KW2, KTD.W_TWIST_KG, KTD.W_UTILISATION_KG)

# Mass figures from the built system (independent of the evaluator).
dec = design_from_vector_v10(xr, PROFILE_ELLIPTICAL, p; power_W=PW,
    cylinder_cone=true, rotor_count_mode=true, power_split=0.6,
    cone_slope_deg=22.0, rotor_spacing_frac=0.8,
    blocking_factor=BLOCKING_WIND_FACTOR_5KW)
sys, u0, pc = KTD.build_system_from_v10(dec, 1.0, K_MPPT_5KW_HONEST;
    tether_diameter=p.tether_diameter, base_params=p)
m_with = KTD.expansion_airborne_mass(sys, pc)
m_wo = KTD.expansion_airborne_mass(sys, pc; include_lifter=false)
@printf("  expansion_airborne_mass: with lifter %.4f kg   without lifter %.4f kg\n", m_with, m_wo)

println("\n  running one evaluator window (cold start, 10 s relax + 40 s window)…")
r = KTD.evaluate_windowed(xr, PROFILE_ELLIPTICAL, p, cfg;
    start_mode=:cold, lift_device=lift_for,
    fitness_fn=(P, F, c, m) -> KTD.appropriate_mass_fitness(P, F, c, m))
@printf("  status=%s  twist_crossed=%s\n", r.status, r.twist_crossed)
@printf("  P_mean=%.4f kW   P_end=%.4f kW (P_score, tail5)   FoS_min=%.4f\n",
    r.P_mean, r.P_end, r.FoS_min)

P_score = r.P_end
excess = max(P_score - cfg.p_ceiling_kw, 0.0)
charge = KTD.W_OVERPOWER_KG_PER_KW2 * excess^2
util = KTD.W_UTILISATION_KG * (cfg.fos_hard / r.FoS_min)^2
mass_implied = r.fitness - charge - util

@printf("\n  fitness (as scored)          = %.4f\n", r.fitness)
@printf("  - over-power charge          = %.4f   (5.0 · max(%.4f − 5.0, 0)²)\n", charge, P_score)
@printf("  - utilisation charge         = %.4f   (20.0 · (2.5/%.4f)²)\n", util, r.FoS_min)
@printf("  = mass the campaign scored   = %.4f kg\n", mass_implied)
@printf("  measured airborne mass       = %.4f kg (with lifter) / %.4f kg (without)\n",
    m_with, m_wo)
@printf("  gap scored-mass vs measured  = %+.4f kg (with lifter) / %+.4f kg (without)\n",
    mass_implied - m_with, mass_implied - m_wo)

println("\n  --- the objective the diagnostics use instead ---")
@printf("  appropriate_mass_fitness  : %.4f  <- what the campaign called\n",
    KTD.appropriate_mass_fitness(P_score, r.FoS_min, cfg, m_wo))
@printf("  mass_min_fitness (bare m) : %.4f  <- what run_v13's comment at :149 names\n",
    KTD.mass_min_fitness(P_score, r.FoS_min, cfg, m_wo))
@printf("  v12_fitness (reads flag)  : %.4f  <- the only reader of penalize_ceiling\n",
    KTD.v12_fitness(P_score, r.FoS_min, cfg, m_wo))
@printf("  recorded campaign fitness = 21.6980 (island 3 best)\n")

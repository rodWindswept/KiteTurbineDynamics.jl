# scratch/av_probe_score_closure.jl — aero-validator, 2026-10-02
#
# DECIDES: is the post-seam residual of each island winner's recorded fitness
# really the TWIST charge, or could the stationarity penalty be hiding in it?
#
# The winner pack (scratch/hermes_winner_pack.jl) identifies residual = twist
# and ASSUMES stationarity ≈ 0.  That assumption is only proven for island 3
# (docs/validation/2026-10-02-genome-index-and-preload-budget.md §8-9, where the
# closure was done at window precision).  This probe MEASURES the stationarity
# term instead of assuming it:
#
#   swing = P_range / P_mean          (objective_evaluator.jl:1124)
#   stat  = STATIONARITY_LAMBDA(10.0) · max(0, swing − STATIONARITY_SWING(0.20))
#                                                            :1125-1126
#   twist = fitness − m_airborne − W_OVERPOWER·max(P_end−5,0)²
#                            − W_UTILISATION·(2.5/FoS)² − stat     :1131-1134
#
# P_mean, P_range, P_end, FoS_min all come back on ObjectiveResult, so every
# term on the right is measured, not assumed.  Also quantifies the precision
# cost of rebuilding the pack's charges from telemetry.csv's 2-dp columns
# (P_end 5.11 / FoS 9.38 are round(...,digits=2) at run_v13_5kw_masslift.jl:193-196).
#
# USAGE: scripts/ktd-julia scratch/av_probe_score_closure.jl

using KiteTurbineDynamics, Printf
const KTD = KiteTurbineDynamics

const ROOT = dirname(@__DIR__)
include(joinpath(ROOT, "scripts", "compute_seeds.jl"))

const KW = 5.0
const PW = KW * 1000.0
const ELEV = π / 6
const V_RATED = 11.0
const LENGTH = 18.8
const CAMPAIGN = joinpath(
    ROOT, "scripts", "results", "v13_5kw_masslift_len18.8_rotorcount_bankderate"
)

# ── same base params as run_v13_5kw_masslift.jl:124-140 ──────────────────
function params_at_length(L::Float64)
    p2 = params_daisy()
    geo = GeometrySpec(
        p2.elevation_angle, p2.lifter_elevation, p2.rotor_radius,
        L, p2.trpt_hub_radius, p2.trpt_rL_ratio, p2.n_lines, p2.n_rings, p2.n_blades
    )
    mat = MaterialSpec(p2.tether_diameter, p2.e_modulus, p2.m_ring, p2.m_blade)
    aero = AeroSpec(p2.rho, p2.v_wind_ref, p2.h_ref, p2.cp)
    ctrl = ControlSpec(
        p2.i_pto, p2.k_mppt, p2.p_rated_w, p2.β_min, p2.β_max, p2.β_rate_max, p2.kp_elev
    )
    back = BackLineSpec(
        p2.EA_back_line, p2.c_back_line, p2.back_anchor_fwd_x, p2.backline_payout
    )
    scaled = mass_scale(SystemParams(geo, mat, aero, ctrl, back), 1.5, KW)
    return override_params(scaled; tether_length=L)
end

const p_base = params_at_length(LENGTH)
const BF = BLOCKING_WIND_FACTOR_5KW
const FOS_HARD = 2.5
const P_CEIL = KW

# ── cfg identical to run_v13_5kw_masslift.jl:151-176 ─────────────────────
cfg = KTD.ObjectiveConfig(;
    power_W=PW, v_rated=V_RATED,
    p_floor_kw=KW, p_ceiling_kw=KW,
    relax_s=10.0, window_s=40.0,
    fos_target=FOS_HARD, fos_hard=FOS_HARD,
    power_stat=:tail5, penalize_ceiling=false,
    kickstart_s=0.0,
    k_mppt=K_MPPT_5KW_HONEST,
    tether_diameter=p_base.tether_diameter,
    rotor_count_mode=true, power_split=0.6,
    cone_slope_deg=22.0, rotor_spacing_frac=0.8,
    blocking_factor=BF,
    min_wall_m=2e-3,
)

lift_for(sys, p) = KTD.sized_lifter_for(sys, p; margin=1.5, v_ref=V_RATED, const_tension=true)

tr_of(c) = c > 0.0 ? sqrt(c / KTD.W_TWIST_KG) / (1.0 + sqrt(c / KTD.W_TWIST_KG)) : 0.0

@printf("=== score closure at window precision, campaign %s ===\n", basename(CAMPAIGN))
println("scorer: appropriate_mass_fitness via the runner's 4-arg seam call")
println()
@printf("%-9s %10s %10s %8s %8s %8s %10s %8s %9s %9s %8s\n",
    "island", "fitness", "mass", "P_end", "FoS", "swing", "stationarity",
    "c_over", "c_util", "twist", "twist tr")

for isl in (1, 2, 3)
    genfile = joinpath(CAMPAIGN, "island_$isl", "island_$(isl)_best.csv")
    x = parse.(Float64, split(strip(read(genfile, String)), ","))
    x[4] = Float64(round(Int, clamp(x[4], 3, 16)))
    x[6] = Float64(round(Int, clamp(x[6], 1, 3)))

    dec = design_from_vector_v10(x, PROFILE_ELLIPTICAL, p_base; power_W=PW,
        cylinder_cone=true, rotor_count_mode=true, power_split=0.6,
        cone_slope_deg=22.0, rotor_spacing_frac=0.8, blocking_factor=BF)
    sizing = KTD.size_beams_closed_form(dec, p_base, cfg)
    sys, u0, pc = KTD.build_system_from_v10(dec, 1.0, K_MPPT_5KW_HONEST;
        tether_diameter=p_base.tether_diameter, base_params=p_base, min_wall_m=2e-3,
        beam_sizing=sizing)
    mass = KTD.expansion_airborne_mass(sys, pc)   # what objective_evaluator.jl:1082 charges

    r = KTD.evaluate_windowed(x, PROFILE_ELLIPTICAL, p_base, cfg;
        start_mode=:cold,
        lift_device=lift_for,
        fitness_fn=(P, F, c, m) -> KTD.appropriate_mass_fitness(P, F, c, m),
    )

    swing = r.P_mean > 0.1 ? r.P_range / r.P_mean : 0.0
    stat = KTD.STATIONARITY_LAMBDA * max(0.0, swing - KTD.STATIONARITY_SWING)
    c_over = KTD.W_OVERPOWER_KG_PER_KW2 * max(r.P_end - P_CEIL, 0.0)^2
    c_util = KTD.W_UTILISATION_KG * (FOS_HARD / r.FoS_min)^2
    twist = r.fitness - mass - c_over - c_util - stat

    @printf("%-9d %10.6f %10.4f %8.4f %8.4f %8.4f %10.4f %8.4f %9.4f %9.4f %8.4f\n",
        isl, r.fitness, mass, r.P_end, r.FoS_min, swing, stat, c_over, c_util, twist, tr_of(twist))
    @printf("          status=%s  P_mean=%.4f kW  P_range=%.4f kW  twist_crossed=%s  drifted=%s  stationary=%s\n",
        r.status, r.P_mean, r.P_range, r.twist_crossed, r.drifted, r.stationary)
    @printf("          closure check: mass+over+util+stat+twist = %.6f  vs fitness %.6f  (Δ %+.2e)\n",
        mass + c_over + c_util + stat + twist, r.fitness,
        mass + c_over + c_util + stat + twist - r.fitness)

    # ── the NEW field (ObjectiveResult.twist_ratio, 2026-10-02) ───────────
    # Does the logged ratio reproduce the residual-derived charge?  If yes, the
    # column that the next combine writes is the same quantity this closure
    # backs out of the fitness, and the pack's preferred path becomes
    # non-circular.
    tw_new = KTD.W_TWIST_KG * (r.twist_ratio / max(1.0 - r.twist_ratio, 1e-6))^2
    @printf("          twist_ratio (new field) = %.6f   charge from it = %.6f   residual-derived = %.6f  (Δ %+.2e)\n",
        r.twist_ratio, tw_new, twist, tw_new - twist)
    println()
end

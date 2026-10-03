# scratch/av_probe_charged_mass.jl — aero-validator, 2026-10-02
#
# DECIDES: what mass does the campaign's score actually charge, on the campaign's
# OWN evaluator call?  This closes (or relocates) the 0.76 kg residual: the
# winner's recorded telemetry row (island 3, gen 21, idx 5: fitness 21.698,
# P_end 5.11, FoS 9.38) implies a charged mass of ~20.2135 kg under the tree's
# own fitness function, while `expansion_airborne_mass` on a bit-identical
# rebuild of the evaluator's build returns 19.4508 kg.  `ObjectiveResult` carries
# NO mass field (objective_evaluator.jl:229-244), so the charged mass is not
# recorded anywhere — hence SV could not close it from the record.
#
# Method: call `evaluate_windowed` with the campaign's own cfg and lift device,
# and intercept the fitness seam to print the mass it is handed.  No src/ edit.
#
# USAGE: scripts/ktd-julia scratch/av_probe_charged_mass.jl

using KiteTurbineDynamics, Printf
const KTD = KiteTurbineDynamics

const ROOT = dirname(@__DIR__)
include(joinpath(ROOT, "scripts", "compute_seeds.jl"))

const KW = 5.0
const PW = KW * 1000.0
const V_RATED = 11.0
const LENGTH = 18.8
const CSV = joinpath(
    ROOT, "scripts", "results",
    "v13_5kw_masslift_len18.8_rotorcount_bankderate", "best_vector.csv"
)

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

const p = params_at_length(LENGTH)
const bf = BLOCKING_WIND_FACTOR_5KW
const xv = [parse(Float64, s) for s in split(strip(read(CSV, String)), ",")]
xv[4] = Float64(round(Int, clamp(xv[4], 3, 16)))
xv[6] = Float64(round(Int, clamp(xv[6], 1, 3)))

# The campaign's own ObjectiveConfig (run_v13_5kw_masslift.jl:151-176).
cfg = KTD.ObjectiveConfig(;
    power_W=PW, v_rated=V_RATED,
    p_floor_kw=5.0, p_ceiling_kw=5.0,
    relax_s=10.0, window_s=40.0,
    fos_target=2.5, fos_hard=2.5,
    power_stat=:tail5, penalize_ceiling=false,
    kickstart_s=0.0,
    k_mppt=K_MPPT_5KW_HONEST,
    tether_diameter=p.tether_diameter,
    rotor_count_mode=true, power_split=0.6,
    cone_slope_deg=22.0, rotor_spacing_frac=0.8,
    blocking_factor=bf, min_wall_m=2e-3,
)

lift_for(sys_, p_) = KTD.sized_lifter_for(sys_, p_; margin=1.5, v_ref=V_RATED, const_tension=true)

seen = Ref{Any}(nothing)
seam = (P, F, c, m) -> begin
    seen[] = (; P, F, m)
    KTD.appropriate_mass_fitness(P, F, c, m)
end

println("=== charged-mass probe: campaign cfg, campaign evaluator, winner genome ===")
println("  (window 40 s, relax 10 s, tail5, k = K_MPPT_5KW_HONEST — ~2-4 min)")
flush(stdout)

t0 = time()
r = KTD.evaluate_windowed(
    xv, PROFILE_ELLIPTICAL, p, cfg;
    start_mode=:cold,          # the campaign's own call (runner:262), NOT the :warm default
    lift_device=lift_for, fitness_fn=seam,
)
wall = time() - t0

@printf("\nstatus          = %s\n", r.status)
@printf("P_mean / P_end  = %.4f / %.4f kW   (recorded row: 5.1 / 5.11)\n", r.P_mean, r.P_end)
@printf("FoS_min         = %.4f           (recorded row: 9.38)\n", r.FoS_min)
@printf("fitness         = %.6f       (recorded row: 21.698286576503694)\n", r.fitness)
@printf("evaluator wall  = %.1f s\n", wall)

if seen[] === nothing
    println("\nSEAM NEVER CALLED — the row rejected before scoring.")
else
    m = seen[].m
    P = seen[].P
    F = seen[].F
    @printf("\nMASS HANDED TO THE SEAM = %.6f kg\n", m)
    @printf("  P_score handed = %.6f kW    FoS handed = %.6f\n", P, F)

    # What the decomposition in the record needs, under the tree's own fitness.
    @printf("  score - mass = %.6f kg of penalties\n", r.fitness - m)
    pen_pow = 5.0 * max(P - 5.0, 0.0)^2
    pen_util = F > 0.0 ? 20.0 * (2.5 / F)^2 : Inf
    @printf("  check: 5.0*max(P-5,0)^2 = %.6f  20*(2.5/F)^2 = %.6f  sum = %.6f\n",
        pen_pow, pen_util, pen_pow + pen_util)
    @printf("  a manual rebuild of the same build gave 19.450762 kg (with the flat 5.0 kg lifter)\n")
    @printf("  the recorded row's algebra needs ~20.2135 kg\n")
    @printf("  residual vs the manual rebuild = %+.6f kg\n", m - 19.450762)
end

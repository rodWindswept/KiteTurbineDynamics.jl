# sv_p0_winner_reeval.jl — Phase 0 item 4: standalone re-evaluation of the
# bankderate2 winner genome (software-validator seat).
# Mirrors scripts/run_v13_5kw_masslift.jl: eval_v13 decode + cfg + lift_for +
# appropriate_mass_fitness, at the launch revision content (a76c5e9; the
# results-branch data commit dd3cc6a leaves src/ and scripts/ identical).
# Usage: cd ktd-aw-fire && scripts/ktd-julia <this file> <best_vector.csv>
using KiteTurbineDynamics, Printf
include("/home/rod/Documents/GitHub/ktd-aw-fire/scripts/compute_seeds.jl")

const KW = 5.0
const PW = KW * 1000.0
const V_RATED = 11.0
const WINDOW_S = 40.0
const MIN_CLEARANCE = 1.5
const GROUND_OFFSET = 1.0
const ELEV = pi / 6
const LENGTH = 18.8
const MIN_WALL_M = 2.0e-3

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

function main()
    csv = ARGS[1]
    p_base = params_at_length(LENGTH)
    beam_profile = PROFILE_ELLIPTICAL
    cfg = ObjectiveConfig(;
        power_W = PW, v_rated = V_RATED,
        p_floor_kw = 5.0, p_ceiling_kw = 5.0,
        relax_s = 10.0, window_s = WINDOW_S,
        fos_target = 2.5, fos_hard = 2.5,
        power_stat = :tail5, penalize_ceiling = false,
        kickstart_s = 0.0,
        k_mppt = K_MPPT_5KW_HONEST,
        tether_diameter = p_base.tether_diameter,
        rotor_count_mode = true,
        power_split = 0.6,
        cone_slope_deg = 22.0,
        rotor_spacing_frac = 0.8,
        blocking_factor = BLOCKING_WIND_FACTOR_5KW,
        min_wall_m = MIN_WALL_M,
    )
    x = [parse(Float64, s) for s in split(strip(read(csv, String)), ",")]
    xr = copy(x)
    xr[4] = Float64(round(Int, clamp(xr[4], 3, 16)))
    xr[6] = Float64(round(Int, clamp(xr[6], 1, 3)))
    println("genome (raw)       = ", x)
    println("genome (evaluated) = ", xr)

    dec = design_from_vector_v10(xr, beam_profile, p_base; power_W=PW,
        cylinder_cone=true, rotor_count_mode=true,
        power_split=cfg.power_split, cone_slope_deg=cfg.cone_slope_deg,
        rotor_spacing_frac=cfg.rotor_spacing_frac, blocking_factor=cfg.blocking_factor)
    clearance = KiteTurbineDynamics.lowest_rotor_clearance(
        dec; ground_offset=GROUND_OFFSET, elevation_deg=rad2deg(ELEV))
    @printf("decoded: n_lines=%d rings=%d n_active=%d r_hub=%.3f r_bot=%.3f\n",
        dec.design.n_lines, dec.n_rings, dec.n_active, dec.design.r_hub, dec.design.r_bottom)
    @printf("clearance = %.6f m  (gate %.1f)\n", clearance, MIN_CLEARANCE)

    t0 = time()
    r = KiteTurbineDynamics.evaluate_windowed(
        xr, beam_profile, p_base, cfg;
        start_mode = :cold,
        lift_device = lift_for,
        fitness_fn = (P, F, c, m) -> begin
            println("fitness_fn args: P_mean=", P, " FoS_min=", F, " mass=", m)
            KiteTurbineDynamics.appropriate_mass_fitness(P, F, c, m)
        end,
    )
    @printf("eval wall = %.1f s\n", time() - t0)
    println("== result fields ==")
    fns = r isa NamedTuple ? collect(keys(r)) : fieldnames(typeof(r))
    for f in fns
        println("  ", f, " = ", getfield(r, f))
    end
    println("SV_REEVAL_DONE")
end
main()

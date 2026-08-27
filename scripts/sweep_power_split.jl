#!/usr/bin/env julia
# scripts/sweep_power_split.jl
#
# Re-sweep the campaign's FIXED power_split knob (top-rotor power fraction)
# under the corrected downstream wake blocking, BEFORE launching a full 12 h
# run.  power_split interacts with blocking now: it gives the TOP rotor (the
# MOST-blocked rotor) the LARGEST power share by default (0.6).  This script
# runs the re-seeded genome (3 rotors, r_hub 2.4, blade_scale 0.7) through the
# EXACT evaluator path for a spread of power_split values and reports
# clearance / power / FoS / fitness so the operator can pick the best fixed
# value before committing compute.
#
# Usage: julia --project=. scripts/sweep_power_split.jl
#
# It mirrors run_v13_5kw_masslift.jl / smoke_masslift_v13.jl exactly (params,
# lift_for, ObjectiveConfig knobs, decode knobs), varying ONLY cfg.power_split.

using KiteTurbineDynamics, Printf
include(joinpath(@__DIR__, "compute_seeds.jl"))

const KW = 5.0
const PW = KW * 1000.0
const V_RATED = 11.0
const WINDOW_S = 40.0
const LENGTH = 18.8
const MIN_CLEARANCE = 1.5

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
    return override_params(mass_scale(SystemParams(geo, mat, aero, ctrl, back), 1.5, KW); tether_length=L)
end

p_base = params_at_length(LENGTH)
seed_v = seed_genome(KW)
seed_v[8] = Float64(round(Int, clamp(seed_v[8], 3, 16)))
seed_v[10] = Float64(round(Int, clamp(seed_v[10], 1, 3)))

println("power_split sweep — seed r_hub=", round(seed_v[5], digits=3),
        " rotors=", Int(seed_v[10]), " bs=", round(seed_v[13], digits=2),
        "  blocking=", round(BLOCKING_WIND_FACTOR_5KW, digits=4))
println("="^92)
println(rpad("power_split", 13), rpad("clearance", 11), rpad("status", 8),
        rpad("P_mean", 9), rpad("FoS", 8), rpad("fitness(kg)", 13), "note")
println("-"^92)

for ps in (0.3, 0.4, 0.5, 0.6, 0.7)
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
        power_split = ps,
        blocking_factor = BLOCKING_WIND_FACTOR_5KW,
    )
    dec = design_from_vector_v10(seed_v, PROFILE_ELLIPTICAL, p_base; power_W=PW,
        cylinder_cone=true, rotor_count_mode=true, power_split=ps,
        cone_slope_deg=22.0, rotor_spacing_frac=0.8,
        blocking_factor=BLOCKING_WIND_FACTOR_5KW)
    clr = KiteTurbineDynamics.lowest_rotor_clearance(dec)

    note = clr < MIN_CLEARANCE ? "CLEARANCE" : ""
    r = KiteTurbineDynamics.evaluate_windowed(
        seed_v, PROFILE_ELLIPTICAL, p_base, cfg;
        start_mode=:cold, lift_device=lift_for,
        fitness_fn=(P, F, c, m) -> KiteTurbineDynamics.mass_min_fitness(P, F, c, m))
    note = r.status === :ok ? note : note * (isempty(note) ? string(r.status) : "|" * string(r.status))
    @printf("%-13s %-11.2f %-8s %-9.2f %-8.2f %-13.2f %s\n",
        ps, clr, r.status, r.P_mean, r.FoS_min, r.fitness, note)
    flush(stdout)
end
println("="^92)
println("Pick the power_split whose status=ok with the lowest fitness; re-verify")
println("clearance >= 1.5 m. Then set it in run_v13_5kw_masslift.jl (cfg.power_split),")
println("ode_gate_v13.jl (power_split kwarg), smoke_masslift_v13.jl, and this script.")

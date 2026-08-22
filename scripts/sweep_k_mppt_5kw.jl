#!/usr/bin/env julia --project=.
# sweep_k_mppt_5kw.jl — k_mppt operating-point sweep for the Daisy-anchored
# 5 kW seed (Rod 2026-08-21).  Find the generator gain where the seed
# sustains ~5 kW at a productive TSR.
#
# Anchors: k_daisy(6-blade) = 0.175 @ 1.5 kW → scaled k = 0.175·(5/1.5)^2.5 = 2.24
#          k_daisy(3-blade) = 0.42  @ 1.5 kW → scaled k = 0.42·(5/1.5)^2.5  = 5.39
#          theory (params_10kw mass_scale) = 1.94
#
# Usage: julia --project=. scripts/sweep_k_mppt_5kw.jl
using KiteTurbineDynamics, Printf, CSV, DataFrames
include(joinpath(@__DIR__, "compute_seeds.jl"))

const KW = 5.0
const PW = KW * 1000.0
const V_RATED = 11.0
const WINDOW_S = 20.0
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
    # LENGTH FIX (2026-08-22): mass_scale also scales the tether length by the
    # rung geom_scale (sqrt(5/1.5) ~ 1.826), so params_at_length(18.8) silently
    # built a 34.3 m machine while h_ref/masses described an 18.8 m machine.
    # L is the FINAL machine length — restore it after rung scaling.
    return override_params(scaled; tether_length=L)
end

p_base = params_at_length(LENGTH)
@printf("Daisy-anchored p_base: k_mppt=%.4f  i_pto=%.3f  tether=%.4f m  m_blade=%.4f kg  n_lines=%d  cp=%.3f  h_ref=%.2f\n",
    p_base.k_mppt, p_base.i_pto, p_base.tether_diameter, p_base.m_blade,
    p_base.n_lines, p_base.cp, p_base.h_ref)

const K_SWEEP = [0.5, 1.0, 1.5, 1.94, 2.24, 3.0, 4.0, 5.39, 7.0, 9.0]

seed_v = seed_genome(KW)
lo, hi = tight_bounds(seed_v, KW)
xr = clamp.(copy(seed_v), lo, hi)
xr[8] = Float64(round(Int, clamp(xr[8], 3, 16)))
xr[10] = clamp(xr[10], 0.0, Float64(N_VALID_MASKS))

# Decoded geometry (mass + annulus) for reference
dec = design_from_vector_v10(xr, PROFILE_ELLIPTICAL, p_base; power_W=PW)
sys0, u0, pc0 = KiteTurbineDynamics.build_system_from_v10(
    dec, 1.0, p_base.k_mppt; tether_diameter=p_base.tether_diameter, base_params=p_base)
m_air = KiteTurbineDynamics.expansion_airborne_mass(sys0, pc0; include_lifter=false)
@printf("seed: r_hub=%.3f r_bottom=%.3f n_lines=%d n_rings=%d n_active=%d  m_airborne(no lifter)=%.2f kg (φ=%.2f kg/kW)\n",
    dec.design.r_hub, dec.design.r_bottom, dec.design.n_lines, dec.n_rings, dec.n_active,
    m_air, m_air / KW)
@printf("hub rotor: r_out=%.3f  r_in=%.3f  annulus A=%.2f m²\n",
    sys0.rotor.radius, sys0.rotor.blade_hub_radius,
    π * (sys0.rotor.radius^2 - sys0.rotor.blade_hub_radius^2))

rows = DataFrame(k=Float64[], status=Symbol[], P_mean=Float64[], P_end=Float64[],
                 omega_eq=Float64[], FoS_min=Float64[], T_lift=Float64[], wall_s=Float64[])
println("\n═ k sweep — seed via runner path (mass_min, cold, L=$LENGTH) ═")
for k in K_SWEEP
    cfg = ObjectiveConfig(;
        power_W = PW, v_rated = V_RATED,
        p_floor_kw = 5.0, p_ceiling_kw = 5.0,
        relax_s = 5.0, window_s = WINDOW_S,
        fos_target = 2.5, fos_hard = 2.5,
        power_stat = :tail5, penalize_ceiling = false,
        kickstart_s = 0.0,
        k_mppt = k,
        tether_diameter = p_base.tether_diameter,
    )
    t0 = time()
    r = KiteTurbineDynamics.evaluate_windowed(
        xr, PROFILE_ELLIPTICAL, p_base, cfg;
        start_mode = :cold,
        lift_device = lift_for,
        fitness_fn = (P, F, c, m) -> KiteTurbineDynamics.mass_min_fitness(P, F, c, m),
    )
    wall = time() - t0
    push!(rows, (k, r.status, r.P_mean, r.P_end, r.ω_eq, r.FoS_min, r.T_lift, wall))
    @printf("k=%5.2f  status=%-6s  P_mean=%6.2f kW  P_end=%6.2f kW  ω_eq=%6.2f  FoS=%6.2f  T_lift=%7.1f N  (%4.0f s)\n",
        k, r.status, r.P_mean, r.P_end, r.ω_eq, r.FoS_min, r.T_lift, wall)
    flush(stdout)
end

OUT = joinpath(@__DIR__, "results", "k_sweep_daisy_5kw.csv")
mkpath(dirname(OUT))
CSV.write(OUT, rows)
println("\nSweep written to $OUT")

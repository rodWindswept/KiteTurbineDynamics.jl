#!/usr/bin/env julia
# analyze_campaign_winners.jl — decode + verify the 5 kW campaign winners.
#
# Reads each island_N_best.csv in the campaign results dir, decodes the
# genome, and reports the physics: geometry, airborne-mass decomposition,
# phi (kg/kW), and the k·omega^2 operating point vs the tau_max_safe clamp.
# Also screens for the FoS=Inf signature (the campaign's DE ran pre-guard,
# commit 402697b; the re-gate must confirm it per winner).
#
# Usage: julia --project=. scripts/analyze_campaign_winners.jl [results_dir]
using KiteTurbineDynamics, Printf, LinearAlgebra

const KW = 5.0
const PW = KW * 1000.0
const V_RATED = 11.0
const K_MPPT = 2.24          # campaign cfg k_mppt (runner, 2026-08-22)
const LENGTH = 18.8

OUT_DIR = length(ARGS) > 0 ? ARGS[1] :
          joinpath(@__DIR__, "results", "v13_5kw_masslift_len18.8")

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

p_base = params_at_length(LENGTH)

println("═"^70)
println("  5 kW campaign winner analysis   dir: $OUT_DIR")
println("  base: params_daisy scaled 1.5 → 5 kW, L=$LENGTH m, k=$K_MPPT (cfg)")
println("═"^70)

files = sort(filter(f -> occursin(r"island_[123]_best\.csv", f), readdir(OUT_DIR)))
isempty(files) && error("no island_N_best.csv files in $OUT_DIR")

for f in files
    x = [parse(Float64, s) for s in split(strip(read(joinpath(OUT_DIR, f), String)), ",")]
    result = design_from_vector_v10(x, PROFILE_ELLIPTICAL, p_base; power_W=PW, v_rated=V_RATED)
    sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(
        result, 1.0, K_MPPT; base_params=p_base)

    A = π * (sys.rotor.radius^2 - sys.rotor.blade_hub_radius^2)
    m_air = expansion_airborne_mass(sys, pc; include_lifter=false)
    m_air_l = expansion_airborne_mass(sys, pc; include_lifter=true)

    println("\n── $f ─────────────────────────────────────────")
    println("  n_lines=$(pc.n_lines)  rings(design)=$(result.n_rings)  n_active=$(result.n_active)")
    println("  r_hub=$(round(result.design.r_hub, digits=3)) m  r_bottom=$(round(result.design.r_bottom, digits=3)) m")
    println("  rotor r_out=$(round(sys.rotor.radius, digits=3)) m  r_in=$(round(sys.rotor.blade_hub_radius, digits=3)) m")
    println("  annulus A=$(round(A, digits=2)) m²")
    println("  blade_scale top/bot=$(round(result.rotors[1].blade_scale, digits=3))")
    println("  bank top/bot=$(round(result.design.r_hub > 0 ? x[11] : 0.0, digits=1))° / $(round(x[12], digits=1))°")
    println("  m_airborne = $(round(m_air, digits=3)) kg (no lifter) / $(round(m_air_l, digits=3)) kg (with lifter)")
    println("  phi = $(round(m_air / KW, digits=3)) kg/kW  (Daisy anchor ≈ 1.3)")
    # Operating point at the rated power the machine must sustain (5 kW floor)
    w5 = (5000.0 / K_MPPT)^(1 / 3)
    tau5 = K_MPPT * w5^2
    tau_cap = 2500.0 * (pc.p_rated_w / 10000.0)^2
    println("  @ 5 kW (k=$K_MPPT): omega=$(round(w5, digits=2)) rad/s  TSR=$(round(w5 * sys.rotor.radius / V_RATED, digits=2))")
    println("  tau_gen=$(round(tau5, digits=1)) N·m vs tau_max_safe=$(round(tau_cap, digits=1)) N·m → ",
        tau5 > tau_cap ? "CLAMP-BINDING" : "below clamp")
    tip = w5 * sys.rotor.radius
    println("  tip speed @ 5 kW = $(round(tip, digits=1)) m/s (ceiling 100)")
    # FoS=Inf screening note (the gate performs the authoritative check)
    println("  SCREEN: re-gate must confirm finite FoS + no twist + clearance (ode_gate_v13.jl)")
end

println("\nNote: run the authoritative pass with: julia --project=. scripts/ode_gate_v13.jl <winner.csv> --length 18.8 --kw 5")

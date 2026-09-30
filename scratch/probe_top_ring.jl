#!/usr/bin/env julia --project=.
#= probe_top_ring.jl — who owns the top ring for the campaign winner?

Builds the winner with the gate's own recipe (scripts/ode_gate_v13.jl:87-120)
and reports the arbitration inputs and outcome. No ODE solve — structural only.
=#

using KiteTurbineDynamics, Printf, LinearAlgebra

include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "scripts", "ode_gate_v13.jl"))

const KW = 5.0
const L18 = 18.8
const WINNER_CSV = joinpath(
    @__DIR__,
    "..",
    "scripts",
    "results",
    "v13_5kw_masslift_len18.8_rotorcount",
    "best_vector.csv",
)

x = [parse(Float64, s) for s in split(strip(read(WINNER_CSV, String)), ",")]
println("=== winner genome (length ", length(x), ") ===")
println(x)

xv = copy(x)
if length(xv) >= 14
    xv[8] = Float64(round(Int, clamp(xv[8], 3, 16)))
    xv[10] = Float64(round(Int, clamp(xv[10], 1, 3)))
    @printf("bank genes: x[11]=bank_top=%.4f deg   x[12]=bank_bottom=%.4f deg\n", xv[11], xv[12])
end

p = params_at_length(params_daisy(), L18, KW)
bf = BLOCKING_WIND_FACTOR_5KW
dec = design_from_vector_v10(
    xv,
    PROFILE_ELLIPTICAL,
    p;
    power_W=KW * 1000.0,
    cylinder_cone=true,
    rotor_count_mode=true,
    power_split=0.6,
    cone_slope_deg=22.0,
    rotor_spacing_frac=0.8,
    blocking_factor=bf,
)

println("\n=== decoded rotors (design vector) ===")
for (i, r) in enumerate(dec.rotors)
    println("rotor $i: ", [(f, getfield(r, f)) for f in fieldnames(typeof(r))])
    println("   is_banked_rotor = ", KiteTurbineDynamics.is_banked_rotor(r))
end

cfg_gate = KiteTurbineDynamics.ObjectiveConfig(;
    power_W=KW * 1000.0,
    v_rated=11.0,
    p_floor_kw=KW,
    fos_target=2.5,
    fos_hard=2.5,
    min_wall_m=2e-3,
    t_over_D=0.055,
    rotor_count_mode=true,
    power_split=0.6,
    blocking_factor=bf,
)
sizing = KiteTurbineDynamics.size_beams_closed_form(dec, p, cfg_gate)
sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(
    dec,
    1.0,
    K_MPPT_5KW_HONEST;
    tether_diameter=p.tether_diameter,
    base_params=p,
    min_wall_m=2e-3,
    beam_sizing=sizing,
)

println("\n=== built system: top-ring arbitration ===")
println("sys.n_ring = ", sys.n_ring)
println("length(sys.expansion_rotors) = ", length(sys.expansion_rotors))
for (i, er) in enumerate(sys.expansion_rotors)
    @printf(
        "  expansion rotor %d: ring_idx=%d  bank=%.4f deg  n_blades=%d  tip=%.4f m  hub=%.4f m  chord=%.4f m  mass=%.4f kg  wind_factor=%.4f  shaft_coupling=%.4f\n",
        i,
        er.ring_idx,
        er.bank_angle_deg,
        er.n_blades,
        er.blade_tip_radius,
        er.blade_hub_radius,
        er.blade_chord,
        er.mass,
        er.wind_factor,
        er.shaft_coupling,
    )
end
hte = KiteTurbineDynamics.has_top_expansion(sys)
println("has_top_expansion(sys) = ", hte)
println(hte ? "=> the DISK model at the top ring is SKIPPED" : "=> the DISK model at the top ring RUNS")

# Physical cross-check: the yaw-misalignment analogy the repo already uses for
# its pitched offset (Tulloch).  A banked rotor is a misaligned rotor; the
# classic power derate is cos^3(beta).
if length(xv) >= 14
    bk = xv[11]
    @printf(
        "\ncross-check: cos^3(bank=%.2f deg) = %.4f  -> 5.46 kW * that = %.3f kW\n",
        bk,
        cosd(bk)^3,
        5.46 * cosd(bk)^3,
    )
end

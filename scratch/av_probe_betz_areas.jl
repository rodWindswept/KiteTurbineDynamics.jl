# av_probe_betz_areas.jl — aero-validator, 2026-10-02
#
# Print exactly the geometry the projected-Betz-ceiling RED test will pin, for
# BOTH winners, through the campaign's own decode/build.  No ODE.
#
# Answers: the un-fold ground truth (dec.design.r_hub), the bank-projected
# annulus under the offset form, the raw axis annulus, the wind-normal factor,
# and the correctness ratio raw/projected.

using KiteTurbineDynamics, Printf

const ROOT = dirname(@__DIR__)
include(joinpath(ROOT, "scripts", "compute_seeds.jl"))
include(joinpath(ROOT, "scripts", "ode_gate_v13.jl"))   # decode_winner (CLI-guarded)

const KW = 5.0
const L18 = 18.8

const WINNERS = [
    "bank-derate (10-D)" =>
        joinpath(ROOT, "scripts", "results",
            "v13_5kw_masslift_len18.8_rotorcount_bankderate", "best_vector.csv"),
    "pre-derate (14-D)" =>
        joinpath(ROOT, "scripts", "results",
            "v13_5kw_masslift_len18.8_rotorcount", "best_vector.csv"),
]

raw_annulus(sys) = π * (sys.rotor.radius^2 - sys.rotor.blade_hub_radius^2)

for (label, csv) in WINNERS
    x = [parse(Float64, s) for s in split(strip(read(csv, String)), ",")]
    d = decode_winner(x; L=L18, KW=KW)
    sys, _u0, _pc = KiteTurbineDynamics.build_system_from_v10(
        d.dec, 1.0, d.k_mp; tether_diameter=d.p.tether_diameter, base_params=d.p,
    )
    p = d.p
    r = sys.rotor
    β = r.bank_angle_deg
    cb = cosd(β)
    span = r.radius - r.blade_hub_radius
    r_ring = 0.3 * r.radius + 0.7 * r.blade_hub_radius
    r_out = r_ring + 0.7 * span * cb
    r_in = max(r_ring - 0.3 * span * cb, 0.0)
    A_bank = π * (r_out^2 - r_in^2)
    A_raw = raw_annulus(sys)
    ce = cos(p.elevation_angle)

    println("="^72)
    println(label, "   ", basename(dirname(csv)), "/best_vector.csv")
    println("  genome length           = ", length(x))
    @printf("  sys.rotor.radius        = %.10f\n", r.radius)
    @printf("  sys.rotor.blade_hub_rad = %.10f\n", r.blade_hub_radius)
    @printf("  sys.rotor.bank_deg      = %.10f   cos = %.10f\n", β, cb)
    @printf("  dec.design.r_hub        = %.10f\n", d.dec.design.r_hub)
    @printf("  dec.n_active=%d  n_rotors=%d  n_expansion_sys=%d\n",
        d.dec.n_active, length(d.dec.rotors), length(sys.expansion_rotors))
    @printf("  un-fold: span = %.10f   r_ring = %.10f   (r_hub err %.3e)\n",
        span, r_ring, r_ring - d.dec.design.r_hub)
    @printf("  un-fold back: r_ring+0.7span = %.12f  vs radius %.12f\n",
        r_ring + 0.7 * span, r.radius)
    @printf("  r_out'=%.10f  r_in'=%.10f\n", r_out, r_in)
    @printf("  BEM.annulus_area(r_ring,span;bank) = %.10f\n",
        KiteTurbineDynamics.BEM.annulus_area(r_ring, span; bank_deg=β))
    @printf("  main_rotor_swept_area (raw)        = %.10f\n", A_raw)
    @printf("  A_bank (offset form)               = %.10f\n", A_bank)
    @printf("  A_raw x cos(bank)                  = %.10f  (first-order form)\n", A_raw * cb)
    @printf("  p.elevation_angle = %.10f rad (%.4f deg)  cos = %.10f\n",
        p.elevation_angle, rad2deg(p.elevation_angle), ce)
    @printf("  A_ZY (A_raw x cos elev)            = %.6f  <- published figure\n", A_raw * ce)
    @printf("  A_ZN (A_bank x cos elev)           = %.6f  <- correct ceiling\n", A_bank * ce)
    @printf("  leniency A_raw/A_bank = %.10f  (ceiling %.4f%% too high)\n",
        A_raw / A_bank, 100 * (A_raw / A_bank - 1))
    @printf("  leniency in A_ZY      = %.10f  (ceiling %.4f%% too high)\n",
        (A_raw * ce) / (A_bank * ce), 100 * ((A_raw * ce) / (A_bank * ce) - 1))
    # The gate itself, at the campaign's rated wind, and the tripwire it drives.
    vr = 11.0
    cel_now = 0.593 * 0.5 * p.rho * A_raw * vr^3 / 1000.0
    cel_fix = 0.593 * 0.5 * p.rho * (A_bank * ce) * vr^3 / 1000.0
    @printf("  Betz_ceiling_kW  now = %.4f   fixed = %.4f   (v_rated %.1f m/s)\n",
        cel_now, cel_fix, vr)
    @printf("  tripwire 1.1x    now = %.4f   fixed = %.4f\n", 1.1 * cel_now, 1.1 * cel_fix)
    @printf("  P_end 5.11 kW sits at %.2f%% of the FIXED tripwire, %.2f%% of the current one\n",
        100 * 5.11 / (1.1 * cel_fix), 100 * 5.11 / (1.1 * cel_now))
    println("  p.rho = ", p.rho)
end

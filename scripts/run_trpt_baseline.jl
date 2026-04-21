#!/usr/bin/env julia
# scripts/run_trpt_baseline.jl
# Item B2 — Step 5: Baseline Benchmarking.
# Single-pass evaluation of the current frame design for 10 kW and 50 kW at
# peak 25 m/s wind loads.  Writes scripts/results/trpt_opt/baseline.csv.

using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics
using CSV, DataFrames, Printf

function eval_baseline(name::String, p)
    d = baseline_design(p)
    r = evaluate_design(d; r_rotor=p.rotor_radius, elev_angle=p.elevation_angle)
    radii = ring_radii(d)
    return (
        config          = name,
        r_rotor_m       = p.rotor_radius,
        r_hub_m         = d.r_hub,
        taper_ratio     = d.taper_ratio,
        n_rings         = d.n_rings,
        Do_top_mm       = d.Do_top * 1000,
        t_over_D        = d.t_over_D,
        tether_length_m = d.tether_length,
        T_peak_N        = peak_hub_thrust(p.rotor_radius, p.elevation_angle),
        mass_total_kg   = r.mass_total_kg,
        mass_beams_kg   = r.mass_beams_kg,
        mass_knuckles_kg = r.mass_knuckles_kg,
        min_fos         = r.min_fos,
        worst_ring_idx  = r.worst_ring_idx,
        feasible        = r.feasible,
        message         = r.constraint_msg,
    )
end

function main()
    outdir = joinpath(dirname(@__DIR__), "scripts", "results", "trpt_opt")
    mkpath(outdir)

    rows = [
        eval_baseline("10 kW", params_10kw()),
        eval_baseline("50 kW", params_50kw()),
    ]
    df = DataFrame(rows)

    csv_path = joinpath(outdir, "baseline.csv")
    CSV.write(csv_path, df)

    println("=" ^ 72)
    println("TRPT Baseline Benchmark @ 25 m/s (Item B2, Step 5)")
    println("=" ^ 72)
    for row in rows
        @printf("\n[%s]\n", row.config)
        @printf("  Rotor radius      : %.3f m\n", row.r_rotor_m)
        @printf("  Hub ring radius   : %.3f m    (taper_ratio=%.3f)\n",
                 row.r_hub_m, row.taper_ratio)
        @printf("  Number of rings   : %d\n", row.n_rings)
        @printf("  Baseline Do_top   : %.2f mm  (t/D=%.3f, √R scaling)\n",
                 row.Do_top_mm, row.t_over_D)
        @printf("  Peak 25 m/s thrust: %.0f N (CT=1.0)\n", row.T_peak_N)
        @printf("  Baseline mass     : %.3f kg (beams %.3f + knuckles %.3f)\n",
                 row.mass_total_kg, row.mass_beams_kg, row.mass_knuckles_kg)
        @printf("  min FOS @25 m/s   : %.3f  (ring %d)\n",
                 row.min_fos, row.worst_ring_idx)
        @printf("  Feasible?         : %s — %s\n", row.feasible, row.message)
    end
    println("\nWrote: ", csv_path)
    println("=" ^ 72)
end

main()

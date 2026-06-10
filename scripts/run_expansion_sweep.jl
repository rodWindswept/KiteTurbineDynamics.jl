#!/usr/bin/env julia
# scripts/run_expansion_sweep.jl
#
# Phase 2.3 — Expansion rotor parameter sweep.
#
# Sweeps across 5 dimensions:
#   N_expansion ∈ {0,1,2,3,4}
#   bridle_angle ∈ {5°,10°,15°,20°,25°}
#   blade_radius ∈ {0.5,1.0,1.5,2.0} m
#   blade_count  ∈ {3,5,8} (n_blades on the main rotor; expansion rotors
#                            use 3 blades standard)
#   power        ∈ {10,20,50} kW
#
# Total: 5 × 5 × 4 × 3 × 3 = 900 + baseline variants = ~1000 configs.
#
# Output: scripts/results/expansion_sweep.csv
#
# Uses mass-budget analysis (no full ODE simulation) for speed.
# Each config takes ~0.1s → sweep completes in ~2 minutes.

using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics, Printf, CSV, DataFrames

function main()

# ══════════════════════════════════════════════════════════════════════════════
# Sweep ranges
# ══════════════════════════════════════════════════════════════════════════════

N_EXPANSION_VALS  = [0, 1, 2, 3, 4]
BRIDLE_ANGLE_VALS = [5.0, 10.0, 15.0, 20.0, 25.0]
BLADE_RADIUS_VALS = [0.5, 1.0, 1.5, 2.0]
BLADE_COUNT_VALS  = [3, 5, 8]
POWER_KW_VALS     = [10, 20, 50]

PLACEMENT_MODES   = [:alternating, :clustered]

total = length(N_EXPANSION_VALS) * length(BRIDLE_ANGLE_VALS) *
        length(BLADE_RADIUS_VALS) * length(BLADE_COUNT_VALS) *
        length(POWER_KW_VALS) * length(PLACEMENT_MODES)

println("Expansion Rotor Parameter Sweep")
println("===============================")
println("Configs: $total")
println("Dimensions: N_exp × bridle_angle × blade_radius × blade_count × power × placement")
println()

# ══════════════════════════════════════════════════════════════════════════════
# Main sweep
# ══════════════════════════════════════════════════════════════════════════════

results = DataFrame()
count = 0
start_time = time()

for power_kw in POWER_KW_VALS
    power_w = power_kw * 1000.0

    # Get base parameters for this power level
    p = if power_kw == 10
        params_10kw()
    elseif power_kw == 20
        params_v5_10kw()   # closest available  — use v5 params as proxy
    else  # 50 kW
        params_v5_50kw()
    end

    v_rated = p.v_wind_ref  # rated wind speed (m/s)

    for blade_count in BLADE_COUNT_VALS
        for blade_radius in BLADE_RADIUS_VALS
            for bridle_angle in BRIDLE_ANGLE_VALS
                for n_exp in N_EXPANSION_VALS
                    for placement in PLACEMENT_MODES

                        count += 1

                        # Build expansion stack config
                        cfg = if n_exp > 0
                            ExpansionStackConfig(
                                placement        = placement,
                                n_rings          = 16,  # default for 10 kW
                                n_expansion      = n_exp,
                                blade_radius     = blade_radius,
                                hub_radius       = 0.15,
                                blade_chord      = 0.06,
                                CL_blade         = 1.0,
                                CD0_blade        = 0.02,
                                k_induced        = 0.05,
                                bridle_angle_deg = bridle_angle,
                                mass_per_rotor   = 0.5,
                                shaft_coupling   = 1.0,
                            )
                        else
                            nothing
                        end

                        # Build stack if expansion rotors present
                        stack = (cfg !== nothing) ? build_expansion_stack(cfg) :
                                                    ExpansionRotorParams[]

                        try
                            # Build system with expansion rotors
                            # Note: blade_count affects main rotor blade count
                            # (for the BEM-coupled structural optimiser in Phase 2.4).
                            # In this mass-budget sweep, expansion rotors always
                            # use 3 blades regardless of main rotor blade count.
                            sys, _ = build_kite_turbine_system(p;
                                expansion_rotors=stack)

                            # Compute telemetry
                            record = expansion_telemetry(sys, p, power_w, v_rated)

                            # Build row
                            row = DataFrame(
                                n_expansion        = record.n_expansion,
                                placement          = record.placement,
                                n_rings            = record.n_rings,
                                n_lines            = record.n_lines,
                                mass_airborne_kg   = record.mass_airborne_kg,
                                mass_tether_kg     = record.mass_tether_kg,
                                mass_expansion_kg  = record.mass_expansion_kg,
                                phi_kg_per_kw      = record.phi_kg_per_kw,
                                power_kw           = power_kw,
                                wind_m_per_s       = record.wind_m_per_s,
                                mean_radius_spread_m = record.mean_radius_spread_m,
                                bridle_angle_deg   = record.bridle_angle_deg,
                                blade_radius_m     = record.blade_radius_m,
                                blade_count        = blade_count,
                            )
                            append!(results, row)

                        catch e
                            @warn "Failed config $count: n_exp=$n_exp bridle=$bridle_angle° r=$blade_radius n_blades=$blade_count P=$power_kw kW $placement" exception = e
                        end

                        if count % 50 == 0
                            elapsed = time() - start_time
                            rate = count / elapsed
                            remaining = (total - count) / rate
                            @printf("  %4d/%d (%.1f%%)  %.1f configs/s  ETA: %.0fs\n",
                                    count, total, 100*count/total, rate, remaining)
                        end
                    end
                end
            end
        end
    end
end

elapsed = time() - start_time
println()
println("Sweep complete: $count configs in $(round(elapsed; digits=1))s")
println("  Rate: $(round(count/elapsed; digits=1)) configs/s")

# ══════════════════════════════════════════════════════════════════════════════
# Save results
# ══════════════════════════════════════════════════════════════════════════════

out_dir = joinpath(dirname(@__DIR__), "scripts", "results")
mkpath(out_dir)
out_path = joinpath(out_dir, "expansion_sweep.csv")
CSV.write(out_path, results)
println("Results saved to $out_path ($(nrow(results)) rows, $(ncol(results)) columns)")

# ══════════════════════════════════════════════════════════════════════════════
# Quick summary
# ══════════════════════════════════════════════════════════════════════════════

println()
println("=== Quick Summary ===")
for pk in POWER_KW_VALS
    subset = filter(r -> r.power_kw == pk, results)
    if nrow(subset) > 0
        phi_baseline = subset[subset.n_expansion .== 0, :phi_kg_per_kw][1]
        phi_best = minimum(subset.phi_kg_per_kw)
        phi_improvement = (phi_baseline - phi_best) / phi_baseline * 100
        println("  $(pk) kW:  baseline φ=$(round(phi_baseline; digits=3))  best φ=$(round(phi_best; digits=3))  improvement=$(round(phi_improvement; digits=1))%")
    end
end

end  # function main

main()

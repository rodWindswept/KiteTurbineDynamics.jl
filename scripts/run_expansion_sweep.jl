#!/usr/bin/env julia
# scripts/run_expansion_sweep.jl
#
# Phase 2.3 — Expansion rotor parameter sweep.
#
# Sweeps across 3 dimensions:
#   n_expansion ∈ {0,1,2,3,4}
#   bank_angle  ∈ {5°,10°,15°,20°,30°,45°}
#   power       ∈ {10,20,50} kW
#   placement   ∈ {:alternating, :clustered}
#
# Expansion blade tip radius, hub radius, chord, and count are inherited
# from the generating rotor — same blade mould, banked downward.
#
# Total: 5 × 6 × 3 × 2 = 180 configs.
#
# Output: scripts/results/expansion_sweep.csv
#
# Uses mass-budget analysis (no full ODE simulation) for speed.
# Each config takes ~0.1s → sweep completes in <1 minute.

using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics, Printf, CSV, DataFrames

function main()

# ══════════════════════════════════════════════════════════════════════════════
# Sweep ranges
# ══════════════════════════════════════════════════════════════════════════════

N_EXPANSION_VALS  = [0, 1, 2, 3, 4]
BANK_ANGLE_VALS   = [5.0, 10.0, 15.0, 20.0, 30.0, 45.0]
POWER_KW_VALS     = [10, 20, 50]

PLACEMENT_MODES   = [:alternating, :clustered]

total = length(N_EXPANSION_VALS) * length(BANK_ANGLE_VALS) *
        length(POWER_KW_VALS) * length(PLACEMENT_MODES)

println("Expansion Rotor Parameter Sweep")
println("===============================")
println("Configs: $total")
println("Dimensions: N_exp × bank_angle × power × placement")
println("(Blade geometry inherited from generating rotor)")
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

    for bank_angle in BANK_ANGLE_VALS
        for n_exp in N_EXPANSION_VALS
            for placement in PLACEMENT_MODES

                count += 1

                # Derive blade geometry from generating rotor
                r_rotor = BEM.rotor_radius_for_power(power_w, v_rated, p.n_lines)
                blade_tip  = r_rotor
                blade_hub  = 0.25 * r_rotor   # same annulus as generating rotor
                blade_ch   = 0.113 * r_rotor   # solidity-calibrated

                cfg = if n_exp > 0
                    ExpansionStackConfig(;
                        placement=placement,
                        n_rings=16,
                        n_expansion=n_exp,
                        n_blades=p.n_blades,
                        blade_tip_radius=blade_tip,
                        blade_hub_radius=blade_hub,
                        blade_chord=blade_ch,
                        CL_blade=1.0,
                        CD0_blade=0.02,
                        k_induced=0.05,
                        bank_angle_deg=bank_angle,
                        mass_per_rotor=0.5,
                        shaft_coupling=1.0,
                    )
                else
                    nothing
                end

                # Build stack if expansion rotors present
                stack = (cfg !== nothing) ? build_expansion_stack(cfg) :
                                            ExpansionRotorParams[]

                try
                    # Build system with expansion rotors
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
                        bank_angle_deg     = record.bank_angle_deg,
                        blade_tip_radius_m = record.blade_tip_radius_m,
                        blade_count        = p.n_blades,
                    )
                    append!(results, row)

                catch e
                    @warn "Failed config $count: n_exp=$n_exp bank=$bank_angle° P=$power_kw kW $placement" exception = e
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

#!/usr/bin/env julia
# scripts/run_expansion_op_sweep.jl
#
# Operating-point sweep for expansion rotors.
#
# Sweeps wind speed × bank angle × shaft omega for a fixed expansion rotor
# configuration, computing τ_net (lift tangential − drag tangential),
# F_radial, F_axial, and power contribution at each point.
#
# Paper output: parasitic power trade-off (Phase 2.5, item 3).
#
# Total: 6 wind speeds × 6 bank angles × 8 omega points = 288 configs.
# Each config is analytical (no ODE) → sweep completes in <1 second.
#
# Usage:
#   julia --project=. scripts/run_expansion_op_sweep.jl
#
# Output:
#   scripts/results/expansion_op_sweep.csv

using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics, Printf, CSV, DataFrames

function main()

# ══════════════════════════════════════════════════════════════════════════════
# Sweep ranges
# ══════════════════════════════════════════════════════════════════════════════

WIND_SPEEDS   = [4.0, 6.0, 8.0, 10.0, 12.0, 15.0]        # m/s (cut-in → above rated)
BANK_ANGLES   = [5.0, 10.0, 15.0, 20.0, 30.0, 45.0]       # degrees
OMEGA_SHAFT   = [3.0, 5.0, 7.0, 9.0, 10.0, 12.0, 15.0, 20.0]  # rad/s
ELEVATION     = 30.0                                        # degrees (fixed)
N_BLADES      = 8
R_NOMINAL     = 2.0                                         # ring radius (m)
BLADE_SPAN    = 2.4                                         # m
BLADE_CHORD   = 0.15                                        # m
CL            = 1.0
CD0           = 0.02
K_INDUCED     = 0.05
RHO           = 1.225
N_EXPANSION   = 3                                           # typical config

total = length(WIND_SPEEDS) * length(BANK_ANGLES) * length(OMEGA_SHAFT)

println("Expansion Rotor Operating-Point Sweep")
println("=====================================")
println("Configs: $total")
println("Axes: wind_speed × bank_angle × omega_shaft")
println("Fixed: elevation=30°, r_nom=2.0m, n_blades=8, span=2.4m, chord=0.15m")
println()

# ══════════════════════════════════════════════════════════════════════════════
# Sweep
# ══════════════════════════════════════════════════════════════════════════════

results = DataFrame()
count = 0
start_time = time()

elev_rad = deg2rad(ELEVATION)

for v_wind in WIND_SPEEDS
    for bank_deg in BANK_ANGLES
        bank_rad = deg2rad(bank_deg)

        for omega in OMEGA_SHAFT
            count += 1

            # Wind component along shaft axis
            v_axial = v_wind * cos(elev_rad)
            v_tan   = omega * R_NOMINAL
            v_app   = sqrt(v_axial^2 + v_tan^2)

            # Inflow angle from rotation plane
            phi = atan(v_axial, v_tan)

            # Dynamic pressure
            q = 0.5 * RHO * v_app^2

            # Per-blade lift and drag
            L = q * BLADE_CHORD * BLADE_SPAN * CL
            D = q * BLADE_CHORD * BLADE_SPAN * (CD0 + K_INDUCED * CL^2)

            # Tangential components (in rotation plane)
            L_tan = L * sin(phi) * cos(bank_rad)   # drives rotation
            D_tan = D * cos(phi)                     # opposes rotation

            # Net shaft torque per expansion rotor
            tau_lift = N_BLADES * L_tan * R_NOMINAL
            tau_drag = N_BLADES * D_tan * R_NOMINAL
            tau_net  = tau_lift - tau_drag

            # Radial and axial forces (ring spreading & thrust)
            F_radial = N_BLADES * L * cos(phi) * sin(bank_rad)
            F_axial  = N_BLADES * L * cos(phi) * cos(bank_rad)

            # Power contribution (per rotor)
            P_kW = tau_net * omega / 1000.0

            # TSR analogue for this operating point
            lambda = omega * R_NOMINAL / max(v_wind, 0.1)

            # Lift-to-drag ratio at this operating point
            LD = L / max(D, 1e-9)

            row = DataFrame(
                v_wind_m_s       = v_wind,
                bank_angle_deg   = bank_deg,
                omega_rad_s      = omega,
                v_axial_m_s      = round(v_axial; digits=2),
                v_app_m_s        = round(v_app; digits=2),
                phi_inflow_deg   = round(rad2deg(phi); digits=2),
                lambda           = round(lambda; digits=2),
                L_per_blade_N    = round(L; digits=1),
                D_per_blade_N    = round(D; digits=1),
                LD_ratio         = round(LD; digits=1),
                F_radial_N       = round(F_radial; digits=1),
                F_axial_N        = round(F_axial; digits=1),
                tau_lift_Nm      = round(tau_lift; digits=1),
                tau_drag_Nm      = round(tau_drag; digits=1),
                tau_net_Nm       = round(tau_net; digits=1),
                P_per_rotor_kW   = round(P_kW; digits=3),
                P_total_3rotors_kW = round(3 * P_kW; digits=3),
            )
            append!(results, row)
        end
    end
end

elapsed = time() - start_time
println("Sweep complete: $count configs in $(round(elapsed; digits=2))s")

# ══════════════════════════════════════════════════════════════════════════════
# Save
# ══════════════════════════════════════════════════════════════════════════════

out_dir = joinpath(dirname(@__DIR__), "scripts", "results")
mkpath(out_dir)
out_path = joinpath(out_dir, "expansion_op_sweep.csv")
CSV.write(out_path, results)
println("Results saved to $out_path ($(nrow(results)) rows, $(ncol(results)) columns)")

# ══════════════════════════════════════════════════════════════════════════════
# Quick summary: find the operating envelope
# ══════════════════════════════════════════════════════════════════════════════

println()
println("=== Quick Summary ===")
println()

# Where is τ_net positive (net driving) vs negative (net braking)?
driving = filter(r -> r.tau_net_Nm > 0, results)
braking = filter(r -> r.tau_net_Nm < 0, results)
println("Net DRIVING  (τ_net > 0): $(nrow(driving))/$(nrow(results)) configs ($(round(nrow(driving)/nrow(results)*100;digits=0))%)")
println("Net BRAKING   (τ_net < 0): $(nrow(braking))/$(nrow(results)) configs ($(round(nrow(braking)/nrow(results)*100;digits=0))%)")

# At rated operating point (v=11 m/s, ω=9.5 rad/s)
rated = filter(r -> abs(r.v_wind_m_s - 11.0) < 0.1 &&
                      abs(r.omega_rad_s - 9.5) < 0.5, results)
if nrow(rated) > 0
    println()
    println("At rated point (v≈11 m/s, ω≈9.5 rad/s):")
    for row in eachrow(rated)
        dir = row.tau_net_Nm > 0 ? "DRIVING" : "BRAKING"
        println("  bank=$(Int(row.bank_angle_deg))°  τ_net=$(round(row.tau_net_Nm;digits=0)) N·m  P=$(round(row.P_per_rotor_kW;digits=2)) kW/rotor  ($dir)")
    end
end

# Transition point: where does net torque cross zero?
println()
println("=== Transition Analysis ===")
for bank_deg in BANK_ANGLES
    subset = filter(r -> abs(r.bank_angle_deg - bank_deg) < 0.1, results)
    # Find omega where τ_net crosses from negative to positive at a given wind speed
    for vw in [6.0, 10.0, 15.0]
        ss = filter(r -> abs(r.v_wind_m_s - vw) < 0.1, subset)
        ss_sorted = sort(ss, :omega_rad_s)
        crossing = nothing
        for i in 2:nrow(ss_sorted)
            if ss_sorted[i-1, :tau_net_Nm] <= 0 && ss_sorted[i, :tau_net_Nm] > 0
                crossing = (omega_lo=ss_sorted[i-1, :omega_rad_s],
                           omega_hi=ss_sorted[i, :omega_rad_s])
                break
            end
        end
        if crossing !== nothing
            println("  bank=$(Int(bank_deg))°  v=$(Int(vw)) m/s:  τ_net crosses zero between ω=$(crossing.omega_lo) and $(crossing.omega_hi) rad/s")
        end
    end
end

println()
println("Done.")

end

main()

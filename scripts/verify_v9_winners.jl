#!/usr/bin/env julia
# Quick verification of V9.0 50kW and 10kW campaign winners
# Run: julia --project=. scripts/verify_v9_winners.jl

using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics, Printf, LinearAlgebra

function verify_campaign(dir::String, label::String, power_W::Float64, p_params)
    println("═"^60)
    println("  $label")
    println("═"^60)

    vec_path = joinpath(dirname(@__DIR__), "scripts", "results", dir, "best_vector.csv")
    x_raw = parse.(Float64, split(readline(vec_path), ","))

    x = copy(x_raw)
    x[8] = Float64(round(Int, clamp(x[8], 3, 24)))
    x[10] = Float64(round(Int, clamp(x[10], 0, 20)))

    n_lines = Int(x[8])
    n_exp = Int(x[10])
    bank = clamp(x[11], 5.0, 25.0)
    blade_s = clamp(x[12], 0.005, 2.0)

    println("  Raw vector:   n_lines=$(round(x_raw[8];digits=2))  n_exp=$(round(x_raw[10];digits=2))")
    println("  Rounded:      n_lines=$n_lines  n_exp=$n_exp")

    # Evaluate through objective_v6
    result = objective_v6(x, PROFILE_ELLIPTICAL, p_params;
        power_W=power_W, max_ground_radius=5.0, v_rated=11.0)
    feasible = result < 1_000_000
    mass = feasible ? result : result - 1_000_000
    @printf("  objective_v6: %.3f kg  %s\n", mass, feasible ? "✓ FEASIBLE" : "✗ INFEASIBLE")

    # Build design
    nt = design_from_vector_v6(x_raw, PROFILE_ELLIPTICAL, p_params;
        max_ground_radius=5.0, power_W=power_W, v_rated=11.0)
    design = nt.design

    # Compute ring geometry
    zs, radii, _ = ring_spacing_v4(
        design.r_hub, design.r_bottom, design.tether_length, design.target_Lr;
        density_profile=design.density_profile
    )
    nr = length(zs)

    println("  Design:")
    println("    n_lines=$n_lines  n_exp=$n_exp  bank=$(round(bank;digits=1))°  λ=$(round(blade_s;digits=3))")
    println("    r_hub=$(round(design.r_hub;digits=3)) m  r_bottom=$(round(design.r_bottom;digits=3)) m")
    println("    n_rings=$nr  tether=$(round(design.tether_length;digits=1)) m  L_total=$(round(zs[end];digits=1)) m")
    println("    density_profile=$(round(design.density_profile;digits=3))")
    println("    Do_top=$(round(x_raw[1]*1000;digits=1)) mm  t/D=$(round(x_raw[2];digits=6))  Do_scale=$(round(x_raw[4];digits=3))")
    println("    beam_aspect=$(round(x_raw[3];digits=3))  target_Lr=$(round(x_raw[7];digits=3))")

    # Equilibrium ω scan
    println("  Equilibrium scan:")
    try
        ω_eq, r_hub_rotor = solve_equilibrium_self_consistent(
            design, nt.stack, p_params, n_lines;
            P_per_rotor=power_W, v_wind=11.0, elev_rad=π/6, max_iter=8
        )
        if ω_eq === nothing
            println("    ** NO EQUILIBRIUM — air brake at all ω **")
        else
            rpm = ω_eq * 60 / (2π)
            λ_eq = ω_eq * r_hub_rotor / 11.0
            P_aero_hub = 0.5 * 1.225 * 11.0^3 * π * r_hub_rotor^2 * BEM.cp_at_tsr(clamp(λ_eq, 0, 8)) * cos(π/6)^2.65
            P_beam, P_tether, P_exp_drag, P_par = parasitic_drag_power(
                design, nt.stack, p_params, n_lines; omega=ω_eq, v_wind=11.0, elev_rad=π/6
            )
            P_net = P_aero_hub - P_par - power_W
            @printf("    ω_eq = %.2f rad/s (%.1f rpm)  TSR = %.2f\n", ω_eq, rpm, λ_eq)
            @printf("    r_hub_rotor = %.3f m\n", r_hub_rotor)
            @printf("    P_aero_hub = %.1f kW\n", P_aero_hub/1000)
            @printf("    P_par = %.1f kW  (beam=%.3f  tether=%.3f  exp=%.3f)\n",
                    P_par/1000, P_beam/1000, P_tether/1000, P_exp_drag/1000)
            @printf("    P_net = %.1f kW\n", P_net/1000)
            if P_net > 0
                println("    ✓ Net positive — can spin and generate rated power")
            else
                println("    ✗ Net negative — would decelerate below rated")
            end
        end
    catch e
        println("    Equilibrium solve FAILED: $(typeof(e)): $(e)")
    end

    # Ring geometry
    println("  Ring geometry ($nr rings):")
    show_n = min(3, nr)
    for i in 1:show_n
        println("    ring $i: z=$(round(zs[i];digits=2))  r=$(round(radii[i];digits=3))")
    end
    if nr > 2*show_n
        println("    ...")
    end
    for i in max(show_n+1, nr-show_n+1):nr
        println("    ring $i: z=$(round(zs[i];digits=2))  r=$(round(radii[i];digits=3))")
    end

    println()
    return feasible, mass
end

# ── 50kW ──
p50 = params_v5_50kw()
f50, m50 = verify_campaign("v9_0_campaign_50kw", "V9.0 50kW Winner", 50000.0, p50)

# ── 10kW ──
p10 = params_10kw()
f10, m10 = verify_campaign("v9_0_campaign_10kw", "V9.0 10kW Winner", 10000.0, p10)

# ── Summary ──
println("═"^60)
println("  SUMMARY")
println("═"^60)
@printf("  50kW: %.3f kg  %s\n", m50, f50 ? "✓ FEASIBLE" : "✗ INFEASIBLE")
@printf("  10kW: %.3f kg  %s\n", m10, f10 ? "✓ FEASIBLE" : "✗ INFEASIBLE")
@printf("  Mass/power: %.3f kg/kW (50kW)  %.3f kg/kW (10kW)\n", m50/50, m10/10)

predicted_m10 = m50 * (10/50)^(2/3)
@printf("  Square-cube prediction: %.2f kg (actual: %.2f kg, ratio: %.3f)\n",
        predicted_m10, m10, m10/predicted_m10)

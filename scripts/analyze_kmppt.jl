#!/usr/bin/env julia
# Quick static analysis of k_mppt equilibrium for V6.2 design
using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics, Printf

function main()
    R = 10.591991451982997
    ρ = 1.225
    v_rated = 11.0
    P_rated = 50000.0
    elev = 30.0
    k_mppt = 614.9
    ω_design = 4.1 * v_rated / R

    println("V6.2 Static Equilibrium Analysis")
    println("R=$(R) m, n_lines=12, v=$(v_rated) m/s, k_mppt=$(k_mppt)")
    println("Design ω = $(round(ω_design;digits=2)) rad/s ($(round(Int, ω_design*60/(2π))) rpm)")
    println()

    # Find all P_aero = P_gen crossings
    crossings = Tuple{Float64,Float64,Float64}[]
    prev_net = nothing

    for w in range(15.0, 0.5; length=200)
        λ = clamp(w * R / v_rated, 0.0, 8.0)
        cp = cp_at_tsr(λ)
        P_aero = 0.5 * ρ * v_rated^3 * π * R^2 * cp * cosd(elev)^2.65 / 1000
        P_gen = k_mppt * w^3 / 1000
        net = P_aero - P_gen
        if prev_net !== nothing && sign(net) != sign(prev_net)
            push!(crossings, (w, P_aero, P_gen))
        end
        prev_net = net
    end

    println("All crossings (P_aero = P_gen):")
    if isempty(crossings)
        println("  NONE found!")
        # Check endpoints
        for w in [15.0, 0.5]
            λ = clamp(w * R / v_rated, 0.0, 8.0)
            cp = cp_at_tsr(λ)
            P_aero = 0.5 * ρ * v_rated^3 * π * R^2 * cp * cosd(elev)^2.65 / 1000
            P_gen = k_mppt * w^3 / 1000
            net = P_aero - P_gen
            @printf("  ω=%.1f: P_aero=%.0f kW  P_gen=%.0f kW  net=%+.0f kW\n", w, P_aero, P_gen, net)
        end
    else
        for (i, (w, Pa, Pg)) in enumerate(crossings)
            @printf("  #%d: ω=%.2f rad/s (%d rpm)  P=%.0f kW (%.0f%% rated)\n",
                    i, w, round(Int, w*60/(2π)), Pa, Pa*1000/P_rated*100)
        end
    end

    # Dashboard operating point
    w_dash = 8.59
    λ_dash = clamp(w_dash * R / v_rated, 0.0, 8.0)
    cp_dash = cp_at_tsr(λ_dash)
    P_aero_dash = 0.5 * ρ * v_rated^3 * π * R^2 * cp_dash * cosd(elev)^2.65 / 1000
    P_gen_dash = k_mppt * w_dash^3 / 1000
    @printf("\nDashboard point: ω=8.59 rad/s (82 rpm)  λ=%.1f\n", λ_dash)
    @printf("  P_aero=%.0f kW  P_gen=%.0f kW  net=%+.0f kW\n", P_aero_dash, P_gen_dash, P_aero_dash-P_gen_dash)

    # Also check: what k_mppt would give P=P_rated at ω=4.26?
    Cp_design = BEM.cp_bem(12, 4.1)
    P_aero_design = 0.5 * ρ * v_rated^3 * π * R^2 * Cp_design * cosd(elev)^2.65
    k_correct = P_aero_design / (ω_design^3)
    @printf("\nFor equilibrium at design ω=%.2f: k_mppt=%.1f (vs current %.1f)\n", ω_design, k_correct, k_mppt)
    @printf("Difference: %.1f%%\n", (k_correct/k_mppt - 1) * 100)
end

main()

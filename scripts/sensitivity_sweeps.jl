#!/usr/bin/env julia
# scripts/sensitivity_sweeps.jl — v2: with intelligent parameter coupling
# When varying n_lines, also scale Do_top to maintain similar per-beam stress.
# When varying β, redistribute ring positions.
# When varying n_exp, scale blade parameters.

using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics
using Printf, Dates

const OPT = (
    Do_top       = 0.0949437454281317,
    t_over_D     = 0.01,
    beam_aspect  = 1.0000000054647131,
    Do_scale_exp = 0.7086247061538968,
    r_hub        = 5.396543964537164,
    r_bottom     = 1.0485906027920717,
    target_Lr    = 2.9812179574495206,
    n_lines      = 12,
    density_profile = -0.12856962561009427,
    n_expansion  = 1,
    bank_angle_deg = 45.0,
    blade_tip_radius = 10.591991451982997,
    power_kw     = 50,
    max_ground_radius = 5.0,
)

function evaluate(x::Vector{Float64})
    xr = copy(x)
    xr[8] = round(Int, clamp(x[8], 3, 12))
    xr[10] = round(Int, clamp(x[10], 0, 6))
    p = params_v5_50kw()
    mgr = OPT.max_ground_radius
    mass = objective_v6(xr, PROFILE_ELLIPTICAL, p; power_W=Float64(OPT.power_kw * 1000), max_ground_radius=mgr)
    return mass
end

# ═══════════════════════════════════════════════════════════════════
# Sweep 1: n_lines — scale Do_top to maintain per-beam compression
# ═══════════════════════════════════════════════════════════════════
function sweep_nlines()
    println("=== Sweep 1: n_lines (with Do scaling) ===")
    open("scripts/results/sweep_nlines.csv", "w") do io
        println(io, "n_lines,Do_top_mm,mass_kg,feasible")
        for n in 3:12
            # Scale Do_top so per-beam compression stays ~constant:
            # At optimum n=12: per-beam force ∝ 1/sin(π/12), Do=94.9mm
            # At other n: Do ∝ sqrt(per-beam force) ∝ 1/sqrt(sin(π/n))
            # Do(n) = Do_opt × sqrt(sin(π/12)/sin(π/n))
            Do_scaled = OPT.Do_top * sqrt(sin(π/12) / sin(π/n))

            x = Float64[
                Do_scaled, OPT.t_over_D, OPT.beam_aspect, OPT.Do_scale_exp,
                OPT.r_hub, OPT.r_bottom, OPT.target_Lr, Float64(n),
                OPT.density_profile, Float64(OPT.n_expansion), OPT.bank_angle_deg
            ]
            mass = evaluate(x)
            feasible = mass < 1e5
            @printf("  n=%2d  Do=%.1fmm  mass=%.2f kg  %s\n", n, Do_scaled*1000, mass, feasible ? "✓" : "✗ INFEASIBLE")
            println(io, "$n,$(Do_scaled*1000),$mass,$feasible")
            flush(io)
        end
    end
end

# ═══════════════════════════════════════════════════════════════════
# Sweep 2: β — sweep density profile
# ═══════════════════════════════════════════════════════════════════
function sweep_beta()
    println("\n=== Sweep 2: density_profile (β) ===")
    betas = [-0.8, -0.6, -0.4, -0.2, -0.12857, 0.0, 0.2, 0.4, 0.6, 0.8]
    open("scripts/results/sweep_beta.csv", "w") do io
        println(io, "beta,mass_kg")
        for β in betas
            x = Float64[
                OPT.Do_top, OPT.t_over_D, OPT.beam_aspect, OPT.Do_scale_exp,
                OPT.r_hub, OPT.r_bottom, OPT.target_Lr, Float64(OPT.n_lines),
                β, Float64(OPT.n_expansion), OPT.bank_angle_deg
            ]
            mass = evaluate(x)
            feasible = mass < 1e5
            @printf("  β=%+.2f  mass=%.2f kg  %s\n", β, mass, feasible ? "✓" : "✗")
            println(io, "$β,$mass")
            flush(io)
        end
    end
end

# ═══════════════════════════════════════════════════════════════════
# Sweep 3: n_expansion
# ═══════════════════════════════════════════════════════════════════
function sweep_nexp()
    println("\n=== Sweep 3: n_expansion ===")
    open("scripts/results/sweep_nexp.csv", "w") do io
        println(io, "n_exp,mass_kg")
        for ne in 0:6
            x = Float64[
                OPT.Do_top, OPT.t_over_D, OPT.beam_aspect, OPT.Do_scale_exp,
                OPT.r_hub, OPT.r_bottom, OPT.target_Lr, Float64(OPT.n_lines),
                OPT.density_profile, Float64(ne), OPT.bank_angle_deg
            ]
            mass = evaluate(x)
            feasible = mass < 1e5
            @printf("  n_exp=%d  mass=%.2f kg  %s\n", ne, mass, feasible ? "✓" : "✗")
            println(io, "$ne,$mass")
            flush(io)
        end
    end
end

println("V6.2 Sensitivity Sweeps v2 — $(now())")
sweep_nlines()
sweep_beta()
sweep_nexp()
println("\nDone.")

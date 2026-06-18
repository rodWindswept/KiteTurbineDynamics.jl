#!/usr/bin/env julia
# scripts/validate_v62_dynamic.jl
#
# Headless dynamic validation of the V6.2 optimum design.
# Answers: does the V6.2 design survive dynamic simulation with
# correct k_mppt?  Sweeps k_mppt to find the stable operating point.
#
# Usage:
#   julia --project=. scripts/validate_v62_dynamic.jl
#   julia --project=. scripts/validate_v62_dynamic.jl --sweep  # full sweep
#   julia --project=. scripts/validate_v62_dynamic.jl --duration 20  # longer sim

using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics, Printf, LinearAlgebra

const RHO = 1.225   # kg/m³

# ═══════════════════════════════════════════════════════════════════════════
# k_mppt calibration
# ═══════════════════════════════════════════════════════════════════════════

"""
    k_mppt_for_design(R, Cp_design, λ_design=4.1, ρ=RHO)

Compute the MPPT gain (N·m·s²/rad²) that gives equilibrium at the design
tip-speed ratio.  From τ_aero = τ_gen at equilibrium:

    k_mppt = ½ρπR⁵ × Cp(λ) / λ³
"""
function k_mppt_for_design(R::Float64, Cp::Float64, λ::Float64=4.1, ρ::Float64=RHO)
    return 0.5 * ρ * π * R^5 * Cp / (λ^3)
end

# ═══════════════════════════════════════════════════════════════════════════
# System builder (mirrors interactive_dashboard.jl --v6)
# ═══════════════════════════════════════════════════════════════════════════

function build_v62_system(; k_mppt::Float64=614.9)
    p = params_v5_50kw()
    sys, u0 = build_kite_turbine_system(p)

    r_rotor = 10.591991451982997  # from best_design.json
    cfg = ExpansionStackConfig(;
        placement=:clustered,
        n_rings=sys.n_ring,
        n_expansion=1,
        n_blades=p.n_blades,
        blade_tip_radius=r_rotor,
        blade_hub_radius=0.25 * r_rotor,
        blade_chord=0.113 * r_rotor,
        CL_blade=1.0,
        CD0_blade=0.02,
        k_induced=0.05,
        bank_angle_deg=45.0,
        mass_per_rotor=0.5,
        shaft_coupling=1.0,
    )
    stack = build_expansion_stack(cfg)
    sys, u0 = build_kite_turbine_system(p; expansion_rotors=stack)

    # Override k_mppt in the system parameters
    p_run = deepcopy(p)
    p_run.k_mppt = k_mppt

    return sys, u0, p_run
end

# ═══════════════════════════════════════════════════════════════════════════
# Simulation runner
# ═══════════════════════════════════════════════════════════════════════════

function run_dynamic_check(sys, u0, p_run; duration=10.0, dt=4e-5, v_wind=11.0)
    n_steps = round(Int, duration / dt)
    u = copy(u0)
    t = 0.0

    P_max = 0.0
    T_max = 0.0
    ω_max = 0.0
    P_vals = Float64[]
    T_vals = Float64[]
    ω_vals = Float64[]
    slack_count = 0
    total_steps = 0

    # Use a simple fixed-step Euler integrator for speed
    # (The full dashboard uses Tsit5 — we use Euler for headless speed)
    for step in 1:n_steps
        du = zeros(Float64, length(u))

        # Evaluate dynamics (simplified — calls the ODE RHS directly)
        try
            rhs!(du, u, p_run, t)
        catch
            @warn "RHS evaluation failed at t=$t" step=step
            break
        end

        # Euler step
        u .+= dt .* du
        t += dt

        # Extract metrics every 100 steps
        if step % 100 == 0
            N = sys.n_ring
            Nr = N  # ring angular states

            # Rotor angular velocity (ring 1 = hub)
            ω = u[6N + 1]

            # Power: P = τ_gen × ω = k_mppt × ω³
            P = p_run.k_mppt * ω^3

            # Tether tension: sum of all line tensions
            T_total = 0.0
            for i in 1:sys.n_lines
                line_gid = sys.line_ids[i]
                anchor_gid = sys.nodes[line_gid].anchor
                if anchor_gid > 0
                    pos_line = u[3*(line_gid-1)+1:3*line_gid]
                    pos_anchor = u[3*(anchor_gid-1)+1:3*anchor_gid]
                    T_total += norm(pos_line - pos_anchor)
                end
            end

            push!(P_vals, P)
            push!(T_vals, T_total)
            push!(ω_vals, ω)
            P_max = max(P_max, P)
            T_max = max(T_max, T_total)
            ω_max = max(ω_max, ω)
            total_steps += 1

            # Detect slack (very low tension)
            if T_total < 100.0
                slack_count += 1
            end
        end
    end

    # Compute mean values from last 25% of simulation (steady state)
    n_steady = max(1, length(P_vals) ÷ 4)
    P_mean = length(P_vals) > n_steady ? mean(P_vals[end-n_steady+1:end]) : mean(P_vals)
    ω_mean = length(ω_vals) > n_steady ? mean(ω_vals[end-n_steady+1:end]) : mean(ω_vals)
    T_mean = length(T_vals) > n_steady ? mean(T_vals[end-n_steady+1:end]) : mean(T_vals)
    slack_frac = total_steps > 0 ? slack_count / total_steps : 0.0

    return (;
        P_mean, P_max, T_mean, T_max, ω_mean, ω_max,
        slack_frac, P_rated=float(p_run.p_rated_w),
        duration=t, n_steps_completed=total_steps,
    )
end

# ═══════════════════════════════════════════════════════════════════════════
# k_mppt sweep
# ═══════════════════════════════════════════════════════════════════════════

function sweep_kmppt(; n_points=20, duration=5.0)
    # Build system once, then override k_mppt per run
    sys, u0, p_base = build_v62_system()

    # Compute the theoretical k_mppt
    R = 10.591991451982997
    Cp_design = BEM.cp_bem(12, 4.1)
    k_theory = k_mppt_for_design(R, Cp_design, 4.1)
    @printf("\n  Theoretical k_mppt: %.1f  (R=%.1f m, Cp=%.4f, λ=4.1)\n", k_theory, R, Cp_design)
    @printf("  Current dashboard k_mppt: 614.9\n")
    @printf("  Ratio: %.1f×\n\n", k_theory / 614.9)

    # Sweep around the theoretical value
    ks = exp10.(range(log10(k_theory * 0.1), log10(k_theory * 3.0); length=n_points))
    @printf("  %8s  %10s  %10s  %10s  %10s  %8s\n",
            "k_mppt", "P_mean(W)", "P_max(W)", "ω_mean", "T_max(N)", "%slack")
    println("  " * "-"^70)

    best_k = k_theory
    best_p_error = Inf

    for (i, k) in enumerate(ks)
        # Create a modified params with this k_mppt
        p_run = deepcopy(p_base)
        p_run.k_mppt = k

        u = copy(u0)
        result = run_dynamic_check(sys, u, p_run; duration=duration, v_wind=11.0)
        p_error = abs(result.P_mean - result.P_rated) / result.P_rated * 100

        marker = p_error < 20.0 ? " ✓" : ""
        @printf("  %8.0f  %10.0f  %10.0f  %10.2f  %10.0f  %7.1f%%%s\n",
                k, result.P_mean, result.P_max, result.ω_mean,
                result.T_max, result.slack_frac * 100, marker)

        if p_error < best_p_error
            best_p_error = p_error
            best_k = k
        end
    end

    @printf("\n  Best k_mppt: %.1f (P error: %.1f%%)\n", best_k, best_p_error)
    return best_k
end

# ═══════════════════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════════════════

function main()
    do_sweep = "--sweep" in ARGS
    duration = 5.0
    for (i, arg) in enumerate(ARGS)
        if arg == "--duration" && i < length(ARGS)
            duration = parse(Float64, ARGS[i+1])
        end
    end

    println("═══════════════════════════════════════════")
    println("  V6.2 Dynamic Validation")
    println("  Duration: $(duration)s per run")
    println("═══════════════════════════════════════════")

    if do_sweep
        best_k = sweep_kmppt(; duration=duration)
        println("\n  → Recommended k_mppt for V6.2: $(round(best_k; digits=1))")
    else
        # Single validation at theoretical k_mppt
        R = 10.591991451982997
        Cp_design = BEM.cp_bem(12, 4.1)
        k_theory = k_mppt_for_design(R, Cp_design, 4.1)
        @printf("\n  Theoretical k_mppt: %.1f\n", k_theory)

        sys, u0, p_run = build_v62_system(; k_mppt=k_theory)
        result = run_dynamic_check(sys, u0, p_run; duration=duration, v_wind=11.0)

        println("\n  ── Results at theoretical k_mppt=$(round(k_theory;digits=1)) ──")
        @printf("  P_mean:    %.0f W  (%.0f%% rated)\n", result.P_mean, result.P_mean/result.P_rated*100)
        @printf("  P_max:     %.0f W\n", result.P_max)
        @printf("  ω_mean:    %.2f rad/s  (%.1f rpm)\n", result.ω_mean, result.ω_mean*60/(2π))
        @printf("  T_max:     %.0f N\n", result.T_max)
        @printf("  Slack:     %.1f%%\n", result.slack_frac * 100)
        @printf("  Duration:  %.1f s  (%d sample points)\n", result.duration, result.n_steps_completed)
    end
end

main()

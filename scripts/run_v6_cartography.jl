#!/usr/bin/env julia
# scripts/run_v6_cartography.jl
#
# V6 Latin Hypercube broad sampling of the 11-DoF expansion-rotor design space.
# Records full design vectors, structural metrics, and feasibility for
# correlation analysis, sensitivity, and heatmap generation.
#
# Usage:
#   julia --project=. scripts/run_v6_cartography.jl \
#         --power 10 --samples 10000 --output scripts/results/v6_cartography_10kw.csv
#
#   julia --project=. scripts/run_v6_cartography.jl \
#         --power 50 --samples 10000 --output scripts/results/v6_cartography_50kw.csv

using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics
using CSV, DataFrames, Random, Printf

function parse_args()
    power_kw = 10
    samples = 10_000
    seed = 7
    output = ""
    for (i, arg) in enumerate(ARGS)
        if arg == "--power" && i < length(ARGS)
            power_kw = parse(Int, ARGS[i + 1])
        elseif arg == "--samples" && i < length(ARGS)
            samples = parse(Int, ARGS[i + 1])
        elseif arg == "--seed" && i < length(ARGS)
            seed = parse(Int, ARGS[i + 1])
        elseif arg == "--output" && i < length(ARGS)
            output = ARGS[i + 1]
        end
    end
    if isempty(output)
        output = "scripts/results/v6_cartography_$(power_kw)kw.csv"
    end
    return (power_kw=power_kw, samples=samples, seed=seed, output=output)
end

function lhs_sample(N::Int, lo::Vector{Float64}, hi::Vector{Float64}, rng::AbstractRNG)
    D = length(lo)
    X = Matrix{Float64}(undef, N, D)
    for d in 1:D
        perm = randperm(rng, N)
        for i in 1:N
            u = (perm[i] - 1.0 + rand(rng)) / N
            X[i, d] = lo[d] + u * (hi[d] - lo[d])
        end
    end
    return X
end

function main()
    args = parse_args()
    power_W = args.power_kw * 1000.0

    # Setup — use widened bounds for 50kW
    p = args.power_kw == 10 ? params_10kw() : params_v5_50kw()
    mgr = args.power_kw == 50 ? 5.0 : OPT_MAX_GROUND_RADIUS
    p_bounds = if args.power_kw == 50
        mass_scale(params_v5_10kw(), 10.0, 50.0 * (9.0 / 3.578)^2)
    else
        p
    end

    lo, hi = search_bounds_v6(p_bounds, PROFILE_ELLIPTICAL; max_ground_radius=mgr)
    dim = length(lo)

    println("V6 LHS cartography: N=$(args.samples), power=$(args.power_kw)kW, seed=$(args.seed)")
    @printf("  r_hub bounds: [%.1f, %.1f] m\n", lo[5], hi[5])
    @printf("  r_bot bounds: [%.1f, %.1f] m\n", lo[6], hi[6])

    rng = MersenneTwister(args.seed)
    X = lhs_sample(args.samples, lo, hi, rng)

    # Output columns: all 11 design vars + derived + structural metrics
    col_names = [
        :Do_top_m, :t_over_D, :beam_aspect, :Do_scale_exp,
        :r_hub_m, :r_bottom_m, :target_Lr, :knuckle_mass_kg,
        :n_lines, :n_expansion, :bank_angle_deg,
        :n_rings, :tether_length_m,
        :mass_structural_kg, :mass_expansion_kg, :mass_tether_kg,
        :mass_total_kg, :cost_kg,
        :min_fos, :min_torsional_fos, :worst_ring,
        :bem_rotor_m, :omega_rads, :feasible,
    ]
    N = args.samples
    out = DataFrame([name => zeros(Float64, N) for name in col_names[1:end-1]]...)
    out[!, :feasible] = falses(N)
    # Integer columns
    for col in [:n_lines, :n_expansion, :n_rings, :worst_ring]
        out[!, col] = zeros(Int, N)
    end

    t0 = time()
    for i in 1:N
        x = X[i, :]
        x_rounded = copy(x)
        x_rounded[9] = round(Int, clamp(x[9], 3, 8))
        x_rounded[10] = round(Int, clamp(x[10], 0, 6))

        result = try
            design_from_vector_v6(x_rounded, PROFILE_ELLIPTICAL, p;
                max_ground_radius=mgr, power_W=power_W)
        catch
            continue
        end
        design = result.design
        stack = result.stack

        r_rotor = BEM.rotor_radius_for_power(power_W, 11.0, design.n_lines)
        omega = 4.1 * 11.0 / r_rotor

        r_eff, F_radial_per_ring, _, _ = estimate_effective_radii(
            design, stack, p; v_wind=11.0, elev_deg=rad2deg(π/6), omega=omega, r_rotor=r_rotor
        )

        eval_result = evaluate_design(design;
            r_rotor=r_rotor, elev_angle=π/6, v_peak=22.0, fos_req=1.8,
            omega_rotor=omega, v_rated=11.0, P_rated=power_W,
            max_ground_radius=mgr, r_eff_override=r_eff,
            F_radial_per_ring=F_radial_per_ring,
        )

        m_exp = sum(er -> er.mass, stack; init=0.0)
        m_tether = design.n_lines * design.tether_length *
            (970.0 * π * (p.tether_diameter / 2)^2)

        out[i, :Do_top_m]         = design.Do_top
        out[i, :t_over_D]         = design.t_over_D
        out[i, :beam_aspect]      = design.beam_aspect
        out[i, :Do_scale_exp]     = design.Do_scale_exp
        out[i, :r_hub_m]          = design.r_hub
        out[i, :r_bottom_m]       = design.r_bottom
        out[i, :target_Lr]        = design.target_Lr
        out[i, :knuckle_mass_kg]  = design.knuckle_mass_kg
        out[i, :n_lines]          = design.n_lines
        out[i, :n_expansion]      = length(stack)
        out[i, :bank_angle_deg]   = isempty(stack) ? 0.0 : stack[1].bank_angle_deg
        out[i, :n_rings]          = length(ring_radii(design))
        out[i, :tether_length_m]  = design.tether_length
        out[i, :mass_structural_kg] = eval_result.mass_total_kg
        out[i, :mass_expansion_kg]  = m_exp
        out[i, :mass_tether_kg]     = m_tether
        out[i, :mass_total_kg]      = eval_result.mass_total_kg + m_exp + m_tether
        out[i, :cost_kg]            = eval_result.feasible ?
            eval_result.mass_total_kg + m_exp + m_tether :
            eval_result.mass_total_kg * min(
                max(1.0, 1.8 / max(eval_result.min_fos, 0.01)) *
                max(1.0, 1.5 / max(eval_result.min_torsional_fos, 0.01)), 10.0) + 1_000_000.0
        out[i, :min_fos]            = eval_result.min_fos
        out[i, :min_torsional_fos]  = eval_result.min_torsional_fos
        out[i, :worst_ring]         = eval_result.worst_ring_idx
        out[i, :bem_rotor_m]        = r_rotor
        out[i, :omega_rads]         = omega
        out[i, :feasible]           = eval_result.feasible

        if i % 2000 == 0
            dt = time() - t0
            @printf("  %d / %d  (%.1f s, %.1f/ms)\n", i, N, dt, i / (dt * 1000))
        end
    end

    mkpath(dirname(args.output))
    CSV.write(args.output, out)
    n_feas = sum(out.feasible)
    best = n_feas > 0 ? minimum(out.mass_total_kg[out.feasible]) : NaN
    println("Wrote $(args.output)")
    @printf("  Feasible: %d / %d (%.1f%%)\n", n_feas, N, 100 * n_feas / N)
    println("  Best feasible mass: $(round(best, digits=1)) kg")
end

main()

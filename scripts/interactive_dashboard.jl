#!/usr/bin/env julia
# scripts/interactive_dashboard.jl
# Canonical source of truth for KiteTurbineDynamics.jl.
# Normal mode: Opens interactive GLMakie dashboard.
# Headless mode: julia --project=. scripts/interactive_dashboard.jl --headless

using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics, Printf, LinearAlgebra, ArgParse, CSV, DataFrames

function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--headless"
            help = "Run in headless batch mode for report generation"
            action = :store_true
        "--wind"
            help = "Wind speed for single run (m/s)"
            arg_type = Float64
            default = 11.0
        "--duration"
            help = "Simulation duration (s)"
            arg_type = Float64
            default = 10.0
    end
    return parse_args(s)
end

function main()
    args = parse_commandline()
    p    = params_10kw()
    
    # ── Initialization ──
    sys, u0 = build_kite_turbine_system(p)
    println("Initializing at rated power equilibrium (ω=9.5)...")
    u_start = settle_to_operational_state(sys, u0, p, 9.5)

    N  = sys.n_total
    Nr = sys.n_ring
    
    # Custom wind function
    v_target = args["wind"]
    wind_fn = (pos, t) -> begin
        z  = max(pos[3], 1.0)
        sh = (z / p.h_ref)^(1.0/7.0)
        [v_target * sh, 0.0, 0.0]
    end

    DT         = 4e-5
    LIN_DAMP   = 0.05
    SAVE_EVERY = 500
    n_steps = round(Int, args["duration"] / DT)

    if args["headless"]
        # ── HEADLESS MODE ──
        println("Running headless simulation: $(args["duration"])s at $(v_target)m/s...")
        u = copy(u_start)
        
        # Simple CSV logging via callback
        results = DataFrame(t=Float64[], hub_z=Float64[], omega_hub=Float64[], P_kw=Float64[])
        
        run_canonical_sim!(u, sys, p, wind_fn, n_steps, DT; 
            lin_damp = LIN_DAMP,
            callback = (u_curr, t_curr, step) -> begin
                if step % SAVE_EVERY == 0
                    hz = u_curr[3*(sys.rotor.node_id-1)+3]
                    om = u_curr[6N + Nr + Nr]
                    pk = p.k_mppt * om^2 * abs(om) / 1000.0
                    push!(results, (t_curr, hz, om, pk))
                end
            end
        )
        
        out_path = "scripts/results/canonical_output_v$(v_target).csv"
        CSV.write(out_path, results)
        println("Done. Results saved to $out_path")
    else
        # ── INTERACTIVE MODE ──
        # Load GLMakie only when needed
        @eval using GLMakie
        
        n_frames = n_steps ÷ SAVE_EVERY
        frames   = Vector{Vector{Float64}}(undef, n_frames)
        times    = Vector{Float64}(undef, n_frames)
        u        = copy(u_start)

        println("Simulating $(args["duration"])s ($n_steps steps -> $n_frames frames)...")
        let fi = 1
            run_canonical_sim!(u, sys, p, wind_fn, n_steps, DT; 
                lin_damp = LIN_DAMP,
                callback = (u_current, t_current, step) -> begin
                    if step % SAVE_EVERY == 0 && fi <= n_frames
                        frames[fi] = copy(u_current)
                        times[fi]  = t_current
                        fi += 1
                    end
                end
            )
        end

        println("Building dashboard...")
        fig = build_dashboard(sys, p, frames; times=times,
                              u_settled=u_start, wind_fn=wind_fn)
        display(fig)
        println("Dashboard open. Ctrl+C to quit.")
        wait(fig.scene)
    end
end

main()

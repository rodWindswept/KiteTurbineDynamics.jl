#!/usr/bin/env julia
# scripts/plot_design_space_3d.jl
# High-fidelity 3D visualization of the TRPT design space mapping Euler and Torsional regimes.

using Pkg; Pkg.activate(dirname(@__DIR__))
ENV["GKSwstype"] = "nul"

using KiteTurbineDynamics, CSV, DataFrames, Printf, LinearAlgebra

const M = try
    @eval using GLMakie
    GLMakie.activate!()
    @info "GLMakie backend active"
    GLMakie
catch err
    @warn "GLMakie unavailable ($err) — falling back to CairoMakie"
    @eval using CairoMakie
    CairoMakie.activate!()
    CairoMakie
end

function main()
    input_path = joinpath(dirname(@__DIR__), "scripts", "results", "trpt_opt_v2", "lhs", "10kw_design_space_deep_dive.csv")
    if !isfile(input_path)
        error("Input data not found at $input_path. Run scripts/run_lhs_cartography.jl first.")
    end

    df = CSV.read(input_path, DataFrame)
    N = nrow(df)
    println("Loaded $N points from $input_path")

    # Filter to interesting range to avoid ultra-heavy outliers skewing the plot
    df_plot = filter(row -> row.mass_kg < 200.0, df)
    println("Plotting $(nrow(df_plot)) points (mass < 200kg)")

    # Define categories
    # Status: 1=Feasible, 2=Euler Fail, 3=Torsional Fail, 4=Both Fail
    statuses = Int[]
    for i in 1:nrow(df_plot)
        e_ok = df_plot.min_fos[i] >= 1.8
        t_ok = df_plot.min_torsional_fos[i] >= 1.5
        if e_ok && t_ok
            push!(statuses, 1)
        elseif !e_ok && t_ok
            push!(statuses, 2)
        elseif e_ok && !t_ok
            push!(statuses, 3)
        else
            push!(statuses, 4)
        end
    end

    colors = [
        M.RGBAf(0.1, 0.8, 0.1, 0.8), # 1: Green (Feasible) - Higher alpha
        M.RGBAf(0.8, 0.1, 0.1, 0.05), # 2: Red (Euler Fail) - Very transparent
        M.RGBAf(0.1, 0.1, 0.8, 0.05), # 3: Blue (Torsional Fail) - Very transparent
        M.RGBAf(0.6, 0.1, 0.6, 0.02), # 4: Purple (Both Fail) - Ghostly
    ]

    fig = M.Figure(size = (1400, 1200), backgroundcolor = :white)
    ax = M.Axis3(fig[1, 1],
                 title = "TRPT Design Space — Euler vs Torsional Feasibility (10 kW)",
                 xlabel = "Hub Radius (m)",
                 ylabel = "Taper Ratio (r_bot / r_hub)",
                 zlabel = "Shaft Mass (kg)",
                 titlesize = 24,
                 aspect = (1, 1, 0.8)) # Force cubic aspect rather than :data which squashes it

    # Plot categories in a specific order so Feasible is drawn last (on top)
    labels = ["Double Failure", "Euler Failure", "Torsional Failure", "Feasible"]
    plot_order = [4, 2, 3, 1] 
    
    scatters = []
    for s in plot_order
        idx = (statuses .== s)
        sum(idx) == 0 && continue
        
        ms = (s == 1) ? 5 : 2 # Feasible points are slightly larger
        
        sc = M.scatter!(ax, df_plot.r_hub_m[idx], df_plot.taper_ratio[idx], df_plot.mass_kg[idx],
                       color = colors[s], markersize = ms, label = labels[findfirst(==(s), plot_order)])
        push!(scatters, sc)
    end

    M.Legend(fig[1, 2], scatters, labels, "Constraint Status", framevisible = true)

    # Highlight the theoretical v5 winner
    # Island 11: r_hub=1.6, taper=0.21, mass=11.47
    M.scatter!(ax, [1.60], [0.21], [11.47], color = :gold, markersize = 25, 
               strokecolor = :black, strokewidth = 2, label = "v5 Global Winner")

    # Add a floor plane for better perspective
    # M.hlines!(ax, [0.0], color = :grey, alpha = 0.3)

    ax.azimuth[] = -π/4
    ax.elevation[] = π/12

    out_path = joinpath(dirname(@__DIR__), "figures", "fig_design_space_3d_cloud.png")
    mkpath(dirname(out_path))
    M.save(out_path, fig, px_per_unit = 2)
    println("Saved stunning 3D visual to $out_path")
end

main()

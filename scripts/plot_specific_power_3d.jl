#!/usr/bin/env julia
# scripts/plot_specific_power_3d.jl
# 3D surface plot mapping the "Specific Power" topology to explain the n_lines paradox.

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

# Use BEM constants
const P_TARGET = 10000.0 # 10 kW

function main()
    input_path = joinpath(dirname(@__DIR__), "scripts", "results", "trpt_opt_v2", "lhs", "10kw_design_space_deep_dive.csv")
    df = CSV.read(input_path, DataFrame)
    
    # Filter to feasible only to show the "optimal shelf"
    df_f = filter(row -> row.feasible && row.mass_kg < 150.0, df)
    println("Plotting $(nrow(df_f)) feasible points")

    # Specific Power = 10000 / mass
    spec_power = P_TARGET ./ df_f.mass_kg

    fig = M.Figure(size = (1200, 1000), backgroundcolor = :white)
    ax = M.Axis3(fig[1, 1],
                 title = "Aero-Structural Efficiency Topology (10 kW)",
                 xlabel = "Number of Lines (n)",
                 ylabel = "Taper Exponent (α)",
                 zlabel = "Specific Power (W/kg)",
                 titlesize = 24,
                 aspect = (1, 1, 0.8)) # Prevent squashing by forcing a cubic aspect

    # Plot the points
    sc = M.scatter!(ax, Float64.(df_f.n_lines), df_f.Do_scale_exp, spec_power,
                   color = spec_power, colormap = :plasma, markersize = 8)

    M.Colorbar(fig[1, 2], sc, label = "Specific Power (W/kg)", labelcolor = :black)

    # Highlight the winner
    # 10kW winner: n=8, spec_power = 10000/11.47 = 871 W/kg
    M.scatter!(ax, [8.0], [0.5], [871.0], color = :gold, markersize = 30, 
               strokecolor = :black, strokewidth = 2, label = "v5 Optimum")

    ax.azimuth[] = -π/6
    ax.elevation[] = π/8

    out_path = joinpath(dirname(@__DIR__), "figures", "fig_specific_power_topology.png")
    mkpath(dirname(out_path))
    M.save(out_path, fig, px_per_unit = 2)
    println("Saved specific power topology to $out_path")
end

main()

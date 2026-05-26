#!/usr/bin/env julia
# scripts/export_interactive_html.jl
# Exports the two main 3D plots as interactive HTML files using WGLMakie and JSServe.

using Pkg; Pkg.activate(dirname(@__DIR__))

using KiteTurbineDynamics, CSV, DataFrames

# Load WGLMakie for WebGL interactive output
using WGLMakie
using Bonito

const P_TARGET = 10000.0 # 10 kW

function export_design_space()
    input_path = joinpath(dirname(@__DIR__), "scripts", "results", "trpt_opt_v2", "lhs", "10kw_design_space_deep_dive.csv")
    df = CSV.read(input_path, DataFrame)
    df_plot = filter(row -> row.mass_kg < 200.0, df)

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
        RGBAf(0.0, 1.0, 0.0, 0.8), # 1: Green (Feasible)
        RGBAf(1.0, 0.0, 0.0, 0.08), # 2: Red (Euler Fail)
        RGBAf(0.0, 0.5, 1.0, 0.08), # 3: Blue (Torsional Fail)
        RGBAf(0.5, 0.0, 0.5, 0.05), # 4: Purple (Both Fail)
    ]

    # Dark background makes the transparent colors pop beautifully
    fig = Figure(size = (1200, 800), backgroundcolor = :grey10)
    ax = Axis3(fig[1, 1],
                 title = "Interactive Design Space (Drag to Rotate)",
                 titlecolor = :white,
                 xlabel = "Hub Radius (m)",
                 ylabel = "Taper Ratio (r_bot / r_hub)",
                 zlabel = "Shaft Mass (kg)",
                 xlabelcolor = :white, ylabelcolor = :white, zlabelcolor = :white,
                 xgridcolor = :grey30, ygridcolor = :grey30, zgridcolor = :grey30,
                 xticklabelcolor = :white, yticklabelcolor = :white, zticklabelcolor = :white,
                 aspect = (1, 1, 0.8),
                 perspectiveness = 0.5)

    labels = ["Double Failure", "Euler Failure", "Torsional Failure", "Feasible"]
    plot_order = [4, 2, 3, 1] 
    
    scatters = []
    for s in plot_order
        idx = (statuses .== s)
        sum(idx) == 0 && continue
        
        ms = (s == 1) ? 5 : 2
        sc = scatter!(ax, df_plot.r_hub_m[idx], df_plot.taper_ratio[idx], df_plot.mass_kg[idx],
                       color = colors[s], markersize = ms, label = labels[findfirst(==(s), plot_order)])
        push!(scatters, sc)
    end

    Legend(fig[1, 2], scatters, labels, "Status", framevisible = false, labelcolor = :white, titlecolor=:white)

    # Highlight the winner
    scatter!(ax, [1.60], [0.21], [11.47], color = :gold, markersize = 20, label = "v5 Optimum")

    out_path = joinpath(dirname(@__DIR__), "figures", "interactive_design_space.html")
    Bonito.export_static(out_path, Bonito.App(fig))
    println("Exported interactive HTML to $out_path")
end

function export_specific_power()
    input_path = joinpath(dirname(@__DIR__), "scripts", "results", "trpt_opt_v2", "lhs", "10kw_design_space_deep_dive.csv")
    df = CSV.read(input_path, DataFrame)
    
    df_f = filter(row -> row.feasible && row.mass_kg < 150.0, df)
    spec_power = P_TARGET ./ df_f.mass_kg

    fig = Figure(size = (1200, 800), backgroundcolor = :grey10)
    ax = Axis3(fig[1, 1],
                 title = "Interactive Specific Power Topology (Drag to Rotate)",
                 titlecolor = :white,
                 xlabel = "Number of Lines (n)",
                 ylabel = "Taper Exponent (α)",
                 zlabel = "Specific Power (W/kg)",
                 xlabelcolor = :white, ylabelcolor = :white, zlabelcolor = :white,
                 xgridcolor = :grey30, ygridcolor = :grey30, zgridcolor = :grey30,
                 xticklabelcolor = :white, yticklabelcolor = :white, zticklabelcolor = :white,
                 aspect = (1, 1, 0.8),
                 perspectiveness = 0.5)

    sc = scatter!(ax, Float64.(df_f.n_lines), df_f.Do_scale_exp, spec_power,
                   color = spec_power, colormap = :plasma, markersize = 10)

    Colorbar(fig[1, 2], sc, label = "Specific Power (W/kg)", labelcolor = :white, ticklabelcolor=:white)

    scatter!(ax, [8.0], [0.5], [871.0], color = :gold, markersize = 25, label = "v5 Optimum")

    out_path = joinpath(dirname(@__DIR__), "figures", "interactive_specific_power.html")
    Bonito.export_static(out_path, Bonito.App(fig))
    println("Exported interactive HTML to $out_path")
end

export_design_space()
export_specific_power()

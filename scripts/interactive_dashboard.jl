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
        "--optimized"
            help = "Render the optimized TRPT geometry from trpt_opt/<label>/best_design.json"
            arg_type = String
            default = ""
    end
    return parse_args(s)
end

# ── TRPT sizing optimization visualization (Item B2, Step 7) ──────────────────
"""
    render_optimized_trpt(label)

Render the optimized TRPT geometry from scripts/results/trpt_opt/<label>/best_design.json
using GLMakie.  Shows:
  - Pentagon rings tapered along the TRPT axis
  - Beam members between adjacent ring vertices (color-coded by Do)
  - Knuckle point masses at each vertex (red spheres)
  - Baseline vs optimized side-by-side if baseline.csv present
  - FOS gauge + mass readout
"""
function render_optimized_trpt(label::AbstractString)
    @eval using GLMakie

    json_path  = joinpath(dirname(@__DIR__), "scripts", "results",
                           "trpt_opt", label, "best_design.json")
    isfile(json_path) || error("best_design.json not found at $json_path")

    # Hand-rolled minimal JSON parse (matches writer format in run_trpt_optimization.jl)
    design = parse_best_design_json(json_path)

    r_top   = design["r_hub_m"]
    r_bot   = r_top * design["taper_ratio"]
    n_int   = design["n_rings"]
    L_total = design["tether_length_m"]
    n_rings_total = n_int + 2
    radii   = [r_bot + (r_top - r_bot) * (i-1)/(n_rings_total-1) for i in 1:n_rings_total]
    L_seg   = L_total / (n_rings_total - 1)
    n_lines = design["n_lines"]
    Do_top  = design["Do_top_m"]
    Do_exp  = design["Do_scale_exp"]

    fig = Figure(size=(1600, 900), fontsize=16)
    ax  = Axis3(fig[1, 1], title="Optimized TRPT — $(design["config"]) / $(design["profile"])",
                 xlabel="x (m)", ylabel="y (m)", zlabel="z — axial (m)",
                 aspect=:data)

    # Ring vertices: pentagon at each height
    for (i, r) in enumerate(radii)
        z = (i - 1) * L_seg
        Do = Do_top * (r / r_top)^Do_exp
        # Pentagon vertices
        pts_x = Float64[];  pts_y = Float64[];  pts_z = Float64[]
        for j in 1:n_lines
            φ = 2π * (j - 1) / n_lines
            push!(pts_x, r * cos(φ));  push!(pts_y, r * sin(φ));  push!(pts_z, z)
        end
        # Close the polygon for visualization
        push!(pts_x, pts_x[1]);  push!(pts_y, pts_y[1]);  push!(pts_z, pts_z[1])
        # Color by Do (larger Do = warmer color)
        col = RGBf(min(1, Do / 0.08), 0.3, 1 - min(1, Do / 0.08))
        lines!(ax, pts_x, pts_y, pts_z; color=col, linewidth=max(1, Do * 200))
        # Knuckles: red spheres at each vertex
        scatter!(ax, pts_x[1:end-1], pts_y[1:end-1], pts_z[1:end-1];
                 color=:red, markersize=8)
    end

    # Longitudinal tether lines between rings (grey)
    for j in 1:n_lines
        line_x = Float64[];  line_y = Float64[];  line_z = Float64[]
        for (i, r) in enumerate(radii)
            z = (i - 1) * L_seg
            φ = 2π * (j - 1) / n_lines
            push!(line_x, r * cos(φ));  push!(line_y, r * sin(φ));  push!(line_z, z)
        end
        lines!(ax, line_x, line_y, line_z; color=(:grey, 0.5), linewidth=1)
    end

    # Side panel: summary text
    side = fig[1, 2] = GridLayout()
    Label(side[1, 1], "Item B2 — Optimization Result"; fontsize=20, tellwidth=false,
          font=:bold)
    summary = """
    Config:         $(design["config"])
    Profile:        $(design["profile"])
    Mass (total):   $(round(design["best_mass_kg"]; digits=3)) kg
    min FOS @25m/s: $(round(design["min_fos"]; digits=3))
    n_rings:        $(design["n_rings"])
    r_hub:          $(round(design["r_hub_m"]; digits=3)) m
    taper_ratio:    $(round(design["taper_ratio"]; digits=3))
    Do_top:         $(round(design["Do_top_m"] * 1000; digits=2)) mm
    t/D:            $(round(design["t_over_D"]; digits=4))
    aspect_ratio:   $(round(design["aspect_ratio"]; digits=3))
    Do scaling exp: $(round(design["Do_scale_exp"]; digits=3))
    knuckle mass:   $(round(design["knuckle_mass_kg"] * 1000; digits=1)) g × $(n_lines * n_rings_total) vertices
    """
    Label(side[2, 1], summary; fontsize=14, tellwidth=false,
           halign=:left, justification=:left)

    display(fig)
    println("Interactive dashboard open for optimized design '$label'. Ctrl+C to quit.")
    wait(fig.scene)
end

"""
    parse_best_design_json(path) → Dict

Minimal parser for the flat-JSON format written by run_trpt_optimization.jl.
Avoids a JSON3 dependency on the hot path.
"""
function parse_best_design_json(path::AbstractString)
    txt = read(path, String)
    out = Dict{String,Any}()
    # Pull top-level scalars and nested fields with a simple regex sweep
    for (k, v) in (
        ("config", raw"\"config\"\s*:\s*\"([^\"]+)\""),
        ("profile", raw"\"profile\"\s*:\s*\"([^\"]+)\""),
        ("best_mass_kg", raw"\"best_mass_kg\"\s*:\s*([-\d.eE+]+)"),
        ("min_fos", raw"\"min_fos\"\s*:\s*([-\d.eE+]+)"),
        ("Do_top_m", raw"\"Do_top_m\"\s*:\s*([-\d.eE+]+)"),
        ("t_over_D", raw"\"t_over_D\"\s*:\s*([-\d.eE+]+)"),
        ("aspect_ratio", raw"\"aspect_ratio\"\s*:\s*([-\d.eE+]+)"),
        ("Do_scale_exp", raw"\"Do_scale_exp\"\s*:\s*([-\d.eE+]+)"),
        ("r_hub_m", raw"\"r_hub_m\"\s*:\s*([-\d.eE+]+)"),
        ("taper_ratio", raw"\"taper_ratio\"\s*:\s*([-\d.eE+]+)"),
        ("n_rings", raw"\"n_rings\"\s*:\s*([-\d.eE+]+)"),
        ("tether_length_m", raw"\"tether_length_m\"\s*:\s*([-\d.eE+]+)"),
        ("n_lines", raw"\"n_lines\"\s*:\s*([-\d.eE+]+)"),
        ("knuckle_mass_kg", raw"\"knuckle_mass_kg\"\s*:\s*([-\d.eE+]+)"),
    )
        m = match(Regex(v), txt)
        if m !== nothing
            out[k] = k in ("config","profile") ? String(m.captures[1]) :
                     k in ("n_rings", "n_lines") ? Int(round(parse(Float64, m.captures[1]))) :
                     parse(Float64, m.captures[1])
        end
    end
    return out
end

function main()
    args = parse_commandline()

    # ── Optimized-geometry mode (Item B2, Step 7) ─────────────────────────────
    if !isempty(args["optimized"])
        render_optimized_trpt(args["optimized"])
        return
    end

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

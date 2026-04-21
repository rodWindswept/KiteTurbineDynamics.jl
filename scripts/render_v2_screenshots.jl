#!/usr/bin/env julia
# scripts/render_v2_screenshots.jl
# Phase G — Headless GLMakie renders of the Phase C winners.
# For each (config, beam, axial) triple we pick the lowest-mass feasible
# design from its DE island archive and render a 3-panel portrait:
#   Panel A: 3D perspective view of the pentagon/polygon ring stack
#   Panel B: side-on axial profile r(z)
#   Panel C: per-ring FOS bar chart
#
# Usage:
#   julia --project=. scripts/render_v2_screenshots.jl
# Output:
#   scripts/results/trpt_opt_v2/renders/<tag>.png

using Pkg; Pkg.activate(dirname(@__DIR__))
ENV["GKSwstype"] = "nul"       # GR text safety
ENV["DISPLAY"]   = get(ENV, "DISPLAY", "")
ENV["GLMAKIE_BACKEND"] = "egl"

using KiteTurbineDynamics
using CSV, DataFrames, Printf, LinearAlgebra, Dates

const ROOT = dirname(@__DIR__)
const V2_DIR = joinpath(ROOT, "scripts", "results", "trpt_opt_v2")
const OUT_DIR = joinpath(V2_DIR, "renders")
mkpath(OUT_DIR)

# Load GLMakie only once; gracefully fall back to CairoMakie if headless GLMakie fails
try
    @eval using GLMakie
    try
        GLMakie.activate!()
    catch err
        @warn "GLMakie activate failed, trying CairoMakie: $err"
        @eval using CairoMakie
        CairoMakie.activate!()
    end
catch err
    @warn "GLMakie unavailable, using CairoMakie: $err"
    @eval using CairoMakie
    CairoMakie.activate!()
end

function build_design_from_archive_row(row, beam_profile::BeamProfile,
                                         axial_profile::AxialProfile,
                                         tether_length::Float64)
    return TRPTDesignV2(
        beam_profile,
        row.Do_top_m, row.t_over_D, row.beam_aspect, row.Do_scale_exp,
        axial_profile, row.profile_exp, row.straight_frac,
        row.r_hub_m, row.taper, row.n_rings, tether_length,
        row.n_lines, row.knuckle_mass_kg,
    )
end

function parse_dir_tag(tag::String)
    # e.g. 10kw_circular_parabolic_s1
    parts = split(tag, "_")
    cfg = parts[1]
    # Beam could be circular/elliptical/airfoil
    beam = parts[2]
    # Axial may be 1 or 2 tokens (straight_taper)
    if length(parts) >= 5 && parts[3] == "straight" && parts[4] == "taper"
        ax = "straight_taper"; seed = parts[5]
    else
        ax = parts[3]; seed = parts[4]
    end
    return cfg, beam, ax, seed
end

function pick_beam(s::String)
    s == "elliptical" ? PROFILE_ELLIPTICAL :
    s == "airfoil"    ? PROFILE_AIRFOIL    :
                        PROFILE_CIRCULAR
end

function pick_axial(s::String)
    s == "linear"         ? AXIAL_LINEAR         :
    s == "elliptic"       ? AXIAL_ELLIPTIC       :
    s == "parabolic"      ? AXIAL_PARABOLIC      :
    s == "trumpet"        ? AXIAL_TRUMPET        :
                            AXIAL_STRAIGHT_TAPER
end

pick_sys(s) = lowercase(s) == "50kw" ? params_50kw() : params_10kw()

function render_design(design::TRPTDesignV2, sys::SystemParams, out_path::String,
                        title::String)
    M = @isdefined(GLMakie) ? GLMakie : CairoMakie

    radii = ring_radii(design)
    zs    = ring_z_positions(design)
    n_v   = design.n_lines
    r_ev  = evaluate_design(design; r_rotor=sys.rotor_radius,
                             elev_angle=sys.elevation_angle)

    # Compute vertex positions (no elevation tilt; pure cartography)
    verts = Vector{Vector{Vector{Float64}}}(undef, length(radii))
    for (i, r) in enumerate(radii)
        verts[i] = [[r*cos(2π*(k-1)/n_v), r*sin(2π*(k-1)/n_v), zs[i]]
                     for k in 1:n_v]
    end

    fig = M.Figure(size=(1600, 900), backgroundcolor=:black)
    ax3 = M.Axis3(fig[1:2, 1:2], title=title, titlecolor=:white,
                   xlabel="x (m)", ylabel="y (m)", zlabel="z (m)",
                   backgroundcolor=:black,
                   xgridcolor=(:white, 0.2), ygridcolor=(:white, 0.2),
                   zgridcolor=(:white, 0.2),
                   xticklabelcolor=:white, yticklabelcolor=:white,
                   zticklabelcolor=:white,
                   xlabelcolor=:white, ylabelcolor=:white, zlabelcolor=:white,
                   aspect=:data)

    # Pentagon ring edges
    for i in 1:length(verts)
        ring = verts[i]
        for k in 1:n_v
            a = ring[k]; b = ring[mod1(k+1, n_v)]
            M.lines!(ax3, [a[1], b[1]], [a[2], b[2]], [a[3], b[3]],
                      color=:cyan, linewidth=2.0)
        end
    end
    # Axial lines (tethers)
    for k in 1:n_v
        xs = [verts[i][k][1] for i in 1:length(verts)]
        ys = [verts[i][k][2] for i in 1:length(verts)]
        zs2 = [verts[i][k][3] for i in 1:length(verts)]
        M.lines!(ax3, xs, ys, zs2, color=(:orange, 0.7), linewidth=1.6)
    end
    # Knuckles
    for i in 1:length(verts)
        ring = verts[i]
        for p in ring
            M.scatter!(ax3, [p[1]], [p[2]], [p[3]], markersize=10, color=:red)
        end
    end

    # Panel B: r(z) profile
    ax_rz = M.Axis(fig[1, 3], title="r(z) — $(axial_profile_name(design.axial_profile))",
                    titlecolor=:white, backgroundcolor=:black,
                    xlabel="r (m)", ylabel="z (m)",
                    xgridcolor=(:white, 0.2), ygridcolor=(:white, 0.2),
                    xticklabelcolor=:white, yticklabelcolor=:white,
                    xlabelcolor=:white, ylabelcolor=:white)
    M.lines!(ax_rz, radii, zs, color=:cyan, linewidth=2.5)
    M.scatter!(ax_rz, radii, zs, markersize=8, color=:white)

    # Panel C: FOS bars
    ax_fos = M.Axis(fig[2, 3], title="per-ring FOS (dashed = required 1.8)",
                     titlecolor=:white, backgroundcolor=:black,
                     xlabel="ring index", ylabel="FOS",
                     xgridcolor=(:white, 0.2), ygridcolor=(:white, 0.2),
                     xticklabelcolor=:white, yticklabelcolor=:white,
                     xlabelcolor=:white, ylabelcolor=:white, yscale=log10)
    fos_vals = [isfinite(f) ? max(f, 0.01) : 10.0 for f in r_ev.fos_per_ring]
    idxs = collect(1:length(fos_vals))
    M.barplot!(ax_fos, idxs, fos_vals, color=:orange)
    M.hlines!(ax_fos, [1.8], color=:red, linestyle=:dash)

    # Annotation box
    summary = """
    mass: $(round(r_ev.mass_total_kg;digits=2)) kg
    min FOS: $(round(r_ev.min_fos;digits=2))
    n_rings: $(design.n_rings)  n_lines: $(design.n_lines)
    r_hub: $(round(design.r_hub;digits=2)) m  taper: $(round(design.taper_ratio;digits=2))
    axial: $(axial_profile_name(design.axial_profile))
    beam: $(design.beam_profile), Do_top=$(round(design.Do_top*1000;digits=1))mm
    knuckle: $(round(design.knuckle_mass_kg*1000;digits=1)) g/vertex
    """
    M.text!(fig.scene, summary, position=(40, 40), color=:white,
             font=:regular, fontsize=14,
             space=:pixel)

    M.save(out_path, fig)
    println("wrote $out_path")
end

function main()
    # Scan DE output dirs
    tags = filter(readdir(V2_DIR)) do d
        isdir(joinpath(V2_DIR, d)) &&
        !(d in ("lhs", "cartography", "renders")) &&
        isfile(joinpath(V2_DIR, d, "elite_archive.csv"))
    end
    println("found $(length(tags)) archives to render")

    for tag in tags
        try
            cfg, beam_s, ax_s, seed = parse_dir_tag(tag)
            sys = pick_sys(cfg)
            beam = pick_beam(beam_s)
            ax   = pick_axial(ax_s)
            arc_csv = joinpath(V2_DIR, tag, "elite_archive.csv")
            df = CSV.read(arc_csv, DataFrame)
            if nrow(df) == 0
                println("skip $tag — empty archive"); continue
            end
            top = first(sort(df, :mass_kg), 1)[1, :]
            design = build_design_from_archive_row(top, beam, ax, sys.tether_length)
            out_path = joinpath(OUT_DIR, "$(tag).png")
            title = "$tag — mass $(round(top.mass_kg;digits=2)) kg, FOS $(round(top.min_fos;digits=2))"
            render_design(design, sys, out_path, title)
        catch err
            @warn "failed to render $tag: $err"
        end
    end
end

main()

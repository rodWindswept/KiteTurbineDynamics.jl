#!/usr/bin/env julia
# scripts/render_v3_winner.jl
# Headless GLMakie render of the v3 10 kW winner (Tulloch torsional constraint enforced).
# Winner: 10 kW circular straight-taper, 15.44 kg, taper=1.0 (cylindrical).
#
# Output: scripts/results/trpt_opt_v3/cartography/fig_v3_winner_glmakie.png

using Pkg; Pkg.activate(dirname(@__DIR__))
ENV["GKSwstype"] = "nul"
ENV["DISPLAY"]   = get(ENV, "DISPLAY", "")

using KiteTurbineDynamics
using CSV, DataFrames, Printf, LinearAlgebra

const ROOT    = dirname(@__DIR__)
# v3 results may live in a sibling worktree before being copied to main repo
const _V3_LOCAL    = joinpath(ROOT, "scripts", "results", "trpt_opt_v3")
const _V3_SIBLING  = joinpath(dirname(ROOT), "relaxed-shamir-cd9a0f",
                               "scripts", "results", "trpt_opt_v3")
# Use local if island data exists there, otherwise fall back to sibling worktree
const _V3_CHECK = joinpath(_V3_LOCAL, "10kw_circular_straight_taper_s1", "elite_archive.csv")
const V3_DIR  = isfile(_V3_CHECK) ? _V3_LOCAL : _V3_SIBLING
const OUT_DIR = joinpath(V3_DIR, "cartography")

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

pick_beam(s)  = s == "elliptical" ? PROFILE_ELLIPTICAL :
                s == "airfoil"    ? PROFILE_AIRFOIL    : PROFILE_CIRCULAR
pick_axial(s) = s == "linear"         ? AXIAL_LINEAR        :
                s == "elliptic"       ? AXIAL_ELLIPTIC      :
                s == "parabolic"      ? AXIAL_PARABOLIC     :
                s == "trumpet"        ? AXIAL_TRUMPET       :
                                        AXIAL_STRAIGHT_TAPER
pick_sys(s) = lowercase(s) == "50kw" ? params_50kw() : params_10kw()

function do_colour(Do, Do_min, Do_max)
    Do_max ≈ Do_min && return M.cgrad(:viridis)[1.0]
    t = clamp((Do - Do_min) / (Do_max - Do_min), 0.0, 1.0)
    return M.cgrad(:viridis)[t]
end

function render_v3(tag::String, out_path::String)
    parts = split(tag, "_")
    cfg    = parts[1]
    beam_s = parts[2]
    seed_s = parts[end]
    axial_parts = parts[3:end-1]
    ax_s   = join(axial_parts, "_")

    sys  = pick_sys(cfg)
    beam = pick_beam(beam_s)
    axial = pick_axial(ax_s)

    df = CSV.read(joinpath(V3_DIR, tag, "elite_archive.csv"), DataFrame)
    row = first(sort(df, :mass_kg), 1)[1, :]

    design = TRPTDesignV2(
        beam,
        row.Do_top_m, row.t_over_D, row.beam_aspect, row.Do_scale_exp,
        axial, row.profile_exp, row.straight_frac,
        row.r_hub_m, row.taper, row.n_rings, sys.tether_length,
        row.n_lines, row.knuckle_mass_kg,
    )

    radii = ring_radii(design)
    zs    = ring_z_positions(design)
    n_v   = design.n_lines

    specs   = [beam_spec_at_ring(design, r) for r in radii]
    Do_vals = [s.Do for s in specs]
    Do_min  = minimum(Do_vals); Do_max = maximum(Do_vals)

    verts = Vector{Vector{Vector{Float64}}}(undef, length(radii))
    for (i, r) in enumerate(radii)
        verts[i] = [[r*cos(2π*(k-1)/n_v), r*sin(2π*(k-1)/n_v), zs[i]]
                    for k in 1:n_v]
    end

    torsional_fos = hasproperty(row, :torsional_fos) ? row.torsional_fos : NaN

    fig = M.Figure(size = (1400, 1600), backgroundcolor = :white)
    ax3 = M.Axis3(fig[1, 1],
                  backgroundcolor = :white,
                  xlabel = "x (m)", ylabel = "y (m)", zlabel = "z (m)",
                  xgridcolor = (:black, 0.1),
                  ygridcolor = (:black, 0.1),
                  zgridcolor = (:black, 0.1),
                  xticklabelcolor = :black, yticklabelcolor = :black,
                  zticklabelcolor = :black,
                  xlabelcolor = :black, ylabelcolor = :black, zlabelcolor = :black,
                  titlesize = 18,
                  titlecolor = :black,
                  title = @sprintf("v3 Winner — %s  %.2f kg  FOS %.2f  TorFOS %.2f  n=%d×%d  r_hub=%.2fm  taper=%.2f",
                                   uppercase(cfg), row.mass_kg, row.min_fos,
                                   isnan(torsional_fos) ? 0.0 : torsional_fos,
                                   design.n_rings, design.n_lines,
                                   design.r_hub, design.taper_ratio),
                  aspect = (1, 1, 3.5))
    M.colsize!(fig.layout, 1, M.Fixed(1200))
    M.rowsize!(fig.layout, 1, M.Fixed(1500))

    for i in 1:length(verts)
        col = do_colour(Do_vals[i], Do_min, Do_max)
        lw  = 3.0 + 6.0 * (Do_vals[i] - Do_min) / max(Do_max - Do_min, 1e-9)
        ring = verts[i]
        for k in 1:n_v
            a = ring[k]; b = ring[mod1(k+1, n_v)]
            M.lines!(ax3, [a[1], b[1]], [a[2], b[2]], [a[3], b[3]],
                     color = col, linewidth = lw)
        end
    end

    for k in 1:n_v
        xs  = [verts[i][k][1] for i in 1:length(verts)]
        ys  = [verts[i][k][2] for i in 1:length(verts)]
        zs2 = [verts[i][k][3] for i in 1:length(verts)]
        M.lines!(ax3, xs, ys, zs2, color = (:grey30, 0.7), linewidth = 1.2)
    end

    for i in 1:length(verts)
        for p in verts[i]
            M.scatter!(ax3, [p[1]], [p[2]], [p[3]],
                       markersize = 14, color = :red, strokewidth = 0)
        end
    end

    cb = M.Colorbar(fig[1, 2],
                    colormap = :viridis,
                    limits = (1e3*Do_min, 1e3*Do_max),
                    label = "Beam outer Ø (mm)",
                    labelcolor = :black,
                    ticklabelcolor = :black,
                    tickcolor = :black,
                    width = 22,
                    height = M.Relative(0.55))
    M.colsize!(fig.layout, 2, M.Fixed(120))

    ax3.azimuth[]         = -π/3.2
    ax3.elevation[]       = π/9
    ax3.perspectiveness[] = 0.4

    mkpath(dirname(out_path))
    M.save(out_path, fig, px_per_unit = 2)
    println("wrote $out_path   ($(row.mass_kg) kg, taper=$(row.taper))")
end

mkpath(OUT_DIR)
render_v3("10kw_circular_straight_taper_s1",
          joinpath(OUT_DIR, "fig_v3_winner_glmakie.png"))

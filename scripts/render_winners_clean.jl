#!/usr/bin/env julia
# scripts/render_winners_clean.jl
# Headless GLMakie render of the Phase C winners (clean cartography view,
# no side panels) for:
#   • 10 kW circular straight-taper  (2.81 kg)
#   • 50 kW circular straight-taper  (19.22 kg)
# White background, no UI chrome. Beam outer diameter Do colour-coded per ring
# (viridis); knuckle vertices as red spheres; tethers as dark grey lines.
#
# Output filenames (dropped into scripts/results/trpt_opt_v2/):
#   winner_10kw_circular_straight_taper_clean.png
#   winner_50kw_circular_straight_taper_clean.png

using Pkg; Pkg.activate(dirname(@__DIR__))
ENV["GKSwstype"] = "nul"
ENV["DISPLAY"]   = get(ENV, "DISPLAY", "")

using KiteTurbineDynamics
using CSV, DataFrames, Printf, LinearAlgebra

const ROOT   = dirname(@__DIR__)
const V2_DIR = joinpath(ROOT, "scripts", "results", "trpt_opt_v2")

# Canvas is a parameter, not a constant, because the print width is not the
# render width: a report panel fixes its printed width (85 mm) and the canvas
# aspect then decides the printed height. The defaults below are the recorded
# 1400x1600 portrait render and are byte-identical to it; a report capture
# sets them from the environment and writes elsewhere, so this script keeps
# one default output and gains a second caller without a second copy of the
# geometry code.
#   KTD_WINNER_FIG_W / _H    Figure canvas (logical px)
#   KTD_WINNER_AX_W  / _H    Axis3 slot inside the canvas
#   KTD_WINNER_OUT           output directory (default: V2_DIR)
const FIG_W = parse(Int, get(ENV, "KTD_WINNER_FIG_W", "1400"))
const FIG_H = parse(Int, get(ENV, "KTD_WINNER_FIG_H", "1600"))
const AX_W  = parse(Int, get(ENV, "KTD_WINNER_AX_W",  "1200"))
const AX_H  = parse(Int, get(ENV, "KTD_WINNER_AX_H",  "1500"))
const OUT_DIR = get(ENV, "KTD_WINNER_OUT", V2_DIR)
# Title payload. "full" is the recorded output: design tag, winner mass, the
# archive's min_fos, then the object's own descriptors. "geometry" keeps the
# tag and the descriptors and drops the two campaign outputs, because in this
# tree neither is a reading a report may print beside the drawing:
# scripts/results/README.md marks this campaign's 10 kW design pre-v3 and
# torsionally infeasible, and min_fos is a saturated gate (one distinct value,
# 1.80, across the elite archive), not a computed safety factor. The strip is
# geometry-neutral: same tower, same camera, same pixels below the title band.
const TITLE_MODE = get(ENV, "KTD_WINNER_TITLE", "full")

function title_string(tag, row, design)
    desc = @sprintf("n_rings=%d, n_lines=%d, r_hub=%.2fm",
                    design.n_rings, design.n_lines, design.r_hub)
    TITLE_MODE == "geometry" && return string(tag, " — ", desc)
    return @sprintf("%s — %.2f kg, FOS %.2f, %s", tag, row.mass_kg, row.min_fos, desc)
end

# Force GLMakie first, fall back to CairoMakie if headless GL fails
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
pick_axial(s) = s == "linear"         ? AXIAL_LINEAR     :
                s == "elliptic"       ? AXIAL_ELLIPTIC   :
                s == "parabolic"      ? AXIAL_PARABOLIC  :
                s == "trumpet"        ? AXIAL_TRUMPET    :
                                        AXIAL_STRAIGHT_TAPER
pick_sys(s) = lowercase(s) == "50kw" ? params_50kw() : params_10kw()

function build_design_from_row(row, beam::BeamProfile, axial::AxialProfile,
                               tether_length::Float64)
    return TRPTDesignV2(
        beam,
        row.Do_top_m, row.t_over_D, row.beam_aspect, row.Do_scale_exp,
        axial, row.profile_exp, row.straight_frac,
        row.r_hub_m, row.taper, row.n_rings, tether_length,
        row.n_lines, row.knuckle_mass_kg,
    )
end

"""Map Do (in metres) to a colour via M.cgrad(:viridis). Normalize Do over the
ring stack so the thickest ring saturates the colormap."""
function do_colour(Do, Do_min, Do_max)
    Do_max ≈ Do_min && return M.cgrad(:viridis)[1.0]
    t = clamp((Do - Do_min) / (Do_max - Do_min), 0.0, 1.0)
    return M.cgrad(:viridis)[t]
end

function render_one(tag::String, out_path::String)
    parts = split(tag, "_")
    cfg = parts[1]; beam_s = parts[2]
    ax_s = parts[3] == "straight" && length(parts) >= 5 ? "straight_taper" : parts[3]
    sys = pick_sys(cfg); beam = pick_beam(beam_s); axial = pick_axial(ax_s)

    df = CSV.read(joinpath(V2_DIR, tag, "elite_archive.csv"), DataFrame)
    row = first(sort(df, :mass_kg), 1)[1, :]
    design = build_design_from_row(row, beam, axial, sys.tether_length)

    radii = ring_radii(design)
    zs    = ring_z_positions(design)
    n_v   = design.n_lines

    specs    = [beam_spec_at_ring(design, r) for r in radii]
    Do_vals  = [s.Do for s in specs]
    Do_min   = minimum(Do_vals); Do_max = maximum(Do_vals)

    # Vertex positions, no elevation tilt, hub at z = 0
    verts = Vector{Vector{Vector{Float64}}}(undef, length(radii))
    for (i, r) in enumerate(radii)
        verts[i] = [[r*cos(2π*(k-1)/n_v), r*sin(2π*(k-1)/n_v), zs[i]]
                    for k in 1:n_v]
    end

    # single-axis, white background, no side panels (default 1400x1600)
    fig = M.Figure(size = (FIG_W, FIG_H), backgroundcolor = :white)
    ax3 = M.Axis3(fig[1, 1],
                  backgroundcolor = :white,
                  xlabel = "x (m)", ylabel = "y (m)", zlabel = "z (m)",
                  xgridcolor = (:black, 0.1),
                  ygridcolor = (:black, 0.1),
                  zgridcolor = (:black, 0.1),
                  xticklabelcolor = :black, yticklabelcolor = :black,
                  zticklabelcolor = :black,
                  xlabelcolor = :black, ylabelcolor = :black, zlabelcolor = :black,
                  titlesize = 22,
                  titlecolor = :black,
                  title = title_string(tag, row, design),
                  aspect = (1, 1, 3.5))
    M.colsize!(fig.layout, 1, M.Fixed(AX_W))
    M.rowsize!(fig.layout, 1, M.Fixed(AX_H))
    # Zero the gaps explicitly: Fixed slots do not reserve the layout default
    # row/col gap, so an unset gap overflows the canvas and clips the title.
    M.colgap!(fig.layout, 0.0)
    M.rowgap!(fig.layout, 0.0)

    # Polygon beams — thickness maps linearly to Do, colour from viridis
    for i in 1:length(verts)
        col = do_colour(Do_vals[i], Do_min, Do_max)
        # Linewidth in points: scale Do (m) so thickest ring ≈ 9 pt
        lw  = 3.0 + 6.0 * (Do_vals[i] - Do_min) / max(Do_max - Do_min, 1e-9)
        ring = verts[i]
        for k in 1:n_v
            a = ring[k]; b = ring[mod1(k+1, n_v)]
            M.lines!(ax3, [a[1], b[1]], [a[2], b[2]], [a[3], b[3]],
                     color = col, linewidth = lw)
        end
    end

    # Tethers — dark grey thin lines spanning vertex-k across all rings
    for k in 1:n_v
        xs = [verts[i][k][1] for i in 1:length(verts)]
        ys = [verts[i][k][2] for i in 1:length(verts)]
        zs2 = [verts[i][k][3] for i in 1:length(verts)]
        M.lines!(ax3, xs, ys, zs2, color = (:grey30, 0.7), linewidth = 1.2)
    end

    # Knuckles — red spheres
    for i in 1:length(verts)
        for p in verts[i]
            M.scatter!(ax3, [p[1]], [p[2]], [p[3]],
                       markersize = 14, color = :red, strokewidth = 0)
        end
    end

    # Colorbar for Do (inside the axis area — we want no side panels, so
    # drop it into the bottom-right inset via fig[1, 1, Right()])
    # Inline colorbar:
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

    # Pick a pleasant default perspective — slight bird's eye down the shaft
    ax3.azimuth[]   = -π/3.2
    ax3.elevation[] = π/9
    ax3.perspectiveness[] = 0.4

    M.save(out_path, fig, px_per_unit = 2)
    println("wrote $out_path   ($(basename(tag)), $(round(row.mass_kg, digits=2)) kg)")
end

function main()
    targets = [
        "10kw_circular_straight_taper_s1",
        "50kw_circular_straight_taper_s1",
    ]
    for tag in targets
        out = joinpath(OUT_DIR, "winner_$(tag |> t->replace(t, r"_s[12]$"=>"")).png")
        render_one(tag, out)
    end
end

main()

#!/usr/bin/env julia
# scripts/overlay_designs.jl
# Overlay 2+ TRPT designs in a single 3D GLMakie view for structural comparison.
#
# Usage:
#   julia --project=. scripts/overlay_designs.jl
#     (uses built-in 10kW + 50kW defaults)
#
#   julia --project=. scripts/overlay_designs.jl path/to/design_a.json path/to/design_b.json ...
#     (reads best_design.json files)
#
#   julia --project=. scripts/overlay_designs.jl --headless
#     (forces CairoMakie for headless rendering)
#
# Output: scripts/results/design_overlay.png

using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics
using Printf
using LinearAlgebra

# ── CLI parsing ──────────────────────────────────────────────────────────────
headless_flag = "--headless" in ARGS
paths = filter(a -> !startswith(a, "-"), ARGS)

# ── Choose Makie backend ─────────────────────────────────────────────────────
if headless_flag
    try
        @eval using CairoMakie
    catch e
        @warn "CairoMakie not available, falling back to GLMakie" exception = e
        @eval using GLMakie
    end
else
    @eval using GLMakie
end

# ── Parse best_design.json ───────────────────────────────────────────────────
"""
    parse_best_design_v6(path) → Dict

Parse best_design.json into a Dict, handling both v6 fields (r_bottom_m,
target_Lr) and older formats (taper_ratio).  Returns missing keys as nothing.
"""
function parse_best_design_v6(path::AbstractString)
    txt = read(path, String)
    out = Dict{String,Any}()
    field_defs = [
        ("power_kw",       raw"\"power_kw\"\s*:\s*([-\d.eE+]+)",         :num),
        ("profile",        raw"\"profile\"\s*:\s*\"([^\"]+)\"",            :str),
        ("best_mass_kg",   raw"\"best_mass_kg\"\s*:\s*([-\d.eE+]+)",     :num),
        ("Do_top_m",       raw"\"Do_top_m\"\s*:\s*([-\d.eE+]+)",         :num),
        ("t_over_D",       raw"\"t_over_D\"\s*:\s*([-\d.eE+]+)",         :num),
        ("aspect_ratio",   raw"\"aspect_ratio\"\s*:\s*([-\d.eE+]+)",     :num),
        ("Do_scale_exp",   raw"\"Do_scale_exp\"\s*:\s*([-\d.eE+]+)",     :num),
        ("r_hub_m",        raw"\"r_hub_m\"\s*:\s*([-\d.eE+]+)",          :num),
        ("r_bottom_m",     raw"\"r_bottom_m\"\s*:\s*([-\d.eE+]+)",       :num),
        ("target_Lr",      raw"\"target_Lr\"\s*:\s*([-\d.eE+]+)",        :num),
        ("taper_ratio",    raw"\"taper_ratio\"\s*:\s*([-\d.eE+]+)",      :num),
        ("tether_length_m",raw"\"tether_length_m\"\s*:\s*([-\d.eE+]+)",  :num),
        ("n_lines",        raw"\"n_lines\"\s*:\s*([-\d.eE+]+)",          :num),
        ("n_rings",        raw"\"n_rings\"\s*:\s*([-\d.eE+]+)",          :num),
        ("knuckle_mass_kg",raw"\"knuckle_mass_kg\"\s*:\s*([-\d.eE+]+)",  :num),
        ("n_expansion",    raw"\"n_expansion\"\s*:\s*([-\d.eE+]+)",      :num),
        ("bank_angle_deg", raw"\"bank_angle_deg\"\s*:\s*([-\d.eE+]+)",   :num),
    ]
    for (key, pattern, kind) in field_defs
        m = match(Regex(pattern), txt)
        if m !== nothing
            if kind == :str
                out[key] = String(m.captures[1])
            elseif kind == :num && key in ("n_lines", "n_rings", "n_expansion")
                out[key] = Int(round(parse(Float64, m.captures[1])))
            else
                out[key] = parse(Float64, m.captures[1])
            end
        end
    end
    out
end

"""
    design_from_dict(d) → TRPTDesignV4

Build a TRPTDesignV4 from a parsed best_design.json dictionary.
Handles both v6 (r_bottom_m, target_Lr) and older (taper_ratio) formats.
"""
function design_from_dict(d::Dict)
    profile_name = get(d, "profile", "PROFILE_ELLIPTICAL")
    profile = if profile_name == "PROFILE_CIRCULAR"
        PROFILE_CIRCULAR
    elseif profile_name == "PROFILE_AIRFOIL"
        PROFILE_AIRFOIL
    else
        PROFILE_ELLIPTICAL
    end

    r_hub = get(d, "r_hub_m", 1.6)
    tether_length = get(d, "tether_length_m", 30.0)

    # Handle both v6 (r_bottom_m, target_Lr) and older (taper_ratio) formats
    r_bottom = if haskey(d, "r_bottom_m") && d["r_bottom_m"] !== nothing
        d["r_bottom_m"]
    elseif haskey(d, "taper_ratio") && d["taper_ratio"] !== nothing
        r_hub * d["taper_ratio"]
    else
        r_hub * 0.48  # baseline fallback
    end

    target_Lr = if haskey(d, "target_Lr") && d["target_Lr"] !== nothing
        d["target_Lr"]
    else
        1.0  # baseline fallback
    end

    TRPTDesignV4(
        profile,
        get(d, "Do_top_m", 0.0348),
        get(d, "t_over_D", 0.02),
        get(d, "aspect_ratio", 1.0),
        get(d, "Do_scale_exp", 0.5),
        r_hub,
        r_bottom,
        target_Lr,
        tether_length,
        get(d, "n_lines", 8),
        get(d, "knuckle_mass_kg", 0.01),
    )
end

# ── Design label ─────────────────────────────────────────────────────────────
function design_label(d::Dict)
    pk = get(d, "power_kw", nothing)
    if pk !== nothing
        return "$(Int(pk))kW"
    end
    m = get(d, "best_mass_kg", nothing)
    if m !== nothing
        return "$(round(m; digits=1)) kg"
    end
    return "Design"
end

# ── Built-in defaults (10 kW + 50 kW campaign bests) ────────────────────────
builtin_10kw = Dict{String,Any}(
    "power_kw" => 10, "profile" => "PROFILE_ELLIPTICAL",
    "Do_top_m" => 0.034810387720714764, "t_over_D" => 0.02,
    "aspect_ratio" => 1.0, "Do_scale_exp" => 0.49170223881472636,
    "r_hub_m" => 1.6, "r_bottom_m" => 1.488301249517557,
    "target_Lr" => 1.105366200006449, "tether_length_m" => 30.0,
    "n_lines" => 8, "knuckle_mass_kg" => 0.01,
    "best_mass_kg" => 23.86806120380797, "n_rings" => 19, "n_expansion" => 0,
    "bank_angle_deg" => 0.0,
)
builtin_50kw = Dict{String,Any}(
    "power_kw" => 50, "profile" => "PROFILE_ELLIPTICAL",
    "Do_top_m" => 0.11237013870949418, "t_over_D" => 0.02,
    "aspect_ratio" => 1.0, "Do_scale_exp" => 0.45687759164294856,
    "r_hub_m" => 7.466951027802908, "r_bottom_m" => 5.0,
    "target_Lr" => 2.0, "tether_length_m" => 67.0820393249937,
    "n_lines" => 8, "knuckle_mass_kg" => 0.01000000001548168,
    "best_mass_kg" => 259.44488782965533, "n_rings" => 6, "n_expansion" => 0,
    "bank_angle_deg" => 0.0,
)

# ── Load designs ─────────────────────────────────────────────────────────────
design_dicts = []  # Vector of NamedTuples with :label, :dict, :design
if isempty(paths)
    push!(design_dicts, (label = "10kW", dict = builtin_10kw, design = design_from_dict(builtin_10kw)))
    push!(design_dicts, (label = "50kW", dict = builtin_50kw, design = design_from_dict(builtin_50kw)))
else
    for p in paths
        d = parse_best_design_v6(p)
        lbl = design_label(d)
        push!(design_dicts, (label = lbl, dict = d, design = design_from_dict(d)))
    end
end

n_designs = length(design_dicts)
println("Overlaying $n_designs designs:")
for dd in design_dicts
    println("  $(dd.label): r_hub=$(round(dd.design.r_hub; digits=2)) m, ",
            "r_bottom=$(round(dd.design.r_bottom; digits=2)) m, ",
            "L=$(round(dd.design.tether_length; digits=1)) m, ",
            "target_Lr=$(round(dd.design.target_Lr; digits=2)), ",
            "n_lines=$(dd.design.n_lines)")
end

# ── Colours ──────────────────────────────────────────────────────────────────
design_colors = [
    RGBf(0.85, 0.15, 0.15),   # red
    RGBf(0.15, 0.65, 0.15),   # green
    RGBf(0.15, 0.30, 0.85),   # blue
    RGBf(0.85, 0.55, 0.10),   # orange
    RGBf(0.55, 0.15, 0.65),   # purple
    RGBf(0.10, 0.65, 0.65),   # cyan
]

# ── Structural evaluation (for FoS in HUD) ───────────────────────────────────
function eval_for_hud(design::TRPTDesignV4, power_kw::Float64)
    v_rated = 11.0
    power_W = power_kw * 1000.0
    r_rotor = BEM.rotor_radius_for_power(power_W, v_rated, design.n_lines)
    omega_rotor = 4.1 * v_rated / r_rotor  # TSR 4.1
    v_peak = 25.0  # survival wind

    result = evaluate_design(
        design;
        r_rotor = r_rotor,
        elev_angle = deg2rad(30.0),
        v_peak = v_peak,
        fos_req = 1.5,
        omega_rotor = omega_rotor,
        v_rated = v_rated,
        P_rated = power_W,
        max_ground_radius = 10.0,  # allow large ground rings for 50kW+
    )
    return result
end

# ── Build geometry for each design ──────────────────────────────────────────
struct DesignGeom
    label::String
    color::RGBf
    zs::Vector{Float64}       # ring axial positions (ground=0, hub=L)
    radii::Vector{Float64}    # ring radii
    n_rings::Int             # intermediate ring count
    n_lines::Int
    mass_kg::Float64
    r_hub::Float64
    r_bottom::Float64
    fos::Float64             # min buckling FoS
    tau_fos::Float64         # min torsional FoS
end

geoms = DesignGeom[]
for (i, dd) in enumerate(design_dicts)
    d = dd.design
    zs, radii, n_rings_int = ring_spacing_v4(
        d.r_hub, d.r_bottom, d.tether_length, d.target_Lr
    )

    # Evaluate structural FoS
    pk = get(dd.dict, "power_kw", 10.0)
    result = eval_for_hud(d, Float64(pk))
    fos = result.feasible ? result.min_fos : -1.0
    tau_fos = result.feasible ? result.min_torsional_fos : -1.0
    @printf("  %s: mass=%.2f kg, FoS=%.2f, τ_FoS=%.2f\n",
            dd.label, result.mass_total_kg, fos, tau_fos)

    push!(geoms, DesignGeom(
        dd.label,
        design_colors[mod1(i, length(design_colors))],
        zs, radii, n_rings_int, d.n_lines,
        get(dd.dict, "best_mass_kg", result.mass_total_kg),
        d.r_hub, d.r_bottom, fos, tau_fos
    ))
end

# ── Build 3D overlay scene ──────────────────────────────────────────────────
println("\nRendering overlay...")

fig = Figure(size=(1600, 950))
ax = Axis3(fig[1, 1];
    title       = "TRPT Tower Design Overlay — Structural Comparison",
    xlabel      = "Y [m]",
    ylabel      = "X [m]",
    zlabel      = "Z — Altitude [m]",
    aspect      = :data,
    titlesize   = 14,
)

# Helper: ring vertex positions
function ring_vertices(r::Float64, z::Float64, n_lines::Int)
    xs = Float64[]; ys = Float64[]; zs = Float64[]
    for j in 1:n_lines
        φ = 2π * (j - 1) / n_lines
        push!(xs, r * cos(φ))
        push!(ys, r * sin(φ))
        push!(zs, z)
    end
    # Close the polygon
    push!(xs, xs[1])
    push!(ys, ys[1])
    push!(zs, zs[1])
    return xs, ys, zs
end

# Render each design
legend_entries = []
for g in geoms
    col = g.color
    alpha_ring = 0.85
    alpha_tether = 0.45
    lw_ring = 2.5
    lw_tether = 1.2

    # Rings (polygons at each z)
    for (i, (z, r)) in enumerate(zip(g.zs, g.radii))
        xs, ys, zs_v = ring_vertices(r, z, g.n_lines)
        is_hub = (i == length(g.zs))           # top ring = hub
        is_ground = (i == 1)                     # bottom ring = ground
        lw = (is_hub || is_ground) ? 3.0 : lw_ring
        alpha_ = (is_hub || is_ground) ? 1.0 : alpha_ring
        # Render with Y/X swapped for standard wind-axis view (wind along +X)
        lines!(ax, ys, xs, zs_v;
               color = (col, alpha_),
               linewidth = lw)
    end

    # Tethers (longitudinal lines between ring vertices)
    for j in 1:g.n_lines
        tether_x = Float64[]
        tether_y = Float64[]
        tether_z = Float64[]
        for (i, (z, r)) in enumerate(zip(g.zs, g.radii))
            φ = 2π * (j - 1) / g.n_lines
            push!(tether_y, r * cos(φ))
            push!(tether_x, r * sin(φ))
            push!(tether_z, z)
        end
        lines!(ax, tether_x, tether_y, tether_z;
               color = (col, alpha_tether),
               linewidth = lw_tether)
    end

    # Knuckle dots at ring vertices (small scatter points)
    for (z, r) in zip(g.zs, g.radii)
        for j in 1:g.n_lines
            φ = 2π * (j - 1) / g.n_lines
            scatter!(ax, [r * sin(φ)], [r * cos(φ)], [z];
                     color = col, markersize = 4)
        end
    end

    push!(legend_entries, (g.label, col))
end

# Ground reference plane (translucent)
ground_extent = maximum([maximum(g.radii) for g in geoms]) * 1.5
for x in range(-ground_extent, ground_extent; step=5.0)
    lines!(ax, [x, x], [-ground_extent, ground_extent], [0.0, 0.0];
           color = (:grey, 0.12), linewidth = 0.5)
end
for y in range(-ground_extent, ground_extent; step=5.0)
    lines!(ax, [-ground_extent, ground_extent], [y, y], [0.0, 0.0];
           color = (:grey, 0.12), linewidth = 0.5)
end
# Ground anchor
scatter!(ax, [0.0], [0.0], [0.0]; color = :limegreen, markersize = 10)

# ── Legend (right side, overlaid) ────────────────────────────────────────────
legend_elements = [
    MarkerElement(; color = col, marker = :circle, markersize = 12,
                   strokecolor = :transparent)
    for (_, col) in legend_entries
]
legend_labels = [lbl for (lbl, _) in legend_entries]
Legend(fig[1, 1], legend_elements, legend_labels, "Designs";
       framevisible = true, padding = (10, 10, 10, 10),
       halign = :right, valign = :top, tellwidth = false, tellheight = false)

# ── HUD text overlay ─────────────────────────────────────────────────────────
function hud_text_lines(geom::DesignGeom)
    lines = String[]
    push!(lines, "── $(geom.label) ──")
    push!(lines, @sprintf("  Mass:     %.2f kg", geom.mass_kg))
    push!(lines, @sprintf("  r_hub:    %.2f m", geom.r_hub))
    push!(lines, @sprintf("  r_bottom: %.2f m", geom.r_bottom))
    push!(lines, @sprintf("  n_rings:  %d", geom.n_rings + 2))  # +2 for ground+hub
    push!(lines, @sprintf("  n_lines:  %d", geom.n_lines))
    if geom.fos > 0
        push!(lines, @sprintf("  FoS (buckle): %.2f", geom.fos))
        push!(lines, @sprintf("  τ FoS:        %.2f", geom.tau_fos))
    else
        push!(lines, "  FoS:  INFEASIBLE")
    end
    return join(lines, "\n")
end

hud_str = join([hud_text_lines(g) for g in geoms], "\n\n")

# Place HUD text using labels in a side layout
hud_grid = GridLayout(fig[1, 2]; tellwidth = false)
colsize!(fig.layout, 2, Fixed(280))

Label(hud_grid[1, 1], "Key Metrics";
      fontsize = 16, font = :bold, tellwidth = false)
Label(hud_grid[2, 1], hud_str;
      fontsize = 13, tellwidth = false, halign = :left, justification = :left)

# ── Camera preset: isometric from ~45° above, looking at centroid ───────────
max_z = maximum([maximum(g.zs) for g in geoms])
max_r = maximum([maximum(g.radii) for g in geoms])
ax.azimuth[] = 0.8π     # slightly off the downwind axis
ax.elevation[] = 0.35π  # ~60° above horizontal

# Auto-zoom to fit all designs
xlims!(ax, -max_r * 1.3, max_r * 1.3)
ylims!(ax, -max_r * 1.3, max_r * 1.3)
zlims!(ax, -max_z * 0.05, max_z * 1.15)

# ══════════════════════════════════════════════════════════════════════════════
# SAVE TO PNG
# ══════════════════════════════════════════════════════════════════════════════
output_dir = joinpath(dirname(@__DIR__), "scripts", "results")
mkpath(output_dir)
output_path = joinpath(output_dir, "design_overlay.png")

println("Saving to $output_path ...")
save(output_path, fig)
println("Done — $(stat(output_path).size) bytes written.")

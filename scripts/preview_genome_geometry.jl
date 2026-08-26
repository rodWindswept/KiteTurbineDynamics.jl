#!/usr/bin/env julia
# scripts/preview_genome_geometry.jl
#
# Visual 3D seed/genome geometry check — render the TRPT geometry a genome
# DECODES and the ODE BUILDS, so a wrong form is caught by eye BEFORE a DE
# campaign spends hours on it.
#
# Why this exists (2026-08-26): two recent geometry failures slipped through
# unseen —
#   1. the 08-24 dead genes (x6/x7/x9 ignored by the builder: decoded r_bottom
#      0.479 m, built 2.224 m), and
#   2. the 08-26 FoS off-by-one that hid a buckled transmission-cylinder ring
#      behind the top ring.
# Both are visible at a glance here: the 3D rings/rotors and the radius-vs-z
# profile show the transmission cylinder, the 22° cone, the harvest cylinder,
# and every rotor annulus.
#
# It renders the ACTUAL ODE system (build_system_from_v10 → sys + u0), not the
# decoder's intent, so builder/geometry bugs show up.  The printed summary also
# lists the decoder's r_hub/r_bottom so the two can be compared directly.
#
# Usage:
#   julia --project=. scripts/preview_genome_geometry.jl                 # 5 kW seed
#   julia --project=. scripts/preview_genome_geometry.jl --headless      # save PNG
#   julia --project=. scripts/preview_genome_geometry.jl --random 4      # seed + 4 random genomes
#   julia --project=. scripts/preview_genome_geometry.jl --csv path/best_vector.csv
#   julia --project=. scripts/preview_genome_geometry.jl --genome "0.06,0.01,..."
#
# Output: scripts/results/preview_genome*.png (or --out for the single case).

using Pkg;
Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics
using Printf
using LinearAlgebra
using Random
include(joinpath(@__DIR__, "compute_seeds.jl"))

# ── CLI ──────────────────────────────────────────────────────────────────────
function parse_cli()
    headless = "--headless" in ARGS
    out_path = nothing
    LENGTH = 18.8
    genome_csv = nothing
    genome_str = nothing
    n_random = 0
    for (i, a) in enumerate(ARGS)
        if a == "--length" && i < length(ARGS)
            LENGTH = parse(Float64, ARGS[i + 1])
        elseif a == "--out" && i < length(ARGS)
            out_path = ARGS[i + 1]
        elseif a == "--csv" && i < length(ARGS)
            genome_csv = ARGS[i + 1]
        elseif a == "--genome" && i < length(ARGS)
            genome_str = ARGS[i + 1]
        elseif a == "--random" && i < length(ARGS)
            n_random = parse(Int, ARGS[i + 1])
        end
    end
    return (
        headless=headless,
        out_path=out_path,
        LENGTH=LENGTH,
        genome_csv=genome_csv,
        genome_str=genome_str,
        n_random=n_random,
    )
end
const CLI = parse_cli()
const headless = CLI.headless
const out_path = CLI.out_path
const LENGTH = CLI.LENGTH
const genome_csv = CLI.genome_csv
const genome_str = CLI.genome_str
const n_random = CLI.n_random

# ── Makie backend ────────────────────────────────────────────────────────────
if headless
    @eval using CairoMakie
else
    @eval using GLMakie
end

const KW = 5.0
const PW = KW * 1000.0

# ── Campaign-equivalent params + decode knobs (mirror run_v13_5kw_masslift.jl) ──
# params_at_length: Daisy 1.5 kW → 5 kW via mass_scale, tether length restored.
function params_at_length(L::Float64)
    p2 = params_daisy()
    geo = GeometrySpec(
        p2.elevation_angle,
        p2.lifter_elevation,
        p2.rotor_radius,
        L,
        p2.trpt_hub_radius,
        p2.trpt_rL_ratio,
        p2.n_lines,
        p2.n_rings,
        p2.n_blades,
    )
    mat = MaterialSpec(p2.tether_diameter, p2.e_modulus, p2.m_ring, p2.m_blade)
    aero = AeroSpec(p2.rho, p2.v_wind_ref, p2.h_ref, p2.cp)
    ctrl = ControlSpec(
        p2.i_pto, p2.k_mppt, p2.p_rated_w, p2.β_min, p2.β_max, p2.β_rate_max, p2.kp_elev
    )
    back = BackLineSpec(
        p2.EA_back_line, p2.c_back_line, p2.back_anchor_fwd_x, p2.backline_payout
    )
    scaled = mass_scale(SystemParams(geo, mat, aero, ctrl, back), 1.5, KW)
    return override_params(scaled; tether_length=L)
end

# Round the discrete genome genes the way the campaign runner does.
function round_discrete!(x::Vector{Float64})
    x[8] = Float64(round(Int, clamp(x[8], 3, 16)))
    x[10] = Float64(round(Int, clamp(x[10], 1, 3)))
    return x
end

# ── Decode + build → the geometry the ODE actually sees ─────────────────────
struct GeometryPreview
    label::String
    genome::Vector{Float64}
    r_hub::Float64
    r_bottom::Float64
    n_rings::Int
    n_lines::Int
    n_active::Int
    taper_start_z::Float64
    harvest_length::Float64
    spacing_ok::Bool
    shaft_dir::Vector{Float64}
    ring_s::Vector{Float64}          # per-ring distance along shaft (ground→hub)
    ring_radii::Vector{Float64}
    ring_section::Vector{Symbol}     # :transmission / :cone / :harvest
    rotors::Vector{NamedTuple}       # (ring_idx, r_out, r_in, is_hub)
end

function build_preview(genome::Vector{Float64}, label::String; length_m::Float64=LENGTH)
    x = round_discrete!(copy(genome))
    p_base = params_at_length(length_m)
    dec = KiteTurbineDynamics.design_from_vector_v10(
        x,
        PROFILE_ELLIPTICAL,
        p_base;
        power_W=PW,
        cylinder_cone=true,
        rotor_count_mode=true,
        power_split=0.6,
        cone_slope_deg=22.0,
        rotor_spacing_frac=0.8,
        blocking_factor=1.0,
    )
    sys, u0, _ = KiteTurbineDynamics.build_system_from_v10(
        dec, 1.0, p_base.k_mppt; tether_diameter=p_base.tether_diameter
    )

    pos(i) = u0[(3 * (i - 1) + 1):(3 * i)]
    centers = [pos(id) for id in sys.ring_ids]
    radii = [(sys.nodes[id]::RingNode).radius for id in sys.ring_ids]

    # Shaft direction from the built geometry (ground → hub).
    shaft = normalize(centers[end] .- centers[1])
    s = [dot(c .- centers[1], shaft) for c in centers]

    # Section labels from the decoder's boundaries (transmission cylinder →
    # cone → harvest cylinder), ground-first.
    t_start = dec.taper_start_z
    t_harv_start = dec.design.tether_length - dec.harvest_length
    section = map(s) do si
        return if si <= t_start + 1e-6
            :transmission
        elseif si >= t_harv_start - 1e-6
            :harvest
        else
            :cone
        end
    end

    # Rotor annuli: main (hub) rotor + expansion rotors.
    rotors = NamedTuple[]
    push!(
        rotors,
        (
            ring_idx=length(sys.ring_ids),
            r_out=sys.rotor.radius,
            r_in=sys.rotor.blade_hub_radius,
            is_hub=true,
        ),
    )
    for er in sys.expansion_rotors
        r_ring = radii[er.ring_idx]
        push!(
            rotors,
            (
                ring_idx=er.ring_idx,
                r_out=r_ring + er.blade_tip_radius,
                r_in=max(r_ring + er.blade_hub_radius, 0.0),
                is_hub=false,
            ),
        )
    end

    return GeometryPreview(
        label,
        x,
        dec.design.r_hub,
        dec.design.r_bottom,
        length(sys.ring_ids),
        dec.design.n_lines,
        dec.n_active,
        t_start,
        dec.harvest_length,
        dec.spacing_ok,
        shaft,
        s,
        radii,
        section,
        rotors,
    )
end

# ── Print summary ────────────────────────────────────────────────────────────
function print_summary(pv::GeometryPreview)
    println("═══ $(pv.label) ═══")
    println("  genome: ", join([@sprintf("%.3f", g) for g in pv.genome], ", "))
    @printf(
        "  r_hub=%.3f m   r_bottom=%.3f m   n_rings=%d   n_lines=%d   n_active=%d\n",
        pv.r_hub,
        pv.r_bottom,
        pv.n_rings,
        pv.n_lines,
        pv.n_active
    )
    @printf(
        "  transmission_cylinder=%.2f m   harvest_cylinder=%.2f m   spacing_ok=%s\n",
        pv.taper_start_z,
        pv.harvest_length,
        string(pv.spacing_ok)
    )
    for r in pv.rotors
        @printf(
            "  rotor ring %d: r_in=%.2f  r_out=%.2f  span=%.2f%s\n",
            r.ring_idx,
            r.r_in,
            r.r_out,
            r.r_out - r.r_in,
            r.is_hub ? "  (hub)" : ""
        )
    end
    for i in 1:pv.n_rings
        @printf(
            "  ring %2d  s=%6.2f m  r=%5.3f m  %s\n",
            i,
            pv.ring_s[i],
            pv.ring_radii[i],
            string(pv.ring_section[i])
        )
    end
end

# ── Geometry helpers ─────────────────────────────────────────────────────────
function circle_pts(center, radius, shaft_dir; n=48)
    e2 = cross(shaft_dir, [0.0, 1.0, 0.0])
    if norm(e2) < 1e-9
        e2 = cross(shaft_dir, [1.0, 0.0, 0.0])
    end
    normalize!(e2)
    e1 = cross(e2, shaft_dir)
    normalize!(e1)
    t = range(0, 2π; length=n + 1)
    x = [center[1] + radius * (cos(θ) * e1[1] + sin(θ) * e2[1]) for θ in t]
    y = [center[2] + radius * (cos(θ) * e1[2] + sin(θ) * e2[2]) for θ in t]
    z = [center[3] + radius * (cos(θ) * e1[3] + sin(θ) * e2[3]) for θ in t]
    return (x, y, z)
end

SECTION_COLOR = Dict(
    :transmission => RGBf(0.12, 0.56, 1.00),   # blue
    :cone => RGBf(1.00, 0.55, 0.00),   # orange
    :harvest => RGBf(0.18, 0.55, 0.34),   # green
)
ROTOR_COLOR = RGBf(0.70, 0.13, 0.13)           # firebrick

function draw_geometry_3d!(ax, pv::GeometryPreview)
    for i in 1:pv.n_rings
        c = pv.ring_s[i] .* pv.shaft_dir
        x, y, z = circle_pts(c, pv.ring_radii[i], pv.shaft_dir)
        lines!(ax, x, y, z; color=SECTION_COLOR[pv.ring_section[i]], linewidth=2.2)
    end
    # Ground ring (index 1) emphasised.
    x, y, z = circle_pts([0.0, 0.0, 0.0], pv.ring_radii[1], pv.shaft_dir)
    lines!(ax, x, y, z; color=:black, linewidth=4.0)
    # Rotor annuli: outer solid, inner dashed.
    for r in pv.rotors
        c = pv.ring_s[r.ring_idx] .* pv.shaft_dir
        xo, yo, zo = circle_pts(c, r.r_out, pv.shaft_dir)
        lines!(ax, xo, yo, zo; color=ROTOR_COLOR, linewidth=2.0)
        xi, yi, zi = circle_pts(c, r.r_in, pv.shaft_dir)
        lines!(ax, xi, yi, zi; color=ROTOR_COLOR, linestyle=:dash)
    end
    # Section boundaries on the shaft axis.
    harv_start = maximum(pv.ring_s) - pv.harvest_length
    for b in (pv.taper_start_z, harv_start)
        (b <= 0.0 || b >= maximum(pv.ring_s)) && continue
        pb = b .* pv.shaft_dir
        scatter!(ax, [pb[1]], [pb[2]], [pb[3]]; color=:black, markersize=8)
    end
    ax.aspect = :data
    return ax
end

function draw_profile_2d!(ax, pv::GeometryPreview)
    for sec in (:transmission, :cone, :harvest)
        idx = findall(==(sec), pv.ring_section)
        isempty(idx) && continue
        scatter!(
            ax, pv.ring_s[idx], pv.ring_radii[idx]; color=SECTION_COLOR[sec], markersize=9
        )
        lines!(
            ax, pv.ring_s[idx], pv.ring_radii[idx]; color=SECTION_COLOR[sec], linewidth=2
        )
    end
    # Boundaries.
    axlims = (0.0, maximum(pv.ring_s))
    for b in (pv.taper_start_z, maximum(pv.ring_s) - pv.harvest_length)
        (b > axlims[1] && b < axlims[2]) && vlines!(ax, b; color=:grey, linestyle=:dot)
    end
    ax.xlabel = "distance along shaft (m)"
    ax.ylabel = "ring radius (m)"
    return ax
end

# ── Build the genome list ────────────────────────────────────────────────────
genomes = Tuple{Vector{Float64}, String}[]
if genome_csv !== nothing
    xs = parse.(Float64, split(strip(read(genome_csv, String)), r"[\s,]+"; keepempty=false))
    push!(genomes, (xs, "csv:" * basename(genome_csv)))
end
if genome_str !== nothing
    xs = parse.(Float64, split(genome_str, r"[\s,]+"; keepempty=false))
    push!(genomes, (xs, "cli-genome"))
end
if n_random > 0
    seed_v = seed_genome(KW)
    lo, hi = tight_bounds(seed_v, KW)
    for i in 1:n_random
        x = round_discrete!(lo .+ (hi .- lo) .* rand(length(lo)))
        push!(genomes, (x, "random-$i"))
    end
end
if isempty(genomes)
    push!(genomes, (seed_genome(KW), "5kW-seed"))
end

previews = [build_preview(x, lbl) for (x, lbl) in genomes]
foreach(print_summary, previews)

# ── Render ───────────────────────────────────────────────────────────────────
if length(previews) == 1
    fig = Figure(; size=(1400, 560))
    ax3d = Axis3(
        fig[1, 1]; title=previews[1].label, xlabel="x (m)", ylabel="y (m)", zlabel="z (m)"
    )
    ax2d = Axis(fig[1, 2]; title="radius profile")
    draw_geometry_3d!(ax3d, previews[1])
    draw_profile_2d!(ax2d, previews[1])
    dest = if out_path === nothing
        joinpath(@__DIR__, "results", "preview_genome.png")
    else
        out_path
    end
else
    n = length(previews)
    fig = Figure(; size=(380 * n, 380))
    for (i, pv) in enumerate(previews)
        ax = Axis3(fig[1, i]; title=pv.label)
        draw_geometry_3d!(ax, pv)
    end
    dest = joinpath(@__DIR__, "results", "preview_genome_grid.png")
end

if headless
    mkpath(dirname(dest))
    save(dest, fig)
    println("\nWrote $dest")
else
    # Keep the GLMakie window alive until the user closes it.  A bare
    # display(fig) in a script lets the process exit and the window vanish
    # immediately.  Block on the Screen (Base.isopen(::Screen) is defined);
    # a Scene has no isopen method.
    screen = GLMakie.Screen()
    display(screen, fig)
    println("\nViewer open — close the window to exit.")
    while isopen(screen)
        sleep(0.25)
    end
end

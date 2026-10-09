#!/usr/bin/env julia
# scratch/hero_gs_probe.jl — composition probe ONLY (not a release figure).
#
# Purpose: show Rod the proposed "ground station goes here" glyph on the
# winner-hero side view before it is baked into the machine-winner-hero kit.
# Draws the island 3 winner (gen 26) from the built state through the same
# decode + build + projection path as the committed strip script
# (docs/reporting/figures/machine-evolution-strip/machine-evolution-strip.jl),
# then adds: a ground line below the datum and a small triangle under the
# axis — the schematic ground-station marker.  No numbers change; the glyph
# asserts nothing and carries no register row.
#
# Run:  scripts/ktd-julia scratch/hero_gs_probe.jl
# Out:  scratch/hero_gs_probe.png

using KiteTurbineDynamics, Printf, LinearAlgebra
const KTD = KiteTurbineDynamics
using CairoMakie

const ROOT = normpath(joinpath(@__DIR__, ".."))
include(joinpath(ROOT, "scripts", "compute_seeds.jl"))

const KW = 5.0
const PW = KW * 1000.0
const V_RATED = 11.0
const LENGTH = 18.8
const BF = BLOCKING_WIND_FACTOR_5KW
const FOS_HARD = 2.5

const C_INK = RGBf(0.10, 0.10, 0.10)
const C_GREY = RGBf(0.33, 0.33, 0.33)
const C_FAINT = RGBf(0.47, 0.47, 0.47)
const C_SHAFT = RGBf(0.77, 0.77, 0.77)
const C_MARK = RGBf(0.85, 0.85, 0.85)
const C_TRANS = RGBf(0.12, 0.56, 1.00)
const C_CONE = RGBf(1.00, 0.55, 0.00)
const C_HARV = RGBf(0.18, 0.55, 0.34)
const C_ROTOR = RGBf(0.70, 0.13, 0.13)
const C_ROPE = RGBf(0.60, 0.63, 0.66)
const C_BLADE = RGBf(0.23, 0.23, 0.23)
const C_GROUND = RGBf(0.15, 0.15, 0.15)
const SECTION_COLOR = Dict(
    :transmission => C_TRANS, :cone => C_CONE, :harvest => C_HARV
)

const EXTRACT = joinpath(ROOT, "docs", "reporting", "figures",
    "machine-evolution-strip", "extract-best-so-far.csv")

tandeg(x) = tan(deg2rad(x))

# ── params at length (mirrors the strip script) ──────────────────────────────
function params_at_length(L::Float64)
    p2 = params_daisy()
    geo = GeometrySpec(p2.elevation_angle, p2.lifter_elevation, p2.rotor_radius,
        L, p2.trpt_hub_radius, p2.trpt_rL_ratio, p2.n_lines, p2.n_rings, p2.n_blades)
    mat = MaterialSpec(p2.tether_diameter, p2.e_modulus, p2.m_ring, p2.m_blade)
    aero = AeroSpec(p2.rho, p2.v_wind_ref, p2.h_ref, p2.cp)
    ctrl = ControlSpec(p2.i_pto, p2.k_mppt, p2.p_rated_w, p2.β_min, p2.β_max,
        p2.β_rate_max, p2.kp_elev)
    back = BackLineSpec(p2.EA_back_line, p2.c_back_line, p2.back_anchor_fwd_x,
        p2.backline_payout)
    scaled = mass_scale(SystemParams(geo, mat, aero, ctrl, back), 1.5, KW)
    return override_params(scaled; tether_length=L)
end

const P_BASE = params_at_length(LENGTH)

round_discrete!(x::Vector{Float64}) = begin
    xr = copy(x)
    if length(xr) >= 14
        xr[8] = Float64(round(Int, clamp(xr[8], 3, 16)))
        xr[10] = Float64(round(Int, clamp(xr[10], 1, 3)))
    else
        xr[4] = Float64(round(Int, clamp(xr[4], 3, 16)))
        xr[6] = Float64(round(Int, clamp(xr[6], 1, 3)))
    end
    xr
end

function read_extract(path::AbstractString)
    lines = readlines(path)
    data = [l for l in lines if !startswith(l, "#") && !isempty(strip(l))]
    header = split(data[1], ",")
    return [Dict(String(k) => String(v) for (k, v) in zip(header, split(l, ",")))
            for l in data[2:end]]
end

# ── decode + build + drawn geometry (same as the strip script) ───────────────
struct Panel
    label::String
    gen::Int
    genome::Vector{Float64}
    s::Vector{Float64}
    radii::Vector{Float64}
    sections::Vector{Symbol}
    ropes2d::Vector{Vector{Tuple{Float64,Float64}}}
    quads::Vector{Vector{Tuple{Float64,Float64}}}
    blades::Vector{Tuple{Tuple{Float64,Float64},Tuple{Float64,Float64}}}
    markers::Vector{Float64}
    checks::Vector{Pair{String,Bool}}
    xmax::Float64
    ymin::Float64
    ymax::Float64
end

function build_panel(rec::Dict{String,String})
    xraw = [parse(Float64, rec["x$j"]) for j in 1:10]
    xesc = round_discrete!(xraw)
    dec = design_from_vector_v10(xesc, PROFILE_ELLIPTICAL, P_BASE; power_W=PW,
        cylinder_cone=true, rotor_count_mode=true, power_split=0.6,
        cone_slope_deg=22.0, rotor_spacing_frac=0.8, blocking_factor=BF,
        v_rated=V_RATED)
    cfg = KTD.ObjectiveConfig(;
        power_W=PW, v_rated=V_RATED, p_floor_kw=KW, fos_target=FOS_HARD,
        fos_hard=FOS_HARD, min_wall_m=2e-3, t_over_D=0.055,
        rotor_count_mode=true, power_split=0.6, blocking_factor=BF,
    )
    sizing = KTD.size_beams_closed_form(dec, P_BASE, cfg)
    sys, u0, pc = KTD.build_system_from_v10(dec, 1.0, K_MPPT_5KW_HONEST;
        tether_diameter=P_BASE.tether_diameter, base_params=P_BASE,
        min_wall_m=2e-3, beam_sizing=sizing)

    Nn = sys.n_total
    pos(id) = u0[3 * (id - 1) + 1:3 * id]
    centers = [pos(id) for id in sys.ring_ids]
    radii = [(sys.nodes[id]::RingNode).radius for id in sys.ring_ids]
    shaft = normalize(centers[end] .- centers[1])
    svec = [dot(c .- centers[1], shaft) for c in centers]
    t_start = dec.taper_start_z
    t_harv = dec.design.tether_length - dec.harvest_length
    sections = map(svec) do si
        si <= t_start + 1e-6 ? :transmission :
        (si >= t_harv - 1e-6 ? :harvest : :cone)
    end

    c1 = centers[1]
    side = normalize(cross([0.0, 1.0, 0.0], shaft))
    proj2(p) = (dot(p .- c1, side), dot(p .- c1, shaft))

    ropes2d = Vector{Vector{Tuple{Float64,Float64}}}()
    for seg in 1:(sys.n_ring - 1), j in 1:pc.n_lines
        xs, ys, zs = KTD._rope_line_pts(u0, sys, pc, seg, j)
        push!(ropes2d, [proj2([xs[i], ys[i], zs[i]]) for i in eachindex(xs)])
    end

    rotor_specs = [(ring_idx=length(sys.ring_ids), r_out=sys.rotor.radius,
        r_in=sys.rotor.blade_hub_radius, bank=sys.rotor.bank_angle_deg)]
    for er in sys.expansion_rotors
        push!(rotor_specs, (ring_idx=er.ring_idx,
            r_out=radii[er.ring_idx] + er.blade_tip_radius,
            r_in=max(radii[er.ring_idx] + er.blade_hub_radius, 0.0),
            bank=er.bank_angle_deg))
    end

    quads = Vector{Vector{Tuple{Float64,Float64}}}()
    blades = Vector{Tuple{Tuple{Float64,Float64},Tuple{Float64,Float64}}}()
    n_blades = dec.design.n_lines
    for rt in rotor_specs
        r_ring = radii[rt.ring_idx]
        Δout = max(rt.r_out - r_ring, 0.0) * tandeg(abs(rt.bank))
        Δin = max(r_ring - rt.r_in, 0.0) * tandeg(abs(rt.bank))
        s_r = svec[rt.ring_idx]
        y_out = s_r - Δout
        y_in = s_r + Δin
        push!(quads, [(-rt.r_in, y_in), (rt.r_in, y_in),
            (rt.r_out, y_out), (-rt.r_out, y_out)])
        ctr = centers[rt.ring_idx]
        alpha0 = u0[6Nn + rt.ring_idx]
        e2 = normalize(cross(shaft, side))
        for j in 1:n_blades
            θ = alpha0 + 2π * (j - 1) / n_blades
            d = cos(θ) .* side .+ sin(θ) .* e2
            p_in = ctr .+ d .* rt.r_in .+ shaft .* Δin
            p_out = ctr .+ d .* rt.r_out .- shaft .* Δout
            push!(blades, (proj2(p_in), proj2(p_out)))
        end
    end

    markers = [b for b in (t_start, t_harv) if 0.0 < b]

    xs = Float64[]
    ys = Float64[]
    for q in quads, pt in q
        push!(xs, pt[1]); push!(ys, pt[2])
    end
    for bl in blades
        push!(xs, bl[1][1], bl[2][1]); push!(ys, bl[1][2], bl[2][2])
    end
    for r in ropes2d, pt in r
        push!(xs, pt[1]); push!(ys, pt[2])
    end
    push!(xs, maximum(radii)); push!(ys, maximum(svec))

    checks = Pair{String,Bool}[
        "n_lines" => dec.design.n_lines == parse(Int, rec["n_lines"]),
        "rings" => length(sys.ring_ids) == parse(Int, rec["rings"]),
        "n_active" => dec.n_active == parse(Int, rec["n_active"]),
        "r_hub" => isapprox(dec.design.r_hub, parse(Float64, rec["r_hub"]); atol=1e-3),
        "r_bot" => isapprox(dec.design.r_bottom, parse(Float64, rec["r_bot"]); atol=1e-3),
    ]
    return Panel(rec["label"], parse(Int, rec["selected_gen"]), xraw,
        svec, radii, sections, ropes2d, quads, blades, markers,
        checks, maximum(abs, xs), minimum(ys), maximum(ys))
end

# ── drawing ──────────────────────────────────────────────────────────────────
function draw_panel!(ax, p::Panel, X::Float64, Ylo::Float64, Yhi::Float64, gy::Float64)
    lines!(ax, [0.0, 0.0], [Ylo, Yhi]; color=C_SHAFT, linewidth=0.9,
        linestyle=:dash)
    for b in p.markers
        lines!(ax, [-X, X], [b, b]; color=C_MARK, linewidth=0.5, linestyle=:dot)
    end
    for r in p.ropes2d
        lines!(ax, [pt[1] for pt in r], [pt[2] for pt in r];
            color=C_ROPE, linewidth=0.8)
    end
    for q in p.quads
        poly!(ax, q; color=(C_ROTOR, 0.18), strokecolor=C_ROTOR, strokewidth=0.8)
    end
    for i in 2:length(p.radii)
        lines!(ax, [-p.radii[i], p.radii[i]], [p.s[i], p.s[i]];
            color=SECTION_COLOR[p.sections[i]], linewidth=1.9)
    end
    lines!(ax, [-p.radii[1], p.radii[1]], [p.s[1], p.s[1]];
        color=C_INK, linewidth=3.4)
    for bl in p.blades
        lines!(ax, [bl[1][1], bl[2][1]], [bl[1][2], bl[2][2]];
            color=C_BLADE, linewidth=2.0)
    end
    return ax
end

function draw_ground_marker!(ax, X::Float64, gy::Float64)
    # ground line
    lines!(ax, [-X, X], [gy, gy]; color=C_GROUND, linewidth=1.4)
    # ground-station glyph: one triangle, apex up, centred on the axis
    tri = [(-0.90, gy), (0.90, gy), (0.0, gy + 1.35)]
    poly!(ax, tri; color=RGBf(1, 1, 1), strokecolor=C_INK, strokewidth=1.8)
    text!(ax, 1.25, gy + 0.72; text="ground station", fontsize=10.5,
        color=C_INK, align=(:left, :center))
    return ax
end

# ── main ─────────────────────────────────────────────────────────────────────
function main()
    recs = read_extract(EXTRACT)
    rec = recs[end]                       # island-3 winner, gen 26
    p = build_panel(rec)
    @printf("panel %s (gen %d): ", p.label, p.gen)
    println(join(["$k $v" for (k, v) in p.checks], " · "))

    X = 1.06 * p.xmax
    gy = min(0.0, p.ymin) - 1.6
    Ylo = gy - 0.9
    Ytop = p.ymax
    Yhi = Ytop + 0.04 * (Ytop - Ylo)
    panel_h = 760
    mpp = (Yhi - Ylo) / panel_h
    panel_w = round(Int, 2X / mpp)
    fig_w = panel_w + 28
    fig_h = 96 + panel_h + 64

    fig = Figure(size=(fig_w, fig_h), backgroundcolor=RGBf(1, 1, 1))
    gl = GridLayout(fig[1, 1])

    hax = Axis(gl[1, 1]; limits=((0, 1), (0, 1)))
    hidedecorations!(hax); hidespines!(hax)
    text!(hax, 0.008, 0.72; text="Winner hero probe — side view with the ground-station glyph",
        fontsize=13.0, color=C_INK, align=(:left, :center))
    text!(hax, 0.008, 0.24;
        text="island 3 winner (gen 26) · built geometry · glyph is schematic, no number",
        fontsize=9, color=C_GREY, align=(:left, :center))

    ax = Axis(gl[2, 1]; limits=((-X, X), (Ylo, Yhi)),
        aspect=DataAspect(), backgroundcolor=RGBf(1, 1, 1))
    hidedecorations!(ax); hidespines!(ax)
    draw_panel!(ax, p, X, Ylo, Yhi, gy)
    draw_ground_marker!(ax, X, gy)

    fax = Axis(gl[3, 1]; limits=((0, 1), (0, 1)))
    hidedecorations!(fax); hidespines!(fax)
    bx = 14.0
    bar_px = 5.0 / mpp
    lines!(fax, [bx / fig_w, (bx + bar_px) / fig_w], [0.62, 0.62];
        color=C_INK, linewidth=1.6)
    lines!(fax, [bx / fig_w, bx / fig_w], [0.50, 0.74]; color=C_INK, linewidth=1.0)
    lines!(fax, [(bx + bar_px) / fig_w, (bx + bar_px) / fig_w], [0.50, 0.74];
        color=C_INK, linewidth=1.0)
    text!(fax, (bx + bar_px + 10) / fig_w, 0.62; text="5 m", fontsize=8.5,
        color=C_INK, align=(:left, :center))
    text!(fax, 14 / fig_w, 0.16;
        text="probe only — do not cite · glyph: triangle under the axis, ground line 1.6 m below datum",
        fontsize=7, color=C_FAINT, align=(:left, :center))

    colsize!(gl, 1, Fixed(fig_w))
    rowsize!(gl, 1, Fixed(96))
    rowsize!(gl, 2, Fixed(panel_h))
    rowsize!(gl, 3, Fixed(64))
    colgap!(gl, 0.0)
    rowgap!(gl, 0.0)

    out = joinpath(@__DIR__, "hero_gs_probe.png")
    save(out, fig; px_per_unit=2.0)
    @printf("wrote %s  (%d x %d px at 1x · m_per_px %.6f)\n", out, fig_w, fig_h, mpp)
    return nothing
end

main()

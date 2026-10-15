#!/usr/bin/env julia
# docs/reporting/figures/machine-corner-grid/machine-corner-grid.jl
#
# Generating script for the corner machines (figure map row 23,
# machine-renderer SPEC, family mode, corner-grid variant — spec delta D10).
# Four panels, one per corner of the PC1-PC2 field: the nearest feasible
# design to each [1,99] percentile window corner (NR-051, signed
# 2026-10-14). Drawn from the built state at one shared scale. Each panel
# carries its corner, its identity tag and its search objective (NR-051).
# Axes are square: both scales read m_per_px.
#
# Run:
#   scripts/ktd-julia docs/reporting/figures/machine-corner-grid/machine-corner-grid.jl \
#       --script-commit <hex>
#
# Outputs (this directory): machine-corner-grid.svg / .pdf / .png,
# manifest.json, checks.log.
#
# Engine: CairoMakie (the machine-renderer D7 steer). No ODE — decode +
# build + render only, with the recorded campaign knobs and v_rated
# threaded (aero-validator delta, 2026-10-08).
#
# F-REPRO: PNG and SVG are byte-stable as written. Cairo stamps the PDF
# with a wall-clock CreationDate, so the pipeline normalises it:
#   cairo -> `mutool clean -dg` -> byte-exact same-length date replace ->
#   `mutool clean -zg`. The -g pass garbage-collects cairo's unreferenced
#   stream-length objects (the one wobbling byte class, 2026-10-14).
#   Toolchain: julia 1.12.5, CairoMakie 0.15.11, mutool 1.23.10.

using KiteTurbineDynamics, Printf, LinearAlgebra
const KTD = KiteTurbineDynamics
using CairoMakie
using JSON3
using SHA

const ROOT = normpath(joinpath(@__DIR__, "..", "..", "..", ".."))
include(joinpath(ROOT, "scripts", "compute_seeds.jl"))

# ── constants ────────────────────────────────────────────────────────────────
const SLUG = "machine-corner-grid"
const DATA_COMMIT = "dd3cc6a"
const EXTRACT_ID = "corner-grid-extract-2026-10-15-picks"
const REGISTER_ROWS = "NR-044 · NR-051"
const SCALE_BAR_M = 5.0
const PANEL_H_PX = 340
const GAP_PX = 16
const HEADER_PX = 84
const LABELS_PX = 60
const FOOTER_PX = 132

# NR-051 display forms (signed 2026-10-14). The label strips draw these.
const OBJ_BY_TAG = Dict("i1-g13-i1" => "60.646", "i1-g7-i7" => "58.864",
    "i2-g21-i4" => "33.704", "i3-g26-i8" => "33.812")

# The signed pick order (NR-051): corner, tag.
const PICK_ORDER = [
    ("low PC1 / low PC2", "i1-g13-i1"),
    ("low PC1 / high PC2", "i1-g7-i7"),
    ("high PC1 / low PC2", "i2-g21-i4"),
    ("high PC1 / high PC2", "i3-g26-i8"),
]

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
const SECTION_COLOR = Dict(
    :transmission => C_TRANS, :cone => C_CONE, :harvest => C_HARV
)

const TITLE = "The corner machines: one typical design from each corner of the PC1-PC2 field"
const SUB = "Built geometry at one shared scale · the value under each machine is its search objective in kg, lower is better · one pick per window corner, the nearest feasible design (NR-051)"

tandeg(x) = tan(deg2rad(x))

# ── params at length (mirrors run_v13_5kw_masslift.jl + the winner pack) ─────
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

# ── extract ──────────────────────────────────────────────────────────────────
function read_extract(path::AbstractString)
    lines = readlines(path)
    data = [l for l in lines if !startswith(l, "#") && !isempty(strip(l))]
    header = split(data[1], ",")
    return [Dict(String(k) => String(v) for (k, v) in zip(header, split(l, ",")))
            for l in data[2:end]]
end

# ── panel: decode + build + drawn geometry (2D shaft frame) ──────────────────
struct Panel
    corner::String
    tag::String
    gen::Int
    genome::Vector{Float64}
    source_row::Int
    objective::String
    s::Vector{Float64}
    radii::Vector{Float64}
    sections::Vector{Symbol}
    ropes2d::Vector{Vector{Tuple{Float64,Float64}}}
    quads::Vector{Vector{Tuple{Float64,Float64}}}
    blades::Vector{Tuple{Tuple{Float64,Float64},Tuple{Float64,Float64}}}
    markers::Vector{Float64}
    counts::NamedTuple
    checks::Vector{Pair{String,Bool}}
    xmax::Float64
    ymin::Float64
    ymax::Float64
    checksok::Bool
end

function build_panel(rec::Dict{String,String}, rownum::Int)
    xraw = [parse(Float64, rec["x$j"]) for j in 1:10]
    gen = parse(Int, rec["gen"])
    tag = rec["tag"]
    corner = rec["corner"]
    obj = rec["fitness"]
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

    # bounds from the drawn elements
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
        "objective" => obj == OBJ_BY_TAG[tag],
    ]
    return Panel(
        corner, tag, gen, xraw, rownum, obj,
        svec, radii, sections, ropes2d, quads, blades, markers,
        (rings=length(radii), gaps=sys.n_ring - 1, lines_per_gap=pc.n_lines,
            rotors=length(rotor_specs), blades_per_rotor=n_blades,
            blade_segments=length(blades),
            polylines=length(ropes2d), markers=length(markers)),
        checks, maximum(abs, xs), minimum(ys), maximum(ys), all(last, checks),
    )
end

# ── PDF date normalisation (byte-exact, same length) ─────────────────────────
function normalise_pdf_date!(path::AbstractString)
    b = read(path)
    out = copy(b)
    repl = Vector{UInt8}(codeunits("D:19700101000000+00'00"))
    nrep = 0
    i = 1
    while i <= length(out) - 21
        if out[i] == 0x44 && out[i + 1] == 0x3a
            ok = true
            for j in 0:13
                c = out[i + 2 + j]
                ok &= (0x30 <= c <= 0x39)
            end
            if ok
                s = i + 16
                if (out[s] == 0x2b || out[s] == 0x2d) && out[s + 3] == 0x27
                    for k in 1:22
                        out[i + k - 1] = repl[k]
                    end
                    nrep += 1
                    i += 22
                    continue
                end
            end
        end
        i += 1
    end
    write(path, out)
    return nrep
end

# ── drawing ──────────────────────────────────────────────────────────────────
function draw_panel!(ax, p::Panel, X::Float64, Ylo::Float64, Yhi::Float64)
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

function footer_entries!(ax, fig_w::Int, y::Float64)
    x = 14.0
    entries = [
        (:line, C_INK, "ground ring"),
        (:line, C_TRANS, "ring, transmission"),
        (:line, C_CONE, "ring, cone"),
        (:line, C_HARV, "ring, harvest"),
        (:poly, C_ROTOR, "swept annulus — trapezoid"),
        (:line, C_BLADE, "blade"),
        (:line, C_ROPE, "TRPT lines"),
    ]
    for (kind, color, label) in entries
        if kind == :line
            lines!(ax, [x / fig_w, (x + 16) / fig_w], [y, y];
                color=color, linewidth=2.4)
        else
            poly!(ax, Rect(x / fig_w, y - 0.05, 16 / fig_w, 0.10);
                color=(color, 0.18), strokecolor=color, strokewidth=0.8)
        end
        text!(ax, (x + 21) / fig_w, y; text=label, fontsize=9,
            color=C_INK, align=(:left, :center))
        x += 21 + 5.0 * length(label) + 20
    end
end

# ── main ─────────────────────────────────────────────────────────────────────
function main()
    script_commit = "uncommitted"
    outdir = @__DIR__
    extract_path = joinpath(@__DIR__, "extract-corner-grid.csv")
    i = 1
    while i <= length(ARGS)
        a = ARGS[i]
        if a == "--script-commit"
            script_commit = ARGS[i + 1]; i += 2
        elseif a == "--outdir"
            outdir = ARGS[i + 1]; i += 2
        elseif a == "--extract"
            extract_path = ARGS[i + 1]; i += 2
        else
            error("unknown argument: $a")
        end
    end
    mkpath(outdir)

    recs = read_extract(extract_path)
    panels = [build_panel(recs[k], k) for k in eachindex(recs)]

    # the signed pick order reads in PICK_ORDER; assert it as a finding
    order_ok = [(p.corner, p.tag) for p in panels] == PICK_ORDER

    # window: one shared data window for the set
    X0 = 1.06 * maximum(p.xmax for p in panels)
    Ytop = maximum(p.ymax for p in panels)
    Ybot = minimum(p.ymin for p in panels)
    padY = 0.04 * (Ytop - Ybot)
    Ylo = Ybot - padY
    Yhi = Ytop + padY
    mpp = (Yhi - Ylo) / PANEL_H_PX          # metres per pixel, the declared scale
    # square axes: grow the window to the next whole pixel so both scales read mpp
    panel_w = ceil(Int, 2X0 / mpp)
    X = panel_w * mpp / 2
    n = length(panels)
    fig_w = n * panel_w + (n - 1) * GAP_PX
    fig_h = HEADER_PX + PANEL_H_PX + LABELS_PX + FOOTER_PX

    fig = Figure(size=(fig_w, fig_h), backgroundcolor=RGBf(1, 1, 1))
    gl = GridLayout(fig[1, 1])

    # header
    hax = Axis(gl[1, 1]; limits=((0, 1), (0, 1)))
    hidedecorations!(hax); hidespines!(hax)
    text!(hax, 0.006, 0.68; text=TITLE, fontsize=14, color=C_INK,
        align=(:left, :center))
    text!(hax, 0.006, 0.22; text=SUB, fontsize=9.5, color=C_GREY,
        align=(:left, :center))

    # panels: one row of four, one shared scale
    pg1 = GridLayout(gl[2, 1])
    axs = Axis[]
    for (k, p) in enumerate(panels)
        ax = Axis(pg1[1, k]; limits=((-X, X), (Ylo, Yhi)),
            aspect=DataAspect(), backgroundcolor=RGBf(1, 1, 1))
        push!(axs, ax)
        hidedecorations!(ax); hidespines!(ax)
        draw_panel!(ax, p, X, Ylo, Yhi)
    end

    # label strip under the panel row
    lax = Axis(gl[3, 1]; limits=((0, 1), (0, 1)))
    hidedecorations!(lax); hidespines!(lax)
    for (k, p) in enumerate(panels)
        xf = ((k - 1) * (panel_w + GAP_PX) + panel_w / 2) / fig_w
        text!(lax, xf, 0.82; text=p.corner, fontsize=12, color=C_INK,
            align=(:center, :center))
        text!(lax, xf, 0.50; text=p.tag, fontsize=9.5, color=C_GREY,
            align=(:center, :center))
        text!(lax, xf, 0.16; text="objective $(p.objective) kg", fontsize=9.5,
            color=C_INK, align=(:center, :center))
    end

    # footer
    fax = Axis(gl[4, 1]; limits=((0, 1), (0, 1)))
    hidedecorations!(fax); hidespines!(fax)

    # fixed sizes and zero gaps — set once every child of the layout exists.
    colsize!(gl, 1, Fixed(fig_w))
    rowsize!(gl, 1, Fixed(HEADER_PX))
    rowsize!(gl, 2, Fixed(PANEL_H_PX))
    rowsize!(gl, 3, Fixed(LABELS_PX))
    rowsize!(gl, 4, Fixed(FOOTER_PX))
    colgap!(gl, 0.0)
    rowgap!(gl, 0.0)
    for k in 1:n
        colsize!(pg1, k, Fixed(panel_w))
    end
    for k in 1:(n - 1)
        colgap!(pg1, k, GAP_PX)
    end

    # footer content
    footer_entries!(fax, fig_w, 0.90)
    bx = 14.0
    bar_px = SCALE_BAR_M / mpp
    lines!(fax, [bx / fig_w, (bx + bar_px) / fig_w], [0.64, 0.64];
        color=C_INK, linewidth=1.6)
    lines!(fax, [bx / fig_w, bx / fig_w], [0.575, 0.705]; color=C_INK, linewidth=1.0)
    lines!(fax, [(bx + bar_px) / fig_w, (bx + bar_px) / fig_w], [0.575, 0.705];
        color=C_INK, linewidth=1.0)
    text!(fax, (bx + bar_px + 10) / fig_w, 0.64; text="$(Int(SCALE_BAR_M)) m",
        fontsize=9.5, color=C_INK, align=(:left, :center))
    stamp1 = "source: data commit $DATA_COMMIT · extract $EXTRACT_ID.csv · picks the nearest feasible design per [1,99] window corner (NR-051)"
    stamp2 = "rows $REGISTER_ROWS · script commit $script_commit · engine CairoMakie · PDF date normalised to 1970-01-01"
    stamp3 = "shaft frame: distance along the shaft is vertical · the operating elevation is not drawn"
    text!(fax, 14 / fig_w, 0.40; text=stamp1, fontsize=8, color=C_FAINT,
        align=(:left, :center))
    text!(fax, 14 / fig_w, 0.24; text=stamp2, fontsize=8, color=C_FAINT,
        align=(:left, :center))
    text!(fax, 14 / fig_w, 0.08; text=stamp3, fontsize=8, color=C_FAINT,
        align=(:left, :center))

    # ── outputs ──────────────────────────────────────────────────────────────
    png_path = joinpath(outdir, "$SLUG.png")
    svg_path = joinpath(outdir, "$SLUG.svg")
    pdf_path = joinpath(outdir, "$SLUG.pdf")
    save(png_path, fig; px_per_unit=3.0)
    save(svg_path, fig)

    mutool = Sys.which("mutool")
    mutool === nothing && error("mutool not found on PATH — needed for the PDF date normalisation")
    vfile = tempname()
    run(pipeline(ignorestatus(`$mutool --version`), stdout=vfile, stderr=vfile))
    mver = match(r"version (\d+(?:\.\d+)+)", read(vfile, String))
    rm(vfile; force=true)
    mutool_ver = mver === nothing ? "unknown" : mver.captures[1]
    tmp_pdf = joinpath(outdir, ".$SLUG.tmp.pdf")
    clean_pdf = joinpath(outdir, ".$SLUG.tmp.clean.pdf")
    norm_pdf = joinpath(outdir, ".$SLUG.tmp.norm.pdf")
    save(tmp_pdf, fig)
    run(pipeline(`$mutool clean -dg $tmp_pdf $clean_pdf`; stdout=devnull))
    nrep = normalise_pdf_date!(clean_pdf)
    run(pipeline(`$mutool clean -zg $clean_pdf $norm_pdf`; stdout=devnull))
    mv(norm_pdf, pdf_path; force=true)
    rm(tmp_pdf; force=true); rm(clean_pdf; force=true)

    # ── checks ───────────────────────────────────────────────────────────────
    loglines = String[]
    push!(loglines, "machine-corner-grid — GENERATE run")
    push!(loglines, "script commit: $script_commit")
    push!(loglines, "toolchain: julia $(VERSION) · CairoMakie $(Base.pkgversion(CairoMakie)) · mutool $mutool_ver")
    push!(loglines, "extract: $(relpath(extract_path, ROOT))  sha256 $(bytes2hex(sha256(read(extract_path))))")
    ok_all = true
    for p in panels
        ok = all(last, p.checks)
        ok_all &= ok
        ck = join(["$k $v" for (k, v) in p.checks], " · ")
        push!(loglines, "panel $(p.tag) [$(p.corner)] (gen $(p.gen)): $ck")
        push!(loglines, "  drawn: ring segments $(p.counts.rings) (incl ground) · TRPT polylines $(p.counts.polylines) ($(p.counts.lines_per_gap) lines x $(p.counts.gaps) gaps) · rotor quads $(p.counts.rotors) · blade segments $(p.counts.blade_segments) ($(p.counts.blades_per_rotor)/rotor) · section markers $(p.counts.markers)")
    end
    # NR-051 pick-order check: the four corners in the signed order
    push!(loglines, "corner order (NR-051): $(order_ok ? "OK — the four signed picks in the signed order" : "FAIL")")
    ok_all &= order_ok
    for p in panels
        push!(loglines, "  $(p.corner): $(p.tag) · objective $(p.objective) kg")
    end
    push!(loglines, @sprintf(
        "window: x ±%.3f m · y %.3f .. %.3f m · m_per_px %.6f · panel %d x %d px · figure %d x %d px · scale bar %.1f m",
        X, Ylo, Yhi, mpp, panel_w, PANEL_H_PX, fig_w, fig_h, SCALE_BAR_M))
    vpf(a) = (v = a.scene.viewport[];
        @sprintf("[%d,%d + %dx%d]", v.origin[1], v.origin[2], v.widths[1], v.widths[2]))
    push!(loglines, "layout viewports: header $(vpf(hax)) · labels $(vpf(lax)) · footer $(vpf(fax)) · panel1 $(vpf(axs[1])) · panel4 $(vpf(axs[end]))")
    v1 = axs[1].scene.viewport[]
    xpxpm = v1.widths[1] / (2X)
    ypxpm = v1.widths[2] / (Yhi - Ylo)
    push!(loglines, @sprintf("axis squareness: x %.9f px/m · y %.9f px/m · delta %.4f ppm",
        xpxpm, ypxpm, (xpxpm / ypxpm - 1.0) * 1e6))
    obj_ok = all(panels) do p
        j = findfirst(c -> first(c) == "objective", p.checks)
        j !== nothing && last(p.checks[j])
    end
    push!(loglines, "objective labels (NR-051): $(length(panels)) drawn · $(obj_ok ? "ALL OK" : "FAIL")")
    push!(loglines, "pdf normalisation: clean -dg ok · CreationDate replacements $nrep · clean -zg ok")
    push!(loglines, "outputs sha256:")
    for f in ("$SLUG.png", "$SLUG.svg", "$SLUG.pdf")
        push!(loglines, "  $f  $(bytes2hex(sha256(read(joinpath(outdir, f)))))")
    end
    push!(loglines, ok_all ? "checks: ALL OK" : "checks: FAIL")
    write(joinpath(outdir, "checks.log"), join(loglines, "\n") * "\n")

    # ── manifest ─────────────────────────────────────────────────────────────
    manifest = (
        set=SLUG, mode="family", variant="corner-grid", slug=SLUG,
        script_commit=script_commit,
        script=(path="docs/reporting/figures/$SLUG/$SLUG.jl",
            sha256=bytes2hex(sha256(read(joinpath(@__DIR__, "$SLUG.jl"))))),
        toolchain=(julia=string(VERSION),
            cairomakie=string(Base.pkgversion(CairoMakie)), mutool=mutool_ver,
            pdf_date_normalised_to="1970-01-01T00:00:00+00:00"),
        data_commit=DATA_COMMIT,
        extract=(path="docs/reporting/figures/$SLUG/extract-corner-grid.csv",
            sha256=bytes2hex(sha256(read(extract_path)))),
        selection=(rule="for each [1,99] percentile window corner of the certified PC1-PC2 projection (NR-044), the feasible (ok) design of least Euclidean distance; one pick per corner; no interpolation",
            corners=[p.corner for p in panels],
            picks=[p.tag for p in panels]),
        registers=["NR-044", "NR-051"],
        knobs=(power_W=PW, v_rated=V_RATED, tether_length=LENGTH,
            k_mppt=K_MPPT_5KW_HONEST, blocking_factor=BF, cylinder_cone=true,
            rotor_count_mode=true, power_split=0.6, cone_slope_deg=22.0,
            rotor_spacing_frac=0.8, min_wall_m=2e-3, t_over_D=0.055),
        scale=(m_per_px=mpp, window=(x=[-X, X], y=[Ylo, Yhi]),
            panel_px=[panel_w, PANEL_H_PX], scale_bar_m=SCALE_BAR_M,
            tolerance_px=0.05),
        panels=[(corner=p.corner, tag=p.tag, gen=p.gen, genome=p.genome,
            source_row=p.source_row, objective=p.objective,
            pc=[parse(Float64, recs[p.source_row]["pc1"]),
                parse(Float64, recs[p.source_row]["pc2"])],
            counts=p.counts) for p in panels],
        command="scripts/ktd-julia docs/reporting/figures/$SLUG/$SLUG.jl --script-commit $script_commit",
        outputs=Dict(
            "$SLUG.png" => bytes2hex(sha256(read(png_path))),
            "$SLUG.svg" => bytes2hex(sha256(read(svg_path))),
            "$SLUG.pdf" => bytes2hex(sha256(read(pdf_path))),
            "checks.log" => bytes2hex(sha256(read(joinpath(outdir, "checks.log")))),
        ),
    )
    open(io -> JSON3.pretty(io, manifest), joinpath(outdir, "manifest.json"), "w")
    open(io -> println(io), joinpath(outdir, "manifest.json"), "a")

    @printf("wrote %s, %s, %s, manifest.json, checks.log to %s\n",
        "$SLUG.png", "$SLUG.svg", "$SLUG.pdf", outdir)
    ok_all || error("checks FAILED — see checks.log")
    return nothing
end

main()

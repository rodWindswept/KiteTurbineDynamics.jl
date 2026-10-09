#!/usr/bin/env julia
# docs/reporting/figures/machine-evolution-strip/machine-evolution-strip.jl
#
# Generating script for the machine evolution strip (figure map row 9,
# machine-renderer SPEC, mode: strip). Seven panels: the island 3 best-so-far
# machine at generations 0, 6, 10, 18, 22, 25 and 26, drawn from the built
# state at one shared scale.
#
# Run:
#   scripts/ktd-julia docs/reporting/figures/machine-evolution-strip/machine-evolution-strip.jl \
#       --script-commit <hex>
#
# Outputs (this directory): machine-evolution-strip.svg / .pdf / .png,
# manifest.json, checks.log.
#
# Engine: CairoMakie (the machine-renderer D7 steer; TikZ release backend stays
# open to the room).  No ODE — decode + build + render only, mirroring
# scratch/hermes_winner_pack.jl and scripts/preview_genome_geometry.jl, with
# the recorded campaign knobs and v_rated threaded (aero-validator delta,
# 2026-10-08).
#
# F-REPRO: PNG and SVG are byte-stable as written.  Cairo stamps the PDF with a
# wall-clock CreationDate, so the pipeline normalises it:
#   cairo -> `mutool clean -d` -> byte-exact same-length date replace ->
#   `mutool clean -z`.  Both mutool passes are deterministic given their input
#   (probe 2026-10-09).  Toolchain: julia 1.12.5, CairoMakie 0.15.11,
#   mutool 1.23.10.

using KiteTurbineDynamics, Printf, LinearAlgebra
const KTD = KiteTurbineDynamics
using CairoMakie
using JSON3
using SHA

const ROOT = normpath(joinpath(@__DIR__, "..", "..", "..", ".."))
include(joinpath(ROOT, "scripts", "compute_seeds.jl"))

# ── constants ────────────────────────────────────────────────────────────────
const SLUG = "machine-evolution-strip"
const DATA_COMMIT = "dd3cc6a"
const EXTRACT_ID = "strip-extract-2026-10-09-best-so-far"
const REGISTER_ROWS = "NR-005 · NR-006 · NR-011"
const SCALE_BAR_M = 5.0
const PANEL_H_PX = 340
const GAP_PX = 16
const HEADER_PX = 84
const LABELS_PX = 40
const FOOTER_PX = 132

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

const TITLE = "Island 3 best-so-far: seven machines from the seed to the winner"
const SUB = "Built geometry at one shared scale · generations 0 · 6 · 10 · 18 · 22 · 25 · 26"

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
    label::String
    gen::Int
    genome::Vector{Float64}
    source_row::Int
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
    ]
    return Panel(
        rec["label"], parse(Int, rec["selected_gen"]), xraw, rownum,
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
        text!(ax, (x + 21) / fig_w, y; text=label, fontsize=8.5,
            color=C_INK, align=(:left, :center))
        x += 21 + 5.0 * length(label) + 20
    end
end

# ── main ─────────────────────────────────────────────────────────────────────
function main()
    script_commit = "uncommitted"
    outdir = @__DIR__
    extract_path = joinpath(@__DIR__, "extract-best-so-far.csv")
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

    # window: one shared data window for the set
    X = 1.06 * maximum(p.xmax for p in panels)
    Ytop = maximum(p.ymax for p in panels)
    Ybot = minimum(p.ymin for p in panels)
    padY = 0.04 * (Ytop - Ybot)
    Ylo = Ybot - padY
    Yhi = Ytop + padY
    mpp = (Yhi - Ylo) / PANEL_H_PX          # metres per pixel, the declared scale
    panel_w = round(Int, 2X / mpp)
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

    # panels
    pg = GridLayout(gl[2, 1])
    axs = Axis[]
    for (k, p) in enumerate(panels)
        ax = Axis(pg[1, k]; limits=((-X, X), (Ylo, Yhi)),
            aspect=DataAspect(), backgroundcolor=RGBf(1, 1, 1))
        push!(axs, ax)
        hidedecorations!(ax); hidespines!(ax)
        draw_panel!(ax, p, X, Ylo, Yhi)
    end

    # label strips
    lax = Axis(gl[3, 1]; limits=((0, 1), (0, 1)))
    hidedecorations!(lax); hidespines!(lax)
    for (k, p) in enumerate(panels)
        xf = ((k - 1) * (panel_w + GAP_PX) + panel_w / 2) / fig_w
        text!(lax, xf, 0.74; text="gen $(p.gen)", fontsize=11, color=C_INK,
            align=(:center, :center))
        text!(lax, xf, 0.24; text=p.label, fontsize=8, color=C_GREY,
            align=(:center, :center))
    end

    # footer
    fax = Axis(gl[4, 1]; limits=((0, 1), (0, 1)))
    hidedecorations!(fax); hidespines!(fax)

    # fixed sizes and zero gaps — set once every child of the layout exists.
    # Nested grids carry an 18 px default row gap; unreserved, it pushed the
    # whole stack 27 px above and below the canvas (layout probe, 2026-10-09).
    colsize!(gl, 1, Fixed(fig_w))
    rowsize!(gl, 1, Fixed(HEADER_PX))
    rowsize!(gl, 2, Fixed(PANEL_H_PX))
    rowsize!(gl, 3, Fixed(LABELS_PX))
    rowsize!(gl, 4, Fixed(FOOTER_PX))
    colgap!(gl, 0.0)
    rowgap!(gl, 0.0)
    for k in 1:n
        colsize!(pg, k, Fixed(panel_w))
    end
    colgap!(pg, GAP_PX)
    for k in 1:(n - 1)
        colgap!(pg, k, GAP_PX)
    end

    # footer content
    footer_entries!(fax, fig_w, 0.86)
    bx = 14.0
    bar_px = SCALE_BAR_M / mpp
    lines!(fax, [bx / fig_w, (bx + bar_px) / fig_w], [0.52, 0.52];
        color=C_INK, linewidth=1.6)
    lines!(fax, [bx / fig_w, bx / fig_w], [0.46, 0.58]; color=C_INK, linewidth=1.0)
    lines!(fax, [(bx + bar_px) / fig_w, (bx + bar_px) / fig_w], [0.46, 0.58];
        color=C_INK, linewidth=1.0)
    text!(fax, (bx + bar_px + 10) / fig_w, 0.52; text="$(Int(SCALE_BAR_M)) m",
        fontsize=8.5, color=C_INK, align=(:left, :center))
    stamp1 = "source: data commit $DATA_COMMIT · extract $EXTRACT_ID.csv · island 3 best-so-far {0, 6, 10, 18, 22, 25, 26}"
    stamp2 = "rows $REGISTER_ROWS · script commit $script_commit · engine CairoMakie · PDF date normalised to 1970-01-01"
    text!(fax, 14 / fig_w, 0.24; text=stamp1, fontsize=6.8, color=C_FAINT,
        align=(:left, :center))
    text!(fax, 14 / fig_w, 0.10; text=stamp2, fontsize=6.8, color=C_FAINT,
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
    run(pipeline(`$mutool clean -d $tmp_pdf $clean_pdf`; stdout=devnull))
    nrep = normalise_pdf_date!(clean_pdf)
    run(pipeline(`$mutool clean -z $clean_pdf $norm_pdf`; stdout=devnull))
    mv(norm_pdf, pdf_path; force=true)
    rm(tmp_pdf; force=true); rm(clean_pdf; force=true)

    # ── checks ───────────────────────────────────────────────────────────────
    loglines = String[]
    push!(loglines, "machine-evolution-strip — GENERATE run")
    push!(loglines, "script commit: $script_commit")
    push!(loglines, "toolchain: julia $(VERSION) · CairoMakie $(Base.pkgversion(CairoMakie)) · mutool $mutool_ver")
    push!(loglines, "extract: $(relpath(extract_path, ROOT))  sha256 $(bytes2hex(sha256(read(extract_path))))")
    ok_all = true
    for p in panels
        ok = all(last, p.checks)
        ok_all &= ok
        ck = join(["$k $v" for (k, v) in p.checks], " · ")
        push!(loglines, "panel $(p.label) (gen $(p.gen)): $ck")
        push!(loglines, "  drawn: ring segments $(p.counts.rings) (incl ground) · TRPT polylines $(p.counts.polylines) ($(p.counts.lines_per_gap) lines x $(p.counts.gaps) gaps) · rotor quads $(p.counts.rotors) · blade segments $(p.counts.blade_segments) ($(p.counts.blades_per_rotor)/rotor) · section markers $(p.counts.markers)")
    end
    # NR-011 winner-panel check (gen 26)
    wp = panels[argmax([p.gen for p in panels])]
    wchk = [
        "n_lines 3" => wp.checks[1].second,
        "rings 6" => wp.checks[2].second,
        "r_hub 4.580" => wp.checks[4].second,
        "r_bot 0.804" => wp.checks[5].second,
    ]
    ok_all &= all(last, wchk)
    push!(loglines, "NR-011 winner-panel check (gen $(wp.gen)): " *
        join(["$k $v" for (k, v) in wchk], " · "))
    push!(loglines, @sprintf(
        "window: x ±%.3f m · y %.3f .. %.3f m · m_per_px %.6f · panel %d x %d px · figure %d x %d px · scale bar %.1f m",
        X, Ylo, Yhi, mpp, panel_w, PANEL_H_PX, fig_w, fig_h, SCALE_BAR_M))
    vpf(a) = (v = a.scene.viewport[];
        @sprintf("[%d,%d + %dx%d]", v.origin[1], v.origin[2], v.widths[1], v.widths[2]))
    push!(loglines, "layout viewports: header $(vpf(hax)) · labels $(vpf(lax)) · footer $(vpf(fax)) · panel1 $(vpf(axs[1])) · panel7 $(vpf(axs[end]))")
    push!(loglines, "pdf normalisation: clean -d ok · CreationDate replacements $nrep · clean -z ok")
    push!(loglines, "outputs sha256:")
    for f in ("$SLUG.png", "$SLUG.svg", "$SLUG.pdf")
        push!(loglines, "  $f  $(bytes2hex(sha256(read(joinpath(outdir, f)))))")
    end
    push!(loglines, ok_all ? "checks: ALL OK" : "checks: FAIL")
    write(joinpath(outdir, "checks.log"), join(loglines, "\n") * "\n")

    # ── manifest ─────────────────────────────────────────────────────────────
    manifest = (
        set=SLUG, mode="strip", slug=SLUG,
        script_commit=script_commit,
        script=(path="docs/reporting/figures/$SLUG/$SLUG.jl",
            sha256=bytes2hex(sha256(read(joinpath(@__DIR__, "$SLUG.jl"))))),
        toolchain=(julia=string(VERSION),
            cairomakie=string(Base.pkgversion(CairoMakie)), mutool=mutool_ver,
            pdf_date_normalised_to="1970-01-01T00:00:00+00:00"),
        data_commit=DATA_COMMIT,
        extract=(path="docs/reporting/figures/$SLUG/extract-best-so-far.csv",
            sha256=bytes2hex(sha256(read(extract_path)))),
        selection=(rule="island 3 best-so-far, ok rows, earliest (gen, idx) tie-break; no interpolation",
            generations=[p.gen for p in panels]),
        registers=["NR-005", "NR-006", "NR-011"],
        knobs=(power_W=PW, v_rated=V_RATED, tether_length=LENGTH,
            k_mppt=K_MPPT_5KW_HONEST, blocking_factor=BF, cylinder_cone=true,
            rotor_count_mode=true, power_split=0.6, cone_slope_deg=22.0,
            rotor_spacing_frac=0.8, min_wall_m=2e-3, t_over_D=0.055),
        scale=(m_per_px=mpp, window=(x=[-X, X], y=[Ylo, Yhi]),
            panel_px=[panel_w, PANEL_H_PX], scale_bar_m=SCALE_BAR_M),
        panels=[(label=p.label, gen=p.gen, genome=p.genome,
            source_row=p.source_row, counts=p.counts) for p in panels],
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

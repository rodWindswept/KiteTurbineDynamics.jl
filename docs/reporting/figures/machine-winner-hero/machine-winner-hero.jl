#!/usr/bin/env julia
# docs/reporting/figures/machine-winner-hero/machine-winner-hero.jl
#
# Generating script for the machine-winner-hero view set (figure map row 10,
# machine-renderer SPEC, mode: hero). One design: the island-3 winner, drawn
# as the plan / side / downwind capture set at one shared scale.
#
# The drawn state (SPEC delta D9, 2026-10-14): the *recorded final operating
# pose* of the winner — ring stations and per-segment twist read from the
# signed pair-extract capture (final integration step of the measurement
# window, the NR-021/NR-022 basis). The built-state construction (decode +
# build, no ODE) supplies the section classes and the rotor spec. The plain
# built state reads an untwisted shaft (probe scratch/fig_hero_state_probe.jl:
# all ring azimuth states 0.000 deg), so the settled twisted form the founder
# asks for comes from the capture, not a fresh settle run. No ODE runs here.
#
# Run:
#   scripts/ktd-julia docs/reporting/figures/machine-winner-hero/machine-winner-hero.jl \
#       --script-commit <hex>
#
# Outputs (this directory): machine-winner-hero.svg / .pdf / .png,
# manifest.json, checks.log.
#
# Engine: CairoMakie (the machine-renderer D7 steer). Two-dimensional drawing
# with explicit orthographic projections per view — no axis3, no freehand.
#
# F-REPRO: PNG and SVG are byte-stable as written. Cairo stamps the PDF with a
# wall-clock CreationDate, so the pipeline normalises it:
#   cairo -> `mutool clean -d` -> byte-exact same-length date replace ->
#   `mutool clean -z`. Toolchain: julia 1.12.5, CairoMakie 0.15.11,
#   mutool 1.23.10.

using KiteTurbineDynamics, Printf, LinearAlgebra
const KTD = KiteTurbineDynamics
using CairoMakie
using JSON3
using SHA

const ROOT = normpath(joinpath(@__DIR__, "..", "..", "..", ".."))
include(joinpath(ROOT, "scripts", "compute_seeds.jl"))

# ── constants ────────────────────────────────────────────────────────────────
const SLUG = "machine-winner-hero"
const DATA_COMMIT = "dd3cc6a"
const GENOME_EXTRACT_ID = "strip-extract-2026-10-09-best-so-far"
const CAPTURE_ID = "pair-extract-2026-10-08-winner-ops"
const REGISTER_ROWS = "NR-011 · NR-017 · NR-021 · NR-022 · NR-043"
const ELEV_DEG = 28.64          # flown-basis elevation (NR-032 block, edge note 5)
const SCALE_BAR_M = 5.0
const MPP = 30.0                # metres per pixel, one scale for the set
const PANEL_H_PX = 660
const GAP_PX = 18
const HEADER_PX = 96
const LABELS_PX = 44
const FOOTER_PX = 158

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

const TITLE = "The island-3 winner at its operating point: plan, side and downwind"
const SUB1 = "Built geometry with the recorded wind-up: six rings, three lines, one rotor (NR-011); per-segment twist at the final operating step (NR-022)."
const SUB2 = "Ring stations read at the same step (NR-021). One scale holds across the three views. Blades: three, span 1.499 m (NR-043)."

tandeg(x) = tan(deg2rad(x))

# ── params at length (mirrors run_v13_5kw_masslift.jl + the strip script) ────
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

# ── readers ──────────────────────────────────────────────────────────────────
function read_extract(path::AbstractString)
    lines = readlines(path)
    data = [l for l in lines if !startswith(l, "#") && !isempty(strip(l))]
    header = split(data[1], ",")
    return [Dict(String(k) => String(v) for (k, v) in zip(header, split(l, ",")))
            for l in data[2:end]]
end

function read_capture(path::AbstractString)
    lines = readlines(path)
    data = [l for l in lines if !startswith(l, "#") && !isempty(strip(l))]
    header = split(data[1], ",")
    segs = Dict{String,Dict{String,String}}()
    rings = Dict{String,Dict{String,String}}()
    for l in data[2:end]
        rec = Dict(String(k) => String(v) for (k, v) in zip(header, split(l, ",")))
        if rec["block"] == "segment"
            segs[rec["id"]] = rec
        elseif rec["block"] == "ring"
            rings[rec["id"]] = rec
        end
    end
    return segs, rings
end

# ── the hero state ───────────────────────────────────────────────────────────
struct Hero
    label::String
    gen::Int
    genome::Vector{Float64}
    stations::Vector{Float64}          # R1..R6, metres along the shaft
    twists_deg::Vector{Float64}        # S1..S5, recorded |dalpha|
    alphas::Vector{Float64}            # R1..R6, cumulative, radians
    radii::Vector{Float64}             # R1..R6, metres (capture)
    sections::Vector{Symbol}           # per ring, from the built state
    r_in::Float64                      # blade inner extent (NR-043 basis)
    r_out::Float64                     # blade tip extent (NR-043 basis)
    bank_deg::Float64
    n_blades::Int
    din::Float64                       # inboard axial offset, metres
    dout::Float64                      # outboard axial offset, metres
    shaft::Vector{Float64}
    side::Vector{Float64}
    e2::Vector{Float64}
    centers::Vector{Vector{Float64}}
    checks::Vector{Pair{String,Bool}}
    counts::NamedTuple
end

function build_hero(rec::Dict{String,String}, segs, rings)
    xraw = [parse(Float64, rec["x$j"]) for j in 1:10]
    gen = parse(Int, rec["selected_gen"])
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

    # ── capture state: stations + twist ──────────────────────────────────────
    seg_ids = ["S$k" for k in 1:5]
    ring_ids = ["R$k" for k in 2:6]
    @assert all(haskey(segs, s) for s in seg_ids) "capture is missing a segment row"
    @assert all(haskey(rings, r) for r in ring_ids) "capture is missing a ring row"
    stations = [0.0; [parse(Float64, rings[r]["station_m"]) for r in ring_ids]]
    twists_deg = [parse(Float64, segs[s]["abs_dalpha_deg"]) for s in seg_ids]

    # radii from the capture segment block: r_a of S1; r_b of each segment
    r_bot_cap = parse(Float64, segs["S1"]["r_a_m"])
    radii = [r_bot_cap; [parse(Float64, segs[s]["r_b_m"]) for s in seg_ids]]
    # consistency: r_b of segment k must equal r_a of segment k+1 (k = 1..4)
    for k in 1:4
        ra_next = parse(Float64, segs["S$(k+1)"]["r_a_m"])
        @assert isapprox(radii[k + 1], ra_next; atol=1e-12) "capture radius chain breaks at S$k"
    end

    # cumulative wind-up. The capture stores |dalpha| only; the drawn sense is
    # the declared spin-sense convention: the hub leads the ground ring, so the
    # azimuths accumulate the recorded magnitudes from R1 upward.
    alphas = zeros(6)
    for k in 1:5
        alphas[k + 1] = alphas[k] + deg2rad(twists_deg[k])
    end

    # ── built state: sections, rotor spec, design radii cross-check ──────────
    pos(id) = u0[3 * (id - 1) + 1:3 * id]
    centers_u0 = [pos(id) for id in sys.ring_ids]
    radii_u0 = [(sys.nodes[id]::RingNode).radius for id in sys.ring_ids]
    shaft = normalize(centers_u0[end] .- centers_u0[1])
    svec_u0 = [dot(c .- centers_u0[1], shaft) for c in centers_u0]
    t_start = dec.taper_start_z
    t_harv = dec.design.tether_length - dec.harvest_length
    sections = map(svec_u0) do si
        si <= t_start + 1e-6 ? :transmission :
        (si >= t_harv - 1e-6 ? :harvest : :cone)
    end

    r_out = sys.rotor.radius                    # tip extent, R_main
    r_in = max(sys.rotor.blade_hub_radius, 0.0)
    bank = sys.rotor.bank_angle_deg
    n_blades = dec.design.n_lines
    span = r_out - r_in

    rad_delta = maximum(abs.(radii_u0 .- radii))

    checks = Pair{String,Bool}[
        "n_lines" => dec.design.n_lines == parse(Int, rec["n_lines"]),
        "rings" => length(sys.ring_ids) == parse(Int, rec["rings"]),
        "n_active" => dec.n_active == parse(Int, rec["n_active"]),
        "r_hub" => isapprox(dec.design.r_hub, parse(Float64, rec["r_hub"]); atol=1e-3),
        "r_bot" => isapprox(dec.design.r_bottom, parse(Float64, rec["r_bot"]); atol=1e-3),
        "capture_rows" => length(segs) == 5 && length(rings) == 5,
        "radii_capture_eq_built" => rad_delta <= 1e-9,
        "sections_order" => sections == [:transmission, :transmission,
            :transmission, :transmission, :cone, :harvest],
        "one_rotor" => isempty(sys.expansion_rotors) && sys.rotor !== nothing,
        "blades_3" => n_blades == 3,
        "span_NR043" => isapprox(span, 1.4994019682084492; atol=1e-12),
        "bank_NR017" => round(bank; digits=3) == 7.088,
        "stations_monotone" => all(diff(stations) .> 0.0),
        "twist_count" => length(twists_deg) == 5 && all(twists_deg .> 0.0),
        "twist_sum_lt_pi" => sum(twists_deg) < 180.0,
    ]

    # ── frame ────────────────────────────────────────────────────────────────
    β = deg2rad(ELEV_DEG)
    shaft_dir = [cos(β), 0.0, sin(β)]
    side = normalize(cross([0.0, 1.0, 0.0], shaft_dir))
    e2 = normalize(cross(shaft_dir, side))
    centers = [s .* shaft_dir for s in stations]

    Δout = max(r_out - radii[6], 0.0) * tandeg(abs(bank))
    Δin = max(radii[6] - r_in, 0.0) * tandeg(abs(bank))

    counts = (rings=6, gaps=5, lines_per_gap=3, ropes=15,
        rotor=1, blades=n_blades, annulus=1, glyph=1)

    return Hero(rec["label"], gen, xraw, stations, twists_deg, alphas, radii,
        sections, r_in, r_out, bank, n_blades, Δin, Δout,
        shaft_dir, side, e2, centers, checks, counts)
end

# ── geometry helpers ─────────────────────────────────────────────────────────
ring_node(h::Hero, k::Int, j::Int) = begin
    θ = h.alphas[k] + 2π * (j - 1) / 3
    h.centers[k] .+ h.radii[k] .* (cos(θ) .* h.side .+ sin(θ) .* h.e2)
end

blade_segment(h::Hero, j::Int) = begin
    θ = h.alphas[6] + 2π * (j - 1) / 3
    d = cos(θ) .* h.side .+ sin(θ) .* h.e2
    p_in = h.centers[6] .+ d .* h.r_in .+ h.shaft .* h.din
    p_out = h.centers[6] .+ d .* h.r_out .- h.shaft .* h.dout
    (p_in, p_out)
end

rope_chord(h::Hero, k::Int, j::Int) = (ring_node(h, k, j), ring_node(h, k + 1, j))

# ── projections (orthographic, per view) ─────────────────────────────────────
proj_side(h::Hero, p) = (dot(p .- h.centers[1], h.side), dot(p .- h.centers[1], h.shaft))
proj_plan(h::Hero, p) = (dot(p .- h.centers[6], h.side), dot(p .- h.centers[6], h.e2))
proj_down(h::Hero, p) = (p[2], p[3])

# ── drawing ──────────────────────────────────────────────────────────────────
function draw_side!(ax, h::Hero, gy::Float64, xr::Float64)
    # shaft-frame elevation: radial vs distance along the shaft
    lines!(ax, [0.0, 0.0], [-2.0, 20.0]; color=C_SHAFT, linewidth=0.9,
        linestyle=:dash)
    # TRPT chords (all 15), drawn light
    for k in 1:5, j in 1:3
        a, b = rope_chord(h, k, j)
        pa = proj_side(h, a); pb = proj_side(h, b)
        lines!(ax, [pa[1], pb[1]], [pa[2], pb[2]]; color=C_ROPE, linewidth=0.8)
    end
    # swept annulus as one truncated cone (trapezoid)
    s6 = h.stations[6]
    y_in = s6 + h.din; y_out = s6 - h.dout
    quad = [(-h.r_in, y_in), (h.r_in, y_in), (h.r_out, y_out), (-h.r_out, y_out)]
    poly!(ax, quad; color=(C_ROTOR, 0.18), strokecolor=C_ROTOR, strokewidth=0.8)
    # ring bars (the SPEC segment convention), R2..R6
    for i in 2:6
        lines!(ax, [-h.radii[i], h.radii[i]], [h.stations[i], h.stations[i]];
            color=SECTION_COLOR[h.sections[i]], linewidth=1.9)
    end
    # ground ring R1, heavy ink
    lines!(ax, [-h.radii[1], h.radii[1]], [0.0, 0.0]; color=C_INK, linewidth=3.4)
    # blades
    for j in 1:h.n_blades
        a, b = blade_segment(h, j)
        pa = proj_side(h, a); pb = proj_side(h, b)
        lines!(ax, [pa[1], pb[1]], [pa[2], pb[2]]; color=C_BLADE, linewidth=2.0)
    end
    # ground line + ground-station glyph (schematic, no number)
    lines!(ax, [-xr, xr], [gy, gy]; color=C_GROUND, linewidth=1.4)
    tri = [(-0.90, gy), (0.90, gy), (0.0, gy + 1.35)]
    poly!(ax, tri; color=RGBf(1, 1, 1), strokecolor=C_INK, strokewidth=1.8)
    return ax
end

function draw_plan!(ax, h::Hero)
    # looking along the shaft: the rotor face, rings as node polygons
    for k in 6:-1:2
        pts = [proj_plan(h, ring_node(h, k, j)) for j in 1:3]
        poly!(ax, pts; color=(SECTION_COLOR[h.sections[k]], 0.06),
            strokecolor=SECTION_COLOR[h.sections[k]], strokewidth=1.6)
    end
    # ground ring R1 drawn last, ink-heavy
    pts1 = [proj_plan(h, ring_node(h, 1, j)) for j in 1:3]
    poly!(ax, pts1; color=(C_INK, 0.0), strokecolor=C_INK, strokewidth=3.0)
    # swept annulus: circles at r_in and r_out (smooth swept region)
    θs = range(0, 2π; length=241)
    for r in (h.r_in, h.r_out)
        xs = r .* cos.(θs); ys = r .* sin.(θs)
        lines!(ax, xs, ys; color=C_ROTOR, linewidth=0.8)
    end
    # TRPT chords
    for k in 1:5, j in 1:3
        a, b = rope_chord(h, k, j)
        pa = proj_plan(h, a); pb = proj_plan(h, b)
        lines!(ax, [pa[1], pb[1]], [pa[2], pb[2]]; color=C_ROPE, linewidth=0.8)
    end
    # blades
    for j in 1:h.n_blades
        a, b = blade_segment(h, j)
        pa = proj_plan(h, a); pb = proj_plan(h, b)
        lines!(ax, [pa[1], pb[1]], [pa[2], pb[2]]; color=C_BLADE, linewidth=2.0)
    end
    return ax
end

function draw_downwind!(ax, h::Hero, gy::Float64, xr::Float64)
    # looking along the wind: the machine foreshortened by its flown elevation
    for k in 6:-1:2
        pts = [proj_down(h, ring_node(h, k, j)) for j in 1:3]
        poly!(ax, pts; color=(SECTION_COLOR[h.sections[k]], 0.06),
            strokecolor=SECTION_COLOR[h.sections[k]], strokewidth=1.6)
    end
    # ground ring R1 drawn last, ink-heavy
    pts1 = [proj_down(h, ring_node(h, 1, j)) for j in 1:3]
    poly!(ax, pts1; color=(C_INK, 0.0), strokecolor=C_INK, strokewidth=3.0)
    # swept annulus: flattened ellipses about the hub centre
    β = deg2rad(ELEV_DEG)
    c6 = proj_down(h, h.centers[6])
    θs = range(0, 2π; length=241)
    for r in (h.r_in, h.r_out)
        xs = c6[1] .+ r .* sin.(θs)
        ys = c6[2] .- r .* cos.(θs) .* cos(β)
        lines!(ax, xs, ys; color=C_ROTOR, linewidth=0.8)
    end
    for k in 1:5, j in 1:3
        a, b = rope_chord(h, k, j)
        pa = proj_down(h, a); pb = proj_down(h, b)
        lines!(ax, [pa[1], pb[1]], [pa[2], pb[2]]; color=C_ROPE, linewidth=0.8)
    end
    for j in 1:h.n_blades
        a, b = blade_segment(h, j)
        pa = proj_down(h, a); pb = proj_down(h, b)
        lines!(ax, [pa[1], pb[1]], [pa[2], pb[2]]; color=C_BLADE, linewidth=2.0)
    end
    lines!(ax, [-xr, xr], [gy, gy]; color=C_GROUND, linewidth=1.4)
    return ax
end

# ── annotations (side view): short labels with leaders ───────────────────────
function annotate_side!(ax, h::Hero)
    lw = 0.9
    gap = 0.14
    # hub ring R6: leader to the ring bar right end, from a right-side text
    tgt = (h.radii[6], h.stations[6])
    lines!(ax, [tgt[1] + gap, tgt[1] + 1.6], [tgt[2] + 0.10, tgt[2] + 0.55];
        color=C_GREY, linewidth=lw)
    text!(ax, tgt[1] + 1.75, tgt[2] + 0.62; text="hub ring R6",
        fontsize=10.5, color=C_INK, align=(:left, :center))
    # TRPT shaft: leader to the right cone line, mid-height
    a, b = rope_chord(h, 5, 3)
    pa = proj_side(h, a); pb = proj_side(h, b)
    mid = (0.5 * (pa[1] + pb[1]), 0.5 * (pa[2] + pb[2]))
    lines!(ax, [mid[1] + 0.28, mid[1] + 1.5], [mid[2] + 0.08, mid[2] + 0.66];
        color=C_GREY, linewidth=lw)
    text!(ax, mid[1] + 1.65, mid[2] + 0.72; text="TRPT shaft",
        fontsize=10.5, color=C_INK, align=(:left, :center))
    # ground ring R1: leader from the left side
    lines!(ax, [-h.radii[1] - 1.9, -h.radii[1] - gap], [0.55, 0.10];
        color=C_GREY, linewidth=lw)
    text!(ax, -h.radii[1] - 2.05, 0.62; text="ground ring R1",
        fontsize=10.5, color=C_INK, align=(:right, :center))
    # ground-station glyph label
    text!(ax, 1.25, -0.88; text="ground station", fontsize=10.5, color=C_INK,
        align=(:left, :center))
    return ax
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

# ── main ─────────────────────────────────────────────────────────────────────
function main()
    script_commit = "uncommitted"
    outdir = @__DIR__
    genome_extract = joinpath(ROOT, "docs", "reporting", "figures",
        "machine-evolution-strip", "extract-best-so-far.csv")
    capture = joinpath(ROOT, "docs", "reporting", "figures",
        "pair-extract", "extract-winner-operating-point.csv")
    i = 1
    while i <= length(ARGS)
        a = ARGS[i]
        if a == "--script-commit"
            script_commit = ARGS[i + 1]; i += 2
        elseif a == "--outdir"
            outdir = ARGS[i + 1]; i += 2
        elseif a == "--extract"
            genome_extract = ARGS[i + 1]; i += 2
        elseif a == "--capture"
            capture = ARGS[i + 1]; i += 2
        else
            error("unknown argument: $a")
        end
    end
    mkpath(outdir)

    recs = read_extract(genome_extract)
    rec = recs[end]                        # island-3 winner, gen 26
    segs, rings = read_capture(capture)
    h = build_hero(rec, segs, rings)

    ok_all = all(last, h.checks)

    # ── layout ───────────────────────────────────────────────────────────────
    gy = -1.6                              # ground line, metres below datum
    xr_side = 6.1                          # ground-line half-span, side/downwind panels
    # windows in metres. The side and downwind panels share one y window, so
    # their ground datums sit on one line. The plan stacks all six rings about
    # the hub, so it takes its own centred y window (the same 22 m extent).
    ywin = (-2.0, 20.0)
    ywin_plan = (-11.0, 11.0)
    yext = ywin[2] - ywin[1]
    @assert isapprox(yext * MPP, PANEL_H_PX; atol=1e-9) "panel height must equal window times scale"
    @assert isapprox((ywin_plan[2] - ywin_plan[1]) * MPP, PANEL_H_PX; atol=1e-9) "plan panel height must equal its window times scale"
    win_side = (-6.2, 9.4)
    win_plan = (-6.2, 6.2)
    win_down = (-6.2, 6.2)
    pxw(w) = round(Int, (w[2] - w[1]) * MPP)
    wpx_side = pxw(win_side)
    wpx_plan = pxw(win_plan)
    wpx_down = pxw(win_down)

    fig_w = wpx_side + GAP_PX + wpx_plan + GAP_PX + wpx_down
    fig_h = HEADER_PX + PANEL_H_PX + LABELS_PX + FOOTER_PX

    fig = Figure(size=(fig_w, fig_h), backgroundcolor=RGBf(1, 1, 1))
    gl = GridLayout(fig[1, 1])

    # header
    hax = Axis(gl[1, 1]; limits=((0, 1), (0, 1)))
    hidedecorations!(hax); hidespines!(hax)
    text!(hax, 0.004, 0.74; text=TITLE, fontsize=14, color=C_INK,
        align=(:left, :center))
    text!(hax, 0.004, 0.42; text=SUB1, fontsize=9.5, color=C_GREY,
        align=(:left, :center))
    text!(hax, 0.004, 0.16; text=SUB2, fontsize=9.5, color=C_GREY,
        align=(:left, :center))

    # panels: plan | side | downwind (the set's reading order)
    pgl = GridLayout(gl[2, 1])
    ax_plan = Axis(pgl[1, 1]; limits=(win_plan, ywin_plan), aspect=DataAspect())
    ax_side = Axis(pgl[1, 2]; limits=(win_side, ywin), aspect=DataAspect())
    ax_down = Axis(pgl[1, 3]; limits=(win_down, ywin), aspect=DataAspect())
    for ax in (ax_side, ax_plan, ax_down)
        hidedecorations!(ax); hidespines!(ax)
        ax.backgroundcolor[] = RGBf(1, 1, 1)
    end
    draw_side!(ax_side, h, gy, xr_side)
    annotate_side!(ax_side, h)
    draw_plan!(ax_plan, h)
    draw_downwind!(ax_down, h, gy, xr_side)

    # label strips
    lax = Axis(gl[3, 1]; limits=((0, 1), (0, 1)))
    hidedecorations!(lax); hidespines!(lax)
    labels = [
        (wpx_plan / 2, "plan — looking along the shaft"),
        (wpx_plan + GAP_PX + wpx_side / 2, "side — the shaft frame"),
        (wpx_plan + GAP_PX + wpx_side + GAP_PX + wpx_down / 2, "downwind — along the wind"),
    ]
    for (x, s) in labels
        text!(lax, x / fig_w, 0.55; text=s, fontsize=11.5, color=C_INK,
            align=(:center, :center))
    end

    # footer
    fax = Axis(gl[4, 1]; limits=((0, 1), (0, 1)))
    hidedecorations!(fax); hidespines!(fax)

    colsize!(gl, 1, Fixed(fig_w))
    rowsize!(gl, 1, Fixed(HEADER_PX))
    rowsize!(gl, 2, Fixed(PANEL_H_PX))
    rowsize!(gl, 3, Fixed(LABELS_PX))
    rowsize!(gl, 4, Fixed(FOOTER_PX))
    colgap!(gl, 0.0)
    rowgap!(gl, 0.0)
    colsize!(pgl, 1, Fixed(wpx_plan))
    colsize!(pgl, 2, Fixed(wpx_side))
    colsize!(pgl, 3, Fixed(wpx_down))
    colgap!(pgl, 1, GAP_PX)
    colgap!(pgl, 2, GAP_PX)

    # legend
    entries = [
        (:line, C_INK, "ground ring"),
        (:line, C_TRANS, "ring, transmission"),
        (:line, C_CONE, "ring, cone"),
        (:line, C_HARV, "ring, harvest"),
        (:poly, C_ROTOR, "swept annulus"),
        (:line, C_BLADE, "blade"),
        (:line, C_ROPE, "TRPT lines"),
        (:tri, C_INK, "ground station — schematic"),
    ]
    x = 14.0
    ytop = 0.92
    for (kind, color, label) in entries
        wneed = 21 + 4.6 * length(label) + 18
        if x + wneed > fig_w - 14.0
            x = 14.0
            ytop -= 0.30
        end
        if kind == :line
            lines!(fax, [x / fig_w, (x + 16) / fig_w], [ytop, ytop];
                color=color, linewidth=2.4)
        elseif kind == :poly
            poly!(fax, Rect(x / fig_w, ytop - 0.05, 16 / fig_w, 0.10);
                color=(color, 0.18), strokecolor=color, strokewidth=0.8)
        else
            tri = [(x / fig_w, ytop - 0.055), ((x + 16) / fig_w, ytop - 0.055),
                ((x + 8) / fig_w, ytop + 0.075)]
            poly!(fax, tri; color=RGBf(1, 1, 1), strokecolor=color,
                strokewidth=1.2)
        end
        text!(fax, (x + 21) / fig_w, ytop; text=label, fontsize=9,
            color=C_INK, align=(:left, :center))
        x += wneed
    end

    # scale bar
    bx = 14.0
    bar_px = SCALE_BAR_M * MPP
    lines!(fax, [bx / fig_w, (bx + bar_px) / fig_w], [0.50, 0.50];
        color=C_INK, linewidth=1.6)
    lines!(fax, [bx / fig_w, bx / fig_w], [0.44, 0.56]; color=C_INK, linewidth=1.0)
    lines!(fax, [(bx + bar_px) / fig_w, (bx + bar_px) / fig_w], [0.44, 0.56];
        color=C_INK, linewidth=1.0)
    text!(fax, (bx + bar_px + 10) / fig_w, 0.50; text="$(Int(SCALE_BAR_M)) m",
        fontsize=9.5, color=C_INK, align=(:left, :center))

    stamp1 = "source: data commit $DATA_COMMIT · genome extract $GENOME_EXTRACT_ID (row $(h.label)) · capture $CAPTURE_ID (ring stations NR-021, per-segment twist NR-022)"
    stamp2 = "rows $REGISTER_ROWS · script commit $script_commit · engine CairoMakie · PDF date normalised to 1970-01-01"
    stamp3 = "views: side is the shaft frame (distance along the shaft vertical) · plan looks along the shaft · downwind looks along the wind, foreshortened by the flown elevation"
    text!(fax, 14 / fig_w, 0.30; text=stamp1, fontsize=8, color=C_FAINT,
        align=(:left, :center))
    text!(fax, 14 / fig_w, 0.19; text=stamp2, fontsize=8, color=C_FAINT,
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
    run(pipeline(`$mutool clean -d $tmp_pdf $clean_pdf`; stdout=devnull))
    nrep = normalise_pdf_date!(clean_pdf)
    run(pipeline(`$mutool clean -z $clean_pdf $norm_pdf`; stdout=devnull))
    mv(norm_pdf, pdf_path; force=true)
    rm(tmp_pdf; force=true); rm(clean_pdf; force=true)

    # ── checks ───────────────────────────────────────────────────────────────
    loglines = String[]
    push!(loglines, "machine-winner-hero — GENERATE run")
    push!(loglines, "script commit: $script_commit")
    push!(loglines, "toolchain: julia $(VERSION) · CairoMakie $(Base.pkgversion(CairoMakie)) · mutool $mutool_ver")
    push!(loglines, "genome extract: $(relpath(genome_extract, ROOT))  sha256 $(bytes2hex(sha256(read(genome_extract))))")
    push!(loglines, "capture: $(relpath(capture, ROOT))  sha256 $(bytes2hex(sha256(read(capture))))")
    ck = join(["$k $v" for (k, v) in h.checks], " · ")
    push!(loglines, "state checks: $ck")
    @printf("state checks: %s\n", ck)
    push!(loglines, @sprintf("stations R1..R6: %.15f, %.15f, %.15f, %.15f, %.15f, %.15f",
        h.stations...))
    push!(loglines, "twists S1..S5 deg: " * join([@sprintf("%.14f", t) for t in h.twists_deg], ", ")
        * @sprintf(" · sum %.12f", sum(h.twists_deg)))
    push!(loglines, "alphas R1..R6 deg: " * join([@sprintf("%.6f", rad2deg(a)) for a in h.alphas], ", "))
    push!(loglines, @sprintf("radii R1..R6: %.16f, %.16f, %.16f, %.16f, %.16f, %.16f",
        h.radii...))
    @printf("radii R1..R5 %.16f · R6 %.16f\n", h.radii[1], h.radii[6])
    push!(loglines, @sprintf("rotor: r_in %.16f · r_out %.16f · span %.16f · bank %.10f deg · blades %d",
        h.r_in, h.r_out, h.r_out - h.r_in, h.bank_deg, h.n_blades))
    push!(loglines, @sprintf("axial offsets: din %.6f m · dout %.6f m · elevation %.2f deg", h.din, h.dout, ELEV_DEG))
    hubz = h.stations[6] * sin(deg2rad(ELEV_DEG))
    push!(loglines, @sprintf("drawn hub altitude: %.4f m (register settled-basis note reads mean z 8.914 m, elevation 28.64 deg)", hubz))
    push!(loglines, "sections R1..R6: " * join(string.(h.sections), ", "))
    push!(loglines, "counts: ring polygons $(h.counts.rings) · TRPT polylines $(h.counts.ropes) ($(h.counts.lines_per_gap) lines x $(h.counts.gaps) gaps) · blades $(h.counts.blades) · annulus views 3 · glyph $(h.counts.glyph)")
    push!(loglines, @sprintf("window: x side [%.1f, %.1f] · plan/downwind [%.1f, %.1f] · y side/downwind [%.1f, %.1f] · y plan [%.1f, %.1f] m · m_per_px %.6f · panels %d/%d/%d x %d px · figure %d x %d px · scale bar %.1f m",
        win_side..., win_plan..., ywin..., ywin_plan..., MPP, wpx_side, wpx_plan, wpx_down, PANEL_H_PX, fig_w, fig_h, SCALE_BAR_M))
    vpf(a) = (v = a.scene.viewport[];
        @sprintf("[%d,%d + %dx%d]", v.origin[1], v.origin[2], v.widths[1], v.widths[2]))
    push!(loglines, "layout viewports: header $(vpf(hax)) · side $(vpf(ax_side)) · plan $(vpf(ax_plan)) · down $(vpf(ax_down)) · labels $(vpf(lax)) · footer $(vpf(fax))")
    for (nm, ax) in (("side", ax_side), ("plan", ax_plan), ("down", ax_down))
        v = ax.scene.viewport[]
        xpxpm = v.widths[1] / (nm == "side" ? (win_side[2] - win_side[1]) :
            (win_plan[2] - win_plan[1]))
        ypxpm = v.widths[2] / yext
        push!(loglines, @sprintf("panel %s: x %.9f px/m · y %.9f px/m · delta %.4f ppm",
            nm, xpxpm, ypxpm, (xpxpm / ypxpm - 1.0) * 1e6))
    end
    push!(loglines, "pdf normalisation: clean -d ok · CreationDate replacements $nrep · clean -z ok")
    push!(loglines, "outputs sha256:")
    for f in ("$SLUG.png", "$SLUG.svg", "$SLUG.pdf")
        push!(loglines, "  $f  $(bytes2hex(sha256(read(joinpath(outdir, f)))))")
    end
    push!(loglines, ok_all ? "checks: ALL OK" : "checks: FAIL")
    write(joinpath(outdir, "checks.log"), join(loglines, "\n") * "\n")

    # ── manifest ─────────────────────────────────────────────────────────────
    manifest = (
        set=SLUG, mode="hero", slug=SLUG,
        script_commit=script_commit,
        script=(path="docs/reporting/figures/$SLUG/$SLUG.jl",
            sha256=bytes2hex(sha256(read(joinpath(@__DIR__, "$SLUG.jl"))))),
        toolchain=(julia=string(VERSION),
            cairomakie=string(Base.pkgversion(CairoMakie)), mutool=mutool_ver,
            pdf_date_normalised_to="1970-01-01T00:00:00+00:00"),
        data_commit=DATA_COMMIT,
        capture=(run_id=CAPTURE_ID,
            path="docs/reporting/figures/pair-extract/extract-winner-operating-point.csv",
            sha256=bytes2hex(sha256(read(capture)))),
        extracts=[
            (purpose="genome", path="docs/reporting/figures/machine-evolution-strip/extract-best-so-far.csv",
                sha256=bytes2hex(sha256(read(genome_extract)))),
            (purpose="capture", path="docs/reporting/figures/pair-extract/extract-winner-operating-point.csv",
                sha256=bytes2hex(sha256(read(capture)))),
        ],
        state=(pose="recorded final operating step (capture)",
            row=h.label, gen=h.gen,
            stations_m=h.stations,
            twists_deg=h.twists_deg,
            winding="declared spin-sense convention: azimuths accumulate the recorded |dalpha| from R1 upward (capture stores magnitudes only)",
            elevation_deg=ELEV_DEG,
            hub_altitude_drawn_m=hubz,
            note="the plain built state reads an untwisted shaft; the settled form comes from the capture (SPEC delta D9)"),
        registers=["NR-011", "NR-017", "NR-021", "NR-022", "NR-043"],
        knobs=(power_W=PW, v_rated=V_RATED, tether_length=LENGTH,
            k_mppt=K_MPPT_5KW_HONEST, blocking_factor=BF, cylinder_cone=true,
            rotor_count_mode=true, power_split=0.6, cone_slope_deg=22.0,
            rotor_spacing_frac=0.8, min_wall_m=2e-3, t_over_D=0.055),
        scale=(m_per_px=MPP,
            window=(shared_y=[ywin[1], ywin[2]],
                side_x=collect(win_side), plan_x=collect(win_plan),
                downwind_x=collect(win_down)),
            panels_px=(side=[wpx_side, PANEL_H_PX], plan=[wpx_plan, PANEL_H_PX],
                downwind=[wpx_down, PANEL_H_PX]),
            scale_bar_m=SCALE_BAR_M, tolerance_px=0.05),
        rotor=(r_in_m=h.r_in, r_out_m=h.r_out, bank_deg=h.bank_deg,
            blades=h.n_blades, din_m=h.din, dout_m=h.dout),
        counts=h.counts,
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

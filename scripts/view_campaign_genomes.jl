#!/usr/bin/env julia
# scripts/view_campaign_genomes.jl
#
# Genome Form Browser — decode any 14-dim V13 5 kW genome from a campaign
# telemetry CSV and render its 3D form (rings, tethers, knuckles, expansion
# rotors) beside the genome's scores, with prev/next navigation across the
# campaign set.  Purpose: review the visual form a builder produced and
# compare it to that genome's scores.
#
# Reference: docs/plans/2026-08-20-genome-form-browser.md
#
# The 14-dim genome is x1..x14 (TRPT_V10_DIM).  k_mppt left the vector on
# 2026-08-09, so this script reads only those 14 columns and nothing beyond.
#
# Decode is pure read + render: it mirrors the runner's decode exactly
# (scripts/run_v13_5kw.jl `params_at_length` + `eval_v13` pre-normalisation)
# but performs no physics, builds no ODE system, and touches no CSV.
#
# Usage:
#   julia --project=. scripts/view_campaign_genomes.jl [csv_path] [options]
#
#   csv_path             telemetry CSV (default: first existing v13_5kw_lenX)
#   --hash=S             first row whose genome fingerprint contains S
#   --row=N              1-based row index to load (default 1)
#   --png=PATH           headless render of the current row to PATH, then exit
#   --selfcheck          assert geometry (AC3) + score-panel equality (AC6), exit
#   --nav-check=N        step through N rows logging each decoded genome (AC5), exit

using Pkg
Pkg.activate(dirname(@__DIR__))

using KiteTurbineDynamics
using CSV, DataFrames, Printf, LinearAlgebra

const ROOT = dirname(@__DIR__)
const RESULTS = joinpath(ROOT, "scripts", "results")

# ══════════════════════════════════════════════════════════════════════════════
# Length-specific params — EXACT copy of scripts/run_v13_5kw.jl:45
# (params_10kw base, tether length = L, then mass_scale 10 kW → 5 kW).
# mass_scale shrinks tether_length by √(5/10), which is why design.tether_length
# reads 12.728 m for a 18 m campaign.  This must be bit-identical to the runner
# or the decoded ring count will be wrong.
# ══════════════════════════════════════════════════════════════════════════════
function params_at_length(L::Float64)
    p2 = params_10kw()
    geo = GeometrySpec(p2.elevation_angle, p2.lifter_elevation, p2.rotor_radius,
        L, p2.trpt_hub_radius, p2.trpt_rL_ratio, p2.n_lines, p2.n_rings,
        p2.n_blades)
    mat = MaterialSpec(p2.tether_diameter, p2.e_modulus, p2.m_ring, p2.m_blade)
    aero = AeroSpec(p2.rho, p2.v_wind_ref, p2.h_ref, p2.cp)
    ctrl = ControlSpec(p2.i_pto, p2.k_mppt, p2.p_rated_w, p2.β_min, p2.β_max,
        p2.β_rate_max, p2.kp_elev)
    back = BackLineSpec(p2.EA_back_line, p2.c_back_line, p2.back_anchor_fwd_x,
        p2.backline_payout)
    return mass_scale(SystemParams(geo, mat, aero, ctrl, back), 10.0, 5.0)
end

# ══════════════════════════════════════════════════════════════════════════════
# Backend selection — GLMakie for the desktop, CairoMakie fallback so the same
# script renders headless (GKSwstype=nul / no DISPLAY) for agent verification.
# ══════════════════════════════════════════════════════════════════════════════
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

# ══════════════════════════════════════════════════════════════════════════════
# Genome fingerprint + decode
# ══════════════════════════════════════════════════════════════════════════════

"Stable string fingerprint of a 14-dim genome (matches telemetry's 6-dp store)."
function genome_fingerprint(x::Vector{Float64})
    return join((@sprintf("%.6g", v) for v in x), ",")
end

"""
    decode_genome(x, L) -> (dec, radii)

Decode a 14-dim genome exactly as the campaign runner does: round x[8] to Int
in 3:16 and clamp x[10] to 0:N_VALID_MASKS (eval_v13), then
`design_from_vector_v10(x, PROFILE_ELLIPTICAL, params_at_length(L); power_W=5000)`.
Ring radii come from `ring_spacing_v4` exactly as `build_system_from_v10` calls
it — dec.zs is the z-position companion (same length, ground-first order).
"""
function decode_genome(x::Vector{Float64}, L::Float64)
    xr = copy(x)
    xr[8] = Float64(round(Int, clamp(xr[8], 3, 16)))
    xr[10] = clamp(xr[10], 0.0, Float64(N_VALID_MASKS))

    p_base = params_at_length(L)
    dec = design_from_vector_v10(xr, PROFILE_ELLIPTICAL, p_base; power_W=5000.0)

    radii = ring_spacing_v4(
        dec.design.r_hub, dec.design.r_bottom,
        dec.design.tether_length, dec.design.target_Lr;
        density_profile=dec.design.density_profile,
    )[2]

    return (dec=dec, radii=radii)
end

"Extract the campaign tether length from the header comment, else the tether col."
function campaign_length(csv_path::String, df::DataFrame)
    open(csv_path, "r") do io
        for _ in 1:5
            line = readline(io; keep=true)
            startswith(line, "#") || break
            m = match(r"length=([0-9.]+)", line)
            m === nothing || return parse(Float64, m.captures[1])
        end
    end
    return Float64(df[1, :tether])
end

# ══════════════════════════════════════════════════════════════════════════════
# Geometry helpers
# ══════════════════════════════════════════════════════════════════════════════

"Vertex positions (n_lines-gon) for every ring, ground-first order."
function ring_vertices(dec, radii::Vector{Float64})
    n_v = dec.design.n_lines
    zs = dec.zs
    verts = Vector{Vector{Vector{Float64}}}(undef, length(radii))
    for (i, r) in enumerate(radii)
        verts[i] = [
            [r * cos(2π * (k - 1) / n_v), r * sin(2π * (k - 1) / n_v), zs[i]]
            for k in 1:n_v
        ]
    end
    return verts
end

"Beam outer diameter per ring (drives the viridis Do-colour, as in the clean renderer)."
function ring_do(dec, radii::Vector{Float64})
    return [beam_spec_at_ring(dec.design, r).Do for r in radii]
end

"Viridis colour for a Do value, normalised over the ring stack."
function do_colour(Do, Do_min, Do_max)
    Do_max ≈ Do_min && return M.cgrad(:viridis)[1.0]
    t = clamp((Do - Do_min) / (Do_max - Do_min), 0.0, 1.0)
    return M.cgrad(:viridis)[t]
end

# ══════════════════════════════════════════════════════════════════════════════
# Rendering
# ══════════════════════════════════════════════════════════════════════════════

"Draw one expansion rotor as a banked blade disc at its ring's z height."
function draw_rotor!(ax3, rotor, z::Float64, n_blades::Int)
    β = deg2rad(rotor.bank_angle_deg)
    tip = rotor.blade_tip_radius
    hub = rotor.blade_hub_radius
    θ = collect(range(0.0, 2π, length=96))

    # Disc plane tilted by β about the x-axis; centre at (0, 0, z).
    for (r, lw) in ((tip, 2.5), (hub, 1.2))
        xs = [r * cos(t) for t in θ]
        ys = [r * sin(t) * cos(β) for t in θ]
        zs = [z + r * sin(t) * sin(β) for t in θ]
        M.lines!(ax3, xs, ys, zs, color=:deepskyblue, linewidth=lw)
    end

    # Radial blades (n_blades = n_lines, matching the balanced polygon).
    for k in 1:n_blades
        a = 2π * (k - 1) / n_blades
        M.lines!(
            ax3,
            [hub * cos(a), tip * cos(a)],
            [hub * sin(a) * cos(β), tip * sin(a) * cos(β)],
            [z + hub * sin(a) * sin(β), z + tip * sin(a) * sin(β)],
            color=(:deepskyblue, 0.6), linewidth=1.0,
        )
    end
end

"Clear and redraw the full 3D form for the decoded genome in `st`."
function draw_form!(ax3, st)
    M.empty!(ax3)
    dec = st.dec
    radii = st.radii
    verts = ring_vertices(dec, radii)
    n_v = dec.design.n_lines
    Do_vals = ring_do(dec, radii)
    Do_min = minimum(Do_vals)
    Do_max = maximum(Do_vals)

    # Ring polygons — linewidth scales with Do, colour from viridis.
    for i in eachindex(verts)
        col = do_colour(Do_vals[i], Do_min, Do_max)
        lw = 3.0 + 6.0 * (Do_vals[i] - Do_min) / max(Do_max - Do_min, 1e-9)
        ring = verts[i]
        for k in 1:n_v
            a = ring[k]
            b = ring[mod1(k + 1, n_v)]
            M.lines!(ax3, [a[1], b[1]], [a[2], b[2]], [a[3], b[3]],
                color=col, linewidth=lw)
        end
    end

    # Tethers — same vertex index across rings.
    for k in 1:n_v
        xs = [verts[i][k][1] for i in eachindex(verts)]
        ys = [verts[i][k][2] for i in eachindex(verts)]
        zs = [verts[i][k][3] for i in eachindex(verts)]
        M.lines!(ax3, xs, ys, zs, color=(:grey30, 0.7), linewidth=1.2)
    end

    # Knuckles — red spheres at every vertex.
    for i in eachindex(verts), p in verts[i]
        M.scatter!(ax3, [p[1]], [p[2]], [p[3]], markersize=10, color=:red,
            strokewidth=0)
    end

    # Expansion rotors — banked blade discs at their ring heights.
    for rotor in dec.rotors
        z = dec.zs[clamp(rotor.ring_idx, 1, length(dec.zs))]
        draw_rotor!(ax3, rotor, z, n_v)
    end
end

# ══════════════════════════════════════════════════════════════════════════════
# Score panel
# ══════════════════════════════════════════════════════════════════════════════

"Format a numeric cell for the panel (NaN preserved as the CSV's literal 'NaN')."
function cell(v)
    v isa Real && isnan(v) && return "NaN"
    v isa Real && return @sprintf("%.6g", v)
    return string(v)
end

"Panel value for a named field, reading T_lift only when the CSV carries it."
function panel_value(row, df, field::Symbol)
    field === :T_lift && return (:T_lift in names(df)) ? row[:T_lift] : nothing
    return row[field]
end

"Multi-line score panel text for the loaded row."
function score_panel_text(row, df, dec)
    has_tlift = :T_lift in names(df)
    lines = String[
        "Genome   $(row.island)/$(row.gen)/$(row.idx)",
        "status   $(row.status)",
        "fitness  $(cell(row.fitness))",
        "P_mean   $(cell(row.P_mean)) kW",
        "FoS      $(cell(row.FoS))",
        has_tlift ? "T_lift   $(cell(row.T_lift)) N" : "T_lift   n/a (absent from CSV)",
        "clearance $(cell(row.clearance)) m",
        "twist_crossed  $(row.twist_crossed)",
        "",
        "n_lines  $(row.n_lines)",
        "n_rings  $(dec.n_rings)",
        "n_active $(dec.n_active)",
        "r_hub    $(round(dec.design.r_hub, digits=3)) m",
        "r_bottom $(round(dec.design.r_bottom, digits=3)) m",
    ]
    return join(lines, "\n")
end

# ══════════════════════════════════════════════════════════════════════════════
# Browser state + navigation
# ══════════════════════════════════════════════════════════════════════════════

mutable struct BrowserState
    df::DataFrame
    L::Float64
    i::Int
    dec::Any
    radii::Vector{Float64}
    fingerprint::String
end

"Decode row `i`, store it, and log the loaded row (AC5 evidence)."
function load_row!(st::BrowserState, i::Int)
    st.i = clamp(i, 1, nrow(st.df))
    row = st.df[st.i, :]
    x = [row[Symbol("x$j")] for j in 1:14]
    st.dec, st.radii = decode_genome(x, st.L)
    st.fingerprint = genome_fingerprint(x)
    dec = st.dec
    println(@sprintf(
        "loaded row %d/%d  island=%d gen=%d idx=%d  fp=%s  n_lines=%d n_rings=%d n_active=%d  r_hub=%.3f r_bottom=%.3f",
        st.i, nrow(st.df), row.island, row.gen, row.idx, first(st.fingerprint, 24),
        dec.design.n_lines, dec.n_rings, dec.n_active, dec.design.r_hub,
        dec.design.r_bottom,
    ))
    return st
end

# ══════════════════════════════════════════════════════════════════════════════
# Assertions (AC3 + AC6) — pure numeric, headless
# ══════════════════════════════════════════════════════════════════════════════

function selfcheck(st::BrowserState, row)
    dec = st.dec
    radii = st.radii
    n_rings_expected = ring_spacing_v4(
        dec.design.r_hub, dec.design.r_bottom,
        dec.design.tether_length, dec.design.target_Lr;
        density_profile=dec.design.density_profile,
    )

    ok = true
    function check(label, pass, detail)
        println((pass ? "PASS  " : "FAIL  ") * label * "  —  " * detail)
        ok &= pass
    end

    verts = ring_vertices(dec, radii)
    check("ring count == dec.n_rings", length(radii) == dec.n_rings,
        "$(length(radii)) == $(dec.n_rings)")
    check("radii match ring_spacing_v4 output", radii ≈ n_rings_expected[2],
        "max|Δ| = $(maximum(abs.(radii .- n_rings_expected[2])))")
    check("vertices per ring == design.n_lines",
        all(length(v) == dec.design.n_lines for v in verts),
        "$(dec.design.n_lines) vertices/ring")
    check("rotor count == dec.n_active", length(dec.rotors) == dec.n_active,
        "$(length(dec.rotors)) == $(dec.n_active)")

    # AC6 — score panel values equal the CSV fields for the loaded row.
    for (label, field) in [
        ("P_mean", :P_mean), ("FoS", :FoS), ("fitness", :fitness),
        ("status", :status), ("clearance", :clearance),
        ("twist_crossed", :twist_crossed), ("T_lift", :T_lift),
    ]
        pv = panel_value(row, st.df, field)
        if pv === nothing
            println("NOTE  T_lift absent from CSV (panel shows n/a) — reference CSVs" *
                    " predate the masslift runner")
        else
            check("panel $label == CSV field",
                isequal(pv, row[field]),
                "$(repr(pv)) == $(repr(row[field]))")
        end
    end

    println(ok ? "SELFCHECK: ALL PASS" : "SELFCHECK: FAILURES PRESENT")
    return ok
end

# ══════════════════════════════════════════════════════════════════════════════
# CLI
# ══════════════════════════════════════════════════════════════════════════════

function default_csv()
    for L in ("18.0", "21.2", "25.0")
        p = joinpath(RESULTS, "v13_5kw_len$L", "telemetry.csv")
        isfile(p) && return p
    end
    return joinpath(RESULTS, "v13_5kw_len18.0", "telemetry.csv")
end

function parse_args(args)
    csv_path = default_csv()
    hash_filt = ""
    row_idx = 1
    png_path = nothing
    do_selfcheck = false
    nav_check = 0

    i = 1
    while i <= length(args)
        a = args[i]
        if startswith(a, "--hash=")
            hash_filt = a[8:end]
        elseif startswith(a, "--row=")
            row_idx = parse(Int, a[7:end])
        elseif startswith(a, "--png=")
            png_path = a[7:end]
        elseif a == "--selfcheck"
            do_selfcheck = true
        elseif startswith(a, "--nav-check=")
            nav_check = parse(Int, a[13:end])
        elseif startswith(a, "-")
            error("unknown flag: $a")
        else
            csv_path = a
        end
        i += 1
    end
    return (csv_path, hash_filt, row_idx, png_path, do_selfcheck, nav_check)
end

function main()
    csv_path, hash_filt, row_idx, png_path, do_selfcheck, nav_check = parse_args(ARGS)
    isfile(csv_path) || error("telemetry CSV not found: $csv_path")

    df = CSV.read(csv_path, DataFrame; comment="#")
    L = campaign_length(csv_path, df)

    # Resolve starting row: --hash, then --row.
    start_i = row_idx
    if !isempty(hash_filt)
        match_i = findfirst(
            i -> occursin(hash_filt, genome_fingerprint([df[i, Symbol("x$j")] for j in 1:14])),
            1:nrow(df),
        )
        match_i === nothing && error("no genome matching --hash=$hash_filt")
        start_i = match_i
    end

    st = BrowserState(df, L, start_i, nothing, Float64[], "")
    load_row!(st, start_i)
    row = st.df[st.i, :]

    # AC5 — navigation: step prev/next, logging each loaded row.
    if nav_check > 0
        println("NAV-CHECK over $(nav_check) rows:")
        for k in 1:nav_check
            load_row!(st, mod1(start_i + k, nrow(df)))
        end
        return
    end

    if do_selfcheck
        exit(selfcheck(st, row) ? 0 : 1)
    end

    # ── Figure ────────────────────────────────────────────────────────────────
    fig = M.Figure(size=(1400, 900), backgroundcolor=:white)
    ax3 = M.Axis3(fig[1, 1],
        backgroundcolor=:white,
        xlabel="x (m)", ylabel="y (m)", zlabel="z (m)",
        xgridcolor=(:black, 0.1), ygridcolor=(:black, 0.1), zgridcolor=(:black, 0.1),
        title=@sprintf("%s — genome %d/%d/%d (%s)", basename(csv_path),
            row.island, row.gen, row.idx, first(st.fingerprint, 16)),
        aspect=(1, 1, 1.2))
    panel = M.Label(fig[1, 2],
        score_panel_text(row, df, st.dec),
        fontsize=16, halign=:left, valign=:top, tellwidth=false, tellheight=false)
    M.colsize!(fig.layout, 1, M.Relative(0.7))
    M.colsize!(fig.layout, 2, M.Relative(0.3))

    draw_form!(ax3, st)
    ax3.azimuth[] = -π / 3.2
    ax3.elevation[] = π / 9
    ax3.perspectiveness[] = 0.4

    if png_path !== nothing
        M.save(png_path, fig, px_per_unit=2)
        println("wrote $png_path")
        return
    end

    # ── Interactive navigation (desktop) ──────────────────────────────────────
    function redraw!()
        draw_form!(ax3, st)
        r = st.df[st.i, :]
        panel.text = score_panel_text(r, df, st.dec)
        ax3.title = @sprintf("%s — genome %d/%d/%d (%s)", basename(csv_path),
            r.island, r.gen, r.idx, first(st.fingerprint, 16))
    end

    prev_btn = M.Button(fig[2, 1], label="◀ Prev")
    next_btn = M.Button(fig[2, 2], label="Next ▶")
    M.on(prev_btn.clicks) do _
        load_row!(st, st.i - 1)
        redraw!()
    end
    M.on(next_btn.clicks) do _
        load_row!(st, st.i + 1)
        redraw!()
    end

    M.display(fig)
    println("Genome Form Browser open — use ◀ Prev / Next ▶ or the buttons.")
    println("Loaded $(st.i)/$(nrow(df)): $(st.fingerprint)")
end

main()

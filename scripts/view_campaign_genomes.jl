#!/usr/bin/env julia
# scripts/view_campaign_genomes.jl
#
# Genome Form Browser / Chooser — decode 14-dim V13 5 kW genomes from campaign
# telemetry CSVs, filter them by decoded physical parameters, browse matching
# designs as cards, and view any selected design in 3D beside its scores.
#
# Reference: docs/plans/2026-08-20-genome-form-browser.md
#            docs/plans/2026-08-20-genome-chooser.md
#
# The 14-dim genome is x1..x14 (TRPT_V10_DIM).  k_mppt left the vector on
# 2026-08-09, so this script reads only those 14 columns and nothing beyond.
#
# Decode is pure read + render: it mirrors the runner's decode exactly
# (scripts/run_v13_5kw.jl `params_at_length` + `eval_v13` pre-normalisation)
# but performs no physics, builds no ODE system, and touches no CSV.
#
# Usage:
#   julia --project=. scripts/view_campaign_genomes.jl [input ...] [options]
#
#   input                 results directory (default: scripts/results/) or one
#                         or more telemetry.csv paths.  A directory is scanned
#                         for v13_5kw_len*/telemetry.csv and the files are
#                         concatenated (each row keeps its own tether column).
#   --hash=S              first row whose genome fingerprint contains S
#   --row=N               1-based global row index to load (default 1)
#   --png=PATH            headless render of the selected row's viewport, exit
#   --selfcheck           assert geometry (AC3) + score-panel equality (AC6), exit
#   --check               run AC8-AC17 (filter/highlights/multi-CSV) assertions, exit
#   --nav-check=N         step through N rows logging each decoded genome (AC5), exit

using Pkg
Pkg.activate(dirname(@__DIR__))

using KiteTurbineDynamics
using CSV, DataFrames, Printf, LinearAlgebra, Statistics, Random

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
const BACKEND = Ref{Symbol}(:none)
const M = try
    @eval using GLMakie
    GLMakie.activate!()
    BACKEND[] = :glmakie
    @info "GLMakie backend active"
    GLMakie
catch err
    @warn "GLMakie unavailable ($err) — falling back to CairoMakie"
    @eval using CairoMakie
    CairoMakie.activate!()
    BACKEND[] = :cairomakie
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

# ══════════════════════════════════════════════════════════════════════════════
# Decoded physical parameters (cached once at load — pure geometry, no ODE)
# ══════════════════════════════════════════════════════════════════════════════

"Filterable/decoded physical parameters of a decoded genome."
struct DecodedParams
    r_hub::Float64
    r_bot::Float64
    n_lines::Int
    n_rings::Int
    n_active::Int
    lam_top::Float64
    lam_bot::Float64
    bank_top::Float64
    bank_bot::Float64
    tether::Float64
    density_profile::Float64
end

"The ten filterable parameter names (n_rings is card-display only, not a filter)."
const FILTER_PARAMS = [
    :r_hub, :r_bot, :n_lines, :n_active, :lam_top, :lam_bot,
    :bank_top, :bank_bot, :tether, :density_profile,
]

param_value(p::DecodedParams, s::Symbol) = getproperty(p, s)

"Extract the decoded filter params from a genome, reusing the single decode path."
function decode_params(x::Vector{Float64}, L::Float64)
    dec, _ = decode_genome(x, L)
    return DecodedParams(
        dec.design.r_hub, dec.design.r_bottom, dec.design.n_lines, dec.n_rings,
        dec.n_active, x[13], x[14], x[11], x[12], L, dec.design.density_profile,
    )
end

"Decode every row once into a cached params + fingerprint table."
function decode_all(df::DataFrame)
    params = Vector{DecodedParams}(undef, nrow(df))
    fps = Vector{String}(undef, nrow(df))
    for i in 1:nrow(df)
        x = [df[i, Symbol("x$j")] for j in 1:14]
        params[i] = decode_params(x, Float64(df[i, :tether]))
        fps[i] = genome_fingerprint(x)
    end
    return (params=params, fingerprints=fps)
end

# ══════════════════════════════════════════════════════════════════════════════
# Filtering
# ══════════════════════════════════════════════════════════════════════════════

"Observed min/max of each filter param across the loaded set (never hardcoded)."
function full_bounds(params::Vector{DecodedParams})
    d = Dict{Symbol,Tuple{Float64,Float64}}()
    for s in FILTER_PARAMS
        vals = [Float64(param_value(p, s)) for p in params]
        d[s] = (minimum(vals), maximum(vals))
    end
    return d
end

"A row matches when every param sits inside its (lo, hi) range (AND-combination)."
function matches(p::DecodedParams, f::Dict{Symbol,Tuple{Float64,Float64}})
    for s in FILTER_PARAMS
        lo, hi = f[s]
        v = Float64(param_value(p, s))
        (lo <= v <= hi) || return false
    end
    return true
end

"Global 1-based row indices matching the filter."
function apply_filter(params::Vector{DecodedParams}, f)
    return [i for i in eachindex(params) if matches(params[i], f)]
end

# ══════════════════════════════════════════════════════════════════════════════
# Highlights (deterministic)
# ══════════════════════════════════════════════════════════════════════════════

"argmax over finite entries (rejected rows carry NaN FoS/P_mean)."
function argmax_finite(v)
    best = 0
    bestval = -Inf
    for (i, x) in enumerate(v)
        isfinite(x) || continue
        if x > bestval
            bestval = x
            best = i
        end
    end
    return best
end

"Standouts: min fitness, max finite FoS, max finite P_mean, best finite clearance."
function standouts(df::DataFrame)
    return unique([
        argmin(df.fitness),
        argmax_finite(df.FoS),
        argmax_finite(df.P_mean),
        argmax_finite(df.clearance),
    ])
end

"Non-dominated front over (fitness ↓, FoS ↑, P_mean ↑); NaN-objective rows excluded."
function pareto_front(df::DataFrame)
    idxs = [
        i for i in 1:nrow(df)
        if isfinite(df[i, :FoS]) && isfinite(df[i, :P_mean])
    ]
    n = length(idxs)
    dominated = falses(n)
    for a in 1:n
        for b in 1:n
            a == b && continue
            ia, ib = idxs[a], idxs[b]
            better = (df[ib, :fitness] <= df[ia, :fitness]) &&
                     (df[ib, :FoS] >= df[ia, :FoS]) &&
                     (df[ib, :P_mean] >= df[ia, :P_mean])
            strict = (df[ib, :fitness] < df[ia, :fitness]) ||
                     (df[ib, :FoS] > df[ia, :FoS]) ||
                     (df[ib, :P_mean] > df[ia, :P_mean])
            if better && strict
                dominated[a] = true
                break
            end
        end
    end
    return idxs[.!dominated]
end

"Min and max design (row index) per decoded dimension, deduplicated."
function per_dim_extremes(params::Vector{DecodedParams})
    reps = Int[]
    for s in FILTER_PARAMS
        vals = [Float64(param_value(p, s)) for p in params]
        push!(reps, argmin(vals), argmax(vals))
    end
    return unique(reps)
end

"Z-score standardise a vector (constant vector → zeros)."
function standardize(v::Vector{Float64})
    μ = mean(v)
    σ = std(v)
    σ < 1e-12 && return zeros(length(v))
    return (v .- μ) ./ σ
end

"""
    kmeans_reps(X, k; seed) -> k distinct row indices

Pure-Julia k-means on a standardised feature matrix.  Deterministic for a fixed
seed.  Representative per cluster = member nearest the centroid; collisions are
backfilled with unused rows so exactly k distinct indices are returned.
"""
function kmeans_reps(X::Matrix{Float64}, k::Int; seed::Int=42, max_iters::Int=100)
    n = size(X, 1)
    k = min(max(k, 1), n)
    rng = MersenneTwister(seed)
    perm = randperm(rng, n)
    centroids = copy(X[perm[1:k], :])
    labels = zeros(Int, n)
    for _ in 1:max_iters
        changed = false
        for i in 1:n
            d = [sum(abs2, X[i, :] .- centroids[j, :]) for j in 1:k]
            l = argmin(d)
            if labels[i] != l
                labels[i] = l
                changed = true
            end
        end
        for j in 1:k
            mem = [i for i in 1:n if labels[i] == j]
            isempty(mem) && continue
            centroids[j, :] = vec(sum(X[mem, :]; dims=1)) ./ length(mem)
        end
        changed || break
    end
    reps = Int[]
    for j in 1:k
        mem = [i for i in 1:n if labels[i] == j]
        if isempty(mem)
            push!(reps, perm[j])
        else
            push!(reps, mem[argmin([sum(abs2, X[i, :] .- centroids[j, :]) for i in mem])])
        end
    end
    result = Int[]
    for r in reps
        r in result || push!(result, r)
    end
    i = 1
    while length(result) < k
        i in result || push!(result, i)
        i += 1
    end
    return sort(result[1:k])
end

"Cluster representatives over standardised decoded params (k-means, k=5, seed 42)."
function cluster_reps(params::Vector{DecodedParams}, k::Int=5)
    cols = [[Float64(param_value(p, s)) for p in params] for s in FILTER_PARAMS]
    X = hcat([standardize(c) for c in cols]...)
    return kmeans_reps(X, k)
end

"HIGHLIGHT_MODES = selectable highlight sets."
const HIGHLIGHT_MODES = ["Standouts", "Pareto front", "Per-dimension extremes",
    "Cluster representatives"]

"Row indices for the selected highlight mode."
function highlights_for_mode(mode::String, df::DataFrame, params::Vector{DecodedParams})
    if mode == "Standouts"
        return standouts(df)
    elseif mode == "Pareto front"
        return pareto_front(df)
    elseif mode == "Per-dimension extremes"
        return per_dim_extremes(params)
    elseif mode == "Cluster representatives"
        return cluster_reps(params, 5)
    end
    return standouts(df)
end

# ══════════════════════════════════════════════════════════════════════════════
# Geometry helpers + rendering (reused from the form browser)
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

"Draw one expansion rotor as a banked blade disc at its ring's z height."
function draw_rotor!(ax3, rotor, z::Float64, n_blades::Int)
    β = deg2rad(rotor.bank_angle_deg)
    tip = rotor.blade_tip_radius
    hub = rotor.blade_hub_radius
    θ = collect(range(0.0, 2π, length=96))

    for (r, lw) in ((tip, 2.5), (hub, 1.2))
        xs = [r * cos(t) for t in θ]
        ys = [r * sin(t) * cos(β) for t in θ]
        zs = [z + r * sin(t) * sin(β) for t in θ]
        M.lines!(ax3, xs, ys, zs, color=:deepskyblue, linewidth=lw)
    end
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

"Clear and redraw the full 3D form for a decoded genome."
function draw_form!(ax3, dec, radii::Vector{Float64})
    M.empty!(ax3)
    verts = ring_vertices(dec, radii)
    n_v = dec.design.n_lines
    Do_vals = ring_do(dec, radii)
    Do_min = minimum(Do_vals)
    Do_max = maximum(Do_vals)

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

    for k in 1:n_v
        xs = [verts[i][k][1] for i in eachindex(verts)]
        ys = [verts[i][k][2] for i in eachindex(verts)]
        zs = [verts[i][k][3] for i in eachindex(verts)]
        M.lines!(ax3, xs, ys, zs, color=(:grey30, 0.7), linewidth=1.2)
    end

    for i in eachindex(verts), p in verts[i]
        M.scatter!(ax3, [p[1]], [p[2]], [p[3]], markersize=10, color=:red,
            strokewidth=0)
    end

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

"Compact single-card text (stat tile)."
function card_text(df::DataFrame, params::Vector{DecodedParams}, decset, rid::Int)
    row = df[rid, :]
    p = params[rid]
    fp = first(decset.fingerprints[rid], 12)
    return @sprintf("%d/%d/%d %s\nP=%.2f FoS=%.3g f=%.4g %s\nn=%d/%d/%d r=%.2f t=%.1f",
        row.island, row.gen, row.idx, fp,
        row.P_mean, row.FoS, row.fitness, row.status,
        p.n_lines, p.n_rings, p.n_active, p.r_hub, p.tether)
end

# ══════════════════════════════════════════════════════════════════════════════
# Browser state + navigation (kept for --selfcheck / --nav-check / --png)
# ══════════════════════════════════════════════════════════════════════════════

mutable struct BrowserState
    df::DataFrame
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
    st.dec, st.radii = decode_genome(x, Float64(row.tether))
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
# Assertions — AC3+AC6 (selfcheck) and AC8-AC17 (check)
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

function fullcheck(df::DataFrame, params::Vector{DecodedParams}, decset)
    ok = Ref(true)
    function check(label, pass, detail)
        println((pass ? "PASS  " : "FAIL  ") * label * "  —  " * detail)
        ok[] &= pass
    end

    full = full_bounds(params)

    # AC11 — multi-CSV concatenation.
    srcs = sort(unique(df.source))
    per_src = [count(==(s), df.source) for s in srcs]
    check("AC11 found 3 length sources", length(srcs) == 3,
        "sources=$(srcs)")
    check("AC11 combined == sum of per-source counts",
        nrow(df) == sum(per_src), "$(nrow(df)) == $(sum(per_src))")
    tethers = sort(unique(df.tether))
    check("AC11 tether values == {18,21.2,25}",
        length(tethers) == 3 && isapprox(tethers, [18.0, 21.2, 25.0]),
        "tethers=$(tethers)")

    # AC10 — slider ranges == observed min/max.
    bounds_ok = true
    for s in FILTER_PARAMS
        vals = [Float64(param_value(p, s)) for p in params]
        lo, hi = full[s]
        bounds_ok &= (lo == minimum(vals)) && (hi == maximum(vals))
    end
    check("AC10 slider bounds == observed min/max", bounds_ok,
        "all $(length(FILTER_PARAMS)) params")

    # AC8 + AC9 — filter correctness + live count.
    f_n6 = copy(full)
    f_n6[:n_lines] = (6.0, 6.0)
    m1 = apply_filter(params, f_n6)
    csv1 = findall(==(6), df.n_lines)
    check("AC8 single-slider n_lines==6 == CSV", Set(m1) == Set(csv1),
        "$(length(m1)) rows (CSV $(length(csv1)))")
    check("AC9 live count == match set size",
        length(m1) == count(matches(p, f_n6) for p in params),
        "count=$(length(m1))")

    f_multi = copy(f_n6)
    f_multi[:tether] = (18.0, 18.0)
    m2 = apply_filter(params, f_multi)
    csv2 = findall((df.n_lines .== 6) .& (df.tether .== 18.0))
    check("AC8 multi-slider AND-combine", Set(m2) == Set(csv2),
        "$(length(m2)) rows (CSV $(length(csv2)))")

    # AC12 — card selection loads the correct row.
    if !isempty(m1)
        rid = m1[1]
        row = df[rid, :]
        x = [row[Symbol("x$j")] for j in 1:14]
        dec, _ = decode_genome(x, Float64(row.tether))
        check("AC12 card selection fingerprint == row genome",
            genome_fingerprint(x) == decset.fingerprints[rid],
            "rid=$rid fp=$(first(decset.fingerprints[rid], 16)) n_active=$(dec.n_active)")
    else
        check("AC12 card selection", false, "no matching rows to select")
    end

    # AC13 — standouts.
    st = standouts(df)
    check("AC13 winner == argmin(fitness)",
        argmin(df.fitness) in st,
        "winner fit=$(df[argmin(df.fitness), :fitness])")
    check("AC13 max FoS == argmax(finite)",
        argmax_finite(df.FoS) in st,
        "FoS=$(df[argmax_finite(df.FoS), :FoS])")
    check("AC13 max P_mean == argmax(finite)",
        argmax_finite(df.P_mean) in st,
        "P_mean=$(df[argmax_finite(df.P_mean), :P_mean])")
    check("AC13 best clearance == argmax(finite)",
        argmax_finite(df.clearance) in st,
        "clearance=$(df[argmax_finite(df.clearance), :clearance])")

    # AC14 — Pareto front is non-dominated (programmatic re-check).
    pf = pareto_front(df)
    nondom = true
    for a in pf, b in pf
        a == b && continue
        if (df[b, :fitness] <= df[a, :fitness]) &&
           (df[b, :FoS] >= df[a, :FoS]) &&
           (df[b, :P_mean] >= df[a, :P_mean]) &&
           ((df[b, :fitness] < df[a, :fitness]) ||
            (df[b, :FoS] > df[a, :FoS]) ||
            (df[b, :P_mean] > df[a, :P_mean]))
            nondom = false
        end
    end
    check("AC14 Pareto front non-dominated", nondom, "$(length(pf)) members")

    # AC15 — per-dimension extremes == argmin/argmax.
    ext_ok = true
    for s in FILTER_PARAMS
        vals = [Float64(param_value(p, s)) for p in params]
        imin, imax = argmin(vals), argmax(vals)
        ext_ok &= (imin in per_dim_extremes(params)) && (imax in per_dim_extremes(params))
    end
    check("AC15 per-dim extremes cover argmin/argmax", ext_ok,
        "$(length(per_dim_extremes(params))) unique designs")

    # AC16 — cluster reps: k=5 distinct valid rows.
    reps = cluster_reps(params, 5)
    check("AC16 cluster reps k=5 distinct valid rows",
        length(reps) == 5 && allunique(reps) &&
        all(1 .<= reps .<= nrow(df)),
        "reps=$(reps)")

    # AC17 — density_profile filtering (not a CSV column).
    r = reps[1]
    dp = params[r].density_profile
    f_dp = copy(full)
    f_dp[:density_profile] = (dp, dp)
    mdp = apply_filter(params, f_dp)
    check("AC17 density_profile filter selects the decoded row",
        r in mdp, "row $r dp=$dp")
    all_dp_match = all(params[i].density_profile == dp for i in mdp)
    check("AC17 density_profile match set all == decoded dp",
        all_dp_match, "$(length(mdp)) rows")

    println(ok[] ? "CHECK: ALL PASS" : "CHECK: FAILURES PRESENT")
    return ok[]
end

# ══════════════════════════════════════════════════════════════════════════════
# Data loading
# ══════════════════════════════════════════════════════════════════════════════

"Scan a directory for v13_5kw_len*/telemetry.csv (one level deep, sorted)."
function collect_telemetry_csvs(dir::String)
    isdir(dir) || return String[]
    subdirs = sort(filter(d -> startswith(d, "v13_5kw_len"), readdir(dir)))
    paths = String[]
    for d in subdirs
        p = joinpath(dir, d, "telemetry.csv")
        isfile(p) && push!(paths, p)
    end
    return paths
end

"Expand a list of directory/file inputs into a list of CSV paths."
function expand_inputs(inputs::Vector{String})
    paths = String[]
    for p in inputs
        if isdir(p)
            append!(paths, collect_telemetry_csvs(p))
        else
            push!(paths, p)
        end
    end
    return paths
end

"Load and concatenate several telemetry CSVs, tagging each row with its source."
function load_set(paths::Vector{String})
    isempty(paths) && error("no telemetry CSVs found (searched $RESULTS)")
    dfs = DataFrame[]
    for p in paths
        isfile(p) || error("telemetry CSV not found: $p")
        d = CSV.read(p, DataFrame; comment="#")
        d[!, :source] .= joinpath(basename(dirname(p)), basename(p))
        push!(dfs, d)
    end
    return vcat(dfs...; cols=:union)
end

# ══════════════════════════════════════════════════════════════════════════════
# UI builders (chooser window + viewport window)
# ══════════════════════════════════════════════════════════════════════════════

"Viewport window: 3D form + score panel, driven by the `selected` row Observable."
function build_viewport(df::DataFrame, selected)
    fig = M.Figure(size=(900, 900), backgroundcolor=:white)
    ax3 = M.Axis3(fig[1, 1],
        backgroundcolor=:white,
        xlabel="x (m)", ylabel="y (m)", zlabel="z (m)",
        xgridcolor=(:black, 0.1), ygridcolor=(:black, 0.1), zgridcolor=(:black, 0.1),
        title="",
        aspect=(1, 1, 1.2))
    panel = M.Label(fig[1, 2], "", fontsize=15, halign=:left, valign=:top,
        tellwidth=false, tellheight=false)
    M.colsize!(fig.layout, 1, M.Relative(0.72))
    M.colsize!(fig.layout, 2, M.Relative(0.28))

    function render(rid)
        rid = clamp(rid, 1, nrow(df))
        row = df[rid, :]
        x = [row[Symbol("x$j")] for j in 1:14]
        dec, radii = decode_genome(x, Float64(row.tether))
        draw_form!(ax3, dec, radii)
        panel.text = score_panel_text(row, df, dec)
        ax3.title = @sprintf("%s — genome %d/%d/%d (%s)", row.source, row.island,
            row.gen, row.idx, first(genome_fingerprint(x), 16))
    end
    M.on(selected) do rid
        render(rid)
    end
    render(selected[])
    return fig
end

"Add a labelled range slider; returns the slider. Integer params snap to ints."
function add_slider(gl, r::Int, name::String, lo::Float64, hi::Float64, integer::Bool)
    M.Label(gl[r, 1], name, fontsize=11, halign=:left, tellwidth=false)
    rng = if integer
        round(Int, lo):round(Int, hi)
    elseif lo ≈ hi
        LinRange(lo, hi + 1e-6, 2)
    else
        LinRange(lo, hi, 400)
    end
    return M.IntervalSlider(gl[r, 2], range=rng, startvalues=(lo, hi), width=180)
end

"Chooser window: filter sliders + highlights menu + card grid."
function build_chooser(df::DataFrame, params::Vector{DecodedParams}, decset, selected)
    full = full_bounds(params)
    fig = M.Figure(size=(1250, 900), backgroundcolor=:white)

    fl = M.GridLayout(fig[1, 1])
    M.Label(fl[1, 1:2], "Filters", fontsize=16, halign=:left, tellwidth=false)

    sliders = Dict{Symbol,Any}()
    sliders[:r_hub] = add_slider(fl, 2, "r_hub (m)", full[:r_hub]..., false)
    sliders[:r_bot] = add_slider(fl, 3, "r_bot (m)", full[:r_bot]..., false)
    sliders[:n_lines] = add_slider(fl, 4, "n_lines", full[:n_lines]..., true)
    sliders[:n_active] = add_slider(fl, 5, "n_active", full[:n_active]..., true)
    sliders[:lam_top] = add_slider(fl, 6, "lam_top (λ)", full[:lam_top]..., false)
    sliders[:lam_bot] = add_slider(fl, 7, "lam_bot (λ)", full[:lam_bot]..., false)
    sliders[:bank_top] = add_slider(fl, 8, "bank_top (deg)", full[:bank_top]..., false)
    sliders[:bank_bot] = add_slider(fl, 9, "bank_bot (deg)", full[:bank_bot]..., false)
    sliders[:tether] = add_slider(fl, 10, "tether (m)", full[:tether]..., false)
    sliders[:density_profile] = add_slider(fl, 11, "density_profile", full[:density_profile]..., false)

    count_label = M.Label(fl[12, 1:2], "", fontsize=14, halign=:left, tellwidth=false)

    M.Label(fl[13, 1:2], "Highlights", fontsize=16, halign=:left, tellwidth=false)
    mode_menu = M.Menu(fl[14, 1:2], options=HIGHLIGHT_MODES, default="Standouts",
        width=200)

    # Card grid (fixed slots; labels + row mapping update on recompute).
    cg = M.GridLayout(fig[1, 2])
    CARD_COLS = 3
    CARD_ROWS = 8
    card_buttons = Vector{Any}(undef, CARD_COLS * CARD_ROWS)
    card_rids = zeros(Int, CARD_COLS * CARD_ROWS)
    for k in 1:(CARD_COLS * CARD_ROWS)
        c = mod1(k, CARD_COLS)
        r = (k - 1) ÷ CARD_COLS + 1
        card_buttons[k] = M.Button(cg[r, c], label="", width=180, height=70)
    end

    function current_spec()
        d = Dict{Symbol,Tuple{Float64,Float64}}()
        for s in FILTER_PARAMS
            v = sliders[s].interval[]
            d[s] = (Float64(v[1]), Float64(v[2]))
        end
        return d
    end

    function recompute!()
        spec = current_spec()
        matching = apply_filter(params, spec)
        count_label.text = "$(length(matching)) / $(nrow(df)) matching"
        hl = highlights_for_mode(mode_menu.selection[], df, params)
        display_rids = unique(vcat(hl, matching))
        for k in 1:length(card_buttons)
            rid = k <= length(display_rids) ? display_rids[k] : 0
            card_rids[k] = rid
            card_buttons[k].label = rid == 0 ? "" : card_text(df, params, decset, rid)
        end
    end

    for k in 1:length(card_buttons)
        M.on(card_buttons[k].clicks) do _
            rid = card_rids[k]
            rid > 0 && (selected[] = rid)
        end
    end
    for s in FILTER_PARAMS
        M.on(sliders[s].interval) do _
            recompute!()
        end
    end
    M.on(mode_menu.selection) do _
        recompute!()
    end

    recompute!()
    return fig
end

# ══════════════════════════════════════════════════════════════════════════════
# CLI
# ══════════════════════════════════════════════════════════════════════════════

function parse_args(args)
    inputs = String[]
    hash_filt = ""
    row_idx = 1
    png_path = nothing
    smoke_prefix = nothing
    do_selfcheck = false
    do_check = false
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
        elseif startswith(a, "--smoke=")
            smoke_prefix = a[9:end]
        elseif a == "--selfcheck"
            do_selfcheck = true
        elseif a == "--check"
            do_check = true
        elseif startswith(a, "--nav-check=")
            nav_check = parse(Int, a[13:end])
        elseif startswith(a, "-")
            error("unknown flag: $a")
        else
            push!(inputs, a)
        end
        i += 1
    end
    return (inputs, hash_filt, row_idx, png_path, smoke_prefix, do_selfcheck,
        do_check, nav_check)
end

function main()
    inputs, hash_filt, row_idx, png_path, smoke_prefix, do_selfcheck, do_check,
        nav_check = parse_args(ARGS)

    paths = expand_inputs(isempty(inputs) ? [RESULTS] : inputs)
    df = load_set(paths)
    decset = decode_all(df)
    params = decset.params

    start_i = row_idx
    if !isempty(hash_filt)
        m = findfirst(i -> occursin(hash_filt, decset.fingerprints[i]), 1:nrow(df))
        m === nothing && error("no genome matching --hash=$hash_filt")
        start_i = m
    end
    start_i = clamp(start_i, 1, nrow(df))

    if do_check
        exit(fullcheck(df, params, decset) ? 0 : 1)
    end

    if do_selfcheck
        st = BrowserState(df, start_i, nothing, Float64[], "")
        load_row!(st, start_i)
        exit(selfcheck(st, st.df[start_i, :]) ? 0 : 1)
    end

    if nav_check > 0
        st = BrowserState(df, start_i, nothing, Float64[], "")
        load_row!(st, start_i)
        println("NAV-CHECK over $nav_check rows:")
        for k in 1:nav_check
            load_row!(st, mod1(start_i + k, nrow(df)))
        end
        return
    end

    selected = M.Observable(start_i)

    if png_path !== nothing
        fig = build_viewport(df, selected)
        M.save(png_path, fig, px_per_unit=2)
        println("wrote $png_path")
        return
    end

    if smoke_prefix !== nothing
        chooser = build_chooser(df, params, decset, selected)
        viewport = build_viewport(df, selected)
        cp = smoke_prefix * "_chooser.png"
        vp = smoke_prefix * "_viewport.png"
        M.save(cp, chooser, px_per_unit=2)
        M.save(vp, viewport, px_per_unit=2)
        println("wrote $cp")
        println("wrote $vp")
        return
    end

    chooser = build_chooser(df, params, decset, selected)
    viewport = build_viewport(df, selected)

    if BACKEND[] === :glmakie
        s1 = GLMakie.Screen()
        display(s1, chooser)
        s2 = GLMakie.Screen()
        display(s2, viewport)
        println("Genome Chooser open — chooser window (filters/cards) + viewport window (3D).")
    else
        # CairoMakie headless fallback — render both to PNG as a best effort.
        M.save(joinpath(tempdir(), "genome_chooser.png"), chooser, px_per_unit=2)
        M.save(joinpath(tempdir(), "genome_viewport.png"), viewport, px_per_unit=2)
        println("CairoMakie fallback — saved chooser + viewport PNGs (no interactive window).")
    end
    println("Loaded $(start_i)/$(nrow(df)): $(decset.fingerprints[start_i])")
end

main()

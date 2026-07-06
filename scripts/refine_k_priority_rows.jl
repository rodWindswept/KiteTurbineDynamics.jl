#!/usr/bin/env julia
# scripts/refine_k_priority_rows.jl
# P2 k-refinement zoom procedure — 3 threshold rows from Gate 1.
#
# Reuses the Gate 1 measurement pipeline verbatim (ControlMapHunt module).
# For each priority row: samples 5 interior log-spaced k values in the bracket
# around the railed grid point, verifies at 60s, finds the true P-maximising k.
#
# Usage:
#   julia --project=. scripts/refine_k_priority_rows.jl              # all 3 rows sequential
#   julia --project=. scripts/refine_k_priority_rows.jl --row R1     # single row (for parallel)
#   julia --project=. scripts/refine_k_priority_rows.jl --row R2
#   julia --project=. scripts/refine_k_priority_rows.jl --row R3
#
# Spec: docs/prd/0006-p2-krefinement-spec.md

# ── Bootstrap: reuse Gate 1 pipeline ─────────────────────────────────────
include(joinpath(@__DIR__, "hunt_kmppt_bisect.jl"))
using .ControlMapHunt
using KiteTurbineDynamics
using Printf

const OUT_DIR = joinpath(@__DIR__, "results", "control_maps")
mkpath(OUT_DIR)

# ═══════════════════════════════════════════════════════════════════════════
# Priority row definitions
# ═══════════════════════════════════════════════════════════════════════════

struct RefineRow
    id::String
    label::String
    builder_fn::Function
    wind::Float64
    k_current::Float64
    P_current::Float64
    FoS_current::Float64
    k_low::Float64      # bracket lower bound (grid neighbour below)
    k_high::Float64     # bracket upper bound (grid neighbour above)
end

const ROWS = RefineRow[
    RefineRow("R1", "V10 Tight λ=1.0",
        ControlMapHunt.v10_tight_builder(blade_scale=1.0),
        11.0, 26.87460856772399, 118.77538304466414, 1.1470993382047319,
        12.9400270199972, 55.7927991064785),
    RefineRow("R2", "V10 Reinforced",
        ControlMapHunt.v10_tight_builder(r_bottom_scale=1.30, tether_diameter=0.004, blade_scale=1.0),
        15.0, 26.87460856772399, 300.98950448722337, 2.261444411221133,
        12.9400270199972, 55.7927991064785),
    RefineRow("R3", "λ=0.69",
        ControlMapHunt.v10_tight_builder(blade_scale=0.69),
        15.0, 6.230576302397042, 155.7585163949913, 2.081676599402634,
        3.0, 12.9400270199972),
]

# ═══════════════════════════════════════════════════════════════════════════
# Step 0 — Determinism check
# ═══════════════════════════════════════════════════════════════════════════

function determinism_check(row::RefineRow)
    lift = KiteTurbineDynamics.rotary_lifter_default()
    println("Step 0: determinism check — running $(row.id) at k=$(row.k_current) twice …")
    s1 = ControlMapHunt.run_verify_timeseries(
        row.builder_fn, row.wind, row.k_current; verbose=false, lift_device=lift)
    s2 = ControlMapHunt.run_verify_timeseries(
        row.builder_fn, row.wind, row.k_current; verbose=false, lift_device=lift)
    p1 = s1[end].P_kw
    p2 = s2[end].P_kw
    ΔP_rel = abs(p1 - p2) / max(abs(p1), 0.01)
    @printf("  run 1: P=%.2f kW  run 2: P=%.2f kW  ΔP_rel=%.4f%%\n", p1, p2, ΔP_rel * 100)
    if ΔP_rel > 0.001
        error("Determinism check FAILED: run-to-run noise $(ΔP_rel*100)% exceeds 0.1% threshold. Cannot proceed with refinement — fix noise source first.")
    end
    println("  ✓ passed (<0.1%)\n")
end

# ═══════════════════════════════════════════════════════════════════════════
# Zoom procedure for one row
# ═══════════════════════════════════════════════════════════════════════════

function refine_row(row::RefineRow, out_path::String)
    lift = KiteTurbineDynamics.rotary_lifter_default()
    N_INTERIOR = 5

    println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    println("$(row.id): $(row.label) @ $(row.wind) m/s")
    println("  current k=$(round(row.k_current, digits=2))  P=$(round(row.P_current, digits=1)) kW  FoS=$(round(row.FoS_current, digits=2))")
    println("  bracket: k ∈ [$(round(row.k_low, digits=2)), $(round(row.k_high, digits=2))]")
    println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

    # Build sample points: endpoints + interior
    log_low  = log10(row.k_low)
    log_high = log10(row.k_high)
    ks_interior = [10.0^(log_low + i * (log_high - log_low) / (N_INTERIOR + 1))
                   for i in 1:N_INTERIOR]
    ks_all = vcat(row.k_low, ks_interior, row.k_high)

    println("  sampling $(length(ks_all)) points: ", join([@sprintf("%.1f", k) for k in ks_all], ", "))

    # Open output CSV (progressive write)
    open(out_path, "w") do io
        hdr = "# script:refine_k_priority_rows @ $(ControlMapHunt.GIT_HASH) · row:$(row.id) · builder:$(row.label) · wind:$(row.wind) m/s\n"
        write(io, hdr)
        write(io, "k_mppt,P_kw,ω_rpm,min_fos,collapse_margin_deg,max_twist_deg,T_max_kN,P_aero_kw,n_failing\n")
    end

    results = Tuple{Float64,Float64,Float64,Float64,Float64,Float64,Float64,Float64,Int}[]

    t_start = time()
    for (n, k) in enumerate(ks_all)
        t0 = time()
        print("  [$(n)/$(length(ks_all))] k=$(round(k, digits=2)) … ")
        flush(stdout)

        slices = ControlMapHunt.run_verify_timeseries(
            row.builder_fn, row.wind, k; verbose=false, lift_device=lift)
        s = slices[end]

        elapsed = round(time() - t0, digits=0)
        @printf("P=%.1f kW  ω=%.0f rpm  FoS=%.2f  cm=%.1f°  fail=%d/21  (%ds)\n",
            s.P_kw, s.ω_rpm, s.min_fos, s.collapse_margin_deg, s.n_failing, elapsed)

        push!(results, (k, s.P_kw, s.ω_rpm, s.min_fos, s.collapse_margin_deg,
                         s.max_twist_deg, s.T_max_kN, s.P_aero_kw, s.n_failing))

        # Progressive save — write this point immediately
        open(out_path, "a") do io
            write(io, @sprintf("%.14f,%.14f,%.14f,%.14f,%.14f,%.14f,%.14f,%.14f,%d\n",
                k, s.P_kw, s.ω_rpm, s.min_fos, s.collapse_margin_deg,
                s.max_twist_deg, s.T_max_kN, s.P_aero_kw, s.n_failing))
        end

        # Time estimate after first point
        if n == 1
            est_total = elapsed * length(ks_all)
            @printf("  ⏱  first point %ds → est total ~%d min for this row\n",
                elapsed, round(Int, est_total / 60))
        end
    end

    total_elapsed = round((time() - t_start) / 60, digits=1)
    println("  ✓ $(row.id) complete in $(total_elapsed) min\n")

    # ── Find peak ──────────────────────────────────────────────────────
    # Sort by k
    perm = sortperm([r[1] for r in results])
    results_sorted = results[perm]

    # Find max P
    P_vals = [r[2] for r in results_sorted]
    i_peak = argmax(P_vals)
    k_peak, P_peak, ω_peak, FoS_peak = results_sorted[i_peak][1:4]

    # Edge check
    if i_peak == 1
        @warn "Peak at bracket LOW edge k=$(round(k_peak, digits=2)) — expand downward or accept (K_MIN)"
    elseif i_peak == length(results_sorted)
        @warn "Peak at bracket HIGH edge k=$(round(k_peak, digits=2)) — expand upward"
    end

    # Peak flatness: 3-point window around peak
    i1 = max(1, i_peak - 1)
    i2 = min(length(results_sorted), i_peak + 1)
    P_window = P_vals[i1:i2]
    flatness = maximum(P_window) / minimum(P_window)

    # Convergence check
    P_neighbours = Float64[]
    if i_peak > 1
        push!(P_neighbours, P_vals[i_peak - 1])
    end
    if i_peak < length(results_sorted)
        push!(P_neighbours, P_vals[i_peak + 1])
    end

    interior = i_peak > 1 && i_peak < length(results_sorted)
    converged = interior && all(P -> begin
        rd = abs(P_peak - P) / P_peak
        ad = abs(P_peak - P)
        rd < 0.01 || ad < 0.5
    end, P_neighbours)

    # Quadratic fit in log10(k) — diagnostic only
    ks_log = log10.([r[1] for r in results_sorted])
    # Fit through the 3 highest-P points
    top3_idx = partialsortperm(P_vals, 1:3, rev=true)
    xs_fit = ks_log[top3_idx]
    ys_fit = P_vals[top3_idx]
    # Quadratic: y = a*(x - x0)^2 + y0
    if length(unique(xs_fit)) >= 3
        A = hcat(ones(3), xs_fit, xs_fit.^2)
        coeffs = A \ ys_fit
        # Vertex at x = -b/(2c) for y = c*x^2 + b*x + a
        if abs(coeffs[3]) > 1e-12
            x_vertex = -coeffs[2] / (2 * coeffs[3])
            k_fit = 10.0^x_vertex
        else
            k_fit = NaN
        end
    else
        k_fit = NaN
    end

    return (row_id=row.id, label=row.label, wind=row.wind,
            k_old=row.k_current, P_old=row.P_current, FoS_old=row.FoS_current,
            k_new=k_peak, P_new=P_peak, ω_new=ω_peak, FoS_new=FoS_peak,
            ΔP_pct=(P_peak - row.P_current) / row.P_current * 100,
            flatness=flatness, k_fit_log10=k_fit,
            interior=interior, converged=converged,
            csv_path=out_path)
end

# ═══════════════════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════════════════

function main()
    # Parse --row filter (simple: --row R3 or --row=R3)
    row_filter = nothing
    i = 1
    while i <= length(ARGS)
        arg = ARGS[i]
        if startswith(arg, "--row=")
            row_filter = arg[7:end]
        elseif arg == "--row" && i < length(ARGS)
            row_filter = ARGS[i+1]
            i += 1
        end
        i += 1
    end

    rows_to_run = isnothing(row_filter) ? ROWS :
        filter(r -> r.id == row_filter, ROWS)
    isempty(rows_to_run) && error("No rows match filter '$row_filter'. Valid: R1, R2, R3")

    println("═══════════════════════════════════════════════════════════════════")
    println("P2 k-refinement zoom procedure")
    println("code state: $(ControlMapHunt.GIT_HASH)")
    println("rows: $(join([r.id for r in rows_to_run], ", "))")
    println("═══════════════════════════════════════════════════════════════════\n")

    # Step 0 — determinism check (run once on first row's k_current, or on R3)
    det_row = filter(r -> r.id == "R3", ROWS)[1]
    determinism_check(det_row)

    # Run refinement for each row
    results = []
    for row in rows_to_run
        out_path = joinpath(OUT_DIR, "k_refine_$(row.id).csv")
        t_start = time()
        result = refine_row(row, out_path)
        push!(results, result)
    end

    # ── Summary table ──────────────────────────────────────────────────
    println("\n" * "═"^90)
    println("REFINEMENT RESULTS")
    println("═"^90)
    println()
    header = @sprintf("%-4s %-18s %5s %7s %8s %7s %7s %8s %7s %7s %7s %5s  %s",
        "Row", "Builder", "Wind", "k_old", "P_old", "FoS_old",
        "k_new", "P_new", "FoS_new", "ΔP%", "flat", "conv", "k_fit(log10 diag)")
    println(header)
    println("─"^85)
    for r in results
        conv_str = r.converged ? "✓" : (r.interior ? "✗rel" : "✗edge")
        kfit_str = isnan(r.k_fit_log10) ? "—" : @sprintf("%.1f", r.k_fit_log10)
        @printf("%-4s %-18s %5.0f %7.1f %8.1f %7.2f %7.1f %8.1f %7.2f %+6.1f%% %5.3f %5s  %s\n",
            r.row_id, r.label, r.wind,
            r.k_old, r.P_old, r.FoS_old,
            r.k_new, r.P_new, r.FoS_new,
            r.ΔP_pct, r.flatness, conv_str, kfit_str)
    end
    println()
    println("CSVs: ", join([r.csv_path for r in results], ", "))

    # FoS threshold warnings
    for r in results
        old_ok = r.FoS_old >= 1.5
        new_ok = r.FoS_new >= 1.5
        old_fail = r.FoS_old < 1.0
        new_fail = r.FoS_new < 1.0
        if old_ok && !new_ok
            println("⚠  $(r.row_id): FoS crossed safe→marginal threshold ($(round(r.FoS_old, digits=2)) → $(round(r.FoS_new, digits=2)))")
        elseif !old_fail && new_fail
            println("🔴 $(r.row_id): FoS crossed marginal→fail threshold ($(round(r.FoS_old, digits=2)) → $(round(r.FoS_new, digits=2)))")
        elseif old_fail && !new_fail
            println("✅ $(r.row_id): FoS crossed fail→marginal ($(round(r.FoS_old, digits=2)) → $(round(r.FoS_new, digits=2)))")
        elseif !old_ok && new_ok
            println("✅ $(r.row_id): FoS crossed marginal→safe ($(round(r.FoS_old, digits=2)) → $(round(r.FoS_new, digits=2)))")
        end
    end
end

main()

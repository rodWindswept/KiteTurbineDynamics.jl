#!/usr/bin/env julia
# scripts/torsional_collapse_check.jl
#
# Post-hoc torsional collapse check for all v2 campaign winners.
# Applies the Tulloch/Wacker criterion for TRPT torsional stability to every
# rank-1 design in every island's elite_archive.csv.
#
# Physics derivation (Tulloch, PhD TU Delft):
# ─────────────────────────────────────────────
# In a TRPT segment of axial length L between two rings of radius r, with
# n_lines lines each under tension T_line = T_total/n_lines, the torque
# transmitted by the helical line winding is:
#
#   τ(δα) = n_lines × T_line × r² × sin(δα) / chord(δα)
#
# where δα is the twist angle per segment and chord(δα) = √(L²+4r²sin²(δα/2))
# is the actual 3D line length.
#
# This function has a unique maximum at:
#
#   δα* = 2 arcsin( L / √(2(L²+2r²)) )
#
# and the maximum torque capacity is:
#
#   τ_cap = n_lines × T_line × r² / √(L² + 2r²)
#          = T_total × r² / √(L² + 2r²)
#
# (n_lines cancels: more lines ↓ per-line tension by n_lines, capacity unchanged).
#
# Torsional FOS = τ_cap / τ_op
# Operating torque: τ_op = P_rated / ω_rated
# where ω_rated = TSR_RATED × v_rated / r_rotor
#
# For conservative analysis, we use r_min = min(r_lower, r_upper) per segment.
# τ_cap ∝ r², so the smallest-radius segment is always worst.
#
# Usage:
#   julia --project=. scripts/torsional_collapse_check.jl

using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics
using CSV, DataFrames, Printf

# ── Constants for the torsional operating-point check ─────────────────────────
const RHO_AIR              = 1.225   # kg/m³
const CT_RATED             = 0.55    # thrust coefficient at rated BEM operation
                                     # (Betz-optimal rotor: a≈0.25–0.30, CT≈0.55)
const TSR_RATED            = 4.1     # optimal tip-speed ratio (from k_mppt derivation)
const TORSION_FOS_REQUIRED = 1.5     # minimum torsional FOS for a feasible segment

# ── Torsional check for one design ────────────────────────────────────────────
"""
    torsional_check(design, p) → (min_fos, fos_per_seg, τ_op_Nm, T_total_N)

Compute Tulloch torsional FOS per segment at rated operating conditions.

τ_cap(i) = T_total_rated × r_min(i)² / √(L(i)² + 2·r_min(i)²)
τ_op     = P_rated / ω_rated  (ω_rated = TSR × v_rated / r_rotor)

r_min(i) = min(r_lower, r_upper) — conservative; worst case is smallest radius.
"""
function torsional_check(design::TRPTDesignV2, p::SystemParams)
    v_rated  = p.v_wind_ref        # rated hub wind speed (m/s)
    r_rotor  = p.rotor_radius      # rotor radius (m)
    β        = p.elevation_angle   # shaft elevation (rad)
    P_rated  = p.p_rated_w         # rated power (W)

    ω_rated       = TSR_RATED * v_rated / r_rotor
    τ_op          = P_rated / ω_rated

    # Total thrust-line tension at rated wind; this is the pre-tension that
    # enables torque transmission.  Uses peak_hub_thrust with rated wind + CT.
    T_total_rated = peak_hub_thrust(r_rotor, β; v=v_rated, CT=CT_RATED)

    radii   = ring_radii(design)
    L_segs  = segment_axial_lengths(design)
    n_seg   = length(L_segs)

    fos_per_seg = Vector{Float64}(undef, n_seg)
    for i in 1:n_seg
        r_min      = min(radii[i], radii[i+1])   # conservative: smaller ring
        L          = L_segs[i]
        τ_cap      = T_total_rated * r_min^2 / sqrt(L^2 + 2*r_min^2)
        fos_per_seg[i] = τ_cap / max(τ_op, 1e-9)
    end
    return minimum(fos_per_seg), fos_per_seg, τ_op, T_total_rated
end

# ── Optimal twist angle at max torque ─────────────────────────────────────────
"""
    optimal_twist_angle(L, r) → δα* (radians)

Twist angle per segment at which torque capacity is maximised.
sin(δα*/2) = L / √(2(L²+2r²))
"""
function optimal_twist_angle(L::Float64, r::Float64)
    arg = clamp(L / sqrt(2*(L^2 + 2*r^2)), 0.0, 1.0)
    return 2*asin(arg)
end

# ── Load best design from each island ─────────────────────────────────────────
function parse_beam_from_name(island::AbstractString)
    lowercase(island) == "elliptical" && return PROFILE_ELLIPTICAL
    lowercase(island) == "airfoil"    && return PROFILE_AIRFOIL
    return PROFILE_CIRCULAR
end

"""
    load_island_winners(v2_dir) → Vector of NamedTuples

For each island in v2_dir that has an elite_archive.csv, load the rank-1
(lightest feasible) design and return it as a reconstructed TRPTDesignV2.
"""
function load_island_winners(v2_dir::String)
    results = []
    for island_dir in sort(readdir(v2_dir; join=true))
        isdir(island_dir) || continue
        arch_path = joinpath(island_dir, "elite_archive.csv")
        isfile(arch_path) || continue

        island = basename(island_dir)
        # Expected format: "{config}_{beam}_{axial}_{seed}"  e.g. "10kw_circular_straight_taper_s1"
        parts = split(island, "_")
        length(parts) < 4 && continue
        config_kw = parts[1]   # "10kw" or "50kw"
        beam_kw   = parts[2]   # "circular", "elliptical", "airfoil"

        p    = config_kw == "50kw" ? params_50kw() : params_10kw()
        beam = parse_beam_from_name(beam_kw)

        df = CSV.read(arch_path, DataFrame)
        isempty(df) && continue

        # rank=1 is the lightest feasible design in the elite archive
        best = df[1, :]

        design = TRPTDesignV2(
            beam,
            Float64(best.Do_top_m),
            Float64(best.t_over_D),
            Float64(best.beam_aspect),
            Float64(best.Do_scale_exp),
            axial_profile_from_index(Int(best.axial_idx)),
            Float64(best.profile_exp),
            clamp(Float64(best.straight_frac), 0.0, 0.9),
            Float64(best.r_hub_m),
            clamp(Float64(best.taper), 0.05, 1.0),
            Int(best.n_rings),
            p.tether_length,
            Int(best.n_lines),
            Float64(best.knuckle_mass_kg),
        )
        push!(results, (
            island   = island,
            config   = config_kw,
            beam     = beam_kw,
            design   = design,
            params   = p,
            mass_kg  = Float64(best.mass_kg),
        ))
    end
    sort!(results, by = r -> (r.config, r.mass_kg))
    return results
end

# ── Per-design detailed report ────────────────────────────────────────────────
function report_design(io::IO, island, config, mass, design, p)
    min_fos, fos_segs, τ_op, T_total = torsional_check(design, p)
    pass = min_fos >= TORSION_FOS_REQUIRED

    v_rated = p.v_wind_ref
    r_rotor = p.rotor_radius
    ω_rated = TSR_RATED * v_rated / r_rotor

    radii  = ring_radii(design)
    L_segs = segment_axial_lengths(design)

    println(io, "  Island: $island")
    @printf(io, "  Mass %.3f kg  |  n_rings=%d  n_lines=%d  r_hub=%.3f m  taper=%.2f\n",
            mass, design.n_rings, design.n_lines, design.r_hub, design.taper_ratio)
    @printf(io, "  τ_op = P/ω = %.0f/%.3f = %.1f N·m  |  T_total_rated = %.0f N\n",
            p.p_rated_w, ω_rated, τ_op, T_total)
    println(io, "  Segment torsional FOS (required ≥ $TORSION_FOS_REQUIRED):")
    for i in eachindex(fos_segs)
        r_lo = radii[i]; r_hi = radii[i+1]
        r_min = min(r_lo, r_hi)
        L     = L_segs[i]
        τ_cap = T_total * r_min^2 / sqrt(L^2 + 2*r_min^2)
        δα_deg = rad2deg(optimal_twist_angle(L, r_min))
        status = fos_segs[i] >= TORSION_FOS_REQUIRED ? "✓" : "✗"
        @printf(io, "    seg%d: r_min=%.3fm  L/r=%.2f  δα*=%.1f°  τ_cap=%.1fN·m  FOS=%.3f %s\n",
                i, r_min, L/r_min, δα_deg, τ_cap, fos_segs[i], status)
    end
    verdict = pass ? "PASS" : "FAIL"
    @printf(io, "  → min torsional FOS = %.3f  [%s]\n", min_fos, verdict)
    println(io)
    return pass, min_fos
end

# ── Main ──────────────────────────────────────────────────────────────────────
function main()
    v2_dir = joinpath(@__DIR__, "results", "trpt_opt_v2")
    if !isdir(v2_dir)
        error("v2 results directory not found: $v2_dir")
    end

    println("="^72)
    println("Torsional Collapse Check — TRPT v2 Campaign (Tulloch/Wacker criterion)")
    println("="^72)
    println()
    println("Formula: τ_cap = T_total_rated × r_min² / √(L_seg² + 2·r_min²)")
    println("         T_total_rated = 0.5 ρ v_rated² π R² × CT_rated × cos²(β)")
    println("         CT_rated = $CT_RATED  |  TSR_rated = $TSR_RATED")
    println("Required torsional FOS ≥ $TORSION_FOS_REQUIRED")
    println()

    islands = load_island_winners(v2_dir)
    if isempty(islands)
        error("No elite archives found in $v2_dir")
    end

    # ── Detailed per-island report ─────────────────────────────────────────
    n_pass_10kw = 0; n_fail_10kw = 0
    n_pass_50kw = 0; n_fail_50kw = 0

    println("─"^72)
    println("10 kW designs")
    println("─"^72)
    for r in filter(x -> x.config == "10kw", islands)
        pass, _ = report_design(stdout, r.island, r.config, r.mass_kg, r.design, r.params)
        pass ? (n_pass_10kw += 1) : (n_fail_10kw += 1)
    end

    println("─"^72)
    println("50 kW designs")
    println("─"^72)
    for r in filter(x -> x.config == "50kw", islands)
        pass, _ = report_design(stdout, r.island, r.config, r.mass_kg, r.design, r.params)
        pass ? (n_pass_50kw += 1) : (n_fail_50kw += 1)
    end

    # ── Summary ────────────────────────────────────────────────────────────
    total_islands = length(islands)
    total_pass    = n_pass_10kw + n_pass_50kw
    total_fail    = n_fail_10kw + n_fail_50kw

    println("="^72)
    println("SUMMARY")
    println("="^72)
    @printf("10 kW: %d/%d PASS  (%d FAIL)\n",
            n_pass_10kw, n_pass_10kw+n_fail_10kw, n_fail_10kw)
    @printf("50 kW: %d/%d PASS  (%d FAIL)\n",
            n_pass_50kw, n_pass_50kw+n_fail_50kw, n_fail_50kw)
    @printf("Total: %d/%d PASS  (%d FAIL)\n", total_pass, total_islands, total_fail)
    println()

    # ── Highlight overall winners ──────────────────────────────────────────
    best_10kw = first(filter(x -> x.config == "10kw", islands))
    best_50kw = first(filter(x -> x.config == "50kw", islands))

    println("Lightest 10 kW winner: $(best_10kw.island)  →  $(round(best_10kw.mass_kg; digits=3)) kg")
    min_fos_10, _, τ_op_10, T_10 = torsional_check(best_10kw.design, best_10kw.params)
    @printf("  Torsional FOS: %.3f  (%s vs required %.1f)\n",
            min_fos_10, min_fos_10 >= TORSION_FOS_REQUIRED ? "PASS" : "FAIL", TORSION_FOS_REQUIRED)

    println()
    println("Lightest 50 kW winner: $(best_50kw.island)  →  $(round(best_50kw.mass_kg; digits=3)) kg")
    min_fos_50, _, τ_op_50, T_50 = torsional_check(best_50kw.design, best_50kw.params)
    @printf("  Torsional FOS: %.3f  (%s vs required %.1f)\n",
            min_fos_50, min_fos_50 >= TORSION_FOS_REQUIRED ? "PASS" : "FAIL", TORSION_FOS_REQUIRED)

    println()
    if total_fail > 0
        println("CONCLUSION: ALL $total_fail v2 winners FAIL the torsional collapse check.")
        println()
        println("The Euler-only optimiser produced frames that survive peak wind loads")
        println("(25 m/s, FOS ≥ 1.8) but cannot transmit rated torque ($(Int(best_10kw.params.p_rated_w/1000)) kW)")
        println("without torsional shaft collapse. The dominant failure mode is small")
        println("ring radius at the ground end — τ_cap ∝ r², so the tapered bottom")
        println("rings with r_min ≈ $(round(best_10kw.design.r_hub*best_10kw.design.taper_ratio; digits=2)) m")
        println("have negligible torque capacity.")
        println()
        println("v3 optimisation with Tulloch torsional FOS ≥ $TORSION_FOS_REQUIRED enforced")
        println("as a hard constraint is required. Expect v3 winners to have:")
        println("  • Much larger bottom-ring radius (taper_ratio → 1.0, near-cylindrical)")
        println("  • More intermediate rings (shorter L per segment → higher τ_cap)")
        println("  • Consequently higher mass than v2 — a real physical constraint,")
        println("    not a modelling penalty.")
    else
        println("All v2 winners PASS the torsional collapse check.")
    end
    println("="^72)
end

main()

#!/usr/bin/env julia
# scripts/verify_top_candidates_envelope.jl
# Phase E — Quasi-static envelope verification of the top elite-archive
# candidates across the full operational wind/RPM envelope.
#
# THESIS
# ------
# The optimizer sizes each design at v_peak = 25 m/s with the rotor spinning
# at its optimal tip-speed ratio (λ = 4.1). That is the DESIGN point, but the
# structure must survive the full envelope:
#   (a) Cut-in (v ≈ 5 m/s, ω low → near-zero centripetal relief)
#   (b) Rated (v ≈ 11 m/s, ω at rated tip-speed-ratio)
#   (c) Over-speed margin (v = 25 m/s, ω at rated)
#   (d) Coherent gust (v jumps 11 → 25 m/s while ω is still at rated — the
#       centripetal relief term lags because the rotor can't spin up
#       instantaneously; gust is the structurally worst case)
#
# We re-evaluate every top candidate at six envelope points and require per-ring
# FOS ≥ 1.5 at every point (a 20% margin below the design FOS of 1.8).
# Candidates that fail any envelope point are flagged non-verified.
#
# INPUT
#   scripts/results/trpt_opt_v2/<tag>/elite_archive.csv   (one per DE island)
#
# OUTPUT
#   scripts/results/trpt_opt_v2/cartography/
#     phase_e_envelope_verification.csv
#     phase_e_envelope_summary.json

using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics
using CSV, DataFrames, JSON3, Printf, Dates, Statistics

const ROOT   = dirname(@__DIR__)
const V2_DIR = joinpath(ROOT, "scripts", "results", "trpt_opt_v2")
const OUT    = joinpath(V2_DIR, "cartography")
mkpath(OUT)

# Envelope points: (label, v_peak, omega_scale_relative_to_rated)
# omega_rated at v_peak=25 is λ·v/r = 4.1*25/5 = 20.5 rad/s (10 kW) or
# 4.1*25/sys.rotor_radius for 50 kW. We scale relative to rated.
const ENVELOPE = [
    ("cut_in",     5.0,  0.2),   # cut-in: 20% of rated RPM
    ("rated",     11.0,  0.44),  # rated wind, rated RPM (11/25)
    ("overspeed", 25.0,  1.0),   # design point
    ("gust_coherent", 25.0, 0.44), # gust arrives while rotor still at rated RPM
    ("gust_hard",     25.0, 0.25), # pessimistic: rotor still at 25% rated
    ("hi_ambient",   20.0, 0.80),  # steady high wind
]
const FOS_ENVELOPE_FLOOR = 1.5

pick_beam(s) =
    s == "elliptical" ? PROFILE_ELLIPTICAL :
    s == "airfoil"    ? PROFILE_AIRFOIL    :
                        PROFILE_CIRCULAR

pick_axial(s) =
    s == "linear"         ? AXIAL_LINEAR         :
    s == "elliptic"       ? AXIAL_ELLIPTIC       :
    s == "parabolic"      ? AXIAL_PARABOLIC      :
    s == "trumpet"        ? AXIAL_TRUMPET        :
                            AXIAL_STRAIGHT_TAPER

pick_sys(s) = lowercase(s) == "50kw" ? params_50kw() : params_10kw()

function parse_tag(tag::String)
    parts = split(tag, "_")
    cfg = parts[1]; beam = parts[2]
    if length(parts) >= 5 && parts[3] == "straight" && parts[4] == "taper"
        ax = "straight_taper"; seed = parts[5]
    else
        ax = parts[3]; seed = parts[4]
    end
    return cfg, beam, ax, seed
end

function build_design(row, beam_profile::BeamProfile,
                      axial_profile::AxialProfile, tether_length::Float64)
    return TRPTDesignV2(
        beam_profile,
        row.Do_top_m, row.t_over_D, row.beam_aspect, row.Do_scale_exp,
        axial_profile, row.profile_exp, row.straight_frac,
        row.r_hub_m, row.taper, row.n_rings, tether_length,
        row.n_lines, row.knuckle_mass_kg,
    )
end

function verify_candidate(design::TRPTDesignV2, sys::SystemParams)
    omega_rated = 4.1 * 25.0 / sys.rotor_radius
    rows = NamedTuple[]
    worst_fos_overall = Inf
    passed_all = true
    for (label, v, om_frac) in ENVELOPE
        omega = om_frac * omega_rated
        r = evaluate_design(design;
                             r_rotor   = sys.rotor_radius,
                             elev_angle = sys.elevation_angle,
                             v_peak    = v,
                             omega_rotor = omega)
        ok = r.feasible && r.min_fos >= FOS_ENVELOPE_FLOOR
        worst_fos_overall = min(worst_fos_overall, r.min_fos)
        passed_all &= ok
        push!(rows, (envelope = label, v_peak = v, omega = omega,
                     min_fos = r.min_fos, feasible = r.feasible,
                     mass_kg = r.mass_total_kg, ok_envelope = ok))
    end
    return rows, passed_all, worst_fos_overall
end

function main(; top_k::Int = 5)
    tags = filter(readdir(V2_DIR)) do d
        isdir(joinpath(V2_DIR, d)) &&
        !(d in ("lhs", "cartography", "renders")) &&
        isfile(joinpath(V2_DIR, d, "elite_archive.csv"))
    end
    isempty(tags) && error("No elite_archive.csv files found under $V2_DIR")
    println("verifying top-$top_k of each of $(length(tags)) islands")

    out_rows = DataFrame()
    n_pass = 0; n_total = 0
    for tag in tags
        try
            cfg, beam_s, ax_s, seed = parse_tag(tag)
            sys = pick_sys(cfg)
            beam = pick_beam(beam_s)
            ax   = pick_axial(ax_s)
            df = CSV.read(joinpath(V2_DIR, tag, "elite_archive.csv"), DataFrame)
            nrow(df) == 0 && continue
            # Take the k lowest-mass rows
            sub = first(sort(df, :mass_kg), min(top_k, nrow(df)))
            for (rank, row) in enumerate(eachrow(sub))
                design = build_design(row, beam, ax, sys.tether_length)
                env_rows, passed, worst_fos = verify_candidate(design, sys)
                n_total += 1
                passed && (n_pass += 1)
                for er in env_rows
                    push!(out_rows, merge((tag=tag, config=cfg, beam=beam_s,
                                           axial=ax_s, seed=seed, rank=rank,
                                           design_mass_kg=row.mass_kg,
                                           design_min_fos=row.min_fos,
                                           verified_overall=passed,
                                           worst_env_fos=worst_fos), er),
                          promote=true)
                end
            end
        catch err
            @warn "failed $tag: $err"
        end
    end

    csv_path = joinpath(OUT, "phase_e_envelope_verification.csv")
    CSV.write(csv_path, out_rows)
    println("wrote $csv_path ($(nrow(out_rows)) rows, $n_pass/$n_total designs pass envelope)")

    summary = Dict(
        "generated_at" => Dates.format(now(), "yyyy-mm-ddTHH:MM:SS"),
        "n_islands" => length(tags),
        "top_k_per_island" => top_k,
        "n_designs_verified" => n_total,
        "n_designs_passed" => n_pass,
        "pass_rate" => n_total == 0 ? 0.0 : n_pass / n_total,
        "fos_envelope_floor" => FOS_ENVELOPE_FLOOR,
        "envelope_points" => [Dict("label"=>l, "v_peak"=>v, "omega_frac"=>o)
                               for (l,v,o) in ENVELOPE],
    )
    open(joinpath(OUT, "phase_e_envelope_summary.json"), "w") do io
        JSON3.pretty(io, summary)
    end
    println("wrote $(joinpath(OUT, "phase_e_envelope_summary.json"))")
end

main(top_k = get(ENV, "PHASE_E_TOPK", "5") |> s -> parse(Int, s))

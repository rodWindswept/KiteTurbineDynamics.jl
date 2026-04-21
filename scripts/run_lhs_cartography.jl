#!/usr/bin/env julia
# scripts/run_lhs_cartography.jl
# Phase D support: Latin Hypercube broad sampling of the v2 design space
# for global sensitivity + heatmap generation (no optimization, just a clean
# coverage of the envelope).
#
# Usage:
#   julia --project=. scripts/run_lhs_cartography.jl \
#         --config 10kw --beam-profile circular --axial-profile free \
#         --samples 50000 --seed 7 \
#         --output scripts/results/trpt_opt_v2/lhs/10kw_circular_free.csv

using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics
using ArgParse, CSV, DataFrames, Random, Dates, Printf

function parse_cli()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--config";        arg_type=String; default="10kw"
        "--beam-profile";  arg_type=String; default="circular"
        "--axial-profile"; arg_type=String; default="free"
        "--samples";       arg_type=Int;    default=50_000
        "--seed";          arg_type=Int;    default=7
        "--output";        arg_type=String; required=true
    end
    return parse_args(s)
end

parse_config(n) = lowercase(n) == "50kw" ? ("50 kW", params_50kw()) :
                                           ("10 kW", params_10kw())
parse_beam(n)   = (lowercase(n) == "elliptical" ? PROFILE_ELLIPTICAL :
                   lowercase(n) == "airfoil"    ? PROFILE_AIRFOIL    :
                                                  PROFILE_CIRCULAR)
function parse_axial(n)
    n == "linear"         && return AXIAL_LINEAR
    n == "elliptic"       && return AXIAL_ELLIPTIC
    n == "parabolic"      && return AXIAL_PARABOLIC
    n == "trumpet"        && return AXIAL_TRUMPET
    n == "straight_taper" && return AXIAL_STRAIGHT_TAPER
    return nothing
end

# LHS: stratified random sample over D dims
function lhs_sample(N::Int, lo::Vector{Float64}, hi::Vector{Float64},
                    rng::AbstractRNG)
    D = length(lo)
    X = Matrix{Float64}(undef, N, D)
    for d in 1:D
        perm = randperm(rng, N)
        for i in 1:N
            u = (perm[i] - 1.0 + rand(rng)) / N
            X[i, d] = lo[d] + u * (hi[d] - lo[d])
        end
    end
    return X
end

function main()
    args = parse_cli()
    cfg_name, p = parse_config(args["config"])
    beam = parse_beam(args["beam-profile"])
    ax_locked = parse_axial(args["axial-profile"])
    r_rotor = p.rotor_radius
    elev    = p.elevation_angle

    rng = MersenneTwister(args["seed"])
    lo, hi = search_bounds_v2(p, beam)
    if ax_locked !== nothing
        idx = Float64(Int(ax_locked))
        lo[8] = idx; hi[8] = idx
    end

    mkpath(dirname(args["output"]))
    N = args["samples"]
    println("LHS cartography: N=$N, config=$cfg_name, beam=$beam, axial=$(ax_locked === nothing ? "free" : ax_locked)")
    X = lhs_sample(N, lo, hi, rng)

    out = DataFrame(
        Do_top_m        = zeros(Float64, N),
        t_over_D        = zeros(Float64, N),
        beam_aspect     = zeros(Float64, N),
        Do_scale_exp    = zeros(Float64, N),
        r_hub_m         = zeros(Float64, N),
        taper_ratio     = zeros(Float64, N),
        n_rings         = zeros(Int, N),
        axial_idx       = zeros(Int, N),
        profile_exp     = zeros(Float64, N),
        straight_frac   = zeros(Float64, N),
        knuckle_mass_kg = zeros(Float64, N),
        n_lines         = zeros(Int, N),
        mass_kg         = zeros(Float64, N),
        mass_beams_kg   = zeros(Float64, N),
        mass_knuckles_kg= zeros(Float64, N),
        min_fos         = zeros(Float64, N),
        worst_ring      = zeros(Int, N),
        feasible        = falses(N),
    )

    t0 = time()
    for i in 1:N
        x = X[i, :]
        d = design_from_vector_v2(x, beam, p)
        r = evaluate_design(d; r_rotor=r_rotor, elev_angle=elev)
        out[i, :Do_top_m]        = d.Do_top
        out[i, :t_over_D]        = d.t_over_D
        out[i, :beam_aspect]     = d.beam_aspect
        out[i, :Do_scale_exp]    = d.Do_scale_exp
        out[i, :r_hub_m]         = d.r_hub
        out[i, :taper_ratio]     = d.taper_ratio
        out[i, :n_rings]         = d.n_rings
        out[i, :axial_idx]       = Int(d.axial_profile)
        out[i, :profile_exp]     = d.profile_exp
        out[i, :straight_frac]   = d.straight_frac
        out[i, :knuckle_mass_kg] = d.knuckle_mass_kg
        out[i, :n_lines]         = d.n_lines
        out[i, :mass_kg]         = r.mass_total_kg
        out[i, :mass_beams_kg]   = r.mass_beams_kg
        out[i, :mass_knuckles_kg]= r.mass_knuckles_kg
        out[i, :min_fos]         = r.min_fos
        out[i, :worst_ring]      = r.worst_ring_idx
        out[i, :feasible]        = r.feasible
        if i % 5000 == 0
            dt = time() - t0
            @printf("  progress %d / %d — %.2fs, %.1f /ms\n", i, N, dt, i/(dt*1000))
        end
    end

    CSV.write(args["output"], out)
    feasible_count = sum(out.feasible)
    feasible_min_mass = feasible_count > 0 ? minimum(out.mass_kg[out.feasible]) : NaN
    println("wrote $(args["output"]) — feasible=$feasible_count/$N ($(round(100*feasible_count/N;digits=1))%)")
    println("feasible min_mass = $(round(feasible_min_mass;digits=3)) kg")
end

main()

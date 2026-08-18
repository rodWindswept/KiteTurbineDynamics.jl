#!/usr/bin/env julia
# scripts/lift_retrospective_v13.jl
#
# Retrospective lift-tension augmentation for the FIRST 5 kW v13 campaigns
# (v13_5kw_len18.0 / 21.2 / 25.0 — fixed rotary lifter era).
#
# For every logged genome: decode it exactly as the campaign did, compute
#   m_airborne      = expansion_airborne_mass(sys, pc)
#   T_mass_1p5_N    = 1.5 * m_airborne * g / sin(70°)  — the mass-aware
#                     CONSTANT-tension requirement (vertical = 1.5× weight,
#                     Rod 2026-08-18)
#   T_rotary_actual = the fixed rotary lifter's tension at rated wind —
#                     what the campaign actually applied (wind-only, not
#                     mass-aware)
# and write an addendum CSV + provenance note into each folder. Originals
# untouched. Decode era: HEAD of this checkout (stamped in the note).
#
# Plan: docs/plans/2026-08-18-5kw-mass-aware-lift-redo.md (Workstream A)

using KiteTurbineDynamics
using CSV, DataFrames, Printf, Dates, Statistics
const KTD = KiteTurbineDynamics

const GIT_HASH = strip(read(`git -C $(dirname(@__DIR__)) rev-parse --short HEAD`, String))
const KW = 5.0
const PW = 5000.0
const V_RATED = 11.0
const MARGIN = 1.5
const ELEV_DEG = 70.0
const G = 9.81
const LENGTHS = [18.0, 21.2, 25.0]

# ── Identical to run_v13_5kw.jl:params_at_length ─────────────────────────
function params_at_length(L::Float64)
    p2 = params_10kw()
    geo = GeometrySpec(p2.elevation_angle, p2.lifter_elevation, p2.rotor_radius,
        L, p2.trpt_hub_radius, p2.trpt_rL_ratio, p2.n_lines, p2.n_rings, p2.n_blades)
    mat = MaterialSpec(p2.tether_diameter, p2.e_modulus, p2.m_ring, p2.m_blade)
    aero = AeroSpec(p2.rho, p2.v_wind_ref, p2.h_ref, p2.cp)
    ctrl = ControlSpec(p2.i_pto, p2.k_mppt, p2.p_rated_w, p2.β_min, p2.β_max, p2.β_rate_max, p2.kp_elev)
    back = BackLineSpec(p2.EA_back_line, p2.c_back_line, p2.back_anchor_fwd_x, p2.backline_payout)
    return mass_scale(SystemParams(geo, mat, aero, ctrl, back), 10.0, KW)
end

# ── Decode a genome exactly as the campaign runner did (xr rounding) ──────
function tension_row(x14::Vector{Float64}, p_base)
    xr = copy(x14)
    xr[8] = Float64(round(Int, clamp(xr[8], 3, 16)))          # n_lines
    xr[10] = clamp(xr[10], 0.0, Float64(N_VALID_MASKS))       # rotor mask
    result = design_from_vector_v10(xr, PROFILE_ELLIPTICAL, p_base; power_W=PW, v_rated=V_RATED)
    sys, u0, pc = KTD.build_system_from_v10(result, 1.0, p_base.k_mppt;
        tether_diameter=p_base.tether_diameter)
    m_air = expansion_airborne_mass(sys, pc)
    T_mass = MARGIN * m_air * G / sind(ELEV_DEG)              # constant 1.5× vertical
    _, T_rot, _ = lift_force_steady(rotary_lifter_default(), pc.rho, V_RATED, pc)
    return (m_air, T_mass, T_rot)
end

# ── Per-length processing ─────────────────────────────────────────────────
for L in LENGTHS
    dir = joinpath(@__DIR__, "results", "v13_5kw_len$(L)")
    tele = joinpath(dir, "telemetry.csv")
    isfile(tele) || (println("MISSING $tele"); continue)
    p_base = params_at_length(L)

    # Line 1 is a # comment, line 2 the header, data from line 3.
    df = CSV.File(tele; header=2, skipto=3) |> DataFrame
    n = nrow(df)
    rows = Vector{NamedTuple{(:island,:gen,:idx,:status,:fitness,:n_lines,:rings,
        :n_active,:r_hub,:r_bot,:tether,:m_airborne_kg,:T_mass_1p5_N,
        :T_rotary_actual_N,:ratio),Tuple{Int,Int,Int,String,Float64,Int,Int,
        Int,Float64,Float64,Float64,Float64,Float64,Float64,Float64}}}(undef, n)

    @printf("length %.1f m: %d rows\n", L, n)
    for i in 1:n
        row = df[i, :]
        x14 = [row["x$j"] for j in 1:14]
        m_air = T_mass = T_rot = NaN
        try
            m_air, T_mass, T_rot = tension_row(x14, p_base)
        catch
            m_air = T_mass = T_rot = NaN
        end
        ratio = (isfinite(T_rot) && T_mass > 0) ? T_rot / T_mass : NaN
        rows[i] = (
            island=Int(row.island), gen=Int(row.gen), idx=Int(row.idx),
            status=String(row.status), fitness=Float64(row.fitness),
            n_lines=Int(row.n_lines), rings=Int(row.rings), n_active=Int(row.n_active),
            r_hub=Float64(row.r_hub), r_bot=Float64(row.r_bot), tether=Float64(row.tether),
            m_airborne_kg=m_air, T_mass_1p5_N=T_mass, T_rotary_actual_N=T_rot, ratio=ratio,
        )
    end

    out = DataFrame(rows)
    CSV.write(joinpath(dir, "lift_tension_retrospective.csv"), out)

    # Winner headline row (best_vector.csv = single line, 14 values).
    winner_x = [parse(Float64, v) for v in split(strip(read(joinpath(dir, "best_vector.csv"), String)), ',')]
    w_m, w_Tm, w_Tr = tension_row(winner_x, p_base)

    # Provenance note
    open(joinpath(dir, "lift_retrospective_note.md"), "w") do io
        println(io, "# Lift-tension retrospective — v13_5kw_len$(L)")
        println(io)
        println(io, "- **Script:** scripts/lift_retrospective_v13.jl (decode era: $(GIT_HASH))")
        println(io, "- **Date:** $(Dates.now())")
        println(io, "- **Question:** the first campaign applied a FIXED rotary lifter. What tension did each genome actually see, and what does the mass-aware constant-tension rule (1.5× vertical, Rod 2026-08-18) require instead?")
        println(io)
        println(io, "## Winner")
        println(io)
        @printf(io, "- m_airborne = %.2f kg\n", w_m)
        @printf(io, "- mass-aware constant tension T = 1.5·m·g/sin(70°) = %.1f N (vertical = 1.5× weight)\n", w_Tm)
        @printf(io, "- rotary tension actually applied at 11 m/s = %.1f N\n", w_Tr)
        @printf(io, "- ratio rotary/mass-aware = %.2f×\n", w_Tr / w_Tm)
        println(io)
        println(io, "## Population summary")
        ok = filter(r -> isfinite(r.ratio), rows)
        if !isempty(ok)
            @printf(io, "- rows decoded: %d / %d\n", length(ok), n)
            @printf(io, "- m_airborne: %.2f – %.2f kg\n", minimum(getfield.(ok, :m_airborne_kg)), maximum(getfield.(ok, :m_airborne_kg)))
            @printf(io, "- ratio rotary/mass-aware: %.2f – %.2f (median %.2f)\n", minimum(getfield.(ok, :ratio)), maximum(getfield.(ok, :ratio)), median(getfield.(ok, :ratio)))
        end
        println(io)
        println(io, "## Disposition")
        println(io)
        println(io, "- Original campaign CSVs untouched; addendum columns in lift_tension_retrospective.csv.")
        println(io, "- The redo (run_v13_5kw_masslift.jl) applies the constant mass-aware tension instead.")
    end

    @printf("length %.1f m: winner m=%.2f kg  T_mass=%.1f N  T_rotary=%.1f N  ratio=%.2f×\n",
        L, w_m, w_Tm, w_Tr, w_Tr / w_Tm)
end

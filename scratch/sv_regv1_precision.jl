#!/usr/bin/env julia --project=.
# sv_regv1_precision.jl — register v1 sign-off support: full-precision cold
# re-eval of the three bankderate2 winners against the recorded values.
# Same call path as scripts/probe_rapid_vs_ode_winners.jl (:cold leg).
# Prints full-precision re-eval values beside the stored strings and the
# per-field rounding verdict at the stored precision.
# Usage (from repo root): bash scripts/ktd-julia --compiled-modules=existing scratch/sv_regv1_precision.jl
using KiteTurbineDynamics, Printf, DelimitedFiles
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))

const KW = 5.0
const PW = KW * 1000.0
const V_RATED = 11.0
const WINDOW_S = 40.0
const ROOT = normpath(joinpath(@__DIR__, ".."))
const RESULTS = joinpath(ROOT, "scripts", "results", "v13_5kw_masslift_len18.8_rotorcount_bankderate2")

lift_for(sys, p) = KiteTurbineDynamics.sized_lifter_for(
    sys, p; margin=1.5, v_ref=V_RATED, const_tension=true)

function params_at_length(L::Float64)
    p2 = params_daisy()
    geo = GeometrySpec(p2.elevation_angle, p2.lifter_elevation, p2.rotor_radius,
        L, p2.trpt_hub_radius, p2.trpt_rL_ratio, p2.n_lines, p2.n_rings, p2.n_blades)
    mat = MaterialSpec(p2.tether_diameter, p2.e_modulus, p2.m_ring, p2.m_blade)
    aero = AeroSpec(p2.rho, p2.v_wind_ref, p2.h_ref, p2.cp)
    ctrl = ControlSpec(p2.i_pto, p2.k_mppt, p2.p_rated_w, p2.β_min, p2.β_max, p2.β_rate_max, p2.kp_elev)
    back = BackLineSpec(p2.EA_back_line, p2.c_back_line, p2.back_anchor_fwd_x, p2.backline_payout)
    scaled = mass_scale(SystemParams(geo, mat, aero, ctrl, back), 1.5, KW)
    return override_params(scaled; tether_length=L)
end

function decimals(s::AbstractString)
    i = findlast('.', s)
    i === nothing && return 0
    return length(s) - i
end

function main()
    p_base = params_at_length(18.8)
    cfg = ObjectiveConfig(;
        power_W = PW, v_rated = V_RATED,
        p_floor_kw = 5.0, p_ceiling_kw = 5.0,
        relax_s = 10.0, window_s = WINDOW_S,
        fos_target = 2.5, fos_hard = 2.5,
        power_stat = :tail5, penalize_ceiling = false,
        kickstart_s = 0.0,
        k_mppt = K_MPPT_5KW_HONEST,
        tether_diameter = p_base.tether_diameter,
        rotor_count_mode = true,
        blocking_factor = BLOCKING_WIND_FACTOR_5KW,
    )

    for island in 1:3
        rows = readdlm(joinpath(RESULTS, "island_$island/telemetry.csv"), ',', String;
                       comments=true, skipstart=1)
        hdr = vec(rows[1, :])
        data = rows[2:end, :]
        ci = Dict(nm => i for (i, nm) in enumerate(hdr))
        ok = [r for r in eachrow(data) if r[ci["status"]] == "ok"]
        best = reduce((a, b) -> parse(Float64, a[ci["fitness"]]) <= parse(Float64, b[ci["fitness"]]) ? a : b, ok)

        v = vec(readdlm(joinpath(RESULTS, "island_$island/best_vector.csv"), ',', Float64))
        r = KiteTurbineDynamics.evaluate_windowed(
            v, PROFILE_ELLIPTICAL, p_base, cfg;
            start_mode = :cold,
            lift_device = lift_for,
            fitness_fn = (P, F, c, m) -> KiteTurbineDynamics.appropriate_mass_fitness(P, F, c, m),
        )

        println("=== island $island (gen $(best[ci["gen"]]), ok rows $((length(ok)))) ===")
        for (name, reeval) in (("P_mean", r.P_mean), ("P_end", r.P_end), ("FoS", r.FoS_min),
                               ("fitness", r.fitness), ("T_lift", r.T_lift))
            stored = best[ci[name]]
            rv = parse(Float64, stored)
            dec = decimals(stored)
            okround = dec > 0 ? (round(reeval, digits=dec) == rv) : false
            @printf("  %-8s stored=%-10s reeval=%.17g  delta=%+.6e  round(%d)-match=%s\n",
                name, stored, reeval, reeval - rv, dec, okround)
        end
        @printf("  omega_eq=%.17g  status=%s  broken=%s\n", r.ω_eq, r.status, r.line_broken)
        flush(stdout)
    end
end

main()

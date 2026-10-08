#!/usr/bin/env julia --project=.
# probe_rapid_vs_ode_winners.jl — accuracy band between the two evaluation
# paths on the bankderate2 island winners:
#   :warm = rapid path (static pre-solve via size_beams_closed_form, R7)
#   :cold = ODE path (settle + kickstart) — what the campaign recorded
# Prints both modes side by side against the recorded telemetry values.
# This is the first probe of the evaluation-fidelity band (Rod 2026-10-08);
# extend to a pool sample for the report's band chart.
#
# Usage: julia --project=. scripts/probe_rapid_vs_ode_winners.jl
using KiteTurbineDynamics, Printf, DelimitedFiles
include(joinpath(@__DIR__, "compute_seeds.jl"))

const KW = 5.0
const PW = KW * 1000.0
const V_RATED = 11.0
const WINDOW_S = 40.0
const RESULTS = joinpath(@__DIR__, "results/v13_5kw_masslift_len18.8_rotorcount_bankderate2")

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

function recorded_row(island::Int)
    # telemetry line 1 is a '#' provenance comment; line 2 is the header.
    rows = readdlm(joinpath(RESULTS, "island_$island/telemetry.csv"), ',', String;
                   comments=true, skipstart=1)
    hdr = vec(rows[1, :])
    data = rows[2:end, :]
    ci = Dict(nm => i for (i, nm) in enumerate(hdr))
    ok = [r for r in eachrow(data) if r[ci["status"]] == "ok"]
    best = reduce((a, b) -> parse(Float64, a[ci["fitness"]]) <= parse(Float64, b[ci["fitness"]]) ? a : b, ok)
    return best, ci
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

    println("mode | island | P_mean kW | P_end kW | FoS_min | fitness kg | T_lift N | omega_eq | status")
    println("----------------------------------------------------------------------------------------")
    for island in 1:3
        best, ci = recorded_row(island)
        v = vec(readdlm(joinpath(RESULTS, "island_$island/best_vector.csv"), ',', Float64))
        for mode in (:warm, :cold)
            t0 = time()
            r = KiteTurbineDynamics.evaluate_windowed(
                v, PROFILE_ELLIPTICAL, p_base, cfg;
                start_mode = mode,
                lift_device = lift_for,
                fitness_fn = (P, F, c, m) -> KiteTurbineDynamics.appropriate_mass_fitness(P, F, c, m),
            )
            @printf("%-5s | %3d     | %8.3f | %8.3f | %7.3f | %10.3f | %7.1f | %8.3f | %6.1fs | twist=%4.2f broken=%s | %s\n",
                mode, island, r.P_mean, r.P_end, r.FoS_min, r.fitness, r.T_lift, r.ω_eq,
                time() - t0, r.twist_ratio, r.line_broken, r.status)
            flush(stdout)
        end
        @printf("rec  | %3d     | %8.3f | %8.3f | %7.3f | %10.3f | %7.1f | ok\n",
            island,
            parse(Float64, best[ci["P_mean"]]), parse(Float64, best[ci["P_end"]]),
            parse(Float64, best[ci["FoS"]]), parse(Float64, best[ci["fitness"]]),
            parse(Float64, best[ci["T_lift"]]))
    end
end

main()

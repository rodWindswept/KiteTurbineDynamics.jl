#!/usr/bin/env julia --project=.
# probe_window_trace.jl — §1.1 window-mean trace read (aero-validator seat).
#
# WHY: the pair extract (scripts/extract_pair_capture.jl) captured 52 tap
# samples of the winner measurement run and kept only the final step.  The
# review's section 1.1 asks for the window-mean ground-ring speed as the
# operating speed; the lead check of 2026-10-11 lists the row as pending on
# one trace read.  This script repeats the extract's exact evaluation and
# keeps the samples (t, ω_hub, ω_gnd) — parity-certified against the
# recorded cold re-eval (scratch/sv_p0_winner_reeval.txt).
#
# PATH   evaluate_windowed :cold — the recorded cold re-eval basis (NR-012),
#        same genome, same frozen ObjectiveConfig as the extract.
# USAGE  scripts/ktd-julia scripts/probe_window_trace.jl
# WRITES stdout only; the committed-run log sits at
#        .julia_depot/logs/av_probe_window_trace.log (local-only evidence).
using KiteTurbineDynamics
include(joinpath(@__DIR__, "compute_seeds.jl"))

const KW = 5.0
const PW = KW * 1000.0
const V_RATED = 11.0
const WINDOW_S = 40.0
const RELAX_S = 10.0
const MIN_WALL_M = 2.0e-3
const LENGTH = 18.8

const REPO = dirname(@__DIR__)
const WINNER = joinpath(REPO, "scripts", "results",
    "v13_5kw_masslift_len18.8_rotorcount_bankderate2", "island_3", "best_vector.csv")

const EXPECTED = Dict{Symbol,Float64}(
    :fitness => 27.3635412663488,
    :P_mean => 5.3087794439367935,
    :P_end => 5.314113662272673,
    :ω_eq => 10.169820334285198,
)

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

function main()
    x = [parse(Float64, tok) for tok in split(strip(read(WINNER, String)), ",")]
    xr = copy(x)
    xr[4] = Float64(round(Int, clamp(xr[4], 3, 16)))
    xr[6] = Float64(round(Int, clamp(xr[6], 1, 3)))

    p_base = params_at_length(LENGTH)
    cfg = ObjectiveConfig(;
        power_W=PW, v_rated=V_RATED,
        p_floor_kw=5.0, p_ceiling_kw=5.0,
        relax_s=RELAX_S, window_s=WINDOW_S,
        fos_target=2.5, fos_hard=2.5,
        power_stat=:tail5, penalize_ceiling=false,
        kickstart_s=0.0,
        k_mppt=K_MPPT_5KW_HONEST,
        tether_diameter=p_base.tether_diameter,
        rotor_count_mode=true,
        power_split=0.6,
        cone_slope_deg=22.0,
        rotor_spacing_frac=0.8,
        blocking_factor=BLOCKING_WIND_FACTOR_5KW,
        min_wall_m=MIN_WALL_M,
    )

    total_n_r = Ref(-1); dt_r = Ref(NaN)
    idx = Ref{Any}(nothing)
    samples = NamedTuple{(:t, :s, :wh, :wg),Tuple{Float64,Int,Float64,Float64}}[]
    function tap(uc, tc, s, ctx)
        if total_n_r[] < 0
            dt_r[] = KiteTurbineDynamics.stable_dt_for_system(ctx.sys, ctx.pc)
            total_n_r[] = round(Int, (RELAX_S + WINDOW_S) / dt_r[])
            sys = ctx.sys
            N = sys.n_total; Nr = sys.n_ring
            hub_ri = sys.nodes[sys.rotor.node_id].ring_idx
            gnd_ri = sys.nodes[sys.ring_ids[1]].ring_idx
            idx[] = (N, Nr, hub_ri, gnd_ri)
            println("tap first call: s=", s, " t=", tc, " | dt=", dt_r[], " total_n=", total_n_r[])
        end
        if s == total_n_r[] || tc - (isempty(samples) ? -Inf : samples[end].t) >= 0.999
            N, Nr, hub_ri, gnd_ri = idx[]
            wh = uc[6N + Nr + hub_ri]
            wg = uc[6N + Nr + gnd_ri]
            push!(samples, (; t=tc, s=s, wh=wh, wg=wg))
        end
    end

    t0 = time()
    r = KiteTurbineDynamics.evaluate_windowed(
        xr, PROFILE_ELLIPTICAL, p_base, cfg;
        start_mode=:cold,
        lift_device=lift_for,
        trace_callback=tap,
        fitness_fn=(P, F, c, m) -> KiteTurbineDynamics.appropriate_mass_fitness(P, F, c, m),
    )
    println("eval wall = ", round(time() - t0, digits=1), " s")

    println("\n== parity vs recorded cold re-eval ==")
    for f in (:fitness, :P_mean, :P_end, :ω_eq)
        got = getfield(r, f); ex = EXPECTED[f]; d = abs(got - ex)
        println("  ", f, " got=", got, " expected=", ex, " |diff|=", d,
            " ", d == 0.0 ? "EXACT" : "CHECK")
    end

    println("\n== trace: ", length(samples), " samples ==")
    println("t_s | s | omega_hub | omega_gnd")
    for sm in samples
        println(sm.t, " | ", sm.s, " | ", sm.wh, " | ", sm.wg)
    end

    win = [sm for sm in samples if sm.t >= RELAX_S]
    rel = [sm for sm in samples if sm.t < RELAX_S]
    whs = [sm.wh for sm in win]; wgs = [sm.wg for sm in win]
    mh = sum(whs) / length(whs); mg = sum(wgs) / length(wgs)
    println("\n== window stats (t >= ", RELAX_S, " s; n=", length(win), " of ",
        length(samples), ") ==")
    println("window-mean omega_hub = ", mh)
    println("window-mean omega_gnd = ", mg)
    println("hub min/max/last = ", minimum(whs), " / ", maximum(whs), " / ", whs[end])
    println("gnd min/max/last = ", minimum(wgs), " / ", maximum(wgs), " / ", wgs[end])
    println("relax samples n=", length(rel), "  hub first..last = ", rel[1].wh, " .. ", rel[end].wh)

    r_ring = 4.57997905482005
    v_ref = 11.01
    println("\nlambda(window-mean hub) = ", mh * r_ring / v_ref)
    println("lambda(window-mean gnd) = ", mg * r_ring / v_ref)
    println("lambda(last hub) = ", whs[end] * r_ring / v_ref)
    println("tau=k*w^2 at window-mean hub (k=2.24) = ", 2.24 * mh^2)
    println("P=k*w^3 at window-mean hub (k=2.24) = ", 2.24 * mh^3 / 1000.0, " kW")
end

main()

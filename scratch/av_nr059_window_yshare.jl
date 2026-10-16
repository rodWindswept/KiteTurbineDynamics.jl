# scratch/av_nr059_window_yshare.jl — aero-validator, 2026-10-16
#
# COUNTER-READ INSTRUMENT for NR-059 (the signed winner bow row, science seat).
#
# The signed block carries the direction line "The sideways share stays under
# 0.003". The committed read log prints the sideways share for the extension
# series only (hub_y_share, t=55..195). This instrument measures the sideways
# fraction through the relax phase and the scored window.
#
# RUN-1 HISTORY (recorded, not tidied): the first form of this instrument
# omitted phase 1 and the diagnostic callback work. Its omega_end read
# 13.3848246684021 against the committed 13.3848247171139 (a 4.9e-8 last-bit
# path difference over the 5.17e6-step window), and the self-check refused the
# run. Kept at scratch/av_nr059_window_yshare_run1_refused.log. This form is a
# near-exact clone of scratch/av_bow_probe.jl phases 1 to 3 (same call order;
# the y-reads are appended inside the callback and read only). Phase 4 is
# dropped: it runs after the window and cannot affect it.
#
# SELF-CHECK (hard gates; the instrument refuses to report on any fail):
#   phase 1 + phase 3 bench gates all true;
#   relax hub perp t=10 = 0.19272 (5e-6) ; window hub perp t=50 = 0.61302 (5e-6);
#   40 window samples; omega_end within 1e-6 of 13.3848247171139 (exact-match
#   flag printed beside it).
#
# This file changes NOTHING in the committed probe or its log.
#
# USAGE: scripts/ktd-julia scratch/av_nr059_window_yshare.jl

using KiteTurbineDynamics, LinearAlgebra, Printf
const KTD = KiteTurbineDynamics
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))

const KW = 5.0
const PW = KW * 1000.0
const V_RATED = 11.0
const LENGTH = 18.8
const MIN_WALL_M = 2.0e-3
const CSV = joinpath(
    @__DIR__, "..", "scripts", "results",
    "v13_5kw_masslift_len18.8_rotorcount_bankderate2", "best_vector.csv",
)

# recorded bench values (sv_p0_secondread_winner_reeval.log, NR-016 bench)
const REC_FITNESS = 27.3635412663488
const REC_OMEGA_EQ = 10.169820334285198
const REC_P_END = 5.314113662272673
const REC_TWIST = 0.4393474253185575
const REC_FOS = 14.971791422208508
const REC_OMEGA_END = 13.3848247171139

lift_for(sys, p) = KTD.sized_lifter_for(sys, p; margin=1.5, v_ref=V_RATED, const_tension=true)

function params_at_length(L::Float64)
    p2 = params_daisy()
    geo = GeometrySpec(
        p2.elevation_angle, p2.lifter_elevation, p2.rotor_radius,
        L, p2.trpt_hub_radius, p2.trpt_rL_ratio, p2.n_lines, p2.n_rings, p2.n_blades,
    )
    mat = MaterialSpec(p2.tether_diameter, p2.e_modulus, p2.m_ring, p2.m_blade)
    aero = AeroSpec(p2.rho, p2.v_wind_ref, p2.h_ref, p2.cp)
    ctrl = ControlSpec(p2.i_pto, p2.k_mppt, p2.p_rated_w, p2.β_min, p2.β_max, p2.β_rate_max, p2.kp_elev)
    back = BackLineSpec(p2.EA_back_line, p2.c_back_line, p2.back_anchor_fwd_x, p2.backline_payout)
    scaled = mass_scale(SystemParams(geo, mat, aero, ctrl, back), 1.5, KW)
    return override_params(scaled; tether_length=L)
end

function main()
    git = strip(read(`git rev-parse --short HEAD`, String))
    println("=== av_nr059_window_yshare.jl   git=", git, " ===")
    p = params_at_length(LENGTH)
    x = [parse(Float64, s) for s in split(strip(read(CSV, String)), ",")]
    xr = copy(x)
    xr[4] = Float64(round(Int, clamp(xr[4], 3, 16)))
    xr[6] = Float64(round(Int, clamp(xr[6], 1, 3)))

    cfg = KTD.ObjectiveConfig(;
        power_W=PW, v_rated=V_RATED,
        p_floor_kw=5.0, p_ceiling_kw=5.0,
        relax_s=10.0, window_s=40.0,
        fos_target=2.5, fos_hard=2.5,
        power_stat=:tail5, penalize_ceiling=false,
        kickstart_s=0.0,
        k_mppt=K_MPPT_5KW_HONEST,
        tether_diameter=p.tether_diameter,
        rotor_count_mode=true,
        power_split=0.6,
        cone_slope_deg=22.0,
        rotor_spacing_frac=0.8,
        blocking_factor=BLOCKING_WIND_FACTOR_5KW,
        min_wall_m=MIN_WALL_M,
    )

    # ── PHASE 1: the evaluator itself (same call as the committed probe) ────
    println("\n── phase 1: evaluate_windowed (cold) — the re-eval bench at this tip ──")
    t1 = time()
    r = KTD.evaluate_windowed(
        xr, PROFILE_ELLIPTICAL, p, cfg;
        start_mode=:cold,
        lift_device=lift_for,
        fitness_fn=(P, F, c, m) -> KTD.appropriate_mass_fitness(P, F, c, m),
    )
    println("  eval wall = ", round(time() - t1, digits=1), " s")
    g_fit = abs(r.fitness - REC_FITNESS) < 1e-9
    g_w = abs(r.ω_eq - REC_OMEGA_EQ) < 1e-9
    g_p = abs(r.P_end - REC_P_END) < 1e-9
    g_tw = abs(r.twist_ratio - REC_TWIST) < 1e-9
    g_fos = abs(r.FoS_min - REC_FOS) < 1e-9
    @printf(
        "  bench gates vs recorded: fitness %s (%.13f)  omega_eq %s  P_end %s  twist %s  FoS %s\n",
        g_fit, r.fitness, g_w, g_p, g_tw, g_fos,
    )
    gates1 = g_fit && g_w && g_p && g_tw && g_fos

    # ── PHASE 2: instrumented replication, same cold path by hand ───────────
    println("\n── phase 2: instrumented pass (manual cold path + geometry tap) ──")
    x_canon = KTD.canonical_v10(xr)
    dec = KTD.design_from_vector_v10(
        x_canon, PROFILE_ELLIPTICAL, p;
        power_W=cfg.power_W, v_rated=cfg.v_rated, cylinder_cone=true,
        rotor_count_mode=cfg.rotor_count_mode, power_split=cfg.power_split,
        cone_slope_deg=cfg.cone_slope_deg, rotor_spacing_frac=cfg.rotor_spacing_frac,
        blocking_factor=cfg.blocking_factor, beam_t_over_D=cfg.t_over_D,
    )
    sizing = KTD.size_beams_closed_form(dec, p, cfg)
    k_mppt = clamp(cfg.k_mppt, 0.01, KTD.K_MPPT_MAX)
    sys, u0, pc = KTD.build_system_from_v10(
        dec, 1.0, k_mppt;
        tether_diameter=cfg.tether_diameter, base_params=p,
        min_wall_m=cfg.min_wall_m, beam_sizing=sizing,
    )
    dt = KTD.stable_dt_for_system(sys, pc)
    lift_dev = lift_for(sys, pc)
    wf = (pos, t) -> [KTD.wind_at_altitude(p.v_wind_ref, p.h_ref, max(pos[3], 1.0)), 0.0, 0.0]
    N, Nr = sys.n_total, sys.n_ring
    @assert Nr == 6 "counter-read instrument expects the 6-ring winner"

    t2 = time()
    u = KTD.settle_to_operational_state(sys, copy(u0), pc, 60.0; wind_fn=wf, lift_device=lift_dev)
    ω_settle = u[6 * N + Nr + 1]
    @printf("  settle wall = %.1f s   omega_settle = %.15f   (recorded %.15f)\n",
        time() - t2, ω_settle, REC_OMEGA_EQ)

    sd = [cos(p.elevation_angle), 0.0, sin(p.elevation_angle)]
    ring_gids = [sys.ring_ids[ri] for ri in 1:Nr]
    posof(uu, gid) = uu[(3 * (gid - 1) + 1):(3 * gid)]

    # nested-function locals carry distinct names (the committed probe's scope note)
    function bow_table(uu)
        centr_ = [posof(uu, g) for g in ring_gids]
        sax_ = [dot(c, sd) for c in centr_]
        vels_ = [c - dot(c, sd) * sd for c in centr_]
        perp_ = [norm(v) for v in vels_]
        return sax_, vels_, perp_
    end

    # ── PHASE 3: the measurement window, sampled as the evaluator samples ───
    println("\n── phase 3: measurement window (relax ", cfg.relax_s, " s + window ", cfg.window_s, " s) ──")
    relax_s = cfg.relax_s
    total_n = round(Int, (cfg.relax_s + cfg.window_s) / dt)
    sample_interval = round(Int, 1.0 / dt)
    ts = Float64[]; omegas = Float64[]; Ps = Float64[]; tws = Float64[]; foss = Float64[]
    win_perps = Vector{Vector{Float64}}()
    relax_ts = Float64[]; relax_perp6 = Float64[]
    relax_huby = Float64[]
    win_huby = Float64[]; win_midy = Float64[]
    relax_every = round(Int, 2.0 / dt)
    # nested-function locals (tcum/hc_/prx_/vvec_/trx_/efx_/fok_) are unique names;
    # the y-reads (hy_/my_) are appended after the probe's call order and read only.
    cb = function (uc, tc, s)
        tcum = s * dt
        if tcum <= relax_s && (s == 1 || s % relax_every == 0)
            hc_ = posof(uc, ring_gids[Nr])
            hy_ = norm(hc_ - dot(hc_, sd) * sd) > 1e-12 ? (hc_ - dot(hc_, sd) * sd)[2] / norm(hc_ - dot(hc_, sd) * sd) : 0.0
            push!(relax_ts, tcum)
            push!(relax_perp6, norm(hc_ - dot(hc_, sd) * sd))
            push!(relax_huby, hy_)
        end
        if tcum > relax_s && s % sample_interval == 0
            _, vvec_, prx_ = bow_table(uc)
            trx_ = KTD.twist_collapse_check(uc, sys)
            efx_ = KTD.capture_extended(uc, sys, pc, tc, wf, lift_dev; brake_engaged=sys.brake_engaged[])
            fok_, _ = KTD.min_airborne_fos(efx_.ring_fos)
            push!(ts, tcum); push!(omegas, uc[6 * N + Nr + 1])
            push!(Ps, efx_.base.P_kw); push!(tws, trx_.max_ratio); push!(foss, fok_)
            push!(win_perps, prx_)
            push!(win_huby, vvec_[Nr][2] / max(norm(vvec_[Nr]), 1e-12))
            push!(win_midy, vvec_[5][2] / max(norm(vvec_[5]), 1e-12))
        end
    end
    t3 = time()
    KTD.run_canonical_sim!(
        u, sys, pc, wf, total_n, dt;
        lift_device=lift_dev, lin_damp=0.05, spoke=nothing,
        callback=cb, breaks_enabled=true, breaks_arm_s=cfg.relax_s,
    )
    println("  window wall = ", round(time() - t3, digits=1), " s   samples = ", length(ts),
        "   any_broken = ", sys.any_broken[])
    n = length(ts)

    # manual pass bench gates (must reproduce phase 1 / recorded values)
    P_end_m = sum(Ps[(end - 4):end]) / 5
    tw_m = maximum(tws)
    fos_m = minimum(foss)
    w_m = omegas[end]
    @printf("  manual bench: P_end %.13f  twist %.13f  FoS %.13f  omega_end %.13f\n",
        P_end_m, tw_m, fos_m, w_m)
    g2_p = abs(P_end_m - r.P_end) < 1e-9
    g2_tw = abs(tw_m - r.twist_ratio) < 1e-9
    g2_fos = abs(fos_m - r.FoS_min) < 1e-9
    g2_w = abs(ω_settle - r.ω_eq) < 1e-9
    @printf("  protocol gates vs phase 1: settle-omega %s  P_end %s  twist %s  FoS %s\n",
        g2_w, g2_p, g2_tw, g2_fos)
    gates2 = g2_w && g2_p && g2_tw && g2_fos

    d_omega_end = abs(w_m - REC_OMEGA_END)
    @printf("  omega_end vs committed: |delta| = %.3e   exact match = %s\n",
        d_omega_end, d_omega_end < 1e-12)

    # window perp series (same prints as the committed probe)
    println("  window ring6 series: ", [round(win_perps[i][Nr], digits=5) for i in 1:n])
    println("  window ring5 series: ", [round(win_perps[i][5], digits=5) for i in 1:n])

    # ── self-check before any y-report ───────────────────────────────────────
    ok_anchor = gates1 && gates2 &&
        abs(relax_perp6[end] - 0.19272) < 5e-6 &&
        abs(win_perps[end][Nr] - 0.61302) < 5e-6 &&
        n == 40 && d_omega_end < 1e-6
    @printf("  anchors: samples %d ; relax hub perp t=10 %.5f ; window hub perp t=50 %.5f ; omega_end %.13f\n",
        n, relax_perp6[end], win_perps[end][Nr], w_m)
    println("  ANCHORS_OK = ", ok_anchor)
    ok_anchor || error("counter-read instrument does not reproduce the committed anchors; refusing to report")

    println("\n── relax-phase hub sideways fraction (t, perp, y_frac) ──")
    for i in 1:length(relax_ts)
        @printf("  t=%4.1f  perp=%.5f  y_frac=%+.5f\n", relax_ts[i], relax_perp6[i], relax_huby[i])
    end

    println("\n── window sideways fraction series (t=11..50, 40 samples) ──")
    println("  hub_y: ", [round(v, digits=5) for v in win_huby])
    println("  mid_y: ", [round(v, digits=5) for v in win_midy])
    maxhy = maximum(abs.(win_huby))
    maxmy = maximum(abs.(win_midy))
    @printf("\nWINDOW |y_frac| max: hub %.5f ; mid %.5f  (n=%d)\n", maxhy, maxmy, n)
    @printf("WHOLE-RUN direction bound: window max %.5f plus extension max 0.00217 (committed log) under 0.003 = %s\n",
        max(maxhy, maxmy), max(maxhy, maxmy) < 0.003)
    println("WINDOW_YSHARE_DONE")
end

main()

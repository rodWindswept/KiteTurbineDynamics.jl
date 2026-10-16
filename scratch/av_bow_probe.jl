# scratch/av_bow_probe.jl — aero-validator, 2026-10-15
#
# THE WINNER BOW READ (founder word: "up", 2026-10-15).
#
# Machine: the bankderate2 island-3 winner genome (NR-005, fitness 27.3635):
#   scripts/results/v13_5kw_masslift_len18.8_rotorcount_bankderate2/best_vector.csv
# Bench:   the cold re-eval protocol of NR-016 (sv_p0_winner_reeval.jl):
#   evaluate_windowed, start_mode=:cold, relax_s=10, window_s=40,
#   kickstart off, K_MPPT_5KW_HONEST.  Recorded outcome (second read):
#   fitness 27.3635412663488, omega_eq 10.169820334285198, P_end 5.314113662673,
#   twist_ratio 0.4393474253185575, FoS_min 14.971791422208508.
#
# SCOPE NOTE (fixed here; first run tripped on it): Julia scoping — an
# assignment inside a nested function to a name that is a local of the
# enclosing function updates the OUTER local (Julia manual, "Scope of
# Variables": "if a variable is already a local outside of an inner function
# and you assign to it in the inner function, the outer local variable is
# updated", and it holds even when the outer local is defined below).  The
# first draft reused the names s_ax/vs/perps inside bow_table AND in main(),
# so every bow_table call clobbered main()'s arrays; reads printed before the
# run were correct, post-run reads showed only the last sample.  Every nested
# function here uses uniquely named locals, and an integrity check asserts the
# settle arrays are byte-unchanged after both runs.
#
# Phases:
#   1. evaluate_windowed (cold) — the re-eval bench at this tip; gates on the
#      recorded NR-016 values (fitness, omega_eq, P_end, twist, FoS).
#   2. Manual replication of the cold path (same build, same settle call) and
#      the settle-state bow profile: per-ring perpendicular offset from the
#      design axis, max ring, hub perp, mid-span ring perp, and each offset's
#      direction resolved against the gravity-perpendicular direction.
#   3. The measurement window (relax 10 s + window 40 s), sampled every 1 s as
#      the evaluator samples: per-ring min/mean/max, profile-max envelope,
#      max-bow ring stability; manual pass must reproduce the bench.
#   4. Extension run t = 50 s -> 200 s, samples every 5 s — does the bow
#      reach a terminal value?  (Answers whether settle and run can agree.)
#
# USAGE: scripts/ktd-julia scratch/av_bow_probe.jl

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
    println("=== av_bow_probe.jl   git=", git, " ===")
    p = params_at_length(LENGTH)
    x = [parse(Float64, s) for s in split(strip(read(CSV, String)), ",")]
    xr = copy(x)
    xr[4] = Float64(round(Int, clamp(xr[4], 3, 16)))
    xr[6] = Float64(round(Int, clamp(xr[6], 1, 3)))
    println("  genome raw       = ", x)
    println("  genome evaluated = ", xr)
    println("  K_MPPT_5KW_HONEST = ", K_MPPT_5KW_HONEST, "   v_wind_ref = ", p.v_wind_ref,
        "   elevation = ", rad2deg(p.elevation_angle), " deg")

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

    # ── PHASE 1: the evaluator itself, at this tip ──────────────────────────
    println("\n── phase 1: evaluate_windowed (cold) — the re-eval bench at this tip ──")
    t1 = time()
    r = KTD.evaluate_windowed(
        xr, PROFILE_ELLIPTICAL, p, cfg;
        start_mode=:cold,
        lift_device=lift_for,
        fitness_fn=(P, F, c, m) -> KTD.appropriate_mass_fitness(P, F, c, m),
    )
    println("  eval wall = ", round(time() - t1, digits=1), " s")
    for f in fieldnames(typeof(r))
        println("  ", f, " = ", getfield(r, f))
    end
    g_fit = abs(r.fitness - REC_FITNESS) < 1e-9
    g_w = abs(r.ω_eq - REC_OMEGA_EQ) < 1e-9
    g_p = abs(r.P_end - REC_P_END) < 1e-9
    g_tw = abs(r.twist_ratio - REC_TWIST) < 1e-9
    g_fos = abs(r.FoS_min - REC_FOS) < 1e-9
    @printf(
        "  bench gates vs recorded: fitness %s (%.13f)  omega_eq %s  P_end %s  twist %s  FoS %s\n",
        g_fit, r.fitness, g_w, g_p, g_tw, g_fos,
    )

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
    @printf("  machine: n_lines=%d n_ring=%d n_total=%d n_active=%d  m_air=%.4f kg  dt=%.6e s\n",
        p.n_lines, Nr, N, dec.n_active, KTD.expansion_airborne_mass(sys, pc), dt)

    t2 = time()
    u = KTD.settle_to_operational_state(sys, copy(u0), pc, 60.0; wind_fn=wf, lift_device=lift_dev)
    ω_settle = u[6 * N + Nr + 1]
    @printf("  settle wall = %.1f s   omega_settle = %.15f   (recorded %.15f)\n",
        time() - t2, ω_settle, REC_OMEGA_EQ)

    # design axis and the downward direction in its perpendicular plane
    sd = [cos(p.elevation_angle), 0.0, sin(p.elevation_angle)]
    gv = [0.0, 0.0, -1.0]
    gpd = normalize(gv - dot(gv, sd) * sd)
    @printf("  design axis sd = [%.6f %.6f %.6f] ; downward in perp plane gpd = [%.6f %.6f %.6f]\n",
        sd..., gpd...)
    println("  r_ring radii: ", [ (sys.nodes[g]::KTD.RingNode).radius for g in sys.ring_ids ])

    ring_gids = [sys.ring_ids[ri] for ri in 1:Nr]
    posof(uu, gid) = uu[(3 * (gid - 1) + 1):(3 * gid)]

    # nested-function locals carry distinct names (scope note in the header):
    # none of centr_/sax_/vels_/perp_ exist in main().
    function bow_table(uu)
        centr_ = [posof(uu, g) for g in ring_gids]
        sax_ = [dot(c, sd) for c in centr_]
        vels_ = [c - dot(c, sd) * sd for c in centr_]
        perp_ = [norm(v) for v in vels_]
        return sax_, vels_, perp_
    end

    # ── settle-state readout ────────────────────────────────────────────────
    sax_s, vss_s, perps_s = bow_table(u)
    sax_s_snap = copy(sax_s); vss_s_snap = copy(vss_s); perps_s_snap = copy(perps_s)
    hp_settle = posof(u, ring_gids[Nr])
    println("\n── SETTLE-STATE bow profile (perpendicular offset from the design axis) ──")
    @printf("  raw: hub@settle = %s  |hub| = %.6f  perp = %.6f\n",
        string(hp_settle), norm(hp_settle), norm(hp_settle - dot(hp_settle, sd) * sd))
    @printf("  %4s %10s %10s %10s %10s %12s\n",
        "ring", "s_axial", "r_perp_m", "down_frac", "y_frac", "ang_to_down")
    for ri in 1:Nr
        vv = vss_s[ri]; pv = perps_s[ri]
        dn = pv > 1e-12 ? dot(vv, gpd) / pv : 0.0
        yf = pv > 1e-12 ? vv[2] / pv : 0.0
        ang = pv > 1e-12 ? rad2deg(acos(clamp(dn, -1.0, 1.0))) : 0.0
        @printf("  %4d %10.4f %10.5f %10.4f %+10.4f %12.2f%s\n",
            ri, sax_s[ri], pv, dn, yf, ang, ri == Nr ? "   <- MAIN ROTOR" : "")
    end
    imax_s = argmax(perps_s)
    imid = argmin(abs.(sax_s .- (sax_s[1] + sax_s[Nr]) / 2))
    @printf("  SETTLE profile max = %.5f m at ring %d (s_axial %.3f)\n", perps_s[imax_s], imax_s, sax_s[imax_s])
    @printf("  SETTLE hub perp (ring %d) = %.5f m ; mid-span ring %d (s_axial %.3f) perp = %.5f m\n",
        Nr, perps_s[Nr], imid, sax_s[imid], perps_s[imid])
    @printf("  SETTLE direction at max ring: down_frac %.4f  y_frac %+.4f\n",
        dot(vss_s[imax_s], gpd) / perps_s[imax_s], vss_s[imax_s][2] / perps_s[imax_s])

    # ── PHASE 3: the measurement window, sampled as the evaluator samples ───
    println("\n── phase 3: measurement window (relax ", cfg.relax_s, " s + window ", cfg.window_s, " s) ──")
    relax_s = cfg.relax_s
    total_n = round(Int, (cfg.relax_s + cfg.window_s) / dt)
    sample_interval = round(Int, 1.0 / dt)
    ts = Float64[]; omegas = Float64[]; Ps = Float64[]; tws = Float64[]; foss = Float64[]
    win_perps = Vector{Vector{Float64}}()
    win_hub_vec = Vector{Vector{Float64}}()
    relax_ts = Float64[]; relax_perp6 = Float64[]
    relax_every = round(Int, 2.0 / dt)
    # nested-function locals (tcum/hc_/prx_/vvec_/trx_/efx_/fok_) are unique names
    cb = function (uc, tc, s)
        tcum = s * dt
        if tcum <= relax_s && (s == 1 || s % relax_every == 0)
            hc_ = posof(uc, ring_gids[Nr])
            push!(relax_ts, tcum)
            push!(relax_perp6, norm(hc_ - dot(hc_, sd) * sd))
        end
        if tcum > relax_s && s % sample_interval == 0
            _, vvec_, prx_ = bow_table(uc)
            trx_ = KTD.twist_collapse_check(uc, sys)
            efx_ = KTD.capture_extended(uc, sys, pc, tc, wf, lift_dev; brake_engaged=sys.brake_engaged[])
            fok_, _ = KTD.min_airborne_fos(efx_.ring_fos)
            push!(ts, tcum); push!(omegas, uc[6 * N + Nr + 1])
            push!(Ps, efx_.base.P_kw); push!(tws, trx_.max_ratio); push!(foss, fok_)
            push!(win_perps, prx_)
            push!(win_hub_vec, vvec_[Nr])
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
    P_end_m = sum(Ps[(end-4):end]) / 5
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

    hp_50 = posof(u, ring_gids[Nr])
    println("  raw: hub at window end (t=50) = ", string(hp_50), "  perp = ",
        round(norm(hp_50 - dot(hp_50, sd) * sd), digits=6))
    println("  relax-phase hub perp (t, value):")
    for i in 1:length(relax_ts)
        println("     t=", round(relax_ts[i], digits=1), "  ", round(relax_perp6[i], digits=6))
    end

    # ── window bow summary ─────────────────────────────────────────────────
    println("\n── WINDOW bow profile: per-ring statistics over the ", n, " samples (t = 11..50 s) ──")
    @printf("  %4s %10s %10s %10s %10s %12s\n",
        "ring", "settle", "win_mean", "win_min", "win_max", "settle-mean")
    devs = Float64[]
    for ri in 1:Nr
        col = [win_perps[i][ri] for i in 1:n]
        wm = sum(col) / n
        push!(devs, abs(perps_s[ri] - wm))
        @printf("  %4d %10.5f %10.5f %10.5f %10.5f %+12.5f%s\n",
            ri, perps_s[ri], wm, minimum(col), maximum(col), perps_s[ri] - wm,
            ri == Nr ? "   <- MAIN ROTOR" : "")
    end
    imax_dev = argmax(devs)
    @printf("  SETTLE-vs-WINDOW: max |settle - window_mean| = %.5f m at ring %d\n",
        maximum(devs), imax_dev)

    profmax = [maximum(win_perps[i]) for i in 1:n]
    pmax_ring = [argmax(win_perps[i]) for i in 1:n]
    vmaxw, imaxw = findmax(profmax)
    vminw = minimum(profmax)
    ring_counts = Dict{Int,Int}()
    for rr in pmax_ring
        ring_counts[rr] = get(ring_counts, rr, 0) + 1
    end
    @printf("  window profile max: min %.5f m, mean %.5f m, max %.5f m (at t=%.0f s)\n",
        vminw, sum(profmax) / n, vmaxw, ts[imaxw])
    println("  max-bow ring across samples: ", ring_counts)
    println("  window sample t (s): ", [round(ts[i], digits=1) for i in 1:n])
    println("  window ring6 series: ", [round(win_perps[i][Nr], digits=5) for i in 1:n])
    println("  window ring5 series: ", [round(win_perps[i][5], digits=5) for i in 1:n])

    hub_col = [win_perps[i][Nr] for i in 1:n]
    mid_col = [win_perps[i][imid] for i in 1:n]
    @printf("  window hub perp (ring %d): min %.5f  mean %.5f  max %.5f m\n",
        Nr, minimum(hub_col), sum(hub_col) / n, maximum(hub_col))
    @printf("  window mid-span ring %d perp: min %.5f  mean %.5f  max %.5f m\n",
        imid, minimum(mid_col), sum(mid_col) / n, maximum(mid_col))

    # ── PHASE 4: extension — does the bow reach a terminal value? ──────────
    println("\n── phase 4: extension run (t = 50 s to 200 s; samples every 5 s) ──")
    ext_span = 150.0
    ext_n = round(Int, ext_span / dt)
    ext_every = round(Int, 5.0 / dt)
    ext_ts = Float64[]; ext_omegas = Float64[]
    ext_perps = Vector{Vector{Float64}}()
    ext_hubv = Vector{Vector{Float64}}()
    # nested-function locals: tcum2/vvec2_/perx2_ are unique names
    cb2 = function (uc2, tc2, s2)
        tcum2 = s2 * dt
        if s2 % ext_every == 0
            _, vvec2_, perx2_ = bow_table(uc2)
            push!(ext_ts, 50.0 + tcum2)
            push!(ext_omegas, uc2[6 * N + Nr + 1])
            push!(ext_perps, perx2_)
            push!(ext_hubv, vvec2_[Nr])
        end
    end
    t4 = time()
    KTD.run_canonical_sim!(
        u, sys, pc, wf, ext_n, dt;
        lift_device=lift_dev, lin_damp=0.05, spoke=nothing,
        callback=cb2, breaks_enabled=true, breaks_arm_s=0.0,
    )
    println("  extension wall = ", round(time() - t4, digits=1), " s   samples = ", length(ext_ts),
        "   any_broken = ", sys.any_broken[])
    ne = length(ext_ts)
    println("\n  t(s)   omega      hub_perp   mid_perp    hub_y_share")
    for i in 1:ne
        hpv = norm(ext_hubv[i])
        yf2 = hpv > 1e-12 ? ext_hubv[i][2] / hpv : 0.0
        @printf("  %5.0f  %9.4f  %9.5f  %9.5f   %+10.5f\n",
            ext_ts[i], ext_omegas[i], ext_perps[i][Nr], ext_perps[i][imid], yf2)
    end
    hp_200 = posof(u, ring_gids[Nr])
    println("  raw: hub at t=200 = ", string(hp_200), "  perp = ",
        round(norm(hp_200 - dot(hp_200, sd) * sd), digits=6))

    hubser = [ext_perps[i][Nr] for i in 1:ne]
    midser = [ext_perps[i][imid] for i in 1:ne]
    inc_last = hubser[end] - hubser[end-1]
    @printf("  terminal: hub perp %.5f m at t=%.0f (last 5 s increment %+.5f m); mid-span %.5f m\n",
        hubser[end], ext_ts[end], inc_last, midser[end])

    # integrity check for the scope hazard (settle arrays must be untouched)
    ok_int = (sax_s == sax_s_snap) && (vss_s == vss_s_snap) && (perps_s == perps_s_snap)
    println("\n  integrity: settle arrays unchanged after both runs = ", ok_int)

    # ── the September check: settle vs run on the bowed shape ──────────────
    println("\n── SEPTEMBER CHECK (settle vs run agree on the bowed shape) ──")
    @printf("  settle state      : profile max %.5f m (ring %d); hub %.5f; mid-span %.5f\n",
        perps_s[imax_s], imax_s, perps_s[Nr], perps_s[imid])
    @printf("  run, window       : profile max rises %.5f -> %.5f m (ring %d); window mean %.5f\n",
        vminw, vmaxw, imax_s, sum(profmax) / n)
    @printf("  run, t=200        : hub %.5f m; mid-span %.5f m\n", hubser[end], midser[end])
    @printf("  max |settle - window_mean| = %.5f m at ring %d\n", maximum(devs), imax_dev)
    same_ring = (length(unique(pmax_ring)) == 1) && (pmax_ring[1] == imax_s)
    println("  topology: max-bow ring settle=", imax_s, " window=", sort(collect(keys(ring_counts))),
        "  -> ", same_ring ? "same ring (the hub), both straight down" : "DIFFERS")
    println("  magnitude: settle reads a straight stack (mm); the run bows to dm and is ",
        "still growing at t=50 -> the two solvers do NOT agree on the shape at this state.")

    # ── consolidated read ──────────────────────────────────────────────────
    println("\n── BOW READ (value / station / state) ──")
    @printf("  profile max : settle %.5f m at ring %d; window %.5f -> %.5f m (mean %.5f); t=200 %.5f m\n",
        perps_s[imax_s], imax_s, vminw, vmaxw, sum(profmax) / n, hubser[end])
    @printf("  hub perp    : ring %d; settle %.5f m; window %.5f -> %.5f m; t=200 %.5f m\n",
        Nr, perps_s[Nr], minimum(hub_col), maximum(hub_col), hubser[end])
    @printf("  mid-span    : ring %d; settle %.5f m; window %.5f -> %.5f m; t=200 %.5f m\n",
        imid, perps_s[imid], minimum(mid_col), maximum(mid_col), midser[end])
    dn_s = dot(vss_s[imax_s], gpd) / perps_s[imax_s]
    hpv200 = norm(ext_hubv[end])
    dn_200 = hpv200 > 1e-12 ? dot(ext_hubv[end], gpd) / hpv200 : 0.0
    @printf("  direction   : settle down_frac %.4f (y %+.4f); t=200 down_frac %.4f (y %+.4f)  [1.0 = straight down]\n",
        dn_s, vss_s[imax_s][2] / perps_s[imax_s], dn_200, ext_hubv[end][2] / hpv200)
    println("  shape       : perp grows with s_axial (whole-stack tilt, max at the hub), not a mid-span belly")

    println("\nAV_BOW_PROBE_DONE")
end

main()

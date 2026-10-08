# extract_pair_capture.jl — mechanism-pair capture extract (aero-validator seat).
#
# WHY: the ring-utilisation and twist-limit plates (report figure map, rows 6-7)
# both read from ONE capture: the winner operating point.  This script produces
# THE extract — one dataset, one run, one declared capture — for F-VALUE.
#
# DATASET   v13_5kw_masslift_len18.8_rotorcount_bankderate2 (data commit dd3cc6a;
#           launch a76c5e9; physics era: post-95c385d_wind-authority).
# PATH      evaluate_windowed :cold — the recorded cold re-eval basis (NR-012).
# CAPTURE   the final integration step of the measurement run (end of the 40 s
#           honest window).
#
# ARRAYS (pair SPECs, "Capture"):
#   rings    — ring_fos / ring_util_axial / ring_util_bending as emitted by
#              capture_extended; max_util re-derived via ring_element_analysis
#              with the A1 identity (axial + bending = max_util) checked.
#   segments — |dalpha| read from the stored alpha block (raw; never the
#              principal-value read); segment twist as emitted; dcrit_deg /
#              has_limit via trpt_twist_limit on the rope_forces C1 gate call
#              pattern; segment_torque as emitted; torque_capacity via
#              trpt_axial_force + trpt_torque_capacity_axial at the same state
#              (Tulloch authority basis; Inf where no limit — NOT the sim's
#              held conservative Case-B cap).
#
# USAGE     scripts/ktd-julia scripts/extract_pair_capture.jl
# WRITES    docs/reporting/figures/pair-extract/extract-winner-operating-point.csv
#           docs/reporting/figures/pair-extract/extract-winner-operating-point.log

using KiteTurbineDynamics, Printf, LinearAlgebra, Dates
include(joinpath(@__DIR__, "compute_seeds.jl"))

const KW = 5.0
const PW = KW * 1000.0
const V_RATED = 11.0
const WINDOW_S = 40.0
const RELAX_S = 10.0
const MIN_WALL_M = 2.0e-3
const GROUND_OFFSET = 1.0
const ELEV = pi / 6
const LENGTH = 18.8

const REPO = dirname(@__DIR__)
const OUTDIR = joinpath(REPO, "docs", "reporting", "figures", "pair-extract")
const WINNER = joinpath(
    REPO, "scripts", "results", "v13_5kw_masslift_len18.8_rotorcount_bankderate2",
    "island_3", "best_vector.csv",
)

# Full-precision cold re-eval values from the recorded re-eval
# (scratch/sv_p0_winner_reeval.txt) — the parity certificate for this run.
const EXPECTED = Dict{Symbol,Float64}(
    :fitness => 27.3635412663488,
    :P_mean => 5.3087794439367935,
    :P_end => 5.314113662272673,
    :FoS_min => 14.971791422208508,
    :util_a => 0.06679174086635262,
    :util_b => 5.334714158942919e-7,
    :T_lift => 324.1250954336462,
    :twist_ratio => 0.4393474253185575,
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

function git_out(args...)
    return strip(read(Cmd(String["git", "-C", REPO, args...]), String))
end

fv(x) = x isa AbstractFloat ? (isnan(x) ? "NaN" : (isinf(x) ? (x > 0 ? "Inf" : "-Inf") : string(x))) : string(x)

function main()
    mkpath(OUTDIR)
    logpath = joinpath(OUTDIR, "extract-winner-operating-point.log")
    csvpath = joinpath(OUTDIR, "extract-winner-operating-point.csv")
    io = open(logpath, "w")
    say(x...) = (println(io, x...); println(x...); flush(io))

    say("pair-extract / extract-winner-operating-point")
    say("generated: ", now())
    say("run-id: pair-extract-2026-10-08-winner-ops")
    say("dataset: v13_5kw_masslift_len18.8_rotorcount_bankderate2 | data commit dd3cc6a | launch a76c5e9")
    say("physics era: post-95c385d_wind-authority")
    say("computing commit: ", git_out("rev-parse", "HEAD"))
    dirt = git_out("status", "--porcelain")
    say("worktree: ", isempty(dirt) ? "clean" : "dirty (other seats' files present; this extract reads only committed src/ + the data commit)")

    total_n_r = Ref(-1)
    dt_r = Ref(NaN)
    ctx_r = Ref{Any}(nothing)
    samples = NamedTuple{(:t, :s, :u),Tuple{Float64,Int,Vector{Float64}}}[]
    function tap(uc, tc, s, ctx)
        if total_n_r[] < 0
            dt_r[] = KiteTurbineDynamics.stable_dt_for_system(ctx.sys, ctx.pc)
            total_n_r[] = round(Int, (RELAX_S + WINDOW_S) / dt_r[])
            ctx_r[] = ctx
            say("tap first call: s=", s, " t=", tc, " | dt=", dt_r[], " total_n=", total_n_r[])
        end
        if s == total_n_r[] || tc - (isempty(samples) ? -Inf : samples[end].t) >= 0.999
            push!(samples, (; t=tc, s=s, u=copy(uc)))
        end
    end

    x = [parse(Float64, tok) for tok in split(strip(read(WINNER, String)), ",")]
    xr = copy(x)
    xr[4] = Float64(round(Int, clamp(xr[4], 3, 16)))
    xr[6] = Float64(round(Int, clamp(xr[6], 1, 3)))
    say("genome (raw)       = ", x)
    say("genome (evaluated) = ", xr)

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

    dec = design_from_vector_v10(xr, PROFILE_ELLIPTICAL, p_base; power_W=PW,
        cylinder_cone=true, rotor_count_mode=true,
        power_split=cfg.power_split, cone_slope_deg=cfg.cone_slope_deg,
        rotor_spacing_frac=cfg.rotor_spacing_frac, blocking_factor=cfg.blocking_factor)
    clearance = KiteTurbineDynamics.lowest_rotor_clearance(
        dec; ground_offset=GROUND_OFFSET, elevation_deg=rad2deg(ELEV))
    say("decoded: n_lines=", dec.design.n_lines, " rings=", dec.n_rings,
        " n_active=", dec.n_active, " r_hub=", dec.design.r_hub, " r_bot=", dec.design.r_bottom)
    say("clearance = ", clearance, " m")

    t0 = time()
    r = KiteTurbineDynamics.evaluate_windowed(
        xr, PROFILE_ELLIPTICAL, p_base, cfg;
        start_mode=:cold,
        lift_device=lift_for,
        trace_callback=tap,
        fitness_fn=(P, F, c, m) -> KiteTurbineDynamics.appropriate_mass_fitness(P, F, c, m),
    )
    say("eval wall = ", round(time() - t0, digits=1), " s")

    say("")
    say("== result fields ==")
    fns = r isa NamedTuple ? collect(keys(r)) : fieldnames(typeof(r))
    for f in fns
        say("  ", f, " = ", getfield(r, f))
    end

    say("")
    say("== parity certificate vs recorded cold re-eval (sv_p0_winner_reeval.txt) ==")
    parity_ok = true
    for f in (:fitness, :P_mean, :P_end, :FoS_min, :util_a, :util_b, :T_lift, :twist_ratio, :ω_eq)
        got = getfield(r, f)
        ex = EXPECTED[f]
        d = abs(got - ex)
        st = d == 0.0 ? "EXACT" : (d <= 1e-9 ? "OK" : "MISMATCH")
        (d == 0.0 || d <= 1e-9) || (parity_ok = false)
        say("  ", rpad(String(f), 12), " got=", got, " expected=", ex, " |diff|=", d, " ", st)
    end
    say("parity: ", parity_ok ? "ALL FIELDS MATCH" : "MISMATCH — INVESTIGATE BEFORE USE")

    say("")
    say("== capture ==")
    say("dt = ", dt_r[], " s | total_n = ", total_n_r[], " steps | relax+window = ", RELAX_S + WINDOW_S, " s")
    say("samples captured: ", length(samples), " (final step + 1 Hz decimation)")
    finalidx = findlast(sm -> sm.s == total_n_r[], samples)
    cap = finalidx === nothing ? samples[end] : samples[finalidx]
    say("capture: s = ", cap.s, ", t = ", cap.t, " s",
        finalidx === nothing ? "  (WARNING: exact final step not found — used last sample)" : "  (final integration step of the measurement run)")

    u = cap.u
    ctx = ctx_r[]
    sys = ctx.sys
    pc = ctx.pc
    wf = ctx.wf
    lift_dev = ctx.lift_device
    N = sys.n_total
    Nr = sys.n_ring
    @assert length(u) == 6 * N + 2 * Nr
    alpha = u[(6 * N + 1):(6 * N + Nr)]

    ef = KiteTurbineDynamics.capture_extended(u, sys, pc, cap.t, wf, lift_dev;
        brake_engaged=sys.brake_engaged[])
    rea = KiteTurbineDynamics.ring_element_analysis(u, alpha, sys, pc, cap.t, wf)
    @assert length(rea) == Nr - 1 == length(ef.ring_fos)
    say("k_mppt_ref at capture = ", sys.k_mppt_ref[])
    say("P at capture = ", ef.base.P_kw, " kW  (vs r.P_end = ", r.P_end, ")")
    # ring stations along the shaft for the ring ticks (cumulative ring-centre
    # separation; R1 = 0 at the ground datum)
    ctr_i(gid) = @view u[(3 * (gid - 1) + 1):(3 * gid)]
    stations = zeros(Nr)
    for ri in 2:Nr
        stations[ri] = stations[ri - 1] + norm(ctr_i(sys.ring_ids[ri]) .- ctr_i(sys.ring_ids[ri - 1]))
    end
    say("ring stations (m, cumulative from R1): ", stations)

    say("")
    say("== ring block (R2..R", Nr, "; hub = R", Nr, ") ==")
    say("ring | station_m | max_util | util_axial | util_bending | resid | ring_fos")
    ring_rows = NamedTuple[]
    for (k, ref) in enumerate(rea)
        rid = "R" * string(k + 1)
        st = stations[k + 1]
        mx = ref.max_util
        ua = ef.ring_util_axial[k]
        ub = ef.ring_util_bending[k]
        resid = (ua + ub) - mx
        fos = ef.ring_fos[k]
        say(rid, " | ", st, " | ", mx, " | ", ua, " | ", ub, " | ", resid, " | ", fos)
        push!(ring_rows, (; id=rid, station=st, is_hub=(k == Nr - 1), max_util=mx, ua=ua, ub=ub, fos=fos))
    end

    say("")
    say("== segment block (S1..S", Nr - 1, ", ground -> hub) ==")
    say("seg | r_a | r_b | l_t | abs_dalpha_deg | twist_deg(emitted) | dcrit_deg | has_limit | tau | capacity | aux: T_sum, L_ax, da_star_deg, ratio, d_touch_deg")
    seg_rows = NamedTuple[]
    for s in 1:(Nr - 1)
        gid_a = sys.ring_ids[s]
        gid_b = sys.ring_ids[s + 1]
        r_a = (sys.nodes[gid_a]::RingNode).radius
        r_b = (sys.nodes[gid_b]::RingNode).radius
        # gate-pattern accumulators, replicated from the rope_forces compute loop
        lr = zeros(pc.n_lines)
        Tsum = 0.0
        for si in eachindex(sys.sub_segs)
            sys.sub_seg_trpt_seg[si] == s || continue
            ss = sys.sub_segs[si]
            lj = ss.end_a.line_idx
            if 1 <= lj <= pc.n_lines
                lr[lj] += ss.length_0
            end
            if ss.end_a.is_ring
                # invert the index formula used by get_segment_tension
                r0 = mod(si - 1, pc.n_lines * KiteTurbineDynamics.ROPE_SUBSEGS)
                j_i = div(r0, KiteTurbineDynamics.ROPE_SUBSEGS) + 1
                sub_i = mod(r0, KiteTurbineDynamics.ROPE_SUBSEGS) + 1
                Tsum += KiteTurbineDynamics.get_segment_tension(u, sys, pc, s, j_i; sub_idx=sub_i)
            end
        end
        l_t = sum(lr) / max(pc.n_lines, 1)
        dang = u[6 * N + s + 1] - u[6 * N + s]
        abs_dalpha_deg = rad2deg(abs(dang))
        lim = KiteTurbineDynamics.trpt_twist_limit(r_a, r_b, l_t)
        pos_a = @view u[(3 * (gid_a - 1) + 1):(3 * gid_a)]
        pos_b = @view u[(3 * (gid_b - 1) + 1):(3 * gid_b)]
        L_ax = norm(pos_b .- pos_a)
        F_ax = KiteTurbineDynamics.trpt_axial_force(max(Tsum, 0.0), l_t, L_ax)
        cap = KiteTurbineDynamics.trpt_torque_capacity_axial(lim, F_ax)
        r_seg = max(r_a, r_b)
        da_star_rad = 2 * asin(min(L_ax / sqrt(2 * (L_ax^2 + 2 * r_seg^2)), 1.0))
        ratio = abs(dang) / max(da_star_rad, 1e-9)
        say("S", s, " | ", r_a, " | ", r_b, " | ", l_t, " | ", abs_dalpha_deg, " | ",
            ef.segment_twist_deg[s], " | ", lim.dcrit_deg, " | ", lim.has_limit, " | ",
            ef.segment_torque[s], " | ", cap, " | T_sum=", Tsum, ", L_ax=", L_ax,
            ", da*=", rad2deg(da_star_rad), ", ratio=", ratio, ", d_touch=", lim.d_touch_deg)
        push!(seg_rows, (; id="S" * string(s), r_a=r_a, r_b=r_b, l_t=l_t,
            has_limit=lim.has_limit, dcrit_deg=lim.dcrit_deg,
            abs_dalpha_deg=abs_dalpha_deg, twist_deg=ef.segment_twist_deg[s],
            tau=ef.segment_torque[s], cap=cap))
    end

    open(csvpath, "w") do cf
        println(cf, "# pair-extract / extract-winner-operating-point.csv")
        println(cf, "# Mechanism-pair capture extract. Generated by scripts/extract_pair_capture.jl.")
        println(cf, "# run-id: pair-extract-2026-10-08-winner-ops")
        println(cf, "# dataset: v13_5kw_masslift_len18.8_rotorcount_bankderate2 | data commit dd3cc6a | launch a76c5e9")
        println(cf, "# physics era: post-95c385d_wind-authority")
        println(cf, "# path: evaluate_windowed :cold (k=2.24, relax 10 s + window 40 s, kickstart 0)")
        println(cf, "# capture: final integration step of the measurement run (s/t in the .log)")
        println(cf, "# ring stations: station_m = cumulative ring-centre separation along the shaft; R1 = 0 at the ground datum")
        println(cf, "# computing commit: ", git_out("rev-parse", "HEAD"))
        println(cf, "# boundaries: |dalpha| raw from the stored alpha block; dcrit/has_limit/capacity on the")
        println(cf, "#   rope_forces C1 gate call pattern (node radii, mean line rest length, ring-attached")
        println(cf, "#   summed line tension). Capacity is the Tulloch authority basis (Inf where no limit),")
        println(cf, "#   not the sim's held conservative Case-B cap. Values become register rows before any")
        println(cf, "#   figure draws them (figure-map rule).")
        println(cf, "block,id,station_m,r_a_m,r_b_m,l_t_m,has_limit,dcrit_deg,abs_dalpha_deg,segment_twist_deg,segment_torque_Nm,torque_capacity_Nm,max_util,util_axial,util_bending,ring_fos,is_hub")
        for sr in seg_rows
            println(cf, join(["segment", sr.id, "", fv(sr.r_a), fv(sr.r_b), fv(sr.l_t),
                string(sr.has_limit), fv(sr.dcrit_deg), fv(sr.abs_dalpha_deg),
                fv(sr.twist_deg), fv(sr.tau), fv(sr.cap), "", "", "", "", ""], ","))
        end
        for rr in ring_rows
            println(cf, join(["ring", rr.id, fv(rr.station), "", "", "", "", "", "", "", "", "",
                fv(rr.max_util), fv(rr.ua), fv(rr.ub), fv(rr.fos),
                rr.is_hub ? "1" : "0"], ","))
        end
    end
    say("")
    say("wrote: ", csvpath)
    say("EXTRACT_DONE")
end
main()

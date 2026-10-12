#!/usr/bin/env julia --project=.
# probe_eval_timeline.jl — F3 evaluation-timeline capture (aero-validator seat).
#
# WHY: the figure-row-4 brief (evaluation timeline; cold and warm paths, relax
# and window) needs ONE 100 Hz trace of the winner's evaluation.  The committed
# 1 Hz probe (scripts/probe_window_trace.jl) misses the warm-start transient
# and carries no P_gen / tau_gen / strain channels.
#
# DATASET   v13_5kw_masslift_len18.8_rotorcount_bankderate2 (data commit dd3cc6a;
#           launch a76c5e9; physics era: post-95c385d_wind-authority).
# PATH      evaluate_windowed :cold and :warm.  The recorded cold re-eval
#           (NR-012) is the parity certificate: fitness / P_mean / P_end /
#           omega_eq must match EXACTLY (|diff| = 0.0), as in probe_window_trace.
# COLUMNS   t, omega_gnd, omega_hub, P_gen_kw, tau_gen_Nm,
#           strain_max_over_break, any_broken    (100 Hz sampling; 0-50 s)
#           P_gen_kw = tau_gen * omega_gnd / 1000  (the scored ef.base.P_kw
#           definition, sim_frame.jl:133; certified against capture_extended
#           at five in-run instants).
#           strain_max_over_break = max over TRPT lines, bridles and the cyan
#           line of path strain / ROPE_BREAK_STRAIN (rope_forces.jl accumulation
#           replicated; the break gate reads the same quantity).
# USAGE     scripts/ktd-julia scripts/probe_eval_timeline.jl
# WRITES    docs/reporting/figures/eval-timeline-extract/extract-eval-timeline-cold.csv
#           docs/reporting/figures/eval-timeline-extract/extract-eval-timeline-warm.csv
using KiteTurbineDynamics, Printf, LinearAlgebra
include(joinpath(@__DIR__, "compute_seeds.jl"))

const KW = 5.0
const PW = KW * 1000.0
const V_RATED = 11.0
const WINDOW_S = 40.0
const RELAX_S = 10.0
const MIN_WALL_M = 2.0e-3
const LENGTH = 18.8

const REPO = dirname(@__DIR__)
const OUTDIR = joinpath(REPO, "docs", "reporting", "figures", "eval-timeline-extract")
const WINNER = joinpath(
    REPO, "scripts", "results", "v13_5kw_masslift_len18.8_rotorcount_bankderate2",
    "island_3", "best_vector.csv",
)

# Full-precision cold re-eval values (NR-012 basis; scratch/sv_p0_winner_reeval.txt)
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
    geo = GeometrySpec(
        p2.elevation_angle, p2.lifter_elevation, p2.rotor_radius,
        L, p2.trpt_hub_radius, p2.trpt_rL_ratio, p2.n_lines, p2.n_rings, p2.n_blades,
    )
    mat = MaterialSpec(p2.tether_diameter, p2.e_modulus, p2.m_ring, p2.m_blade)
    aero = AeroSpec(p2.rho, p2.v_wind_ref, p2.h_ref, p2.cp)
    ctrl = ControlSpec(
        p2.i_pto, p2.k_mppt, p2.p_rated_w, p2.β_min, p2.β_max, p2.β_rate_max, p2.kp_elev,
    )
    back = BackLineSpec(
        p2.EA_back_line, p2.c_back_line, p2.back_anchor_fwd_x, p2.backline_payout,
    )
    scaled = mass_scale(SystemParams(geo, mat, aero, ctrl, back), 1.5, KW)
    return override_params(scaled; tether_length=L)
end

# ── path-strain replication (mirror of the rope_forces.jl accumulation) ──────
# Same helpers the break gate uses (shaft_perp_basis / _tilted_ring_basis /
# attachment_point!); slotting rule copied from rope_forces.jl:506-522.
function endpos!(
    out::Vector{Float64}, se, uc, sys, alpha, pp1_tilt, pp2_tilt,
    perp1_shaft, perp2_shaft, n_lines, hub_ri,
)
    if se.is_ring
        node = sys.nodes[se.node_id]::KiteTurbineDynamics.RingNode
        ri = node.ring_idx
        R = isempty(sys.expansion_rotors) ? node.radius : sys.effective_radii[ri]
        ctr = @view uc[(3 * (se.node_id - 1) + 1):(3 * se.node_id)]
        pp1, pp2 = KiteTurbineDynamics.tilt_applies(ri, hub_ri) ?
            (pp1_tilt, pp2_tilt) : (perp1_shaft, perp2_shaft)
        KiteTurbineDynamics.attachment_point!(
            out, ctr, R, alpha[ri], se.line_idx, n_lines, pp1, pp2,
        )
    else
        out[1] = uc[3 * (se.node_id - 1) + 1]
        out[2] = uc[3 * (se.node_id - 1) + 2]
        out[3] = uc[3 * (se.node_id - 1) + 3]
    end
    return out
end

function strain_state(uc, sys, pc)
    N = sys.n_total
    Nr = sys.n_ring
    n_lines = pc.n_lines
    hub_gid = sys.rotor.node_id
    hub_pos_r = @view uc[(3 * (hub_gid - 1) + 1):(3 * hub_gid)]
    hub_rmag = norm(hub_pos_r)
    shaft_dir = hub_rmag > 0.1 ? collect(hub_pos_r) ./ hub_rmag :
        [cos(pc.elevation_angle), 0.0, sin(pc.elevation_angle)]
    perp1_shaft, perp2_shaft = KiteTurbineDynamics.shaft_perp_basis(shaft_dir)
    hub_ri = (sys.nodes[hub_gid]::KiteTurbineDynamics.RingNode).ring_idx
    pp1_tilt, pp2_tilt = KiteTurbineDynamics._tilted_ring_basis(uc, sys, hub_gid, hub_ri)
    alpha = @view uc[(6N + 1):(6N + Nr)]
    L = zeros(Nr, n_lines)
    L0 = zeros(Nr, n_lines)
    bl = zeros(n_lines)
    bl0 = zeros(n_lines)
    cyan = 0.0
    cyan0 = 0.0
    pa = zeros(3)
    pb = zeros(3)
    bearing_id = sys.bearing_id
    sky_id = sys.sky_anchor_id
    for (si, ss) in enumerate(sys.sub_segs)
        seg = sys.sub_seg_trpt_seg[si]
        endpos!(
            pa, ss.end_a, uc, sys, alpha, pp1_tilt, pp2_tilt,
            perp1_shaft, perp2_shaft, n_lines, hub_ri,
        )
        endpos!(
            pb, ss.end_b, uc, sys, alpha, pp1_tilt, pp2_tilt,
            perp1_shaft, perp2_shaft, n_lines, hub_ri,
        )
        cl = norm(pb .- pa)
        cl < 1e-9 && continue
        lj = ss.end_a.line_idx
        if seg > 0
            if 1 <= seg <= (Nr - 1) && 1 <= lj <= n_lines
                L[seg, lj] += cl
                L0[seg, lj] += ss.length_0
            end
        elseif ss.end_a.node_id == bearing_id
            if 1 <= lj <= n_lines
                bl[lj] += cl
                bl0[lj] += ss.length_0
            end
        elseif (ss.end_a.node_id == bearing_id && ss.end_b.node_id == sky_id) ||
            (ss.end_a.node_id == sky_id && ss.end_b.node_id == bearing_id)
            cyan += cl
            cyan0 += ss.length_0
        end
    end
    s_trpt = 0.0
    for i in eachindex(L0)
        L0[i] > 1e-9 && (s_trpt = max(s_trpt, (L[i] - L0[i]) / L0[i]))
    end
    s_brid = 0.0
    for j in 1:n_lines
        bl0[j] > 1e-9 && (s_brid = max(s_brid, (bl[j] - bl0[j]) / bl0[j]))
    end
    s_cyan = cyan0 > 1e-9 ? (cyan - cyan0) / cyan0 : 0.0
    return (
        peak=max(s_trpt, s_brid, s_cyan), trpt=s_trpt, bridle=s_brid, cyan=s_cyan,
    )
end

function run_trace(xr, p_base, cfg, start_mode::Symbol; dense_start::Bool=false)
    rows_t = Float64[]
    rows_wg = Float64[]
    rows_wh = Float64[]
    rows_P = Float64[]
    rows_tau = Float64[]
    rows_s = Float64[]      # normalized strain (over break)
    rows_s_trpt = Float64[]
    rows_s_brid = Float64[]
    rows_s_cyan = Float64[]
    rows_brk = Int[]
    brk_prev = Ref(false)
    last_row_s = Ref(0)

    total_n_r = Ref(-1)
    dt_r = Ref(NaN)
    stride_r = Ref(0)
    idx = Ref{Any}(nothing)
    kmin = Ref(Inf)
    kmax = Ref(-Inf)
    kfirst = Ref(NaN)
    klast = Ref(NaN)
    strain_err = Ref{Any}(nothing)
    cap_diffs = Tuple{Float64,Float64,Float64}[]   # (t, |dP_kw|, |domega_hub|)
    next_cap = Ref(15.0)
    r24_min = Ref(Inf)
    r24_max = Ref(-Inf)

    function tap(uc, tc, s, ctx)
        sys = ctx.sys
        pc = ctx.pc
        if total_n_r[] < 0
            dt_r[] = KiteTurbineDynamics.stable_dt_for_system(sys, pc)
            stride_r[] = max(1, round(Int, 0.01 / dt_r[]))
            total_n_r[] = round(Int, (RELAX_S + WINDOW_S) / dt_r[])
            N0 = sys.n_total
            Nr0 = sys.n_ring
            hub_ri0 = (sys.nodes[sys.rotor.node_id]::KiteTurbineDynamics.RingNode).ring_idx
            gnd_ri0 = (sys.nodes[sys.ring_ids[1]]::KiteTurbineDynamics.RingNode).ring_idx
            idx[] = (N0, Nr0, hub_ri0, gnd_ri0)
            payout_base = pc.β_min < 5.0 ? 15.0 : pc.β_min
            max_payout = payout_base * (pc.tether_length / 30.0)
            ctrl_mode = round(pc.β_rate_max)
            imu_reliable = pc.kp_elev ≈ 1.0
            println("tap first call: s=", s, " t=", tc, " | dt=", dt_r[],
                " stride=", stride_r[], " total_n=", total_n_r[])
            println("  state layout: N=", N0, " Nr=", Nr0,
                " hub_ri=", hub_ri0, " gnd_ri=", gnd_ri0)
            println("  pc.backline_payout = ", pc.backline_payout,
                "  payout_base = ", payout_base, "  max_payout = ", max_payout,
                "  payout factor = ", max(0.0, 1.0 - pc.backline_payout / max_payout))
            println("  pc.β_min = ", pc.β_min, "  pc.β_rate_max = ", pc.β_rate_max,
                "  -> ctrl_mode = ", ctrl_mode)
            println("  pc.kp_elev = ", pc.kp_elev, "  imu_reliable = ", imu_reliable)
            println("  pc.k_mppt = ", pc.k_mppt, "  pc.p_rated_w = ", pc.p_rated_w,
                "  pc.tether_length = ", pc.tether_length)
            println("  sys.k_mppt_ref[] at first call = ", sys.k_mppt_ref[])
            gl = KiteTurbineDynamics.GENERATOR_LOAD[]
            println("  GENERATOR_LOAD mode = ", gl.mode)
            for f in fieldnames(typeof(gl))
                println("    gl.", f, " = ", getfield(gl, f))
            end
        end
        N, Nr, hub_ri, gnd_ri = idx[]
        wg = uc[6N + Nr + gnd_ri]
        wh = uc[6N + Nr + hub_ri]
        kref = sys.k_mppt_ref[]
        kmin[] = min(kmin[], kref)
        kmax[] = max(kmax[], kref)
        isnan(kfirst[]) && (kfirst[] = kref)
        klast[] = kref
        tau, _ = KiteTurbineDynamics.get_generator_torque(
            uc, sys, pc, tc, ctx.wf; brake_engaged=sys.brake_engaged[],
        )
        P = tau * wg / 1000.0

        brk_now = sys.any_broken[]
        brk_edge = brk_now && !brk_prev[]
        brk_prev[] = brk_now

        do_row = (dense_start && s <= 1500) || (s % stride_r[] == 0) ||
                 (s == total_n_r[]) || brk_edge
        if do_row && s != last_row_s[]
            last_row_s[] = s
            st = (peak=NaN, trpt=NaN, bridle=NaN, cyan=NaN)
            if strain_err[] === nothing
                try
                    st = strain_state(uc, sys, pc)
                catch e
                    strain_err[] = e
                    @printf("STRAIN REPLICATION FAILED at s=%d t=%.4f: %s\n",
                        s, tc, sprint(showerror, e))
                end
            end
            push!(rows_t, tc)
            push!(rows_wg, wg)
            push!(rows_wh, wh)
            push!(rows_P, P)
            push!(rows_tau, tau)
            push!(rows_s, st.peak / KiteTurbineDynamics.ROPE_BREAK_STRAIN)
            push!(rows_s_trpt, st.trpt / KiteTurbineDynamics.ROPE_BREAK_STRAIN)
            push!(rows_s_brid, st.bridle / KiteTurbineDynamics.ROPE_BREAK_STRAIN)
            push!(rows_s_cyan, st.cyan / KiteTurbineDynamics.ROPE_BREAK_STRAIN)
            push!(rows_brk, Int(sys.any_broken[]))
            if abs(wg) > 1.0
                r24 = tau / (2.24 * wg^2)
                r24_min[] = min(r24_min[], r24)
                r24_max[] = max(r24_max[], r24)
            end
            if length(rows_t) % 1000 == 0
                @printf("  progress: %d rows, t=%.2f s\n", length(rows_t), tc)
            end
        end

        # capture_extended parity certificate: P from the scored definition chain
        if tc >= next_cap[] || s == total_n_r[]
            try
                ef = KiteTurbineDynamics.capture_extended(
                    uc, sys, pc, tc, ctx.wf, ctx.lift_device;
                    brake_engaged=sys.brake_engaged[],
                )
                push!(cap_diffs, (tc, abs(ef.base.P_kw - P), abs(ef.base.omega_hub - wh)))
                next_cap[] = tc + 10.0
            catch e
                @printf("capture_extended parity probe failed at t=%.4f: %s\n",
                    tc, sprint(showerror, e))
                next_cap[] = tc + 10.0
            end
        end
    end

    t0 = time()
    r = KiteTurbineDynamics.evaluate_windowed(
        xr, PROFILE_ELLIPTICAL, p_base, cfg;
        start_mode=start_mode,
        lift_device=lift_for,
        trace_callback=tap,
        fitness_fn=(P, F, c, m) -> KiteTurbineDynamics.appropriate_mass_fitness(P, F, c, m),
    )
    wall = round(time() - t0, digits=1)
    println("eval wall = ", wall, " s   status = ", r.status)

    return (; r, rows_t, rows_wg, rows_wh, rows_P, rows_tau, rows_s, rows_s_trpt,
        rows_s_brid, rows_s_cyan, rows_brk, dt=dt_r[], k_min=kmin[], k_max=kmax[],
        k_first=kfirst[], k_last=klast[], strain_err=strain_err[], cap_diffs,
        r24_min=r24_min[], r24_max=r24_max[])
end

function write_csv(path::String, d, tag::String)
    mkpath(dirname(path))
    tree = try
        strip(read(`git rev-parse --short HEAD`, String))
    catch
        "unknown"
    end
    open(path, "w") do io
        println(io, "# eval-timeline-extract / ", basename(path))
        println(io, "# F3 evaluation-timeline capture. Generated by scripts/probe_eval_timeline.jl.")
        println(io, "# run-id: eval-timeline-winner-", tag)
        println(io, "# dataset: v13_5kw_masslift_len18.8_rotorcount_bankderate2 | tree ", tree)
        println(io, "# physics era: post-95c385d_wind-authority")
        if tag == "cold"
            println(io, "# path: evaluate_windowed :cold (k=2.24, relax 10 s + window 40 s, kickstart 0)")
            println(io, "# capture: 100 Hz samples, t 0 to 50 s. Parity vs NR-012 exact on fitness/P_mean/P_end/omega_eq.")
        else
            println(io, "# path: evaluate_windowed :warm (k=2.24, same protocol, equilibrium seed)")
            println(io, "# capture: one row per step, s = 1..98. The run ends at the rope-break latch (NR-013), t = 2.84 ms.")
        end
        println(io, "t,omega_gnd,omega_hub,P_gen_kw,tau_gen_Nm,strain_max_over_break,any_broken")
        for i in eachindex(d.rows_t)
            @printf(io, "%.6f,%.9f,%.9f,%.9f,%.9f,%.9f,%d\n",
                d.rows_t[i], d.rows_wg[i], d.rows_wh[i], d.rows_P[i],
                d.rows_tau[i], d.rows_s[i], d.rows_brk[i])
        end
    end
    println("wrote ", path, "  (", length(d.rows_t), " rows)")
end

function summarize(tag::String, d; parity=false)
    println("\n== ", tag, " summary ==")
    println("status=", d.r.status, "  line_broken=", d.r.line_broken)
    if isempty(d.rows_t)
        println("  (no rows captured — run rejected before the first sample)")
        return
    end
    println("rows n=", length(d.rows_t), "  t range ", d.rows_t[1], " .. ", d.rows_t[end])
    if parity
        println("-- parity vs recorded cold re-eval (NR-012) --")
        ok = true
        for f in (:fitness, :P_mean, :P_end, :ω_eq)
            got = getfield(d.r, f)
            ex = EXPECTED[f]
            diff = abs(got - ex)
            ok &= (diff == 0.0)
            println("  ", f, " got=", got, " expected=", ex, " |diff|=", diff,
                " ", diff == 0.0 ? "EXACT" : "CHECK")
        end
        println("  overall: ", ok ? "EXACT on all four fields" : "MISMATCH")
    else
        println("  fitness=", d.r.fitness, "  P_mean=", d.r.P_mean,
            "  P_end=", d.r.P_end, "  ω_eq=", d.r.ω_eq)
    end

    if d.rows_t[end] < RELAX_S
        println("  run ended at t=", d.rows_t[end], " (before the window) — relax-phase report:")
        for (nm, arr) in (("trpt", d.rows_s_trpt), ("bridle", d.rows_s_brid),
            ("cyan", d.rows_s_cyan), ("peak", d.rows_s))
            im = argmax(arr)
            @printf("  strain %-6s max %.6f at t=%.6f\n", nm, arr[im], d.rows_t[im])
        end
        if sum(d.rows_brk) > 0
            ib = findfirst(==(1), d.rows_brk)
            @printf("  FIRST BREAK OBSERVED: row %d t=%.6f strain/break=%.5f\n",
                ib, d.rows_t[ib], d.rows_s[ib])
        end
        return
    end

    win = findall(>=(RELAX_S), d.rows_t)
    rel = findall(<(RELAX_S), d.rows_t)
    wg = d.rows_wg[win]
    wh = d.rows_wh[win]
    P = d.rows_P[win]
    tau = d.rows_tau[win]
    mwg = sum(wg) / length(wg)
    mwh = sum(wh) / length(wh)
    mP = sum(P) / length(P)
    mtau = sum(tau) / length(tau)
    mwg2 = sum(wg .^ 2) / length(wg)
    mwg3 = sum(wg .^ 3) / length(wg)
    println("-- 100 Hz window stats (t >= ", RELAX_S, ", n=", length(win), ") --")
    @printf("  window-mean omega_gnd = %.15f\n", mwg)
    @printf("  window-mean omega_hub = %.15f\n", mwh)
    @printf("  window-mean tau_gen   = %.15f N.m\n", mtau)
    @printf("  window-mean P_gen     = %.15f kW\n", mP)
    @printf("  k_eff = mean(tau)/mean(w^2) = %.15f  (k=2.24 ratio %.12f)\n",
        mtau / mwg2, mtau / mwg2 / 2.24)
    @printf("  mean(tau)/(2.24*mean(w^2))  = %.15f\n", mtau / (2.24 * mwg2))
    @printf("  per-sample tau/(2.24*w^2)   = min %.15f  max %.15f\n",
        d.r24_min[], d.r24_max[])
    @printf("  mean(k*w^3)/1000 (k=2.24)   = %.15f kW   vs mean(P) = %.15f kW\n",
        2.24 * mwg3 / 1000, mP)
    @printf("  ratio mean(P)/(2.24*mean(w^3)) = %.15f\n", mP / (2.24 * mwg3 / 1000))
    @printf("  NR-030 style: mean(P)*1000/mean(w) = %.15f N.m\n", mP * 1000 / mwg)

    # last-five 1 Hz-sample analogue (t = 46..50 nearest 1 s grid)
    println("-- nearest-sample values at the last-five 1 Hz grid --")
    for tt in (46.0, 47.0, 48.0, 49.0, 50.0)
        j = argmin(abs.(d.rows_t .- tt))
        @printf("  t=%.6f  P=%.9f kW  tau=%.9f  wg=%.9f\n",
            d.rows_t[j], d.rows_P[j], d.rows_tau[j], d.rows_wg[j])
    end
    last5 = findall(>=(46.0), d.rows_t)
    @printf("  mean over t>=46 (%d 100Hz samples) = %.9f kW\n",
        length(last5), sum(d.rows_P[last5]) / length(last5))

    println("-- strain (normalized to break) --")
    for (nm, arr) in (("trpt", d.rows_s_trpt), ("bridle", d.rows_s_brid),
        ("cyan", d.rows_s_cyan), ("peak", d.rows_s))
        iw = argmax(@view arr[win])
        ir = argmax(@view arr[rel])
        @printf("  %-6s window max %.6f at t=%.3f | relax max %.6f at t=%.3f\n",
            nm, arr[win][iw], d.rows_t[win][iw], arr[rel][ir], d.rows_t[rel][ir])
    end
    println("  any_broken samples = ", sum(d.rows_brk))

    println("-- decomposition instrumentation --")
    println("  k_mppt_ref: first=", d.k_first, " last=", d.k_last,
        " min=", d.k_min, " max=", d.k_max)
    if d.strain_err !== nothing
        println("  STRAIN REPLICATION ERROR: ", sprint(showerror, d.strain_err))
    end
    println("  capture_extended parity (|dP_kw|, |domega_hub|):")
    for (tc, dP, dwh) in d.cap_diffs
        @printf("    t=%.4f  dP=%.3e  dwh=%.3e\n", tc, dP, dwh)
    end
end

function main()
    h = try
        strip(read(`git rev-parse HEAD`, String))
    catch
        "unknown"
    end
    println("probe_eval_timeline.jl | HEAD ", h)
    x = [parse(Float64, tok) for tok in split(strip(read(WINNER, String)), ",")]
    xr = copy(x)
    xr[4] = Float64(round(Int, clamp(xr[4], 3, 16)))
    xr[6] = Float64(round(Int, clamp(xr[6], 1, 3)))
    println("x  = ", x)
    println("xr = ", xr)

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

    println("\n############ COLD RUN ############")
    cold = try
        run_trace(xr, p_base, cfg, :cold)
    catch e
        println("COLD RUN FAILED: ", sprint(showerror, e))
        nothing
    end
    if cold !== nothing
        summarize("cold", cold; parity=true)
        write_csv(joinpath(OUTDIR, "extract-eval-timeline-cold.csv"), cold, "cold")
    end

    println("\n############ WARM RUN ############")
    warm = try
        run_trace(xr, p_base, cfg, :warm; dense_start=true)
    catch e
        println("WARM RUN FAILED: ", sprint(showerror, e))
        nothing
    end
    if warm !== nothing
        summarize("warm", warm; parity=false)
        write_csv(joinpath(OUTDIR, "extract-eval-timeline-warm.csv"), warm, "warm")
    end

    if cold !== nothing && warm !== nothing
        println("\n== cold vs warm ==")
        cw = findall(>=(RELAX_S), cold.rows_t)
        ww = findall(>=(RELAX_S), warm.rows_t)
        if !isempty(cw) && !isempty(ww)
            @printf("  window-mean omega_gnd: cold %.12f  warm %.12f\n",
                sum(cold.rows_wg[cw]) / length(cw), sum(warm.rows_wg[ww]) / length(ww))
            @printf("  window-mean P_gen:     cold %.12f  warm %.12f\n",
                sum(cold.rows_P[cw]) / length(cw), sum(warm.rows_P[ww]) / length(ww))
        else
            @printf("  warm ended before the window (status=%s, last t=%.6f) — no window comparison\n",
                warm.r.status, warm.rows_t[end])
        end
        ic = argmax(cold.rows_s)
        iw2 = argmax(warm.rows_s)
        @printf("  peak strain/break: cold %.6f at t=%.3f  warm %.6f at t=%.3f\n",
            cold.rows_s[ic], cold.rows_t[ic], warm.rows_s[iw2], warm.rows_t[iw2])
    end
end

main()

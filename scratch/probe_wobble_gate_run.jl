# scratch/probe_wobble_gate_run.jl
#
# Wobble-gate FULL-PROTOCOL run (one configuration per process).
# Protocol (Rod's decisions, 2026-09-2x):
#   settle (n_op=300_000 + operational polish) -> relax (>=100 s, breaks OFF)
#   -> measurement window (>=120 s, breaks ON), only the given lin_damp active.
#
# Measures, per Rod's gate spec:
#   - shape: per-line slack, threshold T < 1.0 N; gate fails if any line above
#     the ground ring (TRPT tethers, bridle cone, cyan, lift line) is slack for
#     a contiguous t >= 0.1 s, or cumulative slack >= 1.0 s across the window.
#     Slack is tracked every ~10 ms (contiguous resolution far below the 0.1 s
#     threshold); the back line is tracked as context only (off-design slack
#     allowed).
#   - load: FoS from the SAME instrument as the evaluator window
#     (`min_airborne_fos(ef.ring_fos)` on capture_extended samples), reported as
#     trough (min) and mean over the window; gate target FoS >= 2.5 at the peak.
#   - context: hub/bearing lateral trajectory, key tensions, P_gen, omega.
#
# Usage:
#   julia --project=. scratch/probe_wobble_gate_run.jl <lin_damp> <dt_factor> <relax_s> <window_s> <tag>
#   e.g. ... 0.05 1 120 120 wg_ld0.05_dtf1
#
# Log:  .julia_depot/logs/<tag>.log   (via shell redirect)
# CSV:  .julia_depot/logs/<tag>.csv

using KiteTurbineDynamics, LinearAlgebra, Statistics, Printf
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "test", "settle_case_builders.jl"))

const LD = length(ARGS) >= 1 ? parse(Float64, ARGS[1]) : 0.05
const DTF = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 1
const RELAX_S = length(ARGS) >= 3 ? parse(Float64, ARGS[3]) : 120.0
const WINDOW_S = length(ARGS) >= 4 ? parse(Float64, ARGS[4]) : 120.0
const TAG = length(ARGS) >= 5 ? ARGS[5] : "wg_smoke"
const CAPTURE_DT = 0.5     # s, capture_extended sampling in the window
const SLACK_DT = 0.01      # s, slack tracker sampling

pos(u, gid) = u[(3 * (gid - 1) + 1):(3 * gid)]

"Total tension in the six bridles (lift bearing -> main rotor attachment vertices)."
function bridle_total_tension(u, sys, p, N, Nr)
    hub, bear = sys.rotor.node_id, sys.bearing_id
    pp1, pp2 = KiteTurbineDynamics._tilted_ring_basis(u, sys, hub, Nr)
    node = sys.nodes[hub]::RingNode
    R = isempty(sys.expansion_rotors) ? node.radius : sys.effective_radii[node.ring_idx]
    total = 0.0
    for ss in sys.sub_segs
        na, nb = ss.end_a.node_id, ss.end_b.node_id
        ((na == hub && nb == bear) || (na == bear && nb == hub)) || continue
        ring_end = ss.end_a.is_ring ? ss.end_a : ss.end_b
        pa = attachment_point(pos(u, hub), R, u[6N + Nr], ring_end.line_idx, p.n_lines, pp1, pp2)
        L = norm(pos(u, bear) .- pa)
        total += ss.EA * max(0.0, (L - ss.length_0) / ss.length_0)
    end
    return total
end

"Tension in the cyan line (sky anchor <-> lift bearing), by its own spring law."
function cyan_tension(u, sys, p)
    total = 0.0
    for ss in sys.sub_segs
        na, nb = ss.end_a.node_id, ss.end_b.node_id
        (
            (na == sys.sky_anchor_id && nb == sys.bearing_id) ||
            (na == sys.bearing_id && nb == sys.sky_anchor_id)
        ) || continue
        L = norm(pos(u, ss.end_b.node_id) .- pos(u, ss.end_a.node_id))
        total += ss.EA * max(0.0, (L - ss.length_0) / ss.length_0)
    end
    return total
end

"Back-line tension by the single authority `back_line_tension`, same geometry as ring_forces.jl."
function back_tension(u, sys, p)
    hub_gid = sys.rotor.node_id
    hub_ri = (sys.nodes[hub_gid]::RingNode).ring_idx
    r_top = isempty(sys.expansion_rotors) ? (sys.nodes[hub_gid]::RingNode).radius :
            sys.effective_radii[hub_ri]
    bearing_offset = KiteTurbineDynamics.bridle_bearing_offset(r_top)
    cyan_L0 = KiteTurbineDynamics.CYAN_L0_DESIGN
    back_ax = p.tether_length * cos(p.elevation_angle) + p.back_anchor_fwd_x
    sa = pos(u, sys.sky_anchor_id)
    b_dx = sqrt((sa[1] - back_ax)^2 + sa[2]^2)
    b_dz = sa[3]
    b_dist = sqrt(b_dx^2 + b_dz^2)
    L_axis_design = p.tether_length + bearing_offset + cyan_L0
    d_sa_x = L_axis_design * cos(p.elevation_angle)
    d_sa_z = L_axis_design * sin(p.elevation_angle)
    back_L0_design = sqrt((d_sa_x - back_ax)^2 + d_sa_z^2)
    return KiteTurbineDynamics.back_line_tension(
        b_dist, back_L0_design, p.backline_payout, p.EA_back_line
    )
end

"Lift force applied to the sky anchor = mass x (accel with lift - accel without)."
function lift_force_applied(u, sys, p, wf, lift)
    N = sys.n_total
    du_on = zeros(length(u))
    KiteTurbineDynamics.multibody_ode!(du_on, u, (sys, p, wf, lift), 0.0)
    du_off = zeros(length(u))
    KiteTurbineDynamics.multibody_ode!(du_off, u, (sys, p, wf), 0.0)
    g = sys.sky_anchor_id
    m = (sys.nodes[g]).mass
    return m .* (
        du_on[(3N + 3 * (g - 1) + 1):(3N + 3 * g)] .-
        du_off[(3N + 3 * (g - 1) + 1):(3N + 3 * g)]
    )
end

"""
Slack tracker: per-line contiguous/total slack below `thresh = 1.0 N`,
sampled every ~`SLACK_DT` seconds of simulated time. The gated set is every
line above the ground ring: TRPT (per segment, per line), bridle cone (per
line), cyan, lift line. The back line is tracked as context.
"""
function make_slack_tracker(sys, p, wf, lift, N, Nr, dt_use)
    hub_gid = sys.rotor.node_id
    bear_gid = sys.bearing_id
    n_trpt = Nr - 1
    n_line = p.n_lines
    names = String[]
    for s in 1:n_trpt, j in 1:n_line
        push!(names, "trpt_s$(s)_l$(j)")
    end
    for j in 1:n_line
        push!(names, "bridle_l$(j)")
    end
    append!(names, ["cyan", "lift", "back"])
    n = length(names)
    cur = zeros(n); maxc = zeros(n); tot = zeros(n); mint = fill(Inf, n)
    n_eps = zeros(Int, n); lastslack = falses(n)
    sample_every = max(1, round(Int, SLACK_DT / dt_use))
    Δ = sample_every * dt_use

    # Precollect the non-TRPT sub-segments once.
    bridle_subs = Vector{Tuple{Any,Int}}()
    cyan_subs = Vector{Any}()
    for ss in sys.sub_segs
        na, nb = ss.end_a.node_id, ss.end_b.node_id
        if (na == hub_gid && nb == bear_gid) || (na == bear_gid && nb == hub_gid)
            ring_end = ss.end_a.is_ring ? ss.end_a : ss.end_b
            push!(bridle_subs, (ss, ring_end.line_idx))
        elseif (na == sys.sky_anchor_id && nb == bear_gid) ||
               (na == bear_gid && nb == sys.sky_anchor_id)
            push!(cyan_subs, ss)
        end
    end

    buf = zeros(n)

    function compute!(u)
        k = 0
        for s in 1:n_trpt, j in 1:n_line
            k += 1
            buf[k] = get_segment_tension(u, sys, p, s, j)
        end
        pp1, pp2 = KiteTurbineDynamics._tilted_ring_basis(u, sys, hub_gid, Nr)
        node = sys.nodes[hub_gid]::RingNode
        R = isempty(sys.expansion_rotors) ? node.radius : sys.effective_radii[node.ring_idx]
        for j in 1:n_line
            Tj = 0.0
            for (ss, lj) in bridle_subs
                lj == j || continue
                ring_end = ss.end_a.is_ring ? ss.end_a : ss.end_b
                pa = attachment_point(
                    pos(u, hub_gid), R, u[6N + Nr], ring_end.line_idx, p.n_lines, pp1, pp2
                )
                L = norm(pos(u, bear_gid) .- pa)
                Tj += ss.EA * max(0.0, (L - ss.length_0) / ss.length_0)
            end
            k += 1
            buf[k] = Tj
        end
        Tc = 0.0
        for ss in cyan_subs
            L = norm(pos(u, ss.end_b.node_id) .- pos(u, ss.end_a.node_id))
            Tc += ss.EA * max(0.0, (L - ss.length_0) / ss.length_0)
        end
        k += 1; buf[k] = Tc
        k += 1; buf[k] = norm(lift_force_applied(u, sys, p, wf, lift))
        k += 1; buf[k] = back_tension(u, sys, p)
        return buf
    end

    function update!(u)
        Ts = compute!(u)
        @inbounds for i in 1:n
            if Ts[i] < 1.0
                if lastslack[i]
                    cur[i] += Δ
                else
                    lastslack[i] = true
                    cur[i] = Δ
                end
            else
                if lastslack[i]
                    maxc[i] = max(maxc[i], cur[i])
                    tot[i] += cur[i]
                    cur[i] >= 0.1 && (n_eps[i] += 1)
                    cur[i] = 0.0
                    lastslack[i] = false
                end
            end
            mint[i] = min(mint[i], Ts[i])
        end
        return nothing
    end

    function finish!()
        for i in 1:n
            if lastslack[i]
                maxc[i] = max(maxc[i], cur[i])
                tot[i] += cur[i]
                cur[i] >= 0.1 && (n_eps[i] += 1)
            end
        end
        return nothing
    end

    return (; names, mint, maxc, tot, n_eps, sample_every, update!, finish!)
end

function main()
    t0 = time()
    gh = try
        strip(read(`git rev-parse --short HEAD`, String))
    catch
        "unknown"
    end
    sys, u0, p, lift, wf = build_case(nothing, nothing)
    N, Nr = sys.n_total, sys.n_ring
    dt = KiteTurbineDynamics.stable_dt_for_system(sys, p)
    dt_use = dt / DTF
    @printf("=== wobble gate run  tag=%s  git=%s ===\n", TAG, gh)
    @printf("n_total=%d n_ring=%d n_lines=%d rotors=%d\n", N, Nr, p.n_lines,
        length(sys.expansion_rotors))
    @printf("lin_damp=%.4g  dt_factor=%d  dt_use=%.6g s  relax=%.1f s  window=%.1f s\n",
        LD, DTF, dt_use, RELAX_S, WINDOW_S)
    @assert Nr >= 10
    @assert dt_use > 0
    flush(stdout)

    t_s = @elapsed u = settle_to_operational_state(
        sys, copy(u0), p, 60.0; lift_device=lift, wind_fn=wf, n_op=300_000
    )
    @assert all(isfinite, u)
    @printf("settle wall = %.1f s\n", t_s)
    # handoff residual (V6 instrument)
    du = zeros(length(u))
    KiteTurbineDynamics.multibody_ode!(du, u, (sys, p, wf, lift), 0.0)
    accs = [norm(du[(3N + 3 * (g - 1) + 1):(3N + 3 * g)]) for g in 1:N]
    st = [g for g in 1:N if sys.nodes[g] isa RingNode || g == sys.bearing_id || g == sys.sky_anchor_id]
    @printf("handoff residual: acc_struct %.3f m/s2  max_force %.3f N\n",
        maximum(accs[g] for g in st), maximum(sys.nodes[g].mass * accs[g] for g in 1:N))
    flush(stdout)

    # ── relax phase (breaks OFF) ─────────────────────────────────────────
    nrelax = round(Int, RELAX_S / dt_use)
    chunk = round(Int, 20.0 / dt_use)
    t_r = time()
    done = 0
    while done < nrelax
        n = min(chunk, nrelax - done)
        run_canonical_sim!(u, sys, p, wf, n, dt_use; lift_device=lift, lin_damp=LD)
        done += n
        @printf("[relax] t=%6.1f s  hub_lat=%.4f  T_cyan=%.1f T_back=%.1f\n",
            done * dt_use,
            norm(pos(u, sys.rotor.node_id) .- dot(pos(u, sys.rotor.node_id),
                [cos(p.elevation_angle), 0.0, sin(p.elevation_angle)]) .*
                [cos(p.elevation_angle), 0.0, sin(p.elevation_angle)]),
            cyan_tension(u, sys, p), back_tension(u, sys, p))
        flush(stdout)
        sys.any_broken[] && (@warn "break during relax"; break)
    end
    relax_wall = time() - t_r
    @printf("relax wall = %.1f s\n", relax_wall)
    flush(stdout)

    # ── measurement window (breaks ON) ──────────────────────────────────
    tracker = make_slack_tracker(sys, p, wf, lift, N, Nr, dt_use)
    nwin = round(Int, WINDOW_S / dt_use)
    wchunk = round(Int, 5.0 / dt_use)
    ncap = round(Int, WINDOW_S / CAPTURE_DT) + 1
    wts = zeros(ncap); hubE1 = zeros(ncap); hubE2 = zeros(ncap)
    hubL = zeros(ncap); bearE1 = zeros(ncap); bearE2 = zeros(ncap); bearL = zeros(ncap)
    cy = zeros(ncap); bk = zeros(ncap); br = zeros(ncap); topbay = zeros(ncap)
    fos = zeros(ncap); wgnd = zeros(ncap); pgen = zeros(ncap); brk = zeros(ncap)

    shaft = [cos(p.elevation_angle), 0.0, sin(p.elevation_angle)]
    ey = [0.0, 1.0, 0.0]
    e1 = normalize(ey .- dot(ey, shaft) .* shaft)
    e2 = normalize(cross(shaft, e1))
    hub_gid = sys.rotor.node_id
    bear_gid = sys.bearing_id
    lat_of(v) = norm(v .- dot(v, shaft) .* shaft)
    p1c(v) = dot(v .- dot(v, shaft) .* shaft, e1)
    p2c(v) = dot(v .- dot(v, shaft) .* shaft, e2)
    gnd_ri = (sys.nodes[sys.ring_ids[1]]::RingNode).ring_idx
    cap_every = max(1, round(Int, CAPTURE_DT / dt_use))
    nc = Ref(0)
    t_base = Ref(0.0)

    cb(u_, t_, step_) = begin
        if step_ % tracker.sample_every == 0
            tracker.update!(u_)
        end
        if step_ % cap_every == 0
            nc[] += 1
            i = nc[]
            if i <= ncap
                t_abs = t_base[] + t_
                hv = pos(u_, hub_gid); bv = pos(u_, bear_gid)
                wts[i] = t_abs
                hubE1[i] = p1c(hv); hubE2[i] = p2c(hv); hubL[i] = lat_of(hv)
                bearE1[i] = p1c(bv); bearE2[i] = p2c(bv); bearL[i] = lat_of(bv)
                ef = KiteTurbineDynamics.capture_extended(u_, sys, p, t_abs, wf, lift)
                cy[i] = cyan_tension(u_, sys, p)
                bk[i] = back_tension(u_, sys, p)
                br[i] = bridle_total_tension(u_, sys, p, N, Nr)
                topbay[i] = ef.segment_tension[end]
                f, _ = KiteTurbineDynamics.min_airborne_fos(ef.ring_fos)
                fos[i] = f
                wgnd[i] = u_[6N + Nr + gnd_ri]
                tg, _ = KiteTurbineDynamics.get_generator_torque(
                    u_, sys, p, t_abs, wf; brake_engaged=sys.brake_engaged[])
                pgen[i] = tg * wgnd[i] / 1000.0
                brk[i] = sys.any_broken[] ? 1.0 : 0.0
            end
        end
        return nothing
    end

    t_w = time()
    done = 0
    while done < nwin
        n = min(wchunk, nwin - done)
        t_base[] = done * dt_use
        run_canonical_sim!(
            u, sys, p, wf, n, dt_use;
            lift_device=lift, lin_damp=LD, breaks_enabled=true, callback=cb
        )
        done += n
        @printf("[window] t=%6.1f s\n", done * dt_use)
        flush(stdout)
        sys.any_broken[] && (@warn "break during window"; break)
    end
    window_wall = time() - t_w
    tracker.finish!()
    @printf("window wall = %.1f s\n", window_wall)

    # ── summary ─────────────────────────────────────────────────────────
    nc_cap = nc[]
    nc_cap >= 2 || error("no window samples captured")
    rng = 1:nc_cap
    @printf("\n=== GATE SUMMARY tag=%s ===\n", TAG)
    @printf("steps: relax %d, window %d; dt_use %.6g s; captured %d; broken=%s\n",
        nrelax, nwin, dt_use, nc_cap, sys.any_broken[] ? "YES" : "no")
    for (name, v) in (("hub_lat", hubL[rng]), ("bear_lat", bearL[rng]),
        ("T_cyan", cy[rng]), ("T_back", bk[rng]), ("T_bridle", br[rng]),
        ("T_topbay", topbay[rng]), ("P_gen_kW", pgen[rng]), ("omega_gnd", wgnd[rng]))
        @printf("%-10s min %10.4f  max %10.4f  p2p %10.4f  mean %10.4f\n",
            name, minimum(v), maximum(v), maximum(v) - minimum(v), mean(v))
    end
    fv = fos[rng]
    ff = filter(isfinite, fv)
    isempty(ff) && error("no finite FoS samples captured")
    @printf("FoS (airborne min): trough %.4f  mean %.4f  (n=%d nonfinite=%d)\n",
        minimum(ff), mean(ff), length(ff), length(fv) - length(ff))
    h = div(nc_cap, 2)
    @printf("hub_lat p2p first-half %.4f  second-half %.4f;  mean 2nd half %.4f\n",
        maximum(hubL[1:h]) - minimum(hubL[1:h]),
        maximum(hubL[(h + 1):nc_cap]) - minimum(hubL[(h + 1):nc_cap]),
        mean(hubL[(h + 1):nc_cap]))
    @printf("\nslack summary (threshold 1.0 N; Δs=%.4g s):\n", tracker.sample_every * dt_use)
    @printf("  %-14s %9s %9s %9s %6s\n", "line", "min_T_N", "max_cont_s", "tot_s", "#EPS>=0.1")
    anyfail = false
    for i in 1:length(tracker.names)
        gated = tracker.names[i] != "back"
        show = tracker.tot[i] > 0.0 || tracker.mint[i] < 5.0 || !gated
        show || continue
        fail = gated && (tracker.maxc[i] >= 0.1 || tracker.tot[i] >= 1.0)
        anyfail |= fail
        @printf("  %-14s %9.3f %9.4f %9.4f %6d  %s\n", tracker.names[i],
            tracker.mint[i], tracker.maxc[i], tracker.tot[i], tracker.n_eps[i],
            fail ? "** FAIL **" : (gated ? "ok" : "(context)"))
    end
    @printf("SLACK GATE: %s\n", anyfail ? "FAIL" : "pass")
    @printf("FOS GATE (>=2.5 at trough): %s (trough %.4f)\n",
        minimum(ff) >= 2.5 ? "pass" : "FAIL", minimum(ff))

    # ── CSV ─────────────────────────────────────────────────────────────
    csv = joinpath(@__DIR__, "..", ".julia_depot", "logs", "$(TAG).csv")
    open(csv, "w") do io
        println(io, "t,hub_e1,hub_e2,hub_lat,bear_e1,bear_e2,bear_lat,T_cyan,T_back," *
                    "T_bridle,T_topbay,fos_min,omega_gnd,P_gen_kW,broken")
        for i in rng
            @printf(io, "%.4f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.4f,%.4f,%.4f,%.4f,%.4f,%.6f,%.4f,%.0f\n",
                wts[i], hubE1[i], hubE2[i], hubL[i], bearE1[i], bearE2[i], bearL[i],
                cy[i], bk[i], br[i], topbay[i], fos[i], wgnd[i], pgen[i], brk[i])
        end
    end
    @printf("\ncsv: %s\n", csv)
    @printf("total wall %.1f s\n=== done ===\n", time() - t0)
end

main()

# scratch/probe_wobble_refresh.jl
#
# Wobble-gate Step 1 (desktop), HEAD 9e40342 — refresh measurement.
#
# Rod's Step-1 direction (2026-09-2x): run a 20–30 s operational window after
# the production settle on the re-seeded campaign design and measure
#   - hub and bearing lateral swing amplitude ((x,y) trajectory in the
#     shaft-perpendicular plane)
#   - the ~10 s wobble period (is the mode present; has its amplitude moved?)
#   - peak-to-peak tension fluctuation: cyan line, back line, bridle cone,
#     topmost TRPT bay
# and produce the wall-clock / step-count basis for the full gate runs
# (relax >= 100 s + window >= 120 s) BEFORE any long sweep is launched.
#
# Windows:
#   1. lin_damp = 0.05 — production (primary).
#   2. lin_damp = 0.00 — zero-artificial-damping bracket point (ADVISORY:
#      per instrument-trust-log.md it is "trivially-convergent but unphysical"
#      and must not alone be cited as a design finding; it becomes the
#      governing envelope only after the DT-paired sweep, DECISIONS [2026-09-15]).
#
# Both windows run from the SAME settled state so the comparison is clean.
# Call shape matches the v13 gate/campaign path (ode_gate_v13.jl:169-186,
# run_v13_5kw*.jl): no `spoke` is passed, so spokes are off — the trust-log
# "Canonical Config" spokes=ON line is the older (12-gon / V11-V12) era.
#
# Self-asserting: finite samples, positive dt, sane node count — else raise.
#
# Log: .julia_depot/logs/probe_wobble_refresh.log
# CSVs: .julia_depot/logs/wobble_refresh_<tag>.csv

using KiteTurbineDynamics, LinearAlgebra, Statistics, Printf
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "test", "settle_case_builders.jl"))

pos(u, gid) = u[(3 * (gid - 1) + 1):(3 * gid)]

# ── readers — kept IDENTICAL to test/test_settle_validity.jl so the numbers
# are directly comparable with the guard's log.

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

"Period estimate from upward mean crossings of the series (linear interpolation)."
function period_est(ts, x)
    xc = x .- mean(x)
    tc = Float64[]
    for i in 1:(length(xc) - 1)
        if xc[i] < 0 && xc[i + 1] >= 0
            push!(tc, ts[i] - xc[i] * (ts[i + 1] - ts[i]) / (xc[i + 1] - xc[i]))
        end
    end
    return length(tc) >= 2 ? (mean(diff(tc)), length(tc)) : (NaN, length(tc))
end

function run_window(u_op, sys, p, wf, lift, lin_damp; duration=30.0, sample_dt=0.25)
    N, Nr = sys.n_total, sys.n_ring
    u = copy(u_op)
    dt = KiteTurbineDynamics.stable_dt_for_system(sys, p)
    total_steps = round(Int, duration / dt)
    n_chunks = round(Int, duration / sample_dt)
    chunk = div(total_steps, n_chunks)
    ns = n_chunks + 1
    ts = zeros(ns); hubL = zeros(ns); bearL = zeros(ns)
    hubP1 = zeros(ns); hubP2 = zeros(ns); bearP1 = zeros(ns); bearP2 = zeros(ns)
    cy = zeros(ns); bk = zeros(ns); br = zeros(ns); wg = zeros(ns)
    segs = Vector{Vector{Float64}}()

    # shaft-perpendicular basis: e1 (≈ +y) and e2 = shaft × e1
    shaft = [cos(p.elevation_angle), 0.0, sin(p.elevation_angle)]
    ey = [0.0, 1.0, 0.0]
    e1 = normalize(ey .- dot(ey, shaft) .* shaft)
    e2 = normalize(cross(shaft, e1))
    lat_of(v) = norm(v .- dot(v, shaft) .* shaft)
    p1_of(v) = dot(v - dot(v, shaft) .* shaft, e1)
    p2_of(v) = dot(v - dot(v, shaft) .* shaft, e2)
    hub_gid = sys.rotor.node_id
    tag = @sprintf("%.2f", lin_damp)

    t_wall = time()
    for k in 0:n_chunks
        ts[k + 1] = k * sample_dt
        hv = pos(u, hub_gid)
        bv = pos(u, sys.bearing_id)
        hubL[k + 1] = lat_of(hv); bearL[k + 1] = lat_of(bv)
        hubP1[k + 1] = p1_of(hv); hubP2[k + 1] = p2_of(hv)
        bearP1[k + 1] = p1_of(bv); bearP2[k + 1] = p2_of(bv)
        ef = KiteTurbineDynamics.capture_extended(u, sys, p, 0.0, wf, lift)
        cy[k + 1] = cyan_tension(u, sys, p)
        bk[k + 1] = back_tension(u, sys, p)
        br[k + 1] = bridle_total_tension(u, sys, p, N, Nr)
        push!(segs, collect(ef.segment_tension))
        wg[k + 1] = u[6N + Nr + 1]
        if k % 5 == 0
            @printf("[ld=%s] t=%5.2f  hub=(%+.4f,%+.4f) lat=%.4f  bear lat=%.4f  T_cyan=%.2f T_back=%.2f T_bridle=%.2f T_topbay=%.2f\n",
                tag, ts[k + 1], hubP1[k + 1], hubP2[k + 1], hubL[k + 1], bearL[k + 1],
                cy[k + 1], bk[k + 1], br[k + 1], segs[k + 1][end])
            flush(stdout)
        end
        k == n_chunks && break
        run_canonical_sim!(u, sys, p, wf, chunk, dt; lift_device=lift, lin_damp=lin_damp)
        if sys.any_broken[]
            @warn "rope break detected mid-window"
            break
        end
    end
    wall = time() - t_wall
    return (; u, ts, hubL, bearL, hubP1, hubP2, bearP1, bearP2, cy, bk, br, segs, wg,
        wall, dt, total_steps, n_chunks, tag)
end

function summarize(tag, r, sys)
    @printf("\n--- %s ---\n", tag)
    @printf("  wall %.1f s  steps %d  dt %.6g s  sim %.2f s  chunks %d\n",
        r.wall, r.total_steps, r.dt, r.total_steps * r.dt, r.n_chunks)
    @printf("  %-22s %10s %10s %10s %10s\n", "quantity", "min", "max", "p2p", "mean")
    for (name, v) in (
        ("hub lateral (m)", r.hubL), ("bearing lateral (m)", r.bearL),
        ("hub e1 comp (m)", r.hubP1), ("hub e2 comp (m)", r.hubP2),
        ("bear e1 comp (m)", r.bearP1), ("bear e2 comp (m)", r.bearP2),
        ("T_cyan (N)", r.cy), ("T_back (N)", r.bk), ("T_bridle tot (N)", r.br),
        ("omega_gnd (rad/s)", r.wg),
    )
        @printf("  %-22s %10.4f %10.4f %10.4f %10.4f\n",
            name, minimum(v), maximum(v), maximum(v) - minimum(v), mean(v))
    end
    ph, nh = period_est(r.ts, r.hubL)
    pb, nb = period_est(r.ts, r.bearL)
    p1s, n1 = period_est(r.ts, r.hubP1)
    @printf("  hub-lat period: %s s (%d crossings)   bearing: %s s (%d)\n",
        isnan(ph) ? "none" : @sprintf("%.2f", ph), nh,
        isnan(pb) ? "none" : @sprintf("%.2f", pb), nb)
    @printf("  hub-e1 period:  %s s (%d crossings)\n",
        isnan(p1s) ? "none" : @sprintf("%.2f", p1s), n1)
    # first-half vs second-half p2p — damped / steady / growing?
    h = div(length(r.hubL), 2)
    for (name, v) in (("hub lateral", r.hubL), ("T_topbay", [s[end] for s in r.segs]))
        a = maximum(v[1:h]) - minimum(v[1:h]); b = maximum(v[h+1:end]) - minimum(v[h+1:end])
        @printf("  %-12s p2p first-half %.4f  second-half %.4f\n", name, a, b)
    end
    bay = reduce(hcat, r.segs)
    p2p = [maximum(bay[b, :]) - minimum(bay[b, :]) for b in 1:size(bay, 1)]
    bmax = argmax(p2p)
    @printf("  topmost TRPT bay (%d): min %.3f max %.3f p2p %.3f N\n",
        size(bay, 1), minimum(bay[end, :]), maximum(bay[end, :]), p2p[end])
    @printf("  largest-p2p bay (%d): p2p %.3f N\n", bmax, p2p[bmax])
    flush(stdout)
end

function main()
    t0 = time()
    sys, u0, p, lift, wf = build_case(nothing, nothing)
    N, Nr = sys.n_total, sys.n_ring
    @printf("system: n_total=%d n_ring=%d n_lines=%d rotors=%d\n",
        N, Nr, p.n_lines, length(sys.expansion_rotors))
    @assert Nr >= 10
    @assert N > 0
    dt = KiteTurbineDynamics.stable_dt_for_system(sys, p)
    @printf("stable dt = %.6g s\n", dt)
    @assert dt > 0

    println("settling (n_op=300_000, operational polish default ON) ...")
    flush(stdout)
    t_s = @elapsed u_op = settle_to_operational_state(
        sys, copy(u0), p, 60.0; lift_device=lift, wind_fn=wf, n_op=300_000
    )
    @printf("settle wall = %.1f s\n", t_s)
    @assert all(isfinite, u_op)
    flush(stdout)

    for (tag, ld) in (
        ("lin_damp=0.05 (production)", 0.05), ("lin_damp=0.00 (bracket point)", 0.0)
    )
        r = run_window(u_op, sys, p, wf, lift, ld)
        @assert length(r.hubL) == r.n_chunks + 1
        for v in (r.hubL, r.bearL, r.hubP1, r.hubP2, r.bearP1, r.bearP2, r.cy, r.bk, r.br, r.wg)
            @assert all(isfinite, v) "non-finite samples in: $tag"
        end
        for s in r.segs
            @assert all(isfinite, s) "non-finite segment tensions in: $tag"
        end
        summarize(tag, r, sys)
        rate = r.wall / (r.total_steps * r.dt)
        full_steps = round(Int, 240.0 / r.dt)        # relax 120 + window 120
        @printf("  cost rate: %.3f s wall per sim-second; full gate sim (240 s) = %d steps ~ %.1f min (sim only)\n",
            rate, full_steps, full_steps * r.dt * rate / 60)

        # persist the series
        csv = joinpath(@__DIR__, "..", ".julia_depot", "logs",
            @sprintf("wobble_refresh_ld%.2f.csv", ld))
        open(csv, "w") do io
            println(io, "t,hub_e1,hub_e2,hub_lat,bear_e1,bear_e2,bear_lat,T_cyan,T_back,T_bridle,T_topbay,omega_gnd")
            for i in 1:length(r.ts)
                @printf(io, "%.4f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.4f,%.4f,%.4f,%.4f,%.6f\n",
                    r.ts[i], r.hubP1[i], r.hubP2[i], r.hubL[i],
                    r.bearP1[i], r.bearP2[i], r.bearL[i],
                    r.cy[i], r.bk[i], r.br[i], r.segs[i][end], r.wg[i])
            end
        end
        println("  csv: ", csv)
    end

    @printf("\ntotal wall %.1f s\n", time() - t0)
    println("=== done ===")
end

main()

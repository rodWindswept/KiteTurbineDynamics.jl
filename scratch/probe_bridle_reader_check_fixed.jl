# scratch/probe_bridle_reader_check_fixed.jl
#
# CORRECTED bridle reader check (2026-09-21). Same protocol as
# probe_bridle_reader_check.jl (settle -> 120 s relax -> 10 s sample at 10 ms),
# with ONE fix: bridle rest lengths / EAs are collected AFTER
# `settle_to_operational_state`.  The settle runs `apply_design_bridle_preload!`
# (initialization.jl:2203 -> :1317) which REPLACES the bridle sub-segment
# objects with rest lengths CUT for the design preload
# (`L0 = gap / (1 + T_bridle / EA)`, :1334/:1350).  A pre-settle collection is
# stale by ~0.364 mm of rest length and overstates slack.
#
# Output: pre/post L0 table (instrument record), then sim-frame vs reader-frame
# comparison on the settled run with correct L0.
# Log: .julia_depot/logs/bridle_check_fixed_ld0.05.log
using KiteTurbineDynamics, LinearAlgebra, Statistics, Printf
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "test", "settle_case_builders.jl"))

pos(u, gid) = u[(3 * (gid - 1) + 1):(3 * gid)]
const THRESH = 1.0
const SAMPLE_DT = 0.01
const NSAMP = 1000
const LD = 0.05
const RELAX_S = 120.0

function collect_bridles(sys, hub_gid, bear_gid, p)
    pairs = Tuple{Any, Int}[]
    for ss in sys.sub_segs
        na, nb = ss.end_a.node_id, ss.end_b.node_id
        ((na == bear_gid && nb == hub_gid) || (na == hub_gid && nb == bear_gid)) || continue
        ring_end = ss.end_a.is_ring ? ss.end_a : ss.end_b
        push!(pairs, (ss, ring_end.line_idx))
    end
    L0 = fill(NaN, p.n_lines)
    EA = fill(NaN, p.n_lines)
    for (ss, lj) in pairs
        L0[lj] = ss.length_0
        EA[lj] = ss.EA
    end
    return pairs, L0, EA
end

function main()
    sys, u0, p, lift, wf = build_case(nothing, nothing)
    N, Nr = sys.n_total, sys.n_ring
    hub_gid = sys.rotor.node_id
    bear_gid = sys.bearing_id
    hub_ri = (sys.nodes[hub_gid]::RingNode).ring_idx
    dt = KiteTurbineDynamics.stable_dt_for_system(sys, p)
    @printf("=== bridle reader check (FIXED collection order) git=9e40342 ===\n")
    @printf("N=%d Nr=%d hub_ri=%d dt=%.6g\n", N, Nr, hub_ri, dt)

    _, L0pre, _ = collect_bridles(sys, hub_gid, bear_gid, p)
    u = settle_to_operational_state(sys, copy(u0), p, 60.0; lift_device=lift, wind_fn=wf, n_op=300_000)
    pairs, L0, EA = collect_bridles(sys, hub_gid, bear_gid, p)

    @printf("bridle subs (post-settle): %d\n", length(pairs))
    @printf("%-4s %16s %16s %12s %8s\n", "line", "L0 pre-settle", "L0 post-settle", "dL0 (mm)", "nsub")
    for l in 1:(p.n_lines)
        @printf("l%-3d %16.9f %16.9f %12.5f %8d\n", l, L0pre[l], L0[l],
            1000 * (L0[l] - L0pre[l]), count(x -> x[2] == l, pairs))
    end
    @printf("EA (post):")
    for x in EA
        @printf(" %.0f", x)
    end
    @printf("\n")
    flush(stdout)

    R = isempty(sys.expansion_rotors) ? (sys.nodes[hub_gid]::RingNode).radius :
        sys.effective_radii[hub_ri]
    sd0 = [cos(p.elevation_angle), 0.0, sin(p.elevation_angle)]

    function readings(u)
        hub = pos(u, hub_gid)
        bear = pos(u, bear_gid)
        hmag = norm(hub)
        shaft_dir = hmag > 0.1 ? hub ./ hmag : sd0
        pp1s, pp2s = KiteTurbineDynamics.shaft_perp_basis(shaft_dir)
        pp1t, pp2t = KiteTurbineDynamics._tilted_ring_basis(u, sys, hub_gid, hub_ri)
        dLs = zeros(p.n_lines)
        dLt = zeros(p.n_lines)
        vd = 0.0
        for l in 1:(p.n_lines)
            pa_s = attachment_point(hub, R, u[6N + hub_ri], l, p.n_lines, pp1s, pp2s)
            pa_t = attachment_point(hub, R, u[6N + hub_ri], l, p.n_lines, pp1t, pp2t)
            dLs[l] = norm(bear .- pa_s) - L0[l]
            dLt[l] = norm(bear .- pa_t) - L0[l]
            vd = max(vd, norm(pa_s .- pa_t))
        end
        be = bear .- hub
        drift = norm(be .- dot(be, shaft_dir) .* shaft_dir)
        return dLs, dLt, vd, drift
    end

    dLs, dLt, vd, drift = readings(u)
    Ts = EA .* max.(0.0, dLs ./ L0)
    Tt = EA .* max.(0.0, dLt ./ L0)
    @printf("[settle] T_sim=%.3f  T_read=%.3f  drift=%.2fmm\n", sum(Ts), sum(Tt), 1000 * drift)
    flush(stdout)

    nrelax = round(Int, RELAX_S / dt)
    chunk = round(Int, 20.0 / dt)
    done = 0
    while done < nrelax
        n = min(chunk, nrelax - done)
        run_canonical_sim!(u, sys, p, wf, n, dt; lift_device=lift, lin_damp=LD)
        done += n
        dLs, dLt, vd, drift = readings(u)
        Ts = EA .* max.(0.0, dLs ./ L0)
        Tt = EA .* max.(0.0, dLt ./ L0)
        hub = pos(u, hub_gid)
        hl = norm(hub .- dot(hub, sd0) .* sd0)
        @printf("[relax] t=%6.1f  hub_lat=%.3f  drift=%.2fmm  vtxD=%.2fmm  T_sim=%7.2f  T_read=%7.2f\n",
            done * dt, hl, 1000 * drift, 1000 * vd, sum(Ts), sum(Tt))
        flush(stdout)
    end

    se = max(1, round(Int, SAMPLE_DT / dt))
    Δ = se * dt
    ts = zeros(NSAMP)
    drifts = zeros(NSAMP)
    vds = zeros(NSAMP)
    dLsm = zeros(NSAMP, p.n_lines)
    dLtm = zeros(NSAMP, p.n_lines)
    lastsl = falses(p.n_lines); curs = zeros(p.n_lines); maxcs = zeros(p.n_lines)
    tots = zeros(p.n_lines); neps = zeros(Int, p.n_lines)
    lasttl = falses(p.n_lines); curt = zeros(p.n_lines); maxct = zeros(p.n_lines)
    tott = zeros(p.n_lines); nept = zeros(Int, p.n_lines)
    for i in 1:NSAMP
        dLs, dLt, vd, drift = readings(u)
        Ts = EA .* max.(0.0, dLs ./ L0)
        Tt = EA .* max.(0.0, dLt ./ L0)
        ts[i] = (i - 1) * Δ
        drifts[i] = drift
        vds[i] = vd
        dLsm[i, :] = dLs
        dLtm[i, :] = dLt
        for l in 1:(p.n_lines)
            if Ts[l] < THRESH
                if lastsl[l]; curs[l] += Δ else; lastsl[l] = true; curs[l] = Δ end
            else
                if lastsl[l]
                    maxcs[l] = max(maxcs[l], curs[l]); tots[l] += curs[l]
                    curs[l] >= 0.1 && (neps[l] += 1)
                    curs[l] = 0.0; lastsl[l] = false
                end
            end
            if Tt[l] < THRESH
                if lasttl[l]; curt[l] += Δ else; lasttl[l] = true; curt[l] = Δ end
            else
                if lasttl[l]
                    maxct[l] = max(maxct[l], curt[l]); tott[l] += curt[l]
                    curt[l] >= 0.1 && (nept[l] += 1)
                    curt[l] = 0.0; lasttl[l] = false
                end
            end
        end
        i % 200 == 0 && (println("[sample] $i/1000"); flush(stdout))
        i < NSAMP && run_canonical_sim!(u, sys, p, wf, se, dt; lift_device=lift, lin_damp=LD)
    end
    for l in 1:(p.n_lines)
        if lastsl[l]
            maxcs[l] = max(maxcs[l], curs[l]); tots[l] += curs[l]
            curs[l] >= 0.1 && (neps[l] += 1)
        end
        if lasttl[l]
            maxct[l] = max(maxct[l], curt[l]); tott[l] += curt[l]
            curt[l] >= 0.1 && (nept[l] += 1)
        end
    end

    @printf("\n=== BRIDLE READER CHECK (FIXED) SUMMARY ===\n")
    @printf("sampled %.2f s at Δ=%.5f s (lin_damp=%.2f, breaks OFF)\n", NSAMP * Δ, Δ, LD)
    @printf("drift(perp bearing-hub): %.3f..%.3f mm   vertex |pa_sim-pa_reader| max %.3f mm\n",
        1000 * minimum(drifts), 1000 * maximum(drifts), 1000 * maximum(vds))
    @printf("dL_sim range (mm): %.3f..%.3f   dL_reader range (mm): %.3f..%.3f\n",
        1000 * minimum(dLsm), 1000 * maximum(dLsm), 1000 * minimum(dLtm), 1000 * maximum(dLtm))
    @printf("\n%-9s | %-34s | %-34s\n", "line", "SIM frame (force path)", "READER frame (tracker)")
    @printf("%-9s | %7s %7s %7s %7s | %7s %7s %7s %7s\n",
        "", "minT", "maxc", "tot", "neps", "minT", "maxc", "tot", "neps")
    for l in 1:(p.n_lines)
        minTs = minimum(EA[l] .* max.(0.0, dLsm[:, l] ./ L0[l]))
        minTt = minimum(EA[l] .* max.(0.0, dLtm[:, l] ./ L0[l]))
        @printf("l%d        | %7.2f %7.4f %7.2f %7d | %7.2f %7.4f %7.2f %7d\n",
            l, minTs, maxcs[l], tots[l], neps[l], minTt, maxct[l], tott[l], nept[l])
    end

    csv = joinpath(@__DIR__, "..", ".julia_depot", "logs", "bridle_check_fixed_ld0.05_dt1.csv")
    open(csv, "w") do io
        print(io, "t,hub_drift_mm,vtxD_mm")
        for l in 1:(p.n_lines)
            print(io, ",dLsim_l$(l)_mm,dLreader_l$(l)_mm")
        end
        println(io)
        for i in 1:NSAMP
            @printf(io, "%.5f,%.4f,%.4f", ts[i], 1000 * drifts[i], 1000 * vds[i])
            for l in 1:(p.n_lines)
                @printf(io, ",%.4f,%.4f", 1000 * dLsm[i, l], 1000 * dLtm[i, l])
            end
            println(io)
        end
    end
    @printf("\ncsv: %s\n=== done ===\n", csv)
end

main()

# scratch/probe_bridle_reader_check.jl
#
# DECISIVE CHECK (2026-09-20 late): are the six bridle-cone slack episodes seen by
# scratch/probe_wobble_gate_run.jl genuine in the sim's own force path, or an artefact
# of the reader frame?
#
# The tracker's bridle reader was copied from test/test_settle_validity.jl:62-79 and
# evaluates the ring attachment point in the VISUALIZATION "tilted ring basis"
# (geometry.jl:69-104 — a 0.1-scaled bearing-drift tilt, clamp 30 deg, used for the
# dashboard drawing). The model's force path uses the SHAFT frame for bridles by
# design (rope_forces.jl:196-197, 269, 280: "Bridles are kept in the shaft frame to
# prevent tilt->bridle->tilt feedback").
#
# Preload strain scale: bridles are cut for a design preload; stretch ~ T/EA * L0 is
# millimetres. Sub-millimetre length differences between the two frames therefore
# matter for a near-slack reading.
#
# Protocol: settle (n_op=300_000) -> relax 120 s @ lin_damp=0.05 -> sample 10 s at
# 10 ms computing, per line: T_sim (shaft frame, the applied force law) and T_reader
# (tilted basis, the tracker's reader). Slack stats (tracker-equivalent criteria)
# computed for BOTH frames, side by side.
#
# Self-asserting: hub ring_idx == Nr; exactly 6 bridle sub-segs; all finite inputs.
using KiteTurbineDynamics, LinearAlgebra, Statistics, Printf
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "test", "settle_case_builders.jl"))

pos(u, gid) = u[(3 * (gid - 1) + 1):(3 * gid)]

const THRESH = 1.0
const SAMPLE_DT = 0.01
const NSAMP = 1000
const LD = 0.05
const RELAX_S = 120.0

function main()
    sys, u0, p, lift, wf = build_case(nothing, nothing)
    N, Nr = sys.n_total, sys.n_ring
    hub_gid = sys.rotor.node_id
    bear_gid = sys.bearing_id
    hub_ri = (sys.nodes[hub_gid]::RingNode).ring_idx
    @assert hub_ri == Nr "hub ring_idx $(hub_ri) != Nr $(Nr)"
    node = sys.nodes[hub_gid]::RingNode
    R = isempty(sys.expansion_rotors) ? node.radius : sys.effective_radii[hub_ri]
    dt = KiteTurbineDynamics.stable_dt_for_system(sys, p)
    @printf("=== bridle reader check  git=%s ===\n", "9e40342")
    @printf("N=%d Nr=%d R_hub=%.4f m n_lines=%d dt=%.6g s\n", N, Nr, R, p.n_lines, dt)

    # Collect the six bridle sub-segs, per line_idx.
    L0v = fill(NaN, p.n_lines)
    EAv = fill(NaN, p.n_lines)
    for ss in sys.sub_segs
        na, nb = ss.end_a.node_id, ss.end_b.node_id
        ((na == bear_gid && nb == hub_gid) || (na == hub_gid && nb == bear_gid)) || continue
        ring_end = ss.end_a.is_ring ? ss.end_a : ss.end_b
        li = ring_end.line_idx
        L0v[li] = ss.length_0
        EAv[li] = ss.EA
    end
    @assert all(isfinite, L0v) "missing bridle line"
    @printf("bridle L0 (m):")
    for x in L0v
        @printf("  %.6f", x)
    end
    @printf("\n")
    @printf("bridle EA (N):")
    for x in EAv
        @printf("  %.0f", x)
    end
    @printf("\n")
    flush(stdout)

    t_s = @elapsed u = settle_to_operational_state(
        sys, copy(u0), p, 60.0; lift_device=lift, wind_fn=wf, n_op=300_000
    )
    @printf("settle wall = %.1f s\n", t_s)
    flush(stdout)

    sd0 = [cos(p.elevation_angle), 0.0, sin(p.elevation_angle)]

    # Per-line readings in both frames + diagnostics.
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
            dLs[l] = norm(bear .- pa_s) - L0v[l]
            dLt[l] = norm(bear .- pa_t) - L0v[l]
            vd = max(vd, norm(pa_s .- pa_t))
        end
        be = bear .- hub
        drift = norm(be .- dot(be, shaft_dir) .* shaft_dir)
        return dLs, dLt, vd, drift
    end

    # ── relax phase (breaks OFF) ─────────────────────────────────────────
    nrelax = round(Int, RELAX_S / dt)
    chunk = round(Int, 20.0 / dt)
    done = 0
    while done < nrelax
        n = min(chunk, nrelax - done)
        run_canonical_sim!(u, sys, p, wf, n, dt; lift_device=lift, lin_damp=LD)
        done += n
        dLs, dLt, vd, drift = readings(u)
        hub = pos(u, hub_gid)
        hl = norm(hub .- dot(hub, sd0) .* sd0)
        Ts = EAv .* max.(0.0, dLs ./ L0v)
        Tt = EAv .* max.(0.0, dLt ./ L0v)
        @printf("[relax] t=%6.1f  hub_lat=%.3f  drift=%.2fmm  vtxD=%.2fmm  T_sim=%7.1f  T_read=%7.1f\n",
            done * dt, hl, 1000 * drift, 1000 * vd, sum(Ts), sum(Tt))
        flush(stdout)
    end

    # ── sampling phase (breaks OFF; this is an instrument check) ─────────
    sample_every = max(1, round(Int, SAMPLE_DT / dt))
    Δ = sample_every * dt
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
        Ts = EAv .* max.(0.0, dLs ./ L0v)
        Tt = EAv .* max.(0.0, dLt ./ L0v)
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
        if i % 200 == 0
            @printf("[sample] %d/%d\n", i, NSAMP)
            flush(stdout)
        end
        i < NSAMP && run_canonical_sim!(u, sys, p, wf, sample_every, dt; lift_device=lift, lin_damp=LD)
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

    # ── summary ──────────────────────────────────────────────────────────
    @printf("\n=== BRIDLE READER CHECK SUMMARY ===\n")
    @printf("sampled %.2f s at Δ=%.5f s (lin_damp=%.2f)\n", NSAMP * Δ, Δ, LD)
    @printf("drift(perp bearing-hub): %.3f..%.3f mm   vertex |pa_sim-pa_reader| max %.3f mm\n",
        1000 * minimum(drifts), 1000 * maximum(drifts), 1000 * maximum(vds))
    @printf("dL_sim range (mm): %.3f..%.3f   dL_reader range (mm): %.3f..%.3f\n",
        1000 * minimum(dLsm), 1000 * maximum(dLsm), 1000 * minimum(dLtm), 1000 * maximum(dLtm))
    @printf("\n%-9s | %-34s | %-34s\n", "line", "SIM frame (force path)", "READER frame (tracker)")
    @printf("%-9s | %7s %7s %7s %7s | %7s %7s %7s %7s\n",
        "", "minT", "maxc", "tot", "neps", "minT", "maxc", "tot", "neps")
    for l in 1:(p.n_lines)
        minTs = minimum(EAv[l] .* max.(0.0, dLsm[:, l] ./ L0v[l]))
        minTt = minimum(EAv[l] .* max.(0.0, dLtm[:, l] ./ L0v[l]))
        @printf("l%d        | %7.2f %7.4f %7.2f %7d | %7.2f %7.4f %7.2f %7d\n",
            l, minTs, maxcs[l], tots[l], neps[l], minTt, maxct[l], tott[l], nept[l])
    end

    # Small time slice for line 1 (about one revolution: 0.47 s = ~47 samples)
    @printf("\nline 1 slice (first 50 samples): t, dL_sim_mm, dL_reader_mm\n")
    for i in 1:50
        @printf("  %6.3f  %8.3f  %8.3f\n", ts[i], 1000 * dLsm[i, 1], 1000 * dLtm[i, 1])
    end

    csv = joinpath(@__DIR__, "..", ".julia_depot", "logs", "bridle_check_ld0.05_dt1.csv")
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

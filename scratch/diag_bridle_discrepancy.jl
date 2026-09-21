# scratch/diag_bridle_discrepancy.jl
#
# One process, one trajectory: refresh-style vs newprobe-style bridle readers,
# side by side, with raw intermediate dumps. Purpose: localise the 283-N-steady
# vs ~53-N-cycling discrepancy between probe_wobble_refresh.jl and
# probe_bridle_reader_check.jl on the same nominal state (2026-09-21).
using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "test", "settle_case_builders.jl"))

pos(u, gid) = u[(3 * (gid - 1) + 1):(3 * gid)]

function refresh_reader(u, sys, p, N, Nr)
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

function refresh_line(u, sys, p, N, Nr, l)
    hub, bear = sys.rotor.node_id, sys.bearing_id
    pp1, pp2 = KiteTurbineDynamics._tilted_ring_basis(u, sys, hub, Nr)
    node = sys.nodes[hub]::RingNode
    R = isempty(sys.expansion_rotors) ? node.radius : sys.effective_radii[node.ring_idx]
    total = 0.0
    for ss in sys.sub_segs
        na, nb = ss.end_a.node_id, ss.end_b.node_id
        ((na == hub && nb == bear) || (na == bear && nb == hub)) || continue
        ring_end = ss.end_a.is_ring ? ss.end_a : ss.end_b
        ring_end.line_idx == l || continue
        pa = attachment_point(pos(u, hub), R, u[6N + Nr], ring_end.line_idx, p.n_lines, pp1, pp2)
        L = norm(pos(u, bear) .- pa)
        total += ss.EA * max(0.0, (L - ss.length_0) / ss.length_0)
    end
    return total
end

function refresh_line_LT(u, sys, p, N, Nr, l)
    hub, bear = sys.rotor.node_id, sys.bearing_id
    pp1, pp2 = KiteTurbineDynamics._tilted_ring_basis(u, sys, hub, Nr)
    node = sys.nodes[hub]::RingNode
    R = isempty(sys.expansion_rotors) ? node.radius : sys.effective_radii[node.ring_idx]
    T = 0.0
    Llast = 0.0
    nss = 0
    for ss in sys.sub_segs
        na, nb = ss.end_a.node_id, ss.end_b.node_id
        ((na == hub && nb == bear) || (na == bear && nb == hub)) || continue
        ring_end = ss.end_a.is_ring ? ss.end_a : ss.end_b
        ring_end.line_idx == l || continue
        pa = attachment_point(pos(u, hub), R, u[6N + Nr], ring_end.line_idx, p.n_lines, pp1, pp2)
        L = norm(pos(u, bear) .- pa)
        Llast = L
        nss += 1
        T += ss.EA * max(0.0, (L - ss.length_0) / ss.length_0)
    end
    return Llast, T, nss
end

function main()
    sys, u0, p, lift, wf = build_case(nothing, nothing)
    N, Nr = sys.n_total, sys.n_ring
    hub_gid = sys.rotor.node_id
    bear_gid = sys.bearing_id
    hub_ri = (sys.nodes[hub_gid]::RingNode).ring_idx
    dt = KiteTurbineDynamics.stable_dt_for_system(sys, p)
    @printf("N=%d Nr=%d hub_gid=%d bear_gid=%d sky=%d hub_ri=%d n_expansion=%d dt=%.6g\n",
        N, Nr, hub_gid, bear_gid, sys.sky_anchor_id, hub_ri, length(sys.expansion_rotors), dt)
    @printf("effective_radii:")
    for x in sys.effective_radii
        @printf(" %.4f", x)
    end
    @printf("\n")

    subs = Tuple{Any, Int}[]
    for ss in sys.sub_segs
        na, nb = ss.end_a.node_id, ss.end_b.node_id
        ((na == bear_gid && nb == hub_gid) || (na == hub_gid && nb == bear_gid)) || continue
        ring_end = ss.end_a.is_ring ? ss.end_a : ss.end_b
        push!(subs, (ss, ring_end.line_idx))
    end
    @printf("bridle subs: %d\n", length(subs))
    for (ss, lj) in subs
        @printf("  sub lj=%d L0=%.9f EA=%.0f enda=(gid=%d ring=%s) endb=(gid=%d ring=%s)\n",
            lj, ss.length_0, ss.EA, ss.end_a.node_id, string(ss.end_a.is_ring),
            ss.end_b.node_id, string(ss.end_b.is_ring))
    end
    L0v = zeros(p.n_lines)
    EAv = zeros(p.n_lines)
    for (ss, lj) in subs
        L0v[lj] = ss.length_0
        EAv[lj] = ss.EA
    end

    R = isempty(sys.expansion_rotors) ? (sys.nodes[hub_gid]::RingNode).radius :
        sys.effective_radii[hub_ri]
    @printf("R=%.6f node.radius=%.6f eff[hub_ri]=%.6f\n", R,
        (sys.nodes[hub_gid]::RingNode).radius, sys.effective_radii[hub_ri])
    boff = KiteTurbineDynamics.bridle_bearing_offset(R)
    @printf("bearing_offset(R)=%.6f  design gap=%.6f  L0v[1]=%.6f\n",
        boff, sqrt(boff^2 + R^2), L0v[1])

    @printf("slot dump PRE-settle 6N+1..6N+2Nr:")
    for j in 1:(2 * Nr)
        @printf(" %.4f", u0[6N + j])
    end
    @printf("\n")
    flush(stdout)

    u = settle_to_operational_state(sys, copy(u0), p, 60.0; lift_device=lift, wind_fn=wf, n_op=300_000)
    @printf("post-settle live L0s:")
    for (ss, _) in subs
        @printf(" %.9f", ss.length_0)
    end
    @printf("\n")
    @printf("slot dump POST-settle:")
    for j in 1:(2 * Nr)
        @printf(" %.4f", u[6N + j])
    end
    @printf("\n\n")
    flush(stdout)

    chunk = round(Int, 0.5 / dt)
    for k in 0:20
        k > 0 && run_canonical_sim!(u, sys, p, wf, chunk, dt; lift_device=lift, lin_damp=0.05)
        t = k * 0.5
        Tr = refresh_reader(u, sys, p, N, Nr)
        hub = pos(u, hub_gid)
        bear = pos(u, bear_gid)
        pp1r, pp2r = KiteTurbineDynamics._tilted_ring_basis(u, sys, hub_gid, Nr)
        pp1t, pp2t = KiteTurbineDynamics._tilted_ring_basis(u, sys, hub_gid, hub_ri)
        basisdiff = max(norm(pp1r .- pp1t), norm(pp2r .- pp2t))
        Tn = zeros(p.n_lines)
        for l in 1:(p.n_lines)
            pa_n = attachment_point(hub, R, u[6N + hub_ri], l, p.n_lines, pp1t, pp2t)
            Tn[l] = EAv[l] * max(0.0, (norm(bear .- pa_n) - L0v[l]) / L0v[l])
        end
        @printf("t=%4.1f  Tref=%9.3f  Tnp=%9.3f  |dpp|=%.2e  alpha=%.6f (mod %.4f)\n",
            t, Tr, sum(Tn), basisdiff, u[6N + Nr], mod(u[6N + Nr], 2π))
        if k in (0, 1, 2, 4)
            for l in 1:(p.n_lines)
                Lr, Trl, nss = refresh_line_LT(u, sys, p, N, Nr, l)
                pa_n = attachment_point(hub, R, u[6N + hub_ri], l, p.n_lines, pp1t, pp2t)
                Ln = norm(bear .- pa_n)
                Tn_l = EAv[l] * max(0.0, (Ln - L0v[l]) / L0v[l])
                @printf("   l%d nss=%d  Lr=%.7f Ln=%.7f  dLr=%+.4f dLn=%+.4f  Tr=%9.3f Tn=%9.3f\n",
                    l, nss, Lr, Ln, 1000 * (Lr - L0v[l]), 1000 * (Ln - L0v[l]), Trl, Tn_l)
            end
        end
        flush(stdout)
    end

    # dense 2 s: per-line slack duty comparison for both readers, same trajectory
    @printf("\ndense phase: 2 s at ~10 ms, per-line T<1N fraction + min\n")
    se = max(1, round(Int, 0.01 / dt))
    nsl_r = zeros(p.n_lines)
    nsl_n = zeros(p.n_lines)
    min_r = fill(Inf, p.n_lines)
    min_n = fill(Inf, p.n_lines)
    for i in 1:200
        hub = pos(u, hub_gid)
        bear = pos(u, bear_gid)
        pp1t, pp2t = KiteTurbineDynamics._tilted_ring_basis(u, sys, hub_gid, hub_ri)
        for l in 1:(p.n_lines)
            Trl = refresh_line(u, sys, p, N, Nr, l)
            pa_n = attachment_point(hub, R, u[6N + hub_ri], l, p.n_lines, pp1t, pp2t)
            Tnl = EAv[l] * max(0.0, (norm(bear .- pa_n) - L0v[l]) / L0v[l])
            Trl < 1.0 && (nsl_r[l] += 1)
            Tnl < 1.0 && (nsl_n[l] += 1)
            min_r[l] = min(min_r[l], Trl)
            min_n[l] = min(min_n[l], Tnl)
        end
        i < 200 && run_canonical_sim!(u, sys, p, wf, se, dt; lift_device=lift, lin_damp=0.05)
        i % 50 == 0 && (println("[dense] $i/200"); flush(stdout))
    end
    @printf("\n%-6s %12s %12s %12s %12s\n", "line", "duty_ref", "duty_np", "min_ref", "min_np")
    for l in 1:(p.n_lines)
        @printf("l%d     %11.3f %12.3f %12.3f %12.3f\n",
            l, nsl_r[l] / 200, nsl_n[l] / 200, min_r[l], min_n[l])
    end
    println("=== done ===")
end

main()

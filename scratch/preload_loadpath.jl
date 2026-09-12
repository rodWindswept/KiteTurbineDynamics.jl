# scratch/preload_loadpath.jl
#
# READ-ONLY. Dumps the axial force balance NODE BY NODE for the airborne assembly
# on the state the settle returns, so the load path is measured rather than
# inferred. Answers: which link carries the transmission load -- the bridles, the
# cyan line, or nothing?
#
# Topology (src/initialization.jl:174-218, 230-243):
#   ground ring(1) ... rings ... hub(153)
#   hub --bridles(6)--> bearing(154) --cyan(1)--> sky anchor(155) --lift line--> kite
#   back line: ground back-anchor --(catenary)--> sky anchor
#
#   scripts/ktd-julia scratch/preload_loadpath.jl

using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "test", "test_settle_preload_consistency.jl"))

pos(u, gid) = u[(3 * (gid - 1) + 1):(3 * gid)]

function attach(u, sys, p, se, pp1, pp2, N, Nr)
    if se.is_ring
        node = sys.nodes[se.node_id]::RingNode
        R = isempty(sys.expansion_rotors) ? node.radius : sys.effective_radii[node.ring_idx]
        return attachment_point(pos(u, se.node_id), R, u[6N + node.ring_idx],
                                se.line_idx, p.n_lines, pp1, pp2)
    else
        return pos(u, se.node_id)
    end
end

function main()
    sys, u0, p, lift, wf = build_case(nothing, nothing)
    N, Nr = sys.n_total, sys.n_ring
    hub, bear, sky = sys.rotor.node_id, sys.bearing_id, sys.sky_anchor_id
    u = settle_to_operational_state(sys, u0, p, 60.0;
        lift_device=lift, wind_fn=wf, n_op=2_000)
    sd = normalize(pos(u, hub))
    @printf("hub=%d bearing=%d sky=%d   N=%d  n_sub_segs=%d\n",
        hub, bear, sky, N, length(sys.sub_segs))

    # ── sub-segments touching the airborne assembly ────────────────────────────
    println("\nSub-segments touching hub / bearing / sky anchor:")
    @printf("  %4s %-10s %-10s %12s %12s %12s %12s  %s\n",
        "idx", "end_a", "end_b", "L0_m", "achieved_m", "EA_N", "T_N", "role")
    for (i, ss) in enumerate(sys.sub_segs)
        na, nb = ss.end_a.node_id, ss.end_b.node_id
        (na == hub || nb == hub || na == bear || nb == bear ||
         na == sky || nb == sky) || continue
        L = norm(pos(u, nb) .- pos(u, na))
        strain = (L - ss.length_0) / ss.length_0
        T = ss.EA * max(0.0, strain)
        role = (na == hub || nb == hub) ? "HUB-LINK" :
               ((na == sky || nb == sky) && (na == bear || nb == bear)) ? "CYAN" :
               (na == bear || nb == bear) ? "BRIDLE" : "SKY-LINK"
        @printf("  %4d %-10s %-10s %12.6f %12.6f %12.4g %12.4f  %s\n",
            i, "node$na", "node$nb", ss.length_0, L, ss.EA, T, role)
    end

    # ── net force on each airborne node ───────────────────────────────────────
    du = zeros(length(u))
    KiteTurbineDynamics.multibody_ode!(du, u, (sys, p, wf, lift), 0.0)
    println("\nNet force and its axial component:")
    for (nm, gid) in (("hub", hub), ("bearing", bear), ("sky", sky))
        m = (sys.nodes[gid]).mass
        F = m .* du[(3N + 3 * (gid - 1) + 1):(3N + 3 * gid)]
        @printf("  %-8s m=%6.3f kg  F=[%+9.4f %+9.4f %+9.4f]  |F|=%8.4f  axial=%+9.4f N\n",
            nm, m, F..., norm(F), dot(F, sd))
    end

    # ── the six uppermost transmission lines, axially ─────────────────────────
    println("\nUppermost transmission segment (ring 8 -> hub), axial component per line:")
    pp1, pp2 = KiteTurbineDynamics._tilted_ring_basis(u, sys, hub, Nr)
    s = Nr - 1
    tot_ax = 0.0
    tot_T = 0.0
    for j in 1:p.n_lines
        pa = attach(u, sys, p, sys.sub_segs[(s - 1) * p.n_lines * ROPE_SUBSEGS + j].end_a,
                    pp1, pp2, N, Nr)
        pb = attach(u, sys, p, sys.sub_segs[(s - 1) * p.n_lines * ROPE_SUBSEGS + j].end_b,
                    pp1, pp2, N, Nr)
        ss = sys.sub_segs[(s - 1) * p.n_lines * ROPE_SUBSEGS + j]
        L = norm(pb .- pa)
        T = ss.EA * max(0.0, (L - ss.length_0) / ss.length_0)
        ax = T * dot((pb .- pa) ./ L, sd)
        tot_T += T
        tot_ax += ax
    end
    @printf("  sum T = %.3f N   sum axial(up) = %+.3f N  (n_lines=%d)\n",
        tot_T, tot_ax, p.n_lines)
    println()
end

main()

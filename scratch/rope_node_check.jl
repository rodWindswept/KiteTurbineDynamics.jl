# scratch/rope_node_check.jl
#
# READ-ONLY. Measures the ROPE NODE placement against the sub-segment rest lengths
# for one full line of the top segment, on the settled campaign seed.
#
# Why: `settle_to_operational_state` places the ROPE_NODES_PER_LINE interior nodes
# of each line at EQUAL FRACTIONS of the 3D chord between the two attachment
# points.  The sub-segment rest lengths come from the builder's untwisted design
# segment length.  If the twisted chord differs from the sum of the rest lengths,
# the lines are placed stretched (or slack), which corrupts every force reading.
#
# This pins down the actual numbers for line 1 of the top segment.
#
#   scripts/ktd-julia scratch/rope_node_check.jl

using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "test", "test_settle_preload_consistency.jl"))

pos(u, gid) = u[(3 * (gid - 1) + 1):(3 * gid)]

function main()
    sys, u0, p, lift, wf = build_case(nothing, nothing)
    N, Nr = sys.n_total, sys.n_ring
    hub = sys.rotor.node_id
    u = settle_to_operational_state(sys, u0, p, 60.0;
        lift_device=lift, wind_fn=wf, n_op=2_000)
    pp1, pp2 = KiteTurbineDynamics._tilted_ring_basis(u, sys, hub, Nr)

    seg = Nr - 1                     # top segment
    gid_a = sys.ring_ids[seg]        # lower ring
    gid_b = sys.ring_ids[seg + 1]    # hub
    na = sys.nodes[gid_a]::RingNode
    nb = sys.nodes[gid_b]::RingNode
    L = ROPE_SUBSEGS * sys.sub_segs[(seg - 1) * p.n_lines * ROPE_SUBSEGS + 1].length_0

    @printf("top segment %d: lower ring %d (r=%.4f) -> hub %d (r=%.4f)\n",
        seg, gid_a, na.radius, gid_b, nb.radius)
    @printf("segment length used by the builder (4 x length_0) = %.6f m\n\n", L)

    for j in (1, 2)
        @printf("line %d:\n", j)
        pa = attachment_point(pos(u, gid_a), na.radius, u[6N + seg], j, p.n_lines, pp1, pp2)
        pb = attachment_point(pos(u, gid_b), nb.radius, u[6N + seg + 1], j, p.n_lines, pp1, pp2)
        @printf("  chord |pa->pb| = %.6f m   axial gap along shaft = %.6f m\n",
            norm(pb .- pa), abs(dot(pb .- pa, normalize(pos(u, hub)))))
        # walk the four sub-segments of this line in storage order
        base = (seg - 1) * p.n_lines * ROPE_SUBSEGS + (j - 1) * ROPE_SUBSEGS
        total_rest = 0.0
        total_ach = 0.0
        @printf("  %4s %-12s %10s %12s %12s %14s\n",
            "idx", "link", "rest_m", "achieved_m", "ratio", "T_N (EA=1.047e6)")
        for k in 1:ROPE_SUBSEGS
            ss = sys.sub_segs[base + k]
            qa = ss.end_a.is_ring ? pa : pos(u, ss.end_a.node_id)
            qb = ss.end_b.is_ring ? pb : pos(u, ss.end_b.node_id)
            ach = norm(qb .- qa)
            T = ss.EA * max(0.0, (ach - ss.length_0) / ss.length_0)
            total_rest += ss.length_0
            total_ach += ach
            @printf("  %4d %-12s %10.6f %12.6f %12.4f %14.3f\n",
                base + k,
                (ss.end_a.is_ring ? "RING" : "n$(ss.end_a.node_id)") * "->" *
                (ss.end_b.is_ring ? "RING" : "n$(ss.end_b.node_id)"),
                ss.length_0, ach, ach / ss.length_0, T)
        end
        @printf("  TOTAL rest = %.6f m ; TOTAL achieved = %.6f m ; mean ratio = %.4f\n",
            total_rest, total_ach, total_ach / total_rest)
        @printf("  -> total provided by builder to _matched_place_twist = %.6f m\n\n", L)
    end
end

main()

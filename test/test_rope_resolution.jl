# test/test_rope_resolution.jl
# Guard for the rope-discretisation parameterisation (2026-09-10).
#
# The line/shaft was discretised with hardcoded 3 interior nodes (4 sub-segments)
# per ring gap in ~25 index sites.  `ROPE_SUBSEGS` in `src/types.jl` is now the
# single authority.  This test pins the node/sub-segment counts to the constant,
# so a future edit that re-hardcodes a 3/4/5 anywhere fails loudly instead of
# silently mis-indexing the state vector.
using Test, KiteTurbineDynamics

@testset "rope discretisation — node/sub-segment counts follow ROPE_SUBSEGS" begin
    p = params_daisy()
    sys, u0 = build_kite_turbine_system(p)
    n_seg = p.n_rings + 1
    n_ring = n_seg + 1

    @test ROPE_NODES_PER_LINE == ROPE_SUBSEGS - 1
    @test sys.n_ring == n_ring
    @test sys.n_total == n_ring + p.n_lines * ROPE_NODES_PER_LINE * n_seg + 2
    @test length(u0) == 6 * sys.n_total + 2 * sys.n_ring

    # TRPT sub-segments + one bridle per line + the single cyan line.
    @test length(sys.sub_segs) ==
          n_seg * p.n_lines * ROPE_SUBSEGS + p.n_lines + 1

    # Every node slot is populated (a hardcoded loop bound leaves gaps).
    @test all(i -> isassigned(sys.nodes, i), 1:sys.n_total)

    # Each TRPT line is a ring→node→…→node→ring chain of ROPE_SUBSEGS sub-segs.
    for j in 1:p.n_lines
        ends = [sys.sub_segs[(1 - 1) * p.n_lines * ROPE_SUBSEGS + (j - 1) * ROPE_SUBSEGS + k]
                for k in 1:ROPE_SUBSEGS]
        @test ends[1].end_a.is_ring
        @test ends[end].end_b.is_ring
        @test all(ss -> !ss.end_a.is_ring && !ss.end_b.is_ring, ends[2:(end - 1)])
    end
end

println("\n✓ rope-resolution guard complete")

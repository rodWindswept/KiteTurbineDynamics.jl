@testset "types and node counts" begin
    p = params_10kw()
    sys, u0 = build_kite_turbine_system(p)

    # Node counts
    n_ring  = p.n_rings + 2          # ground + 14 rings + hub = 16
    n_rope  = p.n_lines * 3 * (p.n_rings + 1)  # 5 * 3 * 15 = 225
    n_total = n_ring + n_rope        # 241

    @test length(sys.nodes) == n_total
    @test count(n -> isa(n, RingNode), sys.nodes) == n_ring
    @test count(n -> isa(n, RopeNode), sys.nodes) == n_rope

    # State size
    @test state_size(sys) == 6 * n_total + 2 * n_ring  # 1478

    # ring_idx values are 1:n_ring without gaps
    ring_nodes = filter(n -> isa(n, RingNode), sys.nodes)
    idxs = sort([n.ring_idx for n in ring_nodes])
    @test idxs == collect(1:n_ring)

    # Ground node is fixed
    @test sys.nodes[1].is_fixed == true

    # Hub node is last RingNode (node at global id 241)
    hub = sys.nodes[sys.ring_ids[end]]
    @test isa(hub, RingNode)
    @test hub.is_fixed == false

    # sub_segs count: 4 sub-segs × 5 lines × 15 segments = 300
    @test length(sys.sub_segs) == 300
end

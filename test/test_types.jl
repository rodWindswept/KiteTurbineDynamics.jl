@testset "types and node counts" begin
    p = params_10kw()
    sys, u0 = build_kite_turbine_system(p)

    # Node counts (includes bearing + hub vertex nodes)
    n_ring     = p.n_rings + 2           # ground + 14 rings + hub = 16
    n_rope     = p.n_lines * 3 * (p.n_rings + 1)  # 5 * 3 * 15 = 225
    n_vertices = p.n_lines               # hub vertex nodes = 5
    n_bearing  = 1
    n_total    = n_ring + n_rope + n_vertices + n_bearing  # 247

    @test length(sys.nodes) == n_total
    @test count(n -> isa(n, RingNode), sys.nodes) == n_ring
    @test count(n -> isa(n, RopeNode), sys.nodes) == n_rope
    @test count(n -> isa(n, HubVertexNode), sys.nodes) == n_vertices
    @test count(n -> isa(n, BearingNode), sys.nodes) == 1

    # State size: 6 DOF per node + 2 twist states per ring
    @test state_size(sys) == 6 * n_total + 2 * n_ring

    # ring_idx values are 1:n_ring without gaps
    ring_nodes = filter(n -> isa(n, RingNode), sys.nodes)
    idxs = sort([n.ring_idx for n in ring_nodes])
    @test idxs == collect(1:n_ring)

    # Ground node is fixed
    @test sys.nodes[1].is_fixed == true

    # Hub node is last RingNode
    hub = sys.nodes[sys.ring_ids[end]]
    @test isa(hub, RingNode)
    @test hub.is_fixed == false

    # Bearing node exists
    @test sys.bearing_id > 0
    bearing = sys.nodes[sys.bearing_id]
    @test isa(bearing, BearingNode)

    # Hub vertex IDs populated
    @test length(sys.hub_vertex_ids) == n_vertices
    for v_gid in sys.hub_vertex_ids
        @test isa(sys.nodes[v_gid], HubVertexNode)
    end

    # sub_segs: TRPT(4×5×15=300) + spokes(5) + beams(5) + diagonals(5) + bridles(5) = 320
    n_spokes_beams = 3 * p.n_lines  # spokes + sides + diagonals
    @test length(sys.sub_segs) == (4 * p.n_lines * (p.n_rings + 1)) + n_spokes_beams + p.n_lines
end

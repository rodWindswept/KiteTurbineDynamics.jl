using LinearAlgebra

@testset "rope sag in zero wind" begin
    p_low = params_10kw()  # zero wind — pure gravity sag

    sys, u0 = build_kite_turbine_system(p_low)
    u_settled = settle_to_equilibrium(sys, u0, p_low)

    # Compute sag as perpendicular distance from the straight chord between
    # ring attachment points (not z-difference from ring centres — rings are
    # tilted at the elevation angle, so centre-z is not the attachment-point z).
    N  = sys.n_total
    β  = p_low.elevation_angle
    shaft_dir = [cos(β), 0.0, sin(β)]
    perp1, perp2 = shaft_perp_basis(shaft_dir)

    # Segment 1: ground ring → first intermediate ring
    gid_a = sys.ring_ids[1]
    gid_b = sys.ring_ids[2]
    na = sys.nodes[gid_a]::RingNode
    nb = sys.nodes[gid_b]::RingNode
    ctr_a = u_settled[3*(gid_a-1)+1 : 3*gid_a]
    ctr_b = u_settled[3*(gid_b-1)+1 : 3*gid_b]
    α_a = u_settled[6N + na.ring_idx]
    α_b = u_settled[6N + nb.ring_idx]

    # Line 1 attachment points
    pa = attachment_point(ctr_a, na.radius, α_a, 1, p_low.n_lines, perp1, perp2)
    pb = attachment_point(ctr_b, nb.radius, α_b, 1, p_low.n_lines, perp1, perp2)

    # Middle rope node on line 1 (sub_idx=2, gid=3)
    gid_mid = 3   # (1-1)*16 + 2 + (1-1)*3 + (2-1) = 3
    pm = u_settled[3*(gid_mid-1)+1 : 3*gid_mid]

    # Perpendicular distance from the straight chord pa→pb
    AB = pb .- pa
    len2 = dot(AB, AB)
    @test len2 > 1e-18
    foot = pa .+ (dot(pm .- pa, AB) / len2) .* AB
    sag_mm = norm(pm .- foot) * 1000.0

    # Rope should sag under gravity — any positive sag confirms the physics
    @test sag_mm > 0.0
end

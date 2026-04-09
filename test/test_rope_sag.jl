using LinearAlgebra

@testset "rope sag in zero wind" begin
    p_low = SystemParams(
        params_10kw().rho,
        0.5,   # near-zero wind
        params_10kw().h_ref,
        params_10kw().elevation_angle,
        params_10kw().lifter_elevation,
        params_10kw().rotor_radius,
        params_10kw().tether_length,
        params_10kw().trpt_hub_radius,
        params_10kw().trpt_rL_ratio,
        params_10kw().n_lines,
        params_10kw().tether_diameter,
        params_10kw().e_modulus,
        params_10kw().n_rings,
        params_10kw().m_ring,
        params_10kw().n_blades,
        params_10kw().m_blade,
        params_10kw().cp,
        params_10kw().i_pto,
        params_10kw().k_mppt,
        params_10kw().p_rated_w,
        params_10kw().β_min,
        params_10kw().β_max,
        params_10kw().β_rate_max,
        params_10kw().kp_elev,
        params_10kw().EA_back_line,
        params_10kw().c_back_line,
        params_10kw().back_anchor_fwd_x,
    )
    sys, u0 = build_kite_turbine_system(p_low)
    u_settled = settle_to_equilibrium(sys, u0, p_low)

    # Rope sub-node in seg=1, line=1, sub=2 has global id = (1-1)*16 + 2 + (1-1)*3 + (2-1) = 3
    # This is the second intermediate node on line 1 of segment 1
    seg1_rope_sub2_gid = 3
    rope_z = u_settled[3*(seg1_rope_sub2_gid-1)+3]

    # The ring at the top of segment 1 (ring_ids[2])
    ring1_gid = sys.ring_ids[2]
    ring1_z   = u_settled[3*(ring1_gid-1)+3]
    gnd_z     = u_settled[3]      # ground z (should be 0)
    midline_z = (gnd_z + ring1_z) / 2.0

    # Rope node should sag below the straight line between rings
    @test rope_z < midline_z
end

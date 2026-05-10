using LinearAlgebra

@testset "rope forces" begin
    p   = params_10kw()
    sys, u0 = build_kite_turbine_system(p)
    N   = sys.n_total
    Nr  = sys.n_ring

    forces  = [zeros(3) for _ in 1:N]
    torques = zeros(Nr)
    ring_torques_3d = [zeros(3) for _ in 1:Nr]

    # zero wind, zero velocity, straight-line init
    wind_fn = (pos, t) -> [0.0, 0.0, 0.0]
    alpha   = zeros(Nr)

    # Shaft direction from hub position; no tilt at t=0
    hub_gid  = sys.rotor.node_id
    hub_pos  = u0[3*(hub_gid-1)+1 : 3*hub_gid]
    shaft_dir = normalize(hub_pos)
    perp1, perp2 = shaft_perp_basis(shaft_dir)

    compute_rope_forces!(forces, torques, u0, alpha, sys, p, wind_fn, 0.0,
                          ring_torques_3d, perp1, perp2)

    # At rest on straight line with zero twist and zero velocity: no stretch,
    # no damping contribution → net forces on interior rope nodes should be ~0
    # Pick rope node gid=2 (seg=1, line=1, sub=1) and check force is ~0
    @test norm(forces[2]) < 1e-6

    # At zero twist, net torque on all rings should be ~0
    @test maximum(abs.(torques)) < 1e-6
end

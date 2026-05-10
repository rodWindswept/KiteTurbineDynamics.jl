using LinearAlgebra

@testset "rope forces" begin
    p   = params_10kw()
    sys, u0 = build_kite_turbine_system(p)
    N   = sys.n_total
    Nr  = sys.n_ring

    forces  = [zeros(3) for _ in 1:N]
    torques = zeros(Nr)

    # zero wind, zero velocity, straight-line init
    wind_fn = (pos, t) -> [0.0, 0.0, 0.0]
    alpha   = zeros(Nr)

    compute_rope_forces!(forces, torques, u0, alpha, sys, p, wind_fn, 0.0)

    # At rest on straight line with zero twist and zero velocity: no stretch,
    # no damping contribution → net forces on interior rope nodes should be ~0
    # Pick rope node gid=2 (seg=1, line=1, sub=1) and check force is ~0
    @test norm(forces[2]) < 1e-6

    # At zero twist, net torque on all rings should be ~0
    @test maximum(abs.(torques)) < 1e-6
end

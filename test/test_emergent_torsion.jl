using LinearAlgebra

@testset "emergent torsion" begin
    p   = params_10kw()
    sys, u0 = build_kite_turbine_system(p)

    Nr = sys.n_ring
    N  = sys.n_total
    alpha = zeros(Nr)
    alpha[2] = 0.1   # 0.1 rad twist on ring 1 (ring_idx=2)

    forces  = [zeros(3) for _ in 1:N]
    torques = zeros(Nr)
    wind_fn = (pos, t) -> [0.0, 0.0, 0.0]

    # Inject twist into state vector
    u_test = copy(u0)
    u_test[6N+2] = 0.1   # alpha[2] = 0.1 rad

    compute_rope_forces!(forces, torques, u_test, alpha, sys, p, wind_fn, 0.0)

    # Torque on ring 1 (ring_idx=2) should oppose the twist (restoring torque)
    @test torques[2] < 0.0   # negative = opposing positive twist

    # Ground ring torque: with rope nodes held at zero-twist positions and only ring 1
    # twisted, the lower sub-segments are nearly parallel to the shaft → cross-product
    # with shaft_dir is ~0. The ground reaction is emergent only with full twist propagation.
    # Check that it is non-negative (not a spurious negative restoring torque).
    @test torques[1] >= -1e-10
end

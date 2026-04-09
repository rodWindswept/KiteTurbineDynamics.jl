using LinearAlgebra

@testset "ring forces" begin
    p   = params_10kw()
    sys, u0 = build_kite_turbine_system(p)
    N   = sys.n_total
    Nr  = sys.n_ring

    forces  = [zeros(3) for _ in 1:N]
    torques = zeros(Nr)
    omega   = zeros(Nr)

    wind_fn = (pos, t) -> [p.v_wind_ref, 0.0, 0.0]

    compute_ring_forces!(forces, torques, u0, omega, sys, p, wind_fn, 0.0)

    hub_gid = sys.rotor.node_id
    # CT thrust is the only aerodynamic hub force (kite-style CL removed — see ring_forces.jl).
    # At rated wind (11 m/s) the thrust magnitude is large; the hub node must have a
    # non-zero finite force vector with a non-negative X component (downwind component
    # of thrust along the tether axis).
    @test forces[hub_gid][1] > 0      # downwind thrust component always positive
    @test all(isfinite, forces[hub_gid])

    # No NaN anywhere
    hub_ring_idx = (sys.nodes[hub_gid]::RingNode).ring_idx
    @test !isnan(torques[hub_ring_idx])
    @test all(isfinite, forces[hub_gid])
end

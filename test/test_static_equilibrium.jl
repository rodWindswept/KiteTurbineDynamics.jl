using LinearAlgebra

@testset "static equilibrium" begin
    p   = params_10kw()
    sys, u0 = build_kite_turbine_system(p)
    u_settled = settle_to_equilibrium(sys, u0, p)

    N  = sys.n_total
    Nr = sys.n_ring

    # Hub should be above ground
    hub_gid = sys.rotor.node_id
    hub_z   = u_settled[3*(hub_gid-1)+3]
    @test hub_z > 5.0

    # No node should be unreasonably below ground.
    # The inclined TRPT geometry places some ring attachment points at negative z
    # (lower attachment circle dips below the ground plane), so a generous floor is used.
    for i in 2:N
        z = u_settled[3*(i-1)+3]
        @test z >= -3.0   # allow for TRPT geometry and settling overshoot
    end

    # All velocities should be near zero after settling
    vels = u_settled[3N+1 : 6N]
    @test maximum(abs.(vels)) < 1.0
end

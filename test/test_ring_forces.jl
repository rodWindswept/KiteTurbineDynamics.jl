using LinearAlgebra

@testset "ring forces" begin
    p = params_10kw()
    sys, u0 = build_kite_turbine_system(p)
    N = sys.n_total
    Nr = sys.n_ring

    forces = [zeros(3) for _ in 1:N]
    torques = zeros(Nr)
    omega = zeros(Nr)

    wind_fn = (pos, t) -> [p.v_wind_ref, 0.0, 0.0]
    ld = rotary_lifter_default()

    compute_ring_forces!(forces, torques, u0, omega, sys, p, wind_fn, 0.0, ld)

    hub_gid = sys.rotor.node_id

    # At zero omega, CT thrust is zero (ct_at_tsr(0) = 0).
    @test all(isfinite, forces[hub_gid])

    # After 2026-05-12 sky-anchor change: lift + back-line forces apply at the
    # SKY ANCHOR, not the bearing.  The bearing only sees those forces
    # transmitted via the cyan line, which is computed in compute_rope_forces!
    # (not exercised here).  So compute_ring_forces! alone leaves the bearing
    # untouched and loads the sky anchor.
    bearing_gid = sys.bearing_id
    sky_anchor_gid = sys.sky_anchor_id
    @test all(iszero, forces[bearing_gid])      # bearing untouched here
    @test !all(iszero, forces[sky_anchor_gid])   # sky anchor takes the lift
    @test all(isfinite, forces[sky_anchor_gid])

    # No NaN in torques
    hub_ring_idx = (sys.nodes[hub_gid]::RingNode).ring_idx
    @test !isnan(torques[hub_ring_idx])
end

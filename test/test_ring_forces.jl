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

@testset "main-rotor bank derate" begin
    # The measured bank derate (AeroDyn precone sweep, 2026-09-30 / 2026-10-01):
    # a banked rotor keeps cos(bank)^2.65 of its disc power.  Two systems that
    # differ only in the bank gene must have disc torques in exactly that ratio,
    # because the wind, the radius, the tip-speed ratio, the Cp lookup and the
    # elevation factor are all identical between them.
    p = params_10kw()
    sys_planar, u_planar = build_kite_turbine_system(p; main_rotor_bank_deg=0.0)
    sys_bank20, u_bank20 = build_kite_turbine_system(p; main_rotor_bank_deg=20.0)

    # The default must stay planar, so no existing caller moves.
    sys_default, _ = build_kite_turbine_system(p)
    @test sys_default.rotor.bank_angle_deg == 0.0

    N = sys_planar.n_total
    Nr = sys_planar.n_ring
    wind_fn = (pos, t) -> [p.v_wind_ref, 0.0, 0.0]
    ld = rotary_lifter_default()
    hub_ring_idx = (sys_planar.nodes[sys_planar.rotor.node_id]::RingNode).ring_idx

    function disc_torque(sys, u0)
        forces = [zeros(3) for _ in 1:N]
        torques = zeros(Nr)
        # A UNIFORM omega, so every inter-ring Δω is zero and the torsional damper
        # (c_s·Δω, written to the same torques slot) contributes nothing.  Then
        # torques[hub_ring_idx] is the disc torque alone.  With one ring spinning
        # and the rest still, the damper dominates and the ratio is not the bank
        # factor at all (measured: 0.796 against the true 0.848).
        omega = fill(10.0, Nr)            # positive spin => the generating branch
        compute_ring_forces!(forces, torques, u0, omega, sys, p, wind_fn, 0.0, ld)
        return torques[hub_ring_idx]
    end

    tau_planar = disc_torque(sys_planar, u_planar)
    tau_bank20 = disc_torque(sys_bank20, u_bank20)

    @test tau_planar > 0.0
    @test tau_bank20 < tau_planar              # bank costs power, it never adds it
    @test tau_bank20 / tau_planar ≈ cosd(20.0)^2.65 rtol = 1e-9

    # The measured retention at 20 deg is 0.854, so bank costs about 15 per cent.
    # A bare disc model would give 0.000 and the banned expansion model 0.853.
    @test 0.14 < 1.0 - tau_bank20 / tau_planar < 0.16
end

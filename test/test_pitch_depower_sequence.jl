@testset "pitch depower sequence and compliant winch" begin
    p   = params_10kw()
    sys, u0 = build_kite_turbine_system(p)
    ld  = rotary_lifter_default()

    vref = 11.0
    wind_fn = (pos, t) -> begin
        z  = max(pos[3], 1.0)
        [vref * (z / p.h_ref)^(1.0/7.0), 0.0, 0.0]
    end

    # Settle to operational state
    u_start = settle_to_operational_state(sys, u0, p, 9.5; lift_device=ld, wind_fn=wind_fn)

    # Let's run a short pitch depower simulation for all 3 sequence options
    # Sized to 30,000 steps (1.2 s) to exceed the 1.0 s absolute delay of Seq 2 and 3
    n_steps = 30000
    dt = 4e-5
    
    println("  testing Sequence 1 (Stall -> Lift)...")
    u1 = copy(u_start)
    sys.brake_engaged[] = false
    res1 = run_pitch_depower!(u1, sys, p, wind_fn, n_steps, dt;
        lift_device = ld,
        depower_sequence = 1,
        use_mppt_stall = true
    )

    println("  testing Sequence 2 (Lift || Stall)...")
    u2 = copy(u_start)
    sys.brake_engaged[] = false
    res2 = run_pitch_depower!(u2, sys, p, wind_fn, n_steps, dt;
        lift_device = ld,
        depower_sequence = 2,
        use_mppt_stall = true
    )

    println("  testing Sequence 3 (Lift -> Stall)...")
    u3 = copy(u_start)
    sys.brake_engaged[] = false
    res3 = run_pitch_depower!(u3, sys, p, wind_fn, n_steps, dt;
        lift_device = ld,
        depower_sequence = 3,
        use_mppt_stall = true
    )

    # Verify that the compliant winch outputs are smooth and match expectations
    @test length(res1.times) == n_steps ÷ max(1, round(Int, 0.02 / dt))
    @test all(isfinite, res1.backline_payout)
    @test all(isfinite, res2.backline_payout)
    @test all(isfinite, res3.backline_payout)
    
    # Sequence 1 has a 15% payout delay (15% of 1.2 s = 0.18 s)
    # At early steps (frame 1, t = 0.02 s), the payout must be exactly 0.0 m
    @test res1.backline_payout[1] == 0.0
    
    # Sequence 2 has a 1.0 s absolute startup delay.
    # At early steps (frame 1, t = 0.02 s), it must be 0.0 m.
    # At the end of the simulation (t = 1.2 s > 1.0 s), it must have paid out some line (> 0.0 m)
    @test res2.backline_payout[1] == 0.0
    @test res2.backline_payout[end] > 0.0
    
    # k_mppt_scale in Sequence 3 should remain 1.0 at early steps because the payout has not exceeded 30%
    @test res3.k_mppt_scale[1] == 1.0
end

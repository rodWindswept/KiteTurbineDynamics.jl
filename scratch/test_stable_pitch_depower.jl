# scratch/test_stable_pitch_depower.jl
# Run a single full 30-second Pitch Depower simulation with a stable time step (dt = 1e-5 s)
# and print the safety metrics to verify if it passes when simulated stably.

using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics
using LinearAlgebra, Printf

function main()
    println("="^80)
    println("Running Stable Full 30s Pitch Depower Simulation (dt = 1.0e-5 s)")
    println("Using Best V3 Campaign Configuration (Run 20)")
    println("="^80)
    flush(stdout)

    p_base = params_10kw()
    
    # Run 20 parameters:
    #   - Wind Speed: 6.0 m/s
    #   - Payout Duration: 15.0 s
    #   - Active Winch: true
    #   - Damping Mode: 0 (MPPT)
    #   - EA Backline: 350,000 N
    #   - c Backline: 500 N*s/m
    #   - i PTO: 25.0 kg*m^2
    p_base = override_params(p_base;
        lifter_elevation = deg2rad(75.0),
        v_wind_ref       = 6.0,
        EA_back_line     = 350000.0,
        c_back_line      = 500.0,
        i_pto            = 25.0
    )

    sys, u0 = build_kite_turbine_system(p_base)
    lift_dev = rotary_lifter_default()

    wind_fn = let vref = p_base.v_wind_ref, href = p_base.h_ref
        (pos, t) -> begin
            z = max(pos[3], 1.0)
            [vref * (z / href)^(1/7), 0.0, 0.0]
        end
    end

    ω_rated = cbrt(p_base.p_rated_w / p_base.k_mppt)
    println("Settling system to operational state...")
    flush(stdout)
    u_s = settle_to_operational_state(sys, u0, p_base, ω_rated;
                lift_device = lift_dev, wind_fn = wind_fn)
    println("System settled successfully.")
    flush(stdout)

    # Simulation settings
    dt = 1e-5  # Stable time step
    duration_s = 30.0
    n_steps = round(Int, duration_s / dt)
    save_every = round(Int, 0.02 / dt) # Save every 20 ms

    # Reset mechanical brake
    sys.brake_engaged[] = false

    println("Running 30s dynamic Pitch Depower sequence (3,000,000 steps)...")
    flush(stdout)
    
    t_start = time()
    res = run_pitch_depower!(copy(u_s), sys, p_base, wind_fn, n_steps, dt;
        lift_device      = lift_dev,
        use_active_winch = true,
        use_mppt_stall   = false,
        use_field_imu    = true,
        payout_base      = 15.0,
        damping_mode     = 0.0,
        depower_sequence = 3,
        payout_duration  = 15.0,
        save_every       = save_every)
        
    elapsed = time() - t_start
    println("Simulation completed in ", round(elapsed, digits=1), " seconds.")
    flush(stdout)

    # Evaluate metrics
    is_disqualified = false
    disq_reason = "none"

    if res.T_cyan_min < 50.0
        is_disqualified = true
        disq_reason = "slack_sky_anchor"
    elseif res.twist_max >= 0.95 * pi
        is_disqualified = true
        disq_reason = "tulloch_overtwist"
    elseif res.fos_buckling_min < 1.5
        is_disqualified = true
        disq_reason = "ring_buckling"
    end

    println("\n" * "="^80)
    println("PITCH DEPOWER SEQUENCE RESULTS (dt = 1.0e-5 s)")
    println("="^80)
    @printf("  - Minimum Sky Anchor Tension (cyan):  %8.2f N  (Limit: >50 N)   %s\n", res.T_cyan_min, res.T_cyan_min >= 50.0 ? "✓ PASS" : "✗ FAIL")
    @printf("  - Maximum Adjacent Ring Twist:        %8.4f rad (Limit: <2.98 rad) %s\n", res.twist_max, res.twist_max < 0.95*pi ? "✓ PASS" : "✗ FAIL")
    @printf("  - Minimum CFRP Strut Buckling FoS:    %8.3f     (Limit: >1.50)      %s\n", res.fos_buckling_min, res.fos_buckling_min >= 1.5 ? "✓ PASS" : "✗ FAIL")
    println("-"^80)
    println("  - Overall Safety Assessment:          ", is_disqualified ? "DISQUALIFIED (Reason: $disq_reason)" : "✓ 100% SAFE & VIABLE CANDIDATE!")
    println("="^80)
    flush(stdout)
end

main()

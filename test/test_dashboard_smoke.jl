@testset "dashboard build smoke test (headless)" begin
    # Verify the full pipeline runs without bounds errors.
    # This catches ring_ids[s+1] and similar issues before the user
    # launches the GLMakie dashboard.
    p   = params_10kw()
    sys, u0 = build_kite_turbine_system(p)
    ld  = rotary_lifter_default()

    println("  smoke: settling...")
    u_start = settle_to_operational_state(sys, u0, p, 9.5; lift_device=ld)

    N  = sys.n_total
    Nr = sys.n_ring

    wind_fn = (pos, t) -> begin
        z  = max(pos[3], 1.0)
        [p.v_wind_ref * (z / p.h_ref)^(1.0/7.0), 0.0, 0.0]
    end

    n_steps = 1000
    dt = 4e-5
    SAVE_EVERY = 500
    n_frames = n_steps ÷ SAVE_EVERY
    frames = Vector{Vector{Float64}}(undef, n_frames)
    times  = Vector{Float64}(undef, n_frames)

    println("  smoke: simulating $(n_steps*dt)s...")
    u = copy(u_start)
    let fi = 1
        run_canonical_sim!(u, sys, p, wind_fn, n_steps, dt;
            lift_device = ld,
            lin_damp = 0.05,
            callback = (u_current, t_current, step) -> begin
                if step % SAVE_EVERY == 0 && fi <= n_frames
                    frames[fi] = copy(u_current)
                    times[fi]  = t_current
                    fi += 1
                end
            end
        )
    end

    println("  smoke: capturing SimFrames...")
    sim_frames = [capture_frame(frames[i], sys, p, times[i], wind_fn, ld)
                  for i in 1:length(frames)]
    peaks = capture_peaks(sim_frames)

    @test peaks.n_frames == n_frames
    @test all(isfinite(sf.T_max) for sf in sim_frames)
    @test all(isfinite(sf.P_kw) for sf in sim_frames)

    println("  smoke: dashboard data layer OK ($(n_frames) frames)")
end

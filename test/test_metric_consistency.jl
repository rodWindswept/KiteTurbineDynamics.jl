using Test
using KiteTurbineDynamics
using LinearAlgebra
using Statistics

@testset "metric consistency" begin
    p = params_10kw()
    sys, u0 = build_kite_turbine_system(p)
    ld = rotary_lifter_default()

    u_start = settle_to_operational_state(sys, u0, p, 9.5; lift_device=ld, n_op=30_000)
    for ri in 1:sys.n_ring
        u_start[6*sys.n_total + sys.n_ring + ri] = 9.5
    end

    wind_fn = (pos, t) -> begin
        z = max(pos[3], 1.0)
        [p.v_wind_ref * (z / p.h_ref)^(1.0/7.0), 0.0, 0.0]
    end

    n_steps = 1000
    dt = 4e-5
    SAVE_EVERY = 200
    n_frames = n_steps ÷ SAVE_EVERY
    frames = Vector{Vector{Float64}}(undef, n_frames)
    times  = Vector{Float64}(undef, n_frames)

    # 1. Run live simulation, capture states
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

    # 2. Capture SimFrames post-simulation (playback scenario)
    sim_frames = [capture_frame(frames[i], sys, p, times[i], wind_fn, ld)
                  for i in 1:length(frames)]

    # 3. Assertions on consistency
    for i in 1:n_frames
        sf = sim_frames[i]
        u_frame = frames[i]
        t_frame = times[i]

        tau_gen, _ = get_generator_torque(u_frame, sys, p, t_frame, wind_fn; brake_engaged=sys.brake_engaged[])
        P_expected = tau_gen * abs(sf.omega_gnd) / 1000.0

        @test sf.P_kw ≈ P_expected atol=1e-12
        T_max_expected, _ = get_max_rope_tension(u_frame, sys, p)
        @test sf.T_max ≈ T_max_expected atol=1e-12
    end

    p_kw_values = [sf.P_kw for sf in sim_frames]
    t_max_values = [sf.T_max for sf in sim_frames]

    @test mean(p_kw_values) > 0.1
    @test std(p_kw_values) > 1e-6
    @test std(t_max_values) > 1.0

    u_brake = copy(frames[end])
    tau_brake, _ = get_generator_torque(u_brake, sys, p, times[end], wind_fn; brake_engaged=true)
    power_scale = p.p_rated_w / 10000.0
    omega_gnd_now = u_brake[sys.n_total * 6 + sys.n_ring + 1]
    expected_brake_torque = 1500.0 * power_scale * tanh(20.0 * omega_gnd_now)
    @test tau_brake ≈ expected_brake_torque atol=1e-12
end

@testset "grep guard for inline power formulas" begin
    # Prevent future developers from reintroducing inline k_mppt * ω^3 calculations in scripts
    scripts_dir = joinpath(dirname(@__DIR__), "scripts")
    if isdir(scripts_dir)
        for (root, dirs, files) in walkdir(scripts_dir)
            for file in files
                if endswith(file, ".jl")
                    filepath = joinpath(root, file)
                    lines = readlines(filepath)
                    for (line_num, line) in enumerate(lines)
                        clean_line = strip(line)
                        if contains(clean_line, "k_mppt") &&
                           (contains(clean_line, "omega") || contains(clean_line, "ω") || contains(clean_line, "om")) &&
                           (contains(clean_line, "/ 1000") || contains(clean_line, "/1000")) &&
                           !contains(clean_line, "approx generator torque") &&
                           !contains(clean_line, "k_mppt =") &&
                           !contains(clean_line, "k_mppt,") &&
                           !contains(clean_line, "push!(Pgens,")
                            @testset "Check $file:$line_num" begin
                                println("Grep guard failed: Inline power formula found in $file at line $line_num:")
                                println("  $clean_line")
                                @test false
                            end
                        end
                    end
                end
            end
        end
    end
end

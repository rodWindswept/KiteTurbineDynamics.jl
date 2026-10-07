using Test
using KiteTurbineDynamics
using LinearAlgebra
using Statistics

@testset "metric consistency" begin
    p = override_params(params_10kw(); p_rated_w = 5000.0)   # D4 re-pin (2026-10-07): 5 kW discriminating power
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

    # dt is DERIVED from the built system, never a literal (2026-09-16, Rod):
    # `stable_dt_for_system` scales with the shortest TRPT sub-segment, so a fixed
    # 4e-5 pins this test to one geometry and was 1.96x over the stability limit
    # for the 5 kW taper.  The frame COUNT and the 0.04 s window are preserved, so
    # the sample interval and step count follow from the stable dt.
    n_frames = 5
    dt = KiteTurbineDynamics.stable_dt_for_system(sys, p)
    n_steps = round(Int, 0.04 / dt)
    SAVE_EVERY = max(1, n_steps ÷ n_frames)
    n_steps = SAVE_EVERY * n_frames
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
        # Signed (2026-08-20): P = τ_gen·ω_gnd.  The masked `abs(ω_gnd)` form
        # this line used to carry re-derived P at positive ω only, so a
        # reversion to abs()/max(ω,0) masking passed unnoticed.
        P_expected = tau_gen * sf.omega_gnd / 1000.0

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
    omega_gnd_now = u_brake[sys.n_total * 6 + sys.n_ring + 1]
    # D4 (2026-10-07): the brake budget is 1500/2500 of the single calibrated cap
    # authority — the old expectation here was the deleted linear form.
    expected_brake_torque = (1500.0 / 2500.0) * generator_torque_cap(p) * tanh(20.0 * omega_gnd_now)
    @test tau_brake ≈ expected_brake_torque atol=1e-12
end

@testset "generator torque cap law (D4 acceptance)" begin
    # Landed 2026-10-07 (D4): one authority replaces the hidden-unit
    # ((P/10⁴)²) scale at every generator/brake torque site.  tau_rated =
    # P_rated/omega_rated, omega_rated ∝ v/R with R ∝ sqrt(P_rated)
    # -> tau ∝ P_rated^1.5; the constant is calibrated to the April-29
    # anchor rig's measured generator-load plateau: 22.65 N·m at 300 W,
    # inside the measured band [20, 24] N·m (DECISIONS [2026-08-16]).
    cap_of(P) = generator_torque_cap(override_params(params_10kw(); p_rated_w = P))

    # (a) anchor-rig band at 300 W
    @test 20.0 <= cap_of(300.0) <= 24.0
    @test cap_of(300.0) ≈ 22.65 rtol=1e-12

    # (b) discriminating values at 5 / 10 / 50 kW (old 5 kW forms: 625, 1250)
    @test cap_of(5000.0) ≈ 1541.137296501083 rtol=1e-9
    @test cap_of(10000.0) ≈ 4358.994532381675 rtol=1e-9
    @test cap_of(50000.0) ≈ 48735.04043977666 rtol=1e-9

    # (c) the law is tau ∝ P_rated^1.5 at both ends
    @test cap_of(5000.0) / cap_of(300.0) ≈ (5000.0 / 300.0)^1.5 rtol=1e-9
    @test cap_of(50000.0) / cap_of(5000.0) ≈ 10.0^1.5 rtol=1e-9

    # (d) S2 fold release: cap(5 kW) clears the fold's uncapped demand
    # (~695 N·m at the flown speed — kretune record) with >=50% margin.
    @test cap_of(5000.0) >= 1.5 * 695.0

    # (e) >=50% margin over the machine's own rated operating tau at 50 kW:
    # tau_rated = k * omega_r^2, omega_r = (P_rated/k)^(1/3).
    p50 = params_50kw()
    tau_rated_50 = p50.k_mppt * cbrt(p50.p_rated_w / p50.k_mppt)^2
    @test cap_of(p50.p_rated_w) >= 1.5 * tau_rated_50
end

@testset "signed P_gen — reversal/regeneration must read negative" begin
    # DECISIONS [2026-08-20] banned the abs(ω_gnd)/max(ω,0) masking of P_gen.
    # The consistency testset above could not catch a reversion: it re-derived P
    # at positive ω only.  This drives sign-opposite states through the real
    # control law and asserts the signed contract P = τ_gen·ω_gnd, so a
    # reversion to the masked form fails HERE.
    p = params_10kw()
    sys, u0 = build_kite_turbine_system(p)
    N = sys.n_total
    Nr = sys.n_ring
    gnd_idx = 6N + Nr + 1          # ground-ring ω (layout: 6N + Nr + ring_idx)
    u = copy(u0)
    wind_fn(r, t) = [p.v_wind_ref, 0.0, 0.0]

    prev = KiteTurbineDynamics.GENERATOR_LOAD[]
    try
        # Measured τ(ω) curve: a static positive load, no cap, floor far below
        # the tested band (so the floor clamp is not what produces the sign).
        set_generator_load!(GeneratorLoadMode(;
            mode=:table,
            omega_pts=[-10.0, -1.0, 10.0], tau_pts=[8.0, 8.0, 20.0],
            tau_cap=0.0, omega_floor=-100.0,
        ))

        # (a) Motoring: τ > 0, ω > 0 → P > 0.
        u[gnd_idx] = 10.0
        tau_pos, _ = get_generator_torque(u, sys, p, 0.0, wind_fn; brake_engaged=false)
        @test tau_pos > 0.0
        @test tau_pos * u[gnd_idx] / 1000.0 > 0.0

        # (b) Reversed ring: τ > 0, ω < 0 → P MUST be negative.
        u[gnd_idx] = -5.0
        tau_rev, _ = get_generator_torque(u, sys, p, 0.0, wind_fn; brake_engaged=false)
        P_signed = tau_rev * u[gnd_idx] / 1000.0
        @test tau_rev > 0.0
        @test P_signed < 0.0                                  # the contract
        @test tau_rev * abs(u[gnd_idx]) / 1000.0 > 0.0        # the banned form masks it
    finally
        set_generator_load!(prev)
    end
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

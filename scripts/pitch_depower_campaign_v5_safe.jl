#!/usr/bin/env julia
# scripts/pitch_depower_campaign_v5_safe.jl
#
# Windswept & Interesting Ltd
# Safety-Focused Pitch-Depower Parameter Sweep (V5-Safe Campaign).
#
# Sweeps over Wind Speeds, Payout Rates, Winch Compliance, Tether Viscoelastic Damping,
# and Damping Modes using BEM-coupled, geometrically optimized V5-Safe octagons.
#
# Usage:
#   julia --project=. --threads=auto scripts/pitch_depower_campaign_v5_safe.jl
#

using Pkg; Pkg.activate(joinpath(@__DIR__, ".."))

using KiteTurbineDynamics
using LinearAlgebra, Statistics, Printf
using CSV, DataFrames
import Base.Threads: @threads, nthreads

# ── Output directory ──────────────────────────────────────────────────────────
const RESULTS_DIR = joinpath(@__DIR__, "results", "pitch_depower_campaign_v5_safe")
mkpath(RESULTS_DIR)

# ── Define the 4 Structural Configurations ─────────────────────────────────────
# We explicitly model:
#   1. Baseline 10 kW (unoptimized under pitch depower but standard V5 sizing)
#   2. V5-Safe 10 kW (upgraded circular CFRP struts and anti-necking ground-ring)
#   3. Baseline 50 kW (V5 standard sizing scaled to 50 kW)
#   4. V5-Safe 50 kW (reinforced V5-safe circular CFRP struts and anti-necking)

const DESIGN_BASE_10KW = SpacerRingDesign(
    PROFILE_CIRCULAR, 0.0409, 0.02, 1.0, 0.493, 1.6, 0.336/1.6, 19, 8, 30.0, 0.01, 70e9, 1600.0, 600e6
)
const DESIGN_SAFE_10KW = SpacerRingDesign(
    PROFILE_CIRCULAR, 0.0580, 0.02, 1.0, 0.450, 1.6, 0.500/1.6, 19, 8, 30.0, 0.01, 70e9, 1600.0, 600e6
)
const DESIGN_BASE_50KW = SpacerRingDesign(
    PROFILE_CIRCULAR, 0.0586, 0.02, 1.0, 0.426, 3.58, 0.300/3.58, 19, 8, 67.08, 0.01, 70e9, 1600.0, 600e6
)
const DESIGN_SAFE_50KW = SpacerRingDesign(
    PROFILE_CIRCULAR, 0.0750, 0.02, 1.0, 0.400, 3.58, 0.500/3.58, 19, 8, 67.08, 0.01, 70e9, 1600.0, 600e6
)

function get_design(config_idx::Int)
    if config_idx == 1
        return DESIGN_BASE_10KW
    elseif config_idx == 2
        return DESIGN_SAFE_10KW
    elseif config_idx == 3
        return DESIGN_BASE_50KW
    else
        return DESIGN_SAFE_50KW
    end
end

function get_design_name(config_idx::Int)
    names = ["base_10kw", "safe_10kw", "base_50kw", "safe_50kw"]
    return names[config_idx]
end

function get_spacing_params(config_idx::Int)
    if config_idx == 1
        return (target_Lr = 2.0, r_bottom = 0.336)
    elseif config_idx == 2
        return (target_Lr = 2.0, r_bottom = 0.500)
    elseif config_idx == 3
        return (target_Lr = 0.58, r_bottom = 0.300)
    else
        return (target_Lr = 0.58, r_bottom = 0.500)
    end
end

# ── Dynamic Grid Axes (256-run focused campaign) ──────────────────────────────
# We structure a highly scientific 2^6 fractional grid across 4 structural designs
WIND_SPEEDS      = [11.0, 20.0]                     # m/s (Rated wind vs. extreme storm)
PAYOUT_DURATIONS = [5.0, 15.0]                      # s (Fast compliance transient vs. slow quasi-static)
ACTIVE_WINCH_VALS= [false, true]                    # Winch compliance preload toggle
DAMPING_MODES    = [0.0, 2.0]                       # 0=MPPT + Active Damp, 2=LPF Speed Damping
C_BACK_LINES     = [250.0, 500.0]                   # N·s/m (Braided tether core viscoelastic damping)
LIFTER_ELEV_VALS = [75.0, 95.0]                     # deg (Moderate altitude vs. steep pull elevation)

# Build 256-run campaign factorial grid
function build_grid()
    grid = NamedTuple[]
    for config_idx in 1:4
        for ws in WIND_SPEEDS
            for pdur in PAYOUT_DURATIONS
                for awinch in ACTIVE_WINCH_VALS
                    for dmode in DAMPING_MODES
                        for c in C_BACK_LINES
                            for elev in LIFTER_ELEV_VALS
                                push!(grid, (
                                    struc_config    = config_idx,
                                    wind_speed      = ws,
                                    payout_duration = pdur,
                                    active_winch    = awinch,
                                    damping_mode    = dmode,
                                    c_back_line     = c,
                                    lifter_elev_deg = elev,
                                    EA_back_line    = 500000.0, # Golden standard axial stiffness
                                    i_pto           = 12.5,     # Golden standard low-inertia PTO
                                    field_imu       = true,     # IMU closed-loop yaw safety
                                    mppt_stall      = true,     # Stall governor enabled
                                    payout_base_m   = 15.0,     # Standard displacement base
                                    duration_s      = 10.0,     # Simulation window (settled analytically)
                                ))
                            end
                        end
                    end
                end
            end
        end
    end
    # Sort by payout duration to prevent thread tail latency
    return sort(grid, by = x -> x.payout_duration, rev = true)
end

function build_smoke_grid()
    [
        (struc_config=1, wind_speed=11.0, payout_duration=5.0, active_winch=false, damping_mode=0.0, c_back_line=250.0, lifter_elev_deg=75.0, EA_back_line=500000.0, i_pto=12.5, field_imu=true, mppt_stall=true, payout_base_m=15.0, duration_s=1.0),
        (struc_config=2, wind_speed=20.0, payout_duration=15.0, active_winch=true, damping_mode=2.0, c_back_line=500.0, lifter_elev_deg=95.0, EA_back_line=500000.0, i_pto=12.5, field_imu=true, mppt_stall=true, payout_base_m=15.0, duration_s=1.0),
        (struc_config=3, wind_speed=11.0, payout_duration=5.0, active_winch=false, damping_mode=0.0, c_back_line=250.0, lifter_elev_deg=75.0, EA_back_line=500000.0, i_pto=12.5, field_imu=true, mppt_stall=true, payout_base_m=15.0, duration_s=1.0),
        (struc_config=4, wind_speed=20.0, payout_duration=15.0, active_winch=true, damping_mode=2.0, c_back_line=500.0, lifter_elev_deg=95.0, EA_back_line=500000.0, i_pto=12.5, field_imu=true, mppt_stall=true, payout_base_m=15.0, duration_s=1.0),
    ]
end

# ── Metric derivation from DepowerResult ──────────────────────────────────────
function derive_metrics(res::DepowerResult, config::NamedTuple, run_id::Int)
    times    = res.times
    omega_h  = res.omega_hub
    omega_g  = res.omega_gnd
    tau_g    = res.tau_gen
    T_mx     = res.T_max
    n_sl     = res.n_slack
    payout   = res.backline_payout

    n = length(times)
    if n < 2
        return (run_id=run_id, struc_name=get_design_name(config.struc_config), config...,
                d_tau_gen_rms=NaN, d_omega_rms=NaN,
                T_min=NaN, T_mean=NaN, T_std=NaN, slack_events=0,
                slack_events_late=0, speed_ripple_rms=NaN,
                brake_time=NaN, brake_engaged=false,
                omega_hub_final=NaN, omega_gnd_final=NaN,
                time_to_omega1=NaN, max_payout_reached=NaN,
                peak_tau_gen=NaN, min_tension_before_brake=NaN,
                T_cyan_min=NaN, twist_max=NaN, fos_buckling_min=NaN,
                fos_buckling_ring_id=0, peak_strut_load=NaN, peak_strut_ring_id=0,
                max_out_of_plane_accel=NaN, max_node_jerk=NaN,
                T_trpt_max=NaN, peak_trpt_segment_idx=0, peak_trpt_line_idx=0,
                is_disqualified=1, disqualification_reason="degenerate_run")
    end

    dt_fr = (times[end] - times[1]) / (n - 1)

    # Smoothness metrics
    d_tau    = diff(tau_g) ./ dt_fr
    d_tau_rms = sqrt(mean(d_tau .^ 2))

    d_omega   = diff(omega_h) ./ dt_fr
    d_omega_rms = sqrt(mean(d_omega .^ 2))

    # Torsional Speed Ripple (RMS difference)
    speed_ripple_rms = sqrt(mean((omega_h .- omega_g) .^ 2))

    # Tension stability
    T_min_val  = minimum(T_mx)
    T_mean_val = mean(T_mx)
    T_std_val  = std(T_mx)
    
    # Slack events counting
    slack_ev   = sum(n_sl .> 0)
    late_start_idx = findfirst(x -> x >= 4.15, times)
    slack_ev_late  = isnothing(late_start_idx) ? 0 : sum(n_sl[late_start_idx:end] .> 0)

    # Brake metrics
    brake_eng   = !isnan(res.brake_time)
    brake_t     = res.brake_time

    t_omega1 = findfirst(x -> x < 1.0, omega_h)
    time_to_omega1 = isnothing(t_omega1) ? NaN : times[t_omega1]

    max_payout_r = maximum(payout)
    half = max(1, n ÷ 2)
    peak_tg = maximum(tau_g[1:half])
    tail_start = max(1, round(Int, 0.8 * n))
    T_min_tail = minimum(T_mx[tail_start:end])

    # ── Safety Disqualifications ──
    # Note: safety margins are now evaluated continuously, but we track disqualifications
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

    return (
        run_id                   = run_id,
        struc_name               = get_design_name(config.struc_config),
        struc_config             = config.struc_config,
        wind_speed               = config.wind_speed,
        payout_duration          = config.payout_duration,
        active_winch             = Int(config.active_winch),
        damping_mode             = Int(config.damping_mode),
        EA_back_line             = config.EA_back_line,
        c_back_line              = config.c_back_line,
        i_pto                    = config.i_pto,
        field_imu                = Int(config.field_imu),
        mppt_stall               = Int(config.mppt_stall),
        payout_base_m            = config.payout_base_m,
        lifter_elev_deg          = config.lifter_elev_deg,
        duration_s               = config.duration_s,
        d_tau_gen_rms            = d_tau_rms,
        d_omega_rms              = d_omega_rms,
        T_min                    = T_min_val,
        T_mean                   = T_mean_val,
        T_std                    = T_std_val,
        slack_events             = slack_ev,
        slack_events_late        = slack_ev_late,
        speed_ripple_rms         = speed_ripple_rms,
        brake_time               = brake_t,
        brake_engaged            = Int(brake_eng),
        omega_hub_final          = omega_h[end],
        omega_gnd_final          = omega_g[end],
        time_to_omega1           = time_to_omega1,
        max_payout_reached       = max_payout_r,
        peak_tau_gen             = peak_tg,
        min_tension_before_brake = T_min_tail,
        T_cyan_min               = res.T_cyan_min,
        twist_max                = res.twist_max,
        fos_buckling_min         = res.fos_buckling_min,
        fos_buckling_ring_id     = res.fos_buckling_ring_id,
        peak_strut_load          = res.peak_strut_load,
        peak_strut_ring_id       = res.peak_strut_ring_id,
        max_out_of_plane_accel   = res.max_out_of_plane_accel,
        max_node_jerk            = res.max_node_jerk,
        T_trpt_max               = res.T_trpt_max,
        peak_trpt_segment_idx    = res.peak_trpt_segment_idx,
        peak_trpt_line_idx       = res.peak_trpt_line_idx,
        is_disqualified          = Int(is_disqualified),
        disqualification_reason  = disq_reason,
    )
end

function save_timeseries(res::DepowerResult, run_id::Int)
    path = joinpath(RESULTS_DIR, @sprintf("timeseries_%04d.csv", run_id))
    df = DataFrame(
        t               = res.times,
        omega_hub       = res.omega_hub,
        omega_gnd       = res.omega_gnd,
        tau_gen         = res.tau_gen,
        T_max           = res.T_max,
        n_slack         = res.n_slack,
        backline_payout = res.backline_payout,
        k_mppt_scale    = res.k_mppt_scale,
    )
    CSV.write(path, df)
end

# ── Single run execution ──────────────────────────────────────────────────────
function run_one(run_id::Int, config::NamedTuple; save_ts::Bool = true)
    try
        # 1. Initialize base parameters corresponding to the config power rating
        p_base = (config.struc_config in [1, 2]) ? params_10kw() : params_50kw()

        # 2. Extract structural design candidate
        design = get_design(config.struc_config)

        # 3. Dynamic parameter overrides
        p_base = override_params(p_base;
            lifter_elevation = deg2rad(config.lifter_elev_deg),
            v_wind_ref       = config.wind_speed,
            EA_back_line     = config.EA_back_line,
            c_back_line      = config.c_back_line,
            i_pto            = config.i_pto,
            n_lines          = design.n_lines) # Multi-line octagon support

        # ── Build geometrically optimized V5-spacing octagon system ──
        # target_Lr and r_bottom are derived from the configuration index
        params_spacing = get_spacing_params(config.struc_config)
        target_Lr = params_spacing.target_Lr
        r_bottom  = params_spacing.r_bottom
        sys, u0   = build_kite_turbine_system_v5(p_base, target_Lr, r_bottom)
        lift_dev  = rotary_lifter_default()

        wind_fn = let vref = p_base.v_wind_ref, href = p_base.h_ref
            (pos, t) -> begin
                z = max(pos[3], 1.0)
                [vref * (z / href)^(1/7), 0.0, 0.0]
            end
        end

        ω_rated = cbrt(p_base.p_rated_w / p_base.k_mppt)
        
        # ── Step A: Settle preloaded operational state analytically ──
        # Highly stabilized and pre-twisted to eliminate initial startup transients
        u_s = settle_to_operational_state(sys, u0, p_base, ω_rated;
                    lift_device = lift_dev, wind_fn = wind_fn)

        # ── Step B: Execute Dynamic 100 kHz Explicit Euler Loop ──
        dt = 1.0e-5 # Strictly stable time-step for 8-line octagons
        n_steps = round(Int, config.duration_s / dt)

        # Reset mechanical brake latch
        sys.brake_engaged[] = false

        res = run_pitch_depower!(copy(u_s), sys, p_base, wind_fn, n_steps, dt;
            lift_device      = lift_dev,
            use_active_winch = config.active_winch,
            use_mppt_stall   = config.mppt_stall,
            use_field_imu    = config.field_imu,
            payout_base      = config.payout_base_m,
            damping_mode     = Float64(config.damping_mode),
            depower_sequence = 3, # Stall governor enabled
            payout_duration  = config.payout_duration,
            design           = design) # Pass design to evaluate exact CFRP stress

        save_ts && save_timeseries(res, run_id)
        return derive_metrics(res, config, run_id)

    catch e
        @warn "Run $run_id failed" exception=(e, catch_backtrace())
        return (
            run_id                   = run_id,
            struc_name               = get_design_name(config.struc_config),
            struc_config             = config.struc_config,
            wind_speed               = config.wind_speed,
            payout_duration          = config.payout_duration,
            active_winch             = Int(config.active_winch),
            damping_mode             = Int(config.damping_mode),
            EA_back_line             = config.EA_back_line,
            c_back_line              = config.c_back_line,
            i_pto                    = config.i_pto,
            field_imu                = Int(config.field_imu),
            mppt_stall               = Int(config.mppt_stall),
            payout_base_m            = config.payout_base_m,
            lifter_elev_deg          = config.lifter_elev_deg,
            duration_s               = config.duration_s,
            d_tau_gen_rms=NaN, d_omega_rms=NaN,
            T_min=NaN, T_mean=NaN, T_std=NaN, slack_events=0,
            slack_events_late=0, speed_ripple_rms=NaN,
            brake_time=NaN, brake_engaged=0,
            omega_hub_final=NaN, omega_gnd_final=NaN,
            time_to_omega1=NaN, max_payout_reached=NaN,
            peak_tau_gen=NaN, min_tension_before_brake=NaN,
            T_cyan_min=NaN, twist_max=NaN, fos_buckling_min=NaN,
            fos_buckling_ring_id=0, peak_strut_load=NaN, peak_strut_ring_id=0,
            max_out_of_plane_accel=NaN, max_node_jerk=NaN,
            T_trpt_max=NaN, peak_trpt_segment_idx=0, peak_trpt_line_idx=0,
            is_disqualified=1, disqualification_reason="solver_error",
        )
    end
end

# ── High-Performance Main Campaign ───────────────────────────────────────────
function main()
    smoke_test = "--test" in ARGS
    grid = smoke_test ? build_smoke_grid() : build_grid()
    n_runs = length(grid)

    @info "Pitch Depower Campaign V5-Safe" n_runs=n_runs threads=nthreads() smoke_test=smoke_test
    @info "Results directory" RESULTS_DIR

    metrics_path = joinpath(RESULTS_DIR, "campaign_metrics.csv")
    results = Vector{Any}(undef, n_runs)
    t_start = time()

    # ── Channel-based Parallel Worker Pool ──
    task_channel = Channel{Tuple{Int, NamedTuple}}(n_runs)
    for (i, config) in enumerate(grid)
        put!(task_channel, (i, config))
    end
    close(task_channel)

    completed_count = Threads.Atomic{Int}(0)

    @sync for t in 1:nthreads()
        Threads.@spawn begin
            for (i, config) in task_channel
                results[i] = run_one(i, config; save_ts = true)
                Threads.atomic_add!(completed_count, 1)
                done = completed_count[]
                elapsed = time() - t_start
                rate = done / elapsed
                eta = (n_runs - done) / max(rate, 1e-6)
                @info @sprintf("Run %4d / %4d  [%.0f s elapsed, ETA %.0f min]",
                                done, n_runs, elapsed, eta / 60)
            end
        end
    end

    # Write campaign summary CSV
    df = DataFrame([NamedTuple(r) for r in results])
    CSV.write(metrics_path, df)

    elapsed_total = time() - t_start
    @info @sprintf("Campaign V5-Safe complete: %d runs in %.1f minutes", n_runs, elapsed_total / 60)
    @info "Summary CSV" metrics_path
end

main()

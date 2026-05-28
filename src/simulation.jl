export run_canonical_sim!, DepowerResult, run_pitch_depower!, override_params

"""
    run_canonical_sim!(u, sys, p, wind_fn, n_steps, dt; lift_device, lin_damp, callback)

The canonical explicit Euler integration loop, extracted directly from the interactive dashboard.
Provides a unified, headless simulation engine for all batch sweeps and reports.
"""
function run_canonical_sim!(u::Vector{Float64}, sys::KiteTurbineSystem, p::SystemParams, wind_fn::Function, n_steps::Int, dt::Float64;
                            lift_device::Union{Nothing, LiftDevice} = nothing,
                            lin_damp::Float64 = 0.05,
                            callback::Union{Nothing, Function} = nothing)
    N  = sys.n_total
    Nr = sys.n_ring
    du = zeros(Float64, length(u))
    t = 0.0
    ode_params = lift_device === nothing ? (sys, p, wind_fn) : (sys, p, wind_fn, lift_device)

    for step in 1:n_steps
        fill!(du, 0.0)
        multibody_ode!(du, u, ode_params, t)
        t += dt

        @views u[3N+1:6N]        .+= dt .* du[3N+1:6N]
        @views u[1:3N]            .+= dt .* u[3N+1:6N]
        @views u[6N+Nr+1:6N+2Nr] .+= dt .* du[6N+Nr+1:6N+2Nr]
        apply_brake_constraint!(u, sys, N, Nr)   # pin ω_gnd=0 when brake latched
        @views u[6N+1:6N+Nr]     .+= dt .* u[6N+Nr+1:6N+2Nr]

        if lin_damp > 0.0
            orbital_damp_rope_velocities!(u, sys, p, lin_damp)
        end

        u[1:3]       .= 0.0   # ground ring centre stays at origin
        u[3N+1:3N+3] .= 0.0   # ground ring translational velocity = 0

        if callback !== nothing
            callback(u, t, step)
        end
    end
    return u
end

# ══════════════════════════════════════════════════════════════════════════════
# DepowerResult — lightweight time-series output from a headless depower run.
# ══════════════════════════════════════════════════════════════════════════════

"""
    DepowerResult

Lightweight per-frame metrics recorded during a headless pitch-depower simulation.
Designed for batch-campaign analysis — avoids the heavy ring-element analysis
that `capture_frame` performs, keeping the sweep fast.
"""
struct DepowerResult
    times          :: Vector{Float64}   # simulated time at each saved frame (s)
    omega_hub      :: Vector{Float64}   # hub (rotor) angular velocity (rad/s)
    omega_gnd      :: Vector{Float64}   # PTO (ground ring) angular velocity (rad/s)
    tau_gen        :: Vector{Float64}   # generator / brake torque (N·m)
    T_max          :: Vector{Float64}   # maximum mid-rope tension (N)
    n_slack        :: Vector{Int}       # tether lines with T < 5 N
    backline_payout:: Vector{Float64}   # instantaneous backline payout (m)
    k_mppt_scale   :: Vector{Float64}   # instantaneous MPPT stall multiplier
    brake_time     :: Float64           # simulated time when brake first latched (NaN = never)
end

"""
    override_params(base::SystemParams; kwargs...) → SystemParams

Return a copy of `base` with the named fields replaced by the keyword values.
Mirrors the dashboard-internal `_modified_params` helper; exported so scripts
and the test suite can use it without pulling in GLMakie.

Example:
    p2 = override_params(p; lifter_elevation = deg2rad(90.0), backline_payout = 12.5)
"""
function override_params(base::SystemParams; kwargs...)
    fnames    = fieldnames(SystemParams)
    ftypes    = fieldtypes(SystemParams)
    overrides = Dict{Symbol,Any}(kwargs)
    vals = ntuple(length(fnames)) do i
        convert(ftypes[i], get(overrides, fnames[i], getfield(base, fnames[i])))
    end
    SystemParams(vals...)
end

"""
    run_pitch_depower!(u, sys, p_base, wind_fn, n_steps, dt; kwargs...) → DepowerResult

Headless pitch-depower simulation — replicates the dashboard's depower scenario loop
exactly, including the closed-loop winch controller, MPPT stall governor, and
Field-IMU / brake logic.

# Keyword arguments
| Argument          | Default | Description                                            |
|-------------------|---------|--------------------------------------------------------|
| `use_active_winch`| `false` | Proportional payout rate ∝ T_min/150 N feedback        |
| `use_mppt_stall`  | `false` | Ramp k_mppt up to 9× as depower progresses            |
| `use_field_imu`   | `false` | Enable 2-sided torsional damping (kp_elev = 1.0)      |
| `payout_base`     | `15.0`  | Maximum backline payout at full depower (m)            |
| `damping_mode`    | `0.0`   | Generator control mode (0=MPPT, 1=Active Damp, 2=LPF) |
| `save_every`      | auto    | Save a frame every this many steps (default ≈ 0.02 s) |

The caller is responsible for passing a pre-settled `u` (output of
`settle_to_operational_state`), and for resetting `sys.brake_engaged[]` beforehand.
"""
function run_pitch_depower!(u::Vector{Float64}, sys::KiteTurbineSystem, p_base::SystemParams,
                             wind_fn::Function, n_steps::Int, dt::Float64;
                             lift_device::Union{Nothing, LiftDevice} = nothing,
                             use_active_winch::Bool = false,
                             use_mppt_stall::Bool   = false,
                             use_field_imu::Bool    = false,
                             payout_base::Float64   = 15.0,
                             damping_mode::Float64  = 0.0,
                             depower_sequence::Int  = 1,
                             save_every::Int        = max(1, round(Int, 0.02 / dt)))
    N  = sys.n_total
    Nr = sys.n_ring

    n_frames = n_steps ÷ save_every
    times_v       = Vector{Float64}(undef, n_frames)
    omega_hub_v   = Vector{Float64}(undef, n_frames)
    omega_gnd_v   = Vector{Float64}(undef, n_frames)
    tau_gen_v     = Vector{Float64}(undef, n_frames)
    T_max_v       = Vector{Float64}(undef, n_frames)
    n_slack_v     = Vector{Int}(undef, n_frames)
    payout_v      = Vector{Float64}(undef, n_frames)
    kscale_v      = Vector{Float64}(undef, n_frames)

    brake_time       = NaN
    du               = zeros(Float64, length(u))
    t                = 0.0
    fi               = 1
    release_frac     = 0.0
    sigmoid_progress = 0.0
    L_winch          = 0.0
    v_winch          = 0.0
    t_total          = n_steps * dt
    n_seg            = sys.n_ring - 1
    n_lines_p        = p_base.n_lines

    # Node indices for angular velocity extraction
    hub_gid = sys.rotor.node_id
    hub_ri  = (sys.nodes[hub_gid]::RingNode).ring_idx
    gnd_ri  = (sys.nodes[sys.ring_ids[1]]::RingNode).ring_idx

    geom_scale = p_base.tether_length / 30.0
    max_payout = payout_base * geom_scale

    # Power scale for brake torque — matches ring_forces.jl logic
    power_scale = p_base.p_rated_w / 10_000.0

    # Inline mid-rope tension for segment s, line j
    # (avoids importing visualization helpers; identical formula to _mid_tension)
    _mid_t(s, j) = begin
        idx = (s - 1) * n_lines_p * 4 + (j - 1) * 4 + 2
        idx > length(sys.sub_segs) && return 0.0
        ss = sys.sub_segs[idx]
        pa = @view u[3*(ss.end_a.node_id - 1) + 1 : 3*ss.end_a.node_id]
        pb = @view u[3*(ss.end_b.node_id - 1) + 1 : 3*ss.end_b.node_id]
        max(0.0, ss.EA * (norm(pb .- pa) - ss.length_0) / ss.length_0)
    end

    for step in 1:n_steps
        # ── Depower controller: every 50 steps ≈ 2 ms sim time ─────────────
        if step % 50 == 0
            depower_delay    = depower_sequence == 1 ? 0.15 * t_total : 1.0  # 1.0 s absolute startup delay for Seq 2 & 3
            depower_duration = 0.70 * t_total
            target_sig       = clamp((t - depower_delay) / depower_duration, 0.0, 1.0)

            if use_active_winch && target_sig > sigmoid_progress
                # T_min: minimum average segment tension (proxy for stack slack)
                T_min_d = Inf
                for s in 1:n_seg
                    seg_sum = 0.0
                    for j in 1:n_lines_p
                        seg_sum += _mid_t(s, j)
                    end
                    T_min_d = min(T_min_d, seg_sum / n_lines_p)
                end
                rate_factor      = clamp(T_min_d / 150.0, 0.0, 1.0)
                sigmoid_progress += rate_factor * 0.002 * (target_sig - sigmoid_progress)
            else
                sigmoid_progress = target_sig
            end

            release_frac = 3.0 * sigmoid_progress^2 - 2.0 * sigmoid_progress^3
        end

        # Second-order compliant winch actuator model: steps at the simulation rate dt
        L_target  = max_payout * release_frac
        omega_n   = 2.0 * pi * 1.0  # 1.0 Hz actuator natural frequency
        zeta_act  = 1.0            # Critically damped response
        a_winch   = (omega_n^2 * (L_target - L_winch)) - (2.0 * zeta_act * omega_n * v_winch)
        v_winch  += dt * a_winch
        L_winch  += dt * v_winch

        # Stall governor delay logic for Option 3
        stall_ramp   = depower_sequence == 3 ?
                       clamp((release_frac - 0.30) / 0.70, 0.0, 1.0) :
                       release_frac
        k_mppt_scale = use_mppt_stall ? (1.0 + 8.0 * stall_ramp) : 1.0

        p_step = override_params(p_base;
            backline_payout = L_winch,
            k_mppt          = p_base.k_mppt * k_mppt_scale,
            β_rate_max      = damping_mode,
            kp_elev         = use_field_imu ? 1.0 : 0.0)

        ode_p = isnothing(lift_device) ? (sys, p_step, wind_fn) :
                                         (sys, p_step, wind_fn, lift_device)
        fill!(du, 0.0)
        multibody_ode!(du, u, ode_p, t)
        t += dt

        @views u[3N+1:6N]        .+= dt .* du[3N+1:6N]
        @views u[1:3N]            .+= dt .* u[3N+1:6N]
        @views u[6N+Nr+1:6N+2Nr] .+= dt .* du[6N+Nr+1:6N+2Nr]
        apply_brake_constraint!(u, sys, N, Nr)
        @views u[6N+1:6N+Nr]     .+= dt .* u[6N+Nr+1:6N+2Nr]

        orbital_damp_rope_velocities!(u, sys, p_step, 0.05)

        # PTO co-braking: damp all ring angular velocities (only in pure MPPT mode 0)
        if release_frac > 0.0 && round(damping_mode) ≈ 0.0
            @views u[6N+Nr+1:6N+2Nr] .*= (1.0 - release_frac * 1e-5)
        end

        u[1:3] .= 0.0; u[3N+1:3N+3] .= 0.0

        # Latch brake time on first engagement
        if isnan(brake_time) && sys.brake_engaged[]
            brake_time = t
        end

        if step % save_every == 0 && fi <= n_frames
            omega_hub_now = u[6N + Nr + hub_ri]
            omega_gnd_now = u[6N + Nr + gnd_ri]

            # tau_gen: MPPT law or brake torque if latched
            tg = if sys.brake_engaged[]
                1500.0 * power_scale * tanh(20.0 * omega_gnd_now)
            else
                p_step.k_mppt * omega_gnd_now^2
            end

            T_mx = 0.0
            n_sl = 0
            for s in 1:n_seg
                for j in 1:n_lines_p
                    T_ij = _mid_t(s, j)
                    T_mx = max(T_mx, T_ij)
                    T_ij < 5.0 && (n_sl += 1)
                end
            end

            times_v[fi]       = t
            omega_hub_v[fi]   = omega_hub_now
            omega_gnd_v[fi]   = omega_gnd_now
            tau_gen_v[fi]     = tg
            T_max_v[fi]       = T_mx
            n_slack_v[fi]     = n_sl
            payout_v[fi]      = L_winch
            kscale_v[fi]      = k_mppt_scale
            fi += 1
        end
    end

    return DepowerResult(times_v, omega_hub_v, omega_gnd_v, tau_gen_v,
                         T_max_v, n_slack_v, payout_v, kscale_v, brake_time)
end

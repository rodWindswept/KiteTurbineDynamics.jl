export run_canonical_sim!,
    DepowerResult, run_pitch_depower!, override_params, update_kite_pos!

"""
    update_kite_pos!(sys, u, lift_device, p, dt)

Advance `sys.kite_pos` by lagging the relative position vector `r_rel = kite_pos - sa_pos`
toward the instantaneous equilibrium direction:

    r_eq = lift_line_len · lift_dir(p)

The update uses a first-order lag with time constant `KITE_TAU_S` (3 s):

    r_rel .+= (dt / KITE_TAU_S) .* (r_eq .- r_rel)

To model the continuous aerodynamic lift holding the lift line fully taut under normal payout,
we project `r_rel` to exactly `lift_device.line_length` every step:

    r_rel .= (r_rel ./ norm(r_rel)) · lift_line_len

The absolute `sys.kite_pos` is then reconstructed as:

    sys.kite_pos .= sa_pos .+ r_rel

**Why a relative lag?**  The physical kite has inertia and the lift line exerts aerodynamic drag
as it reorients. Using a relative direction lag instead of lagging absolute position ensures that
the lift line is held 100% taut by construction as the sky anchor ascends, transmitting the kite's
lift continuously into the TRPT preloads rather than artificially going slack.
"""
function update_kite_pos!(
    sys::KiteTurbineSystem,
    u::Vector{Float64},
    lift_device::LiftDevice,
    p::SystemParams,
    dt::Float64,
)
    sky_anchor_gid = sys.sky_anchor_id
    sa_pos = @view u[(3 * (sky_anchor_gid - 1) + 1):(3 * sky_anchor_gid)]

    θ_lift = p.lifter_elevation
    lift_dir = [cos(θ_lift), 0.0, sin(θ_lift)]

    # Relative vector from sky anchor to kite
    r_rel = sys.kite_pos .- sa_pos
    r_eq = lift_device.line_length .* lift_dir

    # Euler lag update of the relative vector
    α = min(dt / KITE_TAU_S, 1.0)
    r_rel .+= α .* (r_eq .- r_rel)

    # Project to exact lift line length to keep the lift line 100% taut
    d_rel = norm(r_rel)
    if d_rel > 1e-6
        r_rel .= (r_rel ./ d_rel) .* lift_device.line_length
    else
        r_rel .= lift_device.line_length .* lift_dir
    end

    # Update absolute kite position
    sys.kite_pos .= sa_pos .+ r_rel
    return nothing
end

"""
    run_canonical_sim!(u, sys, p, wind_fn, n_steps, dt; lift_device, lin_damp, callback)

The canonical explicit Euler integration loop, extracted directly from the interactive dashboard.
Provides a unified, headless simulation engine for all batch sweeps and reports.
"""
function run_canonical_sim!(
    u::Vector{Float64},
    sys::KiteTurbineSystem,
    p::SystemParams,
    wind_fn::Function,
    n_steps::Int,
    dt::Float64;
    lift_device::Union{Nothing, LiftDevice}=nothing,
    lin_damp::Float64=0.05,
    callback::Union{Nothing, Function}=nothing,
    spoke::Union{Nothing, KiteTurbineDynamics.SpokeParams}=nothing,
)
    N = sys.n_total
    Nr = sys.n_ring
    # Real operation: enable rope-break detection from here on (option B).
    # The settle's exploratory transients run with breaks disabled.
    sys.breaks_enabled[] = true
    du = zeros(Float64, length(u))
    t = 0.0
    ode_params = if lift_device === nothing
        if spoke === nothing
            (sys, p, wind_fn)
        else
            (sys, p, wind_fn, nothing, spoke)
        end
    else
        if spoke === nothing
            (sys, p, wind_fn, lift_device)
        else
            (sys, p, wind_fn, lift_device, spoke)
        end
    end

    for step in 1:n_steps
        # Rope break early exit (2026-08-14, option B): a broken line
        # disqualifies the design — stop simulating the broken machine.
        sys.any_broken[] && break
        fill!(du, 0.0)
        # ── Pre-ODE NaN/Inf guard: clamp ω, α in state vector ──────────────
        # If α or ω became Inf/NaN in a prior step, the ODE evaluation will
        # crash inside sin/cos before our post-update guards can fire.
        # Clamp to zero here so the ODE sees finite values.  The ring that
        # diverged will have zero twist rate for this step — physically
        # equivalent to "the simulation can no longer trust that ring's state."
        omega_pre = @view u[(6N + Nr + 1):(6N + 2Nr)]
        alpha_pre = @view u[(6N + 1):(6N + Nr)]
        for ri in findall(!isfinite, omega_pre)
            omega_pre[ri] = 0.0
        end
        for ri in findall(!isfinite, alpha_pre)
            alpha_pre[ri] = 0.0
        end
        multibody_ode!(du, u, ode_params, t)
        t += dt

        @views u[(3N + 1):6N] .+= dt .* du[(3N + 1):6N]
        @views u[1:3N] .+= dt .* u[(3N + 1):6N]

        # ── NaN/Inf guard for ring twist derivatives ───────────────────────
        # Expansion-force destabilisation can produce torques that drive ω → Inf.
        # Guard here so that α doesn't get infected and crash sin(α) downstream.
        # Non-finite derivatives are clamped to zero — the step is skipped rather
        # than letting the ring state diverge.
        # ── Save ground-ring ω before explicit Euler step ──────────────────
        # Required by semi-implicit braking correction below.
        omega_gnd_old = u[6N + Nr + 1]
        omega_dot = @view du[(6N + Nr + 1):(6N + 2Nr)]
        unsafe_ri = findall(!isfinite, omega_dot)
        if !isempty(unsafe_ri)
            omega_dot[unsafe_ri] .= 0.0
        end
        @views u[(6N + Nr + 1):(6N + 2Nr)] .+= dt .* omega_dot
        apply_brake_constraint!(u, sys, N, Nr)   # pin ω_gnd=0 when brake latched
        # ── Semi-implicit braking: stabilise k·ω² MPPT term ────────────────
        # Explicit Euler on τ = k·ω² is positive feedback — a small ω
        # perturbation amplifies without bound.  Treat the braking term
        # implicitly on the ground ring:
        #   ω_{n+1} = (ω_n + dt·τ_other/I) / (1 + dt·k·ω_n/I)
        # Denominator > 1 always → unconditionally stable.
        k_mppt_now = sys.k_mppt_ref[]
        if k_mppt_now > 0.01 && omega_gnd_old > 0.1
            omega_gnd_new = u[6N + Nr + 1]
            gnd_gid = sys.ring_ids[1]
            I_z = (sys.nodes[gnd_gid]::RingNode).inertia_z
            du_gen = k_mppt_now * omega_gnd_old^2 / I_z
            du_other = (omega_gnd_new - omega_gnd_old) / dt + du_gen
            denom = 1.0 + dt * k_mppt_now * omega_gnd_old / I_z
            u[6N + Nr + 1] = (omega_gnd_old + dt * du_other) / denom
        end
        if spoke !== nothing && spoke.enabled
            # Spoke spring applied via force accumulation (not post-step projection)
            # Call from here with a local forces array for spoke accumulation only
            f_spoke = zeros(Float64, 3 * N)
            constrain_spokes!(f_spoke, u, sys, N, Nr, p)
            # Apply spoke forces as velocity impulse: Δv = F_spoke · dt / m
            for i in 1:N
                m = sys.nodes[i].mass
                if m > 1e-12
                    v_idx_start = 3N + 3*(i-1) + 1
                    v_idx_end = 3N + 3*i
                    if v_idx_end <= length(u)
                        @views u[v_idx_start:v_idx_end] .+= dt .* f_spoke[(3*(i-1)+1):(3*i)] ./ m
                    end
                end
            end
        end

        # ── Also clamp ω itself if it became Inf/NaN from accumulation ──────
        omega_view = @view u[(6N + Nr + 1):(6N + 2Nr)]
        unsafe_omega = findall(!isfinite, omega_view)
        if !isempty(unsafe_omega)
            omega_view[unsafe_omega] .= 0.0
        end

        @views u[(6N + 1):(6N + Nr)] .+= dt .* u[(6N + Nr + 1):(6N + 2Nr)]

        # ── Clamp α if it became Inf/NaN from ω accumulation ─────────────────
        alpha_view = @view u[(6N + 1):(6N + Nr)]
        unsafe_alpha = findall(!isfinite, alpha_view)
        if !isempty(unsafe_alpha)
            alpha_view[unsafe_alpha] .= 0.0
        end

        if lin_damp > 0.0
            orbital_damp_rope_velocities!(u, sys, p, lin_damp, dt)
        end

        u[1:3] .= 0.0   # ground ring centre stays at origin
        u[(3N + 1):(3N + 3)] .= 0.0   # ground ring translational velocity = 0

        # Advance kite position lag (only when a lift device is present)
        if lift_device !== nothing
            update_kite_pos!(sys, u, lift_device, p, dt)
        end

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
    times::Vector{Float64}   # simulated time at each saved frame (s)
    omega_hub::Vector{Float64}   # hub (rotor) angular velocity (rad/s)
    omega_gnd::Vector{Float64}   # PTO (ground ring) angular velocity (rad/s)
    tau_gen::Vector{Float64}   # generator / brake torque (N·m)
    T_max::Vector{Float64}   # maximum mid-rope tension (N)
    n_slack::Vector{Int}       # tether lines with T < 5 N
    backline_payout::Vector{Float64}   # instantaneous backline payout (m)
    k_mppt_scale::Vector{Float64}   # instantaneous MPPT stall multiplier
    brake_time::Float64           # simulated time when brake first latched (NaN = never)

    # Safety disqualification summary metrics
    T_cyan_min::Float64           # minimum sky anchor tension (N)
    twist_max::Float64           # maximum adjacent ring twist (rad)
    fos_buckling_min::Float64          # minimum CFRP column buckling FoS

    # Advanced Dynamic & Structural Diagnostics (V4 Campaign)
    fos_buckling_ring_id::Int         # ring ID where min buckling FoS occurred
    peak_strut_load::Float64     # peak compressive strut force (N)
    peak_strut_ring_id::Int         # ring ID of peak compressive strut force
    max_out_of_plane_accel::Float64    # max out-of-plane acceleration of ring nodes (m/s²)
    max_node_jerk::Float64     # max rate of acceleration change of ring nodes (m/s³)
    T_trpt_max::Float64     # absolute peak tension in TRPT tethers (N)
    peak_trpt_segment_idx::Int         # segment index of peak TRPT tension
    peak_trpt_line_idx::Int         # line index of peak TRPT tension
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
    fnames = fieldnames(SystemParams)
    ftypes = fieldtypes(SystemParams)
    overrides = Dict{Symbol, Any}(kwargs)
    vals = ntuple(length(fnames)) do i
        return convert(ftypes[i], get(overrides, fnames[i], getfield(base, fnames[i])))
    end
    return SystemParams(vals...)
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
function run_pitch_depower!(
    u::Vector{Float64},
    sys::KiteTurbineSystem,
    p_base::SystemParams,
    wind_fn::Function,
    n_steps::Int,
    dt::Float64;
    lift_device::Union{Nothing, LiftDevice}=nothing,
    use_active_winch::Bool=false,
    use_mppt_stall::Bool=false,
    use_field_imu::Bool=false,
    payout_base::Float64=15.0,
    damping_mode::Float64=0.0,
    depower_sequence::Int=1,
    payout_duration::Float64=NaN,
    save_every::Int=max(1, round(Int, 0.02 / dt)),
    design::Union{Nothing, SpacerRingDesign}=nothing,
)
    N = sys.n_total
    Nr = sys.n_ring

    n_frames = n_steps ÷ save_every
    times_v = Vector{Float64}(undef, n_frames)
    omega_hub_v = Vector{Float64}(undef, n_frames)
    omega_gnd_v = Vector{Float64}(undef, n_frames)
    tau_gen_v = Vector{Float64}(undef, n_frames)
    T_max_v = Vector{Float64}(undef, n_frames)
    n_slack_v = Vector{Int}(undef, n_frames)
    payout_v = Vector{Float64}(undef, n_frames)
    kscale_v = Vector{Float64}(undef, n_frames)

    brake_time = NaN
    kscale_actual = 1.0
    du = zeros(Float64, length(u))
    t = 0.0
    fi = 1
    release_frac = 0.0
    sigmoid_progress = 0.0
    L_winch = 0.0
    v_winch = 0.0
    t_total = n_steps * dt
    n_seg = sys.n_ring - 1
    n_lines_p = p_base.n_lines

    # Node indices for angular velocity extraction
    hub_gid = sys.rotor.node_id
    hub_ri = (sys.nodes[hub_gid]::RingNode).ring_idx
    gnd_ri = (sys.nodes[sys.ring_ids[1]]::RingNode).ring_idx

    geom_scale = p_base.tether_length / 30.0
    max_payout = payout_base * geom_scale

    # Power scale for brake torque — matches ring_forces.jl logic
    power_scale = p_base.p_rated_w / 10_000.0

    T_cyan_min_run = Inf
    twist_max_run = 0.0
    fos_buckling_min_run = Inf

    fos_buckling_ring_id_run = 0
    peak_strut_load_run = 0.0
    peak_strut_ring_id_run = 0
    max_out_of_plane_accel_run = 0.0
    max_node_jerk_run = 0.0
    T_trpt_max_run = 0.0
    peak_trpt_segment_idx_run = 0
    peak_trpt_line_idx_run = 0

    # Acceleration tracking for jerk calculation
    a_prev = zeros(Float64, 3*N)

    # Inline mid-rope tension for segment s, line j
    # (avoids importing visualization helpers; identical formula to _mid_tension)
    _mid_t(s, j) = begin
        idx = (s - 1) * n_lines_p * 4 + (j - 1) * 4 + 2
        idx > length(sys.sub_segs) && return 0.0
        ss = sys.sub_segs[idx]
        pa = @view u[(3 * (ss.end_a.node_id - 1) + 1):(3 * ss.end_a.node_id)]
        pb = @view u[(3 * (ss.end_b.node_id - 1) + 1):(3 * ss.end_b.node_id)]
        max(0.0, ss.EA * (norm(pb .- pa) - ss.length_0) / ss.length_0)
    end

    for step in 1:n_steps
        # ── Depower controller: every 50 steps ≈ 2 ms sim time ─────────────
        if step % 50 == 0
            depower_delay = depower_sequence == 1 ? 0.15 * t_total : 1.0  # 1.0 s absolute startup delay for Seq 2 & 3
            depower_dur = isnan(payout_duration) ? 0.70 * t_total : payout_duration
            target_sig = clamp((t - depower_delay) / depower_dur, 0.0, 1.0)

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
                rate_factor = clamp(T_min_d / 150.0, 0.0, 1.0)
                sigmoid_progress += rate_factor * 0.002 * (target_sig - sigmoid_progress)
            else
                sigmoid_progress = target_sig
            end

            release_frac = 3.0 * sigmoid_progress^2 - 2.0 * sigmoid_progress^3
        end

        # Second-order compliant winch actuator model: steps at the simulation rate dt
        L_target = max_payout * release_frac
        omega_n = 2.0 * pi * 1.0  # 1.0 Hz actuator natural frequency
        zeta_act = 1.0            # Critically damped response
        a_winch = (omega_n^2 * (L_target - L_winch)) - (2.0 * zeta_act * omega_n * v_winch)
        v_winch += dt * a_winch
        L_winch += dt * v_winch

        # Stall governor delay logic for Option 3 with smoothing
        stall_ramp = if depower_sequence == 3
            clamp((release_frac - 0.30) / 0.70, 0.0, 1.0)
        else
            release_frac
        end
        kscale_target = use_mppt_stall ? (1.0 + 8.0 * stall_ramp) : 1.0

        # Smooth out kMPPT using first-order lag with 0.2 s time constant (to match Tulloch damping)
        kscale_actual += (dt / 0.2) * (kscale_target - kscale_actual)
        k_mppt_scale = kscale_actual

        p_step = override_params(
            p_base;
            backline_payout=L_winch,
            k_mppt=p_base.k_mppt * k_mppt_scale,
            β_rate_max=damping_mode,
            kp_elev=use_field_imu ? 1.0 : 0.0,
        )

        ode_p = if isnothing(lift_device)
            (sys, p_step, wind_fn)
        else
            (sys, p_step, wind_fn, lift_device)
        end
        fill!(du, 0.0)
        # ── Pre-ODE NaN/Inf guard: clamp ω, α in state vector ──────────────
        omega_pre = @view u[(6N + Nr + 1):(6N + 2Nr)]
        alpha_pre = @view u[(6N + 1):(6N + Nr)]
        for ri in findall(!isfinite, omega_pre)
            omega_pre[ri] = 0.0
        end
        for ri in findall(!isfinite, alpha_pre)
            alpha_pre[ri] = 0.0
        end
        multibody_ode!(du, u, ode_p, t)
        t += dt

        # ── Whiplash and jerk diagnostics (V4 Campaign) ──
        u_shaft = [cos(p_base.elevation_angle), 0.0, sin(p_base.elevation_angle)]
        for r_idx in 1:Nr
            gid = sys.ring_ids[r_idx]
            a_k = @view du[(3N + 3 * (gid - 1) + 1):(3N + 3 * gid)]
            a_k_perp = a_k .- dot(a_k, u_shaft) .* u_shaft
            max_out_of_plane_accel_run = max(max_out_of_plane_accel_run, norm(a_k_perp))
            if step > 1
                a_prev_k = @view a_prev[(3 * (gid - 1) + 1):(3 * gid)]
                jerk_k = (a_k .- a_prev_k) ./ dt
                max_node_jerk_run = max(max_node_jerk_run, norm(jerk_k))
            end
        end
        a_prev .= @view du[(3N + 1):6N]

        # ── Peak TRPT tension mapping ──
        for s in 1:n_seg
            for j in 1:n_lines_p
                T_ij = _mid_t(s, j)
                if T_ij > T_trpt_max_run
                    T_trpt_max_run = T_ij
                    peak_trpt_segment_idx_run = s
                    peak_trpt_line_idx_run = j
                end
            end
        end

        @views u[(3N + 1):6N] .+= dt .* du[(3N + 1):6N]
        @views u[1:3N] .+= dt .* u[(3N + 1):6N]

        # ── NaN/Inf guard for ring twist derivatives ───────────────────────
        omega_dot = @view du[(6N + Nr + 1):(6N + 2Nr)]
        unsafe_ri = findall(!isfinite, omega_dot)
        if !isempty(unsafe_ri)
            omega_dot[unsafe_ri] .= 0.0
        end
        @views u[(6N + Nr + 1):(6N + 2Nr)] .+= dt .* omega_dot
        apply_brake_constraint!(u, sys, N, Nr)

        # ── Clamp ω and α if they became Inf/NaN from accumulation ──────────
        omega_view = @view u[(6N + Nr + 1):(6N + 2Nr)]
        for ri in findall(!isfinite, omega_view)
            omega_view[ri] = 0.0
        end
        @views u[(6N + 1):(6N + Nr)] .+= dt .* u[(6N + Nr + 1):(6N + 2Nr)]
        alpha_view = @view u[(6N + 1):(6N + Nr)]
        for ri in findall(!isfinite, alpha_view)
            alpha_view[ri] = 0.0
        end

        orbital_damp_rope_velocities!(u, sys, p_step, 0.05, dt)

        # PTO co-braking: damp all ring angular velocities (only in pure MPPT mode 0)
        if release_frac > 0.0 && round(damping_mode) ≈ 0.0
            @views u[(6N + Nr + 1):(6N + 2Nr)] .*= (1.0 - release_frac * 1e-5)
        end

        u[1:3] .= 0.0;
        u[(3N + 1):(3N + 3)] .= 0.0

        # Advance dynamic kite position lag (when a lift device is present)
        if lift_device !== nothing
            update_kite_pos!(sys, u, lift_device, p_step, dt)
        end

        # Latch brake time on first engagement
        if isnan(brake_time) && sys.brake_engaged[]
            brake_time = t
        end

        # --- Dynamic safety metrics evaluated every step ---
        # 1. Sky Anchor Tension
        ss_cyan = sys.sub_segs[end]
        pa_c = @view u[(3 * (ss_cyan.end_a.node_id - 1) + 1):(3 * ss_cyan.end_a.node_id)]
        pb_c = @view u[(3 * (ss_cyan.end_b.node_id - 1) + 1):(3 * ss_cyan.end_b.node_id)]
        T_cyan = max(
            0.0, ss_cyan.EA * (norm(pb_c .- pa_c) - ss_cyan.length_0) / ss_cyan.length_0
        )
        T_cyan_min_run = min(T_cyan_min_run, T_cyan)

        # 2. Adjacent Ring Twist
        alpha_now = @view u[(6N + 1):(6N + Nr)]
        for s in 1:(Nr - 1)
            node_a = sys.nodes[sys.ring_ids[s]]::RingNode
            node_b = sys.nodes[sys.ring_ids[s + 1]]::RingNode
            Δα = mod(alpha_now[node_b.ring_idx] - alpha_now[node_a.ring_idx] + π, 2π) - π
            twist_max_run = max(twist_max_run, abs(Δα))
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

            # 3. Space-Frame CFRP column buckling FoS (evaluated on saved frames)
            min_fos = Inf
            max_comp_N = 0.0
            peak_comp_ring_now = 0
            min_fos_ring_now = 0
            try
                alpha_now = @view u[(6N + 1):(6N + Nr)]
                re_frames = ring_element_analysis(
                    u, alpha_now, sys, p_step, t, wind_fn, design
                )
                for rf in re_frames
                    for b in rf.beams
                        if b.fos < min_fos
                            min_fos = b.fos
                            min_fos_ring_now = rf.ring_id
                        end
                        if b.N > max_comp_N
                            max_comp_N = b.N
                            peak_comp_ring_now = rf.ring_id
                        end
                    end
                end
            catch
                min_fos = 0.0
            end
            if min_fos < fos_buckling_min_run
                fos_buckling_min_run = min_fos
                fos_buckling_ring_id_run = min_fos_ring_now
            end
            if max_comp_N > peak_strut_load_run
                peak_strut_load_run = max_comp_N
                peak_strut_ring_id_run = peak_comp_ring_now
            end

            times_v[fi] = t
            omega_hub_v[fi] = omega_hub_now
            omega_gnd_v[fi] = omega_gnd_now
            tau_gen_v[fi] = tg
            T_max_v[fi] = T_mx
            n_slack_v[fi] = n_sl
            payout_v[fi] = L_winch
            kscale_v[fi] = k_mppt_scale
            fi += 1
        end
    end

    return DepowerResult(
        times_v,
        omega_hub_v,
        omega_gnd_v,
        tau_gen_v,
        T_max_v,
        n_slack_v,
        payout_v,
        kscale_v,
        brake_time,
        T_cyan_min_run,
        twist_max_run,
        fos_buckling_min_run,
        fos_buckling_ring_id_run,
        peak_strut_load_run,
        peak_strut_ring_id_run,
        max_out_of_plane_accel_run,
        max_node_jerk_run,
        T_trpt_max_run,
        peak_trpt_segment_idx_run,
        peak_trpt_line_idx_run,
    )
end

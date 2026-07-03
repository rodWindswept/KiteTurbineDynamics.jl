# src/sim_runner.jl
# Dashboard simulation runner — extracted from visualization.jl.
# Both v1 and v2 layouts call `build_rerun!` to get a scenario runner closure.

"""
    DashboardState

Container for all mutable observables that the dashboard simulation runner
reads from and writes to.  Created once by each layout, passed to `build_rerun!`.
"""
mutable struct DashboardState
    # ── Frame data ───────────────────────────────────────────────────────
    sim_frames_obs::Any
    ext_frames_obs::Any
    frames_obs::Any
    times_ref::Ref{Vector{Float64}}
    frame_obs::Any

    # ── Sliders ──────────────────────────────────────────────────────────
    frame_slider::Any  # Slider — range and value
    speed_slider::Any  # Slider — value
    payout_slider::Any # Slider — value

    # ── Scenarios ────────────────────────────────────────────────────────
    can_rerun::Bool  # true iff u_settled + wind_fn were provided
    scenario_msg_obs::Any
    scenario_msg_color_obs::Any
    system_state_obs::Any  # :idle, :simulating
    sim_dur_obs::Any
    dt_obs::Any
    force_ramp_obs::Any
    pause_obs::Any
    play_pause::Any  # :▶ or :⏸

    # ── Generator & Control ─────────────────────────────────────────────
    gen_ctrl_selection::Any
    depower_payout_selection::Any
    active_winch_obs::Any
    mppt_stall_obs::Any
    field_imu_obs::Any
    depower_seq_obs::Any

    # ── Auto-ramp ────────────────────────────────────────────────────────
    auto_ramp_obs::Any
    ramp_ctrl_obs::Any  # RampController
    ramp_state_obs::Any

    # ── Wind ─────────────────────────────────────────────────────────────
    wind_fn_obs::Any  # current wind function
    hub_z0_ref::Ref{Float64}      # hub-altitude reference
end

"""
    build_rerun!(ds::DashboardState, sys, p, u_settled, wind_fn, lift_device)

Returns a closure `_rerun!(scenario, label, vref)` that runs a simulation
and updates `ds.sim_frames_obs[]`, `ds.ext_frames_obs[]`, and related observables.

Call this once per dashboard build.  Both v1 and v2 layouts call it identically.
"""
function build_rerun!(
    ds::DashboardState,
    sys::KiteTurbineSystem,
    p::SystemParams,
    u_settled::Vector{Float64},
    wind_fn::Function,
    lift_device::Union{Nothing,LiftDevice},
)
    sim_frames_obs    = ds.sim_frames_obs
    ext_frames_obs    = ds.ext_frames_obs
    frames_obs        = ds.frames_obs
    times_ref         = ds.times_ref
    frame_slider      = ds.frame_slider
    speed_slider      = ds.speed_slider
    payout_slider     = ds.payout_slider
    scenario_msg_obs  = ds.scenario_msg_obs
    scenario_msg_color_obs = ds.scenario_msg_color_obs
    system_state_obs  = ds.system_state_obs
    sim_dur_obs       = ds.sim_dur_obs
    dt_obs            = ds.dt_obs
    force_ramp_obs    = ds.force_ramp_obs
    pause_obs         = ds.pause_obs
    play_pause        = ds.play_pause
    gen_ctrl_selection = ds.gen_ctrl_selection
    depower_payout_selection = ds.depower_payout_selection
    active_winch_obs  = ds.active_winch_obs
    mppt_stall_obs    = ds.mppt_stall_obs
    field_imu_obs     = ds.field_imu_obs
    depower_seq_obs   = ds.depower_seq_obs
    auto_ramp_obs     = ds.auto_ramp_obs
    ramp_ctrl_obs     = ds.ramp_ctrl_obs
    ramp_state_obs    = ds.ramp_state_obs
    wind_fn_obs       = ds.wind_fn_obs
    hub_z0_ref        = ds.hub_z0_ref

    N  = sys.n_total
    Nr = sys.n_ring
    dt_nominal = dt_obs[]  # capture initial value

    # ── Safety gate ──────────────────────────────────────────────────────
    _is_safe = let busy = Ref(false)
        function ()
            if busy[]
                return false
            end
            busy[] = true
            return true
        end
    end

    # ── Wind factory (identical to v1 inline) ────────────────────────────
    function _make_wind(vref, scenario, t_total)
        if scenario == :steady
            (pos, t) -> begin
                z = max(pos[3], 1.0); [vref * (z/p.h_ref)^(1/7), 0.0, 0.0]
            end
        elseif scenario == :ramp_down
            (pos, t) -> begin
                z = max(pos[3], 1.0)
                frac = clamp(1.0 - t / t_total, 0.0, 1.0)
                [vref * frac * (z/p.h_ref)^(1/7), 0.0, 0.0]
            end
        elseif scenario == :ramp_up
            (pos, t) -> begin
                z = max(pos[3], 1.0)
                frac = clamp(t / t_total, 0.0, 1.0)
                [vref * frac * (z/p.h_ref)^(1/7), 0.0, 0.0]
            end
        elseif scenario == :gust
            (pos, t) -> begin
                z = max(pos[3], 1.0)
                gust = 1.0 + 0.3*sin(2π*t/5.0) + 0.15*sin(2π*t/2.3)
                [vref * gust * (z/p.h_ref)^(1/7), 0.0, 0.0]
            end
        elseif scenario == :pitch_depower
            (pos, t) -> begin
                z = max(pos[3], 1.0); sh = (z/p.h_ref)^(1/7)
                [Float64(vref)*sh, 0.0, 0.0]
            end
        else   # :land
            (pos, t) -> begin
                v = t < 30.0 ? vref*(1.0-t*0.9/30.0) : vref*0.1*max(0.0,1.0-(t-30.0)/10.0)
                z = max(pos[3], 1.0); [v * (z/p.h_ref)^(1/7), 0.0, 0.0]
            end
        end
    end

    function _rerun!(scenario, label, vref)
        if !_is_safe()
            scenario_msg_color_obs[] = :orangered
            scenario_msg_obs[]       = "⚠  Busy — wait for current operation to finish"
            return
        end
        system_state_obs[] = :simulating
        if !ds.can_rerun
            scenario_msg_color_obs[] = :orangered
            scenario_msg_obs[]       = "⚠  provide u_settled & wind_fn to enable reruns"
            system_state_obs[]       = :idle
            return
        end
        scenario_msg_color_obs[] = :orange
        t_run  = sim_dur_obs[]
        dt_run = dt_obs[]
        n_run  = round(Int, t_run / dt_run)
        scenario_msg_obs[] = "⟳  Running $label …  ($(round(Int,t_run)) s, dt=$dt_run)"
        hub_z0_ref[] = NaN

        # ── Build scenario inputs ──────────────────────────────────────────
        local wf, p_run, u_s, ode_p, ld, t_total, ctrl_mode_val, n_steps_local, dt_local
        try
            n_steps_local = n_run; dt_local = dt_run
            t_total = n_steps_local * dt_local
            wf = _make_wind(Float64(vref), scenario, t_total)
            wind_fn_obs[] = wf
            gen_sel = gen_ctrl_selection[]
            ctrl_mode_val = gen_sel == "Active Damping (Mode 1)" ? 1.0 :
                            gen_sel == "LPF Speed (Mode 2)"      ? 2.0 : 0.0
        catch e
            scenario_msg_color_obs[] = :red
            scenario_msg_obs[] = "✗  Error building scenario: $e"
            system_state_obs[] = :idle
            return
        end

        # ── Build run parameters ──────────────────────────────────────────
        local p_run2, u_s2, ode_p2, ld2
        try
            dl = depower_payout_selection[]
            payout_val = dl == "10m Standard" ? 10.0 : dl == "25m Extended" ? 25.0 : 10.0
            p_run2 = modified_params(p; v_wind_ref=Float64(vref), ctrl_mode=ctrl_mode_val, backline_payout=dl == "0m (none)" ? 0.0 : payout_val)
            fs = force_ramp_obs[]
            u_s2 = deepcopy(u_settled)
            ode_p2 = p_run2
            ld2 = lift_device
        catch e
            scenario_msg_color_obs[] = :red
            scenario_msg_obs[] = "✗  Error building parameters: $e"
            system_state_obs[] = :idle
            return
        end

        # ── Run simulation ─────────────────────────────────────────────────
        try
            sim_dt         = dt_run
            n_steps        = n_steps_local
            save_every     = 200
            n_frames_out   = n_steps ÷ save_every
            new_frames     = Vector{Vector{Float64}}(undef, n_frames_out)
            new_times      = Vector{Float64}(undef, n_frames_out)
            new_sim_frames = Vector{SimFrame}(undef, n_frames_out)
            new_ext_frames = Vector{ExtendedSimFrame}(undef, n_frames_out)

            u  = copy(u_s2); du = zeros(Float64, length(u))
            t  = 0.0; fi = 1
            release_frac = 0.0; sigmoid_progress = 0.0
            L_winch = 0.0; v_winch = 0.0
            use_active_winch = active_winch_obs[]
            use_mppt_stall   = mppt_stall_obs[]
            use_field_imu    = field_imu_obs[]
            depower_seq      = depower_seq_obs[]
            seq_delay_frac   = depower_seq == 1 ? 0.15 : 0.0
            seq_stall_delayed = depower_seq == 3
            n_seg_dyn = Nr - 1
            ea_rope   = sys.sub_segs[1].EA
            p_active  = p_run2
            k_mppt_scale = 1.0

            for step in 1:n_steps
                if scenario == :pitch_depower && step % 50 == 0
                    # Depower logic — identical to v1
                    depower_delay    = depower_seq == 1 ? 0.15 * t_total : 1.0
                    depower_duration = 0.70 * t_total
                    target_sig       = clamp((t - depower_delay) / depower_duration, 0.0, 1.0)
                    payout_base = p_run2.β_min < 5.0 ? 15.0 : p_run2.β_min
                    geom_scale  = p_run2.tether_length / 30.0
                    max_payout  = payout_base * geom_scale
                    if use_active_winch && target_sig > sigmoid_progress
                        hub_gid_d = sys.rotor.node_id
                        hub_ri_d  = (sys.nodes[hub_gid_d]::RingNode).ring_idx
                        perp1_d, perp2_d = _tilted_ring_basis(u, sys, hub_gid_d, hub_ri_d)
                        T_min_d = Inf
                        for s2 in 1:n_seg_dyn
                            seg_sum_d = 0.0
                            for j in 1:p_run2.n_lines
                                seg_nat_len_d = 4 * sys.sub_segs[(s2-1)*p_run2.n_lines*4 + 1].length_0
                                gid_a_d = sys.ring_ids[s2]; gid_b_d = sys.ring_ids[s2+1]
                                na_d    = sys.nodes[gid_a_d]::RingNode
                                nb_d    = sys.nodes[gid_b_d]::RingNode
                                ctr_a_d = u[3*(gid_a_d-1)+1 : 3*gid_a_d]
                                ctr_b_d = u[3*(gid_b_d-1)+1 : 3*gid_b_d]
                                α_a_d   = u[6N + na_d.ring_idx]
                                α_b_d   = u[6N + nb_d.ring_idx]
                                pa_d    = attachment_point(ctr_a_d, na_d.radius, α_a_d, j, p_run2.n_lines, perp1_d, perp2_d)
                                pb_d    = attachment_point(ctr_b_d, nb_d.radius, α_b_d, j, p_run2.n_lines, perp1_d, perp2_d)
                                T_d     = max(0.0, ea_rope * (norm(pb_d .- pa_d) - seg_nat_len_d) / seg_nat_len_d)
                                seg_sum_d += T_d
                            end
                            T_min_d = min(T_min_d, seg_sum_d / p_run2.n_lines)
                        end
                        rate_factor = clamp(T_min_d / 150.0, 0.0, 1.0)
                        sigmoid_progress += rate_factor * 0.002 * (target_sig - sigmoid_progress)
                    else
                        sigmoid_progress = target_sig
                    end
                    payout_now = target_sig * max_payout
                    p_active = deepcopy(p_run2)
                    p_active.backline_payout = payout_now
                end

                du2 = zeros(length(u))
                multibody_ode!(du2, u, (sys, p_active, wf), t)
                u[3N+1:6N] .+= sim_dt .* du2[3N+1:6N]
                u[1:3N]     .+= sim_dt .* u[3N+1:6N]
                u[6N+Nr+1:6N+2Nr] .+= sim_dt .* du2[6N+Nr+1:6N+2Nr]
                apply_brake_constraint!(u, sys, N, Nr)
                u[6N+1:6N+Nr] .+= sim_dt .* u[6N+Nr+1:6N+2Nr]
                u[1:3] .= 0.0; u[3N+1:3N+3] .= 0.0
                t += sim_dt

                if ld2 !== nothing && mod(step, 50) == 0
                    update_kite_pos!(sys, u, ld2, p_active, sim_dt)
                end

                if step % save_every == 0
                    new_frames[fi]     = copy(u)
                    new_times[fi]      = t
                    new_sim_frames[fi] = capture_frame(u, sys, p_active, t, wf, ld2; brake_engaged=sys.brake_engaged[])
                    new_ext_frames[fi] = capture_extended(u, sys, p_active, t, wf, ld2; brake_engaged=sys.brake_engaged[])
                    if auto_ramp_obs[]
                        ctrl_dt = sim_dt * save_every
                        ctrl = ramp_ctrl_obs[]
                        sf = new_sim_frames[fi]
                        min_fos_val = sf.fos_ring
                        collapse_margin = min_collapse_margin(u, sys, ctrl)
                        new_state = update_ramp!(ctrl, sys, sf, ctrl_dt;
                            min_fos=min_fos_val, collapse_margin_deg=collapse_margin)
                        ramp_state_obs[] = state_label(ctrl)
                    end
                    fi += 1
                end
            end

            nf = length(new_frames)
            times_ref[]      = new_times
            frames_obs[]     = new_frames
            sim_frames_obs[] = new_sim_frames
            ext_frames_obs[] = new_ext_frames
            try; frame_slider.range[] = 1:nf; frame_slider.value[] = 1; catch; end
            scenario_msg_color_obs[] = :lawngreen
            scenario_msg_obs[] = @sprintf("✓  %s complete — %d frames", label, nf)
        catch e
            scenario_msg_color_obs[] = :red
            scenario_msg_obs[] = "✗  Simulation failed: $e"
            system_state_obs[] = :idle
            return
        end

        system_state_obs[] = :idle
        nothing
    end

    return _rerun!
end

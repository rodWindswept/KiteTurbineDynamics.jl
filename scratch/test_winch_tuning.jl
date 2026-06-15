# scratch/test_winch_tuning.jl
# Test whether further winch tuning (winch threshold, rate, or active damping)
# can prevent tethers from going slack and keep the minimum buckling FoS above 1.5 during payout.

using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics
using LinearAlgebra, Printf

function test_winch(winch_threshold::Float64, winch_rate_gain::Float64)
    p_base = params_10kw()
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
    u_s = settle_to_operational_state(sys, u0, p_base, ω_rated;
                lift_device = lift_dev, wind_fn = wind_fn)

    # We will simulate 8.0 seconds at dt = 1e-5 s
    dt = 1e-5
    duration_s = 8.0
    n_steps = round(Int, duration_s / dt)
    save_every = round(Int, 0.20 / dt)

    sys.brake_engaged[] = false

    N = sys.n_total
    Nr = sys.n_ring
    n_seg = sys.n_ring - 1
    n_lines_p = p_base.n_lines
    hub_gid = sys.rotor.node_id
    hub_ri  = (sys.nodes[hub_gid]::RingNode).ring_idx

    geom_scale = p_base.tether_length / 30.0
    max_payout = 15.0 * geom_scale

    u = copy(u_s)
    du = zeros(Float64, length(u))
    t = 0.0

    _mid_t(u, s, j) = begin
        idx = (s - 1) * n_lines_p * 4 + (j - 1) * 4 + 2
        idx > length(sys.sub_segs) && return 0.0
        ss = sys.sub_segs[idx]
        pa = @view u[3*(ss.end_a.node_id - 1) + 1 : 3*ss.end_a.node_id]
        pb = @view u[3*(ss.end_b.node_id - 1) + 1 : 3*ss.end_b.node_id]
        max(0.0, ss.EA * (norm(pb .- pa) - ss.length_0) / ss.length_0)
    end

    sigmoid_progress = 0.0
    release_frac     = 0.0
    L_winch          = 0.0
    v_winch          = 0.0
    
    min_fos_overall = Inf
    worst_ring_overall = 0
    max_slack_overall = 0
    t_min_overall = Inf

    for step in 1:n_steps
        # Winch controller with custom threshold and gain
        if step % 50 == 0
            depower_delay    = 1.0
            depower_dur      = 15.0
            target_sig       = clamp((t - depower_delay) / depower_dur, 0.0, 1.0)
            
            T_min_d = Inf
            for s in 1:n_seg
                seg_sum = 0.0
                for j in 1:n_lines_p
                    seg_sum += _mid_t(u, s, j)
                end
                T_min_d = min(T_min_d, seg_sum / n_lines_p)
            end
            
            # Use tuned threshold and winch_rate_gain
            rate_factor      = clamp(T_min_d / winch_threshold, 0.0, 1.0)
            sigmoid_progress += rate_factor * winch_rate_gain * (target_sig - sigmoid_progress)
            release_frac = 3.0 * sigmoid_progress^2 - 2.0 * sigmoid_progress^3
        end

        L_target  = max_payout * release_frac
        omega_n   = 2.0 * pi * 1.0
        zeta_act  = 1.0
        a_winch   = (omega_n^2 * (L_target - L_winch)) - (2.0 * zeta_act * omega_n * v_winch)
        v_winch  += dt * a_winch
        L_winch  += dt * v_winch

        p_step = override_params(p_base;
            backline_payout = L_winch,
            kp_elev         = 1.0)

        fill!(du, 0.0)
        multibody_ode!(du, u, (sys, p_step, wind_fn, lift_dev), t)
        t += dt

        @views u[3N+1:6N]        .+= dt .* du[3N+1:6N]
        @views u[1:3N]            .+= dt .* u[3N+1:6N]
        @views u[6N+Nr+1:6N+2Nr] .+= dt .* du[6N+Nr+1:6N+2Nr]
        @views u[6N+1:6N+Nr]     .+= dt .* u[6N+Nr+1:6N+2Nr]

        orbital_damp_rope_velocities!(u, sys, p_step, 0.05)
        u[1:3] .= 0.0; u[3N+1:3N+3] .= 0.0

        if step % save_every == 0
            T_mx = 0.0
            n_sl = 0
            for s in 1:n_seg
                for j in 1:n_lines_p
                    T_ij = _mid_t(u, s, j)
                    T_mx = max(T_mx, T_ij)
                    T_ij < 5.0 && (n_sl += 1)
                end
            end
            
            t_min_overall = min(t_min_overall, T_mx)
            max_slack_overall = max(max_slack_overall, n_sl)

            min_fos = Inf
            worst_ring = 0
            try
                alpha_now = @view u[6N+1 : 6N+Nr]
                re_frames = ring_element_analysis(u, alpha_now, sys, p_step, t, wind_fn)
                for rf in re_frames
                    for b in rf.beams
                        if b.fos < min_fos
                            min_fos = b.fos
                            worst_ring = rf.ring_id
                        end
                    end
                end
            catch
                min_fos = 0.0
            end
            
            if min_fos < min_fos_overall
                min_fos_overall = min_fos
                worst_ring_overall = worst_ring
            end
        end
    end
    
    @printf("Threshold: %5.1f N | Gain: %.4f | Min Buckling FoS: %8.3f (Ring %2d) | Max Slack: %2d | Payout Reached: %5.2fm\n",
            winch_threshold, winch_rate_gain, min_fos_overall, worst_ring_overall, max_slack_overall, L_winch)
    return min_fos_overall
end

function main()
    println("="^100)
    println("Winch Controller Parameter Tuning Gate")
    println("="^100)
    flush(stdout)
    
    # Sweep over winch threshold and controller rate gain
    # Baseline: threshold=150.0 N, gain=0.002
    test_winch(150.0, 0.002)   # Baseline
    test_winch(300.0, 0.002)
    test_winch(400.0, 0.002)
    test_winch(450.0, 0.002)
    test_winch(400.0, 0.001)   # Slower Winch response
    test_winch(450.0, 0.001)
    test_winch(500.0, 0.001)
end

main()

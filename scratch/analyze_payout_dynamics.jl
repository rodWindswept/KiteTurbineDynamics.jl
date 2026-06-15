# scratch/analyze_payout_dynamics.jl
# Run custom 8.0s Pitch Depower simulation at dt = 1e-5 s and print detailed per-frame structural metrics.

using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics
using LinearAlgebra, Printf

function main()
    println("="^100)
    println("Analyzing Pitch Depower Transient Dynamics & Buckling Timeline (dt = 1.0e-5 s)")
    println("==================================================================================")
    flush(stdout)

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

    # Simulate 8.0 seconds at dt = 1e-5 s
    dt = 1e-5
    duration_s = 8.0
    n_steps = round(Int, duration_s / dt)
    save_every = round(Int, 0.20 / dt) # Save every 200 ms for a clean table

    sys.brake_engaged[] = false

    N = sys.n_total
    Nr = sys.n_ring
    n_seg = sys.n_ring - 1
    n_lines_p = p_base.n_lines
    hub_gid = sys.rotor.node_id
    hub_ri  = (sys.nodes[hub_gid]::RingNode).ring_idx
    gnd_ri  = (sys.nodes[sys.ring_ids[1]]::RingNode).ring_idx

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

    println("  t (s) | Payout (m) | Max Tension (N) | Slack Count | Min Buckling FoS | Worst Ring | Hub Speed (rad/s) | Gnd Speed (rad/s)")
    println("  -------------------------------------------------------------------------------------------------------------------------")
    
    sigmoid_progress = 0.0
    release_frac     = 0.0
    L_winch          = 0.0
    v_winch          = 0.0

    for step in 1:n_steps
        # Winch controller
        if step % 50 == 0
            depower_delay    = 1.0  # 1.0 s startup delay
            depower_dur      = 15.0 # 15s payout duration
            target_sig       = clamp((t - depower_delay) / depower_dur, 0.0, 1.0)
            
            # Active winch feedback
            T_min_d = Inf
            for s in 1:n_seg
                seg_sum = 0.0
                for j in 1:n_lines_p
                    seg_sum += _mid_t(u, s, j)
                end
                T_min_d = min(T_min_d, seg_sum / n_lines_p)
            end
            rate_factor      = clamp(T_min_d / 150.0, 0.0, 1.0)
            sigmoid_progress += rate_factor * 0.002 * (target_sig - sigmoid_progress)
            release_frac = 3.0 * sigmoid_progress^2 - 2.0 * sigmoid_progress^3
        end

        # Compliant winch actuator
        L_target  = max_payout * release_frac
        omega_n   = 2.0 * pi * 1.0
        zeta_act  = 1.0
        a_winch   = (omega_n^2 * (L_target - L_winch)) - (2.0 * zeta_act * omega_n * v_winch)
        v_winch  += dt * a_winch
        L_winch  += dt * v_winch

        p_step = override_params(p_base;
            backline_payout = L_winch,
            kp_elev         = 1.0) # Field IMU on

        fill!(du, 0.0)
        multibody_ode!(du, u, (sys, p_step, wind_fn, lift_dev), t)
        t += dt

        @views u[3N+1:6N]        .+= dt .* du[3N+1:6N]
        @views u[1:3N]            .+= dt .* u[3N+1:6N]
        @views u[6N+Nr+1:6N+2Nr] .+= dt .* du[6N+Nr+1:6N+2Nr]
        @views u[6N+1:6N+Nr]     .+= dt .* u[6N+Nr+1:6N+2Nr]

        orbital_damp_rope_velocities!(u, sys, p_step, 0.05)
        u[1:3] .= 0.0; u[3N+1:3N+3] .= 0.0

        # Print state on saved frames
        if step % save_every == 0
            omega_hub_now = u[6N + Nr + hub_ri]
            omega_gnd_now = u[6N + Nr + gnd_ri]

            T_mx = 0.0
            n_sl = 0
            for s in 1:n_seg
                for j in 1:n_lines_p
                    T_ij = _mid_t(u, s, j)
                    T_mx = max(T_mx, T_ij)
                    T_ij < 5.0 && (n_sl += 1)
                end
            end

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

            @printf("  %5.2f |  %9.3f |  %14.2f |  %10d |  %15.3f |  %10d |  %17.3f |  %17.3f\n",
                    t, L_winch, T_mx, n_sl, min_fos, worst_ring, omega_hub_now, omega_gnd_now)
            flush(stdout)
        end
    end
end

main()

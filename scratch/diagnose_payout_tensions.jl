# scratch/diagnose_payout_tensions.jl
#
# DIAGNOSTIC: Trace ALL tension components frame-by-frame during backline payout.
#
# Investigates the user's physical question:
#   "When we release the backline, shouldn't tension INCREASE through the system
#    (kite is now freer to rise), rather than the TRPT tethers going slack?"
#
# Records at every save frame:
#   1. Backline tension (back line from sky anchor → ground anchor) - is it slack?
#   2. T_cyan  (cyan line: bearing → sky anchor)
#   3. T_kite_approx  (kite lift force magnitude from aerodynamics)
#   4. Sky anchor height z (did it actually rise?)
#   5. Bearing height z
#   6. Mean TRPT tether tension (averaged across all segments/lines)
#   7. Min TRPT tether tension (weakest segment)
#   8. Slack segment count
#   9. Backline payout L_winch
#
# This exposes whether:
#   a) The sky anchor actually rises on payout (physics says it should)
#   b) T_cyan increases (bearing being pulled up by kite winning the tug-of-war)
#   c) Or whether something in the model inverts the expected behaviour

using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics
using LinearAlgebra, Printf

function diagnose_payout_tensions()
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

    dt = 1e-5
    duration_s = 8.0
    n_steps    = round(Int, duration_s / dt)
    save_every = round(Int, 0.05 / dt)   # save every 50ms for fine resolution

    sys.brake_engaged[] = false

    N         = sys.n_total
    Nr        = sys.n_ring
    n_seg     = sys.n_ring - 1
    n_lines_p = p_base.n_lines

    bearing_gid    = sys.bearing_id
    sky_anchor_gid = sys.sky_anchor_id

    geom_scale = p_base.tether_length / 30.0
    max_payout = 15.0 * geom_scale

    # ------ Backline geometry constants (MUST match ring_forces.jl) ------
    back_ax        = p_base.tether_length * cos(p_base.elevation_angle) + p_base.back_anchor_fwd_x
    bearing_offset = 6.0
    cyan_L0_const  = 5.0
    L_axis_design  = p_base.tether_length + bearing_offset + cyan_L0_const
    design_sa_x    = L_axis_design * cos(p_base.elevation_angle)
    design_sa_z    = L_axis_design * sin(p_base.elevation_angle)
    back_L0_design = sqrt((design_sa_x - back_ax)^2 + design_sa_z^2)

    # Initial kite position is set by build_kite_turbine_system (from p.lifter_elevation)
    # and evolves via update_kite_pos! each step. No frozen reference needed.
    lift_line_len = lift_dev.line_length   # 25.0 m

    # Cyan line sub-segment (last one in sub_segs list)
    ss_cyan = sys.sub_segs[end]
    cyan_EA = ss_cyan.EA
    cyan_L0 = ss_cyan.length_0

    # Helper: mid-rope tension for TRPT segment s, line j
    _mid_t(u, s, j) = begin
        idx = (s - 1) * n_lines_p * 4 + (j - 1) * 4 + 2
        idx > length(sys.sub_segs) && return 0.0
        ss = sys.sub_segs[idx]
        pa = @view u[3*(ss.end_a.node_id - 1) + 1 : 3*ss.end_a.node_id]
        pb = @view u[3*(ss.end_b.node_id - 1) + 1 : 3*ss.end_b.node_id]
        max(0.0, ss.EA * (norm(pb .- pa) - ss.length_0) / ss.length_0)
    end

    sigmoid_progress = 0.0
    L_winch          = 0.0
    v_winch          = 0.0
    release_frac     = 0.0

    u  = copy(u_s)
    du = zeros(Float64, length(u))
    t  = 0.0

    # Print geometry header
    println("\n--- Design geometry ---")
    @printf("  TRPT tether length:          %.1f m\n", p_base.tether_length)
    @printf("  Design shaft elevation:      %.1f°\n", rad2deg(p_base.elevation_angle))
    @printf("  Lifter elevation:            %.1f°\n", rad2deg(p_base.lifter_elevation))
    @printf("  Design sky anchor pos:       (x=%.2f, z=%.2f) m\n", design_sa_x, design_sa_z)
    @printf("  Dynamic kite pos (init):     (x=%.2f, z=%.2f) m\n", sys.kite_pos[1], sys.kite_pos[3])
    @printf("  Back anchor x:               %.2f m\n", back_ax)
    @printf("  Back line design rest len:   %.2f m\n", back_L0_design)
    @printf("  Cyan line rest length:       %.2f m\n", cyan_L0)
    _, T_kite_design, elev_lift = lift_force_steady(lift_dev, p_base.rho, p_base.v_wind_ref, p_base)
    @printf("  Kite lift at %.1f m/s:        %.1f N (elev %.1f°)\n",
            p_base.v_wind_ref, T_kite_design, elev_lift)

    # Print initial state
    sa0 = @view u_s[3*(sky_anchor_gid-1)+1 : 3*sky_anchor_gid]
    brg0 = @view u_s[3*(bearing_gid-1)+1    : 3*bearing_gid]
    pa0 = @view u_s[3*(ss_cyan.end_a.node_id - 1) + 1 : 3*ss_cyan.end_a.node_id]
    pb0 = @view u_s[3*(ss_cyan.end_b.node_id - 1) + 1 : 3*ss_cyan.end_b.node_id]
    T_cyan0 = max(0.0, cyan_EA * (norm(pb0 .- pa0) - cyan_L0) / cyan_L0)
    println("\n--- Settled state (before payout) ---")
    @printf("  Sky anchor z:     %.3f m   (design = %.3f m)\n", sa0[3], design_sa_z)
    @printf("  Bearing z:        %.3f m\n", brg0[3])
    @printf("  T_cyan:           %.1f N\n", T_cyan0)

    # Print header
    println()
    @printf("%-6s %-8s %-8s %-9s %-9s %-9s %-9s %-10s %-8s %-6s %-8s\n",
            "t(s)", "Pay(m)", "T_bkL(N)", "T_cyan(N)", "T_kite(N)",
            "SA_z(m)", "Brg_z(m)", "TRPT_mn(N)", "TRPTmin", "n_slk", "Kite_z(m)")
    println("-"^100)

    for step in 1:n_steps
        # Winch controller (baseline parameters: threshold=150N, gain=0.002)
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
            rate_factor       = clamp(T_min_d / 150.0, 0.0, 1.0)
            sigmoid_progress += rate_factor * 0.002 * (target_sig - sigmoid_progress)
            release_frac      = 3.0 * sigmoid_progress^2 - 2.0 * sigmoid_progress^3
        end

        L_target = max_payout * release_frac
        omega_n  = 2.0 * pi * 1.0
        zeta_act = 1.0
        a_winch  = (omega_n^2 * (L_target - L_winch)) - (2.0 * zeta_act * omega_n * v_winch)
        v_winch += dt * a_winch
        L_winch += dt * v_winch

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

        # Advance dynamic kite position lag — critical for the lagged kite model
        update_kite_pos!(sys, u, lift_dev, p_step, dt)

        if step % save_every == 0
            # 1. Sky anchor and bearing positions
            sa_pos  = u[3*(sky_anchor_gid-1)+1 : 3*sky_anchor_gid]
            brg_pos = u[3*(bearing_gid-1)+1    : 3*bearing_gid]

            # 2. Cyan line tension (bearing → sky anchor)
            pa_c = @view u[3*(ss_cyan.end_a.node_id - 1) + 1 : 3*ss_cyan.end_a.node_id]
            pb_c = @view u[3*(ss_cyan.end_b.node_id - 1) + 1 : 3*ss_cyan.end_b.node_id]
            T_cyan_now = max(0.0, cyan_EA * (norm(pb_c .- pa_c) - cyan_L0) / cyan_L0)

            # 3. Backline slack/tension check
            b_dx   = sqrt((sa_pos[1] - back_ax)^2 + sa_pos[2]^2)
            b_dz   = sa_pos[3]
            b_dist = sqrt(b_dx^2 + b_dz^2)
            back_L0_now = back_L0_design + L_winch
            T_back_approx = 0.0
            if b_dist > back_L0_now + 1e-6
                strain = (b_dist - back_L0_now) / back_L0_now
                T_back_approx = p_base.EA_back_line * strain
            end

            # 4. Kite lift force (aerodynamics) at current sky anchor altitude
            v_at_sa  = wind_fn(sa_pos, t)
            v_h_now  = sqrt(v_at_sa[1]^2 + v_at_sa[2]^2)
            _, T_kite_now, _ = lift_force_steady(lift_dev, p_base.rho, v_h_now, p_base)

            # 5. Check distance: sky anchor vs live kite position
            line_to_kite = sys.kite_pos .- sa_pos
            line_dist    = norm(line_to_kite)
            kite_z       = sys.kite_pos[3]

            # 6. TRPT tether tensions
            T_sum   = 0.0
            T_min   = Inf
            n_slack = 0
            n_total_segs = n_seg * n_lines_p
            for s in 1:n_seg
                for j in 1:n_lines_p
                    T_ij = _mid_t(u, s, j)
                    T_sum += T_ij
                    T_min  = min(T_min, T_ij)
                    T_ij < 5.0 && (n_slack += 1)
                end
            end
            T_mean = T_sum / n_total_segs

            # Flag if kite line is shorter than 99% of design (model applies no force)
            kite_flag = line_dist < lift_line_len * 0.99 ? "(slack!)" : "      "

            @printf("%-6.2f %-8.3f %-8.1f %-9.1f %-9.1f %-9.2f %-9.2f %-10.1f %-8.1f %-6d %-8.2f%s\n",
                    t, L_winch, T_back_approx, T_cyan_now, T_kite_now,
                    sa_pos[3], brg_pos[3], T_mean, T_min, n_slack, kite_z, kite_flag)
            flush(stdout)
        end
    end

    println("\nLegend: (slack!) = kite lift line shorter than 99% of design → T_lift = 0")
    println("\nKEY QUESTION: With lagged kite model (τ = ", KiteTurbineDynamics.KITE_TAU_S, " s)...")
    println("  → Does kite_z follow SA_z with a lag? (good: continuous lift during payout)")
    println("  → Does n_slack drop to near-zero compared to frozen kite? (fixed!)")
    println("  → Does TRPT_mn stay positive throughout payout?")
end

diagnose_payout_tensions()

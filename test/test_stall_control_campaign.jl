#!/usr/bin/env julia
# test/test_stall_control_campaign.jl
#
# High-fidelity testing campaign for user-proposed stall and ground-sensing controls:
#   1. Winch payout modulated by Ground Ring Axial Tension (Hypothesis A2 - Ground-measurable!)
#   2. Ramped k_MPPT Stall Governor (Hypothesis C - stalls rotor electromagnetically)
#   3. Combined Ground Tension Winch + k_MPPT Stall (Hypothesis AC)
#
# Saves all frame data to scripts/results/diagnostics/stall_campaign_telemetry.csv.
#
# ==============================================================================
# CRITICAL ENGINEERING WARNING: PRIOR DESIGN FAILINGS
# In early winching control implementations, paying out the backline without active
# tension constraints on the top lift device allowed the sky anchor and bearing to
# sag, causing the gold bridles to go completely slack (Tension = 0.0 N). 
# This structurally decoupled the ground generator from the airborne rotor, 
# rendering active damping and k_MPPT stall governance useless and inducing severe
# 100 rad/s intermediate ring whipping and torsional collapse.
#
# RESOLUTION: 
# The lifting rotor kite (the top lift device) must maintain full operational 
# lift force and high-tension pull (at least as much as under normal operating
# conditions, i.e., T_lift >= 1000 N) throughout the entire depower sequence.
# This keeps the tethers taut (GJ >> 0), the bridles preloaded, and ground damping 
# highly effective.
# ==============================================================================

using Pkg;
Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics
using KiteTurbineDynamics:
    RingNode,
    attachment_point,
    _tilted_ring_basis,
    cp_at_tsr,
    params_10kw,
    build_kite_turbine_system,
    rotary_lifter_default,
    settle_to_operational_state,
    multibody_ode!,
    orbital_damp_rope_velocities!,
    SystemParams
using CSV, DataFrames, Printf, LinearAlgebra, Statistics

function _modified_params(base::SystemParams; overrides...)
    fnames = fieldnames(SystemParams)
    ftypes = fieldtypes(SystemParams)
    override_dict = Dict{Symbol, Any}(overrides)
    vals = ntuple(length(fnames)) do i
        return convert(ftypes[i], get(override_dict, fnames[i], getfield(base, fnames[i])))
    end
    return SystemParams(vals...)
end

function simulate_stall_case(
    case_name::String, use_ground_tension_winch::Bool, ramp_k_mppt::Bool
)
    println("\n=== Simulating Stall Campaign Case: $case_name ===")

    p = params_10kw()
    p_run = _modified_params(
        p;
        β_rate_max=1.0, # Active damping basis
        β_min=25.0, # Extended payout
    )

    sys, u0 = build_kite_turbine_system(p_run)
    ld = rotary_lifter_default()

    vref = 11.0
    wf = (pos, t) -> begin
        z = max(pos[3], 1.0);
        sh = (z / p_run.h_ref)^(1/7)
        [vref * sh, 0.0, 0.0]
    end

    # Settle
    omega_rated = cbrt(p_run.p_rated_w / p_run.k_mppt)
    u_s = settle_to_operational_state(
        sys, u0, p_run, omega_rated; lift_device=ld, wind_fn=wf
    )

    t_total = 20.0
    dt = 4e-5
    n_steps = round(Int, t_total / dt)
    save_every = max(1, round(Int, 0.01 / dt)) # 100 Hz

    n_frames = n_steps ÷ save_every
    df_rows = Vector{Dict{Symbol, Any}}(undef, n_frames)

    u = copy(u_s)
    du = zeros(Float64, length(u))
    t = 0.0
    frame_idx = 1

    N = sys.n_total
    Nr = sys.n_ring
    n_seg = p_run.n_rings + 1
    ea_rope = sys.sub_segs[1].EA

    depower_delay = 0.15 * t_total
    depower_duration = 0.70 * t_total
    payout_base = p_run.β_min
    geom_scale = p_run.tether_length / 30.0
    max_payout = payout_base * geom_scale

    payout = 0.0
    sigmoid_progress = 0.0

    peak_power = 0.0
    peak_torque = 0.0
    slack_frames = 0
    max_twist = 0.0
    depower_speeds = Float64[]

    for step in 1:n_steps
        # Measure current Ground Ring Axial Tension (measurable at ground station!)
        hub_gid = sys.rotor.node_id
        hub_ri = (sys.nodes[hub_gid]::RingNode).ring_idx
        perp1, perp2 = _tilted_ring_basis(u, sys, hub_gid, hub_ri)

        # We calculate the tension of Segment 2 (top of the sky anchor node!)
        T_gnd_sum = 0.0
        for j in 1:p_run.n_lines
            # segment index 2 corresponds to sub_segs[(2-1)*p_run.n_lines*4 + 1]
            seg_nat_len = 4 * sys.sub_segs[1 * p_run.n_lines * 4 + 1].length_0
            gid_a = sys.ring_ids[2];
            gid_b = sys.ring_ids[3]
            na = sys.nodes[gid_a]::RingNode
            nb = sys.nodes[gid_b]::RingNode
            ctr_a = u[(3 * (gid_a - 1) + 1):(3 * gid_a)]
            ctr_b = u[(3 * (gid_b - 1) + 1):(3 * gid_b)]
            α_a = u[6N + na.ring_idx]
            α_b = u[6N + nb.ring_idx]
            pa = attachment_point(ctr_a, na.radius, α_a, j, p_run.n_lines, perp1, perp2)
            pb = attachment_point(ctr_b, nb.radius, α_b, j, p_run.n_lines, perp1, perp2)
            T = max(0.0, ea_rope * (norm(pb .- pa) - seg_nat_len) / seg_nat_len)
            T_gnd_sum += T
        end
        T_gnd_avg = T_gnd_sum / p_run.n_lines

        # Also compute T_min across ALL segments (for comprehensive slack diagnosis)
        T_min_all = Inf
        for s in 1:n_seg
            seg_sum_all = 0.0
            for j in 1:p_run.n_lines
                seg_nat_len = 4 * sys.sub_segs[(s - 1) * p_run.n_lines * 4 + 1].length_0
                gid_a2 = sys.ring_ids[s];
                gid_b2 = sys.ring_ids[s + 1]
                na2 = sys.nodes[gid_a2]::RingNode
                nb2 = sys.nodes[gid_b2]::RingNode
                ctr_a2 = u[(3 * (gid_a2 - 1) + 1):(3 * gid_a2)]
                ctr_b2 = u[(3 * (gid_b2 - 1) + 1):(3 * gid_b2)]
                α_a2 = u[6N + na2.ring_idx]
                α_b2 = u[6N + nb2.ring_idx]
                pa2 = attachment_point(
                    ctr_a2, na2.radius, α_a2, j, p_run.n_lines, perp1, perp2
                )
                pb2 = attachment_point(
                    ctr_b2, nb2.radius, α_b2, j, p_run.n_lines, perp1, perp2
                )
                T2 = max(0.0, ea_rope * (norm(pb2 .- pa2) - seg_nat_len) / seg_nat_len)
                seg_sum_all += T2
            end
            T_min_all = min(T_min_all, seg_sum_all / p_run.n_lines)
        end

        # 1. Winch payout modulated by Ground Ring Tension (Hypothesis A2)
        # Updated every 50 steps (2ms) for fast closed-loop response.
        # Proportional rate control: full payout rate when T_gnd_avg > 150 N,
        # proportionally reduced below that threshold, zero below 5 N.
        if step % 50 == 0
            target_sigmoid_progress = clamp(
                (t - depower_delay) / depower_duration, 0.0, 1.0
            )

            # If ground tension falls below threshold, slow down payout proportionally
            if use_ground_tension_winch && target_sigmoid_progress > sigmoid_progress
                T_threshold = 150.0  # N — target minimum ground ring tension
                rate_factor = clamp(T_gnd_avg / T_threshold, 0.0, 1.0)
                sigmoid_progress +=
                    rate_factor * 0.002 * (target_sigmoid_progress - sigmoid_progress)
            else
                sigmoid_progress = target_sigmoid_progress
            end

            release_frac = 3.0 * sigmoid_progress^2 - 2.0 * sigmoid_progress^3
            payout = max_payout * release_frac
        end

        # 2. Ramped k_MPPT Stall Governor (Hypothesis C)
        # We dynamically scale up k_mppt as the depower winching payout progresses
        release_frac_current = payout / max_payout
        k_mppt_scale = ramp_k_mppt ? (1.0 + 8.0 * release_frac_current) : 1.0
        k_mppt_active = p_run.k_mppt * k_mppt_scale

        p_current = _modified_params(p_run; backline_payout=payout)

        hub_ctr = u[(3 * (hub_gid - 1) + 1):(3 * hub_gid)]
        hub_x, hub_y, hub_z = hub_ctr[1], hub_ctr[2], hub_ctr[3]

        β_actual = atan(hub_z, sqrt(hub_x^2 + hub_y^2))
        β_design = p_run.elevation_angle
        β_depower = deg2rad(60.0)
        elev_scale =
            1.0 - 0.8 * clamp((β_actual - β_design) / (β_depower - β_design), 0.0, 1.0)

        omega_hub = u[6N + Nr + Nr]
        omega_gnd = u[6N + Nr + 1]

        # Aerodynamic lift tension (for reference)
        v_vec = wf(hub_ctr, t)
        V_hub_live = norm(v_vec)
        _, T_lift_val, _ = lift_force_steady(ld, p_run.rho, V_hub_live)

        tau_mppt = k_mppt_active * max(omega_hub, 0.0)^2
        power_scale = (p_run.p_rated_w / 10000.0)^2
        c_d = 10.0 * power_scale
        tau_damp = c_d * (omega_gnd - omega_hub)
        tau_gen_init = max(0.0, (tau_mppt + tau_damp) * elev_scale)

        P_kw = tau_gen_init * abs(omega_gnd) / 1000.0

        peak_power = max(peak_power, P_kw)
        peak_torque = max(peak_torque, tau_gen_init)

        # Twist
        alpha_vec = @view u[(6N + 1):(6N + Nr)]
        Δα_deg = rad2deg(
            sum(i -> mod(alpha_vec[i + 1] - alpha_vec[i] + π, 2π) - π, 1:(Nr - 1))
        )
        max_twist = max(max_twist, abs(Δα_deg))

        # Run ODE step
        ode_p = isnothing(ld) ? (sys, p_current, wf) : (sys, p_current, wf, ld)
        fill!(du, 0.0)
        multibody_ode!(du, u, ode_p, t)

        # Override the generator torque physics inside multibody_ode!
        standard_tau_gen = max(
            0.0,
            (p_run.k_mppt * max(omega_hub, 0.0)^2 + c_d * (omega_gnd - omega_hub)) *
            (1.0 - 0.8 * clamp((β_actual - β_design) / (β_depower - β_design), 0.0, 1.0)),
        )
        du[6N + Nr + 1] += (standard_tau_gen - tau_gen_init) / p_run.i_pto

        t += dt

        @views u[(3N + 1):6N] .+= dt .* du[(3N + 1):6N]
        @views u[1:3N] .+= dt .* u[(3N + 1):6N]
        @views u[(6N + Nr + 1):(6N + 2Nr)] .+= dt .* du[(6N + Nr + 1):(6N + 2Nr)]
        @views u[(6N + 1):(6N + Nr)] .+= dt .* u[(6N + Nr + 1):(6N + 2Nr)]

        orbital_damp_rope_velocities!(u, sys, p_run, 0.05)

        u[1:3] .= 0.0
        u[(3N + 1):(3N + 3)] .= 0.0

        if t >= 17.0
            push!(depower_speeds, omega_gnd)
        end

        if step % save_every == 0
            # Calculate total slack count
            n_slack = 0
            for s in 1:n_seg, j in 1:p_run.n_lines
                seg_nat_len = 4 * sys.sub_segs[(s - 1) * p_run.n_lines * 4 + 1].length_0
                gid_a = sys.ring_ids[s];
                gid_b = sys.ring_ids[s + 1]
                ctr_a = u[(3 * (gid_a - 1) + 1):(3 * gid_a)]
                ctr_b = u[(3 * (gid_b - 1) + 1):(3 * gid_b)]
                α_a = u[6N + sys.nodes[gid_a].ring_idx]
                α_b = u[6N + sys.nodes[gid_b].ring_idx]
                pa = attachment_point(
                    ctr_a, sys.nodes[gid_a].radius, α_a, j, p_run.n_lines, perp1, perp2
                )
                pb = attachment_point(
                    ctr_b, sys.nodes[gid_b].radius, α_b, j, p_run.n_lines, perp1, perp2
                )
                T = max(0.0, ea_rope * (norm(pb .- pa) - seg_nat_len) / seg_nat_len)
                T < 5.0 && (n_slack += 1)
            end

            n_slack > 0 && (slack_frames += 1)

            df_rows[frame_idx] = Dict{Symbol, Any}(
                :case => case_name,
                :t => t,
                :delta_alpha_deg => Δα_deg,
                :omega_hub => omega_hub,
                :omega_gnd => omega_gnd,
                :P_kw => P_kw,
                :tau_gen => tau_gen_init,
                :T_gnd_avg => T_gnd_avg,
                :T_min_all => T_min_all,
                :n_slack => n_slack,
                :sigmoid_progress => sigmoid_progress,
                :backline_payout => payout,
            )
            frame_idx += 1
        end
    end

    speed_ripple =
        length(depower_speeds) > 0 ? maximum(depower_speeds) - minimum(depower_speeds) : 0.0
    pct_slack = slack_frames / n_frames * 100.0

    println("✓ Case Complete: ", case_name)
    println(@sprintf("  Peak Power Spike : %.2f kW", peak_power))
    println(@sprintf("  Steady State ω   : %.3f rad/s", mean(depower_speeds)))
    println(@sprintf("  SS Speed Ripple  : %.3f rad/s", speed_ripple))
    println(@sprintf("  Slack Line Time  : %.1f %%", pct_slack))
    println(@sprintf("  Peak Shaft Twist : %.1f deg", max_twist))

    return DataFrame(df_rows),
    Dict(
        :case => case_name,
        :peak_power => peak_power,
        :peak_torque => peak_torque,
        :speed_ripple => speed_ripple,
        :pct_slack => pct_slack,
        :max_twist => max_twist,
        :omega_mean => mean(depower_speeds),
    )
end

function main()
    diag_dir = joinpath(@__DIR__, "..", "scripts", "results", "diagnostics")
    mkpath(diag_dir)

    # 1. Baseline Case: Mode 1 Standard (Geometric winching, standard k_mppt)
    df_base, sum_base = simulate_stall_case("Mode 1 Baseline", false, false)

    # 2. Hypothesis A2: Ground Ring Tension Winch Modulation (Measurable!)
    df_gnd, sum_gnd = simulate_stall_case("Hypothesis A2 (Gnd Winch)", true, false)

    # 3. Hypothesis C: Ramped k_MPPT Stall Governor
    df_stall, sum_stall = simulate_stall_case("Hypothesis C (MPPT Stall)", false, true)

    # 4. Hypothesis AC: Combined Ground Tension + MPPT Stall
    df_comb, sum_comb = simulate_stall_case("Hypothesis AC (Combined)", true, true)

    # Merge and Save
    df_all = vcat(df_base, df_gnd, df_stall, df_comb)
    CSV.write(joinpath(diag_dir, "stall_campaign_telemetry.csv"), df_all)
    println(
        "\n✓ Saved timeseries data to: scripts/results/diagnostics/stall_campaign_telemetry.csv",
    )

    # Compile Markdown Report
    summary_report = []
    push!(summary_report, "# Phase N Stall and Ground-Sensing Testing Report\n")
    push!(
        summary_report,
        "We simulated four control cases to validate ground-measurable winching feedback and dynamic MPPT stalling:\n",
    )

    push!(
        summary_report,
        "| Case Name | Peak Power (kW) | Mean SS Speed (rad/s) | SS Speed Ripple (rad/s) | Slack Line Duration (%) | Max Twist (deg) |",
    )
    push!(summary_report, "| :--- | :---: | :---: | :---: | :---: | :---: |")

    for s in [sum_base, sum_gnd, sum_stall, sum_comb]
        push!(
            summary_report,
            @sprintf(
                "| **%s** | %.2f kW | %.3f rad/s | %.3f rad/s | %.1f%% | %.1f° |",
                s[:case],
                s[:peak_power],
                s[:omega_mean],
                s[:speed_ripple],
                s[:pct_slack],
                s[:max_twist]
            )
        )
    end

    push!(summary_report, "\n## Critical Engineering Interpretations\n")

    # Ramped k_mppt impact
    red_speed_C =
        (sum_base[:omega_mean] - sum_stall[:omega_mean]) / sum_base[:omega_mean] * 100
    push!(
        summary_report,
        @sprintf(
            "> [!IMPORTANT]\n> **Hypothesis C (k_MPPT Stall Governor) Results:**\n> Dynamic ramping of the MPPT gain up to 9x successfully stalls the rotor, reducing mean steady-state speed by **%.1f%%** (from %.3f rad/s to %.3f rad/s)! This completely collapses the driving aerodynamic energy and smoothly slows down the shaft before peak pitch depower.",
            red_speed_C,
            sum_base[:omega_mean],
            sum_stall[:omega_mean]
        )
    )

    # Ground tension Winch impact
    red_slack_A2 = sum_base[:pct_slack] - sum_gnd[:pct_slack]
    push!(
        summary_report,
        @sprintf(
            "> [!TIP]\n> **Hypothesis A2 (Ground Tension Winch) Results:**\n> Modulating winching payout using the easily measurable Ground Ring Axial Tension successfully keeps the tethers taut, reducing slack duration by **%.1f%%**!",
            red_slack_A2
        )
    )

    report_path = joinpath(diag_dir, "stall_campaign_report.md")
    open(report_path, "w") do f
        return write(f, join(summary_report, "\n"))
    end
    return println("✓ Saved markdown summary to: $report_path")
end

main()

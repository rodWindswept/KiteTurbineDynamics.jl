#!/usr/bin/env julia
# scripts/generate_high_fidelity_diagnostics.jl
#
# Generates high-fidelity timeseries diagnostics for the 3 modes.
# Captures:
#   1. Angular speed of EVERY single ring (to track torsional wave propagation).
#   2. Tension of EVERY single line segment tether (to track the slack-line front).
#   3. Key drivetrain states at 100 Hz sampling (dt = 0.01s, perfect for FFT).

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
using CSV, DataFrames, Printf, LinearAlgebra

# Helper to override SystemParams fields
function _modified_params(base::SystemParams; overrides...)
    fnames = fieldnames(SystemParams)
    ftypes = fieldtypes(SystemParams)
    override_dict = Dict{Symbol, Any}(overrides)
    vals = ntuple(length(fnames)) do i
        return convert(ftypes[i], get(override_dict, fnames[i], getfield(base, fnames[i])))
    end
    return SystemParams(vals...)
end

function run_diagnostics_case(mode_name::String, ctrl_mode::Float64, payout_base::Float64)
    println("\n=== Running Diagnostics Case: $mode_name ===")

    p = params_10kw()
    p_run = _modified_params(p; β_rate_max=ctrl_mode, β_min=payout_base)

    sys, u0 = build_kite_turbine_system(p_run)
    ld = rotary_lifter_default()

    # Wind at 11.0 m/s reference
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

    # Simulation parameters
    t_total = 20.0
    dt = 4e-5
    n_steps = round(Int, t_total / dt)
    save_every = max(1, round(Int, 0.01 / dt)) # 0.01s (100 Hz)

    n_frames = n_steps ÷ save_every
    df_rows = Vector{Dict{Symbol, Any}}(undef, n_frames)

    u = copy(u_s)
    du = zeros(Float64, length(u))
    t = 0.0
    release_frac = 0.0
    frame_idx = 1

    N = sys.n_total
    Nr = sys.n_ring
    n_seg = p_run.n_rings + 1
    ea_rope = sys.sub_segs[1].EA

    depower_delay = 0.15 * t_total
    depower_duration = 0.70 * t_total

    ode_p = isnothing(ld) ? (sys, p_run, wf) : (sys, p_run, wf, ld)

    for step in 1:n_steps
        if step % 500 == 0
            x = clamp((t - depower_delay) / depower_duration, 0.0, 1.0)
            release_frac = 3.0 * x^2 - 2.0 * x^3 # Sigmoid curve

            geom_scale = p_run.tether_length / 30.0
            max_payout = payout_base * geom_scale

            p_depower = _modified_params(p_run; backline_payout=max_payout * release_frac)
            ode_p = isnothing(ld) ? (sys, p_depower, wf) : (sys, p_depower, wf, ld)
        end

        fill!(du, 0.0)
        multibody_ode!(du, u, ode_p, t)
        t += dt

        @views u[(3N + 1):6N] .+= dt .* du[(3N + 1):6N]
        @views u[1:3N] .+= dt .* u[(3N + 1):6N]
        @views u[(6N + Nr + 1):(6N + 2Nr)] .+= dt .* du[(6N + Nr + 1):(6N + 2Nr)]
        @views u[(6N + 1):(6N + Nr)] .+= dt .* u[(6N + Nr + 1):(6N + 2Nr)]

        orbital_damp_rope_velocities!(u, sys, p_run, 0.05)

        # PTO co-braking hack (Mode 0 only!)
        if release_frac > 0.0 && ctrl_mode ≈ 0.0
            @views u[(6N + Nr + 1):(6N + 2Nr)] .*= (1.0 - release_frac * 1e-5)
        end

        # Boundary anchors
        u[1:3] .= 0.0
        u[(3N + 1):(3N + 3)] .= 0.0

        # Save frame at save_every steps
        if step % save_every == 0
            # Current payout info
            geom_scale = p_run.tether_length / 30.0
            max_payout = payout_base * geom_scale
            p_current = _modified_params(p_run; backline_payout=max_payout * release_frac)

            # Extract state
            omega_hub = u[6N + Nr + Nr]
            omega_gnd = u[6N + Nr + 1]
            omega_vec = u[(6N + Nr + 1):(6N + 2Nr)]

            hub_gid = sys.rotor.node_id
            hub_ri = (sys.nodes[hub_gid]::RingNode).ring_idx
            perp1, perp2 = _tilted_ring_basis(u, sys, hub_gid, hub_ri)

            hub_ctr = u[(3 * (hub_gid - 1) + 1):(3 * hub_gid)]
            hub_x, hub_y, hub_z = hub_ctr[1], hub_ctr[2], hub_ctr[3]

            # PTO Torque calculation
            tau_gen_init, _ = get_generator_torque(
                u, sys, p_current, t, wind_fn; brake_engaged=sys.brake_engaged[]
            )

            P_kw = tau_gen_init * abs(omega_gnd) / 1000.0

            # Total shaft twist
            alpha_vec = @view u[(6N + 1):(6N + Nr)]
            Δα_deg = rad2deg(
                sum(i -> mod(alpha_vec[i + 1] - alpha_vec[i] + π, 2π) - π, 1:(Nr - 1))
            )
            Δω = omega_hub - omega_gnd

            # Create frame record
            rec = Dict{Symbol, Any}(
                :t => t,
                :delta_alpha_deg => Δα_deg,
                :delta_omega => Δω,
                :tau_gen => tau_gen_init,
                :P_kw => P_kw,
                :hub_x => hub_x,
                :hub_y => hub_y,
                :hub_z => hub_z,
                :backline_payout => p_current.backline_payout,
            )

            # 1. Store speed of every ring
            for i in 1:Nr
                rec[Symbol("omega_ring_$i")] = omega_vec[i]
            end

            # 2. Store tension of every single line segment
            for s in 1:n_seg, j in 1:p_run.n_lines
                seg_nat_len = 4 * sys.sub_segs[(s - 1) * p_run.n_lines * 4 + 1].length_0
                gid_a = sys.ring_ids[s];
                gid_b = sys.ring_ids[s + 1]
                na = sys.nodes[gid_a]::RingNode
                nb = sys.nodes[gid_b]::RingNode
                ctr_a = u[(3 * (gid_a - 1) + 1):(3 * gid_a)]
                ctr_b = u[(3 * (gid_b - 1) + 1):(3 * gid_b)]
                α_a = u[6N + na.ring_idx]
                α_b = u[6N + nb.ring_idx]
                pa = attachment_point(ctr_a, na.radius, α_a, j, p_run.n_lines, perp1, perp2)
                pb = attachment_point(ctr_b, nb.radius, α_b, j, p_run.n_lines, perp1, perp2)
                T = max(0.0, ea_rope * (norm(pb .- pa) - seg_nat_len) / seg_nat_len)

                rec[Symbol("tension_seg_$(s)_line_$(j)")] = T
            end

            df_rows[frame_idx] = rec

            if frame_idx % 400 == 0
                @printf("  Progress: %.1f s / %.1f s\n", t, t_total)
            end

            frame_idx += 1
        end
    end

    return DataFrame(df_rows)
end

function main()
    diag_dir = joinpath(@__DIR__, "results", "diagnostics")
    mkpath(diag_dir)

    # Run Mode 0
    df0 = run_diagnostics_case("Mode 0", 0.0, 15.0)
    CSV.write(joinpath(diag_dir, "mode0_high_fidelity.csv"), df0)
    println("✓ Saved Mode 0 high-fidelity diagnostics.")

    # Run Mode 1
    df1 = run_diagnostics_case("Mode 1", 1.0, 25.0)
    CSV.write(joinpath(diag_dir, "mode1_high_fidelity.csv"), df1)
    println("✓ Saved Mode 1 high-fidelity diagnostics.")

    # Run Mode 2
    df2 = run_diagnostics_case("Mode 2", 2.0, 25.0)
    CSV.write(joinpath(diag_dir, "mode2_high_fidelity.csv"), df2)
    println("✓ Saved Mode 2 high-fidelity diagnostics.")

    return println("\n✓ All high-fidelity diagnostic simulations complete!")
end

main()

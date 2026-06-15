# scratch/test_no_bisection.jl
# Test if removing the redundant torque-chain bisection and straight-line overwrite
# eliminates the high-frequency tension oscillations.

using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics
using LinearAlgebra, Printf

# We'll define a custom settle_to_operational_state without the bisection overwrite
function custom_settle(sys::KiteTurbineSystem, u0::Vector{Float64}, p::SystemParams, ω_rated_max::Float64;
                       lift_device=nothing, wind_fn=nothing)
    sys.brake_engaged[] = false

    u_start = KiteTurbineDynamics.settle_to_equilibrium(sys, u0, p;
                                     lift_device = lift_device,
                                     wind_fn     = wind_fn)

    N  = sys.n_total
    Nr = sys.n_ring

    v_wind_hub = wind_fn === nothing ? zeros(3) : wind_fn(u_start[3*(sys.rotor.node_id-1)+1 : 3*sys.rotor.node_id], 0.0)
    v_mag = norm(v_wind_hub)
    ω_eq = ω_rated_max
    if v_mag > 0.1
        for w in range(ω_rated_max, 0.1, length=200)
            lambda = w * sys.rotor.radius / v_mag
            P_aero = 0.5 * p.rho * v_mag^3 * π * sys.rotor.radius^2 * cp_at_tsr(lambda) * cos(p.elevation_angle)^3
            P_gen = p.k_mppt * w^3
            if P_aero > P_gen
                ω_eq = w
                break
            end
        end
    else
        ω_eq = 0.0
    end
    τ_eq  = p.k_mppt * ω_eq^2

    # Restore design ring positions with aero-derived axial preload
    β_r   = p.elevation_angle
    sd_r  = [cos(β_r), 0.0, sin(β_r)]
    let
        if lift_device !== nothing
            T_cyan_des = design_preload_from_sky_anchor(p, lift_device)
            n_seg_r    = Nr - 1
            EA_tot     = p.n_lines * p.e_modulus * π * (p.tether_diameter / 2)^2
            k_ax       = EA_tot / (p.tether_length / n_seg_r)
            m_rotor_d  = p.n_blades * p.m_blade
            kite_m_d   = sys.kite.mass
            v_r        = p.v_wind_ref
            thrust_r   = 0.5 * p.rho * v_r^2 * π * p.rotor_radius^2 * 0.8 * cos(β_r)^2
            F_aero_z_r = thrust_r * sin(β_r) + (m_rotor_d + kite_m_d) * (-9.81)
            F_top_ax_r = max(F_aero_z_r / sin(β_r) + T_cyan_des, 20.0)
            g_inc      = p.m_ring * 9.81 / sin(β_r)
            F_ax       = zeros(n_seg_r)
            F_ax[n_seg_r] = F_top_ax_r
            for i in (n_seg_r-1):-1:1
                F_ax[i] = F_ax[i+1] + g_inc
            end
            seg_len = p.tether_length / n_seg_r
            rp = zeros(3)
            for k in 1:Nr
                gid = sys.ring_ids[k]
                idx = 3*(gid-1)+1 : 3*gid
                u_start[idx] .= rp
                if k < Nr
                    stretch = max(0.0, F_ax[k] / k_ax)
                    rp .+= (seg_len + stretch) .* sd_r
                end
            end
        else
            for k in 1:Nr
                gid = sys.ring_ids[k]
                idx = 3*(gid-1)+1 : 3*gid
                u_start[idx] .= u0[idx]
            end
        end
    end

    preload_ring_pos = [u_start[3*(sys.ring_ids[k]-1)+1 : 3*sys.ring_ids[k]] for k in 1:Nr]

    # Uniform ω — zero inter-ring velocity difference at t=0
    for ri in 1:Nr
        u_start[6N + Nr + ri] = ω_eq
    end

    # Operational settle — find bearing equilibrium at ω_rated
    du2 = zeros(Float64, length(u_start))
    wind_use   = wind_fn === nothing ? (pos, t) -> zeros(3) : wind_fn
    ode_params = lift_device === nothing ? (sys, p, wind_use) :
                                            (sys, p, wind_use, lift_device)
    dt_op   = p.n_lines >= 8 ? 1e-5 : 4e-5
    n_op    = 150_000

    for _ in 1:n_op
        fill!(du2, 0.0)
        multibody_ode!(du2, u_start, ode_params, 0.0)
        @views u_start[3N+1:6N]        .+= dt_op .* du2[3N+1:6N]
        @views u_start[1:3N]            .+= dt_op .* u_start[3N+1:6N]
        @views u_start[6N+Nr+1:6N+2Nr] .= ω_eq   # pin ω throughout

        orbital_damp_rope_velocities!(u_start, sys, p, 0.05)

        for k in 1:Nr
            gid = sys.ring_ids[k]
            bv  = 3N + 3*(gid-1) + 1
            u_start[bv : bv+2] .= 0.0
        end
        for k in 1:Nr
            gid = sys.ring_ids[k]
            idx = 3*(gid-1)+1 : 3*gid
            u_start[idx] .= preload_ring_pos[k]
        end
        u_start[1:3]       .= 0.0
        u_start[3N+1:3N+3] .= 0.0
    end
    
    # We do NOT run bisection. Instead, we keep the dynamically-settled rope node positions!
    # Set orbital velocities one last time to make sure velocities are perfect
    set_orbital_velocities!(u_start, sys, p)
    @views u_start[3N + 3*(sys.ring_ids[1]-1)+1 : 3N + 3*sys.ring_ids[1]] .= 0.0

    sys.brake_engaged[] = false
    return u_start
end

function main()
    p_base = params_10kw()
    p_base = override_params(p_base;
        lifter_elevation = deg2rad(75.0),
        v_wind_ref       = 6.0
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
    println("Settling system with custom settle (no bisection overwrite)...")
    u_s = custom_settle(sys, u0, p_base, ω_rated;
                lift_device = lift_dev, wind_fn = wind_fn)
    println("System settled.")

    N = sys.n_total
    Nr = sys.n_ring
    n_seg = sys.n_ring - 1
    n_lines_p = p_base.n_lines

    _mid_t(u, s, j) = begin
        idx = (s - 1) * n_lines_p * 4 + (j - 1) * 4 + 2
        idx > length(sys.sub_segs) && return 0.0
        ss = sys.sub_segs[idx]
        pa = @view u[3*(ss.end_a.node_id - 1) + 1 : 3*ss.end_a.node_id]
        pb = @view u[3*(ss.end_b.node_id - 1) + 1 : 3*ss.end_b.node_id]
        max(0.0, ss.EA * (norm(pb .- pa) - ss.length_0) / ss.length_0)
    end

    # Print initial tension
    T_mx = 0.0
    for s in 1:n_seg
        for j in 1:n_lines_p
            T_mx = max(T_mx, _mid_t(u_s, s, j))
        end
    end
    println("Initial Max Tension: ", T_mx, " N")

    # Run 10 steps
    u = copy(u_s)
    du = zeros(Float64, length(u))
    dt = 4e-5
    t = 0.0
    ode_params = (sys, p_base, wind_fn, lift_dev)

    println("\nStep-by-step evolution (WITHOUT bisection overwrite):")
    println("  Step | Time (ms) | Max Tension (N) | Hub position (Z) | Sky Anchor position (Z) | Bearing position (Z)")
    println("  -------------------------------------------------------------------------------------------------")
    
    hub_gid = sys.rotor.node_id
    sky_anchor_gid = sys.sky_anchor_id
    bearing_gid = sys.bearing_id

    for step in 1:10
        fill!(du, 0.0)
        multibody_ode!(du, u, ode_params, t)
        t += dt

        @views u[3N+1:6N]        .+= dt .* du[3N+1:6N]
        @views u[1:3N]            .+= dt .* u[3N+1:6N]
        @views u[6N+Nr+1:6N+2Nr] .+= dt .* du[6N+Nr+1:6N+2Nr]
        @views u[6N+1:6N+Nr]     .+= dt .* u[6N+Nr+1:6N+2Nr]

        orbital_damp_rope_velocities!(u, sys, p_base, 0.05)
        u[1:3] .= 0.0; u[3N+1:3N+3] .= 0.0

        T_mx_step = 0.0
        for s in 1:n_seg
            for j in 1:n_lines_p
                T_mx_step = max(T_mx_step, _mid_t(u, s, j))
            end
        end

        hp = u[3*(hub_gid-1)+1 : 3*hub_gid]
        sp = u[3*(sky_anchor_gid-1)+1 : 3*sky_anchor_gid]
        bp = u[3*(bearing_gid-1)+1 : 3*bearing_gid]

        @printf("   %2d  |  %8.3f |  %14.2f |  %14.4f |  %22.4f |  %20.4f\n",
                step, t * 1000, T_mx_step, hp[3], sp[3], bp[3])
    end
end

main()

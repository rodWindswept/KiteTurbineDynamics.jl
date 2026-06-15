# scratch/diagnose_first_steps.jl
# Diagnose the first few steps of the dynamic simulation with a smaller dt to test numerical stability.

using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics
using LinearAlgebra, Printf

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
    println("Settling system...")
    u_s = settle_to_operational_state(sys, u0, p_base, ω_rated;
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

    # Let's test two different dts: 1e-5 s and 5e-6 s
    for dt in [1e-5, 5e-6]
        @printf("\n=========================================\n")
        @printf("Testing dt = %.1e s\n", dt)
        @printf("=========================================\n")
        
        u = copy(u_s)
        du = zeros(Float64, length(u))
        t = 0.0
        ode_params = (sys, p_base, wind_fn, lift_dev)

        println("  Step | Time (ms) | Max Tension (N) | Hub Z   | Sky Anchor Z | Bearing Z")
        println("  -----------------------------------------------------------------------")
        
        hub_gid = sys.rotor.node_id
        sky_anchor_gid = sys.sky_anchor_id
        bearing_gid = sys.bearing_id

        # Run for 0.40 ms
        n_steps = round(Int, 0.40e-3 / dt)
        for step in 1:n_steps
            fill!(du, 0.0)
            multibody_ode!(du, u, ode_params, t)
            t += dt

            @views u[3N+1:6N]        .+= dt .* du[3N+1:6N]
            @views u[1:3N]            .+= dt .* u[3N+1:6N]
            @views u[6N+Nr+1:6N+2Nr] .+= dt .* du[6N+Nr+1:6N+2Nr]
            @views u[6N+1:6N+Nr]     .+= dt .* u[6N+Nr+1:6N+2Nr]

            orbital_damp_rope_velocities!(u, sys, p_base, 0.05)
            u[1:3] .= 0.0; u[3N+1:3N+3] .= 0.0

            # Print every few steps to have ~10 rows total
            if step % (n_steps ÷ 10) == 0
                T_mx_step = 0.0
                for s in 1:n_seg
                    for j in 1:n_lines_p
                        T_mx_step = max(T_mx_step, _mid_t(u, s, j))
                    end
                end

                hp = u[3*(hub_gid-1)+1 : 3*hub_gid]
                sp = u[3*(sky_anchor_gid-1)+1 : 3*sky_anchor_gid]
                bp = u[3*(bearing_gid-1)+1 : 3*bearing_gid]

                @printf("   %3d |  %8.3f |  %14.2f |  %6.3f  |  %12.3f  |  %9.3f\n",
                        step, t * 1000, T_mx_step, hp[3], sp[3], bp[3])
            end
        end
    end
end

main()

# scratch/test_steady_state_fos.jl
# Run a single steady-state simulation at 6 m/s (no depower) and print the buckling FoS for all rings.

using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics
using LinearAlgebra, Printf

function main()
    println("="^72)
    println("Evaluating Steady-State Buckling FoS at 6.0 m/s Wind (No Depower)")
    println("="^72)

    p_base = params_10kw()
    # Let's set steady wind to 6.0 m/s and elevation to 75 deg
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
    println("Settling system to steady operational state...")
    flush(stdout)
    
    u_s = settle_to_operational_state(sys, u0, p_base, ω_rated;
                lift_device = lift_dev, wind_fn = wind_fn)
    println("System settled.")
    
    N = sys.n_total
    Nr = sys.n_ring
    alpha_vec = u_s[6N+1 : 6N+Nr]
    
    re_frames = ring_element_analysis(u_s, collect(alpha_vec), sys, p_base, 0.0, wind_fn)
    
    println("\nRing-by-Ring Structural Buckling Analysis at Steady State:")
    println("-"^72)
    for rf in re_frames
        min_fos = Inf
        for b in rf.beams
            min_fos = min(min_fos, b.fos)
        end
        @printf("Ring %2d | Radius: %5.2f m | Max Utilisation: %8.4f | Min Buckling FoS: %8.3f\n",
                rf.ring_id, rf.radius, rf.max_util, min_fos)
    end
    println("-"^72)
    
    # Let's also check a higher wind speed: 11 m/s steady state (rated wind, no depower)
    println("\nEvaluating Steady-State Buckling FoS at 11.0 m/s Wind (No Depower)")
    println("="^72)
    p_rated = override_params(p_base; v_wind_ref = 11.0)
    sys_r, u0_r = build_kite_turbine_system(p_rated)
    wind_fn_r = let vref = p_rated.v_wind_ref, href = p_rated.h_ref
        (pos, t) -> begin
            z = max(pos[3], 1.0)
            [vref * (z / href)^(1/7), 0.0, 0.0]
        end
    end
    ω_rated_r = cbrt(p_rated.p_rated_w / p_rated.k_mppt)
    u_s_r = settle_to_operational_state(sys_r, u0_r, p_rated, ω_rated_r;
                lift_device = lift_dev, wind_fn = wind_fn_r)
    alpha_vec_r = u_s_r[6N+1 : 6N+Nr]
    re_frames_r = ring_element_analysis(u_s_r, collect(alpha_vec_r), sys_r, p_rated, 0.0, wind_fn_r)
    for rf in re_frames_r
        min_fos = Inf
        for b in rf.beams
            min_fos = min(min_fos, b.fos)
        end
        @printf("Ring %2d | Radius: %5.2f m | Max Utilisation: %8.4f | Min Buckling FoS: %8.3f\n",
                rf.ring_id, rf.radius, rf.max_util, min_fos)
    end
    println("-"^72)
end

main()

# scratch/debug_v5.jl
using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics, Printf, LinearAlgebra

function diagnose_config(current_config)
    println("\n=======================================================")
    println(" DIAGNOSING CONFIG: $current_config")
    println("=======================================================")
    
    if current_config == "v5 Optimized 8-line"
        p = params_v5_10kw()
        sys, u0 = build_kite_turbine_system_v5(p, 2.0, 0.336)
        label = "v5 octagon"
        DT = 1e-5
    elseif current_config == "v5-safe 8-line"
        p = params_v5_safe_10kw()
        sys, u0 = build_kite_turbine_system_v5(p, 1.61, 1.49)
        label = "v5-safe octagon"
        DT = 4e-5
    else
        error("unknown config")
    end

    wind_fn = (pos, t) -> begin
        z  = max(pos[3], 1.0)
        sh = (z / p.h_ref)^(1.0/7.0)
        [11.0 * sh, 0.0, 0.0]
    end
    default_lift = rotary_lifter_default()

    println("Settling to operational state (ω=9.5 rad/s)...")
    u = settle_to_operational_state(sys, u0, p, 9.5; lift_device=default_lift, wind_fn=wind_fn)

    # Inspect settled state
    inspect_summary(u, sys, p, 0.0, wind_fn, "Settled t=0.0")

    # Simulate for a few steps matching the DT and SAVE_EVERY in the dashboard
    LIN_DAMP = 0.05
    n_steps = 1500
    
    println("Simulating $n_steps steps to t = $(n_steps * DT) seconds...")
    run_canonical_sim!(u, sys, p, wind_fn, n_steps, DT;
        lift_device = default_lift,
        lin_damp = LIN_DAMP
    )

    inspect_summary(u, sys, p, n_steps * DT, wind_fn, "Simulated t=$(n_steps * DT)")
end

function inspect_summary(u, sys, p, t, wind_fn, label)
    N = sys.n_total
    Nr = sys.n_ring
    alpha_vec = collect(@view u[6N+1 : 6N+Nr])

    rea_results = ring_element_analysis(u, alpha_vec, sys, p, t, wind_fn)
    
    println("  Summary for $label:")
    for (k, frame) in enumerate(rea_results)
        ring_gid = sys.ring_ids[k + 1]
        node = sys.nodes[ring_gid]
        R = node.radius
        tp = tube_props(R)
        worst_idx = argmax([b.utilisation for b in frame.beams])
        wb = frame.beams[worst_idx]
        
        @printf("    Ring %2d (R=%4.2fm, GID %3d): Worst Beam Util = %5.1f%% [N_term=%4.1f%%, M_term=%5.1f%%, Do=%4.1fmm]\n", 
            k, R, ring_gid, wb.utilisation * 100.0, 
            (max(wb.N, 0.0)/wb.N_crit)*100.0, 
            (sqrt(wb.M_ip^2 + wb.M_oop^2)/wb.M_el)*100.0,
            tp.Do*1000.0)
    end
end

diagnose_config("v5 Optimized 8-line")
diagnose_config("v5-safe 8-line")

# scratch/debug_util_timeline.jl
using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics, Printf, LinearAlgebra

function run_diagnostics()
    # 1. Canonical 5-line configuration
    println("--- DIAGNOSING CANONICAL 5-LINE SYSTEM ---")
    p = params_10kw()
    sys, u0 = build_kite_turbine_system(p)
    wind_fn = (pos, t) -> begin
        z  = max(pos[3], 1.0)
        sh = (z / p.h_ref)^(1.0/7.0)
        [11.0 * sh, 0.0, 0.0]
    end
    default_lift = rotary_lifter_default()

    println("Settling to operational state (ω=9.5 rad/s)...")
    u = settle_to_operational_state(sys, u0, p, 9.5; lift_device=default_lift, wind_fn=wind_fn)

    # Inspect settled state first
    inspect_frame(u, sys, p, 0.0, wind_fn, "Settled t=0.0")

    # Simulate for a few steps matching the DT and SAVE_EVERY in the dashboard
    DT = 4e-5
    LIN_DAMP = 0.05
    n_steps = 1500  # 1500 * 4e-5 = 0.06 seconds (frame 1)
    
    println("\nSimulating $n_steps steps to t = 0.06 seconds...")
    run_canonical_sim!(u, sys, p, wind_fn, n_steps, DT;
        lift_device = default_lift,
        lin_damp = LIN_DAMP
    )

    inspect_frame(u, sys, p, 0.06, wind_fn, "Simulated t=0.06")
end

function inspect_frame(u, sys, p, t, wind_fn, label)
    N = sys.n_total
    Nr = sys.n_ring
    alpha_vec = collect(@view u[6N+1 : 6N+Nr])

    println("\n=======================================================")
    println(" FRAME DIAGNOSTICS: $label")
    println("=======================================================")
    
    # Run ring element analysis
    rea_results = ring_element_analysis(u, alpha_vec, sys, p, t, wind_fn)
    
    for (k, frame) in enumerate(rea_results)
        ring_gid = sys.ring_ids[k + 1]
        node = sys.nodes[ring_gid]
        R = node.radius
        n = p.n_lines
        tp = tube_props(R)
        L_beam = 2.0 * R * sin(π / n)
        
        # Recover critical parameters
        N_crit = 4.0 * π^2 * E_CFRP * tp.I_bend / L_beam^2   # fixed-fixed K=0.5
        M_el   = σ_CFRP_COMPR * tp.I_bend / (tp.Do / 2.0)    # elastic moment capacity

        println("\nRing $k (GID $ring_gid): Radius = $(round(R, digits=3)) m, Lines = $n, Beam Length = $(round(L_beam, digits=3)) m")
        println("  Tube properties: Do = $(round(tp.Do*1000, digits=2)) mm, t = $(round(tp.t*1000, digits=2)) mm")
        println("  Capacities: N_crit = $(round(N_crit, digits=1)) N, M_el = $(round(M_el, digits=3)) N*m")
        
        # Worst beam
        worst_idx = argmax([b.utilisation for b in frame.beams])
        wb = frame.beams[worst_idx]
        
        println("  WORST BEAM ($worst_idx):")
        println("    Utilisation = $(round(wb.utilisation * 100, digits=1))% (N_term = $(round(max(wb.N, 0.0)/N_crit*100, digits=1))%, M_term = $(round(sqrt(wb.M_ip^2 + wb.M_oop^2)/M_el*100, digits=1))%)")
        println("    Forces: N = $(round(wb.N, digits=2)) N, M_ip = $(round(wb.M_ip, digits=3)) N*m, M_oop = $(round(wb.M_oop, digits=3)) N*m, T_tor = $(round(wb.T_tor, digits=3)) N*m")
        
        # Let's inspect local node forces
        # We need to replicate how analyse_ring transforms to local frame to see where the force imbalance is
        β = p.elevation_angle
        shaft_dir = [cos(β), 0.0, sin(β)]
        perp1, perp2 = shaft_perp_basis(shaft_dir)
        F_global = KiteTurbineDynamics.extract_vertex_forces(u, sys, ring_gid, alpha_vec, p, perp1, perp2, t, wind_fn)
        
        # Add self weight
        m_vertex = 0.05 + tp.A * L_beam * 1600.0
        F_grav = [0.0, 0.0, -9.81 * m_vertex]
        for j in 1:n
            F_global[:, j] .+= F_grav
        end
        
        # Net force before inertia relief
        F_net_before = sum(F_global, dims=2)
        
        # Apply inertia relief
        F_global_relieved = copy(F_global)
        for j in 1:n
            F_global_relieved[:, j] .-= F_net_before ./ n
        end
        
        R_to_local = [perp1'; perp2'; shaft_dir']
        F_local = R_to_local * F_global_relieved
        
        println("    Nodal Forces (ring-local perp1, perp2, shaft_dir):")
        for j in 1:n
            @printf("      Node %d: [%6.1f, %6.1f, %6.1f] N\n", j, F_local[1, j], F_local[2, j], F_local[3, j])
        end
        println("    Net Force before inertia relief (global): [$(round(F_net_before[1], digits=1)), $(round(F_net_before[2], digits=1)), $(round(F_net_before[3], digits=1))] N")
    end
end

run_diagnostics()

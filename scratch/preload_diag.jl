# Diagnostic print for the preload iterations
using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "test", "test_settle_preload_consistency.jl"))

function diag_solve(beta_deg)
    p = params_5kw_188()
    sys, u0, pc, lift, wf = build_case(nothing, nothing)
    pc = override_params(pc; elevation_angle=deg2rad(beta_deg))
    lift = sized_lifter_for(sys, pc; margin=1.5, v_ref=11.0, const_tension=true)
    
    n_ring = sys.n_ring
    n_seg = n_ring - 1
    T_cyan = KiteTurbineDynamics.design_preload_from_sky_anchor(pc, lift)
    m_rotor = pc.n_blades * pc.m_blade
    F_aero_z = 0.5 * pc.rho * pc.v_wind_ref^2 * π * pc.rotor_radius^2 * 0.8 * cos(pc.elevation_angle)^2 * sin(pc.elevation_angle) + (m_rotor + sys.kite.mass) * (-9.81)
    F_top_guess = max(F_aero_z / sin(pc.elevation_angle) + T_cyan, 20.0)
    g_inc = pc.m_ring * 9.81 / sin(pc.elevation_angle)
    F_profile(top) = [top + (n_seg - i) * g_inc for i in 1:n_seg]

    # Pre-settle bearing/anchor equilibrium
    u = KiteTurbineDynamics.settle_to_equilibrium(sys, u0, pc; lift_device=lift, wind_fn=wf)
    N = sys.n_total
    hub_gid = sys.rotor.node_id
    m_hub = (sys.nodes[hub_gid]::RingNode).mass
    sd = [cos(pc.elevation_angle), 0.0, sin(pc.elevation_angle)]
    du = zeros(Float64, length(u))

    T_top = F_top_guess
    println("--- Beta = $beta_deg deg | Guess = $F_top_guess N | T_cyan = $T_cyan N ---")
    for iter in 1:35
        F_ax = F_profile(T_top)
        tau_eq = sys.k_mppt_ref[] * max(u[6N + 2n_ring], 0.0)^2
        alpha_m, ctrs = KiteTurbineDynamics._matched_place_twist(sys, pc, F_ax, tau_eq, u[6N + 2n_ring], wf, sd)
        for k in 1:n_ring
            gid = sys.ring_ids[k]
            u[(3gid - 2):3gid] .= ctrs[k]
            u[6N + k] = alpha_m[k]
        end
        pp1, pp2 = KiteTurbineDynamics._tilted_ring_basis(u, sys, hub_gid, n_ring)
        for node in sys.nodes
            node isa RopeNode || continue
            s, j = node.seg_idx, node.line_idx
            ra = isempty(sys.expansion_rotors) ? (sys.nodes[sys.ring_ids[s]]::RingNode).radius : sys.effective_radii[s]
            rb = isempty(sys.expansion_rotors) ? (sys.nodes[sys.ring_ids[s + 1]]::RingNode).radius : sys.effective_radii[s + 1]
            pa = attachment_point(ctrs[s], ra, alpha_m[s], j, pc.n_lines, pp1, pp2)
            pb = attachment_point(ctrs[s + 1], rb, alpha_m[s + 1], j, pc.n_lines, pp1, pp2)
            u[(3node.id - 2):3node.id] .= pa .+ (node.sub_idx / ROPE_SUBSEGS) .* (pb .- pa)
        end
        KiteTurbineDynamics.set_orbital_velocities!(u, sys, pc)

        fill!(du, 0.0)
        KiteTurbineDynamics.multibody_ode!(du, u, (sys, pc, wf, lift), 0.0)
        f_net_ax = m_hub * dot(du[(3N + 3hub_gid - 2):(3N + 3hub_gid)], sd)
        @printf("iter=%2d | T_top=%8.3f N | f_net_ax=%+10.4f N\n", iter, T_top, f_net_ax)
        if abs(f_net_ax) < 1e-2
            println("Converged!")
            return
        end
        T_top += 0.7 * f_net_ax
    end
end
diag_solve(30.0)

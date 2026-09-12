# Print iteration behavior for all sweeps
using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "test", "test_settle_preload_consistency.jl"))

function test_sweep_robustness()
    for beta_deg in (30.0, 45.0, 60.0, 70.0)
        for rc in (nothing, 4)
            println("\n==========================================")
            println("Case: beta=$beta_deg deg, n_lines_gene=$rc")
            sys, u0, pc, lift, wf = build_case(rc, nothing)
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

            _, u0_build = KiteTurbineDynamics.build_kite_turbine_system(pc)
            u = KiteTurbineDynamics.settle_to_equilibrium(sys, u0_build, pc; lift_device=lift, wind_fn=wf)
            N = sys.n_total
            hub_gid = sys.rotor.node_id
            m_hub = (sys.nodes[hub_gid]::RingNode).mass
            sd = [cos(pc.elevation_angle), 0.0, sin(pc.elevation_angle)]
            du = zeros(Float64, length(u))

            # Measure numerical derivative df/dT_top
            eval_f(T) = begin
                F_ax = F_profile(T)
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
                return m_hub * dot(du[(3N + 3hub_gid - 2):(3N + 3hub_gid)], sd)
            end

            f0 = eval_f(F_top_guess)
            f1 = eval_f(F_top_guess + 1.0)
            df_dT = f1 - f0
            @printf("F_top_guess=%8.2f N | f0=%+10.4f N | df/dT=%+10.6f\n", F_top_guess, f0, df_dT)

            # Let's run a secant / 1D solver with bounds
            T_curr = F_top_guess
            f_curr = f0
            for it in 1:20
                @printf("iter=%2d | T_top=%8.3f N | f_net_ax=%+10.4f N\n", it, T_curr, f_curr)
                if abs(f_curr) < 1e-2
                    println("SUCCESS")
                    break
                end
                step = -f_curr / df_dT
                step = clamp(step, -200.0, 200.0)
                T_next = max(T_curr + step, 10.0)
                f_next = eval_f(T_next)
                if abs(T_next - T_curr) > 1e-6
                    df_dT = (f_next - f_curr) / (T_next - T_curr)
                end
                T_curr = T_next
                f_curr = f_next
            end
        end
    end
end
test_sweep_robustness()

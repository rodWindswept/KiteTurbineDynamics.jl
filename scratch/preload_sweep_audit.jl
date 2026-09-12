# Standalone audit for the preload solve across beta and ring counts
using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "test", "test_settle_preload_consistency.jl"))

function solve_axial_profile_kernel(sys, p, lift_device;
                                    u_anchor=nothing, wind_fn=nothing,
                                    max_iter=30, tol_N=1e-2, relax=0.7)
    lift_device === nothing && return Float64[]
    n_ring = sys.n_ring
    n_seg = n_ring - 1
    T_top_guess = KiteTurbineDynamics.design_preload_from_sky_anchor(p, lift_device)
    # Start guess from old formula components
    m_rotor = p.n_blades * p.m_blade
    F_aero_z = 0.5 * p.rho * p.v_wind_ref^2 * π * p.rotor_radius^2 * 0.8 * cos(p.elevation_angle)^2 * sin(p.elevation_angle) + (m_rotor + sys.kite.mass) * (-9.81)
    F_top_guess = max(F_aero_z / sin(p.elevation_angle) + T_top_guess, 20.0)

    g_inc = p.m_ring * 9.81 / sin(p.elevation_angle)
    F_profile(top) = [top + (n_seg - i) * g_inc for i in 1:n_seg]

    # Pre-build baseline state
    wf = wind_fn === nothing ? ((r, t) -> [p.v_wind_ref, 0.0, 0.0]) : wind_fn
    u = u_anchor === nothing ? KiteTurbineDynamics.settle_to_equilibrium(sys, KiteTurbineDynamics.build_kite_turbine_system(p)[2], p; lift_device=lift_device, wind_fn=wf) : copy(u_anchor)
    N = sys.n_total
    hub_gid = sys.rotor.node_id
    m_hub = (sys.nodes[hub_gid]::RingNode).mass
    sd = [cos(p.elevation_angle), 0.0, sin(p.elevation_angle)]
    ode_params = (sys, p, wf, lift_device)
    du = zeros(Float64, length(u))

    T_top = F_top_guess
    for iter in 1:max_iter
        F_ax = F_profile(T_top)
        tau_eq = sys.k_mppt_ref[] * max(u[6N + 2n_ring], 0.0)^2
        alpha_m, ctrs = KiteTurbineDynamics._matched_place_twist(sys, p, F_ax, tau_eq, u[6N + 2n_ring], wf, sd)
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
            pa = attachment_point(ctrs[s], ra, alpha_m[s], j, p.n_lines, pp1, pp2)
            pb = attachment_point(ctrs[s + 1], rb, alpha_m[s + 1], j, p.n_lines, pp1, pp2)
            u[(3node.id - 2):3node.id] .= pa .+ (node.sub_idx / ROPE_SUBSEGS) .* (pb .- pa)
        end
        KiteTurbineDynamics.set_orbital_velocities!(u, sys, p)

        fill!(du, 0.0)
        KiteTurbineDynamics.multibody_ode!(du, u, ode_params, 0.0)
        f_net_ax = m_hub * dot(du[(3N + 3hub_gid - 2):(3N + 3hub_gid)], sd)
        if abs(f_net_ax) < tol_N
            return F_ax, iter, f_net_ax, F_top_guess
        end
        T_top += relax * f_net_ax
        if !isfinite(T_top) || T_top <= 0.0
            error("Preload solver diverged or became non-positive: T_top=$T_top")
        end
    end
    error("Preload solver did not converge in $max_iter iterations")
end

function sweep_audit()
    println("=== Preload Kernel Audit across beta and ring counts ===")
    for beta_deg in (30.0, 45.0, 60.0, 70.0)
        for rc in (nothing, 4)
            p = params_5kw_188()
            p = override_params(p; elevation_angle=deg2rad(beta_deg))
            sys, u0, pc, lift, wf = build_case(rc, nothing)
            # update elevation in pc as well
            pc = override_params(pc; elevation_angle=deg2rad(beta_deg))
            F_ax, iters, residual, guess = solve_axial_profile_kernel(sys, pc, lift; wind_fn=wf)
            @printf("beta=%4.1f deg | rc=%s | iters=%2d | residual=%+.4e N | old_top=%8.2f N | new_top=%8.2f N | diff=%+7.2f N\n",
                    beta_deg, string(rc), iters, residual, guess, F_ax[end], F_ax[end] - guess)
        end
    end
end
sweep_audit()

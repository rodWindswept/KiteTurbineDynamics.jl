using LinearAlgebra

function compute_ring_forces!(forces  ::Vector{<:AbstractVector},
                               torques ::AbstractVector,
                               u       ::AbstractVector,
                               omega   ::AbstractVector,
                               sys     ::KiteTurbineSystem,
                               p       ::SystemParams,
                               wind_fn ::Function,
                               t       ::Float64)
    N        = sys.n_total
    hub_gid  = sys.rotor.node_id
    hub_ri   = (sys.nodes[hub_gid]::RingNode).ring_idx
    hub_pos  = u[3*(hub_gid-1)+1 : 3*hub_gid]
    hub_vel  = u[3*N+3*(hub_gid-1)+1 : 3*N+3*hub_gid]
    β        = p.elevation_angle

    v_wind  = wind_fn(Float64.(hub_pos), t)
    v_app   = v_wind .- hub_vel
    v_mag   = norm(v_app)

    # ── Kite lift + drag ───────────────────────────────────────────────────
    if v_mag > 0.1
        q        = 0.5 * p.rho * v_mag^2
        drag_dir = v_app ./ v_mag
        ẑ        = [0.0, 0.0, 1.0]
        ẑ_perp   = ẑ .- dot(ẑ, drag_dir) .* drag_dir
        n_zp     = norm(ẑ_perp)
        lift_dir = n_zp > 1e-6 ? ẑ_perp ./ n_zp : ẑ
        forces[hub_gid] .+= q * sys.kite.area * sys.kite.CL .* lift_dir
        forces[hub_gid] .+= q * sys.kite.area * sys.kite.CD .* drag_dir
    end

    # ── Rotor thrust + aero torque ─────────────────────────────────────────
    v_hub_mag = norm(v_wind)
    if v_hub_mag > 0.1
        omega_rotor = omega[hub_ri]
        lambda_t    = abs(omega_rotor) * sys.rotor.radius / v_hub_mag
        elev_angle  = atan(real(hub_pos[3]), norm(real.(hub_pos[1:2])))

        thrust_mag  = 0.5 * p.rho * v_hub_mag^2 *
                      π * sys.rotor.radius^2 * 0.8 * cos(elev_angle)^2
        tether_dir  = hub_pos .- u[1:3]   # ground is node 1
        tl          = norm(tether_dir)
        if tl > 0; tether_dir ./= tl; end
        forces[hub_gid] .+= thrust_mag .* tether_dir

        P_aero   = 0.5 * p.rho * v_hub_mag^3 *
                   π * sys.rotor.radius^2 * cp_at_tsr(lambda_t) * cos(elev_angle)^3
        tau_aero = abs(omega_rotor) > 0.1 ?
                   sign(omega_rotor) * P_aero / abs(omega_rotor) : 0.0
        torques[hub_ri] += tau_aero
    end

    # ── Generator MPPT torque on ground node ──────────────────────────────
    gnd_ri    = (sys.nodes[sys.ring_ids[1]]::RingNode).ring_idx   # = 1
    omega_gnd = omega[gnd_ri]
    tau_gen   = p.k_mppt * omega_gnd^2 * sign(omega_gnd + 1e-9)
    torques[gnd_ri] -= tau_gen
end

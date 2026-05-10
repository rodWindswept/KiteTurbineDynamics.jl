using LinearAlgebra

function multibody_ode!(du, u, params, t)
    sys, p, wind_fn = params[1], params[2], params[3]
    lift_device = length(params) >= 4 ? params[4] : nothing
    N  = sys.n_total
    Nr = sys.n_ring
    g  = [0.0, 0.0, -9.81]

    # ── Extract twist states ───────────────────────────────────────────────
    alpha = u[6N+1    : 6N+Nr]
    omega = u[6N+Nr+1 : 6N+2Nr]

    # ── Initialise accumulators ────────────────────────────────────────────
    forces  = [zeros(eltype(u), 3) for _ in 1:N]
    torques = zeros(eltype(u), Nr)
    ring_torques_3d = [zeros(eltype(u), 3) for _ in 1:Nr]

    # ── Compute tilted ring-plane basis ────────────────────────────────────
    # Hub ring's stored tilt axis (from previous ODE step) drives the
    # quasi-static ring-plane tilt for all rings (coherent tilt).
    hub_gid  = sys.rotor.node_id
    hub_pos  = u[3*(hub_gid-1)+1 : 3*hub_gid]
    hub_rmag = norm(hub_pos)

    shaft_dir = hub_rmag > 0.1 ?
                hub_pos ./ hub_rmag :
                [cos(p.elevation_angle), 0.0, sin(p.elevation_angle)]

    hub_ri       = (sys.nodes[hub_gid]::RingNode).ring_idx
    tau_stored   = sys.ring_tilt_axis[hub_ri]
    tau_non_shaft = tau_stored .- dot(tau_stored, shaft_dir) .* shaft_dir
    tilted_normal = normalize(shaft_dir .+ DISC_TILT_COMPLIANCE .* tau_non_shaft .+ [1e-12, 1e-12, 1e-12])
    perp1_tilt, perp2_tilt = shaft_perp_basis(tilted_normal)

    # ── Gravity on all nodes ───────────────────────────────────────────────
    for i in 1:N
        node = sys.nodes[i]
        m    = if node isa RingNode
            node.mass
        elseif node isa RopeNode
            node.mass
        elseif node isa BearingNode
            node.mass
        else
            error("unknown node type")
        end
        forces[i] .+= m .* g
    end

    # ── Rope sub-segment forces (spring/damp/drag + emergent torsion) ──────
    compute_rope_forces!(forces, torques, u, alpha, sys, p, wind_fn, t,
                          ring_torques_3d, perp1_tilt, perp2_tilt)

    # ── Store tilt axis for next ODE step ──────────────────────────────────
    # Exponential smoothing models ring rotational inertia: the tilt axis
    # cannot change instantly; it responds with time constant τ ≈ dt/(1-α).
    # This prevents the numerical feedback loop that otherwise blows up.
    α_smooth = TILT_SMOOTH
    β_smooth = 1.0 - α_smooth
    for ri in 1:Nr
        tau_ri             = ring_torques_3d[ri]
        tau_ri_non_shaft   = tau_ri .- dot(tau_ri, shaft_dir) .* shaft_dir
        sys.ring_tilt_axis[ri] = α_smooth .* sys.ring_tilt_axis[ri] .+ β_smooth .* tau_ri_non_shaft
    end

    # ── Rotor/kite aero + generator torque ────────────────────────────────
    compute_ring_forces!(forces, torques, u, omega, sys, p, wind_fn, t, lift_device)

    # ── Assemble du ────────────────────────────────────────────────────────
    for i in 1:N
        node   = sys.nodes[i]
        bp     = 3*(i-1)+1
        bv     = 3N+3*(i-1)+1

        if node isa RingNode && node.is_fixed
            du[bp:bp+2]   .= 0.0
            du[bv:bv+2]   .= 0.0
        else
            du[bp:bp+2] .= u[bv:bv+2]        # d(pos)/dt = vel
            m = if node isa RingNode
                node.mass
            elseif node isa RopeNode
                node.mass
            elseif node isa BearingNode
                node.mass
            else
                error("unknown node type")
            end
            du[bv:bv+2] .= forces[i] ./ m    # d(vel)/dt = F/m
        end
    end

    # ── Twist states — only for RingNodes ─────────────────────────────────
    for node in sys.nodes
        node isa RingNode || continue
        ri    = node.ring_idx
        I_z   = node.inertia_z
        du[6N + ri]      = omega[ri]
        du[6N + Nr + ri] = torques[ri] / I_z   # always live; pos_fixed handled by translation block above
    end

    return nothing
end

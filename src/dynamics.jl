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

    # ── Shaft direction ────────────────────────────────────────────────────
    hub_gid  = sys.rotor.node_id
    hub_pos  = u[3*(hub_gid-1)+1 : 3*hub_gid]
    hub_rmag = norm(hub_pos)
    shaft_dir = hub_rmag > 0.1 ?
                hub_pos ./ hub_rmag :
                [cos(p.elevation_angle), 0.0, sin(p.elevation_angle)]

    # ── Disc tilt from bearing offset (one-way, stable) ──────────────────
    # When the bearing drifts from its design position (e.g. during furl),
    # the ring plane tilts.  We compute the tilt angle from the bearing
    # offset perpendicular to the shaft axis, then derive a tilted ring-plane
    # basis for TRPT sub-segments.  Bridle geometry stays in the shaft frame
    # to prevent feedback instability.
    bearing_gid  = sys.bearing_id
    bearing_pos  = u[3*(bearing_gid-1)+1 : 3*bearing_gid]
    bearing_design = hub_pos .+ 6.0 .* shaft_dir  # 6m offset along shaft
    bearing_error  = bearing_pos .- bearing_design
    tilt_perp = bearing_error .- dot(bearing_error, shaft_dir) .* shaft_dir
    tilt_mag  = norm(tilt_perp)
    # Scale: 10 m bearing offset → 1 rad tilt (tuneable)
    # Clamp at ±30° to prevent geometry inversion
    TILT_SCALE  = 0.1          # rad per metre of bearing offset
    tilt_angle  = min(tilt_mag * TILT_SCALE, π/6)
    tilt_dir_v  = tilt_mag > 1e-9 ? tilt_perp ./ tilt_mag : [0.0, 0.0, 0.0]

    # Tilted ring-plane normal (for TRPT geometry only)
    tilted_normal = normalize(cos(tilt_angle) .* shaft_dir .+ sin(tilt_angle) .* tilt_dir_v .+ [1e-12, 1e-12, 1e-12])
    perp1_tilt, perp2_tilt = shaft_perp_basis(tilted_normal)

    # Store tilted normal for dashboard visualization
    hub_ri = (sys.nodes[hub_gid]::RingNode).ring_idx
    sys.ring_tilt_axis[hub_ri] = tilted_normal

    # ── Gravity on all nodes ───────────────────────────────────────────────
    for i in 1:N
        node = sys.nodes[i]
        m    = if node isa RingNode
            node.mass
        elseif node isa RopeNode
            node.mass
        elseif node isa BearingNode
            node.mass
        elseif node isa SkyAnchorNode
            node.mass
        else
            error("unknown node type")
        end
        forces[i] .+= m .* g
    end

    # ── Rope sub-segment forces ────────────────────────────────────────────
    # Pass tilted basis for TRPT sub-segments; bridles use shaft_dir internally
    compute_rope_forces!(forces, torques, u, alpha, sys, p, wind_fn, t,
                          perp1_tilt, perp2_tilt)

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
            elseif node isa SkyAnchorNode
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
        du[6N + Nr + ri] = torques[ri] / I_z
    end

    return nothing
end

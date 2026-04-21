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

    # ── Gravity on all nodes ───────────────────────────────────────────────
    for i in 1:N
        node = sys.nodes[i]
        m    = node isa RingNode ? node.mass : (node::RopeNode).mass
        forces[i] .+= m .* g
    end

    # ── Rope sub-segment forces (spring/damp/drag + emergent torsion) ──────
    compute_rope_forces!(forces, torques, u, alpha, sys, p, wind_fn, t)

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
            m = node isa RingNode ? node.mass : (node::RopeNode).mass
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

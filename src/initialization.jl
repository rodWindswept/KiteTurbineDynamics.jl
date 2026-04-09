using LinearAlgebra

"""
    build_kite_turbine_system(p; kite_area, kite_mass, kite_tether_length)
        → (sys::KiteTurbineSystem, u0::Vector{Float64})

Constructs the KiteTurbineSystem and a starting state vector u0 with nodes
placed along the shaft axis (rope nodes linearly interpolated between rings).
u0 is suitable as initial conditions for the pre-solve settling step.
"""
function build_kite_turbine_system(p::SystemParams;
                                   kite_area::Float64          = 10.0,
                                   kite_mass::Float64          = 5.0,
                                   kite_tether_length::Float64 = 20.0)

    n_seg    = p.n_rings + 1        # 15
    n_ring   = p.n_rings + 2        # 16  (ground + rings + hub)
    n_rope   = p.n_lines * 3 * n_seg  # 225
    n_total  = n_ring + n_rope        # 241

    β         = p.elevation_angle
    shaft_dir = [cos(β), 0.0, sin(β)]
    perp1, perp2 = shaft_perp_basis(shaft_dir)

    # ── Ring radii (linear taper ground→hub) ──────────────────────────────
    r_top = p.trpt_hub_radius
    r_bot = 2.0 * p.tether_length * p.trpt_rL_ratio / n_seg - r_top
    seg_len_0 = p.tether_length / n_seg

    ring_radii = Vector{Float64}(undef, n_ring)
    ring_radii[1] = r_bot   # ground anchor (radius unused but defined)
    for k in 1:p.n_rings
        frac           = (k - 0.5) / n_seg
        ring_radii[k+1] = r_bot + frac * (r_top - r_bot)
    end
    ring_radii[n_ring] = r_top  # hub

    # ── Ring node positions along shaft ───────────────────────────────────
    EA_total  = p.e_modulus * π * (p.tether_diameter / 2)^2 * p.n_lines
    k_axial   = EA_total / seg_len_0

    m_rotor   = p.n_blades * p.m_blade
    g_z       = -9.81
    v         = p.v_wind_ref
    q         = 0.5 * p.rho * v^2
    # Initial vertical force balance on hub — determines TRPT axial pre-tension.
    # kite_lift_z removed: the rotor disc generates no net kite-style upward lift
    # (flat blades in rotation plane, symmetric disc — see ring_forces.jl note).
    # Upward support comes only from CT thrust's vertical component (thrust·sinβ)
    # and, in operation, from the separate lift device.
    thrust_ax   = q * π * p.rotor_radius^2 * 0.8 * cos(β)^2
    F_aero_z    = thrust_ax * sin(β) + (m_rotor + kite_mass) * g_z
    F_top_ax    = max(-F_aero_z / sin(β), 20.0)

    g_axial_inc = p.m_ring * 9.81 / sin(β)
    F_axial     = zeros(n_seg)
    F_axial[n_seg] = F_top_ax
    for i in (n_seg-1):-1:1
        F_axial[i] = F_axial[i+1] + g_axial_inc
    end

    ring_pos = Vector{Vector{Float64}}(undef, n_ring)
    ring_pos[1] = [0.0, 0.0, 0.0]
    for i in 1:n_seg
        stretch     = max(0.0, F_axial[i] / k_axial)
        ring_pos[i+1] = ring_pos[i] .+ (seg_len_0 + stretch) .* shaft_dir
    end

    # ── Build node list ────────────────────────────────────────────────────
    nodes = Vector{AbstractNode}(undef, n_total)
    ring_ids = Vector{Int}(undef, n_ring)

    EA_single = p.e_modulus * π * (p.tether_diameter / 2)^2
    sub_len_0 = seg_len_0 / 4.0
    m_rope_sub = DYNEEMA_DENSITY * π * (p.tether_diameter/2)^2 * sub_len_0

    # ground (ring index k=0, ring_idx=1)
    # Mass 1e30 keeps position fixed (F/m ≈ 0); i_pto gives real generator rotational inertia.
    nodes[1] = RingNode(1, 1, 1e30, ring_radii[1], p.i_pto, true)
    ring_ids[1] = 1

    for s in 1:n_seg                      # segment s connects ring (s-1) to ring s
        # rope nodes for this segment
        for j in 1:p.n_lines
            for m in 1:3
                gid = (s-1)*16 + 2 + (j-1)*3 + (m-1)
                nodes[gid] = RopeNode(gid, m_rope_sub, j, s, m)
            end
        end
        # ring at top of segment
        gid_ring   = 1 + s * 16
        inertia_z  = (s < n_seg) ? p.m_ring * ring_radii[s+1]^2 :
                                   m_rotor * p.rotor_radius^2
        mass_node  = (s < n_seg) ? p.m_ring : m_rotor
        nodes[gid_ring] = RingNode(gid_ring, s+1, mass_node, ring_radii[s+1],
                                   inertia_z, false)
        ring_ids[s+1] = gid_ring
    end

    # ── Build sub-segment list (300 total) ────────────────────────────────
    zeta   = 1.5
    c_damp = 2.0 * zeta * sqrt(EA_single / sub_len_0 * m_rope_sub)
    sub_segs = Vector{RopeSubSegment}()
    sizehint!(sub_segs, 4 * p.n_lines * n_seg)

    for s in 1:n_seg
        ring_a_gid = ring_ids[s]      # lower ring global id
        ring_b_gid = ring_ids[s+1]    # upper ring global id
        for j in 1:p.n_lines
            ends = Vector{SubSegmentEnd}(undef, 5)
            ends[1] = SubSegmentEnd(ring_a_gid, true,  j)
            for m in 1:3
                gid      = (s-1)*16 + 2 + (j-1)*3 + (m-1)
                ends[m+1] = SubSegmentEnd(gid, false, j)
            end
            ends[5] = SubSegmentEnd(ring_b_gid, true, j)

            for sub in 1:4
                push!(sub_segs, RopeSubSegment(
                    ends[sub], ends[sub+1],
                    sub_len_0, EA_single, c_damp, p.tether_diameter))
            end
        end
    end

    rotor = RotorSpec(ring_ids[end], p.rotor_radius, m_rotor,
                      m_rotor * p.rotor_radius^2)
    kite  = KiteSpec(ring_ids[end], kite_area, kite_mass, 1.2, 0.1,
                     kite_tether_length)

    sys = KiteTurbineSystem(nodes, sub_segs, ring_ids, rotor, kite, n_ring, n_total)

    # ── Initial state vector (straight-line rope placement) ───────────────
    u0 = zeros(Float64, state_size(sys))
    for k in 1:n_ring
        gid = ring_ids[k]
        u0[3*(gid-1)+1 : 3*gid] .= ring_pos[k]
    end

    for s in 1:n_seg
        ring_a_pos = ring_pos[s]
        ring_b_pos = ring_pos[s+1]
        alpha_a = 0.0; alpha_b = 0.0   # zero twist at initialisation
        for j in 1:p.n_lines
            pa = attachment_point(ring_a_pos, ring_radii[s],   alpha_a, j, p.n_lines, perp1, perp2)
            pb = attachment_point(ring_b_pos, ring_radii[s+1], alpha_b, j, p.n_lines, perp1, perp2)
            for m in 1:3
                frac = m / 4.0
                gid  = (s-1)*16 + 2 + (j-1)*3 + (m-1)
                u0[3*(gid-1)+1 : 3*gid] .= rope_helix_pos(pa, pb, frac)
            end
        end
    end

    return sys, u0
end

"""
    settle_to_equilibrium(sys, u0, p; n_steps, dt) → Vector{Float64}

Explicit damped integrator that lets rope nodes sag under gravity without the
stiffness penalty of a general-purpose ODE solver.

Algorithm: semi-implicit Euler + per-step velocity kill at rate `damp`.
Stability condition for the highest natural frequency ω_max:
    (1 + ω_max·dt) · damp < 1
With ω_max ≈ 20 000 rad/s (100 GPa Dyneema, 3 mm, 0.5 m sub-segs),
dt = 4e-5 s → ω_max·dt = 0.8, so we need damp < 1/1.8 ≈ 0.56. Using 0.05.
After 4 000 steps (0.16 s simulated) the gravity-driven sag (~0.1 mm) is
fully resolved; high-frequency oscillations are damped out in ~5 steps.
"""
function settle_to_equilibrium(sys         ::KiteTurbineSystem,
                                u0          ::Vector{Float64},
                                p           ::SystemParams;
                                lift_device ::Union{Nothing, LiftDevice} = nothing,
                                n_steps     ::Int     = 4_000,
                                dt          ::Float64 = 4e-5,
                                damp        ::Float64 = 0.05)
    u    = copy(u0)
    N    = sys.n_total
    Nr   = sys.n_ring
    du   = zeros(Float64, length(u))
    wind_zero  = (pos, t) -> zeros(3)
    ode_params = lift_device === nothing ? (sys, p, wind_zero) :
                                           (sys, p, wind_zero, lift_device)

    for _ in 1:n_steps
        fill!(du, 0.0)
        multibody_ode!(du, u, ode_params, 0.0)

        # Semi-implicit Euler: velocities first, then positions
        @views u[3N+1:6N]        .+= dt .* du[3N+1:6N]
        @views u[1:3N]            .+= dt .* u[3N+1:6N]
        @views u[6N+Nr+1:6N+2Nr] .+= dt .* du[6N+Nr+1:6N+2Nr]
        @views u[6N+1:6N+Nr]     .+= dt .* u[6N+Nr+1:6N+2Nr]

        # Kill high-frequency oscillations
        @views u[3N+1:6N]        .*= damp
        @views u[6N+Nr+1:6N+2Nr] .*= damp

        # Enforce fixed ground node
        u[1:3]       .= 0.0
        u[3N+1:3N+3] .= 0.0
        u[6N+1]       = 0.0
        u[6N+Nr+1]    = 0.0
    end
    # Final velocity zero: rope nodes retain an O(dt·F/m/(1-damp)) equilibrium
    # velocity that can cause c_damp·vel_proj torque residuals at the next call.
    # Zero it here so callers can build exact torsional equilibria.
    @views u[3N+1:6N] .= 0.0
    return u
end

"""
    set_orbital_velocities!(u, sys, p)

Initialise every rope-node translational velocity to its expected orbital velocity —
the velocity it would have if it perfectly tracked the rotation of its two bounding rings.

For ring k spinning at ω_k with attachment-point angle φ = α_k + (j-1)·2π/n_lines:
  v_att_k = ω_k · R_k · (−sin(φ)·pp1 + cos(φ)·pp2)

The rope node at sub_idx/4 of the way between rings a and b interpolates linearly:
  v_orbital = (1 − frac)·v_att_a + frac·v_att_b

Call this once AFTER the equilibrium init so that the simulation starts with
rope nodes already moving at the correct tangential speed (no impulsive loading
on the first step).
"""
function set_orbital_velocities!(u::Vector{Float64},
                                  sys::KiteTurbineSystem,
                                  p  ::SystemParams)
    N  = sys.n_total
    Nr = sys.n_ring
    hub_gid  = sys.rotor.node_id
    hub_posv = u[3*(hub_gid-1)+1 : 3*hub_gid]
    hub_rmv  = norm(hub_posv)
    sd = hub_rmv > 0.1 ?
         hub_posv ./ hub_rmv :
         [cos(p.elevation_angle), 0.0, sin(p.elevation_angle)]
    pp1, pp2 = shaft_perp_basis(sd)

    alpha = @view u[6N+1    : 6N+Nr]
    omega = @view u[6N+Nr+1 : 6N+2Nr]

    for node in sys.nodes
        node isa RopeNode || continue
        gid  = node.id
        s    = node.seg_idx
        j    = node.line_idx
        frac = node.sub_idx / 4.0

        na   = sys.nodes[sys.ring_ids[s]]::RingNode
        nb   = sys.nodes[sys.ring_ids[s+1]]::RingNode
        ri_a = na.ring_idx;  ri_b = nb.ring_idx
        φ_a  = alpha[ri_a] + (j - 1) * (2π / p.n_lines)
        φ_b  = alpha[ri_b] + (j - 1) * (2π / p.n_lines)
        v_a  = omega[ri_a] * na.radius * (-sin(φ_a) .* pp1 .+ cos(φ_a) .* pp2)
        v_b  = omega[ri_b] * nb.radius * (-sin(φ_b) .* pp1 .+ cos(φ_b) .* pp2)

        bv = 3N + 3*(gid - 1) + 1
        u[bv : bv+2] .= (1.0 - frac) .* v_a .+ frac .* v_b
    end
end

"""
    orbital_damp_rope_velocities!(u, sys, p, lin_damp)

Apply oscillation-damping to rope nodes while preserving their orbital velocity.

For each rope node the velocity is split into:
  v = v_orbital  +  v_oscillatory

Only the oscillatory component is multiplied by `lin_damp`; the orbital part is
left unchanged.  Ring-node translational velocities are killed uniformly with
`lin_damp` (ring centres should not drift).

This replaces the flat `u[3N+1:6N] .*= lin_damp` in the simulation loop, which
suppressed orbital rotation (requiring O(1e5) m/s² of force to sustain it) and
caused the hub to decelerate and reverse despite positive aero torque.
"""
function orbital_damp_rope_velocities!(u       ::Vector{Float64},
                                        sys     ::KiteTurbineSystem,
                                        p       ::SystemParams,
                                        lin_damp::Float64)
    N  = sys.n_total
    Nr = sys.n_ring
    hub_gid  = sys.rotor.node_id
    hub_posw = u[3*(hub_gid-1)+1 : 3*hub_gid]
    hub_rmw  = norm(hub_posw)
    shaft_dw = hub_rmw > 0.1 ?
               hub_posw ./ hub_rmw :
               [cos(p.elevation_angle), 0.0, sin(p.elevation_angle)]
    pp1, pp2 = shaft_perp_basis(shaft_dw)

    alpha = @view u[6N+1    : 6N+Nr]
    omega = @view u[6N+Nr+1 : 6N+2Nr]

    # ── Ring nodes: kill translational velocity (centres must not drift) ───
    # The hub ring is intentionally EXCLUDED here: with free-β dynamics, the
    # hub must be free to translate under physical forces (gravity, rope tension,
    # aero, back line, lift device).  Applying lin_damp to the hub velocity
    # would artificially suppress collapse and tether droop.  Intermediate
    # ring nodes are still killed to prevent their centres from drifting
    # off the shaft axis (they are constrained by rope geometry).
    for node in sys.nodes
        node isa RingNode || continue
        node.id == hub_gid && continue    # hub: free to translate physically
        bv = 3*sys.n_total + 3*(node.id - 1) + 1
        @views u[bv : bv+2] .*= lin_damp
    end

    # ── Rope nodes: damp only oscillatory component ─────────────────────────
    for node in sys.nodes
        node isa RopeNode || continue
        gid  = node.id
        s    = node.seg_idx
        j    = node.line_idx
        frac = node.sub_idx / 4.0

        na   = sys.nodes[sys.ring_ids[s]]::RingNode
        nb   = sys.nodes[sys.ring_ids[s+1]]::RingNode
        ri_a = na.ring_idx;  ri_b = nb.ring_idx
        φ_a  = alpha[ri_a] + (j - 1) * (2π / p.n_lines)
        φ_b  = alpha[ri_b] + (j - 1) * (2π / p.n_lines)
        v_a  = omega[ri_a] * na.radius * (-sin(φ_a) .* pp1 .+ cos(φ_a) .* pp2)
        v_b  = omega[ri_b] * nb.radius * (-sin(φ_b) .* pp1 .+ cos(φ_b) .* pp2)
        v_orbital = (1.0 - frac) .* v_a .+ frac .* v_b

        bv = 3N + 3*(gid - 1) + 1
        v_osc = @view(u[bv : bv+2]) .- v_orbital
        u[bv : bv+2] .= v_orbital .+ lin_damp .* v_osc
    end
end

"""
    simulate(sys, u0, p, wind_fn; n_steps, dt, lin_damp, ang_damp) → Vector{Float64}

Explicit semi-implicit Euler integrator with wind loading.
Same stability guarantee as `settle_to_equilibrium` but drives the full
aero + generator dynamics so angular velocity can evolve naturally.

`ang_damp = 1.0` (default) means no angular velocity kill per step —
the hub is free to spin up or down under the net torque balance.
`lin_damp = 0.05` keeps rope oscillations damped without stopping the physics.
"""
function simulate(sys         ::KiteTurbineSystem,
                  u0          ::Vector{Float64},
                  p           ::SystemParams,
                  wind_fn     ::Function;
                  lift_device ::Union{Nothing, LiftDevice} = nothing,
                  n_steps     ::Int     = 50_000,
                  dt          ::Float64 = 4e-5,
                  lin_damp    ::Float64 = 0.05,
                  ang_damp    ::Float64 = 1.0)
    u  = copy(u0)
    N  = sys.n_total
    Nr = sys.n_ring
    du = zeros(Float64, length(u))
    t  = 0.0
    ode_params = lift_device === nothing ? (sys, p, wind_fn) :
                                           (sys, p, wind_fn, lift_device)

    for _ in 1:n_steps
        fill!(du, 0.0)
        multibody_ode!(du, u, ode_params, t)
        t += dt

        @views u[3N+1:6N]        .+= dt .* du[3N+1:6N]
        @views u[1:3N]            .+= dt .* u[3N+1:6N]
        @views u[6N+Nr+1:6N+2Nr] .+= dt .* du[6N+Nr+1:6N+2Nr]
        @views u[6N+1:6N+Nr]     .+= dt .* u[6N+Nr+1:6N+2Nr]

        orbital_damp_rope_velocities!(u, sys, p, lin_damp)
        @views u[6N+Nr+1:6N+2Nr] .*= ang_damp

        u[1:3]       .= 0.0   # ground ring centre stays at origin
        u[3N+1:3N+3] .= 0.0   # ground ring translational velocity = 0
        # alpha[1] and omega[1] evolve freely — ground ring IS the generator input shaft
    end
    return u
end


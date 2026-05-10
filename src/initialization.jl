using LinearAlgebra

"""
    _build_kite_turbine_system_impl(p, ring_radii, seg_lengths; kite_*)

Shared builder core — used by both build_kite_turbine_system (canonical
linear taper) and build_kite_turbine_system_v5 (ring_spacing_v4 geometry).

Receives pre-computed ring_radii and seg_lengths arrays (axial segment
lengths) from the caller.  Handles ALL shared work:
- Axial pre-tension (force balance at hub)
- Node list construction (RingNodes, RopeNodes)
- Sub-segment list (with per-segment 3D chord correction and damping)
- Initial state vector (straight-line rope placement)
- RotorSpec and KiteSpec construction
"""
function _build_kite_turbine_system_impl(p::SystemParams,
                                          ring_radii::Vector{Float64},
                                          seg_lengths::Vector{Float64};
                                          kite_area::Float64          = 10.0,
                                          kite_mass::Float64          = 5.0,
                                          kite_tether_length::Float64 = 20.0)

    n_seg   = length(seg_lengths)
    n_ring  = n_seg + 1
    n_rope  = p.n_lines * 3 * n_seg
    n_total = n_ring + n_rope + 1       # +1 for bearing
    stride  = 1 + p.n_lines * 3

    β         = p.elevation_angle
    shaft_dir = [cos(β), 0.0, sin(β)]
    perp1, perp2 = shaft_perp_basis(shaft_dir)

    # ── Axial pre-tension (force balance at hub) ──────────────────────────
    EA_total  = p.e_modulus * π * (p.tether_diameter / 2)^2 * p.n_lines
    k_axial   = EA_total / (p.tether_length / n_seg)

    m_rotor   = p.n_blades * p.m_blade
    g_z       = -9.81
    v         = p.v_wind_ref
    q         = 0.5 * p.rho * v^2
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
        ring_pos[i+1] = ring_pos[i] .+ (seg_lengths[i] + stretch) .* shaft_dir
    end

    # ── Build node list ──────────────────────────────────────────────────
    nodes = Vector{AbstractNode}(undef, n_total)
    ring_ids = Vector{Int}(undef, n_ring)

    EA_single = p.e_modulus * π * (p.tether_diameter / 2)^2

    # ground (ring index k=0, ring_idx=1)
    nodes[1] = RingNode(1, 1, 1e30, ring_radii[1], p.i_pto, true)
    ring_ids[1] = 1

    for s in 1:n_seg
        r_a = ring_radii[s]
        r_b = ring_radii[s+1]
        # 3D chord includes radial taper spread: chord² = L_axial² + Δr²
        chord_3d = sqrt(seg_lengths[s]^2 + (r_b - r_a)^2)
        sub_len_0_s = chord_3d / 4.0
        m_rope_sub_s = DYNEEMA_DENSITY * π * (p.tether_diameter/2)^2 * sub_len_0_s

        for j in 1:p.n_lines
            for m in 1:3
                gid = (s-1)*stride + 2 + (j-1)*3 + (m-1)
                nodes[gid] = RopeNode(gid, m_rope_sub_s, j, s, m)
            end
        end
        gid_ring   = 1 + s * stride
        inertia_z  = (s < n_seg) ? p.m_ring * ring_radii[s+1]^2 :
                                   m_rotor * p.rotor_radius^2
        mass_node  = (s < n_seg) ? p.m_ring : m_rotor
        nodes[gid_ring] = RingNode(gid_ring, s+1, mass_node, ring_radii[s+1],
                                   inertia_z, false)
        ring_ids[s+1] = gid_ring
    end

    # ── Build sub-segment list ────────────────────────────────────────────
    zeta   = 1.5
    sub_segs = Vector{RopeSubSegment}()
    sizehint!(sub_segs, 4 * p.n_lines * n_seg)

    for s in 1:n_seg
        ring_a_gid = ring_ids[s]
        ring_b_gid = ring_ids[s+1]
        r_a_seg = ring_radii[s]
        r_b_seg = ring_radii[s+1]
        chord_3d_s = sqrt(seg_lengths[s]^2 + (r_b_seg - r_a_seg)^2)
        sub_len_0_s = chord_3d_s / 4.0
        m_rope_sub_s = DYNEEMA_DENSITY * π * (p.tether_diameter/2)^2 * sub_len_0_s
        c_damp_s = 2.0 * zeta * sqrt(EA_single / sub_len_0_s * m_rope_sub_s)

        for j in 1:p.n_lines
            ends = Vector{SubSegmentEnd}(undef, 5)
            ends[1] = SubSegmentEnd(ring_a_gid, true,  j)
            for m in 1:3
                gid      = (s-1)*stride + 2 + (j-1)*3 + (m-1)
                ends[m+1] = SubSegmentEnd(gid, false, j)
            end
            ends[5] = SubSegmentEnd(ring_b_gid, true, j)

            for sub in 1:4
                push!(sub_segs, RopeSubSegment(
                    ends[sub], ends[sub+1],
                    sub_len_0_s, EA_single, c_damp_s, p.tether_diameter))
            end
        end
    end

    rotor = RotorSpec(ring_ids[end], p.rotor_radius, m_rotor,
                      m_rotor * p.rotor_radius^2)
    kite  = KiteSpec(ring_ids[end], kite_area, kite_mass, 1.2, 0.1,
                     kite_tether_length)

    # ── Bearing node + bridle segments ──────────────────────────────────
    # The bearing is a free particle placed above the hub ring centre along
    # the shaft axis.  N bridle spring-dampers connect it to the hub ring
    # vertices, distributing lift/backline forces through the tension network
    # rather than applying them as a single vector at the hub centre.
    BEARING_MASS   = 0.3           # kg — small bearing + skateboard wheel
    BRIDLE_EA      = 500_000.0     # N  — stiff bridle lines (Dyneema 2mm)
    BRIDLE_C_DAMP  = 100.0         # N·s/m
    BRIDLE_DIAM    = 0.002         # m  — 2mm Dyneema bridle line
    bearing_offset = 6.0           # m above hub centre (along shaft)

    bearing_gid = n_total
    nodes[bearing_gid] = BearingNode(bearing_gid, BEARING_MASS)
    bearing_pos0 = ring_pos[end] .+ bearing_offset .* shaft_dir

    for j in 1:p.n_lines
        pa_attach = attachment_point(ring_pos[end], ring_radii[end], 0.0,
                                     j, p.n_lines, perp1, perp2)
        bridle_L0 = norm(bearing_pos0 .- pa_attach)
        push!(sub_segs, RopeSubSegment(
            SubSegmentEnd(bearing_gid, false, j),   # bearing end
            SubSegmentEnd(ring_ids[end], true, j),   # hub-vertex end
            bridle_L0, BRIDLE_EA, BRIDLE_C_DAMP, BRIDLE_DIAM))
    end

    sys = KiteTurbineSystem(nodes, sub_segs, ring_ids, rotor, kite,
                            bearing_gid, n_ring, n_total,
                            [zeros(3) for _ in 1:n_ring])

    # ── Initial state vector (straight-line rope placement) ───────────────
    u0 = zeros(Float64, state_size(sys))
    for k in 1:n_ring
        gid = ring_ids[k]
        u0[3*(gid-1)+1 : 3*gid] .= ring_pos[k]
    end

    for s in 1:n_seg
        ring_a_pos = ring_pos[s]
        ring_b_pos = ring_pos[s+1]
        alpha_a = 0.0; alpha_b = 0.0
        for j in 1:p.n_lines
            pa = attachment_point(ring_a_pos, ring_radii[s],   alpha_a, j, p.n_lines, perp1, perp2)
            pb = attachment_point(ring_b_pos, ring_radii[s+1], alpha_b, j, p.n_lines, perp1, perp2)
            for m in 1:3
                frac = m / 4.0
                gid  = (s-1)*stride + 2 + (j-1)*3 + (m-1)
                u0[3*(gid-1)+1 : 3*gid] .= rope_helix_pos(pa, pb, frac)
            end
        end
    end

    # Bearing initial position
    u0[3*(bearing_gid-1)+1 : 3*bearing_gid] .= bearing_pos0

    return sys, u0
end

"""
    build_kite_turbine_system(p; kite_area, kite_mass, kite_tether_length)
        → (sys::KiteTurbineSystem, u0::Vector{Float64})

Constructs the KiteTurbineSystem and a starting state vector u0 with nodes
placed along the shaft axis (rope nodes linearly interpolated between rings).
u0 is suitable as initial conditions for the pre-solve settling step.

Ring geometry: linear taper from ground to hub, uniform axial spacing.
Uses the shared _build_kite_turbine_system_impl for all construction.
"""
function build_kite_turbine_system(p::SystemParams;
                                   kite_area::Float64          = 10.0,
                                   kite_mass::Float64          = 5.0,
                                   kite_tether_length::Float64 = 20.0)

    n_seg = p.n_rings + 1
    r_top = p.trpt_hub_radius
    r_bot = 2.0 * p.tether_length * p.trpt_rL_ratio / n_seg - r_top

    ring_radii = Vector{Float64}(undef, n_seg + 1)
    ring_radii[1] = r_bot
    for k in 1:p.n_rings
        frac = (k - 0.5) / n_seg
        ring_radii[k+1] = r_bot + frac * (r_top - r_bot)
    end
    ring_radii[n_seg + 1] = r_top

    seg_len_0 = p.tether_length / n_seg
    seg_lengths = fill(seg_len_0, n_seg)

    return _build_kite_turbine_system_impl(p, ring_radii, seg_lengths;
        kite_area=kite_area, kite_mass=kite_mass,
        kite_tether_length=kite_tether_length)
end

"""
    build_kite_turbine_system_v5(p, target_Lr, r_bottom; ...) → (sys, u0)

Constructs the KiteTurbineSystem using v5 constant-L/r non-uniform ring spacing
from ring_spacing_v4().  Supports arbitrary n_lines (specifically 8 for the
optimized octagon geometry).

Differences from build_kite_turbine_system():
  - Ring positions/radii computed by ring_spacing_v4 (non-uniform axial spacing)
  - n_rings is an output of ring_spacing_v4, not a SystemParams field
  - Segment natural lengths are non-uniform (derived from z_positions)
  - Uses stride = 1 + p.n_lines * 3 (generalises to any n_lines)
"""
function build_kite_turbine_system_v5(p::SystemParams,
                                       target_Lr::Float64,
                                       r_bottom::Float64;
                                       kite_area::Float64          = 10.0,
                                       kite_mass::Float64          = 5.0,
                                       kite_tether_length::Float64 = 20.0)

    z_positions, ring_radii_computed, n_rings_computed = ring_spacing_v4(
        p.trpt_hub_radius, r_bottom, p.tether_length, target_Lr)

    seg_lengths = diff(z_positions)
    for i in eachindex(seg_lengths)
        seg_lengths[i] = max(seg_lengths[i], 1e-6)
    end

    return _build_kite_turbine_system_impl(p, ring_radii_computed, seg_lengths;
        kite_area=kite_area, kite_mass=kite_mass,
        kite_tether_length=kite_tether_length)
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
    # Auto-adjust dt for high-line-count systems: shorter ground-end segments
    # (e.g., 0.17 m in v5 vs 0.50 m canonical) have higher natural frequencies
    # that exceed the semi-implicit Euler stability limit at dt=4e-5.
    # Scaling: ω_max ∝ 1/√L₀, so for L₀=0.17 m we need dt ≈ 4e-5×√(0.17/0.50) ≈ 2.3e-5
    # Conservative bound: n_lines ≥ 8 → dt = 1e-5
    local dt_use = p.n_lines >= 8 ? 1e-5 : dt
    local n_use  = p.n_lines >= 8 ? n_steps * 4 : n_steps  # 4× steps to match sim time
    u    = copy(u0)
    N    = sys.n_total
    Nr   = sys.n_ring
    du   = zeros(Float64, length(u))
    wind_zero  = (pos, t) -> zeros(3)
    ode_params = lift_device === nothing ? (sys, p, wind_zero) :
                                           (sys, p, wind_zero, lift_device)

    for _ in 1:n_use
        fill!(du, 0.0)
        multibody_ode!(du, u, ode_params, 0.0)

        # Semi-implicit Euler: velocities first, then positions
        @views u[3N+1:6N]        .+= dt_use .* du[3N+1:6N]
        @views u[1:3N]            .+= dt_use .* u[3N+1:6N]
        @views u[6N+Nr+1:6N+2Nr] .+= dt_use .* du[6N+Nr+1:6N+2Nr]
        @views u[6N+1:6N+Nr]     .+= dt_use .* u[6N+Nr+1:6N+2Nr]

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

    # ── Ring nodes: NO artificial translational damping ─────────────────────
    # In the real system ring centres are constrained only by rope geometry —
    # nothing in the sky damps transverse motion.  Artificial damping here
    # suppresses genuine wobbles, resonances, and lateral ring oscillations
    # that are the suspected mechanism behind real-world TRPT collapses and
    # over-twist events observed in flight.  All rings (including hub) are
    # free to translate in all directions; the ropes provide the only physical
    # restoring force.  Ground ring position is zeroed explicitly below.

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


"""
    settle_to_operational_state(sys::KiteTurbineSystem, u0::Vector{Float64}, p::SystemParams, ω_rated::Float64)

Initializes the system at the rated operating point to avoid torsional transients.
Uses a torque-chain bisection method to find the exact helical equilibrium of the ropes.
This logic was shadowed directly from the interactive dashboard.
"""
function settle_to_operational_state(sys::KiteTurbineSystem, u0::Vector{Float64}, p::SystemParams, ω_rated::Float64;
                                    lift_device::Union{Nothing, LiftDevice} = nothing)
    u_start = settle_to_equilibrium(sys, u0, p; lift_device=lift_device)

    N  = sys.n_total
    Nr = sys.n_ring

    τ_rated  = p.k_mppt * ω_rated^2
    EA_rope  = p.e_modulus * π * (p.tether_diameter / 2)^2
    β_a      = p.elevation_angle
    sd       = [cos(β_a), 0.0, sin(β_a)]
    pp1, pp2 = shaft_perp_basis(sd)
    stride   = 1 + p.n_lines * 3

    # 1. Uniform ω — zero inter-ring velocity difference at t=0
    for ri in 1:Nr
        u_start[6N + Nr + ri] = ω_rated
    end

    # 2. Per-segment equilibrium twist via torque-chain bisection.
    u_start[6N + 1] = 0.0   # ground ring: α = 0 (reference)
    α_cum      = 0.0
    τ_target_a = τ_rated    # torque needed on the LOWER ring of the first segment

    for s in 1:(Nr - 1)
        gid_a = sys.ring_ids[s]
        gid_b = sys.ring_ids[s + 1]
        na    = sys.nodes[gid_a]::RingNode
        nb    = sys.nodes[gid_b]::RingNode

        ctr_a = u_start[3*(gid_a-1)+1 : 3*gid_a]
        ctr_b = u_start[3*(gid_b-1)+1 : 3*gid_b]

        # Natural segment length derived from sub_segs (supports non-uniform spacing)
        L_seg_s = 4 * sys.sub_segs[(s-1)*p.n_lines*4 + 1].length_0

        τ_fn_a = (Δα) -> begin
            τ = 0.0
            for j in 1:p.n_lines
                pa_j    = attachment_point(ctr_a, na.radius, α_cum,       j, p.n_lines, pp1, pp2)
                pb_j    = attachment_point(ctr_b, nb.radius, α_cum + Δα,  j, p.n_lines, pp1, pp2)
                chord_j = norm(pb_j .- pa_j)
                chord_j < 1e-9 && continue
                T_j     = EA_rope * max(0.0, (chord_j - L_seg_s) / L_seg_s)
                dir_j   = (pb_j .- pa_j) ./ chord_j
                r_vec_a = pa_j .- ctr_a
                τ      += T_j * dot(cross(r_vec_a, dir_j), sd)
            end
            τ
        end

        lo, hi = 0.001, π / 4
        for _ in 1:60
            mid = (lo + hi) / 2
            τ_fn_a(mid) < τ_target_a ? (lo = mid) : (hi = mid)
        end
        Δα_eq = (lo + hi) / 2

        τ_b = 0.0
        for j in 1:p.n_lines
            pa_j    = attachment_point(ctr_a, na.radius, α_cum,         j, p.n_lines, pp1, pp2)
            pb_j    = attachment_point(ctr_b, nb.radius, α_cum + Δα_eq, j, p.n_lines, pp1, pp2)
            chord_j = norm(pb_j .- pa_j)
            chord_j < 1e-9 && continue
            T_j     = EA_rope * max(0.0, (chord_j - L_seg_s) / L_seg_s)
            dir_j   = (pb_j .- pa_j) ./ chord_j
            r_vec_b = pb_j .- ctr_b
            τ_b    += T_j * dot(cross(r_vec_b, -dir_j), sd)
        end
        τ_target_a = -τ_b   # next lower ring must cancel this segment's load on ring_b

        α_cum += Δα_eq
        u_start[6N + nb.ring_idx] = α_cum

        # 3. Rope nodes consistent with equilibrium twist for this segment.
        α_a = u_start[6N + na.ring_idx]
        α_b = u_start[6N + nb.ring_idx]
        for j in 1:p.n_lines
            pa = attachment_point(ctr_a, na.radius, α_a, j, p.n_lines, pp1, pp2)
            pb = attachment_point(ctr_b, nb.radius, α_b, j, p.n_lines, pp1, pp2)
            for m in 1:3
                frac = m / 4.0
                gid  = (s - 1) * stride + 2 + (j - 1) * 3 + (m - 1)
                u_start[3*(gid-1)+1 : 3*gid] .= pa .+ frac .* (pb .- pa)
            end
        end
    end

    set_orbital_velocities!(u_start, sys, p)
    @views u_start[3N + 3*(sys.ring_ids[1]-1)+1 : 3N + 3*sys.ring_ids[1]] .= 0.0

    return u_start
end
export settle_to_operational_state

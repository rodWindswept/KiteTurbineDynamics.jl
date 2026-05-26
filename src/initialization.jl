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
    n_total = n_ring + n_rope + 2       # +1 for bearing, +1 for sky anchor
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
    F_top_ax    = max(F_aero_z / sin(β), 20.0)

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

    # ── Bearing node + bridle segments + sky anchor + cyan line ──────────
    # The bearing is a free particle placed above the hub ring centre along
    # the shaft axis.  N bridle spring-dampers connect it to the hub ring
    # vertices.  A single "cyan line" runs from the bearing up to the sky
    # anchor — a small particle that takes the lifter-kite force at ~80°
    # and the back line down to the ground anchor.  This three-way splice
    # ("Sky Anchor") replaces the old fixed-direction lift force on the
    # bearing and lets the system rise when the back line is paid out.
    BEARING_MASS   = 0.3           # kg — small bearing + skateboard wheel
    BRIDLE_EA      = 500_000.0     # N  — stiff bridle lines (Dyneema 2mm)
    BRIDLE_C_DAMP  = 500.0         # N·s/m — ~80% of critical for bearing mass
    BRIDLE_DIAM    = 0.002         # m  — 2mm Dyneema bridle line
    bearing_offset = 6.0           # m above hub centre (along shaft)

    SKY_ANCHOR_MASS = 0.3           # kg — small splice/knot, not the lifter itself
    CYAN_L0         = 5.0           # m — bearing↔sky-anchor line ("a few m")
    CYAN_EA         = 500_000.0     # N  — same Dyneema as bridles
    CYAN_C_DAMP     = 500.0         # N·s/m — same critical fraction
    CYAN_DIAM       = 0.003         # m  — 3 mm Dyneema (carries lifter load)

    # Bearing slot (n_total-1) and sky anchor slot (n_total)
    bearing_gid    = n_total - 1
    sky_anchor_gid = n_total

    nodes[bearing_gid]    = BearingNode(bearing_gid, BEARING_MASS)
    nodes[sky_anchor_gid] = SkyAnchorNode(sky_anchor_gid, SKY_ANCHOR_MASS)

    bearing_pos0    = ring_pos[end] .+ bearing_offset .* shaft_dir
    # Sky anchor sits CYAN_L0 further along the shaft so the cyan line is at
    # rest length and pulls the bearing along +shaft_dir at frame 0 — that
    # plus symmetric bridles is what keeps the bearing on-axis.
    sky_anchor_pos0 = bearing_pos0 .+ CYAN_L0 .* shaft_dir

    # Bridles: bearing → hub-ring vertices (unchanged geometry)
    for j in 1:p.n_lines
        pa_attach = attachment_point(ring_pos[end], ring_radii[end], 0.0,
                                     j, p.n_lines, perp1, perp2)
        bridle_L0 = norm(bearing_pos0 .- pa_attach)
        push!(sub_segs, RopeSubSegment(
            SubSegmentEnd(bearing_gid, false, j),   # bearing end (lower)
            SubSegmentEnd(ring_ids[end], true, j),  # hub-vertex end (upper)
            bridle_L0, BRIDLE_EA, BRIDLE_C_DAMP, BRIDLE_DIAM))
    end

    # Cyan line: single sub-segment, both ends non-ring (bearing → sky anchor).
    # line_idx is unused for non-ring ends; pick an arbitrary 1.
    push!(sub_segs, RopeSubSegment(
        SubSegmentEnd(bearing_gid,    false, 1),    # bearing end (lower)
        SubSegmentEnd(sky_anchor_gid, false, 1),    # sky anchor end (upper)
        CYAN_L0, CYAN_EA, CYAN_C_DAMP, CYAN_DIAM))

    sys = KiteTurbineSystem(nodes, sub_segs, ring_ids, rotor, kite,
                            bearing_gid, sky_anchor_gid, n_ring, n_total,
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

    # Bearing + sky anchor initial positions
    u0[3*(bearing_gid-1)+1    : 3*bearing_gid]    .= bearing_pos0
    u0[3*(sky_anchor_gid-1)+1 : 3*sky_anchor_gid] .= sky_anchor_pos0

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
                                wind_fn     ::Union{Nothing, Function} = nothing,
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
    wind_zero  = wind_fn === nothing ? (pos, t) -> zeros(3) : wind_fn
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
         
    hub_ri = (sys.nodes[hub_gid]::RingNode).ring_idx
    pp1, pp2 = _tilted_ring_basis(u, sys, hub_gid, hub_ri)

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
               
    hub_ri = (sys.nodes[hub_gid]::RingNode).ring_idx
    pp1, pp2 = _tilted_ring_basis(u, sys, hub_gid, hub_ri)

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
    simulate(sys, u0, p, wind_fn; n_steps, dt, lin_damp, ang_damp, bearing_tr_damp) → Vector{Float64}

Explicit semi-implicit Euler integrator with wind loading.
Same stability guarantee as `settle_to_equilibrium` but drives the full
aero + generator dynamics so angular velocity can evolve naturally.

`ang_damp = 1.0` (default) means no angular velocity kill per step —
the hub is free to spin up or down under the net torque balance.
`lin_damp = 0.05` keeps rope oscillations damped without stopping the physics.

`bearing_tr_damp = 0.99994` damps the bearing's velocity component
transverse to the shaft axis (i.e. the off-axis precession velocity).
The along-shaft component is untouched so the bearing can rise and fall freely.

**Physical justification:** The bearing assembly is a free particle in the
air, held in position only by tether lines (cyan line below, bridles above,
back line via sky anchor).  Several small real-world dissipation mechanisms
damp transverse (off-axis) oscillations that the ODE does not model:
aerodynamic drag on the fitting hardware and attachment knots, viscoelastic
damping in the line material (Dyneema creep and hysteresis), and gyroscopic
stabilisation from the spinning rotor above resisting lateral excitation.
Without any transverse dissipation the simulated bearing is an ideal free
particle that can precess indefinitely under asymmetric bridle loading
# (e.g. during pitch depower when ring deceleration makes bridle tensions unequal).
The default corresponds to an e-folding time of ~0.7 s for transverse
motion — consistent with observed line-system damping and gentle enough to
preserve all physically meaningful dynamics.
"""
function simulate(sys            ::KiteTurbineSystem,
                  u0             ::Vector{Float64},
                  p              ::SystemParams,
                  wind_fn        ::Function;
                  lift_device    ::Union{Nothing, LiftDevice} = nothing,
                  n_steps        ::Int     = 50_000,
                  dt             ::Float64 = 4e-5,
                  lin_damp       ::Float64 = 0.05,
                  ang_damp       ::Float64 = 1.0,
                  bearing_tr_damp::Float64 = 0.99994)
    u  = copy(u0)
    N  = sys.n_total
    Nr = sys.n_ring
    du = zeros(Float64, length(u))
    t  = 0.0
    ode_params = lift_device === nothing ? (sys, p, wind_fn) :
                                           (sys, p, wind_fn, lift_device)

    β0      = p.elevation_angle
    sd0     = [cos(β0), 0.0, sin(β0)]   # design shaft direction (fallback)
    bgid    = sys.bearing_id
    hub_gid = sys.rotor.node_id
    b_iv    = 3N + 3*(bgid-1) + 1       # first velocity index of bearing in u

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

        # Bearing transverse damping: damp only the velocity component perpendicular
        # to the shaft axis.  The axial component (rise/fall during pitch depower) is free.
        hp    = @view u[3*(hub_gid-1)+1 : 3*hub_gid]
        hp_m  = norm(hp)
        sd    = hp_m > 0.1 ? hp ./ hp_m : sd0
        vbx, vby, vbz = u[b_iv], u[b_iv+1], u[b_iv+2]
        v_ax_s = vbx*sd[1] + vby*sd[2] + vbz*sd[3]   # scalar dot product
        u[b_iv]   = v_ax_s*sd[1] + bearing_tr_damp*(vbx - v_ax_s*sd[1])
        u[b_iv+1] = v_ax_s*sd[2] + bearing_tr_damp*(vby - v_ax_s*sd[2])
        u[b_iv+2] = v_ax_s*sd[3] + bearing_tr_damp*(vbz - v_ax_s*sd[3])

        u[1:3]       .= 0.0   # ground ring centre stays at origin
        u[3N+1:3N+3] .= 0.0   # ground ring translational velocity = 0
        # alpha[1] and omega[1] evolve freely — ground ring IS the generator input shaft
    end
    return u
end


"""
    design_preload_from_sky_anchor(p, lift_device; bearing_offset, cyan_L0) → T_cyan

Solve the 3-force balance at the sky anchor node to find the design cyan-line tension.

Sky anchor equilibrium:  F_lift + T_back·back_dir + T_cyan·cyan_dir + W_sky = 0

Solves the 2×2 (x, z) linear system for [T_back; T_cyan] given:
- F_lift from lift_force_steady at design wind speed
- Sky anchor position: (tether_length + bearing_offset + cyan_L0) along shaft
- Back anchor position: (tether_length·cos β + back_anchor_fwd_x, 0, 0)
- Bearing position: (tether_length + bearing_offset) along shaft

Returns T_cyan (clamped to ≥ 0).
"""
function design_preload_from_sky_anchor(p::SystemParams, lift_device::LiftDevice;
                                         bearing_offset::Float64 = 6.0,
                                         cyan_L0::Float64        = 5.0,
                                         m_sky::Float64          = 0.3)
    β         = p.elevation_angle
    shaft_dir = [cos(β), 0.0, sin(β)]

    bearing_pos   = (p.tether_length + bearing_offset) .* shaft_dir
    sky_pos       = (p.tether_length + bearing_offset + cyan_L0) .* shaft_dir
    back_ax       = p.tether_length * cos(β) + p.back_anchor_fwd_x
    back_pos      = [back_ax, 0.0, 0.0]

    back_dir = normalize(back_pos .- sky_pos)
    cyan_dir = normalize(bearing_pos .- sky_pos)   # ≈ –shaft_dir

    _, T_lift, el_deg = lift_force_steady(lift_device, p.rho, p.v_wind_ref)
    el = deg2rad(el_deg)

    # T_back·back_dir + T_cyan·cyan_dir = –F_lift + W_sky_upward
    A   = [back_dir[1]  cyan_dir[1];
           back_dir[3]  cyan_dir[3]]
    rhs = [-T_lift * cos(el);
           -T_lift * sin(el) + m_sky * 9.81]
    sol = A \ rhs
    return max(sol[2], 0.0)
end

"""
    settle_to_operational_state(sys::KiteTurbineSystem, u0::Vector{Float64}, p::SystemParams, ω_rated::Float64)

Initializes the system at the rated operating point to avoid torsional transients.
Uses a torque-chain bisection method to find the exact helical equilibrium of the ropes.
This logic was shadowed directly from the interactive dashboard.
"""
function settle_to_operational_state(sys::KiteTurbineSystem, u0::Vector{Float64}, p::SystemParams, ω_rated_max::Float64;
                                    lift_device::Union{Nothing, LiftDevice} = nothing,
                                    wind_fn::Union{Nothing, Function}      = nothing)
    u_start = settle_to_equilibrium(sys, u0, p;
                                     lift_device = lift_device,
                                     wind_fn     = wind_fn)

    N  = sys.n_total
    Nr = sys.n_ring

    # Find the true aerodynamic equilibrium ω to prevent over-wound startup
    # and immediate deceleration transients when v_wind < v_rated.
    v_wind_hub = wind_fn === nothing ? zeros(3) : wind_fn(u_start[3*(sys.rotor.node_id-1)+1 : 3*sys.rotor.node_id], 0.0)
    v_mag = norm(v_wind_hub)
    ω_eq = ω_rated_max
    if v_mag > 0.1
        # Scan downwards from rated speed to find the stable operating point
        # where aerodynamic torque equals generator torque. We look for the 
        # highest ω where P_aero > P_gen to avoid the trivial P=0 stall state.
        for w in range(ω_rated_max, 0.1, length=200)
            lambda = w * sys.rotor.radius / v_mag
            P_aero = 0.5 * p.rho * v_mag^3 * π * sys.rotor.radius^2 * cp_at_tsr(lambda) * cos(p.elevation_angle)^3
            P_gen = p.k_mppt * w^3
            if P_aero > P_gen
                ω_eq = w
                break
            end
        end
    else
        ω_eq = 0.0
    end
    τ_eq  = p.k_mppt * ω_eq^2

    # ── Restore design ring positions with aero-derived axial preload ────────
    # settle_to_equilibrium runs at ω ≈ 0 with no aerodynamic loading, so the
    # rings settle to nearly their natural (zero-strain) spacing.  At that
    # spacing the tether chord ≈ L_seg_s → zero tension → grey lines at frame 0
    # and no torsional rigidity at start-up (the "preload deletion" bug).
    # When lift_device is provided, we add T_cyan (cyan line tension from the
    # sky anchor 3-force balance) to the design F_top_ax.  This accounts for
    # the additional axial load the kite line imposes on the bearing, which
    # propagates through the bridles to preload the top of the TRPT shaft.
    # Bearing and sky-anchor positions from the settle are intentionally kept;
    # the operational settle below will re-equilibrate them at ω_rated.
    β_r   = p.elevation_angle
    sd_r  = [cos(β_r), 0.0, sin(β_r)]
    let
        if lift_device !== nothing
            T_cyan_des = design_preload_from_sky_anchor(p, lift_device)
            n_seg_r    = Nr - 1
            EA_tot     = p.n_lines * p.e_modulus * π * (p.tether_diameter / 2)^2
            k_ax       = EA_tot / (p.tether_length / n_seg_r)
            m_rotor_d  = p.n_blades * p.m_blade
            kite_m_d   = sys.kite.mass
            v_r        = p.v_wind_ref
            thrust_r   = 0.5 * p.rho * v_r^2 * π * p.rotor_radius^2 * 0.8 * cos(β_r)^2
            F_aero_z_r = thrust_r * sin(β_r) + (m_rotor_d + kite_m_d) * (-9.81)
            F_top_ax_r = max(F_aero_z_r / sin(β_r) + T_cyan_des, 20.0)
            g_inc      = p.m_ring * 9.81 / sin(β_r)
            F_ax       = zeros(n_seg_r)
            F_ax[n_seg_r] = F_top_ax_r
            for i in (n_seg_r-1):-1:1
                F_ax[i] = F_ax[i+1] + g_inc
            end
            seg_len = p.tether_length / n_seg_r
            rp = zeros(3)
            for k in 1:Nr
                gid = sys.ring_ids[k]
                idx = 3*(gid-1)+1 : 3*gid
                u_start[idx] .= rp
                if k < Nr
                    stretch = max(0.0, F_ax[k] / k_ax)
                    rp .+= (seg_len + stretch) .* sd_r
                end
            end
        else
            for k in 1:Nr
                gid = sys.ring_ids[k]
                idx = 3*(gid-1)+1 : 3*gid
                u_start[idx] .= u0[idx]
            end
        end
    end

    # Capture restored ring positions — pinned throughout the operational settle
    # to prevent dt²·(F/m) position drift from erasing the axial preload.
    preload_ring_pos = [u_start[3*(sys.ring_ids[k]-1)+1 : 3*sys.ring_ids[k]] for k in 1:Nr]

    EA_rope  = p.e_modulus * π * (p.tether_diameter / 2)^2
    # shaft direction for torque projections: ring positions were restored to
    # design-preloaded values along [cos β, 0, sin β]; normalising the hub
    # position recovers that direction exactly.  sd_r (computed above) is the
    # same vector — used here as the fallback when hub is near origin.
    hub_p_settled = u_start[3*(sys.rotor.node_id-1)+1 : 3*sys.rotor.node_id]
    hp_mag        = norm(hub_p_settled)
    sd            = hp_mag > 0.1 ? hub_p_settled ./ hp_mag : sd_r
    stride   = 1 + p.n_lines * 3

    # 1. Uniform ω — zero inter-ring velocity difference at t=0
    for ri in 1:Nr
        u_start[6N + Nr + ri] = ω_eq
    end

    # ── Operational settle — find bearing equilibrium at ω_rated ────────────
    # We must do this BEFORE bisection because the operational settle moves
    # the bearing, which changes the tilted ring plane. If we bisect before
    # the bearing moves, the initialized rope node positions will not match
    # the tilted basis used by the ODE during the actual simulation, causing
    # a visual disconnect and huge artificial tension spikes at t=0.
    #
    # Uses orbital_damp_rope_velocities! (same as the simulation loop) rather
    # than a flat velocity kill.  The flat kill zeroed orbital rope velocities,
    # producing a "rings spinning, ropes static" equilibrium that is inconsistent
    # with the simulation's orbital-preserving damper — the mismatch caused
    # visible power swings in the first ~2 s of every scenario rerun.
    # With orbital damping, the settle trains positions AND velocities to be
    # mutually consistent, so the first simulation frame is already smooth.
    let
        du2 = zeros(Float64, length(u_start))
        wind_use   = wind_fn === nothing ? (pos, t) -> zeros(3) : wind_fn
        ode_params = lift_device === nothing ? (sys, p, wind_use) :
                                                (sys, p, wind_use, lift_device)
        dt_op   = p.n_lines >= 8 ? 1e-5 : 4e-5
        n_op    = 150_000   # 6 s simulated — long enough for bearing+rope to
                            # reach orbital equilibrium from any starting state

        for _ in 1:n_op
            fill!(du2, 0.0)
            multibody_ode!(du2, u_start, ode_params, 0.0)
            @views u_start[3N+1:6N]        .+= dt_op .* du2[3N+1:6N]
            @views u_start[1:3N]            .+= dt_op .* u_start[3N+1:6N]
            @views u_start[6N+Nr+1:6N+2Nr] .= ω_eq   # pin ω throughout

            # Damp rope nodes with the orbital-preserving damper (same as
            # the simulation loop) — trains rope positions/velocities to be
            # consistent with orbital motion so the first sim frame is smooth.
            orbital_damp_rope_velocities!(u_start, sys, p, 0.05)

            # Ring centres should not drift during the settle — zero their
            # translational velocities explicitly.  (orbital_damp only touches
            # RopeNodes; ring translational DOFs are free otherwise.)
            for k in 1:Nr
                gid = sys.ring_ids[k]
                bv  = 3N + 3*(gid-1) + 1
                u_start[bv : bv+2] .= 0.0
            end
            # Pin ring positions to design preload — prevents dt²·(F/m) drift
            # from accumulating over 150 000 steps and erasing axial preload.
            for k in 1:Nr
                gid = sys.ring_ids[k]
                idx = 3*(gid-1)+1 : 3*gid
                u_start[idx] .= preload_ring_pos[k]
            end
            # Bearing and sky-anchor translational velocities: let them settle
            # naturally (they need to find equilibrium, not be pinned).
            u_start[1:3]       .= 0.0   # ground ring position (fixed)
            u_start[3N+1:3N+3] .= 0.0   # ground ring velocity (fixed)
        end
        # All translational velocities to zero at the end — the subsequent
        # set_orbital_velocities! call is now redundant (rope nodes are
        # already at their orbital values) but kept as a consistency check.
        @views u_start[3N+1:6N] .= 0.0
    end

    # Now that the bearing has found its equilibrium, the tilt axis is stable.
    # Extract the tilted basis for the hub to use for all TRPT bisections.
    hub_gid = sys.rotor.node_id
    hub_ri = (sys.nodes[hub_gid]::RingNode).ring_idx
    pp1, pp2 = _tilted_ring_basis(u_start, sys, hub_gid, hub_ri)

    # 2. Per-segment equilibrium twist via torque-chain bisection.
    u_start[6N + 1] = 0.0   # ground ring: α = 0 (reference)
    α_cum      = 0.0
    τ_target_a = τ_eq    # torque needed on the LOWER ring of the first segment

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
export design_preload_from_sky_anchor

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
    kite_lift_z = q * kite_area * 1.2
    thrust_ax   = q * π * p.rotor_radius^2 * 0.8 * cos(β)^2
    F_aero_z    = kite_lift_z + thrust_ax * sin(β) + (m_rotor + kite_mass) * g_z
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
    nodes[1] = RingNode(1, 1, 1e30, ring_radii[1], 1e30 * ring_radii[1]^2, true)
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

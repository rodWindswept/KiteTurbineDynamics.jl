using LinearAlgebra

"""
    compute_rope_forces!(forces, torques, u, alpha, sys, p, wind_fn, t,
                          perp1_tilt, perp2_tilt)

Accumulates sub-segment spring/damper/drag forces into `forces[i]` for all nodes,
and shaft-axis torques into `torques[k]` for RingNodes (indexed by ring_idx).

Uses TWO ring-plane bases:
- **shaft_dir** basis for bridle sub-segments (bearing→hub connections).
  Bridles are kept in the shaft frame to prevent tilt→bridle→tilt feedback.
- **tilted** basis for TRPT sub-segments (ring→ring connections).
  The tilted basis lets the tether geometry respond to ring-plane tilt,
  enabling power spill during furl.

`alpha` is a length-n_ring vector of current twist angles (ring_idx order).
"""
function compute_rope_forces!(forces      ::Vector{<:AbstractVector},
                               torques     ::AbstractVector,
                               u           ::AbstractVector,
                               alpha       ::AbstractVector,
                               sys         ::KiteTurbineSystem,
                               p           ::SystemParams,
                               wind_fn     ::Function,
                               t           ::Float64,
                               perp1_tilt  ::Union{AbstractVector, Nothing} = nothing,
                               perp2_tilt  ::Union{AbstractVector, Nothing} = nothing)

    N  = sys.n_total
    # Dynamic shaft direction
    hub_gid   = sys.rotor.node_id
    hub_pos_r = u[3*(hub_gid-1)+1 : 3*hub_gid]
    hub_rmag  = norm(hub_pos_r)
    shaft_dir = hub_rmag > 0.1 ?
                hub_pos_r ./ hub_rmag :
                [cos(p.elevation_angle), 0.0, sin(p.elevation_angle)]
    perp1_shaft, perp2_shaft = shaft_perp_basis(shaft_dir)

    # Default tilted basis = shaft basis if not provided
    local pp1_tilt = perp1_tilt === nothing ? perp1_shaft : perp1_tilt
    local pp2_tilt = perp2_tilt === nothing ? perp2_shaft : perp2_tilt

    # Helper: 3D position of a SubSegmentEnd
    function end_pos(se::SubSegmentEnd, use_tilted::Bool)
        if se.is_ring
            node  = sys.nodes[se.node_id]::RingNode
            ri    = node.ring_idx
            R     = node.radius
            α     = alpha[ri]
            ctr   = u[3*(se.node_id-1)+1 : 3*se.node_id]
            pp1, pp2 = use_tilted ? (pp1_tilt, pp2_tilt) : (perp1_shaft, perp2_shaft)
            return attachment_point(ctr, R, α, se.line_idx, p.n_lines, pp1, pp2)
        else
            return u[3*(se.node_id-1)+1 : 3*se.node_id]
        end
    end

    # Helper: velocity at a SubSegmentEnd
    function end_vel(se::SubSegmentEnd)
        return u[3*N+3*(se.node_id-1)+1 : 3*N+3*se.node_id]
    end

    for ss in sys.sub_segs
        # Bridle sub-segments have non-ring end_a (bearing); TRPT have both ring ends.
        # Bridles → shaft basis (stable); TRPT → tilted basis (power spill).
        is_bridle = !ss.end_a.is_ring
        pa = end_pos(ss.end_a, !is_bridle)
        pb = end_pos(ss.end_b, !is_bridle)
        va = end_vel(ss.end_a)
        vb = end_vel(ss.end_b)

        diff_pos    = pb .- pa
        current_len = norm(diff_pos)
        current_len < 1e-9 && continue

        dir      = diff_pos ./ current_len
        rel_vel  = vb .- va
        vel_proj = dot(rel_vel, dir)
        strain   = (current_len - ss.length_0) / ss.length_0
        tension  = max(0.0, ss.EA * strain + ss.c_damp * vel_proj)
        F_vec    = tension .* dir

        # Aerodynamic drag on all rope/tether sub-segments (50/50 distributed)
        mid_pos = (pa .+ pb) ./ 2.0
        v_wind  = wind_fn(mid_pos, t)
        v_node  = (va .+ vb) ./ 2.0
        drag    = tether_drag_force(p.rho, TETHER_DRAG_CD, ss.diameter,
                                     ss.length_0, v_wind, v_node, dir)
        forces[ss.end_a.node_id] .+= 0.5 .* drag
        forces[ss.end_b.node_id] .+= 0.5 .* drag

        # Apply spring force to nodes — torque projection always uses shaft_dir
        if ss.end_a.is_ring
            node_a  = sys.nodes[ss.end_a.node_id]::RingNode
            ri_a    = node_a.ring_idx
            ctr_a   = u[3*(ss.end_a.node_id-1)+1 : 3*ss.end_a.node_id]
            r_vec_a = pa .- ctr_a
            forces[ss.end_a.node_id]   .+= F_vec
            torques[ri_a]              += dot(cross(r_vec_a, F_vec), shaft_dir)
        else
            forces[ss.end_a.node_id] .+= F_vec
        end

        if ss.end_b.is_ring
            node_b  = sys.nodes[ss.end_b.node_id]::RingNode
            ri_b    = node_b.ring_idx
            ctr_b   = u[3*(ss.end_b.node_id-1)+1 : 3*ss.end_b.node_id]
            r_vec_b = pb .- ctr_b
            forces[ss.end_b.node_id]   .-= F_vec
            torques[ri_b]              += dot(cross(r_vec_b, -F_vec), shaft_dir)
        else
            forces[ss.end_b.node_id] .-= F_vec
        end
    end
end

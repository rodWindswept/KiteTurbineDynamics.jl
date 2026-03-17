using LinearAlgebra

"""
    compute_rope_forces!(forces, torques, u, alpha, sys, p, wind_fn, t)

Accumulates sub-segment spring/damper/drag forces into `forces[i]` for all nodes,
and shaft-axis torques into `torques[k]` for RingNodes (indexed by ring_idx).

`alpha` is a length-n_ring vector of current twist angles (ring_idx order).
"""
function compute_rope_forces!(forces      ::Vector{<:AbstractVector},
                               torques     ::AbstractVector,
                               u           ::AbstractVector,
                               alpha       ::AbstractVector,
                               sys         ::KiteTurbineSystem,
                               p           ::SystemParams,
                               wind_fn     ::Function,
                               t           ::Float64)

    N  = sys.n_total
    β  = p.elevation_angle
    shaft_dir = [cos(β), 0.0, sin(β)]
    perp1, perp2 = shaft_perp_basis(shaft_dir)

    # Helper: 3D position of a SubSegmentEnd
    function end_pos(se::SubSegmentEnd)
        if se.is_ring
            node  = sys.nodes[se.node_id]::RingNode
            ri    = node.ring_idx
            R     = node.radius
            α     = alpha[ri]
            ctr   = u[3*(se.node_id-1)+1 : 3*se.node_id]
            return attachment_point(ctr, R, α, se.line_idx, p.n_lines, perp1, perp2)
        else
            return u[3*(se.node_id-1)+1 : 3*se.node_id]
        end
    end

    # Helper: velocity at a SubSegmentEnd (ring attachment ≈ ring centre velocity)
    function end_vel(se::SubSegmentEnd)
        return u[3*N+3*(se.node_id-1)+1 : 3*N+3*se.node_id]
    end

    for ss in sys.sub_segs
        pa = end_pos(ss.end_a)
        pb = end_pos(ss.end_b)
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

        # Aerodynamic drag on rope nodes (applied at end_b when it is a rope node)
        if !ss.end_b.is_ring
            mid_pos = (pa .+ pb) ./ 2.0
            v_wind  = wind_fn(mid_pos, t)
            v_node  = vb
            v_rel   = v_wind .- v_node
            v_perp  = v_rel .- dot(v_rel, dir) .* dir
            v_perp_mag = norm(v_perp)
            if v_perp_mag > 0.01
                drag = 0.5 * p.rho * 1.0 * ss.diameter * ss.length_0 *
                       v_perp_mag .* v_perp
                forces[ss.end_b.node_id] .+= drag
            end
        end

        # Apply spring force to nodes
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

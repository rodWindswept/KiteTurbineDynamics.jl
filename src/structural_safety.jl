# src/structural_safety.jl
# Ring hoop compression and Euler buckling FoS — post-process only, no ODE coupling.

const RING_SWL   = 500.0    # N — conservative buckling limit
const TETHER_SWL = 3500.0   # N — Dyneema 3 mm safe working load

"""
    ring_safety_frame(u, alpha, sys, p) → Vector{NamedTuple}

Compute per-ring hoop compression and Euler buckling FoS for one ODE frame.
Skips the fixed ground node (ring_idx=1) and the hub (ring_idx=Nr).
"""
function ring_safety_frame(u      ::AbstractVector,
                            alpha  ::AbstractVector,
                            sys    ::KiteTurbineSystem,
                            p      ::SystemParams)
    N  = sys.n_total
    Nr = sys.n_ring
    β        = p.elevation_angle
    shaft_dir = [cos(β), 0.0, sin(β)]
    perp1, perp2 = shaft_perp_basis(shaft_dir)

    results = Vector{NamedTuple}()

    E_ring = p.e_modulus
    d_ring = 0.005          # 5 mm ring cross-section diameter (placeholder)
    I_ring = π * (d_ring / 2)^4 / 4.0

    for (k, ring_gid) in enumerate(sys.ring_ids[2:end-1])  # skip ground and hub
        node   = sys.nodes[ring_gid]::RingNode
        R      = node.radius
        ri     = node.ring_idx
        α_ring = alpha[ri]
        ctr    = u[3*(ring_gid-1)+1 : 3*ring_gid]

        F_inward = 0.0
        for ss in sys.sub_segs
            # Only sub-segments whose upper end attaches to this ring
            ss.end_b.is_ring && ss.end_b.node_id == ring_gid || continue

            pa = if ss.end_a.is_ring
                node_a = sys.nodes[ss.end_a.node_id]::RingNode
                ctr_a  = u[3*(ss.end_a.node_id-1)+1 : 3*ss.end_a.node_id]
                attachment_point(ctr_a, node_a.radius, alpha[node_a.ring_idx],
                                 ss.end_a.line_idx, p.n_lines, perp1, perp2)
            else
                u[3*(ss.end_a.node_id-1)+1 : 3*ss.end_a.node_id]
            end

            pb  = attachment_point(ctr, R, α_ring, ss.end_b.line_idx,
                                   p.n_lines, perp1, perp2)
            len = norm(pb .- pa)
            len < 1e-9 && continue

            strain = (len - ss.length_0) / ss.length_0
            T      = max(0.0, ss.EA * strain)

            r_vec  = pb .- ctr
            r_norm = norm(r_vec)
            r_norm < 1e-9 && continue
            r_hat  = r_vec ./ r_norm

            dir = (pb .- pa) ./ len
            F_inward += T * abs(dot(dir, -r_hat))
        end

        F_hoop = F_inward / (2π)
        L_circ = 2π * R
        P_crit = (π^2 * E_ring * I_ring) / L_circ^2
        util   = F_hoop / max(P_crit, 1e-9)
        fos    = P_crit / max(F_hoop, 1e-9)

        push!(results, (ring_id    = k,
                        radius     = R,
                        F_hoop     = F_hoop,
                        P_crit     = P_crit,
                        utilisation = util,
                        fos        = fos,
                        exceeded   = (util > 1.0)))
    end
    return results
end

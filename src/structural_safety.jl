# src/structural_safety.jl
# Ring polygon-frame compression and Euler column buckling FoS — post-process only, no ODE coupling.
#
# Failure mode: Euler column buckling of each flat polygon segment (pin-pin ends).
# This governs a pentagon (or any regular polygon) frame, NOT ring hoop Euler buckling.
# Ring hoop Euler (P = 3EI/R²) applies to a continuous circular ring and overestimates
# P_crit for a polygon frame by 5–10× at TRPT geometry.  See TRPT_Ring_Scalability_Report.docx.

const TETHER_SWL = 3500.0   # N — Dyneema 3 mm safe working load

# ── CFRP tube structural constants ────────────────────────────────────────────
# Ring frames are built from CFRP hollow tubes; see TRPT_Ring_Scalability_Report §3.
const E_CFRP      = 70e9    # Pa  — conservative isotropic CFRP Young's modulus
const RHO_CFRP    = 1600.0  # kg/m³ — CFRP density
const T_OVER_D    = 0.05    # t/D wall ratio — aerodynamic and structural optimum
const T_MIN_WALL  = 5e-4    # m   — 0.5 mm minimum manufacturable wall thickness
const FOS_DESIGN  = 3.0     # column buckling factor of safety at design point

# Scaling law from analysis (exact thin-wall calibration, 10 kW rated, 5-line pentagon):
#   Do = DO_SCALE × √R
# Derivation: N_comp is constant across all ring radii when L_seg ∝ R (tapered TRPT),
# so I_req ∝ L_poly² ∝ R² and Do ∝ (I_req)^(1/4) ∝ R^(1/2).
# Calibrated by exact tube_I formula: Do = 19.7 mm at R = 2 m (vs 20.7 mm in the
# scalability report which used the thin-wall I ≈ π·t/D·D⁴/8 approximation).
#
# CALIBRATION NOTE (2026-04-20): DO_SCALE was originally set using T_line ≈ 2333 N from
# a pre-CT-correction simulation (commit fd02e39, 2026-03-26).  The CT-thrust correction
# (commit 6fa0100, 2026-04-09) reduced tether tension to ~820 N at rated (k=1.0, v=11 m/s)
# and ~730 N at optimal MPPT (k=1.5).  DO_SCALE is therefore CONSERVATIVE by ~√(2333/820)
# ≈ 1.69×, giving actual FoS ≈ 8–9 at rated conditions (vs design FoS = 3.0).
# DO_SCALE is intentionally left unchanged (structural conservatism; ring re-sizing pending
# formal review).  The ring_safety_frame() dashboard readout reflects live simulation loads.
const DO_SCALE = 0.01396    # m/m^0.5  →  Do = DO_SCALE × √R  (conservative — see note above)

"""
    tube_I(Do, t) → I (m⁴)

Second moment of area for a hollow circular tube (exact formula).
"""
function tube_I(Do::Float64, t::Float64)::Float64
    Di = Do - 2.0 * t
    return π / 64.0 * (Do^4 - Di^4)
end

"""
    ring_safety_frame(u, alpha, sys, p) → Vector{NamedTuple}

Compute per-ring polygon-segment compression and Euler column buckling FoS for one ODE frame.

Failure mode: Euler column (pin-pin) buckling of each straight polygon segment.
  P_crit = π² · E_CFRP · I_tube / L_poly²
where L_poly = 2R·sin(π/n) is the flat chord length of one polygon side.

Ring tube design: CFRP hollow tube sized by Do = DO_PER_R × R, t = T_OVER_D × Do.
FoS is computed against that design tube.  At rated loads FoS ≈ FOS_DESIGN = 3.0;
under higher than rated loads FoS falls, under lighter loads it rises — giving a
meaningful real-time margin indicator on the dashboard.

Skips the fixed ground node (ring_idx = 1) and the hub (ring_idx = Nr).
"""
function ring_safety_frame(u      ::AbstractVector,
                            alpha  ::AbstractVector,
                            sys    ::KiteTurbineSystem,
                            p      ::SystemParams)
    N  = sys.n_total
    Nr = sys.n_ring
    β         = p.elevation_angle
    shaft_dir = [cos(β), 0.0, sin(β)]
    perp1, perp2 = shaft_perp_basis(shaft_dir)

    results = Vector{NamedTuple}()

    for (k, ring_gid) in enumerate(sys.ring_ids[2:end-1])  # skip ground and hub
        node   = sys.nodes[ring_gid]::RingNode
        R      = node.radius
        ri     = node.ring_idx
        α_ring = alpha[ri]
        ctr    = u[3*(ring_gid-1)+1 : 3*ring_gid]

        # ── Accumulate total inward radial force on this ring from all attached sub-segments ──
        F_inward = 0.0
        for ss in sys.sub_segs
            on_end_b = ss.end_b.is_ring && ss.end_b.node_id == ring_gid
            on_end_a = ss.end_a.is_ring && ss.end_a.node_id == ring_gid
            (on_end_b || on_end_a) || continue

            if on_end_b
                pa = ss.end_a.is_ring ? begin
                        node_a = sys.nodes[ss.end_a.node_id]::RingNode
                        ctr_a  = u[3*(ss.end_a.node_id-1)+1 : 3*ss.end_a.node_id]
                        attachment_point(ctr_a, node_a.radius, alpha[node_a.ring_idx],
                                         ss.end_a.line_idx, p.n_lines, perp1, perp2)
                     end : u[3*(ss.end_a.node_id-1)+1 : 3*ss.end_a.node_id]
                pb  = attachment_point(ctr, R, α_ring, ss.end_b.line_idx,
                                       p.n_lines, perp1, perp2)
                len = norm(pb .- pa); len < 1e-9 && continue
                T   = max(0.0, ss.EA * (len - ss.length_0) / ss.length_0)
                r_vec = pb .- ctr
                dir   = (pb .- pa) ./ len   # rope direction toward ring
                F_inward += T * abs(dot(-dir, r_vec ./ max(norm(r_vec), 1e-9)))
            else
                pb = ss.end_b.is_ring ? begin
                        node_b = sys.nodes[ss.end_b.node_id]::RingNode
                        ctr_b  = u[3*(ss.end_b.node_id-1)+1 : 3*ss.end_b.node_id]
                        attachment_point(ctr_b, node_b.radius, alpha[node_b.ring_idx],
                                         ss.end_b.line_idx, p.n_lines, perp1, perp2)
                     end : u[3*(ss.end_b.node_id-1)+1 : 3*ss.end_b.node_id]
                pa  = attachment_point(ctr, R, α_ring, ss.end_a.line_idx,
                                       p.n_lines, perp1, perp2)
                len = norm(pb .- pa); len < 1e-9 && continue
                T   = max(0.0, ss.EA * (len - ss.length_0) / ss.length_0)
                r_vec = pa .- ctr
                dir   = (pa .- pb) ./ len   # rope direction toward ring
                F_inward += T * abs(dot(-dir, r_vec ./ max(norm(r_vec), 1e-9)))
            end
        end

        # ── Polygon column compression ─────────────────────────────────────────────────────────
        # For a regular n-gon with equal inward nodal forces F_v = F_inward/n:
        #   compression per segment  N_comp = F_v / (2·tan(π/n))
        n_float = float(p.n_lines)
        F_v     = F_inward / n_float
        N_comp  = F_v / (2.0 * tan(π / n_float))

        # Polygon segment length: flat chord between adjacent vertices (pin-pin column length)
        L_poly  = 2.0 * R * sin(π / n_float)

        # ── CFRP design tube for this ring ─────────────────────────────────────────────────────
        # Tube outer diameter scales as Do = DO_SCALE × √R  (derived: N_comp constant, I_req ∝ R²).
        Do_design = max(DO_SCALE * sqrt(R), T_MIN_WALL / T_OVER_D)
        t_design  = max(T_OVER_D * Do_design, T_MIN_WALL)
        I_design  = tube_I(Do_design, t_design)
        P_crit    = π^2 * E_CFRP * I_design / L_poly^2

        util = N_comp  / max(P_crit, 1e-9)
        fos  = P_crit  / max(N_comp,  1e-9)

        push!(results, (ring_id     = k,
                        radius      = R,
                        N_comp      = N_comp,
                        P_crit      = P_crit,
                        tube_Do_mm  = Do_design * 1e3,
                        utilisation = util,
                        fos         = fos,
                        exceeded    = (util > 1.0)))
    end
    return results
end

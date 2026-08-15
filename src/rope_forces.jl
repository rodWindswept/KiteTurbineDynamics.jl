using LinearAlgebra

# ══════════════════════════════════════════════════════════════════════════════
# TRPT-segment classification (2026-08-14): a sub-seg belongs to TRPT segment
# s (rings s ↔ s+1) when BOTH endpoint gids lie in [ring_ids[s], ring_ids[s+1]].
# TRPT lines are ring→rope-node→…→ring chains; "both ends are rings" is never
# true for them. 0 = not a TRPT chain sub-seg (bridle, cyan, lift).
# ══════════════════════════════════════════════════════════════════════════════
function trpt_seg_map(sub_segs, ring_ids)::Vector{Int}
    map = zeros(Int, length(sub_segs))
    n_seg = length(ring_ids) - 1
    for (si, ss) in enumerate(sub_segs)
        ga = ss.end_a.node_id
        gb = ss.end_b.node_id
        for s in 1:n_seg
            lo = ring_ids[s]
            hi = ring_ids[s + 1]
            if lo <= ga <= hi && lo <= gb <= hi
                map[si] = s
                break
            end
        end
    end
    return map
end

# Rope break strain (2026-08-14, Rod): Dyneema SK99 ultimate strain ≈ 3.5%.
# A sub-segment strained past this BREAKS: zero tension thereafter, and the
# evaluation is disqualified at the break instant (option B — no wreckage
# physics, no post-break simulation).
const ROPE_BREAK_STRAIN = 0.035

"""
    get_subsegment_tension(ss::RopeSubSegment, diff_pos, current_len, dir, va, vb; rel_buf=nothing) -> tension::Float64

Compute the physical spring-damper tension in a single rope sub-segment.
Accepts pre-computed geometry from the caller to avoid duplicate allocations.
When `rel_buf` (3-vector) is provided, uses it as scratch to avoid allocating `rel_vel`.

Break semantics (2026-08-14): pass `idx` (the sub-seg's index in
`sys.sub_segs`) and `broken::BitVector` — a broken sub-seg returns 0.0.
Break DETECTION is done at line level in `compute_rope_forces!` (full
ring-to-ring path strain vs ROPE_BREAK_STRAIN), not per numerical sub-seg —
mid-node placement artifacts must not trip the criterion.
"""
function get_subsegment_tension(ss::RopeSubSegment, diff_pos, current_len, dir, va, vb;
                                rel_buf=nothing, idx::Int=0, broken=nothing)
    if broken !== nothing && idx > 0 && broken[idx]
        return 0.0
    end
    if rel_buf !== nothing
        @inbounds for k in 1:3; rel_buf[k] = vb[k] - va[k]; end
        vel_proj = rel_buf[1]*dir[1] + rel_buf[2]*dir[2] + rel_buf[3]*dir[3]
    else
        rel_vel = vb .- va
        vel_proj = dot(rel_vel, dir)
    end
    return max(0.0, ss.EA * (current_len - ss.length_0) / ss.length_0 + ss.c_damp * vel_proj)
end

"""
    get_max_rope_tension(u::AbstractVector, sys::KiteTurbineSystem, p::SystemParams) -> (T_max::Float64, n_slack::Int)

Calculate the maximum tether tension and the number of slack lines across the TRPT shaft tethers.
Pure function of `u` (positions and velocities live in the state vector).
"""
function get_max_rope_tension(u::AbstractVector, sys::KiteTurbineSystem, p::SystemParams)
    N = sys.n_total
    Nr = sys.n_ring

    # Dynamic shaft direction
    hub_gid = sys.rotor.node_id
    hub_pos_r = @view u[(3 * (hub_gid - 1) + 1):(3 * hub_gid)]
    hub_rmag = norm(hub_pos_r)
    shaft_dir = if hub_rmag > 0.1
        hub_pos_r ./ hub_rmag
    else
        [cos(p.elevation_angle), 0.0, sin(p.elevation_angle)]
    end
    perp1_shaft, perp2_shaft = shaft_perp_basis(shaft_dir)

    # Tilted basis
    hub_ri = (sys.nodes[hub_gid]::RingNode).ring_idx
    pp1_tilt, pp2_tilt = _tilted_ring_basis(u, sys, hub_gid, hub_ri)

    alpha = @view u[(6N + 1):(6N + Nr)]

    function get_pos(se::SubSegmentEnd)
        if se.is_ring
            node = sys.nodes[se.node_id]::RingNode
            ri = node.ring_idx
            R = isempty(sys.expansion_rotors) ? node.radius : sys.effective_radii[ri]
            α = alpha[ri]
            ctr = @view u[(3 * (se.node_id - 1) + 1):(3 * se.node_id)]
            return attachment_point(ctr, R, α, se.line_idx, p.n_lines, pp1_tilt, pp2_tilt)
        else
            return @view u[(3 * (se.node_id - 1) + 1):(3 * se.node_id)]
        end
    end

    T_max = 0.0
    n_slack = 0

    n_tether_segs = 4 * p.n_lines * (sys.n_ring - 1)

    for idx in 1:n_tether_segs
        ss = sys.sub_segs[idx]
        pa = get_pos(ss.end_a)
        pb = get_pos(ss.end_b)
        va = @view u[(3 * N + 3 * (ss.end_a.node_id - 1) + 1):(3 * N + 3 * ss.end_a.node_id)]
        vb = @view u[(3 * N + 3 * (ss.end_b.node_id - 1) + 1):(3 * N + 3 * ss.end_b.node_id)]

        diff_pos = pb .- pa
        current_len = norm(diff_pos)
        current_len < 1e-9 && continue
        dir = diff_pos ./ current_len
        T = get_subsegment_tension(ss, diff_pos, current_len, dir, va, vb)
        T_max = max(T_max, T)
        T < 5.0 && (n_slack += 1)
    end

    return T_max, n_slack
end

"""
    get_segment_tension(u::AbstractVector, sys::KiteTurbineSystem, p::SystemParams, s::Int, j::Int; sub_idx::Int=2) -> Float64

Compute the physical tension of segment `s`, line `j` (specifically at subsegment `sub_idx` in 1..4).
Pure function of `u` (positions and velocities live in the state vector).
"""
function get_segment_tension(
    u::AbstractVector,
    sys::KiteTurbineSystem,
    p::SystemParams,
    s::Int,
    j::Int;
    sub_idx::Int=2,
)
    N = sys.n_total
    Nr = sys.n_ring

    # Dynamic shaft direction
    hub_gid = sys.rotor.node_id
    hub_pos_r = @view u[(3 * (hub_gid - 1) + 1):(3 * hub_gid)]
    hub_rmag = norm(hub_pos_r)
    shaft_dir = if hub_rmag > 0.1
        hub_pos_r ./ hub_rmag
    else
        [cos(p.elevation_angle), 0.0, sin(p.elevation_angle)]
    end
    perp1_shaft, perp2_shaft = shaft_perp_basis(shaft_dir)

    # Tilted basis
    hub_ri = (sys.nodes[hub_gid]::RingNode).ring_idx
    pp1_tilt, pp2_tilt = _tilted_ring_basis(u, sys, hub_gid, hub_ri)

    alpha = @view u[(6N + 1):(6N + Nr)]

    function get_pos(se::SubSegmentEnd)
        if se.is_ring
            node = sys.nodes[se.node_id]::RingNode
            ri = node.ring_idx
            R = isempty(sys.expansion_rotors) ? node.radius : sys.effective_radii[ri]
            α = alpha[ri]
            ctr = @view u[(3 * (se.node_id - 1) + 1):(3 * se.node_id)]
            return attachment_point(ctr, R, α, se.line_idx, p.n_lines, pp1_tilt, pp2_tilt)
        else
            return @view u[(3 * (se.node_id - 1) + 1):(3 * se.node_id)]
        end
    end

    idx = (s - 1) * p.n_lines * 4 + (j - 1) * 4 + sub_idx
    idx > length(sys.sub_segs) && return 0.0
    ss = sys.sub_segs[idx]

    pa = get_pos(ss.end_a)
    pb = get_pos(ss.end_b)
    va = @view u[(3 * N + 3 * (ss.end_a.node_id - 1) + 1):(3 * N + 3 * ss.end_a.node_id)]
    vb = @view u[(3 * N + 3 * (ss.end_b.node_id - 1) + 1):(3 * N + 3 * ss.end_b.node_id)]

    diff_pos = pb .- pa
    current_len = norm(diff_pos)
    current_len < 1e-9 && return 0.0
    dir = diff_pos ./ current_len
    return get_subsegment_tension(ss, diff_pos, current_len, dir, va, vb)
end

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
  enabling power spill during pitch depower.

`alpha` is a length-n_ring vector of current twist angles (ring_idx order).
"""
function compute_rope_forces!(
    forces::Vector{<:AbstractVector},
    torques::AbstractVector,
    u::AbstractVector,
    alpha::AbstractVector,
    sys::KiteTurbineSystem,
    p::SystemParams,
    wind_fn::Function,
    t::Float64,
    perp1_tilt::Union{AbstractVector, Nothing}=nothing,
    perp2_tilt::Union{AbstractVector, Nothing}=nothing,
)
    N = sys.n_total
    Nr = sys.n_ring
    # Dynamic shaft direction
    hub_gid = sys.rotor.node_id
    hub_pos_r = u[(3 * (hub_gid - 1) + 1):(3 * hub_gid)]
    hub_rmag = norm(hub_pos_r)
    shaft_dir = if hub_rmag > 0.1
        hub_pos_r ./ hub_rmag
    else
        [cos(p.elevation_angle), 0.0, sin(p.elevation_angle)]
    end
    perp1_shaft, perp2_shaft = shaft_perp_basis(shaft_dir)

    # Default tilted basis = shaft basis if not provided
    local pp1_tilt = perp1_tilt === nothing ? perp1_shaft : perp1_tilt
    local pp2_tilt = perp2_tilt === nothing ? perp2_shaft : perp2_tilt

    # ── Pre-allocated scratch buffers (reused across sub_segs, zero per-step allocs) ──
    pa    = zeros(3);  pb    = zeros(3);  diff  = zeros(3)
    dir_v = zeros(3);  F_vec = zeros(3);  mid   = zeros(3)
    v_mid = zeros(3);  drag  = zeros(3);  hdrag = zeros(3)
    r_a   = zeros(3);  r_b   = zeros(3)
    vrel_buf = zeros(3);  vperp_buf = zeros(3)
    # C1 (2026-08-14): per-segment shaft-torque (both ends) + tension
    # accumulators for the post-loop saturation clamp, and line-path strain
    # accumulators for rope break (segment index = 1..Nr-1).
    seg_tau_a = zeros(Nr)
    seg_tau_b = zeros(Nr)
    seg_tension = zeros(Nr)
    seg_pathlen = zeros(Nr)
    seg_restlen = zeros(Nr)

    for (si, ss) in enumerate(sys.sub_segs)
        is_bridle = ss.end_a.node_id == sys.bearing_id

        # ── positions (in-place) ──
        if ss.end_a.is_ring
            node_a_r = sys.nodes[ss.end_a.node_id]::RingNode
            ri_a_p = node_a_r.ring_idx
            R_a = isempty(sys.expansion_rotors) ? node_a_r.radius : sys.effective_radii[ri_a_p]
            ctr_a = @view u[(3 * (ss.end_a.node_id - 1) + 1):(3 * ss.end_a.node_id)]
            pp1_a, pp2_a = is_bridle ? (perp1_shaft, perp2_shaft) : (pp1_tilt, pp2_tilt)
            attachment_point!(pa, ctr_a, R_a, alpha[ri_a_p], ss.end_a.line_idx, p.n_lines, pp1_a, pp2_a)
        else
            pa_v = @view u[(3 * (ss.end_a.node_id - 1) + 1):(3 * ss.end_a.node_id)]
            pa[1]=pa_v[1]; pa[2]=pa_v[2]; pa[3]=pa_v[3]
        end
        if ss.end_b.is_ring
            node_b_r = sys.nodes[ss.end_b.node_id]::RingNode
            ri_b_p = node_b_r.ring_idx
            R_b = isempty(sys.expansion_rotors) ? node_b_r.radius : sys.effective_radii[ri_b_p]
            ctr_b = @view u[(3 * (ss.end_b.node_id - 1) + 1):(3 * ss.end_b.node_id)]
            pp1_b, pp2_b = is_bridle ? (perp1_shaft, perp2_shaft) : (pp1_tilt, pp2_tilt)
            attachment_point!(pb, ctr_b, R_b, alpha[ri_b_p], ss.end_b.line_idx, p.n_lines, pp1_b, pp2_b)
        else
            pb_v = @view u[(3 * (ss.end_b.node_id - 1) + 1):(3 * ss.end_b.node_id)]
            pb[1]=pb_v[1]; pb[2]=pb_v[2]; pb[3]=pb_v[3]
        end

        # ── velocities (views — no allocation) ──
        va = @view u[(3N + 3*(ss.end_a.node_id-1)+1):(3N + 3*ss.end_a.node_id)]
        vb = @view u[(3N + 3*(ss.end_b.node_id-1)+1):(3N + 3*ss.end_b.node_id)]

        # ── geometry (in-place) ──
        @inbounds for k in 1:3; diff[k] = pb[k] - pa[k]; end
        current_len = sqrt(diff[1]^2 + diff[2]^2 + diff[3]^2)
        current_len < 1e-9 && continue
        inv_len = 1.0 / current_len
        @inbounds for k in 1:3; dir_v[k] = diff[k] * inv_len; end

        # Break detection only during real operation (breaks_enabled latch set
        # by run_canonical_sim!); the settle's exploratory transients must not
        # break healthy machines.
        brk_flags = sys.breaks_enabled[] ? sys.broken_lines : nothing
        tension = get_subsegment_tension(ss, diff, current_len, dir_v, va, vb;
            rel_buf=vrel_buf, idx=si, broken=brk_flags)
        @inbounds for k in 1:3; F_vec[k] = tension * dir_v[k]; end

        # ── aerodynamic drag (in-place) ──
        @inbounds for k in 1:3
            mid[k]   = (pa[k] + pb[k]) * 0.5
            v_mid[k] = (va[k] + vb[k]) * 0.5
        end
        v_wind = wind_fn(mid, t)
        tether_drag_force!(drag, p.rho, TETHER_DRAG_CD, ss.diameter, ss.length_0,
                           v_wind, v_mid, dir_v, vrel_buf, vperp_buf)
        @inbounds for k in 1:3; hdrag[k] = 0.5 * drag[k]; end

        # ── accumulate forces to nodes (manual loops — no broadcast allocs) ──
        nid_a = ss.end_a.node_id
        nid_b = ss.end_b.node_id
        @inbounds for k in 1:3
            forces[nid_a][k] += hdrag[k]
            forces[nid_b][k] += hdrag[k]
        end

        # ── spring force + torque ──
        seg = sys.sub_seg_trpt_seg[si]
        if ss.end_a.is_ring
            ri_a = ri_a_p
            ctr_a_view = @view u[(3*(nid_a-1)+1):(3*nid_a)]
            @inbounds for k in 1:3
                r_a[k] = pa[k] - ctr_a_view[k]
                forces[nid_a][k] += F_vec[k]
            end
            tau_a = (r_a[1]*F_vec[2] - r_a[2]*F_vec[1])*shaft_dir[3] +
                    (r_a[2]*F_vec[3] - r_a[3]*F_vec[2])*shaft_dir[1] +
                    (r_a[3]*F_vec[1] - r_a[1]*F_vec[3])*shaft_dir[2]
            if seg > 0
                seg_tau_a[seg] += tau_a          # TRPT end — defer for C1 clamp
                seg_tension[seg] += tension
            else
                torques[ri_a] += tau_a           # non-TRPT ring (bridle) — direct
            end
        else
            @inbounds for k in 1:3; forces[nid_a][k] += F_vec[k]; end
        end

        if ss.end_b.is_ring
            ri_b = ri_b_p
            ctr_b_view = @view u[(3*(nid_b-1)+1):(3*nid_b)]
            @inbounds for k in 1:3
                r_b[k] = pb[k] - ctr_b_view[k]
                forces[nid_b][k] -= F_vec[k]
            end
            tau_b = (r_b[1]*(-F_vec[2]) - r_b[2]*(-F_vec[1]))*shaft_dir[3] +
                    (r_b[2]*(-F_vec[3]) - r_b[3]*(-F_vec[2]))*shaft_dir[1] +
                    (r_b[3]*(-F_vec[1]) - r_b[1]*(-F_vec[3]))*shaft_dir[2]
            if seg > 0
                seg_tau_b[seg] += tau_b
            else
                torques[ri_b] += tau_b
            end
        else
            @inbounds for k in 1:3; forces[nid_b][k] -= F_vec[k]; end
        end

        if seg > 0
            seg_pathlen[seg] += current_len
            seg_restlen[seg] += ss.length_0
        end
    end

    # ── C1: per-segment torque saturation (2026-08-14, Rod) ────────────────
    # The chain transmits at most its physical crossing-limit torque:
    # τ_sat = n_lines·T·r²·sin(δα*)/chord, δα* = 2·asin(L/√(2(L²+2r²))),
    # r = ½(r_a+r_b). Clamped with sign preserved — no reversal past δα*,
    # so a wound segment can never pump a ring (the freewheel ratchet dies).
    for s in 1:(Nr - 1)
        # Rope break at LINE level (2026-08-14, Rod — SK99 3.5%): the full
        # ring-to-ring path strain must not exceed ROPE_BREAK_STRAIN. Path
        # level (not per numerical sub-seg) so mid-node placement artifacts
        # cannot trip it. Detection only during real operation. Runs BEFORE
        # the torque-clamp continue so zero-torque segments still break.
        if sys.breaks_enabled[]
            line_strain = (seg_pathlen[s] - seg_restlen[s]) / max(seg_restlen[s], 1e-9)
            if line_strain > ROPE_BREAK_STRAIN
                for si2 in 1:length(sys.sub_segs)
                    sys.sub_seg_trpt_seg[si2] == s && (sys.broken_lines[si2] = true)
                end
                sys.any_broken[] = true
            end
        end

        ts_a = seg_tau_a[s]
        ts_b = seg_tau_b[s]
        (ts_a == 0.0 && ts_b == 0.0) && continue
        gid_a = sys.ring_ids[s]
        gid_b = sys.ring_ids[s+1]
        pos_a = @view u[(3*(gid_a-1)+1):(3*gid_a)]
        pos_b = @view u[(3*(gid_b-1)+1):(3*gid_b)]
        L_s = norm(pos_b - pos_a)
        r_ring_a = (sys.nodes[gid_a]::RingNode).radius
        r_ring_b = (sys.nodes[gid_b]::RingNode).radius
        r_s = 0.5 * (r_ring_a + r_ring_b)
        dastar = 2 * asin(min(L_s / sqrt(2 * (L_s^2 + 2 * r_s^2)), 1.0))
        chord = sqrt(L_s^2 + 2 * r_s^2 * (1 - cos(dastar)))
        T_s = seg_tension[s] / max(p.n_lines, 1)
        tau_sat = p.n_lines * max(T_s, 0.0) * r_s^2 * sin(dastar) / max(chord, 1e-9)
        # Action-reaction: the segment transmits ONE torque; ring s sees +τ,
        # ring s+1 sees −τ (Newton's third law on the shaft). The symmetric
        # average of the two end accumulations is the transmitted value
        # (they are equal-and-opposite up to numerical asymmetry).
        tau_tr = clamp(0.5 * (ts_a - ts_b), -tau_sat, tau_sat)
        torques[s] += tau_tr
        torques[s+1] -= tau_tr
    end
end

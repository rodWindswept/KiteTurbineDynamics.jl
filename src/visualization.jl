# src/visualization.jl
# GLMakie 3D visualization for KiteTurbineDynamics.jl.
# Renders rope node geometry, ring polygons, and a structural HUD.
# Usage:  fig = build_dashboard(sys, p, frames)
#         display(fig)

using GLMakie
using LinearAlgebra
using Printf

# ── Colour helper ───────────────────────────────────────────────────────────────

"""Map scalar `v` ∈ [0, v_max] to blue → red RGBf."""
function _force_color(v::Float64, v_max::Float64)
    t = v_max > 0.0 ? clamp(v / v_max, 0.0, 1.0) : 0.0
    return RGBf(t, 0.0, 1.0 - t)
end

# ── Rope line extractor ─────────────────────────────────────────────────────────

"""
    _rope_line_pts(u, sys, p, s, j, perp1, perp2) → (xs, ys, zs)

Five points for line j of segment s:
  attachment(lower_ring) → rope_sub_1 → rope_sub_2 → rope_sub_3 → attachment(upper_ring)
"""
function _rope_line_pts(u, sys, p, s, j, perp1, perp2)
    N  = sys.n_total

    ring_a_gid = sys.ring_ids[s]
    ring_b_gid = sys.ring_ids[s + 1]
    node_a = sys.nodes[ring_a_gid]::RingNode
    node_b = sys.nodes[ring_b_gid]::RingNode

    ctr_a  = u[3*(ring_a_gid-1)+1 : 3*ring_a_gid]
    ctr_b  = u[3*(ring_b_gid-1)+1 : 3*ring_b_gid]
    α_a    = u[6N + node_a.ring_idx]
    α_b    = u[6N + node_b.ring_idx]

    pa = attachment_point(ctr_a, node_a.radius, α_a, j, p.n_lines, perp1, perp2)
    pb = attachment_point(ctr_b, node_b.radius, α_b, j, p.n_lines, perp1, perp2)

    pts = Vector{Vector{Float64}}(undef, 5)
    pts[1] = pa
    for m in 1:3
        gid      = (s-1)*16 + 2 + (j-1)*3 + (m-1)
        pts[m+1] = u[3*(gid-1)+1 : 3*gid]
    end
    pts[5] = pb

    return [pt[1] for pt in pts],
           [pt[2] for pt in pts],
           [pt[3] for pt in pts]
end

# ── Middle sub-segment tension (rope→rope, avoids attachment-point ambiguity) ───

"""Tension in the middle (rope→rope) sub-segment of line j, segment s."""
function _mid_tension(u, sys, p, s, j)
    idx = (s-1) * p.n_lines * 4 + (j-1) * 4 + 2   # sub=2: rope_sub_1 → rope_sub_2
    idx > length(sys.sub_segs) && return 0.0
    ss     = sys.sub_segs[idx]
    pa_pos = u[3*(ss.end_a.node_id-1)+1 : 3*ss.end_a.node_id]
    pb_pos = u[3*(ss.end_b.node_id-1)+1 : 3*ss.end_b.node_id]
    len    = norm(pb_pos .- pa_pos)
    return max(0.0, ss.EA * (len - ss.length_0) / ss.length_0)
end

# ── Main dashboard builder ──────────────────────────────────────────────────────

"""
    build_dashboard(sys, p, frames) → Figure

Build a GLMakie interactive figure from a vector of ODE state snapshots.
Each element of `frames` is a `Vector{Float64}` of length `state_size(sys)`.

Controls: frame slider, play/pause button.
3D view: rope node geometry, ring polygons (blue→red = structural utilisation).
HUD: hub omega, estimated generator power, tether max tension, ring utilisation.
"""
function build_dashboard(sys    ::KiteTurbineSystem,
                          p      ::SystemParams,
                          frames ::Vector{<:AbstractVector})
    n_frames = length(frames)
    n_seg    = p.n_rings + 1
    N        = sys.n_total
    Nr       = sys.n_ring

    β         = p.elevation_angle
    shaft_dir = [cos(β), 0.0, sin(β)]
    perp1, perp2 = shaft_perp_basis(shaft_dir)

    # ── Observables ──────────────────────────────────────────────────────────
    time_obs = Observable(1)
    u_obs    = @lift frames[$time_obs]

    # ── Figure layout ─────────────────────────────────────────────────────────
    fig = Figure(size=(1600, 900))

    # ── 3D axes ───────────────────────────────────────────────────────────────
    ax3d = Axis3(fig[1, 1];
                 title  = "KiteTurbineDynamics — Rope Node Geometry",
                 xlabel = "X downwind (m)", ylabel = "Y crosswind (m)",
                 zlabel = "Altitude (m)", aspect=:data)

    # Ground plane grid
    for x in -10:5:30
        lines!(ax3d, [float(x), float(x)], [-10.0, 10.0], [0.0, 0.0];
               color=(:grey, 0.2), linewidth=0.5)
    end
    for y in -10:5:10
        lines!(ax3d, [-10.0, 30.0], [float(y), float(y)], [0.0, 0.0];
               color=(:grey, 0.2), linewidth=0.5)
    end
    scatter!(ax3d, [0.0], [0.0], [0.0]; color=:green, markersize=20)

    # Tether lines — tension-coloured using middle sub-segment (rope→rope)
    for s in 1:n_seg
        for j in 1:p.n_lines
            line_obs  = @lift _rope_line_pts($u_obs, sys, p, s, j, perp1, perp2)
            color_obs = @lift _force_color(
                _mid_tension($u_obs, sys, p, s, j), TETHER_SWL)
            lines!(ax3d,
                   @lift($line_obs[1]),
                   @lift($line_obs[2]),
                   @lift($line_obs[3]);
                   color=color_obs, linewidth=1.5)
        end
    end

    # Ring polygons — coloured by structural utilisation (blue→red)
    for k in 2:(Nr-1)    # skip ground (k=1) and hub (k=Nr)
        ring_gid = sys.ring_ids[k]
        node_k   = sys.nodes[ring_gid]::RingNode
        R_k      = node_k.radius
        ri_k     = node_k.ring_idx

        ring_obs = @lift begin
            u   = $u_obs
            ctr = u[3*(ring_gid-1)+1 : 3*ring_gid]
            α   = u[6N + ri_k]
            jj  = [1:p.n_lines; 1]
            pts = [attachment_point(ctr, R_k, α, jj[i], p.n_lines, perp1, perp2)
                   for i in eachindex(jj)]
            ([pt[1] for pt in pts],
             [pt[2] for pt in pts],
             [pt[3] for pt in pts])
        end

        ring_color_obs = @lift begin
            u     = $u_obs
            alpha = u[6N+1 : 6N+Nr]
            sf    = ring_safety_frame(u, alpha, sys, p)
            row   = findfirst(r -> r.ring_id == k-1, sf)
            util  = isnothing(row) ? 0.0 : sf[row].utilisation
            _force_color(util, 1.0)
        end

        lines!(ax3d, @lift($ring_obs[1]), @lift($ring_obs[2]), @lift($ring_obs[3]);
               color=ring_color_obs, linewidth=1.5)
    end

    # Hub ring — firebrick landmark
    hub_gid  = sys.ring_ids[Nr]
    hub_node = sys.nodes[hub_gid]::RingNode
    hub_R    = hub_node.radius
    hub_ri   = hub_node.ring_idx

    hub_ring_obs = @lift begin
        u   = $u_obs
        ctr = u[3*(hub_gid-1)+1 : 3*hub_gid]
        α   = u[6N + hub_ri]
        jj  = [1:p.n_lines; 1]
        pts = [attachment_point(ctr, hub_R, α, jj[i], p.n_lines, perp1, perp2)
               for i in eachindex(jj)]
        ([pt[1] for pt in pts], [pt[2] for pt in pts], [pt[3] for pt in pts])
    end
    lines!(ax3d,
           @lift($hub_ring_obs[1]), @lift($hub_ring_obs[2]), @lift($hub_ring_obs[3]);
           color=:firebrick, linewidth=3.5)

    # ── HUD ───────────────────────────────────────────────────────────────────
    right = GridLayout(fig[1, 2])
    colsize!(fig.layout, 2, Fixed(320))
    row_n = Ref(0)
    next_row!() = (row_n[] += 1; row_n[])

    lbl(txt; kw...) = Label(right[next_row!(), 1], txt;
                             halign=:left, tellwidth=false, justification=:left, kw...)

    lbl("KiteTurbineDynamics"; fontsize=16, font=:bold)
    time_lbl   = lbl("Frame  1 / $(n_frames)")
    omega_lbl  = lbl("Hub ω =  0.000 rad/s  (  0.0 rpm)")
    gen_lbl    = lbl("Gen power  P =  0.00 kW")
    lbl("")   # spacer
    lbl("Structural Loads"; fontsize=13, font=:bold)
    tether_lbl = lbl("Tether max:     0 N  ·  FoS  ∞")
    ring_lbl   = lbl("Ring util max:  0.0%")
    warn_lbl   = lbl(""; color=:red)

    on(time_obs) do fi
        u = frames[fi]

        omega_hub = u[6N + Nr + Nr]
        rpm       = omega_hub * 60.0 / (2π)
        omega_gnd = u[6N + 2]   # omega[ring_idx=2] = ground ring (ring_idx=1 is twist, not driven)
        tau_gen   = p.k_mppt * omega_gnd^2
        P_gen_kw  = tau_gen * abs(omega_gnd) / 1000.0

        time_lbl.text[]  = @sprintf("Frame %d / %d", fi, n_frames)
        omega_lbl.text[] = @sprintf("Hub ω = %7.3f rad/s  (%6.1f rpm)", omega_hub, rpm)
        gen_lbl.text[]   = @sprintf("Gen power  P = %5.2f kW", P_gen_kw)

        T_max = 0.0
        for s in 1:n_seg, j in 1:p.n_lines
            T_max = max(T_max, _mid_tension(u, sys, p, s, j))
        end
        fos_t = T_max > 0.0 ? TETHER_SWL / T_max : Inf

        alpha_vec = u[6N+1 : 6N+Nr]
        sf        = ring_safety_frame(u, alpha_vec, sys, p)
        max_util  = isempty(sf) ? 0.0 : maximum(r.utilisation for r in sf)

        tether_lbl.text[] = @sprintf("Tether max: %5.0f N  ·  FoS %s",
                                      T_max,
                                      isinf(fos_t) ? "  ∞" : @sprintf("%.1f", fos_t))
        ring_lbl.text[]   = @sprintf("Ring util max: %4.1f%%", max_util * 100.0)
        warn_lbl.text[]   = max_util > 0.8 ? "!! BUCKLING RISK" : ""
    end

    # ── Frame slider + play ────────────────────────────────────────────────────
    next_row!()  # spacer
    Label(right[next_row!(), 1], "Frame"; halign=:left)
    time_slider = Slider(right[next_row!(), 1]; range=1:n_frames, startvalue=1)
    connect!(time_obs, time_slider.value)

    play_btn   = Button(right[next_row!(), 1]; label="▶ Play")
    is_playing = Observable(false)
    on(play_btn.clicks) do _
        is_playing[] = !is_playing[]
        play_btn.label[] = is_playing[] ? "|| Pause" : "▶ Play"
    end
    @async while true
        if is_playing[]
            nf = min(time_slider.value[] + 1, n_frames)
            set_close_to!(time_slider, nf)
            nf == n_frames && (is_playing[] = false; play_btn.label[] = "▶ Play")
        end
        sleep(1 / 30)
    end

    notify(time_obs)
    return fig
end

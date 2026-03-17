# src/visualization.jl
# GLMakie 3D visualization for KiteTurbineDynamics.jl.
# Usage:  fig = build_dashboard(sys, p, frames; times=t_vec)
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

# ── Geometry helpers ────────────────────────────────────────────────────────────

"""Five points for line j of segment s (attachment → 3 rope nodes → attachment)."""
function _rope_line_pts(u, sys, p, s, j, perp1, perp2)
    N      = sys.n_total
    gid_a  = sys.ring_ids[s]
    gid_b  = sys.ring_ids[s + 1]
    na     = sys.nodes[gid_a]::RingNode
    nb     = sys.nodes[gid_b]::RingNode
    ctr_a  = u[3*(gid_a-1)+1 : 3*gid_a]
    ctr_b  = u[3*(gid_b-1)+1 : 3*gid_b]
    α_a    = u[6N + na.ring_idx]
    α_b    = u[6N + nb.ring_idx]
    pa     = attachment_point(ctr_a, na.radius, α_a, j, p.n_lines, perp1, perp2)
    pb     = attachment_point(ctr_b, nb.radius, α_b, j, p.n_lines, perp1, perp2)
    pts    = Vector{Vector{Float64}}(undef, 5)
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

"""Tension of the middle (rope→rope) sub-segment for line j, segment s."""
function _mid_tension(u, sys, p, s, j)
    idx    = (s-1) * p.n_lines * 4 + (j-1) * 4 + 2
    idx > length(sys.sub_segs) && return 0.0
    ss     = sys.sub_segs[idx]
    pa     = u[3*(ss.end_a.node_id-1)+1 : 3*ss.end_a.node_id]
    pb     = u[3*(ss.end_b.node_id-1)+1 : 3*ss.end_b.node_id]
    len    = norm(pb .- pa)
    return max(0.0, ss.EA * (len - ss.length_0) / ss.length_0)
end

"""Max tension across all tether sub-segments (middle sub-segs only, for speed)."""
function _tether_max(u, sys, p)
    T = 0.0
    for s in 1:p.n_rings+1, j in 1:p.n_lines
        T = max(T, _mid_tension(u, sys, p, s, j))
    end
    return T
end

"""Count slack sub-segments (negative strain = torsional collapse indicator)."""
function _n_slack(u, sys)
    n = 0
    for ss in sys.sub_segs
        pa  = u[3*(ss.end_a.node_id-1)+1 : 3*ss.end_a.node_id]
        pb  = u[3*(ss.end_b.node_id-1)+1 : 3*ss.end_b.node_id]
        (norm(pb .- pa) - ss.length_0) / ss.length_0 < -0.01 && (n += 1)
    end
    return n
end

# ── Main dashboard builder ──────────────────────────────────────────────────────

"""
    build_dashboard(sys, p, frames; times=nothing) → Figure

Build a GLMakie interactive figure from a vector of ODE state snapshots.
`times` is an optional `Vector{Float64}` of simulated times in seconds.

3D view: rope sag, ring polygons (blue→red = buckling utilisation),
         rotor blades, lift lines to kite position.
HUD: live telemetry, structural loads, run-wide peaks.
Controls: frame slider + play/pause.
"""
function build_dashboard(sys    ::KiteTurbineSystem,
                          p      ::SystemParams,
                          frames ::Vector{<:AbstractVector};
                          times  ::Union{Vector{Float64}, Nothing} = nothing)
    n_frames = length(frames)
    n_seg    = p.n_rings + 1
    N        = sys.n_total
    Nr       = sys.n_ring

    β         = p.elevation_angle
    shaft_dir = [cos(β), 0.0, sin(β)]
    perp1, perp2 = shaft_perp_basis(shaft_dir)

    l_seg           = p.tether_length / n_seg
    bearing_offset  = 1.5 * l_seg     # above hub along shaft
    lift_offset     = 1.0             # further above bearing

    hub_gid  = sys.ring_ids[Nr]
    hub_node = sys.nodes[hub_gid]::RingNode
    hub_R    = hub_node.radius
    hub_ri   = hub_node.ring_idx

    # ── Pre-compute run-wide peaks ────────────────────────────────────────────
    T_peak     = 0.0
    omega_peak = 0.0
    P_peak     = 0.0
    for u_f in frames
        T_peak     = max(T_peak,     _tether_max(u_f, sys, p))
        omega_hub  = abs(u_f[6N + Nr + Nr])
        omega_gnd  = abs(u_f[6N + Nr + 1])
        tau_gen    = p.k_mppt * omega_gnd^2
        omega_peak = max(omega_peak, omega_hub)
        P_peak     = max(P_peak,     tau_gen * omega_gnd / 1000.0)
    end

    # ── Observables ──────────────────────────────────────────────────────────
    time_obs = Observable(1)
    u_obs    = @lift frames[$time_obs]

    # ── Figure ────────────────────────────────────────────────────────────────
    fig = Figure(size=(1600, 950))

    # ── 3D axes ───────────────────────────────────────────────────────────────
    ax3d = Axis3(fig[1, 1];
                 title  = "KiteTurbineDynamics — TRPT Kite Turbine",
                 xlabel = "X (m)", ylabel = "Y (m)", zlabel = "Z (m)",
                 aspect = :data)

    for x in -10:5:35
        lines!(ax3d, [float(x), float(x)], [-12.0, 12.0], [0.0, 0.0];
               color=(:grey, 0.15), linewidth=0.5)
    end
    for y in -10:5:10
        lines!(ax3d, [-10.0, 35.0], [float(y), float(y)], [0.0, 0.0];
               color=(:grey, 0.15), linewidth=0.5)
    end
    scatter!(ax3d, [0.0], [0.0], [0.0]; color=:limegreen, markersize=22)

    # Tether lines — tension-coloured
    for s in 1:n_seg, j in 1:p.n_lines
        lo = @lift _rope_line_pts($u_obs, sys, p, s, j, perp1, perp2)
        co = @lift _force_color(_mid_tension($u_obs, sys, p, s, j), TETHER_SWL)
        lines!(ax3d, @lift($lo[1]), @lift($lo[2]), @lift($lo[3]);
               color=co, linewidth=1.5)
    end

    # Ring polygons — utilisation-coloured (skip ground k=1 and hub k=Nr)
    for k in 2:(Nr-1)
        gid_k = sys.ring_ids[k]
        nk    = sys.nodes[gid_k]::RingNode
        R_k   = nk.radius
        ri_k  = nk.ring_idx

        ro = @lift begin
            u   = $u_obs
            ctr = u[3*(gid_k-1)+1 : 3*gid_k]
            α   = u[6N + ri_k]
            jj  = [1:p.n_lines; 1]
            pts = [attachment_point(ctr, R_k, α, jj[i], p.n_lines, perp1, perp2)
                   for i in eachindex(jj)]
            ([pt[1] for pt in pts], [pt[2] for pt in pts], [pt[3] for pt in pts])
        end
        rc = @lift begin
            u     = $u_obs
            alpha = u[6N+1 : 6N+Nr]
            sf    = ring_safety_frame(u, alpha, sys, p)
            row   = findfirst(r -> r.ring_id == k-1, sf)
            util  = isnothing(row) ? 0.0 : sf[row].utilisation
            _force_color(util, 1.0)
        end
        lines!(ax3d, @lift($ro[1]), @lift($ro[2]), @lift($ro[3]);
               color=rc, linewidth=1.5)
    end

    # Hub ring — firebrick
    hub_ring_obs = @lift begin
        u   = $u_obs
        ctr = u[3*(hub_gid-1)+1 : 3*hub_gid]
        α   = u[6N + hub_ri]
        jj  = [1:p.n_lines; 1]
        pts = [attachment_point(ctr, hub_R, α, jj[i], p.n_lines, perp1, perp2)
               for i in eachindex(jj)]
        ([pt[1] for pt in pts], [pt[2] for pt in pts], [pt[3] for pt in pts])
    end
    lines!(ax3d, @lift($hub_ring_obs[1]), @lift($hub_ring_obs[2]), @lift($hub_ring_obs[3]);
           color=:firebrick, linewidth=3.5)

    # Rotor blades — steelblue lines from hub centre to blade tip
    for b in 1:p.n_blades
        blade_obs = @lift begin
            u   = $u_obs
            ctr = u[3*(hub_gid-1)+1 : 3*hub_gid]
            α   = u[6N + hub_ri]
            φ   = α + (b-1) * (2π / p.n_blades)
            tip = ctr .+ sys.rotor.radius .* (cos(φ) .* perp1 .+ sin(φ) .* perp2)
            ([ctr[1], tip[1]], [ctr[2], tip[2]], [ctr[3], tip[3]])
        end
        lines!(ax3d, @lift($blade_obs[1]), @lift($blade_obs[2]), @lift($blade_obs[3]);
               color=:steelblue, linewidth=3.0)
    end

    # Lifter kite system — gold lines from hub attachment points → bearing → lift point
    bearing_obs   = @lift $u_obs[3*(hub_gid-1)+1 : 3*hub_gid] .+ bearing_offset .* shaft_dir
    lift_point_obs = @lift $bearing_obs .+ lift_offset .* shaft_dir

    for j in 1:p.n_lines
        line_to_bearing = @lift begin
            u    = $u_obs
            ctr  = u[3*(hub_gid-1)+1 : 3*hub_gid]
            α    = u[6N + hub_ri]
            node = attachment_point(ctr, hub_R, α, j, p.n_lines, perp1, perp2)
            bp   = $bearing_obs
            ([node[1], bp[1]], [node[2], bp[2]], [node[3], bp[3]])
        end
        lines!(ax3d,
               @lift($line_to_bearing[1]),
               @lift($line_to_bearing[2]),
               @lift($line_to_bearing[3]);
               color=:gold, linewidth=1.5)
    end

    bearing_to_lift = @lift begin
        bp = $bearing_obs; lp = $lift_point_obs
        ([bp[1], lp[1]], [bp[2], lp[2]], [bp[3], lp[3]])
    end
    lines!(ax3d,
           @lift($bearing_to_lift[1]),
           @lift($bearing_to_lift[2]),
           @lift($bearing_to_lift[3]);
           color=:gold, linewidth=3.0)

    scatter!(ax3d, @lift([$bearing_obs[1]]),   @lift([$bearing_obs[2]]),
                   @lift([$bearing_obs[3]]);    color=:gold, markersize=10)
    scatter!(ax3d, @lift([$lift_point_obs[1]]), @lift([$lift_point_obs[2]]),
                   @lift([$lift_point_obs[3]]); color=:white, markersize=12,
                   marker=:diamond)

    # ── HUD ───────────────────────────────────────────────────────────────────
    right = GridLayout(fig[1, 2])
    colsize!(fig.layout, 2, Fixed(340))
    r = Ref(0)
    nr!() = (r[] += 1; r[])

    lbl(txt; kw...) = Label(right[nr!(), 1], txt;
                             halign=:left, tellwidth=false, justification=:left, kw...)

    fos_str(v) = (isinf(v) || isnan(v) || v > 999) ? "  ∞" : @sprintf("%5.1f", v)

    # Live telemetry
    lbl("Live Telemetry"; fontsize=15, font=:bold)
    t_lbl      = lbl(isnothing(times) ? "Frame  1 / $(n_frames)" :
                                        @sprintf("t =  0.00 s  (frame  1 / %d)", n_frames))
    omega_lbl  = lbl("Hub ω =  0.000 rad/s  (  0.0 rpm)")
    power_lbl  = lbl("Gen power  P =  0.00 kW")
    twist_lbl  = lbl("Shaft twist / section  α =  0.0°")
    margin_lbl = lbl("Collapse margin:  100.0%")
    wind_lbl   = lbl(@sprintf("Wind ref  V = %5.2f m/s", p.v_wind_ref))
    elev_lbl   = lbl(@sprintf("Elevation  β = %5.1f°", rad2deg(p.elevation_angle)))

    # Structural loads
    lbl("")
    lbl("Structural Loads (this frame)"; fontsize=14, font=:bold)
    lbl("Tether tension  (SWL = $(Int(TETHER_SWL)) N)"; fontsize=11, color=:steelblue)
    t_frame_lbl = lbl("    max     0 N  ·  FoS  ∞")
    lbl("Ring compression  (SWL = $(Int(RING_SWL)) N)"; fontsize=11, color=:firebrick)
    c_frame_lbl = lbl("    max util   0.0%  ·  FoS  ∞")
    warn_lbl    = lbl(""; color=:red, fontsize=12, font=:bold)

    # Run peaks
    lbl("")
    lbl("Run peaks (all frames)"; fontsize=14, font=:bold)
    tp_lbl  = lbl(@sprintf("T_peak  %5.0f N  ·  FoS %s",
                             T_peak, fos_str(T_peak > 0 ? TETHER_SWL / T_peak : Inf)))
    pp_lbl  = lbl(@sprintf("P_peak  %6.2f kW", P_peak))
    op_lbl  = lbl(@sprintf("ω_peak  %7.3f rad/s  (%6.1f rpm)",
                             omega_peak, omega_peak * 60 / (2π)))

    on(time_obs) do fi
        u = frames[fi]

        # Telemetry
        omega_hub = u[6N + Nr + Nr]          # omega[ring_idx=Nr]
        omega_gnd = u[6N + Nr + 1]           # omega[ring_idx=1]  (MPPT generator)
        rpm       = omega_hub * 60.0 / (2π)
        tau_gen   = p.k_mppt * omega_gnd^2
        P_kw      = tau_gen * abs(omega_gnd) / 1000.0

        total_twist    = abs(u[6N + Nr] - u[6N + 1])   # alpha[Nr] - alpha[1]
        twist_per_sec  = total_twist / n_seg
        margin         = max(0.0, (1.0 - twist_per_sec / π) * 100.0)

        if isnothing(times)
            t_lbl.text[] = @sprintf("Frame %d / %d", fi, n_frames)
        else
            t_lbl.text[] = @sprintf("t = %6.2f s  (frame %d / %d)",
                                     times[fi], fi, n_frames)
        end
        omega_lbl.text[]  = @sprintf("Hub ω = %7.3f rad/s  (%6.1f rpm)", omega_hub, rpm)
        power_lbl.text[]  = @sprintf("Gen power  P = %5.2f kW", P_kw)
        twist_lbl.text[]  = @sprintf("Shaft twist / section  α = %5.1f°",
                                      rad2deg(twist_per_sec))
        margin_lbl.text[] = @sprintf("Collapse margin: %5.1f%%", margin)

        # Structural this frame
        T_max    = _tether_max(u, sys, p)
        fos_t    = T_max > 0.0 ? TETHER_SWL / T_max : Inf
        alpha_v  = u[6N+1 : 6N+Nr]
        sf       = ring_safety_frame(u, alpha_v, sys, p)
        max_util = isempty(sf) ? 0.0 : maximum(r.utilisation for r in sf)
        fos_r    = max_util > 0.0 ? 1.0 / max_util : Inf
        n_slack  = _n_slack(u, sys)

        t_frame_lbl.text[] = @sprintf("    max %5.0f N  ·  FoS %s",
                                        T_max, fos_str(fos_t))
        c_frame_lbl.text[] = @sprintf("    max util %4.1f%%  ·  FoS %s",
                                        max_util * 100.0, fos_str(fos_r))

        warnings = String[]
        max_util > 0.8    && push!(warnings, "!! BUCKLING RISK")
        n_slack  > 0      && push!(warnings, "!! TORSIONAL COLLAPSE ($(n_slack) slack)")
        warn_lbl.text[]   = join(warnings, "  ")
    end

    # ── Controls ──────────────────────────────────────────────────────────────
    lbl("")
    lbl("Playback"; fontsize=13, font=:bold)
    if !isnothing(times)
        t_range = @sprintf("%.2f – %.2f s", times[1], times[end])
        lbl(t_range; fontsize=10, color=:grey60)
    end
    time_slider = Slider(right[nr!(), 1]; range=1:n_frames, startvalue=1)
    connect!(time_obs, time_slider.value)

    play_btn   = Button(right[nr!(), 1]; label="▶ Play")
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

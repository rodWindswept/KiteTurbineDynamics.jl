# src/visualization.jl
# GLMakie 3D visualization for KiteTurbineDynamics.jl.
# Usage:  fig = build_dashboard(sys, p, frames; times=t_vec)
#         display(fig)

using GLMakie
using LinearAlgebra
using Printf

# ── Colour helpers ───────────────────────────────────────────────────────────────

"""4-stop tension colour ramp: blue → green → orange → red. Grey when slack (T < 5 N)."""
function _tension_color(T::Float64, swl::Float64)
    T < 5.0 && return RGBf(0.6f0, 0.6f0, 0.6f0)
    t = clamp(T / swl, 0.0, 1.0)
    if t <= 0.5
        s = Float32(t / 0.5)
        return RGBf(0.0f0, 0.2f0 + 0.6f0 * s, 1.0f0 - 0.8f0 * s)    # blue → green
    elseif t <= 0.8
        s = Float32((t - 0.5) / 0.3)
        return RGBf(s, 0.8f0 - 0.3f0 * s, 0.2f0 - 0.2f0 * s)         # green → orange
    else
        s = Float32((t - 0.8) / 0.2)
        return RGBf(1.0f0, 0.5f0 - 0.5f0 * s, 0.0f0)                  # orange → red
    end
end

"""Ring hoop-compression colour: blue → cyan → orange → red."""
function _ring_util_color(util::Float64)
    t = clamp(util, 0.0, 1.0)
    if t <= 0.5
        s = Float32(t / 0.5)
        return RGBf(0.0f0, s, 1.0f0)                                   # blue → cyan
    elseif t <= 0.8
        s = Float32((t - 0.5) / 0.3)
        return RGBf(s, 1.0f0 - 0.7f0 * s, 1.0f0 - s)                  # cyan → orange
    else
        s = Float32((t - 0.8) / 0.2)
        return RGBf(1.0f0, 0.3f0 - 0.3f0 * s, 0.0f0)                  # orange → red
    end
end

# ── Geometry helpers ─────────────────────────────────────────────────────────────

"""Five-point polyline for tether line j of segment s: attach_A, 3 rope nodes, attach_B."""
function _rope_line_pts(u, sys, p, s, j, perp1, perp2)
    N     = sys.n_total
    gid_a = sys.ring_ids[s]
    gid_b = sys.ring_ids[s + 1]
    na    = sys.nodes[gid_a]::RingNode
    nb    = sys.nodes[gid_b]::RingNode
    ctr_a = u[3*(gid_a-1)+1 : 3*gid_a]
    ctr_b = u[3*(gid_b-1)+1 : 3*gid_b]
    α_a   = u[6N + na.ring_idx]
    α_b   = u[6N + nb.ring_idx]
    pa    = attachment_point(ctr_a, na.radius, α_a, j, p.n_lines, perp1, perp2)
    pb    = attachment_point(ctr_b, nb.radius, α_b, j, p.n_lines, perp1, perp2)
    pts   = Vector{Vector{Float64}}(undef, 5)
    pts[1] = pa
    for m in 1:3
        gid      = (s-1)*16 + 2 + (j-1)*3 + (m-1)
        pts[m+1] = u[3*(gid-1)+1 : 3*gid]
    end
    pts[5] = pb
    ([pt[1] for pt in pts], [pt[2] for pt in pts], [pt[3] for pt in pts])
end

"""Tension of the middle (rope→rope) sub-segment for tether line j of segment s."""
function _mid_tension(u, sys, p, s, j)
    idx = (s-1) * p.n_lines * 4 + (j-1) * 4 + 2
    idx > length(sys.sub_segs) && return 0.0
    ss  = sys.sub_segs[idx]
    pa  = u[3*(ss.end_a.node_id-1)+1 : 3*ss.end_a.node_id]
    pb  = u[3*(ss.end_b.node_id-1)+1 : 3*ss.end_b.node_id]
    max(0.0, ss.EA * (norm(pb .- pa) - ss.length_0) / ss.length_0)
end

"""Maximum tether tension across all 75 lines (5 lines × 15 segments)."""
function _tether_max(u, sys, p)
    T = 0.0
    for s in 1:p.n_rings+1, j in 1:p.n_lines
        T = max(T, _mid_tension(u, sys, p, s, j))
    end
    T
end

"""Count slack tether lines (T < 5 N)."""
function _n_slack_lines(u, sys, p)
    n = 0
    for s in 1:p.n_rings+1, j in 1:p.n_lines
        _mid_tension(u, sys, p, s, j) < 5.0 && (n += 1)
    end
    n
end

"""Mid-rope sag (mm) for segment s, line 1: distance from m=2 rope node to chord."""
function _seg_sag_mm(u, sys, p, s, perp1, perp2)
    N     = sys.n_total
    gid_a = sys.ring_ids[s]
    gid_b = sys.ring_ids[s + 1]
    na    = sys.nodes[gid_a]::RingNode
    nb    = sys.nodes[gid_b]::RingNode
    ctr_a = u[3*(gid_a-1)+1 : 3*gid_a]
    ctr_b = u[3*(gid_b-1)+1 : 3*gid_b]
    pa    = attachment_point(ctr_a, na.radius, u[6N + na.ring_idx],
                             1, p.n_lines, perp1, perp2)
    pb    = attachment_point(ctr_b, nb.radius, u[6N + nb.ring_idx],
                             1, p.n_lines, perp1, perp2)
    # m=2 interior rope node for j=1: gid = (s-1)*16 + 2 + 0*3 + 1
    gid_mid = (s-1)*16 + 3
    pm    = u[3*(gid_mid-1)+1 : 3*gid_mid]
    AB    = pb .- pa
    len2  = dot(AB, AB)
    len2 < 1e-18 && return 0.0
    foot  = pa .+ (dot(pm .- pa, AB) / len2) .* AB
    norm(pm .- foot) * 1000.0   # m → mm
end

# ── Dashboard builder ────────────────────────────────────────────────────────────

"""
    build_dashboard(sys, p, frames; times, u_settled, wind_fn) → Figure

Build a GLMakie interactive dashboard from a vector of ODE state snapshots.

- `times`     : optional `Vector{Float64}` of simulated times (s)
- `u_settled` : optional settled initial state — enables scenario re-run buttons
- `wind_fn`   : optional wind closure used during settle/simulate for re-runs

3-column dark-theme layout: Controls (left) | 3D viewport (centre) | HUD (right).
"""
function build_dashboard(sys       ::KiteTurbineSystem,
                          p         ::SystemParams,
                          frames    ::Vector{<:AbstractVector};
                          times     ::Union{Vector{Float64}, Nothing}   = nothing,
                          u_settled ::Union{Vector{Float64}, Nothing}   = nothing,
                          wind_fn   ::Union{Function, Nothing}          = nothing)

    n_frames = length(frames)
    n_seg    = p.n_rings + 1
    N        = sys.n_total
    Nr       = sys.n_ring

    β         = p.elevation_angle
    shaft_dir = [cos(β), 0.0, sin(β)]
    perp1, perp2 = shaft_perp_basis(shaft_dir)

    l_seg          = p.tether_length / n_seg
    bearing_offset = 1.5 * l_seg
    lift_offset    = 1.0

    hub_gid  = sys.ring_ids[Nr]
    hub_node = sys.nodes[hub_gid]::RingNode
    hub_R    = hub_node.radius
    hub_ri   = hub_node.ring_idx

    # Tension / ring colourmap for colorbars
    tension_cmap = cgrad([RGBf(0.0, 0.2, 1.0), RGBf(0.0, 0.8, 0.2),
                          RGBf(1.0, 0.5, 0.0), RGBf(1.0, 0.0, 0.0)],
                          [0.0, 0.5, 0.8, 1.0])
    ring_cmap    = cgrad([RGBf(0.0, 0.0, 1.0), RGBf(0.0, 1.0, 1.0),
                          RGBf(1.0, 0.5, 0.0), RGBf(1.0, 0.0, 0.0)],
                          [0.0, 0.5, 0.8, 1.0])

    # ── Pre-compute run-wide peaks ────────────────────────────────────────────
    T_peak     = 0.0
    omega_peak = 0.0
    P_peak     = 0.0
    V_peak     = 0.0
    slack_events = 0
    for u_f in frames
        T_f       = _tether_max(u_f, sys, p)
        T_peak    = max(T_peak, T_f)
        omega_hub = abs(u_f[6N + Nr + Nr])
        omega_gnd = abs(u_f[6N + Nr + 1])
        P_kw      = p.k_mppt * omega_gnd^2 * omega_gnd / 1000.0
        omega_peak = max(omega_peak, omega_hub)
        P_peak     = max(P_peak, P_kw)
        hub_ctr    = u_f[3*(hub_gid-1)+1 : 3*hub_gid]
        z_hub      = max(hub_ctr[3], 1.0)
        V_hub      = p.v_wind_ref * (z_hub / p.h_ref)^(1.0/7.0)
        V_peak     = max(V_peak, V_hub)
        _n_slack_lines(u_f, sys, p) > 0 && (slack_events += 1)
    end

    # ── Observables ───────────────────────────────────────────────────────────
    frame_obs = Observable(1)
    u_obs     = @lift frames[$frame_obs]

    # Frames reference for re-run (wrapped so we can swap)
    frames_ref = Ref(frames)

    # ── Figure — dark theme, 3 columns ───────────────────────────────────────
    set_theme!(theme_dark())
    fig = Figure(size=(1600, 950))
    colsize!(fig.layout, 1, Fixed(280))   # Controls
    colsize!(fig.layout, 3, Fixed(340))   # HUD

    # ── 3D Axis (centre column) ───────────────────────────────────────────────
    ax3d = Axis3(fig[1, 2];
                 title   = "KiteTurbineDynamics — TRPT Kite Turbine",
                 xlabel  = "Downwind X [m]",
                 ylabel  = "Crosswind Y [m]",
                 zlabel  = "Altitude Z [m]",
                 aspect  = :data,
                 titlesize = 13)

    # Ground plane grid (x: -20→60, y: -25→25, 5 m steps)
    for x in -20:5:60
        lines!(ax3d, [float(x), float(x)], [-25.0, 25.0], [0.0, 0.0];
               color=(:grey, 0.3), linewidth=0.5)
    end
    for y in -25:5:25
        lines!(ax3d, [-20.0, 60.0], [float(y), float(y)], [0.0, 0.0];
               color=(:grey, 0.3), linewidth=0.5)
    end

    # Ground anchor
    scatter!(ax3d, [0.0], [0.0], [0.0]; color=:limegreen, markersize=20)

    # Tether lines — 4-stop tension colour; slack lines drawn grey
    for s in 1:n_seg, j in 1:p.n_lines
        lo = @lift _rope_line_pts($u_obs, sys, p, s, j, perp1, perp2)
        T_ob = @lift _mid_tension($u_obs, sys, p, s, j)
        co   = @lift _tension_color($T_ob, TETHER_SWL)
        lw   = @lift ($T_ob < 5.0 ? 0.8f0 : 1.5f0)
        lines!(ax3d, @lift($lo[1]), @lift($lo[2]), @lift($lo[3]);
               color=co, linewidth=lw)
    end

    # Intermediate ring polygons — hoop-compression utilisation colour
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
            u    = $u_obs
            αvec = u[6N+1 : 6N+Nr]
            sf   = ring_safety_frame(u, αvec, sys, p)
            row  = findfirst(r -> r.ring_id == k-1, sf)
            util = isnothing(row) ? 0.0 : sf[row].utilisation
            _ring_util_color(util)
        end
        lines!(ax3d, @lift($ro[1]), @lift($ro[2]), @lift($ro[3]);
               color=rc, linewidth=1.5)
    end

    # Hub (rotor) ring — firebrick, thicker
    hub_ring_obs = @lift begin
        u   = $u_obs
        ctr = u[3*(hub_gid-1)+1 : 3*hub_gid]
        α   = u[6N + hub_ri]
        jj  = [1:p.n_lines; 1]
        pts = [attachment_point(ctr, hub_R, α, jj[i], p.n_lines, perp1, perp2)
               for i in eachindex(jj)]
        ([pt[1] for pt in pts], [pt[2] for pt in pts], [pt[3] for pt in pts])
    end
    lines!(ax3d, @lift($hub_ring_obs[1]), @lift($hub_ring_obs[2]),
                 @lift($hub_ring_obs[3]); color=:firebrick, linewidth=3.5)

    # Rotor blades — quad outline (inner root at 0.3×R inboard, outer tip at R)
    r_inner = hub_R   # inner radius = hub radius (tether attachment circle)
    r_outer = sys.rotor.radius
    chord   = r_outer * 0.15
    for b in 1:p.n_blades
        blade_obs = @lift begin
            u    = $u_obs
            ctr  = u[3*(hub_gid-1)+1 : 3*hub_gid]
            α    = u[6N + hub_ri]
            φ    = α + (b-1) * (2π / p.n_blades)
            # Radial direction and chord direction
            r_dir = cos(φ) .* perp1 .+ sin(φ) .* perp2
            c_dir = -sin(φ) .* perp1 .+ cos(φ) .* perp2
            hc    = chord / 2.0
            p1 = ctr .+ r_inner .* r_dir .- hc .* c_dir
            p2 = ctr .+ r_outer .* r_dir .- hc .* c_dir
            p3 = ctr .+ r_outer .* r_dir .+ hc .* c_dir
            p4 = ctr .+ r_inner .* r_dir .+ hc .* c_dir
            xs = [p1[1], p2[1], p3[1], p4[1], p1[1]]
            ys = [p1[2], p2[2], p3[2], p4[2], p1[2]]
            zs = [p1[3], p2[3], p3[3], p4[3], p1[3]]
            (xs, ys, zs)
        end
        lines!(ax3d, @lift($blade_obs[1]), @lift($blade_obs[2]),
                     @lift($blade_obs[3]); color=:steelblue, linewidth=2.5)
    end

    # Lift system — gold bridle lines from hub attachment points to bearing
    bearing_obs    = @lift $u_obs[3*(hub_gid-1)+1 : 3*hub_gid] .+ bearing_offset .* shaft_dir
    lift_point_obs = @lift $bearing_obs .+ lift_offset .* shaft_dir

    for j in 1:p.n_lines
        bridle_obs = @lift begin
            u    = $u_obs
            ctr  = u[3*(hub_gid-1)+1 : 3*hub_gid]
            α    = u[6N + hub_ri]
            node = attachment_point(ctr, hub_R, α, j, p.n_lines, perp1, perp2)
            bp   = $bearing_obs
            ([node[1], bp[1]], [node[2], bp[2]], [node[3], bp[3]])
        end
        lines!(ax3d, @lift($bridle_obs[1]), @lift($bridle_obs[2]),
                     @lift($bridle_obs[3]); color=:gold, linewidth=1.2)
    end

    lift_line_obs = @lift begin
        bp = $bearing_obs; lp = $lift_point_obs
        ([bp[1], lp[1]], [bp[2], lp[2]], [bp[3], lp[3]])
    end
    lines!(ax3d, @lift($lift_line_obs[1]), @lift($lift_line_obs[2]),
                 @lift($lift_line_obs[3]); color=:gold, linewidth=3.0)

    scatter!(ax3d, @lift([$bearing_obs[1]]),    @lift([$bearing_obs[2]]),
                   @lift([$bearing_obs[3]]);     color=:gold, markersize=12)
    scatter!(ax3d, @lift([$lift_point_obs[1]]), @lift([$lift_point_obs[2]]),
                   @lift([$lift_point_obs[3]]); color=:white, markersize=10,
             marker=:diamond)

    # Wind arrow — from (hub - v_wind*x̂) to hub; length = wind speed (m/s = m)
    wind_arrow_obs = @lift begin
        u    = $u_obs
        ctr  = u[3*(hub_gid-1)+1 : 3*hub_gid]
        z    = max(ctr[3], 1.0)
        v    = p.v_wind_ref * (z / p.h_ref)^(1.0/7.0)
        tail = ctr .- [v, 0.0, 0.0]
        (tail, ctr, v)
    end
    lines!(ax3d,
           @lift([$wind_arrow_obs[1][1], $wind_arrow_obs[2][1]]),
           @lift([$wind_arrow_obs[1][2], $wind_arrow_obs[2][2]]),
           @lift([$wind_arrow_obs[1][3], $wind_arrow_obs[2][3]]);
           color=:darkorange, linewidth=3)
    scatter!(ax3d,
             @lift([$wind_arrow_obs[2][1]]),
             @lift([$wind_arrow_obs[2][2]]),
             @lift([$wind_arrow_obs[2][3]]);
             color=:darkorange, markersize=10)

    # ── HUD (right column) ────────────────────────────────────────────────────
    hud = GridLayout(fig[1, 3])
    # Fixed column width prevents label jitter as numbers change width
    colsize!(hud, 1, Fixed(320))

    r = Ref(0)
    nr!() = (r[] += 1; r[])

    # All live labels use tellwidth=false so column width is fixed by colsize!
    # @sprintf format strings always produce the same character count — no jitter.
    lbl(txt; kw...) = Label(hud[nr!(), 1], txt;
                             halign=:left, tellwidth=false,
                             justification=:left, kw...)

    fos_str(v) = (isinf(v) || isnan(v) || v > 9999) ? "   ∞" : @sprintf("%6.1f", v)

    # ── Live Telemetry ────────────────────────────────────────────────────────
    lbl("── Live Telemetry ──────────────────────"; fontsize=13, font=:bold)
    t_lbl      = lbl(isnothing(times) ? "Frame     1 / $(n_frames)" :
                                         "t =     0.00 s  (frame     1 / $(n_frames))")
    v_lbl      = lbl("Wind at hub  V =   0.00 m/s")
    p_lbl      = lbl("Output power  P =   0.00 kW  (  0% rated)")
    omega_lbl  = lbl("Rotor speed  ω =   0.000 rad/s  (  0.0 rpm)")
    tsr_lbl    = lbl("Tip speed ratio  λ =   0.00")
    elev_lbl   = lbl(@sprintf("Elevation  β = %5.1f°", rad2deg(p.elevation_angle)))
    kite_lbl   = lbl(@sprintf("Kite  CL = %4.2f  CD = %4.2f",
                               sys.kite.CL, sys.kite.CD))

    # ── Structural Loads ─────────────────────────────────────────────────────
    lbl("")
    lbl("── Structural Loads (this frame) ──────"; fontsize=13, font=:bold)
    lbl("Tether tension  (SWL = $(Int(TETHER_SWL)) N)"; fontsize=11, color=:steelblue)
    t_frame_lbl = lbl("  max      0 N  ·  FoS      ∞")
    Colorbar(hud[nr!(), 1]; colormap=tension_cmap, limits=(0.0, Float64(TETHER_SWL)),
             vertical=false, height=14, tellheight=true, tellwidth=false,
             label="0 N → $(Int(TETHER_SWL)) N SWL",
             labelsize=9, ticksize=4, ticklabelsize=8)
    lbl("Ring hoop compression  (P_crit = $(Int(RING_SWL)) N)"; fontsize=11, color=:firebrick)
    c_frame_lbl = lbl("  max util   0.0%  ·  FoS      ∞")
    Colorbar(hud[nr!(), 1]; colormap=ring_cmap, limits=(0.0, 1.0),
             vertical=false, height=14, tellheight=true, tellwidth=false,
             label="0 → buckling limit",
             labelsize=9, ticksize=4, ticklabelsize=8)
    warn_tors  = lbl(""; color=:red,    fontsize=12, font=:bold)
    warn_buck  = lbl(""; color=:orange, fontsize=12, font=:bold)
    warn_slack = lbl(""; color=:yellow, fontsize=12, font=:bold)

    # ── Run Peaks ─────────────────────────────────────────────────────────────
    lbl("")
    lbl("── Run Peaks ──────────────────────────"; fontsize=13, font=:bold)
    fos_t_peak  = T_peak > 0 ? TETHER_SWL / T_peak : Inf
    tp_lbl  = lbl(@sprintf("P_peak   %6.2f kW", P_peak))
    pp_lbl  = lbl(@sprintf("ω_peak   %7.3f rad/s  (%6.1f rpm)",
                             omega_peak, omega_peak * 60 / (2π)))
    op_lbl  = lbl(@sprintf("T_peak   %5.0f N  ·  FoS %s",
                             T_peak, fos_str(fos_t_peak)))
    vp_lbl  = lbl(@sprintf("V_peak   %5.2f m/s", V_peak))
    se_lbl  = lbl(@sprintf("Slack events:  %d frames with ≥1 slack line", slack_events))

    # ── Sag table (15 segments, compact) ──────────────────────────────────────
    lbl("")
    lbl("── Sag (mid-rope vs chord) ─────────────"; fontsize=13, font=:bold)
    sag_lbls = [lbl(@sprintf("Seg %2d:  ---  mm", s)) for s in 1:n_seg]

    # ── on() handler — update HUD every frame ────────────────────────────────
    on(frame_obs) do fi
        u = frames_ref[][fi]

        # Telemetry
        omega_hub = u[6N + Nr + Nr]
        omega_gnd = u[6N + Nr + 1]
        rpm       = omega_hub * 60.0 / (2π)
        P_kw      = p.k_mppt * omega_gnd^2 * abs(omega_gnd) / 1000.0
        pct_rated = p.p_rated_w > 0 ? P_kw * 1000.0 / p.p_rated_w * 100.0 : 0.0

        hub_ctr_i = u[3*(hub_gid-1)+1 : 3*hub_gid]
        z_hub     = max(hub_ctr_i[3], 1.0)
        V_hub     = p.v_wind_ref * (z_hub / p.h_ref)^(1.0/7.0)
        v_tip     = omega_hub * sys.rotor.radius
        tsr       = V_hub > 0.1 ? v_tip / (V_hub * cos(p.elevation_angle)) : 0.0

        if isnothing(times)
            t_lbl.text[] = @sprintf("Frame %5d / %d", fi, n_frames)
        else
            t_lbl.text[] = @sprintf("t = %8.2f s  (frame %5d / %d)",
                                     times[fi], fi, n_frames)
        end
        v_lbl.text[]    = @sprintf("Wind at hub  V = %6.2f m/s", V_hub)
        p_lbl.text[]    = @sprintf("Output power  P = %6.2f kW  (%3.0f%% rated)",
                                    P_kw, pct_rated)
        omega_lbl.text[] = @sprintf("Rotor speed  ω = %7.3f rad/s  (%6.1f rpm)",
                                     omega_hub, rpm)
        tsr_lbl.text[]  = @sprintf("Tip speed ratio  λ = %6.2f", tsr)
        elev_lbl.text[] = @sprintf("Elevation  β = %5.1f°", rad2deg(p.elevation_angle))

        # Structural this frame
        T_max   = _tether_max(u, sys, p)
        fos_t   = T_max > 0.0 ? TETHER_SWL / T_max : Inf
        α_vec   = u[6N+1 : 6N+Nr]
        sf      = ring_safety_frame(u, α_vec, sys, p)
        max_util = isempty(sf) ? 0.0 : maximum(r.utilisation for r in sf)
        fos_r   = max_util > 0.0 ? 1.0 / max_util : Inf
        n_slack = _n_slack_lines(u, sys, p)

        t_frame_lbl.text[] = @sprintf("  max %5.0f N  ·  FoS %s", T_max, fos_str(fos_t))
        c_frame_lbl.text[] = @sprintf("  max util %4.1f%%  ·  FoS %s",
                                        max_util * 100.0, fos_str(fos_r))

        warn_tors.text[]  = n_slack  > 0    ? "!! TORSIONAL COLLAPSE" : ""
        warn_buck.text[]  = max_util > 0.8   ? "!! BUCKLING RISK"      : ""
        warn_slack.text[] = n_slack  > 0    ?
                            @sprintf("!! LINE SLACK: %d lines", n_slack) : ""

        # Sag table
        for s in 1:n_seg
            sag = _seg_sag_mm(u, sys, p, s, perp1, perp2)
            sag_lbls[s].text[] = if sag < 10.0
                @sprintf("Seg %2d: %5.1f mm", s, sag)
            elseif sag < 1000.0
                @sprintf("Seg %2d: %5.0f mm", s, sag)
            else
                @sprintf("Seg %2d: %5.0f cm", s, sag / 10.0)
            end
        end
    end

    # ── Controls (left column) ────────────────────────────────────────────────
    ctrl = GridLayout(fig[1, 1])
    colsize!(ctrl, 1, Fixed(260))

    cr = Ref(0)
    cnr!() = (cr[] += 1; cr[])

    clbl(txt; kw...) = Label(ctrl[cnr!(), 1], txt;
                              halign=:left, tellwidth=false, kw...)
    function cslider!(range_; start=first(range_))
        Slider(ctrl[cnr!(), 1]; range=range_, startvalue=start)
    end
    function cval_lbl!(txt)
        Label(ctrl[cnr!(), 1], txt; halign=:left, tellwidth=false,
              fontsize=10, color=:grey70)
    end

    # ── Parameters ────────────────────────────────────────────────────────────
    clbl("── Parameters ──────────────────────────"; fontsize=12, font=:bold)

    clbl("Wind speed V_ref (m/s)"; fontsize=11)
    sl_vref   = cslider!(0.0:0.5:25.0; start=p.v_wind_ref)
    vl_vref   = cval_lbl!(@sprintf("%.1f m/s", p.v_wind_ref))
    on(sl_vref.value) do v; vl_vref.text[] = @sprintf("%.1f m/s", v); end

    clbl("MPPT gain k_mppt"; fontsize=11)
    sl_kmppt  = cslider!(1.0:1.0:50.0; start=clamp(p.k_mppt, 1.0, 50.0))
    vl_kmppt  = cval_lbl!(@sprintf("%.1f N·m·s²/rad²", p.k_mppt))
    on(sl_kmppt.value) do v; vl_kmppt.text[] = @sprintf("%.1f N·m·s²/rad²", v); end

    clbl("Kite CL"; fontsize=11)
    sl_cl     = cslider!(0.5:0.05:2.5; start=clamp(sys.kite.CL, 0.5, 2.5))
    vl_cl     = cval_lbl!(@sprintf("CL = %.2f", sys.kite.CL))
    on(sl_cl.value) do v
        vl_cl.text[] = @sprintf("CL = %.2f", v)
        kite_lbl.text[] = @sprintf("Kite  CL = %4.2f  CD = %4.2f",
                                    v, sl_cd.value[])
    end

    clbl("Kite CD"; fontsize=11)
    sl_cd     = cslider!(0.01:0.01:0.5; start=clamp(sys.kite.CD, 0.01, 0.5))
    vl_cd     = cval_lbl!(@sprintf("CD = %.2f", sys.kite.CD))
    on(sl_cd.value) do v
        vl_cd.text[] = @sprintf("CD = %.2f", v)
        kite_lbl.text[] = @sprintf("Kite  CL = %4.2f  CD = %4.2f",
                                    sl_cl.value[], v)
    end

    clbl("Elevation β (deg)"; fontsize=11)
    sl_beta   = cslider!(15.0:1.0:70.0; start=clamp(rad2deg(p.elevation_angle), 15.0, 70.0))
    vl_beta   = cval_lbl!(@sprintf("β = %.1f°", rad2deg(p.elevation_angle)))
    on(sl_beta.value) do v
        vl_beta.text[]  = @sprintf("β = %.1f°", v)
        elev_lbl.text[] = @sprintf("Elevation  β = %5.1f°", v)
    end

    clbl("Wind direction φ (deg) — visual only"; fontsize=11)
    sl_phi    = cslider!(0.0:1.0:360.0; start=0.0)
    vl_phi    = cval_lbl!("φ = 0°")
    on(sl_phi.value) do v; vl_phi.text[] = @sprintf("φ = %.0f°", v); end

    # ── Scenarios ─────────────────────────────────────────────────────────────
    clbl("")
    clbl("── Scenarios ───────────────────────────"; fontsize=12, font=:bold)

    scenario_msg = Observable("")
    Label(ctrl[cnr!(), 1], scenario_msg; halign=:left, tellwidth=false,
          fontsize=10, color=:grey60)

    can_rerun = !isnothing(u_settled) && !isnothing(wind_fn)
    scen_color(c) = can_rerun ? c : :grey40

    function _make_wind(vref, scenario, t_total)
        if scenario == :steady
            (pos, t) -> begin
                z  = max(pos[3], 1.0)
                sh = (z / p.h_ref)^(1.0/7.0)
                [vref * sh, 0.0, 0.0]
            end
        elseif scenario == :ramp_down
            (pos, t) -> begin
                v  = vref * max(0.0, 1.0 - t / t_total)
                z  = max(pos[3], 1.0)
                sh = (z / p.h_ref)^(1.0/7.0)
                [v * sh, 0.0, 0.0]
            end
        elseif scenario == :ramp_up
            (pos, t) -> begin
                v  = vref * min(1.0, t / t_total)
                z  = max(pos[3], 1.0)
                sh = (z / p.h_ref)^(1.0/7.0)
                [v * sh, 0.0, 0.0]
            end
        elseif scenario == :gust
            (pos, t) -> begin
                gust = t < t_total * 0.5 ? 1.5 * sin(π * t / (t_total * 0.5))^2 : 0.0
                v    = vref * (1.0 + gust)
                z    = max(pos[3], 1.0)
                sh   = (z / p.h_ref)^(1.0/7.0)
                [v * sh, 0.0, 0.0]
            end
        elseif scenario == :launch
            # Wind 0 → vref over 30 s, hold 30 s
            (pos, t) -> begin
                v  = t < 30.0 ? vref * t / 30.0 : vref
                z  = max(pos[3], 1.0)
                sh = (z / p.h_ref)^(1.0/7.0)
                [v * sh, 0.0, 0.0]
            end
        else   # :land
            (pos, t) -> begin
                v  = t < 30.0 ? vref * (1.0 - t * 0.9 / 30.0) :
                                 vref * 0.1 * max(0.0, 1.0 - (t - 30.0) / 10.0)
                z  = max(pos[3], 1.0)
                sh = (z / p.h_ref)^(1.0/7.0)
                [v * sh, 0.0, 0.0]
            end
        end
    end

    function _rerun!(scenario, label, vref=sl_vref.value[])
        can_rerun || begin scenario_msg[] = "⚠ provide u_settled & wind_fn to enable"; return end
        n_steps = 250_000
        dt      = 4e-5
        t_total = n_steps * dt
        wf      = _make_wind(vref, scenario, t_total)
        u_s     = copy(u_settled)
        u_s[6N + Nr + Nr] = 1.0   # seed hub
        scenario_msg[] = "Running $label …"
        @async begin
            new_frames = Vector{Vector{Float64}}(undef, n_steps ÷ 500)
            new_times  = Vector{Float64}(undef, n_steps ÷ 500)
            u  = copy(u_s)
            du = zeros(Float64, length(u))
            t  = 0.0
            fi = 1
            for step in 1:n_steps
                fill!(du, 0.0)
                multibody_ode!(du, u, (sys, p, wf), t)
                t += dt
                @views u[3N+1:6N]        .+= dt .* du[3N+1:6N]
                @views u[1:3N]            .+= dt .* u[3N+1:6N]
                @views u[6N+Nr+1:6N+2Nr] .+= dt .* du[6N+Nr+1:6N+2Nr]
                @views u[6N+1:6N+Nr]     .+= dt .* u[6N+Nr+1:6N+2Nr]
                @views u[3N+1:6N]        .*= 0.05
                u[1:3]       .= 0.0
                u[3N+1:3N+3] .= 0.0
                if step % 500 == 0
                    new_frames[fi] = copy(u)
                    new_times[fi]  = t
                    fi += 1
                end
            end
            frames_ref[] = new_frames
            notify(frame_obs)
            scenario_msg[] = "$label done  ($(length(new_frames)) frames)"
        end
    end

    scen_rows = GridLayout(ctrl[cnr!(), 1])
    Button(scen_rows[1, 1]; label="Run: Steady",   buttoncolor=scen_color(:darkgreen),
           labelcolor=:white) |> b -> on(b.clicks) do _; _rerun!(:steady,   "Steady"); end
    Button(scen_rows[1, 2]; label="Run: Ramp-Up",  buttoncolor=scen_color(:steelblue),
           labelcolor=:white) |> b -> on(b.clicks) do _; _rerun!(:ramp_up,  "Ramp-Up"); end
    Button(scen_rows[2, 1]; label="Run: Ramp-Down",buttoncolor=scen_color(:darkorange),
           labelcolor=:white) |> b -> on(b.clicks) do _; _rerun!(:ramp_down,"Ramp-Down"); end
    Button(scen_rows[2, 2]; label="Run: Gust",     buttoncolor=scen_color(:firebrick),
           labelcolor=:white) |> b -> on(b.clicks) do _; _rerun!(:gust,     "Gust"); end
    Button(scen_rows[3, 1]; label="Run: Launch",   buttoncolor=scen_color(:mediumpurple),
           labelcolor=:white) |> b -> on(b.clicks) do _; _rerun!(:launch,   "Launch"); end
    Button(scen_rows[3, 2]; label="Run: Land",     buttoncolor=scen_color(:saddlebrown),
           labelcolor=:white) |> b -> on(b.clicks) do _; _rerun!(:land,     "Land"); end

    # ── Playback ──────────────────────────────────────────────────────────────
    clbl("")
    clbl("── Playback ────────────────────────────"; fontsize=12, font=:bold)
    if !isnothing(times)
        Label(ctrl[cnr!(), 1],
              @sprintf("%.2f – %.2f s", times[1], times[end]);
              halign=:left, fontsize=10, color=:grey60, tellwidth=false)
    end

    frame_slider = Slider(ctrl[cnr!(), 1]; range=1:n_frames, startvalue=1)
    connect!(frame_obs, frame_slider.value)

    pb_row     = GridLayout(ctrl[cnr!(), 1])
    play_btn   = Button(pb_row[1, 1]; label="▶ Play")
    is_playing = Observable(false)
    speed_obs  = Observable(1.0)

    Menu(pb_row[1, 2]; options=["0.5×", "1×", "2×"], default="1×") |> m ->
        on(m.selection) do s
            speed_obs[] = s == "0.5×" ? 0.5 : s == "2×" ? 2.0 : 1.0
        end

    on(play_btn.clicks) do _
        is_playing[] = !is_playing[]
        play_btn.label[] = is_playing[] ? "|| Pause" : "▶ Play"
    end

    @async while true
        if is_playing[]
            nf = min(frame_slider.value[] + 1, length(frames_ref[]))
            set_close_to!(frame_slider, nf)
            if nf == length(frames_ref[])
                is_playing[] = false
                play_btn.label[] = "▶ Play"
            end
        end
        sleep(1 / 30 / speed_obs[])
    end

    # ── Actions ───────────────────────────────────────────────────────────────
    clbl("")
    clbl("── Actions ─────────────────────────────"; fontsize=12, font=:bold)

    act_row1 = GridLayout(ctrl[cnr!(), 1])
    Button(act_row1[1, 1]; label="Export Force CSV", buttoncolor=:purple,
           labelcolor=:white) |> b ->
        on(b.clicks) do _
            fi = frame_obs[]
            u  = frames_ref[][fi]
            du = zeros(Float64, length(u))
            wf = isnothing(wind_fn) ?
                     (pos, t) -> [p.v_wind_ref, 0.0, 0.0] : wind_fn
            multibody_ode!(du, u, (sys, p, wf), 0.0)
            fname = @sprintf("force_frame_%04d.csv", fi)
            open(fname, "w") do io
                println(io, "node_id,type,fx,fy,fz")
                for i in 1:N
                    nd = sys.nodes[i]
                    bp = 3*(i-1)+1
                    t_  = nd isa RingNode ? "ring" : "rope"
                    println(io, "$i,$t_,$(du[bp]),$(du[bp+1]),$(du[bp+2])")
                end
            end
            @info "Saved $fname"
        end

    Button(act_row1[1, 2]; label="Export Node CSV", buttoncolor=:darkslateblue,
           labelcolor=:white) |> b ->
        on(b.clicks) do _
            fi = frame_obs[]
            u  = frames_ref[][fi]
            fname = @sprintf("nodes_frame_%04d.csv", fi)
            open(fname, "w") do io
                println(io, "node_id,type,x,y,z,vx,vy,vz,tension_N")
                for i in 1:N
                    nd = sys.nodes[i]
                    bp = 3*(i-1)+1
                    bv = 3N + 3*(i-1)+1
                    t_ = nd isa RingNode ? "ring" : "rope"
                    T  = 0.0
                    if nd isa RopeNode
                        s, j = nd.seg_idx, nd.line_idx
                        T = _mid_tension(u, sys, p, s, j)
                    end
                    println(io, "$i,$t_,$(u[bp]),$(u[bp+1]),$(u[bp+2])," *
                                "$(u[bv]),$(u[bv+1]),$(u[bv+2]),$T")
                end
            end
            @info "Saved $fname"
        end

    act_row2 = GridLayout(ctrl[cnr!(), 1])
    Button(act_row2[1, 1]; label="Reset View", buttoncolor=:grey40,
           labelcolor=:white) |> b ->
        on(b.clicks) do _
            u      = frames_ref[][frame_obs[]]
            xs     = [u[3*(i-1)+1] for i in 1:N]
            ys     = [u[3*(i-1)+2] for i in 1:N]
            zs     = [u[3*(i-1)+3] for i in 1:N]
            pad    = 0.4
            dx     = (maximum(xs) - minimum(xs)) * pad
            dy     = (maximum(ys) - minimum(ys)) * pad
            dz     = (maximum(zs) - minimum(zs)) * pad
            ax3d.limits[] = (minimum(xs)-dx, maximum(xs)+dx,
                             minimum(ys)-dy, maximum(ys)+dy,
                             minimum(zs)-dz, maximum(zs)+dz)
        end

    unlock_toggle = Toggle(act_row2[1, 2])
    Label(act_row2[1, 3], "unlock"; halign=:left, fontsize=10, color=:grey60)

    rerun_btn = Button(ctrl[cnr!(), 1]; label="Re-run ODE 🔒", buttoncolor=:grey30,
                       labelcolor=:grey60)
    on(rerun_btn.clicks) do _
        if !unlock_toggle.active[]
            scenario_msg[] = "Toggle unlock to enable Re-run ODE"
            return
        end
        _rerun!(:steady, "Re-run Steady", sl_vref.value[])
    end
    on(unlock_toggle.active) do v
        rerun_btn.label[]       = v ? "Re-run ODE 🔓" : "Re-run ODE 🔒"
        rerun_btn.labelcolor[]  = v ? :white          : :grey60
        rerun_btn.buttoncolor[] = v ? :darkgreen      : :grey30
    end

    # ── Initial notify ────────────────────────────────────────────────────────
    notify(frame_obs)
    return fig
end

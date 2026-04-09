# src/visualization.jl
# GLMakie interactive dashboard for KiteTurbineDynamics.jl.
# Layout: 1600 × 950  |  Left 300 px Controls  |  Centre 3D  |  Right 370 px HUD
# Usage:  fig = build_dashboard(sys, p, frames; times=t_vec)
#         display(fig)

using GLMakie
using LinearAlgebra
using Printf

# ── Colour helpers ─────────────────────────────────────────────────────────────

"""4-stop tension colour ramp: blue → green → orange → red. Grey when slack (T < 5 N)."""
function _tension_color(T::Float64, swl::Float64)
    T < 5.0 && return RGBf(0.6f0, 0.6f0, 0.6f0)
    t = clamp(T / swl, 0.0, 1.0)
    if t <= 0.5
        s = Float32(t / 0.5)
        return RGBf(0.0f0, 0.2f0 + 0.6f0 * s, 1.0f0 - 0.8f0 * s)
    elseif t <= 0.8
        s = Float32((t - 0.5) / 0.3)
        return RGBf(s, 0.8f0 - 0.3f0 * s, 0.2f0 - 0.2f0 * s)
    else
        s = Float32((t - 0.8) / 0.2)
        return RGBf(1.0f0, 0.5f0 - 0.5f0 * s, 0.0f0)
    end
end

"""Ring polygon-column buckling colour: blue → cyan → orange → red."""
function _ring_util_color(util::Float64)
    t = clamp(util, 0.0, 1.0)
    if t <= 0.5
        s = Float32(t / 0.5)
        return RGBf(0.0f0, s, 1.0f0)
    elseif t <= 0.8
        s = Float32((t - 0.5) / 0.3)
        return RGBf(s, 1.0f0 - 0.7f0 * s, 1.0f0 - s)
    else
        s = Float32((t - 0.8) / 0.2)
        return RGBf(1.0f0, 0.3f0 - 0.3f0 * s, 0.0f0)
    end
end

# ── Geometry helpers ──────────────────────────────────────────────────────────

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

"""Maximum tether tension across all lines."""
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

"""Maximum mid-rope sag (mm) across all 15 segments, line 1."""
function _max_sag_mm(u, sys, p, perp1, perp2)
    N   = sys.n_total
    best = 0.0; best_seg = 1
    for s in 1:(p.n_rings+1)
        gid_a = sys.ring_ids[s];   gid_b = sys.ring_ids[s+1]
        na = sys.nodes[gid_a]::RingNode; nb = sys.nodes[gid_b]::RingNode
        ctr_a = u[3*(gid_a-1)+1:3*gid_a]; ctr_b = u[3*(gid_b-1)+1:3*gid_b]
        pa = attachment_point(ctr_a, na.radius, u[6N+na.ring_idx], 1, p.n_lines, perp1, perp2)
        pb = attachment_point(ctr_b, nb.radius, u[6N+nb.ring_idx], 1, p.n_lines, perp1, perp2)
        gid_mid = (s-1)*16 + 3
        pm  = u[3*(gid_mid-1)+1:3*gid_mid]
        AB  = pb .- pa; len2 = dot(AB, AB)
        len2 < 1e-18 && continue
        foot = pa .+ (dot(pm .- pa, AB) / len2) .* AB
        sag  = norm(pm .- foot) * 1000.0
        if sag > best; best = sag; best_seg = s; end
    end
    best, best_seg
end

# ── Dashboard builder ─────────────────────────────────────────────────────────

"""
    build_dashboard(sys, p, frames; times, u_settled, wind_fn) → Figure

Build a GLMakie interactive dashboard from ODE state snapshots.

Layout (1600 × 950, dark theme):
  Left  300 px — Controls: Parameters · Playback · Actions
  Centre        — 3D viewport: TRPT kite turbine + wind arrow
  Right 370 px  — HUD: Telemetry · Torque · Structural · Peaks · Scenarios
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

    # ── Tension closures — use ring attachment geometry, not rope node positions ──
    # Ring attachment points track the ODE alpha angles correctly even when rope
    # nodes drift to natural length.  l_seg is the natural length of one full
    # tether segment (4 sub-segs in series), so EA×Δl/l_seg gives correct force.
    _ea_rope = sys.sub_segs[1].EA
    _l_seg_nat = p.tether_length / n_seg
    _seg_T = (u, s, j) -> begin
        gid_a = sys.ring_ids[s];      gid_b = sys.ring_ids[s + 1]
        na    = sys.nodes[gid_a]::RingNode
        nb    = sys.nodes[gid_b]::RingNode
        ctr_a = u[3*(gid_a-1)+1 : 3*gid_a]
        ctr_b = u[3*(gid_b-1)+1 : 3*gid_b]
        α_a   = u[6N + na.ring_idx]
        α_b   = u[6N + nb.ring_idx]
        pa    = attachment_point(ctr_a, na.radius, α_a, j, p.n_lines, perp1, perp2)
        pb    = attachment_point(ctr_b, nb.radius, α_b, j, p.n_lines, perp1, perp2)
        max(0.0, _ea_rope * (norm(pb .- pa) - _l_seg_nat) / _l_seg_nat)
    end
    _tmax_local   = u -> maximum((_seg_T(u, s, j) for s in 1:n_seg, j in 1:p.n_lines); init=0.0)
    _nslack_local = u -> count(_seg_T(u, s, j) < 5.0 for s in 1:n_seg, j in 1:p.n_lines)

    l_seg          = p.tether_length / n_seg
    bearing_offset = 1.5 * l_seg
    lift_offset    = 1.0

    hub_gid  = sys.ring_ids[Nr]
    hub_node = sys.nodes[hub_gid]::RingNode
    hub_R    = hub_node.radius
    hub_ri   = hub_node.ring_idx

    tension_cmap = cgrad([RGBf(0.0, 0.2, 1.0), RGBf(0.0, 0.8, 0.2),
                          RGBf(1.0, 0.5, 0.0), RGBf(1.0, 0.0, 0.0)],
                          [0.0, 0.5, 0.8, 1.0])
    ring_cmap    = cgrad([RGBf(0.0, 0.0, 1.0), RGBf(0.0, 1.0, 1.0),
                          RGBf(1.0, 0.5, 0.0), RGBf(1.0, 0.0, 0.0)],
                          [0.0, 0.5, 0.8, 1.0])

    # ── Pre-compute run-wide peaks ────────────────────────────────────────────
    T_peak = 0.0; omega_peak = 0.0; P_peak = 0.0; V_peak = 0.0; slack_events = 0
    for u_f in frames
        T_peak     = max(T_peak,     _tmax_local(u_f))
        omega_hub  = abs(u_f[6N + Nr + Nr])
        omega_gnd  = abs(u_f[6N + Nr + 1])
        P_kw       = p.k_mppt * omega_gnd^2 * omega_gnd / 1000.0
        omega_peak = max(omega_peak, omega_hub)
        P_peak     = max(P_peak,     P_kw)
        hub_ctr    = u_f[3*(hub_gid-1)+1 : 3*hub_gid]
        z_hub      = max(hub_ctr[3], 1.0)
        V_peak     = max(V_peak, p.v_wind_ref * (z_hub / p.h_ref)^(1.0/7.0))
        _nslack_local(u_f) > 0 && (slack_events += 1)
    end

    # ── Observables ──────────────────────────────────────────────────────────
    frame_obs       = Observable(1)
    frames_obs      = Observable(frames)          # mutable — updated by every _rerun!
    times_ref       = Ref(isnothing(times) ? Float64[] : collect(times))
    u_obs           = @lift $frames_obs[$frame_obs]   # reacts to BOTH frame index AND new frames
    lift_device_obs = Observable{Union{Nothing, LiftDevice}}(nothing)
    wind_fn_obs     = Observable{Function}(isnothing(wind_fn) ?
                          (pos, t) -> [p.v_wind_ref, 0.0, 0.0] : wind_fn)

    # ── Figure — dark theme ───────────────────────────────────────────────────
    set_theme!(theme_dark())
    fig = Figure(size=(1600, 950))

    ctrl = GridLayout(fig[1, 1])
    hud  = GridLayout(fig[1, 3])
    colsize!(fig.layout, 1, Fixed(300))
    colsize!(fig.layout, 3, Fixed(370))

    # ── 3D Axis ───────────────────────────────────────────────────────────────
    ax3d = Axis3(fig[1, 2];
                 title     = "KiteTurbineDynamics — TRPT Kite Turbine",
                 xlabel    = "Downwind X [m]",
                 ylabel    = "Crosswind Y [m]",
                 zlabel    = "Altitude Z [m]",
                 aspect    = :data,
                 titlesize = 13)

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

    # Tether lines — tension-coloured
    for s in 1:n_seg, j in 1:p.n_lines
        lo   = @lift _rope_line_pts($u_obs, sys, p, s, j, perp1, perp2)
        T_ob = @lift _seg_T($u_obs, s, j)
        co   = @lift _tension_color($T_ob, TETHER_SWL)
        lw   = @lift ($T_ob < 5.0 ? 0.8f0 : 1.5f0)
        lines!(ax3d, @lift($lo[1]), @lift($lo[2]), @lift($lo[3]);
               color=co, linewidth=lw)
    end

    # Intermediate ring polygons — hoop-compression colour
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

    # Rotor blades
    r_inner = hub_R
    r_outer = sys.rotor.radius
    chord   = r_outer * 0.15
    for b in 1:p.n_blades
        blade_obs = @lift begin
            u    = $u_obs
            ctr  = u[3*(hub_gid-1)+1 : 3*hub_gid]
            α    = u[6N + hub_ri]
            φ    = α + (b-1) * (2π / p.n_blades)
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

    # Lift system — bridle lines from hub attachment → swivel bearing → kite
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

    scatter!(ax3d, @lift([$lift_point_obs[1]]), @lift([$lift_point_obs[2]]),
                   @lift([$lift_point_obs[3]]); color=:white, markersize=10,
             marker=:diamond)

    # Lift kite tether + kite marker — position is dynamic: drops when wind drops
    kite_pos_obs = @lift begin
        lp  = $lift_point_obs
        ld  = $lift_device_obs
        wfn = $wind_fn_obs
        fi  = $frame_obs
        # Estimate current wind speed from the wind function at the hub position
        # Use times_ref so we always track the most recently run scenario's times
        tr = times_ref[]
        t_now = (!isempty(tr) && fi <= length(tr)) ? tr[fi] : 0.0
        v_vec   = wfn(lp, t_now)
        v_now   = max(sqrt(v_vec[1]^2 + v_vec[2]^2), 0.5)
        sh_horiz = [shaft_dir[1], shaft_dir[2], 0.0]
        sh_hat   = sh_horiz ./ max(norm(sh_horiz), 1e-6)
        if !isnothing(ld)
            # Quasi-static kite elevation angle from lift physics
            _, _, elev_deg = lift_force_steady(ld, p.rho, v_now)
            θ = deg2rad(max(5.0, elev_deg))  # clamp: kite can't go below 5°
            ll = (ld isa SingleKiteParams   ? ld.line_length :
                  ld isa StackedKitesParams ? ld.spacing * ld.n_kites :
                  ld.line_length)
            lp .+ ll .* (sh_hat .* cos(θ) .+ [0.0, 0.0, sin(θ)])
        else
            # No lift device configured — show a visual kite that still responds
            # to wind speed so kite-drop scenarios are visible.
            # Elevation scales from 5° at stall (v < 3 m/s) to 45° at rated wind.
            v_stall  = 3.0
            v_ref_kd = max(p.v_wind_ref, 8.0)   # rated reference for scaling
            θ_min = deg2rad(5.0); θ_max = deg2rad(45.0)
            θ = v_now <= v_stall ? θ_min :
                v_now >= v_ref_kd ? θ_max :
                θ_min + (θ_max - θ_min) * (v_now - v_stall) / (v_ref_kd - v_stall)
            lp .+ 25.0 .* (sh_hat .* cos(θ) .+ [0.0, 0.0, sin(θ)])
        end
    end
    kite_tether_obs = @lift begin
        lp = $lift_point_obs; kt = $kite_pos_obs
        ([lp[1], kt[1]], [lp[2], kt[2]], [lp[3], kt[3]])
    end
    lines!(ax3d, @lift($kite_tether_obs[1]), @lift($kite_tether_obs[2]),
                 @lift($kite_tether_obs[3]); color=:deepskyblue, linewidth=2.0)
    scatter!(ax3d, @lift([$kite_pos_obs[1]]), @lift([$kite_pos_obs[2]]),
                   @lift([$kite_pos_obs[3]]); color=:deepskyblue, markersize=15)

    # Back line — coral, from 10 cm above the hub bearing down to the fixed ground
    # anchor.  The anchor is back_anchor_fwd_x metres downwind of the hub's design
    # x-projection, placing it clear of the TRPT rope footprint.
    # Colour: coral = taut; grey = slack.
    let back_off    = 0.10,
        back_ax     = p.tether_length * cos(p.elevation_angle) + p.back_anchor_fwd_x,
        design_hub_x = p.tether_length * cos(p.elevation_angle),
        design_hub_z = p.tether_length * sin(p.elevation_angle) + 0.10,
        back_L0     = sqrt(p.back_anchor_fwd_x^2 + (p.tether_length * sin(p.elevation_angle) + back_off)^2)
        scatter!(ax3d, [back_ax], [0.0], [0.0]; color=:coral, markersize=12, marker=:diamond)
        back_line_obs = @lift begin
            lp   = $lift_point_obs
            att  = (lp[1], lp[2], lp[3] + back_off)
            bv   = (att[1] - back_ax, att[2], att[3])
            taut = sqrt(bv[1]^2 + bv[2]^2 + bv[3]^2) > back_L0
            ([back_ax, att[1]], [0.0, att[2]], [0.0, att[3]]), taut
        end
        lines!(ax3d,
               @lift($back_line_obs[1][1]), @lift($back_line_obs[1][2]),
               @lift($back_line_obs[1][3]);
               color=@lift($back_line_obs[2] ? :coral : :grey50),
               linewidth=1.5)
    end

    # Wind arrow — orange, upwind side, length = wind speed (m/s ≡ m visual)
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
             @lift([$wind_arrow_obs[1][1]]),
             @lift([$wind_arrow_obs[1][2]]),
             @lift([$wind_arrow_obs[1][3]]);
             color=:darkorange, markersize=12, marker=:rtriangle)

    # ── HUD (right column) ────────────────────────────────────────────────────
    # Fixed column width prevents label jitter as numbers change width
    colsize!(hud, 1, Fixed(350))

    hr = Ref(0)
    hnr!() = (hr[] += 1; hr[])

    hlbl(txt; kw...) = Label(hud[hnr!(), 1], txt;
                              halign=:left, tellwidth=false,
                              justification=:left, kw...)
    fos_str(v) = (isinf(v) || isnan(v) || v > 9999) ? "   ∞" : @sprintf("%6.1f", v)

    # ── SECTION A: Live Telemetry ─────────────────────────────────────────────
    hlbl("── Live Telemetry ─────────────────────────"; fontsize=13, font=:bold)

    # Time / frame indicator — shows simulated time if available
    t_lbl = hlbl(isnothing(times) ? "Frame     1 / $(n_frames)" :
                                     "t =     0.00 s  (frame     1 / $(n_frames))")

    # Wind speed at hub altitude (Hellmann shear applied)
    v_lbl = hlbl("Wind at hub    V =    0.00 m/s")

    # Rotor (hub) angular velocity and RPM
    # Purpose: primary rotational state of the kite/rotor assembly
    omega_lbl = hlbl("Rotor (hub)    ω =   0.000 rad/s  (  0.0 rpm)")

    # PTO (ground ring) angular velocity — actual generator shaft speed
    # Purpose: what the generator sees; differs from hub by TRPT torsional slip
    pto_lbl = hlbl("PTO (ground)   ω =   0.000 rad/s  (  0.0 rpm)")

    # Electrical output power = τ_gen × ω_PTO = k_mppt × ω_PTO³
    # Purpose: primary performance metric
    p_lbl = hlbl("Output power   P =   0.00 kW  (  0% rated)")

    # Tip speed ratio λ = ω_hub × R / V_hub
    # Purpose: operating point on the Cp–λ curve; optimal ~4.1
    tsr_lbl = hlbl("Tip speed ratio  λ =   0.00  (opt ≈ 4.1)")

    # TRPT total twist: accumulated α from ground ring to hub
    # Purpose: torsional loading indicator; large twist → rope near failure
    twist_lbl = hlbl("TRPT twist  Δα =   0.0°  (hub – PTO)")

    # Hub altitude — key indicator for kite drop / TRPT sag scenarios
    hub_z0_ref = Ref{Float64}(NaN)   # reference Z from frame 1; NaN = not yet set; reset each rerun
    hub_z_lbl  = hlbl("Hub altitude  Z =   0.0 m  (Δ = ±  0.0 m)")

    # Fixed operating parameters (update only on frame changes for β; others static)
    elev_lbl  = hlbl(@sprintf("Elevation  β = %5.1f°  |  Rated %.0f kW",
                               rad2deg(p.elevation_angle), p.p_rated_w/1000.0))
    kite_lbl  = hlbl(@sprintf("Kite  CL = %4.2f  CD = %4.2f  |  A = %.1f m²",
                               sys.kite.CL, sys.kite.CD, sys.kite.area))

    # ── SECTION B: Torque & Power Balance ────────────────────────────────────
    hlbl(""; fontsize=6)
    hlbl("── Torque & Power Balance ──────────────────"; fontsize=13, font=:bold)

    # Aero torque at hub: τ_aero = P_aero / ω_hub
    # Purpose: driving torque from wind; must exceed generator load for sustained rotation
    tau_aero_lbl = hlbl("τ_aero  =      0 N·m   (wind drives rotor)")

    # Generator (MPPT) torque on PTO: τ_gen = k_mppt × ω_PTO²
    # Purpose: braking load; set by MPPT law to maximise power at all wind speeds
    tau_gen_lbl  = hlbl("τ_gen   =      0 N·m   (MPPT brake on PTO)")

    # Angular velocity difference between hub and PTO
    # Purpose: non-zero Δω = torsional "slip"; needed to transmit torque but
    #          large Δω causes damper heating and structural stress
    delta_omega_lbl = hlbl("Δω (hub−PTO)  =   0.000 rad/s")

    # ── SECTION C: Structural Loads ───────────────────────────────────────────
    hlbl(""; fontsize=6)
    hlbl("── Structural Loads (this frame) ───────────"; fontsize=13, font=:bold)

    # Tether max tension vs SWL — measured at mid sub-segment (avoids ring attachment spikes)
    hlbl("Tether tension  (SWL = $(Int(TETHER_SWL)) N)"; fontsize=11, color=:steelblue)
    t_frame_lbl = hlbl("  max      0 N  ·  FoS      ∞")
    Colorbar(hud[hnr!(), 1]; colormap=tension_cmap, limits=(0.0, Float64(TETHER_SWL)),
             vertical=false, height=14, tellheight=true, tellwidth=false,
             label="0 N → $(Int(TETHER_SWL)) N SWL",
             labelsize=9, ticksize=4, ticklabelsize=8)

    # Ring polygon column buckling — fraction of Euler column P_crit for CFRP design tube
    hlbl("Ring column buckling  (CFRP tube, FoS_design = $(Int(FOS_DESIGN)))"; fontsize=11, color=:firebrick)
    c_frame_lbl = hlbl("  max util   0.0%  ·  FoS      ∞")
    Colorbar(hud[hnr!(), 1]; colormap=ring_cmap, limits=(0.0, 1.0),
             vertical=false, height=14, tellheight=true, tellwidth=false,
             label="0 → buckling limit",
             labelsize=9, ticksize=4, ticklabelsize=8)

    # Max rope sag (single line, most-sagged segment)
    # Purpose: sag indicates gravity loading vs rope tension; large sag → low tension
    sag_lbl = hlbl("Max rope sag   0.0 mm  (seg --)  |  slack: 0 lines")

    # Warnings — only visible when condition is active
    # TORSIONAL COLLAPSE: hub twist > 270° (nearing rope-wrap limit)
    # BUCKLING RISK: ring hoop utilisation > 80%
    # LINE SLACK: any tether line below 5 N tension
    warn_tors  = hlbl(""; color=:red,    fontsize=12, font=:bold)
    warn_buck  = hlbl(""; color=:orange, fontsize=12, font=:bold)
    warn_slack = hlbl(""; color=:yellow, fontsize=12, font=:bold)

    # ── SECTION D: Run Peaks ─────────────────────────────────────────────────
    hlbl(""; fontsize=6)
    hlbl("── Run Peaks ──────────────────────────────"; fontsize=13, font=:bold)
    fos_t_peak = T_peak > 0 ? TETHER_SWL / T_peak : Inf
    # P_peak: maximum electrical power achieved during the run
    hlbl(@sprintf("P_peak   %6.2f kW  |  ω_peak  %6.3f rad/s (%5.1f rpm)",
                   P_peak, omega_peak, omega_peak * 60 / (2π)))
    # T_peak: maximum tether tension and corresponding factor of safety
    hlbl(@sprintf("T_peak   %5.0f N  ·  FoS %s  |  V_peak  %5.2f m/s",
                   T_peak, fos_str(fos_t_peak), V_peak))
    hlbl(@sprintf("Slack events:  %d / %d frames (%.1f%%)",
                   slack_events, n_frames, 100.0*slack_events/max(n_frames,1)))

    # ── SECTION E: Scenarios ──────────────────────────────────────────────────
    # Moved here from Controls — these are operational choices, not parameter tweaks
    hlbl(""; fontsize=6)
    hlbl("── Scenarios ──────────────────────────────"; fontsize=13, font=:bold)

    can_rerun          = !isnothing(u_settled) && !isnothing(wind_fn)
    scenario_msg       = Observable(can_rerun ? "Select a scenario and press Run." :
                                               "⚠  Pass u_settled & wind_fn to enable reruns.")
    scenario_msg_color = Observable(can_rerun ? :grey60 : :orangered)
    Label(hud[hnr!(), 1], scenario_msg; halign=:left, tellwidth=false,
          fontsize=11, color=scenario_msg_color)

    scen_color(_) = can_rerun ? :grey30 : :grey20

    # Build a modified copy of an immutable SystemParams (field overrides via kwargs).
    # Explicit convert(fieldtype, value) ensures the positional constructor matches.
    function _modified_params(base::SystemParams; kwargs...)
        fnames    = fieldnames(SystemParams)
        ftypes    = fieldtypes(SystemParams)
        overrides = Dict{Symbol,Any}(kwargs)
        vals = ntuple(length(fnames)) do i
            convert(ftypes[i], get(overrides, fnames[i], getfield(base, fnames[i])))
        end
        SystemParams(vals...)
    end

    function _make_wind(vref, scenario, t_total)
        if scenario == :steady
            (pos, t) -> begin
                z = max(pos[3], 1.0); [vref * (z/p.h_ref)^(1/7), 0.0, 0.0]
            end
        elseif scenario == :ramp_down
            (pos, t) -> begin
                v = vref * max(0.0, 1.0 - t / t_total)
                z = max(pos[3], 1.0); [v * (z/p.h_ref)^(1/7), 0.0, 0.0]
            end
        elseif scenario == :ramp_up
            (pos, t) -> begin
                v = vref * min(1.0, t / t_total)
                z = max(pos[3], 1.0); [v * (z/p.h_ref)^(1/7), 0.0, 0.0]
            end
        elseif scenario == :gust
            (pos, t) -> begin
                gust = t < t_total*0.5 ? 1.5*sin(π*t/(t_total*0.5))^2 : 0.0
                z = max(pos[3], 1.0); [vref*(1+gust)*(z/p.h_ref)^(1/7), 0.0, 0.0]
            end
        elseif scenario == :launch
            (pos, t) -> begin
                v = t < 30.0 ? vref*t/30.0 : vref
                z = max(pos[3], 1.0); [v * (z/p.h_ref)^(1/7), 0.0, 0.0]
            end
        elseif scenario == :kite_drop
            # Wind holds for 1.5 s then falls over 5 s to 12 % of rated (done by
            # t ≈ 6.5 s), leaving 3.5 s of low-wind sag visible within the 10 s run.
            (pos, t) -> begin
                hold_t = 1.5; drop_t = 5.0
                frac = t < hold_t ? 1.0 :
                       t < hold_t + drop_t ? 1.0 - (t - hold_t) / drop_t * 0.88 :
                       0.12
                v = vref * frac
                z = max(pos[3], 1.0); [v * (z/p.h_ref)^(1/7), 0.0, 0.0]
            end
        else   # :land
            (pos, t) -> begin
                v = t < 30.0 ? vref*(1.0-t*0.9/30.0) : vref*0.1*max(0.0,1.0-(t-30.0)/10.0)
                z = max(pos[3], 1.0); [v * (z/p.h_ref)^(1/7), 0.0, 0.0]
            end
        end
    end

    function _rerun!(scenario, label, vref)
        # ── Status update FIRST — always visible regardless of what follows ──
        if !can_rerun
            scenario_msg_color[] = :orangered
            scenario_msg[]       = "⚠  provide u_settled & wind_fn to enable reruns"
            return
        end
        scenario_msg_color[] = :orange
        scenario_msg[]       = "⟳  Running $label …  (10 s simulation)"
        hub_z0_ref[]         = NaN   # reset hub-altitude reference for this run

        # ── Build scenario inputs (errors surfaced via status label) ──────────
        local wf, p_run, u_s, ode_p
        try
            n_steps_local = 250_000; dt_local = 4e-5
            t_total       = n_steps_local * dt_local
            wf    = _make_wind(Float64(vref), scenario, t_total)
            wind_fn_obs[] = wf
            p_run = _modified_params(p;
                        k_mppt          = Float64(sl_kmppt.value[]),
                        elevation_angle = deg2rad(Float64(sl_beta.value[])))
            ld    = lift_device_obs[]
            ode_p = isnothing(ld) ? (sys, p_run, wf) : (sys, p_run, wf, ld)
            u_s   = copy(u_settled)
            set_orbital_velocities!(u_s, sys, p_run)
        catch e
            scenario_msg_color[] = :orangered
            scenario_msg[]       = "Setup error: $(sprint(showerror, e))"
            return
        end

        n_steps = 250_000; dt = 4e-5
        @async try
            new_frames = Vector{Vector{Float64}}(undef, n_steps ÷ 500)
            new_times  = Vector{Float64}(undef,  n_steps ÷ 500)
            u  = copy(u_s); du = zeros(Float64, length(u))
            t  = 0.0; fi = 1
            for step in 1:n_steps
                fill!(du, 0.0)
                multibody_ode!(du, u, ode_p, t)
                t += dt
                @views u[3N+1:6N]        .+= dt .* du[3N+1:6N]
                @views u[1:3N]            .+= dt .* u[3N+1:6N]
                @views u[6N+Nr+1:6N+2Nr] .+= dt .* du[6N+Nr+1:6N+2Nr]
                @views u[6N+1:6N+Nr]     .+= dt .* u[6N+Nr+1:6N+2Nr]
                orbital_damp_rope_velocities!(u, sys, p_run, 0.05)   # was: p (bug)
                u[1:3] .= 0.0; u[3N+1:3N+3] .= 0.0
                if step % 500 == 0
                    new_frames[fi] = copy(u); new_times[fi] = t; fi += 1
                end
            end
            nf           = length(new_frames)
            times_ref[]  = new_times
            frames_obs[] = new_frames
            frame_slider.range[] = 1:nf
            frame_slider.value[] = 1
            scenario_msg_color[] = :lawngreen
            scenario_msg[]       = "✓  $label complete  ($nf frames, $(round(new_times[end], digits=1)) s)"
        catch e
            scenario_msg_color[] = :orangered
            scenario_msg[]       = "Sim error: $(sprint(showerror, e))"
        end
    end

    scen_rows = GridLayout(hud[hnr!(), 1])
    # Wind speed slider for scenarios (inline, compact)
    Label(scen_rows[1, 1], "V_ref:"; halign=:left, fontsize=10, color=:grey70)
    scen_vref_slider = Slider(scen_rows[1, 2:4]; range=5.0:0.5:20.0,
                               startvalue=p.v_wind_ref)
    scen_vref_lbl = Label(scen_rows[1, 5], @sprintf("%.1f m/s", p.v_wind_ref);
                           halign=:left, fontsize=10, color=:grey70, tellwidth=false)
    on(scen_vref_slider.value) do v
        scen_vref_lbl.text[] = @sprintf("%.1f m/s", v)
    end

    bc          = scen_color(:_)   # neutral: grey30 (enabled) or grey20 (disabled)
    bc_active   = can_rerun ? :steelblue : :grey20   # highlight for the selected scenario
    active_btn  = Ref{Any}(nothing)                  # tracks the last-clicked button
    # Deferred precheck for kite_drop — filled in after device_menu is defined below
    _kite_drop_precheck! = Ref{Function}(() -> nothing)
    scen_btns   = GridLayout(hud[hnr!(), 1])
    for (pos, lbl, sym) in [
            ((1,1), "Steady",    :steady),
            ((1,2), "Ramp Up",   :ramp_up),
            ((1,3), "Ramp Down", :ramp_down),
            ((2,1), "Gust",      :gust),
            ((2,2), "Launch",    :launch),
            ((2,3), "Land",      :land),
            ((3,1), "Kite Drop", :kite_drop)]
        btn = Button(scen_btns[pos...]; label=lbl, buttoncolor=bc,
                     labelcolor=:white, height=28)
        let btn=btn, sym=sym, lbl=lbl          # explicit capture per iteration
            on(btn.clicks) do _
                # deactivate previous selection
                prev = active_btn[]
                isnothing(prev) || (prev.buttoncolor[] = bc)
                # highlight this button as active
                btn.buttoncolor[] = bc_active
                active_btn[] = btn
                # kite drop requires a lift device — auto-select one if none chosen
                sym == :kite_drop && _kite_drop_precheck![]()
                _rerun!(sym, lbl, scen_vref_slider.value[])
            end
        end
    end

    # ── HUD update handler ────────────────────────────────────────────────────
    on(frame_obs) do fi
        u = frames_obs[][fi]

        # ── Telemetry ────────────────────────────────────────────────────────
        omega_hub = u[6N + Nr + Nr]            # hub (rotor) angular velocity
        omega_gnd = u[6N + Nr + 1]             # ground ring (PTO) angular velocity
        rpm_hub   = omega_hub * 60.0 / (2π)
        rpm_gnd   = omega_gnd * 60.0 / (2π)
        P_kw      = p.k_mppt * omega_gnd^2 * abs(omega_gnd) / 1000.0
        pct_rated = p.p_rated_w > 0 ? P_kw*1000.0/p.p_rated_w*100.0 : 0.0
        hub_ctr   = u[3*(hub_gid-1)+1 : 3*hub_gid]
        z_hub     = max(hub_ctr[3], 1.0)
        # Use actual wind function at current time — reflects scenario accurately
        tr        = times_ref[]
        t_hud     = (!isempty(tr) && fi <= length(tr)) ? tr[fi] : 0.0
        wfn_hud   = wind_fn_obs[]
        v_vec_hub = wfn_hud(hub_ctr, t_hud)
        V_hub     = max(sqrt(v_vec_hub[1]^2 + v_vec_hub[2]^2), 0.1)
        # TSR: blade tip speed ratio = ω_hub·R / V_hub (not cosine-corrected — operational display)
        tsr       = V_hub > 0.1 ? abs(omega_hub) * sys.rotor.radius / V_hub : 0.0
        # TRPT structural twist: sum of principal-value inter-ring angular offsets.
        # Raw (α_hub − α_gnd) grows without bound whenever ω_hub ≠ ω_gnd (elastic
        # shaft slip) even though the torsional deformation is settled.  Reducing
        # each inter-ring delta to its principal value in (−π, π] removes accumulated
        # whole-revolution counts and shows only the instantaneous geometric twist.
        alpha_vec = @view u[6N+1 : 6N+Nr]
        Δα_deg    = rad2deg(sum(i -> mod(alpha_vec[i+1] - alpha_vec[i] + π, 2π) - π,
                                1:Nr-1))

        nf_now       = length(frames_obs[])
        t_lbl.text[] = isempty(tr) ?
            @sprintf("Frame %5d / %d", fi, nf_now) :
            @sprintf("t = %8.2f s  (frame %5d / %d)", t_hud, fi, nf_now)
        v_lbl.text[]        = @sprintf("Wind at hub    V = %6.2f m/s", V_hub)
        omega_lbl.text[]    = @sprintf("Rotor (hub)    ω = %7.3f rad/s  (%6.1f rpm)",
                                        omega_hub, rpm_hub)
        pto_lbl.text[]      = @sprintf("PTO (ground)   ω = %7.3f rad/s  (%6.1f rpm)",
                                        omega_gnd, rpm_gnd)
        p_lbl.text[]        = @sprintf("Output power   P = %6.2f kW  (%3.0f%% rated)",
                                        P_kw, pct_rated)
        tsr_lbl.text[]      = @sprintf("Tip speed ratio  λ = %5.2f  (opt ≈ 4.1)", tsr)
        twist_lbl.text[]    = @sprintf("TRPT twist  Δα = %7.1f°  (hub – PTO)", Δα_deg)

        # Hub altitude — resolve reference on first frame of each run
        z_hub_now = hub_ctr[3]
        if isnan(hub_z0_ref[]);  hub_z0_ref[] = z_hub_now;  end
        δz_hub    = z_hub_now - hub_z0_ref[]
        hub_z_lbl.text[] = @sprintf("Hub altitude  Z = %5.1f m  (Δ = %+.2f m)",
                                     z_hub_now, δz_hub)

        elev_lbl.text[]     = @sprintf("Elevation  β = %5.1f°  |  Rated %.0f kW",
                                        rad2deg(p.elevation_angle), p.p_rated_w/1000.0)

        # ── Torque & Power Balance ────────────────────────────────────────────
        # Aero torque: τ = P_aero / ω (with floor at 0.5 to match dynamics)
        lambda_t = abs(omega_hub) * sys.rotor.radius / max(V_hub, 0.1)
        P_aero   = 0.5 * p.rho * V_hub^3 * π * sys.rotor.radius^2 *
                   cp_at_tsr(lambda_t) * cos(p.elevation_angle)^3
        tau_aero = P_aero / max(abs(omega_hub), 0.5)
        # Generator torque: MPPT quadratic law
        tau_gen  = p.k_mppt * omega_gnd^2   # magnitude; sign opposes rotation
        Δω       = omega_hub - omega_gnd

        tau_aero_lbl.text[]     = @sprintf("τ_aero  = %7.0f N·m   (wind drives rotor)", tau_aero)
        tau_gen_lbl.text[]      = @sprintf("τ_gen   = %7.0f N·m   (MPPT brake on PTO)", tau_gen)
        delta_omega_lbl.text[]  = @sprintf("Δω (hub−PTO)  = %8.4f rad/s", Δω)

        # ── Structural ───────────────────────────────────────────────────────
        T_max    = _tmax_local(u)
        fos_t    = T_max > 0.0 ? TETHER_SWL / T_max : Inf
        α_vec    = u[6N+1 : 6N+Nr]
        sf       = ring_safety_frame(u, α_vec, sys, p)
        max_util = isempty(sf) ? 0.0 : maximum(r.utilisation for r in sf)
        fos_r    = max_util > 0.0 ? 1.0 / max_util : Inf
        n_slack  = _nslack_local(u)
        max_sag, sag_seg = _max_sag_mm(u, sys, p, perp1, perp2)

        t_frame_lbl.text[] = @sprintf("  max %5.0f N  ·  FoS %s", T_max, fos_str(fos_t))
        c_frame_lbl.text[] = @sprintf("  max util %4.1f%%  ·  FoS %s",
                                        max_util*100.0, fos_str(fos_r))
        sag_lbl.text[]     = @sprintf("Max rope sag %5.1f mm  (seg %2d)  |  slack: %d lines",
                                        max_sag, sag_seg, n_slack)

        # TORSIONAL COLLAPSE: hub twist > 270° indicates rope approaching wrap limit
        warn_tors.text[]  = abs(Δα_deg) > 270.0 ? "!! TORSIONAL OVERTWIST" : ""
        warn_buck.text[]  = max_util > 0.8        ? "!! BUCKLING RISK"       : ""
        warn_slack.text[] = n_slack > 0 ?
                            @sprintf("!! LINE SLACK: %d lines", n_slack) : ""
    end

    # Compact HUD row spacing so all rows fit within 950 px
    rowgap!(hud, 2)

    # ── Controls (left column) ────────────────────────────────────────────────
    colsize!(ctrl, 1, Fixed(280))

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

    # ── SECTION L: Lift Device ────────────────────────────────────────────────
    # Two adaptive sliders whose meaning changes with the selected device type.
    # Slider A: Area (kites) or ω (rotary) — the dominant sizing parameter.
    # Slider B: CL (kites) or Rotor radius (rotary) — the performance lever.
    clbl("── Lift Device ──────────────────────────"; fontsize=12, font=:bold)

    device_menu = Menu(ctrl[cnr!(), 1];
                       options=["None", "Single Kite", "Stacked ×3", "Rotary Lifter"],
                       default="None", width=270)

    # Slider A  ─  Area / N kites / ω
    ld_slA_row = GridLayout(ctrl[cnr!(), 1])
    ld_lbl_A   = Label(ld_slA_row[1,1], "Area (m²)"; halign=:left, fontsize=10, color=:grey70)
    ld_sl_A    = Slider(ld_slA_row[1,2]; range=5.0:1.0:50.0, startvalue=15.0)
    ld_val_A   = Label(ld_slA_row[1,3], "15 m²"; halign=:left, fontsize=10, color=:grey60, tellwidth=false)

    # Slider B  ─  CL / CL / Rotor radius
    ld_slB_row = GridLayout(ctrl[cnr!(), 1])
    ld_lbl_B   = Label(ld_slB_row[1,1], "Lift CL";   halign=:left, fontsize=10, color=:grey70)
    ld_sl_B    = Slider(ld_slB_row[1,2]; range=0.5:0.05:2.5, startvalue=1.2)
    ld_val_B   = Label(ld_slB_row[1,3], "1.20"; halign=:left, fontsize=10, color=:grey60, tellwidth=false)

    # Reconfigure slider ranges + labels when device type changes
    function _reconfigure_ld_sliders!(choice)
        if choice == "Single Kite" || choice == "Stacked ×3"
            ld_lbl_A.text[] = choice == "Single Kite" ? "Area (m²)" : "N kites"
            ld_sl_A.range[] = choice == "Single Kite" ? (5.0:1.0:50.0) : (2.0:1.0:10.0)
            ld_sl_A.value[] = choice == "Single Kite" ? 15.0 : 3.0
            ld_lbl_B.text[] = "Lift CL"
            ld_sl_B.range[] = 0.5:0.05:2.5
            ld_sl_B.value[] = 1.2
        elseif choice == "Rotary Lifter"
            ld_lbl_A.text[] = "ω (rad/s)"
            ld_sl_A.range[] = 10.0:5.0:80.0
            ld_sl_A.value[] = 40.0
            ld_lbl_B.text[] = "Radius (m)"
            ld_sl_B.range[] = 0.5:0.1:3.0
            ld_sl_B.value[] = 1.0
        end
    end

    on(ld_sl_A.value) do v
        choice = device_menu.selection[]
        ld_val_A.text[] = (choice == "Stacked ×3")  ? string(round(Int, v)) :
                          (choice == "Rotary Lifter") ? @sprintf("%.0f r/s", v) :
                                                        @sprintf("%.0f m²",  v)
    end
    on(ld_sl_B.value) do v
        choice = device_menu.selection[]
        ld_val_B.text[] = (choice == "Rotary Lifter") ? @sprintf("%.1f m", v) :
                                                         @sprintf("%.2f",   v)
    end

    # Rebuild lift_device_obs whenever type or either slider changes
    function _update_lift_device!(choice)
        a = ld_sl_A.value[]; b = ld_sl_B.value[]
        lift_device_obs[] = if choice == "Single Kite"
            SingleKiteParams(CL=b, CD=0.12, area=a,
                             line_length=25.0, line_EA=1.5e5, m_kite=3.0)
        elseif choice == "Stacked ×3"
            StackedKitesParams(n_kites=round(Int,a), CL=b, CD=0.12,
                               area_each=8.0, spacing=8.0,
                               line_EA=1.5e5, m_kite_each=2.0)
        elseif choice == "Rotary Lifter"
            RotaryLifterParams(rotor_radius=b, hub_radius=0.05, n_blades=3,
                               blade_chord=0.12, CL_blade=1.2, CD_blade=0.02,
                               omega_fixed=a, line_length=25.0,
                               line_EA=1.5e5, m_lifter=5.0)
        else
            nothing
        end
    end

    on(device_menu.selection) do choice
        _reconfigure_ld_sliders!(choice)
        _update_lift_device!(choice)
    end
    on(ld_sl_A.value) do _; _update_lift_device!(device_menu.selection[]); end
    on(ld_sl_B.value) do _; _update_lift_device!(device_menu.selection[]); end

    # Wire up kite-drop precheck now that device_menu exists.
    # If no lift device is selected when Kite Drop is clicked, auto-select Single Kite —
    # without a lift device the hub has no upward support and the scenario is physically meaningless.
    _kite_drop_precheck![] = () -> begin
        if isnothing(lift_device_obs[])
            device_menu.selection[] = "Single Kite"   # triggers _reconfigure_ld_sliders! + _update_lift_device!
            scenario_msg_color[] = :steelblue
            scenario_msg[]       = "ℹ  Auto-selected Single Kite lifter (required for kite drop)"
        end
    end

    clbl(""; fontsize=4)   # visual spacer

    # ── SECTION A: Run Parameters ─────────────────────────────────────────────
    # These two sliders are snapshotted at the start of every scenario run via
    # _modified_params().  Wind speed V_ref is set in the Scenarios panel (HUD).
    clbl("── Run Parameters ──────────────────────"; fontsize=12, font=:bold)

    # MPPT gain — sets the quadratic generator load curve (τ = k × ω²)
    clbl("MPPT gain k_mppt"; fontsize=11)
    sl_kmppt = cslider!(1.0:1.0:50.0; start=clamp(p.k_mppt, 1.0, 50.0))
    vl_kmppt = cval_lbl!(@sprintf("%.1f N·m·s²/rad²", p.k_mppt))
    on(sl_kmppt.value) do v; vl_kmppt.text[] = @sprintf("%.1f N·m·s²/rad²", v); end

    # Elevation angle — shaft tilt; trades rotor power (cos³β) for vertical lift
    clbl("Elevation β (deg)"; fontsize=11)
    sl_beta = cslider!(15.0:1.0:70.0; start=clamp(rad2deg(p.elevation_angle), 15.0, 70.0))
    vl_beta = cval_lbl!(@sprintf("β = %.1f°", rad2deg(p.elevation_angle)))
    on(sl_beta.value) do v
        vl_beta.text[] = @sprintf("β = %.1f°", v)
        elev_lbl.text[] = @sprintf("Elevation  β = %5.1f°  |  Rated %.0f kW",
                                    v, p.p_rated_w/1000.0)
    end

    # ── SECTION B: Playback ───────────────────────────────────────────────────
    clbl(""; fontsize=6)
    clbl("── Playback ────────────────────────────"; fontsize=12, font=:bold)

    if !isnothing(times)
        Label(ctrl[cnr!(), 1],
              @sprintf("Simulation: %.2f – %.2f s  (%d frames)", times[1], times[end], n_frames);
              halign=:left, fontsize=10, color=:grey60, tellwidth=false)
    end

    # Frame scrubber — drag to inspect any point in the simulation
    frame_slider = Slider(ctrl[cnr!(), 1]; range=1:n_frames, startvalue=1)
    connect!(frame_obs, frame_slider.value)

    # Play / Pause with speed selection
    pb_row = GridLayout(ctrl[cnr!(), 1])
    play_btn  = Button(pb_row[1, 1]; label="▶ Play",  buttoncolor=:darkgreen, labelcolor=:white)
    is_playing = Observable(false)
    speed_obs  = Observable(1.0)

    Menu(pb_row[1, 2]; options=["0.25×","0.5×","1×","2×","4×"], default="1×") |> m ->
        on(m.selection) do s
            speed_obs[] = s=="0.25×" ? 0.25 : s=="0.5×" ? 0.5 :
                          s=="2×"    ? 2.0  : s=="4×"   ? 4.0 : 1.0
        end

    on(play_btn.clicks) do _
        is_playing[] = !is_playing[]
        play_btn.label[]       = is_playing[] ? "|| Pause" : "▶ Play"
        play_btn.buttoncolor[] = is_playing[] ? :darkorange : :darkgreen
    end

    @async while true
        if is_playing[]
            nf = min(frame_slider.value[] + 1, length(frames_ref[]))
            set_close_to!(frame_slider, nf)
            if nf == length(frames_ref[])
                is_playing[] = false
                play_btn.label[]       = "▶ Play"
                play_btn.buttoncolor[] = :darkgreen
            end
        end
        sleep(1 / 30 / speed_obs[])
    end

    # ── SECTION C: Actions ────────────────────────────────────────────────────
    clbl(""; fontsize=6)
    clbl("── Actions ─────────────────────────────"; fontsize=12, font=:bold)

    # Export Force CSV — writes per-node force vector at the current frame
    act_row1 = GridLayout(ctrl[cnr!(), 1])
    Button(act_row1[1, 1]; label="Export Forces", buttoncolor=:purple,
           labelcolor=:white, height=30) |> b ->
        on(b.clicks) do _
            fi = frame_obs[]; u = frames_ref[][fi]
            du = zeros(Float64, length(u))
            wf = isnothing(wind_fn) ? (pos, t) -> [p.v_wind_ref, 0.0, 0.0] : wind_fn
            multibody_ode!(du, u, (sys, p, wf), 0.0)
            fname = @sprintf("force_frame_%04d.csv", fi)
            open(fname, "w") do io
                println(io, "node_id,type,fx,fy,fz")
                for i in 1:N
                    nd = sys.nodes[i]; bp = 3*(i-1)+1
                    t_ = nd isa RingNode ? "ring" : "rope"
                    println(io, "$i,$t_,$(du[bp]),$(du[bp+1]),$(du[bp+2])")
                end
            end
            @info "Saved $fname"
        end

    # Export Node CSV — writes per-node position, velocity and tension at current frame
    Button(act_row1[1, 2]; label="Export Nodes", buttoncolor=:darkslateblue,
           labelcolor=:white, height=30) |> b ->
        on(b.clicks) do _
            fi = frame_obs[]; u = frames_ref[][fi]
            fname = @sprintf("nodes_frame_%04d.csv", fi)
            open(fname, "w") do io
                println(io, "node_id,type,x,y,z,vx,vy,vz,tension_N")
                for i in 1:N
                    nd = sys.nodes[i]; bp = 3*(i-1)+1; bv = 3N+3*(i-1)+1
                    t_ = nd isa RingNode ? "ring" : "rope"
                    T  = nd isa RopeNode ? _mid_tension(u, sys, p, nd.seg_idx, nd.line_idx) : 0.0
                    println(io, "$i,$t_,$(u[bp]),$(u[bp+1]),$(u[bp+2])," *
                                "$(u[bv]),$(u[bv+1]),$(u[bv+2]),$T")
                end
            end
            @info "Saved $fname"
        end

    # Reset View — auto-fits the 3D camera to all node positions at current frame
    act_row2 = GridLayout(ctrl[cnr!(), 1])
    Button(act_row2[1, 1]; label="Reset View", buttoncolor=:grey40,
           labelcolor=:white, height=30) |> b ->
        on(b.clicks) do _
            u   = frames_ref[][frame_obs[]]
            xs  = [u[3*(i-1)+1] for i in 1:N]
            ys  = [u[3*(i-1)+2] for i in 1:N]
            zs  = [u[3*(i-1)+3] for i in 1:N]
            pad = 0.4
            dx  = (maximum(xs) - minimum(xs)) * pad
            dy  = (maximum(ys) - minimum(ys)) * pad
            dz  = (maximum(zs) - minimum(zs)) * pad
            ax3d.limits[] = (minimum(xs)-dx, maximum(xs)+dx,
                             minimum(ys)-dy, maximum(ys)+dy,
                             minimum(zs)-dz, maximum(zs)+dz)
        end

    # Re-run ODE — repeats the full simulation with current slider parameters
    # Locked by default to prevent accidental long recomputes
    unlock_toggle = Toggle(act_row2[1, 2])
    Label(act_row2[1, 3], "unlock re-run"; halign=:left, fontsize=10, color=:grey60)

    rerun_btn = Button(ctrl[cnr!(), 1]; label="Re-run ODE [locked]",
                       buttoncolor=:grey30, labelcolor=:grey60, height=30)
    on(rerun_btn.clicks) do _
        if !unlock_toggle.active[]
            scenario_msg[] = "Toggle 'unlock re-run' first"; return
        end
        _rerun!(:steady, "Re-run Steady", scen_vref_slider.value[])
    end
    on(unlock_toggle.active) do v
        rerun_btn.label[]       = v ? "Re-run ODE [open]" : "Re-run ODE [locked]"
        rerun_btn.labelcolor[]  = v ? :white  : :grey60
        rerun_btn.buttoncolor[] = v ? :darkgreen : :grey30
    end

    # Compact Controls row spacing to match HUD
    rowgap!(ctrl, 2)

    # ── Initial notify ────────────────────────────────────────────────────────
    notify(frame_obs)
    return fig
end

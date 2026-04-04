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
    frame_obs  = Observable(1)
    u_obs      = @lift frames[$frame_obs]
    frames_ref = Ref(frames)

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

    # Lift kite tether + kite marker
    kite_pos_obs = @lift begin
        lp   = $lift_point_obs
        γ_l  = p.lifter_elevation
        sh   = [shaft_dir[1], shaft_dir[2], 0.0]
        sh_hat = sh ./ max(sqrt(shaft_dir[1]^2 + shaft_dir[2]^2), 1e-6)
        lp .+ 25.0 .* (sh_hat .* cos(γ_l) .+ [0.0, 0.0, sin(γ_l)])
    end
    kite_tether_obs = @lift begin
        lp = $lift_point_obs; kt = $kite_pos_obs
        ([lp[1], kt[1]], [lp[2], kt[2]], [lp[3], kt[3]])
    end
    lines!(ax3d, @lift($kite_tether_obs[1]), @lift($kite_tether_obs[2]),
                 @lift($kite_tether_obs[3]); color=:deepskyblue, linewidth=2.0)
    scatter!(ax3d, @lift([$kite_pos_obs[1]]), @lift([$kite_pos_obs[2]]),
                   @lift([$kite_pos_obs[3]]); color=:deepskyblue, markersize=15)

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

    scenario_msg = Observable("")
    Label(hud[hnr!(), 1], scenario_msg; halign=:left, tellwidth=false,
          fontsize=10, color=:grey60)

    can_rerun = !isnothing(u_settled) && !isnothing(wind_fn)
    scen_color(c) = can_rerun ? c : :grey40

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
        else   # :land
            (pos, t) -> begin
                v = t < 30.0 ? vref*(1.0-t*0.9/30.0) : vref*0.1*max(0.0,1.0-(t-30.0)/10.0)
                z = max(pos[3], 1.0); [v * (z/p.h_ref)^(1/7), 0.0, 0.0]
            end
        end
    end

    function _rerun!(scenario, label, vref)
        can_rerun || begin scenario_msg[] = "⚠ provide u_settled & wind_fn to enable"; return end
        n_steps = 250_000; dt = 4e-5; t_total = n_steps * dt
        wf  = _make_wind(vref, scenario, t_total)
        u_s = copy(u_settled)
        # Ensure orbital velocities are set for the current ω profile
        set_orbital_velocities!(u_s, sys, p)
        scenario_msg[] = "Running $label …"
        @async begin
            new_frames = Vector{Vector{Float64}}(undef, n_steps ÷ 500)
            new_times  = Vector{Float64}(undef, n_steps ÷ 500)
            u  = copy(u_s); du = zeros(Float64, length(u))
            t  = 0.0; fi = 1
            for step in 1:n_steps
                fill!(du, 0.0)
                multibody_ode!(du, u, (sys, p, wf), t)
                t += dt
                @views u[3N+1:6N]        .+= dt .* du[3N+1:6N]
                @views u[1:3N]            .+= dt .* u[3N+1:6N]
                @views u[6N+Nr+1:6N+2Nr] .+= dt .* du[6N+Nr+1:6N+2Nr]
                @views u[6N+1:6N+Nr]     .+= dt .* u[6N+Nr+1:6N+2Nr]
                # Use orbital-frame damping — preserves rotational kinematics
                orbital_damp_rope_velocities!(u, sys, p, 0.05)
                u[1:3] .= 0.0; u[3N+1:3N+3] .= 0.0
                if step % 500 == 0
                    new_frames[fi] = copy(u); new_times[fi] = t; fi += 1
                end
            end
            frames_ref[] = new_frames
            notify(frame_obs)
            scenario_msg[] = "$label done  ($(length(new_frames)) frames)"
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

    scen_btns = GridLayout(hud[hnr!(), 1])
    Button(scen_btns[1,1]; label="Steady",   buttoncolor=scen_color(:darkgreen),
           labelcolor=:white, height=28) |> b ->
        on(b.clicks) do _; _rerun!(:steady,    "Steady",    scen_vref_slider.value[]); end
    Button(scen_btns[1,2]; label="Ramp Up",  buttoncolor=scen_color(:steelblue),
           labelcolor=:white, height=28) |> b ->
        on(b.clicks) do _; _rerun!(:ramp_up,   "Ramp-Up",   scen_vref_slider.value[]); end
    Button(scen_btns[1,3]; label="Ramp Down",buttoncolor=scen_color(:darkorange),
           labelcolor=:white, height=28) |> b ->
        on(b.clicks) do _; _rerun!(:ramp_down, "Ramp-Down", scen_vref_slider.value[]); end
    Button(scen_btns[2,1]; label="Gust",     buttoncolor=scen_color(:firebrick),
           labelcolor=:white, height=28) |> b ->
        on(b.clicks) do _; _rerun!(:gust,      "Gust",      scen_vref_slider.value[]); end
    Button(scen_btns[2,2]; label="Launch",   buttoncolor=scen_color(:mediumpurple),
           labelcolor=:white, height=28) |> b ->
        on(b.clicks) do _; _rerun!(:launch,    "Launch",    scen_vref_slider.value[]); end
    Button(scen_btns[2,3]; label="Land",     buttoncolor=scen_color(:saddlebrown),
           labelcolor=:white, height=28) |> b ->
        on(b.clicks) do _; _rerun!(:land,      "Land",      scen_vref_slider.value[]); end

    # ── HUD update handler ────────────────────────────────────────────────────
    on(frame_obs) do fi
        u = frames_ref[][fi]

        # ── Telemetry ────────────────────────────────────────────────────────
        omega_hub = u[6N + Nr + Nr]            # hub (rotor) angular velocity
        omega_gnd = u[6N + Nr + 1]             # ground ring (PTO) angular velocity
        rpm_hub   = omega_hub * 60.0 / (2π)
        rpm_gnd   = omega_gnd * 60.0 / (2π)
        P_kw      = p.k_mppt * omega_gnd^2 * abs(omega_gnd) / 1000.0
        pct_rated = p.p_rated_w > 0 ? P_kw*1000.0/p.p_rated_w*100.0 : 0.0
        hub_ctr   = u[3*(hub_gid-1)+1 : 3*hub_gid]
        z_hub     = max(hub_ctr[3], 1.0)
        V_hub     = p.v_wind_ref * (z_hub / p.h_ref)^(1.0/7.0)
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

        t_lbl.text[] = if isnothing(times)
            @sprintf("Frame %5d / %d", fi, n_frames)
        else
            @sprintf("t = %8.2f s  (frame %5d / %d)", times[fi], fi, n_frames)
        end
        v_lbl.text[]        = @sprintf("Wind at hub    V = %6.2f m/s", V_hub)
        omega_lbl.text[]    = @sprintf("Rotor (hub)    ω = %7.3f rad/s  (%6.1f rpm)",
                                        omega_hub, rpm_hub)
        pto_lbl.text[]      = @sprintf("PTO (ground)   ω = %7.3f rad/s  (%6.1f rpm)",
                                        omega_gnd, rpm_gnd)
        p_lbl.text[]        = @sprintf("Output power   P = %6.2f kW  (%3.0f%% rated)",
                                        P_kw, pct_rated)
        tsr_lbl.text[]      = @sprintf("Tip speed ratio  λ = %5.2f  (opt ≈ 4.1)", tsr)
        twist_lbl.text[]    = @sprintf("TRPT twist  Δα = %7.1f°  (hub – PTO)", Δα_deg)
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

    # ── SECTION A: Parameters ─────────────────────────────────────────────────
    # These sliders configure the NEXT scenario run — they do NOT live-edit the
    # current simulation (which is already recorded as frames).
    clbl("── Parameters (for next run) ────────────"; fontsize=12, font=:bold)

    # Reference wind speed — scales the full Hellmann wind profile
    clbl("Wind speed V_ref (m/s)"; fontsize=11)
    sl_vref  = cslider!(0.0:0.5:25.0; start=p.v_wind_ref)
    vl_vref  = cval_lbl!(@sprintf("%.1f m/s", p.v_wind_ref))
    on(sl_vref.value) do v; vl_vref.text[] = @sprintf("%.1f m/s", v); end

    # MPPT gain — sets the quadratic generator load curve (τ = k × ω²)
    clbl("MPPT gain k_mppt"; fontsize=11)
    sl_kmppt = cslider!(1.0:1.0:50.0; start=clamp(p.k_mppt, 1.0, 50.0))
    vl_kmppt = cval_lbl!(@sprintf("%.1f N·m·s²/rad²", p.k_mppt))
    on(sl_kmppt.value) do v; vl_kmppt.text[] = @sprintf("%.1f N·m·s²/rad²", v); end

    # Kite CL — lifter kite lift coefficient (affects vertical equilibrium force)
    clbl("Kite CL (lifter)"; fontsize=11)
    sl_cl = cslider!(0.5:0.05:2.5; start=clamp(sys.kite.CL, 0.5, 2.5))
    vl_cl = cval_lbl!(@sprintf("CL = %.2f", sys.kite.CL))
    on(sl_cl.value) do v
        vl_cl.text[]  = @sprintf("CL = %.2f", v)
        kite_lbl.text[] = @sprintf("Kite  CL = %4.2f  CD = %4.2f  |  A = %.1f m²",
                                    v, sl_cd.value[], sys.kite.area)
    end

    # Kite CD — lifter kite drag coefficient (downwind force, reduces effective lift)
    clbl("Kite CD (lifter)"; fontsize=11)
    sl_cd = cslider!(0.01:0.01:0.5; start=clamp(sys.kite.CD, 0.01, 0.5))
    vl_cd = cval_lbl!(@sprintf("CD = %.2f", sys.kite.CD))
    on(sl_cd.value) do v
        vl_cd.text[]  = @sprintf("CD = %.2f", v)
        kite_lbl.text[] = @sprintf("Kite  CL = %4.2f  CD = %4.2f  |  A = %.1f m²",
                                    sl_cl.value[], v, sys.kite.area)
    end

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
        _rerun!(:steady, "Re-run Steady", sl_vref.value[])
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

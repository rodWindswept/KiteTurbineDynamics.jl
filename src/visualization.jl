# src/visualization.jl
# GLMakie interactive dashboard for KiteTurbineDynamics.jl.
# Layout: 1600 × 950  |  Left 300 px Controls  |  Centre 3D  |  Right 370 px HUD
# Usage:  fig, config_changed = build_dashboard(sys, p, frames; times=t_vec)
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
function _rope_line_pts(u, sys, p, s, j)
    N     = sys.n_total
    gid_a = sys.ring_ids[s]
    gid_b = sys.ring_ids[s + 1]
    na    = sys.nodes[gid_a]::RingNode
    nb    = sys.nodes[gid_b]::RingNode
    ctr_a = u[3*(gid_a-1)+1 : 3*gid_a]
    ctr_b = u[3*(gid_b-1)+1 : 3*gid_b]
    α_a   = u[6N + na.ring_idx]
    α_b   = u[6N + nb.ring_idx]
    pp1, pp2 = _tilted_ring_basis(u, sys, sys.rotor.node_id,
                                   (sys.nodes[sys.rotor.node_id]::RingNode).ring_idx)
    pa    = attachment_point(ctr_a, na.radius, α_a, j, p.n_lines, pp1, pp2)
    pb    = attachment_point(ctr_b, nb.radius, α_b, j, p.n_lines, pp1, pp2)
    pts   = Vector{Vector{Float64}}(undef, 5)
    pts[1] = pa
    # Compute stride from p.n_lines (not hardcoded: 5→16, 8→25)
    _stride = 1 + p.n_lines * 3
    for m in 1:3
        gid      = (s-1)*_stride + 2 + (j-1)*3 + (m-1)
        pts[m+1] = u[3*(gid-1)+1 : 3*gid]
    end
    pts[5] = pb
    ([pt[1] for pt in pts], [pt[2] for pt in pts], [pt[3] for pt in pts])
end

"""Tension of the middle (rope→rope) sub-segment for tether line j of segment s."""
function _mid_tension(u, sys, p, s, j)
    return get_segment_tension(u, sys, p, s, j)
end

function _tether_max(u, sys, p)
    return get_max_rope_tension(u, sys, p)[1]
end

"""Count slack tether lines (T < 5 N)."""
function _n_slack_lines(u, sys, p)
    return get_max_rope_tension(u, sys, p)[2]
end


"""Maximum mid-rope sag (mm) across all 15 segments, line 1."""
function _max_sag_mm(u, sys, p)
    N   = sys.n_total
    hub_gid  = sys.rotor.node_id
    hub_ri   = (sys.nodes[hub_gid]::RingNode).ring_idx
    pp1, pp2 = _tilted_ring_basis(u, sys, hub_gid, hub_ri)
    best = 0.0; best_seg = 1
    for s in 1:(sys.n_ring-1)
        gid_a = sys.ring_ids[s];   gid_b = sys.ring_ids[s+1]
        na = sys.nodes[gid_a]::RingNode; nb = sys.nodes[gid_b]::RingNode
        ctr_a = u[3*(gid_a-1)+1:3*gid_a]; ctr_b = u[3*(gid_b-1)+1:3*gid_b]
        pa = attachment_point(ctr_a, na.radius, u[6N+na.ring_idx], 1, p.n_lines, pp1, pp2)
        pb = attachment_point(ctr_b, nb.radius, u[6N+nb.ring_idx], 1, p.n_lines, pp1, pp2)
        gid_mid = (s-1)*(1 + p.n_lines*3) + 3
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
    build_dashboard(sys, p, frames; times, u_settled, wind_fn, config_name) → (Figure, Observable)

Build a GLMakie interactive dashboard from ODE state snapshots.

Returns `(fig, config_changed_obs)` where `config_changed_obs` is an
Observable{Union{String,Nothing}} — `nothing` while normal, set to a config
name when the user requests a configuration switch.

Layout (1600 × 950, dark theme):
  Left  300 px — Controls: Config · Lift Device · Parameters · Playback
  Centre        — 3D viewport: TRPT kite turbine + wind arrow
  Right 370 px  — HUD: Telemetry · Torque · Structural · Peaks · Scenarios
"""
function build_dashboard(sys       ::KiteTurbineSystem,
                          p         ::SystemParams,
                          frames    ::Vector{<:AbstractVector};
                          times     ::Union{Vector{Float64}, Nothing}   = nothing,
                          u_settled ::Union{Vector{Float64}, Nothing}   = nothing,
                          wind_fn   ::Union{Function, Nothing}          = nothing,
                          config_name::String = "Canonical 5-line")

    n_frames = length(frames)
    n_seg    = sys.n_ring - 1
    N        = sys.n_total
    Nr       = sys.n_ring

    hub_gid  = sys.ring_ids[Nr]
    hub_node = sys.nodes[hub_gid]::RingNode
    hub_R    = hub_node.radius
    hub_ri   = hub_node.ring_idx

    # ── Ring-plane basis: tilted (matches TRPT physics) ──────────────────────
    # All intermediate rings, the hub, and the rotor blades render in the tilted
    # frame to align with the tether geometry and visualize furl pitching.
    _perp_fn = (u) -> begin
        _tilted_ring_basis(u, sys, hub_gid, hub_ri)
    end

    _seg_T = (u, s, j) -> get_segment_tension(u, sys, p, s, j)
    _tmax_local   = u -> get_max_rope_tension(u, sys, p)[1]
    _nslack_local = u -> get_max_rope_tension(u, sys, p)[2]

    l_seg = p.tether_length / n_seg

    tension_cmap = cgrad([RGBf(0.0, 0.2, 1.0), RGBf(0.0, 0.8, 0.2),
                          RGBf(1.0, 0.5, 0.0), RGBf(1.0, 0.0, 0.0)],
                          [0.0, 0.5, 0.8, 1.0])
    ring_cmap    = cgrad([RGBf(0.0, 0.0, 1.0), RGBf(0.0, 1.0, 1.0),
                          RGBf(1.0, 0.5, 0.0), RGBf(1.0, 0.0, 0.0)],
                          [0.0, 0.5, 0.8, 1.0])

    # ── Pre-compute run-wide peaks via SimFrame capture ────────────────────────
    # Capture all frames once; SimPeaks aggregates run-wide maxima.
    # SimFrames are also stored for the HUD update handler to read from.
    sim_frames = [capture_frame(u_f, sys, p,
                   isnothing(times) ? 0.0 : times[i],
                   isnothing(wind_fn) ? (pos, t) -> [p.v_wind_ref, 0.0, 0.0] : wind_fn,
                   nothing)  # lift device configured later
                  for (i, u_f) in enumerate(frames)]
    peaks      = capture_peaks(sim_frames)
    T_peak     = peaks.T_peak
    omega_peak = peaks.omega_peak
    P_peak     = peaks.P_peak
    V_peak     = peaks.V_peak
    slack_events = peaks.slack_events
    sim_frames_obs = Observable(sim_frames)  # mirrors frames — updated by _rerun!

    # ── Observables ──────────────────────────────────────────────────────────
    frame_obs       = Observable(1)
    frames_obs      = Observable(frames)          # mutable — updated by every _rerun!
    times_ref       = Ref(isnothing(times) ? Float64[] : collect(times))
    u_obs           = @lift $frames_obs[$frame_obs]   # reacts to BOTH frame index AND new frames
    lift_device_obs = Observable{Union{Nothing, LiftDevice}}(
        RotaryLifterParams(3.7, 0.05, 3, 0.12, 1.0, 0.20, 40.0, 25.0, 1.5e5, 5.0))
    wind_fn_obs     = Observable{Function}(isnothing(wind_fn) ?
                          (pos, t) -> [p.v_wind_ref, 0.0, 0.0] : wind_fn)

    # ── Layer visibility toggles ────────────────────────────────────────────
    vis_tethers  = Observable(true)   # TRPT tension-coloured tether lines
    vis_rings    = Observable(true)   # intermediate ring polygons
    vis_hub      = Observable(true)   # hub ring + rotor blades
    vis_bridles  = Observable(true)   # gold bridle lines (bearing→hub)
    vis_bearing  = Observable(true)   # white diamond bearing marker
    vis_lift     = Observable(true)   # lift kite tether + kite marker
    vis_backline = Observable(true)   # backline catenary
    vis_ground   = Observable(true)   # ground grid + anchor

    # ── Configuration switching & safety state machine ────────────────────────
    config_changed_obs = Observable{Union{String, Nothing}}(nothing)  # nil = no change pending
    system_state_obs   = Observable{Symbol}(:idle)   # :idle | :simulating | :switching
    build_status_obs   = Observable("")              # shown during transitions
    _is_safe()         = (system_state_obs[] == :idle)

    # ── Figure — A1 Instrument dark theme ─────────────────────────────────────
    # Palette: near-black background, cyan accent, light-grey ink
    A1_BG        = RGBf(0.039, 0.047, 0.063)
    A1_PANEL     = RGBf(0.071, 0.086, 0.114)
    A1_EDGE      = RGBf(0.133, 0.165, 0.208)
    A1_INK       = RGBf(0.910, 0.933, 0.965)
    A1_INK_DIM   = RGBf(0.604, 0.655, 0.714)
    A1_ACCENT    = RGBf(0.224, 0.816, 0.847)
    A1_GREEN     = RGBf(0.2, 0.8, 0.3)
    A1_ORANGE    = RGBf(0.95, 0.55, 0.1)
    A1_RED       = RGBf(0.95, 0.2, 0.2)

    set_theme!(theme_dark())
    fig_w, fig_h = 1400, 850  # fits 15" laptop screens
    fig = Figure(size=(fig_w, fig_h), backgroundcolor=A1_BG)

    # ── Main content: controls | 3D viewport | HUD ────────────────────────────
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
               color=(:grey, 0.3), linewidth=0.5, visible=vis_ground)
    end
    for y in -25:5:25
        lines!(ax3d, [-20.0, 60.0], [float(y), float(y)], [0.0, 0.0];
               color=(:grey, 0.3), linewidth=0.5, visible=vis_ground)
    end

    # Ground anchor
    scatter!(ax3d, [0.0], [0.0], [0.0]; color=:limegreen, markersize=20,
             visible=vis_ground)

    # Tether lines — tension-coloured
    for s in 1:n_seg, j in 1:p.n_lines
        lo   = @lift _rope_line_pts($u_obs, sys, p, s, j)
        T_ob = @lift _seg_T($u_obs, s, j)
        co   = @lift _tension_color($T_ob, TETHER_SWL)
        lw   = @lift ($T_ob < 5.0 ? 0.8f0 : 1.5f0)
        lines!(ax3d, @lift($lo[1]), @lift($lo[2]), @lift($lo[3]);
               color=co, linewidth=lw, visible=vis_tethers)
    end

    # Intermediate ring polygons — per-beam utilisation colour
    for k in 2:(Nr-1)
        gid_k = sys.ring_ids[k]
        nk    = sys.nodes[gid_k]::RingNode
        R_k   = nk.radius
        ri_k  = nk.ring_idx
        for j in 1:p.n_lines
            j_next = mod1(j + 1, p.n_lines)
            edge_obs = @lift begin
                u    = $u_obs
                ctr  = u[3*(gid_k-1)+1 : 3*gid_k]
                α    = u[6N + ri_k]
                pp1, pp2 = _perp_fn(u)
                pa = attachment_point(ctr, R_k, α, j,      p.n_lines, pp1, pp2)
                pb = attachment_point(ctr, R_k, α, j_next, p.n_lines, pp1, pp2)
                ([pa[1], pb[1]], [pa[2], pb[2]], [pa[3], pb[3]])
            end
            ec = @lift begin
                sfs  = $sim_frames_obs
                fi   = $frame_obs
                util = (fi <= length(sfs) &&
                        k-1 <= length(sfs[fi].ring_beam_utils) &&
                        j   <= length(sfs[fi].ring_beam_utils[k-1])) ?
                       sfs[fi].ring_beam_utils[k-1][j] : 0.0
                _ring_util_color(util)
            end
            lines!(ax3d, @lift($edge_obs[1]), @lift($edge_obs[2]), @lift($edge_obs[3]);
                   color=ec, linewidth=2.0, visible=vis_rings)
        end
    end

    # Expansion rotor ring markers — cyan dots at rings with expansion rotors
    if !isempty(sys.expansion_rotors)
        exp_ring_ids = [er.ring_idx for er in sys.expansion_rotors]
        for ri in exp_ring_ids
            if ri < 1 || ri > Nr; continue; end
            gid = sys.ring_ids[ri]
            pos_obs = @lift begin
                u = $u_obs
                u[(3*(gid-1)+1):(3*gid)]
            end
            scatter!(ax3d,
                @lift([$pos_obs[1]]), @lift([$pos_obs[2]]), @lift([$pos_obs[3]]);
                color=:cyan, markersize=12, marker=:diamond,
                visible=vis_rings)
        end
    end

    # Hub (rotor) ring — firebrick, thicker
    hub_ring_obs = @lift begin
        u   = $u_obs
        ctr = u[3*(hub_gid-1)+1 : 3*hub_gid]
        α   = u[6N + hub_ri]
        pp1, pp2 = _perp_fn(u)
        jj  = [1:p.n_lines; 1]
        pts = [attachment_point(ctr, hub_R, α, jj[i], p.n_lines, pp1, pp2)
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
            pp1, pp2 = _perp_fn(u)
            r_dir = cos(φ) .* pp1 .+ sin(φ) .* pp2
            c_dir = -sin(φ) .* pp1 .+ cos(φ) .* pp2
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

    # ── Expansion rotor blades ──────────────────────────────────────────────
    if !isempty(sys.expansion_rotors)
        hub_gid_val = hub_gid
        ground_gid_val = sys.ring_ids[1]
        for (ei, er) in enumerate(sys.expansion_rotors)
            ri_val = er.ring_idx
            if ri_val < 1 || ri_val > sys.n_ring; continue; end
            ring_gid_val = sys.ring_ids[ri_val]
            ring_node = sys.nodes[ring_gid_val]
            ring_R_val = ring_node.radius
            r_outer_val = ring_R_val + er.blade_tip_radius
            bank_rad_val = deg2rad(er.bank_angle_deg)
            n_blades_val = er.n_blades
            for b in 1:n_blades_val
                b_val = b
                exp_blade_obs = @lift begin
                    uu = $u_obs
                    ctr  = @view uu[(3*(ring_gid_val-1)+1):(3*ring_gid_val)]
                    hub  = @view uu[(3*(hub_gid_val-1)+1):(3*hub_gid_val)]
                    gnd  = @view uu[(3*(ground_gid_val-1)+1):(3*ground_gid_val)]
                    α_val  = uu[6N + ri_val]
                    φ_val  = α_val + (b_val - 1) * (2π / n_blades_val)
                    pp1, pp2 = _perp_fn(uu)
                    r_dir = cos(φ_val) .* pp1 .+ sin(φ_val) .* pp2
                    shaft_dir = normalize(Vector(gnd .- hub))
                    bank_dir = cos(bank_rad_val) .* r_dir .+ sin(bank_rad_val) .* shaft_dir
                    p_inner = Vector(ctr) .+ ring_R_val .* r_dir
                    p_outer = Vector(ctr) .+ r_outer_val .* bank_dir
                    ([p_inner[1], p_outer[1]], [p_inner[2], p_outer[2]], [p_inner[3], p_outer[3]])
                end
                lines!(ax3d, @lift($exp_blade_obs[1]), @lift($exp_blade_obs[2]),
                             @lift($exp_blade_obs[3]); color=:darkorange, linewidth=2.0)
            end
        end
    end

    # Lift system — bearing and sky anchor are real ODE particles.
    # Bearing only sees gravity, bridles, and the cyan line.  The sky anchor
    # (the splice/knot at the upper end of the cyan line) takes the kite
    # lift force at ~80° and the back line down to the ground anchor.
    bearing_gid_viz    = sys.bearing_id
    sky_anchor_gid_viz = sys.sky_anchor_id
    bearing_obs        = @lift $u_obs[3*(bearing_gid_viz-1)+1    : 3*bearing_gid_viz]
    sky_anchor_obs     = @lift $u_obs[3*(sky_anchor_gid_viz-1)+1 : 3*sky_anchor_gid_viz]
    # Kite tether and back line both attach at the sky anchor (matches physics)
    lift_point_obs     = sky_anchor_obs

    # Bridle lines: bearing → hub ring vertices (spring-dampers in the ODE)
    for j in 1:p.n_lines
        bridle_obs = @lift begin
            u    = $u_obs
            ctr  = u[3*(hub_gid-1)+1 : 3*hub_gid]
            α    = u[6N + hub_ri]
            hub_rmag  = norm(ctr)
            shaft_dir = hub_rmag > 0.1 ?
                        ctr ./ hub_rmag :
                        [cos(p.elevation_angle), 0.0, sin(p.elevation_angle)]
            pp1, pp2 = shaft_perp_basis(shaft_dir)
            node = attachment_point(ctr, hub_R, α, j, p.n_lines, pp1, pp2)
            bp   = $bearing_obs
            ([node[1], bp[1]], [node[2], bp[2]], [node[3], bp[3]])
        end
        lines!(ax3d, @lift($bridle_obs[1]), @lift($bridle_obs[2]),
                     @lift($bridle_obs[3]); color=:gold, linewidth=1.2)
    end

    # Cyan line: bearing → sky anchor (both live in the ODE state).
    # When the back line is paid out, the kite force lifts the sky anchor,
    # which pulls the bearing up via this line — visible as the whole
    # cyan-bearing-bridle assembly rising in unison.
    lift_line_obs = @lift begin
        bp = $bearing_obs
        ap = $sky_anchor_obs
        ([bp[1], ap[1]], [bp[2], ap[2]], [bp[3], ap[3]])
    end
    lines!(ax3d, @lift($lift_line_obs[1]), @lift($lift_line_obs[2]),
                 @lift($lift_line_obs[3]); color=:cyan, linewidth=2.0, visible=vis_lift)

    # Sky anchor marker — cyan circle at the live anchor position
    scatter!(ax3d, @lift([$sky_anchor_obs[1]]), @lift([$sky_anchor_obs[2]]),
                   @lift([$sky_anchor_obs[3]]); color=:cyan, markersize=12,
             marker=:circle, visible=vis_lift)

    # Bearing marker (white diamond)
    scatter!(ax3d, @lift([$bearing_obs[1]]), @lift([$bearing_obs[2]]),
                   @lift([$bearing_obs[3]]); color=:white, markersize=12,
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
        sh      = normalize(lp)  # bearing→ground direction ≈ shaft direction
        sh_horiz = [sh[1], sh[2], 0.0]
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

    # Back line — coral, from the SKY ANCHOR down to the fixed ground anchor.
    # Colour: coral = taut; grey = slack.  The geometric constants 6.0 and
    # 5.0 must match initialization.jl (bearing offset + cyan_L0) and the
    # back_L0_design in ring_forces.jl.
    let back_ax     = p.tether_length * cos(p.elevation_angle) + p.back_anchor_fwd_x,
        L_axis_des  = p.tether_length + 6.0 + 5.0,
        des_anc_x   = L_axis_des * cos(p.elevation_angle),
        des_anc_z   = L_axis_des * sin(p.elevation_angle),
        back_L0     = sqrt((des_anc_x - back_ax)^2 + des_anc_z^2)
        scatter!(ax3d, [back_ax], [0.0], [0.0]; color=:coral, markersize=12, marker=:diamond)
        back_line_obs = @lift begin
            ap   = $sky_anchor_obs
            bv   = (ap[1] - back_ax, ap[2], ap[3])
            taut = sqrt(bv[1]^2 + bv[2]^2 + bv[3]^2) > back_L0
            ([back_ax, ap[1]], [0.0, ap[2]], [0.0, ap[3]]), taut
        end
        lines!(ax3d,
               @lift($back_line_obs[1][1]), @lift($back_line_obs[1][2]),
               @lift($back_line_obs[1][3]);
               color=@lift(to_color($back_line_obs[2] ? :coral : :grey50)),
               linewidth=1.5)
    end

    # Wind indicator — blue-grey dots upwind of rotor, animated \"marching ants\"
    # Dots stream from 3 m upwind (clear of blades) fading toward far upwind.
    # Each dot gets a slight sinusoidal scatter in y, z so it looks organic.
    wind_dot_obs = @lift begin
        u       = $u_obs
        ctr     = u[3*(hub_gid-1)+1 : 3*hub_gid]
        z       = max(ctr[3], 1.0)
        wfn     = $wind_fn_obs
        v_vec   = wfn(ctr, 0.0)   # 3D wind at rotor
        v_mag   = sqrt(v_vec[1]^2 + v_vec[2]^2)
        v_mag   = max(v_mag, 0.5)   # minimum for visibility (1 dot per 0.5 m/s)
        n_dots  = 20
        fi      = $frame_obs
        flow    = mod(fi * 0.3, 1.0)   # marching offset 0→1 per 3 frames
        spacing = 0.5                  # m between adjacent dots
        xs = Float64[]; ys = Float64[]; zs = Float64[]
        alphas = Float64[]
        for i in 0:(n_dots-1)
            dist = 3.0 + i * spacing + flow * spacing  # 3 m clearance + dot spacing
            push!(xs, ctr[1] - dist)
            # Slight scatter: sin(i·1.7 + flow·π) adds organic variation
            push!(ys, ctr[2] + 0.15 * sin(i * 1.7 + flow * π))
            push!(zs, ctr[3] + 0.15 * cos(i * 2.3 + flow * π))
            # Fade from bold (near rotor) to near-transparent (far upwind)
            push!(alphas, 0.85 * (1.0 - i / n_dots))
        end
        (xs, ys, zs, alphas)
    end
    # 20 individual scatter calls so each dot has its own alpha
    wind_dots = [scatter!(ax3d,
        @lift([$wind_dot_obs[1][i+1]]),
        @lift([$wind_dot_obs[2][i+1]]),
        @lift([$wind_dot_obs[3][i+1]]);
        color=RGBf(0.50, 0.58, 0.72),
        markersize=@lift(4 + 3 * $wind_dot_obs[4][i+1]),
        alpha=@lift($wind_dot_obs[4][i+1]))
        for i in 0:19]

    # ── HUD (right column) ────────────────────────────────────────────────────
    # Fixed column width prevents label jitter as numbers change width
    colsize!(hud, 1, Fixed(350))

    # ── Cockpit telemetry — opens as a separate resizable window ──────────────
    strip_power    = Observable("0.00 kW")
    strip_rpm      = Observable("0 rpm")
    strip_fos      = Observable("∞")
    strip_fos_col  = Observable(A1_GREEN)
    strip_util     = Observable("0%")
    strip_util_col = Observable(A1_GREEN)
    strip_wind     = Observable("0.0 m/s")
    strip_time     = Observable("0.00 s")

    cockpit_fig = Figure(size=(900, 110), backgroundcolor=A1_BG)
    cp = GridLayout(cockpit_fig[1, 1])
    Label(cp[2, 1], "POWER kW";       fontsize=10, color=A1_INK_DIM, halign=:left)
    Label(cp[2, 2], "ROTOR rpm";      fontsize=10, color=A1_INK_DIM, halign=:left)
    Label(cp[2, 3], "TETHER FoS";     fontsize=10, color=A1_INK_DIM, halign=:left)
    Label(cp[2, 4], "RING BUCKLING";  fontsize=10, color=A1_INK_DIM, halign=:left)
    Label(cp[2, 5], "WIND m/s";       fontsize=10, color=A1_INK_DIM, halign=:left)
    Label(cp[2, 6], "ELEVATION";      fontsize=10, color=A1_INK_DIM, halign=:left)
    Label(cp[2, 7], "TIME";           fontsize=10, color=A1_INK_DIM, halign=:left)
    Label(cp[1, 1], strip_power;    fontsize=28, font=:bold, color=A1_INK,          halign=:left, tellwidth=false)
    Label(cp[1, 2], strip_rpm;      fontsize=28, font=:bold, color=A1_INK,          halign=:left, tellwidth=false)
    Label(cp[1, 3], strip_fos;      fontsize=28, font=:bold, color=strip_fos_col,   halign=:left, tellwidth=false)
    Label(cp[1, 4], strip_util;     fontsize=28, font=:bold, color=strip_util_col,  halign=:left, tellwidth=false)
    Label(cp[1, 5], strip_wind;     fontsize=28, font=:bold, color=A1_INK,          halign=:left, tellwidth=false)
    Label(cp[1, 6], Observable(@sprintf("%.0f°", rad2deg(p.elevation_angle))); fontsize=28, font=:bold, color=A1_INK, halign=:left, tellwidth=false)
    Label(cp[1, 7], strip_time;     fontsize=28, font=:bold, color=A1_INK,          halign=:left, tellwidth=false)
    for i in 1:7; colsize!(cp, i, Fixed(120)); end
    colsize!(cp, 7, Fixed(160))

    hr = Ref(0)
    hnr!() = (hr[] += 1; hr[])

    hlbl(txt; kw...) = Label(hud[hnr!(), 1], txt;
                              halign=:left, tellwidth=false,
                              justification=:left, kw...)
    fos_str(v) = (isinf(v) || isnan(v) || v > 9999) ? "   ∞" : @sprintf("%6.1f", v)

    # ── Sparkline buffers (circular, last 80 frames) ───────────────────────
    SPARK_N = 80
    spark_power   = Observable(fill(NaN, SPARK_N))
    spark_tension = Observable(fill(NaN, SPARK_N))
    spark_ring    = Observable(fill(NaN, SPARK_N))
    spark_idx     = Ref(1)

    # ── SECTION A: Compact Live Telemetry ─────────────────────────────────
    hlbl("── LIVE ─────────────────────────────────────"; fontsize=12, font=:bold, color=A1_ACCENT)

    # Power sparkline
    ax_pwr = Axis(hud[hnr!(), 1]; height=50, width=330,
                  backgroundcolor=A1_PANEL, xgridcolor=A1_EDGE, ygridcolor=A1_EDGE,
                  xticklabelsize=0, yticklabelsize=8, ytickcolor=A1_INK_DIM,
                  spinewidth=0.5, xtrimspine=true, ytrimspine=true)
    lines!(ax_pwr, 1:SPARK_N, spark_power; color=A1_ACCENT, linewidth=1.5)
    pwr_readout = hlbl("P =   0.00 kW  (  0% rated)"; fontsize=10, color=A1_INK_DIM)

    # Tether tension sparkline
    ax_ten = Axis(hud[hnr!(), 1]; height=50, width=330,
                  backgroundcolor=A1_PANEL, xgridcolor=A1_EDGE, ygridcolor=A1_EDGE,
                  xticklabelsize=0, yticklabelsize=8, ytickcolor=A1_INK_DIM,
                  spinewidth=0.5, xtrimspine=true, ytrimspine=true)
    lines!(ax_ten, 1:SPARK_N, spark_tension; color=:orange, linewidth=1.5)
    hlines!(ax_ten, [Float64(TETHER_SWL)]; color=A1_RED, linestyle=:dash, linewidth=1)
    ten_readout = hlbl("T =      0 N  ·  FoS  ∞"; fontsize=10, color=A1_INK_DIM)

    # Ring utilisation bar
    ax_ring = Axis(hud[hnr!(), 1]; height=22, width=330,
                   backgroundcolor=A1_PANEL,
                   xticklabelsize=0, yticklabelsize=0,
                   spinewidth=0, xgridvisible=false, ygridvisible=false,
                   xautolimitmargin=(0,0), yautolimitmargin=(0,0))
    ring_bar_val = Observable(0.0)
    barplot!(ax_ring, @lift([$ring_bar_val]); color=strip_util_col,
             direction=:x, width=20, strokewidth=0)
    xlims!(ax_ring, 0, 1.05)
    ring_readout = hlbl("Ring util   0.0%  ·  FoS  ∞"; fontsize=10, color=A1_INK_DIM)

    # ── Lift Device Status ─────────────────────────────────────────────────
    hlbl("── LIFT DEVICE ────────────────────────────"; fontsize=12, font=:bold, color=A1_ACCENT)
    lift_status_lbl = hlbl("Type: Rotary  |  T_lift =      0 N")
    lift_cl_lbl     = hlbl("R = 3.7 m  |  β = 30.0°")
    lift_ttop_lbl   = hlbl("T_top (phys) =      --- N"; color=:lightcyan)
    lift_line_lbl   = hlbl("Lift line tension =      0 N"; color=to_color(:cyan))
    backline_lbl    = hlbl("Backline payout =    0.0 m  |  T_back =      0 N"; color=to_color(:coral))
    bridles_lbl     = hlbl("Bridles (gold) avg =      0 N"; color=to_color(:gold))
    depower_phase_obs = Observable("")
    lift_depower_lbl   = hlbl(""; fontsize=10, color=:lawngreen)

    # Hub altitude reference (reset each rerun, used by _rerun!)
    hub_z0_ref = Ref{Float64}(NaN)

    # ── Compact structural + warnings ──────────────────────────────────────
    sag_lbl = hlbl("Sag 0.0 mm  |  slack: 0 lines"; fontsize=10, color=A1_INK_DIM)

    # Warnings — only visible when condition is active
    # TORSIONAL COLLAPSE: hub twist > 270° (nearing rope-wrap limit)
    # BUCKLING RISK: ring hoop utilisation > 80%
    # LINE SLACK: any tether line below 5 N tension
    warn_tors  = hlbl(""; color=:red,    fontsize=12, font=:bold)
    warn_buck  = hlbl(""; color=:orange, fontsize=12, font=:bold)
    warn_slack = hlbl(""; color=:yellow, fontsize=12, font=:bold)

    # ── SECTION D: Expansion Rotors ──────────────────────────────────────────
    exp_n = length(sys.expansion_rotors)
    if exp_n > 0
        hlbl(""; fontsize=6)
        hlbl("── Expansion Rotors ─────────────────────────"; fontsize=13, font=:bold, color=:cyan)
        exp_rings_str = join([string(er.ring_idx) for er in sys.expansion_rotors], ", ")
        exp_bank = sys.expansion_rotors[1].bank_angle_deg
        exp_span = sys.expansion_rotors[1].blade_tip_radius
        exp_chord = sys.expansion_rotors[1].blade_chord
        hlbl("Rings: $exp_rings_str  |  bank: $(round(exp_bank;digits=0))°"; fontsize=11, color=:cyan)
        hlbl("Blade: span=$(round(exp_span;digits=1)) m, chord=$(round(exp_chord*1000;digits=0)) mm"; fontsize=10, color=:lightcyan)
        hlbl("n_blades: $(sys.expansion_rotors[1].n_blades)  (from generating rotor)"; fontsize=10, color=:lightcyan)
    end

    # ── SECTION E: Run Peaks ─────────────────────────────────────────────────
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
          fontsize=11, color=@lift(to_color($scenario_msg_color)))

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

    # Simulation duration observable — read by _rerun! and by the duration menu widget
    sim_dur_obs = Observable(10.0)   # seconds; default 10 s

    # Timestep observable — reduce if the sim blows up (non-finite values / rings flying off)
    dt_obs = Observable(4e-5)        # seconds; 4e-5 stable for canonical, v5 needs 1e-5
    if p.n_lines == 8
        dt_obs[] = 1e-5              # v5 octagon: shorter segments → higher stiffness
    end

    # Generator control mode and winch payout observables
    gen_ctrl_selection       = Observable("Active Damping (Mode 1)")
    depower_payout_selection = Observable("25m Extended")
    # Pitch Depower closed-loop control toggles
    # active_winch_obs: enables proportional payout rate control using T_min feedback
    # mppt_stall_obs: enables ramped k_mppt stall governor (scales up to 9× during depower)
    # field_imu_obs: enables two-sided active torsional damping using Field IMU delta-omega telemetry
    # depower_seq_obs: controls payout/brake sequencing
    #   1 = "Stall → Lift"  (current: payout starts at 15%, brake fires freely)
    #   2 = "Lift ∥ Stall"  (payout starts immediately, brake fires freely)
    #   3 = "Lift → Stall"  (payout starts immediately, brake inhibited until ≥30% lift)
    active_winch_obs = Observable(false)
    mppt_stall_obs   = Observable(false)
    field_imu_obs    = Observable(false)
    depower_seq_obs  = Observable(1)

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
        elseif scenario == :pitch_depower
            # Power-spill Pitch Depower: wind stays at user-selected vref throughout.
            # The power reduction is purely geometric — backline payout lets the generating
            # rotor rise and tilt, increasing β (pointing more vertically) and spilling wind.
            # The lifting rotor kite provides a high-tension, high-elevation pull to keep the TRPT preloaded and stable.
            (pos, t) -> begin
                z = max(pos[3], 1.0); sh = (z / p.h_ref)^(1/7)
                [Float64(vref) * sh, 0.0, 0.0]
            end
        else   # :land
            (pos, t) -> begin
                v = t < 30.0 ? vref*(1.0-t*0.9/30.0) : vref*0.1*max(0.0,1.0-(t-30.0)/10.0)
                z = max(pos[3], 1.0); [v * (z/p.h_ref)^(1/7), 0.0, 0.0]
            end
        end
    end

    function _rerun!(scenario, label, vref)
        # ── Safety gate ────────────────────────────────────────────────────
        if !_is_safe()
            scenario_msg_color[] = :orangered
            scenario_msg[]       = "⚠  Busy — wait for current operation to finish"
            return
        end
        system_state_obs[] = :simulating
        # ── Status update FIRST — always visible regardless of what follows ──
        if !can_rerun
            scenario_msg_color[] = :orangered
            scenario_msg[]       = "⚠  provide u_settled & wind_fn to enable reruns"
            system_state_obs[]   = :idle
            return
        end
        scenario_msg_color[] = :orange
        t_run  = sim_dur_obs[]
        dt_run = dt_obs[]
        n_run  = round(Int, t_run / dt_run)
        scenario_msg[]       = "⟳  Running $label …  ($(round(Int,t_run)) s, dt=$(dt_run))"
        hub_z0_ref[]         = NaN   # reset hub-altitude reference for this run

        # ── Build scenario inputs (errors surfaced via status label) ──────────
        local wf, p_run, u_s, ode_p, ld, t_total
        try
            n_steps_local = n_run; dt_local = dt_run
            t_total       = n_steps_local * dt_local
            wf    = _make_wind(Float64(vref), scenario, t_total)
            wind_fn_obs[] = wf
            gen_sel = gen_ctrl_selection[]
            ctrl_mode_val = gen_sel == "Active Damping (Mode 1)" ? 1.0 :
                            gen_sel == "LPF Speed (Mode 2)"      ? 2.0 : 0.0
            
            payout_sel = depower_payout_selection[]
            payout_base_val = payout_sel == "25m Extended" ? 25.0 : 15.0

            use_field_imu = field_imu_obs[]
            p_run = _modified_params(p;
                        k_mppt          = Float64(sl_kmppt.value[]),
                        elevation_angle = deg2rad(Float64(sl_beta.value[])),
                        β_rate_max      = ctrl_mode_val,
                        β_min           = payout_base_val,
                        kp_elev         = use_field_imu ? 1.0 : 0.0)
            ld    = lift_device_obs[]
            ode_p = isnothing(ld) ? (sys, p_run, wf) : (sys, p_run, wf, ld)
            u_s   = copy(u_settled)
            # Operational pre-settle: regenerate the rated operating point for
            # this scenario's wind + k_mppt, instead of just gravity-settling
            # (which damps ω back to zero and forces a slow spin-up transient
            # under PTO + lifter drag from cold start).
            #
            # settle_to_operational_state internally:
            #   1. settle_to_equilibrium (gravity + wind + lift, ω damps to ~0)
            #   2. set ω = ω_rated for all rings
            #   3. torque-chain bisection to find equilibrium twist α
            #   4. set_orbital_velocities! for rope nodes
            #   5. operational settle at ω_rated (translation only, ω pinned)
            #      so the bearing finds its true ω_rated lift equilibrium
            # so frame 0 is the actual operating state and frame 1 is a smooth
            # continuation — no lifter step input, no asymmetric bridle snap,
            # no spin-up transient hiding the rotor's actual operating ω.
            #
            # ω_rated derived from the slider-modified k_mppt so the operating
            # point tracks the dashboard's k_mppt control.
            ω_rated_run = cbrt(p_run.p_rated_w / p_run.k_mppt)
            u_s = settle_to_operational_state(sys, u_s, p_run, ω_rated_run;
                        lift_device=ld, wind_fn=wf)
        catch e
            scenario_msg_color[] = :orangered
            scenario_msg[]       = "Setup error: $(sprint(showerror, e))"
            system_state_obs[]   = :idle
            return
        end

        n_steps = n_run; dt = dt_run
        @async try
            save_every = max(1, round(Int, 0.02 / dt))   # ≈ 0.02 s per frame for all dt values
            new_frames = Vector{Vector{Float64}}(undef, n_steps ÷ save_every)
            new_times  = Vector{Float64}(undef,  n_steps ÷ save_every)
            new_params = Vector{SystemParams}(undef, n_steps ÷ save_every)
            new_sim_frames = Vector{SimFrame}(undef, n_steps ÷ save_every)
            u  = copy(u_s); du = zeros(Float64, length(u))
            t  = 0.0; fi = 1
            release_frac     = 0.0   # depower payout fraction
            sigmoid_progress = 0.0   # closed-loop winch controller state
            L_winch          = 0.0   # physical actuator payout (m)
            v_winch          = 0.0   # actuator payout velocity (m/s)
            # Read control settings once at run start (immutable during a run)
            use_active_winch = active_winch_obs[]
            use_mppt_stall   = mppt_stall_obs[]
            use_field_imu    = field_imu_obs[]
            depower_seq      = depower_seq_obs[]
            # Sequence-derived parameters:
            #   seq 1 (Stall→Lift): payout delayed 15%, stall governor ramps with release_frac
            #   seq 2 (Lift∥Stall): payout immediate, stall governor ramps with release_frac
            #   seq 3 (Lift→Stall): payout immediate, stall governor held at 1× until ≥30%
            #                       payout — rotor decelerates naturally from rising hub first,
            #                       then stall governor assists.  Latch brake fires normally.
            seq_delay_frac    = depower_seq == 1 ? 0.15 : 0.0
            seq_stall_delayed = depower_seq == 3
            n_seg_dyn = sys.n_ring - 1
            ea_rope   = sys.sub_segs[1].EA
            p_active  = p_run
            k_mppt_scale      = 1.0   # initial stall scale
            for step in 1:n_steps
                # ── Pitch Depower: closed-loop winch + MPPT stall governor ──────
                # Every 50 steps (≈ 2 ms sim time) — fast enough to respond to slack events.
                #
                # Physics: releasing the backline lets the sky anchor rise under the
                # full lifting power (T_lift ≥ 1000 N) of the top lifter device.
                # This tilts the TRPT axis toward vertical, reducing the apparent
                # rotor annulus area to the wind and depowering the generating rotor.
                # The lifter remains at full operational tension to keep tethers taut.
                #
                # Hypothesis A — Proportional Winch Retarder (if active_winch_obs[]):
                #   Payout rate ∝ T_min / 150 N.  Zero payout when top segments go slack.
                # Hypothesis C — k_MPPT Stall Governor (if mppt_stall_obs[]):
                #   k_mppt ramped up to 9× proportional to how far through the depower we are.
                if scenario == :pitch_depower && step % 50 == 0
                    depower_delay    = depower_seq == 1 ? 0.15 * t_total : 1.0  # 1.0 s absolute startup delay for Seq 2 & 3
                    depower_duration = 0.70 * t_total
                    target_sig       = clamp((t - depower_delay) / depower_duration, 0.0, 1.0)
                    
                    payout_base = p_run.β_min < 5.0 ? 15.0 : p_run.β_min
                    geom_scale  = p_run.tether_length / 30.0
                    max_payout  = payout_base * geom_scale
                    
                    if use_active_winch && target_sig > sigmoid_progress
                        # Measure T_min: minimum average segment tension across all TRPT segments
                        hub_gid_d = sys.rotor.node_id
                        hub_ri_d  = (sys.nodes[hub_gid_d]::RingNode).ring_idx
                        perp1_d, perp2_d = _tilted_ring_basis(u, sys, hub_gid_d, hub_ri_d)
                        T_min_d = Inf
                        for s in 1:n_seg_dyn
                            seg_sum_d = 0.0
                            for j in 1:p_run.n_lines
                                seg_nat_len_d = 4 * sys.sub_segs[(s-1)*p_run.n_lines*4 + 1].length_0
                                gid_a_d = sys.ring_ids[s];  gid_b_d = sys.ring_ids[s+1]
                                na_d    = sys.nodes[gid_a_d]::RingNode
                                nb_d    = sys.nodes[gid_b_d]::RingNode
                                ctr_a_d = u[3*(gid_a_d-1)+1 : 3*gid_a_d]
                                ctr_b_d = u[3*(gid_b_d-1)+1 : 3*gid_b_d]
                                α_a_d   = u[6N + na_d.ring_idx]
                                α_b_d   = u[6N + nb_d.ring_idx]
                                pa_d    = attachment_point(ctr_a_d, na_d.radius, α_a_d, j, p_run.n_lines, perp1_d, perp2_d)
                                pb_d    = attachment_point(ctr_b_d, nb_d.radius, α_b_d, j, p_run.n_lines, perp1_d, perp2_d)
                                T_d     = max(0.0, ea_rope * (norm(pb_d .- pa_d) - seg_nat_len_d) / seg_nat_len_d)
                                seg_sum_d += T_d
                            end
                            T_min_d = min(T_min_d, seg_sum_d / p_run.n_lines)
                        end
                        # Proportional rate: 0 when slack, 1 when T_min ≥ 150 N
                        rate_factor = clamp(T_min_d / 150.0, 0.0, 1.0)
                        sigmoid_progress += rate_factor * 0.002 * (target_sig - sigmoid_progress)
                    else
                        sigmoid_progress = target_sig
                    end
                    
                    release_frac = 3.0 * sigmoid_progress^2 - 2.0 * sigmoid_progress^3
                    
                    # k_MPPT stall governor: ramp up to 9× as depower progresses.
                    # Lift→Stall sequence: hold at 1× until 30% payout is established,
                    # then ramp over the remaining 70% — so the rotor sees natural power
                    # spill from rising hub before any electrical stall torque is added.
                    stall_ramp   = seq_stall_delayed ?
                                   clamp((release_frac - 0.30) / 0.70, 0.0, 1.0) :
                                   release_frac
                    k_mppt_scale = use_mppt_stall ? (1.0 + 8.0 * stall_ramp) : 1.0
                end

                if scenario == :pitch_depower
                    # Second-order compliant winch actuator model: steps at the simulation rate dt
                    payout_base = p_run.β_min < 5.0 ? 15.0 : p_run.β_min
                    geom_scale  = p_run.tether_length / 30.0
                    max_payout  = payout_base * geom_scale

                    L_target  = max_payout * release_frac
                    omega_n   = 2.0 * pi * 1.0  # 1.0 Hz actuator natural frequency
                    zeta_act  = 1.0            # Critically damped response
                    a_winch   = (omega_n^2 * (L_target - L_winch)) - (2.0 * zeta_act * omega_n * v_winch)
                    v_winch  += dt * a_winch
                    L_winch  += dt * v_winch

                    # Reconstruct p_active and ode_p every step with the new L_winch
                    p_active = _modified_params(p_run;
                        backline_payout = L_winch,
                        k_mppt          = p_run.k_mppt * k_mppt_scale,
                        kp_elev         = use_field_imu ? 1.0 : 0.0)
                    ode_p = isnothing(ld) ? (sys, p_active, wf) : (sys, p_active, wf, ld)
                end

                # all scenarios: progress update + yield every 500 steps
                if step % 500 == 0
                    pct = round(Int, 100 * t / t_total)
                    scenario_msg[] = if scenario == :pitch_depower
                        payout_base = p_run.β_min < 5.0 ? 15.0 : p_run.β_min
                        geom_scale  = p_run.tether_length / 30.0
                        max_payout  = payout_base * geom_scale
                        ctrl_flags  = (use_active_winch ? " [Winch✓]" : "") * (use_mppt_stall ? " [Stall✓]" : "")
                        "⟳ Depower$ctrl_flags … $pct%  (payout=$(round(max_payout*release_frac, digits=2)) m,  t=$(round(t,digits=1)) / $(round(t_total,digits=0)) s)"
                    else
                        "⟳ $label … $pct%  (t=$(round(t,digits=1)) / $(round(t_total,digits=0)) s)"
                    end
                    yield()
                end
                fill!(du, 0.0)
                multibody_ode!(du, u, ode_p, t)
                t += dt
                @views u[3N+1:6N]        .+= dt .* du[3N+1:6N]
                @views u[1:3N]            .+= dt .* u[3N+1:6N]
                @views u[6N+Nr+1:6N+2Nr] .+= dt .* du[6N+Nr+1:6N+2Nr]
                apply_brake_constraint!(u, sys, N, Nr)
                @views u[6N+1:6N+Nr]     .+= dt .* u[6N+Nr+1:6N+2Nr]
                orbital_damp_rope_velocities!(u, sys, p_run, 0.05)
                # PTO co-braking during depower: damp all ring angular velocities
                # proportionally to how far through the Pitch Depower we are.
                if scenario == :pitch_depower && release_frac > 0.0 && round(p_run.β_rate_max) ≈ 0.0
                    @views u[6N+Nr+1:6N+2Nr] .*= (1.0 - release_frac * 1e-5)
                end
                u[1:3] .= 0.0; u[3N+1:3N+3] .= 0.0
                if ld !== nothing
                    update_kite_pos!(sys, u, ld, p_active, dt)
                end
                if step % save_every == 0
                    new_frames[fi] = copy(u)
                    new_times[fi] = t
                    new_params[fi] = p_active
                    new_sim_frames[fi] = capture_frame(u, sys, p_active, t, wf, ld; brake_engaged=sys.brake_engaged[])
                    fi += 1
                end
            end

            nf           = length(new_frames)
            times_ref[]  = new_times
            frames_obs[] = new_frames
            sim_frames_obs[] = new_sim_frames
            frame_slider.range[] = 1:nf
            frame_slider.value[] = 1
            scenario_msg_color[] = :lawngreen
            scenario_msg[]       = "✓  $label complete  ($nf frames, $(round(new_times[end], digits=1)) s)"
            system_state_obs[]   = :idle
        catch e
            scenario_msg_color[] = :orangered
            scenario_msg[]       = "Sim error: $(sprint(showerror, e))"
            system_state_obs[]   = :idle
        end
    end

    scen_rows = GridLayout(hud[hnr!(), 1])
    # Wind speed slider for scenarios (inline, compact) — 0.1 m/s minimum for hub-droop demos
    Label(scen_rows[1, 1], "V_ref:"; halign=:left, fontsize=10, color=:grey70)
    scen_vref_slider = Slider(scen_rows[1, 2:4]; range=0.1:0.1:20.0,
                               startvalue=clamp(p.v_wind_ref, 0.1, 20.0))
    scen_vref_lbl = Label(scen_rows[1, 5], @sprintf("%.1f m/s", p.v_wind_ref);
                           halign=:left, fontsize=10, color=:grey70, tellwidth=false)
    on(scen_vref_slider.value) do v
        scen_vref_lbl.text[] = @sprintf("%.1f m/s", v)
    end

    # Simulation duration selector (10 / 20 / 30 s)
    Label(scen_rows[2, 1], "Duration:"; halign=:left, fontsize=10, color=:grey70)
    dur_menu = Menu(scen_rows[2, 2:5];
                    options=["10 s", "20 s", "30 s"],
                    default="10 s", width=90)
    on(dur_menu.selection) do sel
        sim_dur_obs[] = parse(Float64, split(sel)[1])
    end

    # Timestep slider — reduce if sim produces non-finite values or rings fly off
    Label(scen_rows[3, 1], "dt:"; halign=:left, fontsize=10, color=:grey70)
    dt_slider = Slider(scen_rows[3, 2:4];
                       range=[4e-5, 3e-5, 2e-5, 1e-5],
                       startvalue=4e-5)
    dt_val_lbl = Label(scen_rows[3, 5], "4×10⁻⁵ s";
                       halign=:left, fontsize=10, color=:grey70, tellwidth=false)
    on(dt_slider.value) do v
        dt_obs[] = v
        dt_val_lbl.text[] = @sprintf("%.0e s", v)
    end
    # Note: reduce dt if rings go unstable (blow up / fly off) — more free ring
    # DOFs means more high-frequency modes; halving dt ~4× slower but stays stable
    Label(scen_rows[4, 1:5],
          "↑ reduce if rings blow up  (halving dt ≈ 4× slower)";
          halign=:left, fontsize=9, color=:grey50, tellwidth=false)

    bc          = to_color(scen_color(:_))   # neutral: grey30 (enabled) or grey20 (disabled)
    bc_active   = to_color(can_rerun ? :steelblue : :grey20)   # highlight for the selected scenario
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
            ((3,1), "Kite Drop", :kite_drop),
            ((3,2), "Pitch Depower", :pitch_depower)]
        btn = Button(scen_btns[pos...]; label=lbl, buttoncolor=bc,
                     labelcolor=:white, height=28)
        let btn=btn, sym=sym, lbl=lbl          # explicit capture per iteration
            on(btn.clicks) do _
                _is_safe() || return
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
        u  = frames_obs[][fi]
        sf = sim_frames_obs[][fi]

        # ── Telemetry ────────────────────────────────────────────────────────
        omega_hub = sf.omega_hub
        omega_gnd = sf.omega_gnd
        rpm_hub   = omega_hub * 60.0 / (2π)
        rpm_gnd   = omega_gnd * 60.0 / (2π)
        P_kw      = sf.P_kw
        pct_rated = sf.pct_rated
        V_hub     = sf.V_hub
        tsr       = sf.tsr
        Δα_deg    = sf.delta_alpha_deg
        z_hub_now = sf.hub_z
        δz_hub    = sf.hub_z_delta

        nf_now       = length(frames_obs[])
        tr           = times_ref[]
        t_hud        = sf.t

        # ── Cockpit strip updates ────────────────────────────────────────────
        strip_power[]    = @sprintf("%.1f kW", P_kw)
        strip_rpm[]      = @sprintf("%.0f rpm", rpm_hub)
        strip_wind[]     = @sprintf("%.1f m/s", V_hub)
        strip_time[]     = @sprintf("%.1f s", t_hud)

        # ── Sparkline data push ────────────────────────────────────────────
        let buf_p = spark_power[], buf_t = spark_tension[], buf_r = spark_ring[]
            i = spark_idx[]
            buf_p[i] = P_kw
            buf_t[i] = sf.T_max
            buf_r[i] = sf.ring_max_util * 100
            spark_power[] = buf_p; spark_tension[] = buf_t; spark_ring[] = buf_r
            spark_idx[] = mod1(i + 1, SPARK_N)
        end

        # ── Sparkline readouts ─────────────────────────────────────────────
        pwr_readout.text[]  = @sprintf("P = %6.2f kW  (%3.0f%% rated)", P_kw, pct_rated)
        ten_readout.text[]  = @sprintf("T = %5.0f N  ·  FoS %s", sf.T_max, fos_str(sf.fos_tether))
        ring_bar_val[]      = sf.ring_max_util
        ring_readout.text[] = @sprintf("Ring util %4.1f%%  ·  FoS %s",
                                        sf.ring_max_util*100.0, fos_str(sf.fos_ring))

        # ── Lift Device Telemetry ──────────────────────────────────────────
        hub_ctr  = u[3*(hub_gid-1)+1 : 3*hub_gid]
        β_actual = atan(hub_ctr[3], hub_ctr[1])
        ld_hud   = lift_device_obs[]
        if ld_hud !== nothing
            # Compute T_lift LIVE (not from pre-captured SimFrame which used lift_device=nothing)
            tr = times_ref[]
            t_now = (!isempty(tr) && fi <= length(tr)) ? tr[fi] : 0.0
            v_vec = wind_fn_obs[](hub_ctr, t_now)
            V_hub_live = norm(v_vec)
            _, T_lift_val, elev_lift_val = lift_force_steady(ld_hud, p.rho, V_hub_live)
            lift_margin_v = T_lift_val / max(autogyro_lift_required(p)[1], 1.0)
            if ld_hud isa RotaryLifterParams
                lift_status_lbl.text[] = @sprintf("Type: Rotary  |  T_lift = %6.0f N  |  pitch = %.1f×  |  CL/CD = %.1f",
                    T_lift_val, ld_hud.CL_blade, ld_hud.CL_blade / 0.20)
                lift_cl_lbl.text[] = @sprintf("R = %.1f m  |  β = %.1f°  |  elev = %.1f°  |  margin = %.1f×",
                    ld_hud.rotor_radius, rad2deg(β_actual), elev_lift_val, lift_margin_v)
            elseif ld_hud isa SingleKiteParams
                lift_status_lbl.text[] = @sprintf("Type: Single Kite  |  T_lift = %6.0f N", T_lift_val)
                lift_cl_lbl.text[] = @sprintf("CL = %.2f  |  β_actual = %.1f°  |  elev_lift = %.0f°",
                    ld_hud.CL, rad2deg(β_actual), elev_lift_val)
            elseif ld_hud isa StackedKitesParams
                lift_status_lbl.text[] = @sprintf("Type: Stacked×%d  |  T_lift = %6.0f N",
                    ld_hud.n_kites, T_lift_val)
                lift_cl_lbl.text[] = @sprintf("CL = %.2f  |  β_actual = %.1f°  |  elev_lift = %.0f°",
                    ld_hud.CL, rad2deg(β_actual), elev_lift_val)
            end
        else
            lift_status_lbl.text[] = "Type: None"
            lift_cl_lbl.text[]     = @sprintf("β_actual = %.1f°", rad2deg(β_actual))
        end

        # ── T_top_avg: physical top-segment tension (real lift line check) ──────
        # The topmost TRPT segment (sky-anchor → hub) carries the lift line load.
        # This must stay above the operational baseline during Pitch Depower.
        # Colour: cyan (taut ≥ 200N) → orange (low 50–200N) → red (slack < 50N)
        let n_seg_hud = sys.n_ring - 1,
            ea_hud    = sys.sub_segs[1].EA
            T_top_hud = 0.0
            hub_gid_h = sys.rotor.node_id
            hub_ri_h  = (sys.nodes[hub_gid_h]::RingNode).ring_idx
            perp1_h, perp2_h = _tilted_ring_basis(u, sys, hub_gid_h, hub_ri_h)
            for j in 1:p.n_lines
                seg_nat_h = 4 * sys.sub_segs[(n_seg_hud - 1) * p.n_lines * 4 + 1].length_0
                gid_a_h = sys.ring_ids[n_seg_hud];   gid_b_h = sys.ring_ids[n_seg_hud + 1]
                na_h    = sys.nodes[gid_a_h]::RingNode
                nb_h    = sys.nodes[gid_b_h]::RingNode
                ctr_a_h = u[3*(gid_a_h - 1) + 1 : 3*gid_a_h]
                ctr_b_h = u[3*(gid_b_h - 1) + 1 : 3*gid_b_h]
                α_a_h   = u[6N + na_h.ring_idx]
                α_b_h   = u[6N + nb_h.ring_idx]
                pa_h    = attachment_point(ctr_a_h, na_h.radius, α_a_h, j, p.n_lines, perp1_h, perp2_h)
                pb_h    = attachment_point(ctr_b_h, nb_h.radius, α_b_h, j, p.n_lines, perp1_h, perp2_h)
                T_top_hud += max(0.0, ea_hud * (norm(pb_h .- pa_h) - seg_nat_h) / seg_nat_h)
            end
            T_top_hud /= p.n_lines
            ttop_colour = T_top_hud > 200.0 ? to_color(:lightcyan) : (T_top_hud > 50.0 ? to_color(:orange) : to_color(:red))
            lift_ttop_lbl.color[] = ttop_colour
            lift_ttop_lbl.text[]  = @sprintf("T_top (phys) = %6.0f N  %s",
                T_top_hud,
                T_top_hud > 200.0 ? "✅ taut" : (T_top_hud > 50.0 ? "⚠️ low" : "❌ SLACK"))
        end

        # ── Lift line, backline, and gold bridles telemetry updates ──
        let
            # 1. Cyan Lift Line Tension
            ss_cyan = sys.sub_segs[end]
            pa_cyan = u[3*(sys.bearing_id-1)+1 : 3*sys.bearing_id]
            pb_cyan = u[3*(sys.sky_anchor_id-1)+1 : 3*sys.sky_anchor_id]
            T_cyan_now = max(0.0, ss_cyan.EA * (norm(pb_cyan .- pa_cyan) - ss_cyan.length_0) / ss_cyan.length_0)
            lift_line_lbl.text[] = @sprintf("Lift line tension = %6.0f N", T_cyan_now)
            
            # 2. Backline Payout & Tension
            T_back_now = 0.0
            payout_now = 0.0
            if ld_hud !== nothing
                sky_pos = u[3*(sys.sky_anchor_id-1)+1 : 3*sys.sky_anchor_id]
                v_lift = wind_fn_obs[](sky_pos, t_hud)
                v_hmag = sqrt(v_lift[1]^2 + v_lift[2]^2)
                _, T_lift_val, elev_lift_val = lift_force_steady(ld_hud, p.rho, v_hmag)
                if T_lift_val > 0.0 && v_hmag > 1e-6
                    downwind = [v_lift[1] / v_hmag, v_lift[2] / v_hmag, 0.0]
                    θ_lift   = deg2rad(elev_lift_val)
                    lift_dir = cos(θ_lift) .* downwind .+ sin(θ_lift) .* [0.0, 0.0, 1.0]
                    F_lift_vec = T_lift_val .* lift_dir
                    
                    bearing_pos = u[3*(sys.bearing_id-1)+1 : 3*sys.bearing_id]
                    cyan_dir = normalize(bearing_pos .- sky_pos)
                    F_cyan_vec = T_cyan_now .* cyan_dir
                    
                    F_grav = [0.0, 0.0, -0.3 * 9.81]
                    F_back_vec = - (F_lift_vec + F_cyan_vec + F_grav)
                    T_back_now = max(0.0, norm(F_back_vec))
                    
                    back_ax = p.tether_length * cos(p.elevation_angle) + p.back_anchor_fwd_x
                    b_dist = norm(sky_pos .- [back_ax, 0.0, 0.0])
                    
                    bearing_offset = 6.0
                    cyan_L0        = 5.0
                    L_axis_design        = p.tether_length + bearing_offset + cyan_L0
                    design_sky_anchor_x  = L_axis_design * cos(p.elevation_angle)
                    design_sky_anchor_z  = L_axis_design * sin(p.elevation_angle)
                    back_L0_design       = sqrt((design_sky_anchor_x - back_ax)^2 + design_sky_anchor_z^2)
                    
                    payout_now = max(0.0, b_dist - back_L0_design)
                end
            end
            backline_lbl.text[] = @sprintf("Backline payout = %5.1f m  |  T_back = %5.0f N", payout_now, T_back_now)
            
            # 3. Gold Bridles Tension
            T_bridles_sum = 0.0
            for j in 1:p.n_lines
                ss_b = sys.sub_segs[end - p.n_lines + j - 1]
                pa_b = u[3*(sys.bearing_id-1)+1 : 3*sys.bearing_id]
                
                hub_gid = sys.rotor.node_id
                hub_ri = (sys.nodes[hub_gid]::RingNode).ring_idx
                ctr_h = u[3*(hub_gid-1)+1 : 3*hub_gid]
                α_h   = u[6N + hub_ri]
                
                # Bridles must use the dynamic shaft_perp_basis (NOT tilted basis)
                # to match the physics solver in rope_forces.jl
                hub_rmag  = norm(ctr_h)
                shaft_dir = hub_rmag > 0.1 ?
                            ctr_h ./ hub_rmag :
                            [cos(p.elevation_angle), 0.0, sin(p.elevation_angle)]
                pp1, pp2 = shaft_perp_basis(shaft_dir)
                
                hub_node_b = sys.nodes[hub_gid]::RingNode
                pb_b  = attachment_point(ctr_h, hub_node_b.radius, α_h, j, p.n_lines, pp1, pp2)
                
                T_bridles_sum += max(0.0, ss_b.EA * (norm(pb_b .- pa_b) - ss_b.length_0) / ss_b.length_0)
            end
            T_bridles_avg = T_bridles_sum / p.n_lines
            bridles_lbl.text[] = @sprintf("Bridles (gold) avg = %5.0f N", T_bridles_avg)
        end

        # ── Compact structural + warnings ─────────────────────────────────
        sag_lbl.text[]     = @sprintf("Sag %4.1f mm  |  slack: %d lines",
                                        sf.max_sag_mm, sf.n_slack)

        # Cockpit FoS / ring util colour-coded
        strip_fos[]  = fos_str(sf.fos_tether)
        strip_util[] = @sprintf("%.0f%%", sf.ring_max_util * 100.0)
        fv = sf.fos_tether
        strip_fos_col[]  = fv >= 3.0 ? A1_GREEN : (fv >= 1.8 ? A1_ORANGE : A1_RED)
        ru = sf.ring_max_util
        strip_util_col[] = ru <= 0.5 ? A1_GREEN : (ru <= 0.8 ? A1_ORANGE : A1_RED)

        # Warnings
        warn_tors.text[]  = sf.torsional_overtwist ? "!! TORSIONAL OVERTWIST" : ""
        warn_buck.text[]  = sf.buckling_risk        ? "!! BUCKLING RISK"       : ""
        warn_slack.text[] = sf.line_slack ?
                            @sprintf("!! LINE SLACK: %d lines", sf.n_slack) : ""
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

    # ── SECTION C: Configuration ──────────────────────────────────────────────
    clbl("── Configuration ───────────────────────"; fontsize=12, font=:bold)

    # Current config display
    config_display = clbl(@sprintf("Active: %s", config_name); fontsize=11, color=:lawngreen)

    # Config selector menu — disabled during simulation
    config_menu = Menu(ctrl[cnr!(), 1];
        options=["Canonical 5-line", "v5 Optimized 8-line", "v5-safe 8-line",
                 "V6.2 12-line dodecagon", "V6.3 7-line heptagon",
                 "V6.4 3-line triangle", "V6.5 3-line triangle"],
        default=config_name, width=270)

    # Also disable menu when not idle
    on(system_state_obs) do st
        # Menu doesn't support direct disable, but button gating prevents action
    end

    # Switch button — only active when safe
    switch_btn = Button(ctrl[cnr!(), 1];
        label="Switch Configuration",
        buttoncolor=:steelblue, labelcolor=:white, height=28,
        tellwidth=false)

    # Status line for build progress
    status_line = clbl(""; fontsize=9, color=:darkorange)

    on(switch_btn.clicks) do _
        _is_safe() || return
        new_cfg = config_menu.selection[]
        if new_cfg == config_name
            build_status_obs[] = "Already using $(config_name)"
            return
        end
        system_state_obs[]   = :switching
        build_status_obs[]   = "⟳ Switching to $(new_cfg) — rebuilding..."
        config_changed_obs[] = new_cfg
    end

    # Disable switch button when not idle
    on(system_state_obs) do st
        if st == :idle
            switch_btn.buttoncolor[] = to_color(:steelblue)
            switch_btn.labelcolor[]  = :white
            switch_btn.label[]       = "Switch Configuration"
        else
            switch_btn.buttoncolor[] = to_color(:grey30)
            switch_btn.labelcolor[]  = :grey60
            switch_btn.label[]       = st == :simulating ? "Busy — simulating..." : "Switching..."
        end
    end

    # Keep status line updated
    on(build_status_obs) do msg
        status_line.text[] = msg
    end

    clbl(""; fontsize=4)   # visual spacer

    # ── SECTION L: Lift Device ────────────────────────────────────────────────
    # Two adaptive sliders whose meaning changes with the selected device type.
    # Slider A: Area (kites) or ω (rotary) — the dominant sizing parameter.
    # Slider B: CL (kites) or Rotor radius (rotary) — the performance lever.
    clbl("── Lift Device ──────────────────────────"; fontsize=12, font=:bold)

    device_menu = Menu(ctrl[cnr!(), 1];
                       options=["None", "Single Kite", "Stacked ×3", "Rotary Lifter"],
                       default="Rotary Lifter", width=270)

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
            ld_lbl_A.text[] = "Elevation Factor"
            ld_sl_A.range[] = 0.5:0.1:3.0
            ld_sl_A.value[] = 1.0
            ld_lbl_B.text[] = "Radius (m)"
            ld_sl_B.range[] = 0.5:0.1:5.0
            ld_sl_B.value[] = 1.5      # rotary_lifter_default() rotor radius
        end
    end

    on(ld_sl_A.value) do v
        choice = device_menu.selection[]
        ld_val_A.text[] = (choice == "Stacked ×3")  ? string(round(Int, v)) :
                          (choice == "Rotary Lifter") ? @sprintf("%.1f×", v) :
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
            SingleKiteParams(b, 0.12, a, 25.0, 1.5e5, 3.0)
        elseif choice == "Stacked ×3"
            StackedKitesParams(round(Int,a), b, 0.12, 8.0, 8.0, 1.5e5, 2.0)
        elseif choice == "Rotary Lifter"
            # a = elevation factor (CL_blade), b = rotor radius
            RotaryLifterParams(b, 0.05, 3, 0.12, a, 0.20, 40.0, 25.0, 1.5e5, 5.0)
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

    # Trigger initial slider config for default device (Rotary Lifter)
    _reconfigure_ld_sliders!("Rotary Lifter")
    _update_lift_device!("Rotary Lifter")

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

    clbl("Generator Control"; fontsize=11)
    gen_ctrl_menu = Menu(ctrl[cnr!(), 1];
                         options=["Standard (Mode 0)", "Active Damping (Mode 1)", "LPF Speed (Mode 2)"],
                         default=gen_ctrl_selection[])
    on(gen_ctrl_menu.selection) do sel
        gen_ctrl_selection[] = sel
    end

    clbl("Depower Winch Payout"; fontsize=11)
    depower_payout_menu = Menu(ctrl[cnr!(), 1];
                               options=["15m Baseline", "25m Extended"],
                               default=depower_payout_selection[])
    on(depower_payout_menu.selection) do sel
        depower_payout_selection[] = sel
    end

    # ── Pitch Depower Closed-Loop Controls ───────────────────────────────────────
    # These toggles activate the control hypotheses during the Pitch Depower scenario.
    # They have no effect on steady / ramp-down / kite-drop scenarios.
    clbl(""; fontsize=3)   # spacer
    clbl("── Pitch Depower Controls ──────────────"; fontsize=12, font=:bold)


    # Hypothesis A: Proportional Active Winch Tension-Keeping
    # Measures T_min across all TRPT segments every 2ms and throttles payout rate
    # proportionally: zero payout if top segments are slack, full rate if well-tensioned.
    tog_row_A = GridLayout(ctrl[cnr!(), 1])
    Label(tog_row_A[1, 1]; text="Active Winch (T_min feedback)", fontsize=11, halign=:left, tellwidth=false)
    active_winch_toggle = Toggle(tog_row_A[1, 2]; active=active_winch_obs[], framecolor_active=to_color(:limegreen))
    on(active_winch_toggle.active) do v
        active_winch_obs[] = v
    end

    # Hypothesis C: k_MPPT Stall Governor
    # Ramps the MPPT gain up to 9× during depower to overload the rotor with
    # braking torque and smoothly stall it without relying on geometry alone.
    tog_row_C = GridLayout(ctrl[cnr!(), 1])
    Label(tog_row_C[1, 1]; text="k_MPPT Stall Governor (9×)", fontsize=11, halign=:left, tellwidth=false)
    mppt_stall_toggle = Toggle(tog_row_C[1, 2]; active=mppt_stall_obs[], framecolor_active=to_color(:orange))
    on(mppt_stall_toggle.active) do v
        mppt_stall_obs[] = v
    end

    # Hypothesis D: Field IMU Torsional Damping
    # Transmits a high-fidelity angular velocity signal from the sky (field rotor IMU)
    # down to the ground PTO and applies a symmetric, two-sided torsional damper
    # (without the motor/generator motoring clamp) to eliminate whipping resonance.
    tog_row_D = GridLayout(ctrl[cnr!(), 1])
    Label(tog_row_D[1, 1]; text="Field IMU Active Damping", fontsize=11, halign=:left, tellwidth=false)
    field_imu_toggle = Toggle(tog_row_D[1, 2]; active=field_imu_obs[], framecolor_active=to_color(:cyan))
    on(field_imu_toggle.active) do v
        field_imu_obs[] = v
    end

    # Depower sequence selector: controls the relative timing of backline payout
    # vs. PTO brake engagement.
    #   Stall → Lift  Payout starts at 15% of scenario time.  Brake fires freely
    #                 at omega < 1 rad/s.  Currently observed: rotor stalls first,
    #                 then hub lifts — TRPT absorbs torsional shock at full elevation.
    #   Lift ∥ Stall  Payout starts immediately.  Brake fires freely.  Hub begins
    #                 rising from t=0; rotor may still stall early if wind is low.
    #   Lift → Stall  Payout starts immediately.  Brake is inhibited until ≥30%
    #                 payout has been released — guarantees hub is rising and rotor
    #                 power is substantially reduced before the mechanical brake locks.
    #                 This is the originally intended sequence.
    clbl(""; fontsize=4)
    clbl("Depower Sequence"; fontsize=11, font=:bold, halign=:left)
    _seq_options = ["Stall → Lift  (current)", "Lift ∥ Stall  (immediate payout)", "Lift → Stall  (stall gov. after lift)"]
    seq_row = GridLayout(ctrl[cnr!(), 1])
    seq_menu = Menu(seq_row[1, 1];
        options   = _seq_options,
        default   = _seq_options[1],
        fontsize  = 10,
        tellwidth = false)
    on(seq_menu.selection) do sel
        idx = findfirst(==( sel), _seq_options)
        if !isnothing(idx)
            depower_seq_obs[] = idx
        end
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
    play_btn  = Button(pb_row[1, 1]; label="▶ Play",  buttoncolor=to_color(:darkgreen), labelcolor=:white)
    is_playing = Observable(false)
    speed_obs  = Observable(1.0)

    Menu(pb_row[1, 2]; options=["0.25×","0.5×","1×","2×","4×"], default="1×") |> m ->
        on(m.selection) do s
            speed_obs[] = s=="0.25×" ? 0.25 : s=="0.5×" ? 0.5 :
                          s=="2×"    ? 2.0  : s=="4×"   ? 4.0 : 1.0
        end

    # Wall-clock references — reset when playback starts or speed changes so that
    # the "which frame should be showing right now?" calculation is always anchored
    # to a known (frame, time) pair.  GLMakie may drop frames when rendering is
    # slow, but the animation speed is governed by wall time, not by sleep duration.
    play_wall_t0  = Ref(0.0)
    play_frame_t0 = Ref(1)

    on(play_btn.clicks) do _
        is_playing[] = !is_playing[]
        play_btn.label[]       = is_playing[] ? "|| Pause" : "▶ Play"
        play_btn.buttoncolor[] = is_playing[] ? to_color(:darkorange) : to_color(:darkgreen)
        if is_playing[]
            play_wall_t0[]  = time()
            play_frame_t0[] = frame_slider.value[]
        end
    end

    on(speed_obs) do _
        if is_playing[]
            play_wall_t0[]  = time()
            play_frame_t0[] = frame_slider.value[]
        end
    end

    @async while true
        if is_playing[]
            wall_elapsed = time() - play_wall_t0[]
            target_nf    = play_frame_t0[] + round(Int, wall_elapsed * speed_obs[] / 0.02)
            nf = clamp(target_nf, 1, length(frames_obs[]))
            nf != frame_slider.value[] && set_close_to!(frame_slider, nf)
            if nf >= length(frames_obs[])
                is_playing[] = false
                play_btn.label[]       = "▶ Play"
                play_btn.buttoncolor[] = to_color(:darkgreen)
            end
        end
        sleep(0.016)   # ~60 Hz poll; GLMakie renders at its own rate
    end

    # ── SECTION C: Actions ────────────────────────────────────────────────────
    clbl(""; fontsize=6)
    clbl("── Actions ─────────────────────────────"; fontsize=12, font=:bold)

    # Export Force CSV — writes per-node force vector at the current frame
    act_row1 = GridLayout(ctrl[cnr!(), 1])
    Button(act_row1[1, 1]; label="Export Forces", buttoncolor=:purple,
           labelcolor=:white, height=30) |> b ->
        on(b.clicks) do _
            fi = frame_obs[]; u = frames_obs[][fi]
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
            fi = frame_obs[]; u = frames_obs[][fi]
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
            u   = frames_obs[][frame_obs[]]
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
        rerun_btn.buttoncolor[] = to_color(v ? :darkgreen : :grey30)
    end

    # Compact Controls row spacing to match HUD
    rowgap!(ctrl, 2)

    # ── Initial notify ────────────────────────────────────────────────────────
    notify(frame_obs)
    return (fig, cockpit_fig, config_changed_obs)
end

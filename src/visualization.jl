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
function _rope_line_pts(u, sys, p, s, j, perp1, perp2)
    N     = sys.n_total
    gid_a = sys.ring_ids[s]
    # Top segment: upper endpoint is a vertex node, not a ring centre
    is_top_viz = (s == p.n_rings + 1)
    gid_b = is_top_viz ? sys.rotor.node_id : sys.ring_ids[s + 1]
    na    = sys.nodes[gid_a]::RingNode
    nb    = sys.nodes[gid_b]::RingNode
    ctr_a = u[3*(gid_a-1)+1 : 3*gid_a]
    ctr_b = u[3*(gid_b-1)+1 : 3*gid_b]
    α_a   = u[6N + na.ring_idx]
    α_b   = u[6N + nb.ring_idx]
    pa    = attachment_point(ctr_a, na.radius, α_a, j, p.n_lines, perp1, perp2)
    # Top segment: upper endpoint is a hub vertex node, not ring centre
    if s == p.n_rings + 1
        v_gid = sys.hub_vertex_ids[j]
        pb    = u[3*(v_gid-1)+1 : 3*v_gid]
    else
        pb = attachment_point(ctr_b, nb.radius, α_b, j, p.n_lines, perp1, perp2)
    end
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
    idx = (s-1) * p.n_lines * 4 + (j-1) * 4 + 2
    idx > length(sys.sub_segs) && return 0.0
    ss  = sys.sub_segs[idx]
    pa  = u[3*(ss.end_a.node_id-1)+1 : 3*ss.end_a.node_id]
    pb  = u[3*(ss.end_b.node_id-1)+1 : 3*ss.end_b.node_id]
    max(0.0, ss.EA * (norm(pb .- pa) - ss.length_0) / ss.length_0)
end

# ── Geometry helpers for 3D tether rendering ────────────────────────────────
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
    for s in 1:p.n_rings    # skip top segment (uses vertex nodes)
        gid_a = sys.ring_ids[s];   gid_b = sys.ring_ids[s+1]
        na = sys.nodes[gid_a]::RingNode; nb = sys.nodes[gid_b]::RingNode
        ctr_a = u[3*(gid_a-1)+1:3*gid_a]; ctr_b = u[3*(gid_b-1)+1:3*gid_b]
        pa = attachment_point(ctr_a, na.radius, u[6N+na.ring_idx], 1, p.n_lines, perp1, perp2)
        pb = attachment_point(ctr_b, nb.radius, u[6N+nb.ring_idx], 1, p.n_lines, perp1, perp2)
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
    # Per-segment natural length — critical for v5 non-uniform spacing.
    # Sub-segments within a segment all share the same natural length.
    _seg_nat_len = (s) -> 4 * sys.sub_segs[(s-1)*p.n_lines*4 + 1].length_0
    _seg_T = (u, s, j) -> begin
        gid_a = sys.ring_ids[s]
        na    = sys.nodes[gid_a]::RingNode
        ctr_a = u[3*(gid_a-1)+1 : 3*gid_a]
        α_a   = u[6N + na.ring_idx]
        pa    = attachment_point(ctr_a, na.radius, α_a, j, p.n_lines, perp1, perp2)
        # Upper endpoint: ring centre or vertex node
        if s == n_seg
            v_gid = sys.hub_vertex_ids[j]
            pb    = u[3*(v_gid-1)+1 : 3*v_gid]
        else
            gid_b = sys.ring_ids[s + 1]
            nb    = sys.nodes[gid_b]::RingNode
            ctr_b = u[3*(gid_b-1)+1 : 3*gid_b]
            α_b   = u[6N + nb.ring_idx]
            pb    = attachment_point(ctr_b, nb.radius, α_b, j, p.n_lines, perp1, perp2)
        end
        l_nat = _seg_nat_len(s)
        max(0.0, _ea_rope * (norm(pb .- pa) - l_nat) / l_nat)
    end
    _tmax_local   = u -> maximum((_seg_T(u, s, j) for s in 1:n_seg, j in 1:p.n_lines); init=0.0)
    _nslack_local = u -> count(_seg_T(u, s, j) < 5.0 for s in 1:n_seg, j in 1:p.n_lines)

    l_seg = p.tether_length / n_seg

    hub_gid  = sys.rotor.node_id   # hub centre (ring_idx=0, not in ring_ids)
    hub_node = sys.nodes[hub_gid]::RingNode
    hub_R    = hub_node.radius
    hub_ri   = hub_node.ring_idx   # = 0

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

    # ── Configuration switching & safety state machine ────────────────────────
    config_changed_obs = Observable{Union{String, Nothing}}(nothing)  # nil = no change pending
    system_state_obs   = Observable{Symbol}(:idle)   # :idle | :simulating | :switching
    build_status_obs   = Observable("")              # shown during transitions
    _is_safe()         = (system_state_obs[] == :idle)

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
    n_ring_vis = length(sys.ring_ids) - 1    # exclude ground
    for ki in 1:n_ring_vis
        k  = ki + 1                            # ring_ids index (skip ground)
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
            sfs  = $sim_frames_obs
            fi   = $frame_obs
            util = fi <= length(sfs) ? sfs[fi].ring_utils[ki] : 0.0
            _ring_util_color(util)
        end
        lines!(ax3d, @lift($ro[1]), @lift($ro[2]), @lift($ro[3]);
               color=rc, linewidth=1.5)
    end

    # Hub (rotor) ring — firebrick, drawn from vertex node positions
    hub_ring_obs = @lift begin
        u   = $u_obs
        pts = [u[3*(gid-1)+1 : 3*gid] for gid in sys.hub_vertex_ids]
        push!(pts, pts[1])  # close the polygon
        ([pt[1] for pt in pts], [pt[2] for pt in pts], [pt[3] for pt in pts])
    end
    lines!(ax3d, @lift($hub_ring_obs[1]), @lift($hub_ring_obs[2]),
                 @lift($hub_ring_obs[3]); color=:firebrick, linewidth=3.5)

    # Rotor blades — in the ring plane, attached at hub vertex positions
    r_inner = hub_R
    r_outer = sys.rotor.radius
    chord   = r_outer * 0.15
    for b in 1:p.n_blades
        v_gid = sys.hub_vertex_ids[b]
        blade_obs = @lift begin
            u     = $u_obs
            v_ids = sys.hub_vertex_ids
            vpos  = u[3*(v_gid-1)+1 : 3*v_gid]
            ctr   = u[3*(hub_gid-1)+1 : 3*hub_gid]
            # direction from centre to vertex
            r_vec = vpos .- ctr
            r_len = max(norm(r_vec), 1e-9)
            r_dir = r_vec ./ r_len
            # Ring plane normal from first 3 vertices
            v1 = u[3*(v_ids[1]-1)+1 : 3*v_ids[1]]
            v2 = u[3*(v_ids[2]-1)+1 : 3*v_ids[2]]
            v3 = u[3*(v_ids[3]-1)+1 : 3*v_ids[3]]
            ring_n = normalize(cross(v2 .- v1, v3 .- v1))
            # Chord direction: in ring plane, perpendicular to radial
            c_dir = normalize(cross(ring_n, r_dir))
            hc    = chord / 2.0
            p1 = vpos .- hc .* c_dir
            p2 = ctr .+ (r_outer / r_inner) .* r_vec .- hc .* c_dir
            p3 = ctr .+ (r_outer / r_inner) .* r_vec .+ hc .* c_dir
            p4 = vpos .+ hc .* c_dir
            xs = [p1[1], p2[1], p3[1], p4[1], p1[1]]
            ys = [p1[2], p2[2], p3[2], p4[2], p1[2]]
            zs = [p1[3], p2[3], p3[3], p4[3], p1[3]]
            (xs, ys, zs)
        end
        lines!(ax3d, @lift($blade_obs[1]), @lift($blade_obs[2]),
                     @lift($blade_obs[3]); color=:steelblue, linewidth=2.5)
    end

    # Lift system — bearing is a real ODE particle; bridle lines are spring-dampers
    bearing_gid_viz = sys.bearing_id
    bearing_obs     = @lift $u_obs[3*(bearing_gid_viz-1)+1 : 3*bearing_gid_viz]
    # lift tether and backline both attach to the bearing
    lift_point_obs  = bearing_obs

    # Bridle lines: bearing → hub vertex nodes (real ODE particles)
    for (j, v_gid) in enumerate(sys.hub_vertex_ids)
        bridle_obs = @lift begin
            bp = $bearing_obs
            vp = $u_obs[3*(v_gid-1)+1 : 3*v_gid]
            ([bp[1], vp[1]], [bp[2], vp[2]], [bp[3], vp[3]])
        end
        lines!(ax3d, @lift($bridle_obs[1]), @lift($bridle_obs[2]),
                     @lift($bridle_obs[3]); color=:gold, linewidth=1.2)
    end

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

    # Back line — coral, from 10 cm above the bearing down to the fixed ground
    # anchor.  Colour: coral = taut; grey = slack.
    let back_off    = 0.10,
        back_ax     = p.tether_length * cos(p.elevation_angle) + p.back_anchor_fwd_x,
        design_bearing_x = p.tether_length * cos(p.elevation_angle),
        design_bearing_z = p.tether_length * sin(p.elevation_angle) + 6.0 + back_off,
        back_L0     = sqrt(p.back_anchor_fwd_x^2 + (p.tether_length * sin(p.elevation_angle) + 6.0 + back_off)^2)
        scatter!(ax3d, [back_ax], [0.0], [0.0]; color=:coral, markersize=12, marker=:diamond)
        back_line_obs = @lift begin
            bp   = $bearing_obs
            att  = (bp[1], bp[2], bp[3] + back_off)
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

    # ── SECTION L: Lift Device Status ──────────────────────────────────────────
    hlbl(""; fontsize=6)
    hlbl("── Lift Device ───────────────────────────"; fontsize=13, font=:bold)
    lift_status_lbl = hlbl("Type: Rotary  |  T_lift =      0 N")
    lift_cl_lbl     = hlbl("R = 3.7 m  |  β = 30.0°")
    lift_furl_lbl   = hlbl(""; fontsize=10, color=:lawngreen)

    # Furl phase indicator — updated during simulation
    furl_phase_obs = Observable("")

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
             label="utilisation:  0 (safe)  →  1.0 (buckle)",
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

    # Simulation duration observable — read by _rerun! and by the duration menu widget
    sim_dur_obs = Observable(10.0)   # seconds; default 10 s

    # Timestep observable — reduce if the sim blows up (non-finite values / rings flying off)
    dt_obs = Observable(4e-5)        # seconds; 4e-5 stable for canonical, v5 needs 1e-5
    if p.n_lines == 8
        dt_obs[] = 1e-5              # v5 octagon: shorter segments → higher stiffness
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
        elseif scenario == :furl
            # Power-spill furl: wind stays at user-selected vref throughout.
            # The power reduction is purely geometric — backline payout lets the
            # rotor rise, increasing β and spilling wind.  No wind ramp needed.
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
            system_state_obs[]   = :idle
            return
        end

        n_steps = n_run; dt = dt_run
        @async try
            new_frames = Vector{Vector{Float64}}(undef, n_steps ÷ 500)
            new_times  = Vector{Float64}(undef,  n_steps ÷ 500)
            u  = copy(u_s); du = zeros(Float64, length(u))
            t  = 0.0; fi = 1
            for step in 1:n_steps
                # ── Furl: winch payout controller (every 500 steps) ─────────
                # The winch pays out extra backline from a FIXED anchor point.
                # This increases the backline rest length → line goes slack →
                # lift device pulls hub UP and DOWNWIND → rotor rises → β↑ →
                # wind incidence drops → power spills.  Pitch boost helps the
                # lift device overcome the initial inertia.
                if scenario == :furl && step % 500 == 0
                    release_frac = clamp(t / 5.0, 0.0, 1.0)  # full deploy in 5 s
                    p_furl = _modified_params(p_run;
                        backline_payout = 40.0 * release_frac)
                    # Anchor stays FIXED — winch pays out extra line.
                    # Rest length increases → backline goes slack → lift rises.

                    ld_furl = ld
                    if ld_furl !== nothing
                        if t < 2.0
                            # Phase 1: pre-furl — ramp pitch modestly
                            boost = 1.0 + 0.5 * (t / 2.0)  # 1→1.5× over 2 s
                        else
                            # Phase 2: pitch responds to excess power
                            ω_gnd_now = abs(u[6N + Nr + 1])
                            P_now = p.k_mppt * ω_gnd_now^3 / 1000.0
                            P_rated_kw = p.p_rated_w / 1000.0
                            excess = max(0.0, P_now - P_rated_kw)
                            boost = clamp(1.0 + 2.0 * excess / P_rated_kw, 1.0, 3.0)
                        end
                        if ld isa RotaryLifterParams
                            ld_furl = RotaryLifterParams(ld.rotor_radius,
                                ld.hub_radius, ld.n_blades, ld.blade_chord,
                                ld.CL_blade * boost, ld.CD_blade, ld.omega_fixed,
                                ld.line_length, ld.line_EA, ld.m_lifter)
                        elseif ld isa SingleKiteParams
                            ld_furl = SingleKiteParams(ld.CL * boost,
                                ld.CD, ld.area, ld.line_length, ld.line_EA, ld.m_kite)
                        elseif ld isa StackedKitesParams
                            ld_furl = StackedKitesParams(ld.n_kites,
                                ld.CL * boost, ld.CD, ld.area_each, ld.spacing,
                                ld.line_EA, ld.m_kite_each)
                        end
                    end
                    ode_p = isnothing(ld_furl) ? (sys, p_furl, wf) : (sys, p_furl, wf, ld_furl)

                    # Progress update — keep the UI alive during long furl runs
                    pct = round(Int, 100 * t / t_total)
                    scenario_msg[] = "⟳ Furl … $pct% (t=$(round(t, digits=1))s)"
                    yield()
                end
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
            # Rebuild SimFrames for the new run
            sim_frames_obs[] = [capture_frame(new_frames[i], sys, p,
                                  new_times[i], wf, ld)
                                 for i in 1:nf]
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
            ((3,1), "Kite Drop", :kite_drop),
            ((3,2), "Furl",      :furl)]
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
        if isnan(hub_z0_ref[]);  hub_z0_ref[] = z_hub_now;  end
        hub_z_lbl.text[] = @sprintf("Hub altitude  Z = %5.1f m  (Δ = %+.2f m)",
                                     z_hub_now, isnan(hub_z0_ref[]) ? 0.0 : z_hub_now - hub_z0_ref[])

        elev_lbl.text[]     = @sprintf("Elevation  β = %5.1f°  |  Rated %.0f kW",
                                        rad2deg(p.elevation_angle), p.p_rated_w/1000.0)

        # ── Lift Device Telemetry ──────────────────────────────────────────
        ld_hud   = lift_device_obs[]
        hub_ctr  = u[3*(hub_gid-1)+1 : 3*hub_gid]
        β_actual = atan(hub_ctr[3], hub_ctr[1])
        if ld_hud !== nothing
            T_lift_val    = sf.T_lift
            elev_lift_val = sf.lift_elev_deg
            if ld_hud isa RotaryLifterParams
                lift_status_lbl.text[] = @sprintf("Type: Rotary  |  T_lift = %6.0f N  |  pitch = %.1f×  |  CL/CD = %.1f",
                    T_lift_val, ld_hud.CL_blade, ld_hud.CL_blade / 0.20)
                lift_cl_lbl.text[] = @sprintf("R = %.1f m  |  β = %.1f°  |  elev = %.1f°  |  margin = %.1f×",
                    ld_hud.rotor_radius, rad2deg(β_actual), elev_lift_val, sf.lift_margin)
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

        # ── Torque & Power Balance ────────────────────────────────────────────
        tau_aero_lbl.text[]     = @sprintf("τ_aero  = %7.0f N·m   (wind drives rotor)", sf.tau_aero)
        tau_gen_lbl.text[]      = @sprintf("τ_gen   = %7.0f N·m   (MPPT brake on PTO)", sf.tau_gen)
        delta_omega_lbl.text[]  = @sprintf("Δω (hub−PTO)  = %8.4f rad/s", sf.delta_omega)

        # ── Structural ───────────────────────────────────────────────────────
        t_frame_lbl.text[] = @sprintf("  max %5.0f N  ·  FoS %s", sf.T_max, fos_str(sf.fos_tether))
        c_frame_lbl.text[] = @sprintf("  max util %4.1f%%  ·  FoS %s",
                                        sf.ring_max_util*100.0, fos_str(sf.fos_ring))
        sag_lbl.text[]     = @sprintf("Max rope sag %5.1f mm  (seg %2d)  |  slack: %d lines",
                                        sf.max_sag_mm, sf.sag_seg, sf.n_slack)

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
        options=["Canonical 5-line", "v5 Optimized 8-line", "v5-safe 8-line"],
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
            switch_btn.buttoncolor[] = :steelblue
            switch_btn.labelcolor[]  = :white
            switch_btn.label[]       = "Switch Configuration"
        else
            switch_btn.buttoncolor[] = :grey30
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
            ld_lbl_A.text[] = "Pitch Factor"
            ld_sl_A.range[] = 0.5:0.1:3.0
            ld_sl_A.value[] = 1.0
            ld_lbl_B.text[] = "Radius (m)"
            ld_sl_B.range[] = 0.5:0.1:5.0
            ld_sl_B.value[] = 3.7      # auto-sized for v5 10kW
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
            # a = pitch factor (CL_blade), b = rotor radius
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
    return (fig, config_changed_obs)
end

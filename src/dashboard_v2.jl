# src/dashboard_v2.jl
# Single-window "cockpit" dashboard (v2) for KiteTurbineDynamics.jl.
#
# Contrast with v1 (build_dashboard in visualization.jl): v1 is an aggregate HUD
# with the telemetry in a separate window. v2 puts the 3D viewport, the
# per-component TRPT diagnostic panels (ring health, tension chain, torque chain)
# and a bottom cockpit telemetry strip in ONE window, all bound to a single frame
# Observable driven by a Play/scrub control so everything animates together.
#
# IMPORTANT: this does NOT modify build_dashboard (v1). The 3D scene block below is
# copied verbatim from v1's known-good code so it renders identically; only the
# surrounding layout + panel wiring + playback are new. Panels are the extracted,
# layout-agnostic functions from dashboard_panels.jl and read efs[end], so the
# frame handler feeds a growing slice ext_frames[1:fi] (the proven standalone path).

"""
    build_dashboard_v2(sys, p, frames; times, u_settled, wind_fn, lift_device, config_name) → Figure

Build the single-window v2 cockpit dashboard from precomputed ODE state snapshots.
Returns the Figure; `display(GLMakie.Screen(), fig)` to show it.
"""
function build_dashboard_v2(sys        ::KiteTurbineSystem,
                             p          ::SystemParams,
                             frames     ::Vector{<:AbstractVector};
                             times      ::Union{Vector{Float64}, Nothing} = nothing,
                             u_settled  ::Union{Vector{Float64}, Nothing} = nothing,
                             wind_fn    ::Union{Function, Nothing}        = nothing,
                             lift_device::Union{Nothing, LiftDevice}      = nothing,
                             config_name::String = "Canonical 5-line")

    n_frames = length(frames)
    n_frames == 0 && error("build_dashboard_v2: no frames to display")
    n_seg = sys.n_ring - 1
    N     = sys.n_total
    Nr    = sys.n_ring

    hub_gid  = sys.ring_ids[Nr]
    hub_node = sys.nodes[hub_gid]::RingNode
    hub_R    = hub_node.radius
    hub_ri   = hub_node.ring_idx

    # Resolved (value, not observable) wind + lift used for frame capture below.
    wf       = isnothing(wind_fn) ? (pos, t) -> [p.v_wind_ref, 0.0, 0.0] : wind_fn
    lift_dev = isnothing(lift_device) ?
        RotaryLifterParams(3.7, 0.05, 3, 0.12, 1.0, 0.20, 40.0, 25.0, 1.5e5, 5.0) :
        lift_device

    # ── Tilted ring basis + segment tension closures (match v1) ───────────────
    _perp_fn = (u) -> _tilted_ring_basis(u, sys, hub_gid, hub_ri)
    _seg_T   = (u, s, j) -> get_segment_tension(u, sys, p, s, j)

    # ── Per-frame telemetry + extended diagnostics ────────────────────────────
    sim_frames = [capture_frame(u_f, sys, p,
                    isnothing(times) ? 0.0 : times[i], wf, lift_dev;
                    brake_engaged=sys.brake_engaged[])
                  for (i, u_f) in enumerate(frames)]
    ext_frames = [capture_extended(u_f, sys, p,
                    isnothing(times) ? 0.0 : times[i], wf, lift_dev;
                    brake_engaged=sys.brake_engaged[])
                  for (i, u_f) in enumerate(frames)]

    # ── Observables (names match the v1 3D block copied below) ────────────────
    frame_obs       = Observable(1)
    frames_obs      = Observable(frames)
    sim_frames_obs  = Observable(sim_frames)
    ext_obs         = Observable(ext_frames[1:1])
    times_ref       = Ref(isnothing(times) ? Float64[] : collect(times))
    u_obs           = @lift $frames_obs[$frame_obs]
    lift_device_obs = Observable{Union{Nothing, LiftDevice}}(lift_dev)
    wind_fn_obs     = Observable{Function}(wf)

    # Layer visibility (all on; kept for parity with the copied v1 block)
    vis_tethers = Observable(true); vis_rings  = Observable(true)
    vis_hub     = Observable(true); vis_bridles = Observable(true)
    vis_bearing = Observable(true); vis_lift   = Observable(true)
    vis_backline = Observable(true); vis_ground = Observable(true)

    # ── A1 Instrument dark theme ──────────────────────────────────────────────
    A1_BG        = RGBf(0.039, 0.047, 0.063)
    A1_PANEL     = RGBf(0.071, 0.086, 0.114)
    A1_EDGE      = RGBf(0.133, 0.165, 0.208)
    A1_INK       = RGBf(0.910, 0.933, 0.965)
    A1_INK_DIM   = RGBf(0.604, 0.655, 0.714)
    A1_INK_FAINT = RGBf(0.392, 0.447, 0.518)
    A1_ACCENT    = RGBf(0.224, 0.816, 0.847)
    A1_GREEN     = RGBf(0.2, 0.8, 0.3)
    A1_ORANGE    = RGBf(0.95, 0.55, 0.1)
    A1_RED       = RGBf(0.95, 0.2, 0.2)
    pal = DashboardPalette(A1_BG, A1_PANEL, A1_EDGE, A1_INK, A1_INK_DIM,
                           A1_INK_FAINT, A1_ACCENT, A1_GREEN, A1_ORANGE, A1_RED)

    set_theme!(theme_dark())
    fig = Figure(size=(1780, 1180), backgroundcolor=A1_BG)
    # Layout — 6 rows × 6 cols. The three tall diagnostic bar charts sit BESIDE
    # each other (Rod's request) so the ring/torque/tension relationship reads at
    # a glance; the rotor power dials stack VERTICALLY beside them (Rod: "stacked
    # beside the bar charts top to bottom … like the rotors are"), with the 3D
    # viewport filling the rest of the tall row:
    #   ROW 1  cockpit telemetry strip (full width, cols 1:6)
    #   ROW 2  headers: TORQUE | RING HEALTH | TENSION | ROTOR POWER | 3D VIEWPORT
    #   ROW 3  torque(1) | ring(2) | tension(3) | rotor_gauges! stacked(4) | 3D(5:6)  ← TALL
    #   ROW 4  headers: TWIST VIEW | CONFIG & CONTROLS | EVENT LOG
    #   ROW 5  twist_view! (1) | config_panel! (2:3) | event log (4:6)
    #   ROW 6  playback controls (full width, cols 1:6)
    # colsize!/rowsize! are applied at the end, once every cell has been placed.

    # ── 3D Axis (VERBATIM from build_dashboard v1, only the grid cell changed) ──
    # Placed in the tall row's viewport cell (row 3, cols 5:6). Every
    # lines!/scatter! call below targets `ax3d`, so nothing else in the block moves.
    ax3d = Axis3(fig[3, 5:6];
                 xlabel    = "Downwind X [m]",
                 ylabel    = "Crosswind Y [m]",
                 zlabel    = "Altitude Z [m]",
                 aspect    = :data,
                 titlevisible = false)

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
    bearing_gid_viz    = sys.bearing_id
    sky_anchor_gid_viz = sys.sky_anchor_id
    bearing_obs        = @lift $u_obs[3*(bearing_gid_viz-1)+1    : 3*bearing_gid_viz]
    sky_anchor_obs     = @lift $u_obs[3*(sky_anchor_gid_viz-1)+1 : 3*sky_anchor_gid_viz]
    lift_point_obs     = sky_anchor_obs

    # Bridle lines: bearing → hub ring vertices
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

    # Cyan line: bearing → sky anchor
    lift_line_obs = @lift begin
        bp = $bearing_obs
        ap = $sky_anchor_obs
        ([bp[1], ap[1]], [bp[2], ap[2]], [bp[3], ap[3]])
    end
    lines!(ax3d, @lift($lift_line_obs[1]), @lift($lift_line_obs[2]),
                 @lift($lift_line_obs[3]); color=:cyan, linewidth=2.0, visible=vis_lift)

    # Sky anchor marker
    scatter!(ax3d, @lift([$sky_anchor_obs[1]]), @lift([$sky_anchor_obs[2]]),
                   @lift([$sky_anchor_obs[3]]); color=:cyan, markersize=12,
             marker=:circle, visible=vis_lift)

    # Bearing marker (white diamond)
    scatter!(ax3d, @lift([$bearing_obs[1]]), @lift([$bearing_obs[2]]),
                   @lift([$bearing_obs[3]]); color=:white, markersize=12,
             marker=:diamond)

    # Lift kite tether + kite marker — position is dynamic
    kite_pos_obs = @lift begin
        lp  = $lift_point_obs
        ld  = $lift_device_obs
        wfn = $wind_fn_obs
        fi  = $frame_obs
        tr = times_ref[]
        t_now = (!isempty(tr) && fi <= length(tr)) ? tr[fi] : 0.0
        v_vec   = wfn(lp, t_now)
        v_now   = max(sqrt(v_vec[1]^2 + v_vec[2]^2), 0.5)
        sh      = normalize(lp)
        sh_horiz = [sh[1], sh[2], 0.0]
        sh_hat   = sh_horiz ./ max(norm(sh_horiz), 1e-6)
        if !isnothing(ld)
            _, _, elev_deg = lift_force_steady(ld, p.rho, v_now)
            θ = deg2rad(max(5.0, elev_deg))
            ll = (ld isa SingleKiteParams   ? ld.line_length :
                  ld isa StackedKitesParams ? ld.spacing * ld.n_kites :
                  ld.line_length)
            lp .+ ll .* (sh_hat .* cos(θ) .+ [0.0, 0.0, sin(θ)])
        else
            v_stall  = 3.0
            v_ref_kd = max(p.v_wind_ref, 8.0)
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

    # Back line — coral (taut) / grey (slack), sky anchor → ground anchor
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

    # Wind indicator — marching "ants" upwind of the rotor
    wind_dot_obs = @lift begin
        u       = $u_obs
        ctr     = u[3*(hub_gid-1)+1 : 3*hub_gid]
        wfn     = $wind_fn_obs
        v_vec   = wfn(ctr, 0.0)
        v_mag   = max(sqrt(v_vec[1]^2 + v_vec[2]^2), 0.5)
        n_dots  = 20
        fi      = $frame_obs
        flow    = mod(fi * 0.3, 1.0)
        spacing = 0.5
        xs = Float64[]; ys = Float64[]; zs = Float64[]
        alphas = Float64[]
        for i in 0:(n_dots-1)
            dist = 3.0 + i * spacing + flow * spacing
            push!(xs, ctr[1] - dist)
            push!(ys, ctr[2] + 0.15 * sin(i * 1.7 + flow * π))
            push!(zs, ctr[3] + 0.15 * cos(i * 2.3 + flow * π))
            push!(alphas, 0.85 * (1.0 - i / n_dots))
        end
        (xs, ys, zs, alphas)
    end
    wind_dots = [scatter!(ax3d,
        @lift([$wind_dot_obs[1][i+1]]),
        @lift([$wind_dot_obs[2][i+1]]),
        @lift([$wind_dot_obs[3][i+1]]);
        color=RGBf(0.50, 0.58, 0.72),
        markersize=@lift(4 + 3 * $wind_dot_obs[4][i+1]),
        alpha=@lift($wind_dot_obs[4][i+1]))
        for i in 0:19]

    # ══ Cockpit telemetry strip (ROW 1, full width) ═══════════════════════════
    strip_power = Observable("0.00 kW")
    strip_rpm   = Observable("0 rpm")
    strip_fos   = Observable("   ∞")
    strip_util  = Observable("0%")
    strip_wind  = Observable("0.0 m/s")
    strip_twist = Observable("0°")
    strip_time  = Observable("0.00 s")

    strip = GridLayout(fig[1, 1:6])
    strip_kpis = [("GEN ELEC kW", strip_power), ("Ω HUB rpm", strip_rpm),
                  ("TETHER FoS", strip_fos), ("RING UTIL", strip_util),
                  ("WIND m/s", strip_wind), ("TWIST", strip_twist),
                  ("TIME", strip_time)]
    for (i, (lbl, vo)) in enumerate(strip_kpis)
        Label(strip[1, i], vo;  fontsize=22, font=:bold, color=A1_INK,     halign=:left, tellwidth=false)
        Label(strip[2, i], lbl; fontsize=9,             color=A1_INK_DIM, halign=:left, tellwidth=false)
        colsize!(strip, i, Fixed(150))
    end

    # ══ Panel grid — shared labels ════════════════════════════════════════════
    ring_labels  = ["R$i" for i in 1:Nr]
    exp_idxs     = [er.ring_idx for er in sys.expansion_rotors]
    rotor_labels = ["Hub"; ["R$(er.ring_idx)" for er in sys.expansion_rotors]]
    P_rated_kw   = p.p_rated_w / 1000.0

    # ── Event log infrastructure (Label placed in ROW 5; wired in frame handler)─
    event_log = Observable("")
    log_lines = String[]
    push_log! = function (msg::String)
        pushfirst!(log_lines, msg)
        while length(log_lines) > 6; pop!(log_lines); end
        event_log[] = join(log_lines, "\n")
    end
    prev_warn = Ref((buckle=false, slack=false, overtwist=false, brake=false))
    push_log!("● v2 cockpit ready — $(config_name), $(n_frames) frames")

    # ── ROW 2: headers for the TALL diagnostic row ────────────────────────────
    for (col, hdr) in [(1, "TORQUE CHAIN"), (2, "RING HEALTH"), (3, "TENSION CHAIN")]
        Label(fig[2, col], hdr; fontsize=10, color=A1_ACCENT, font=:bold, halign=:center)
    end
    Label(fig[2, 4], "ROTOR POWER"; fontsize=10, color=A1_ACCENT, font=:bold, halign=:center)
    Label(fig[2, 5:6], "3D VIEWPORT"; fontsize=10, color=A1_ACCENT, font=:bold, halign=:center)

    # ── ROW 3 (TALL): three bar charts beside each other + 3D viewport ────────
    # torque | ring health | tension sit side-by-side so their relationship reads
    # at a glance; all three x-axes autoscale to the current frame (see panels).
    torque_chain!(fig[3, 1], ext_obs, pal; n_segments=Nr-1)
    ring_health!(fig[3, 2], ext_obs, pal; n_rings=Nr, ring_labels=ring_labels, exp_rings=exp_idxs)
    tension_chain!(fig[3, 3], ext_obs, pal; n_segments=Nr-1, swl=Float64(TETHER_SWL)/1000.0)
    # Rotor power dials stacked vertically (hub top → expansion rotors down), tall
    # like the bar charts beside them (Rod's request). horizontal=false → stacked.
    rotor_gauges!(GridLayout(fig[3, 4]), ext_obs, pal;
                  labels=rotor_labels, P_rated_kw=P_rated_kw, horizontal=false)
    # (ax3d already placed at fig[3, 5:6])

    # ── ROW 4: headers for the secondary row ──────────────────────────────────
    Label(fig[4, 1],   "TWIST VIEW";  fontsize=10, color=A1_ACCENT, font=:bold, halign=:center)
    Label(fig[4, 2:3], "CONFIG & CONTROLS"; fontsize=10, color=A1_ACCENT, font=:bold, halign=:center)
    Label(fig[4, 4:6], "EVENT LOG"; fontsize=10, color=A1_ACCENT, font=:bold, halign=:center)

    # ── ROW 5: twist | config panel (wide) | event log (wide) ─────────────────
    # Rotor gauges moved up into the TALL row (col 4); config now gets cols 2:3 so
    # its menus + peak/regen lines have room and stay clear of the play bar.
    twist_view!(fig[5, 1], ext_obs, pal; n_segments=Nr-1)
    cfg = config_panel!(GridLayout(fig[5, 2:3]), ext_obs, pal; config_name=config_name)
    Label(fig[5, 4:6], event_log; fontsize=9, color=A1_INK_DIM,
          halign=:left, valign=:top, justification=:left, tellwidth=false, tellheight=false)

    # Wire config menus → event log (live rerun deferred).
    on(cfg.design.selection)    do s; push_log!(@sprintf("[%.2fs] ⚙ design → %s (rerun pending)",    sim_frames[frame_obs[]].t, s)); end
    on(cfg.scenario.selection)  do s; push_log!(@sprintf("[%.2fs] ⚙ scenario → %s (rerun pending)",  sim_frames[frame_obs[]].t, s)); end
    on(cfg.generator.selection) do s; push_log!(@sprintf("[%.2fs] ⚙ generator → %s (rerun pending)", sim_frames[frame_obs[]].t, s)); end
    on(cfg.payout.selection)    do s; push_log!(@sprintf("[%.2fs] ⚙ payout → %s (rerun pending)",     sim_frames[frame_obs[]].t, s)); end

    # ══ Playback controls (ROW 6, full width) ═════════════════════════════════
    ctrlg = GridLayout(fig[6, 1:6])
    frame_slider = Slider(ctrlg[1, 1]; range=1:n_frames, startvalue=1)
    connect!(frame_obs, frame_slider.value)
    play_btn  = Button(ctrlg[1, 2]; label="▶ Play", buttoncolor=to_color(:darkgreen), labelcolor=:white)
    stop_btn  = Button(ctrlg[1, 3]; label="■ Stop", buttoncolor=to_color(:grey20),    labelcolor=:white)
    frame_ctr = Label(ctrlg[1, 4], @sprintf("1/%d", n_frames);
                      fontsize=10, color=A1_INK_DIM, tellwidth=false)
    is_playing = Observable(false)
    speed_obs  = Observable(1.0)
    Label(ctrlg[1, 5], "speed"; fontsize=9, color=A1_INK_DIM, tellwidth=false)
    speed_menu = Menu(ctrlg[1, 6]; options=["0.25×","0.5×","1×","2×","4×"], default="1×", width=80)
    on(speed_menu.selection) do s
        speed_obs[] = s=="0.25×" ? 0.25 : s=="0.5×" ? 0.5 :
                      s=="2×"    ? 2.0  : s=="4×"   ? 4.0 : 1.0
    end
    colsize!(ctrlg, 1, Relative(0.55))

    play_wall_t0  = Ref(0.0)
    play_frame_t0 = Ref(1)
    start_play!() = (is_playing[] = true;
                     play_btn.label[] = "|| Pause";
                     play_btn.buttoncolor[] = to_color(:darkorange);
                     play_wall_t0[] = time();
                     play_frame_t0[] = frame_slider.value[])
    stop_play!()  = (is_playing[] = false;
                     play_btn.label[] = "▶ Play";
                     play_btn.buttoncolor[] = to_color(:darkgreen))
    on(play_btn.clicks) do _
        is_playing[] ? stop_play!() : start_play!()
    end
    on(stop_btn.clicks) do _
        stop_play!()
        set_close_to!(frame_slider, 1)
    end
    on(speed_obs) do _
        if is_playing[]
            play_wall_t0[]  = time()
            play_frame_t0[] = frame_slider.value[]
        end
    end

    # ══ Single frame handler: panels + strip + counter + event log ════════════
    on(frame_obs) do fi
        (fi < 1 || fi > n_frames) && return
        ext_obs[] = ext_frames[1:fi]      # panels read efs[end] → tracks current frame
        sf = sim_frames[fi]
        strip_power[] = @sprintf("%.2f kW",  sf.P_kw)
        strip_rpm[]   = @sprintf("%.0f rpm", abs(sf.omega_hub) * 60 / (2π))
        strip_fos[]   = fos_str(sf.fos_tether)
        strip_util[]  = @sprintf("%.0f%%",   sf.ring_max_util * 100)
        strip_wind[]  = @sprintf("%.1f m/s", sf.V_hub)
        strip_twist[] = @sprintf("%.0f°",    sf.delta_alpha_deg)
        strip_time[]  = @sprintf("%.2f s",   sf.t)
        frame_ctr.text[] = @sprintf("%d/%d", fi, n_frames)

        # Event log — emit on warning-state transitions.
        w  = (buckle=sf.buckling_risk, slack=sf.line_slack,
              overtwist=sf.torsional_overtwist, brake=sf.brake_engaged)
        pw = prev_warn[]
        w.buckle    && !pw.buckle    && push_log!(@sprintf("[%.2fs] ⚠ buckling risk — ring util %.0f%%", sf.t, sf.ring_max_util*100))
        w.slack     && !pw.slack     && push_log!(@sprintf("[%.2fs] ⚠ slack line detected", sf.t))
        w.overtwist && !pw.overtwist && push_log!(@sprintf("[%.2fs] ⚠ over-twist |Δα|=%.0f°", sf.t, sf.delta_alpha_deg))
        w.brake     && !pw.brake     && push_log!(@sprintf("[%.2fs] ● brake engaged", sf.t))
        !w.brake    && pw.brake      && push_log!(@sprintf("[%.2fs] ● brake released", sf.t))
        prev_warn[] = w
    end

    @async while true
        if is_playing[]
            wall_elapsed = time() - play_wall_t0[]
            target_nf    = play_frame_t0[] + round(Int, wall_elapsed * speed_obs[] / 0.02)
            nf = clamp(target_nf, 1, n_frames)
            nf != frame_slider.value[] && set_close_to!(frame_slider, nf)
            nf >= n_frames && stop_play!()
        end
        sleep(0.016)
    end

    # ══ Row + column sizing (all cells placed) ════════════════════════════════
    rowsize!(fig.layout, 1, Fixed(56))    # cockpit strip
    rowsize!(fig.layout, 2, Fixed(20))    # tall-row headers
    rowsize!(fig.layout, 4, Fixed(22))    # secondary-row headers
    rowsize!(fig.layout, 5, Fixed(340))   # secondary row: twist | config | log | rotor (taller so config fits above the control bar)
    rowsize!(fig.layout, 6, Fixed(46))    # playback controls
    # Row 3 (the tall diagnostic row) stays Auto and takes all remaining height.

    # Columns: keep the three bar charts + rotor dial stack narrow (cols 1-4) so
    # the 3D viewport (cols 5:6) stays wide. Cols 5-6 stay Auto and share the rest.
    colsize!(fig.layout, 1, Relative(0.12))
    colsize!(fig.layout, 2, Relative(0.12))
    colsize!(fig.layout, 3, Relative(0.12))
    colsize!(fig.layout, 4, Relative(0.12))

    # Floating tooltips on hover (Rod's request). The bar panels set custom
    # `inspector_label`s (ring/segment id + value); other inspectable plots show
    # their default readout.
    DataInspector(fig)

    notify(frame_obs)
    return fig
end

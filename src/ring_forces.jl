using LinearAlgebra

function compute_ring_forces!(forces      ::Vector{<:AbstractVector},
                               torques     ::AbstractVector,
                               u           ::AbstractVector,
                               omega       ::AbstractVector,
                               sys         ::KiteTurbineSystem,
                               p           ::SystemParams,
                               wind_fn     ::Function,
                               t           ::Float64,
                               lift_device ::Union{Nothing, LiftDevice} = nothing)
    N        = sys.n_total
    hub_gid  = sys.rotor.node_id
    hub_ri   = (sys.nodes[hub_gid]::RingNode).ring_idx
    hub_pos  = @view u[3*(hub_gid-1)+1 : 3*hub_gid]
    bearing_gid    = sys.bearing_id
    bearing_pos    = @view u[3*(bearing_gid-1)+1 : 3*bearing_gid]
    sky_anchor_gid = sys.sky_anchor_id
    sky_anchor_pos = @view u[3*(sky_anchor_gid-1)+1 : 3*sky_anchor_gid]

    v_wind  = wind_fn(hub_pos, t)

    # ── Rotor disc aerodynamics — CT thrust only ──────────────────────────
    # NOTE: a previous kite-lift block (q·A·CL in direction [0,0,1]) has been
    # removed.  It was wrong for two reasons:
    #
    #   1. Geometry: [0,0,1] is perpendicular to horizontal wind — correct only
    #      for a horizontal disc (90° elevation).  Our disc normal is at 30°
    #      elevation; a static disc at this angle produces normal force along the
    #      shaft axis [cos30°,0,sin30°], not straight up.
    #
    #   2. Double-count: the CT thrust below already captures the dominant axial
    #      hub force.  Flat blades rotating in the disc plane produce zero net
    #      kite-style lift on the hub; in-plane wind loads (v·sin30° component)
    #      are small and point slightly DOWNWARD at 30° elevation.
    #
    # The only legitimate aerodynamic hub forces are CT thrust (below) and the
    # separate lift device (further below).

    # ── Rotor thrust + aero torque ─────────────────────────────────────────
    v_hub_mag = norm(v_wind)
    if v_hub_mag > 0.1
        omega_rotor = omega[hub_ri]
        lambda_t    = abs(omega_rotor) * sys.rotor.radius / v_hub_mag
        elev_angle  = atan(hub_pos[3], sqrt(hub_pos[1]^2 + hub_pos[2]^2))

        # ── Disc tilt ─────────────────────────────────────────────────────
        # Disc tilt (pitch/yaw of the rotor plane) now emerges from the
        # quasi-static tilt model in dynamics.jl.  The ring-plane basis for
        # attachment points is tilted by non-shaft torque from the bridle
        # tension network — no separate aero correction needed.
        #
        # Aerodynamic area convention: both Cp and CT are normalised to the FULL DISC
        # area π·R² (outer-radius convention, consistent with AeroDyn BEM source data
        # Rotor_TRTP_Sizing_Iteration2.xlsx).  The TRPT blades are physically annular
        # (inner tip at trpt_hub_radius ≈ 0.4·R, outer tip at R), but the inner hub
        # region contributes negligibly at operational TSR so the BEM Cp/CT values
        # referenced to π·R² are consistent with the physical swept annulus.
        # CT uses the BEM table (not a fixed 0.8 — at λ_opt ≈ 4.1, CT_BEM ≈ 0.548).
        thrust_mag  = 0.5 * p.rho * v_hub_mag^2 *
                      π * sys.rotor.radius^2 * ct_at_tsr(lambda_t) *
                      cos(elev_angle)^2
        tether_dir  = hub_pos .- @view(u[1:3])   # ground is node 1
        tl          = norm(tether_dir)
        if tl > 0; tether_dir ./= tl; end
        forces[hub_gid] .+= thrust_mag .* tether_dir

        P_aero   = 0.5 * p.rho * v_hub_mag^3 *
                   π * sys.rotor.radius^2 * cp_at_tsr(lambda_t) *
                   cos(elev_angle)^3
        # Wind always drives the rotor in the +ω direction regardless of current spin
        # direction. The previous sign(omega_rotor) factor caused negative aero torque
        # when the hub reversed (ω < 0), which physically-incorrectly reinforced the
        # reversal and pinned P_peak to zero. Floor at 0.5 rad/s prevents division blow-up
        # at standstill while giving a finite starting torque.
        tau_aero = P_aero / max(abs(omega_rotor), 0.5)
        torques[hub_ri] += tau_aero
    end

    # ── Generator MPPT torque on ground node ──────────────────────────────
    gnd_ri    = (sys.nodes[sys.ring_ids[1]]::RingNode).ring_idx   # = 1
    omega_gnd = omega[gnd_ri]
    
    # Winch payout base and geometric scaling for system size
    payout_base = p.β_min < 5.0 ? 15.0 : p.β_min
    geom_scale  = p.tether_length / 30.0
    max_payout  = payout_base * geom_scale

    ctrl_mode = round(p.β_rate_max)
    
    if ctrl_mode ≈ 1.0 || ctrl_mode ≈ 2.0
        # Physical shaft elevation angle β_actual
        β_actual = atan(hub_pos[3], sqrt(hub_pos[1]^2 + hub_pos[2]^2))
        β_design = p.elevation_angle
        β_furl   = deg2rad(60.0)
        elev_scale = 1.0 - 0.8 * clamp((β_actual - β_design) / (β_furl - β_design), 0.0, 1.0)
        
        omega_hub = omega[hub_ri]
        
        if ctrl_mode ≈ 1.0
            # Mode 1: Active Torsional Damping
            tau_mppt = p.k_mppt * max(omega_hub, 0.0)^2
            power_scale = (p.p_rated_w / 10000.0)^2
            c_d = 10.0 * power_scale
            tau_damp = c_d * (omega_gnd - omega_hub)
            tau_gen = max(0.0, (tau_mppt + tau_damp) * elev_scale)
        else
            # Mode 2: LPF Speed MPPT (smooth hub speed)
            tau_gen = p.k_mppt * max(omega_hub, 0.0)^2 * elev_scale
        end
    else
        # Mode 0: Standard MPPT with dynamic max payout
        tau_gen = p.k_mppt * max(omega_gnd, 0.0)^2 * max(0.0, 1.0 - p.backline_payout / max_payout)
    end
    
    torques[gnd_ri] -= tau_gen

    # ── Inter-ring torsional damping ──────────────────────────────────────────
    # The torsional SPRING (coupling per ring-angle twist Δα) is provided entirely
    # by rope_forces.jl via the physical rope geometry.  Adding an explicit spring
    # here caused double-counting (~2× braking torque), which stopped the hub.
    #
    # We add only an angular-velocity damper c_s × Δω between adjacent rings.
    # Without this, the TRPT torsional mode is underdamped: the hub winds up to
    # max twist then rebounds through zero into reverse, where low-λ aero torque
    # cannot restore it.  c_s is sized for ζ ≈ 1.0 on the LOCAL ring-pair mode
    # (ω_n = √(k_sec/I_min)); this over-damps the global torsional mode (ζ > 1),
    # which is fine — it simply prevents torsional oscillation entirely.
    Nr      = sys.n_ring
    alpha   = @view u[6N+1 : 6N+Nr]
    L_seg   = p.tether_length / (Nr - 1)
    EA_rope = p.e_modulus * π * (p.tether_diameter / 2)^2

    for s in 1:length(sys.ring_ids) - 1
        node_a = sys.nodes[sys.ring_ids[s]]::RingNode
        node_b = sys.nodes[sys.ring_ids[s+1]]::RingNode
        ri_a   = node_a.ring_idx
        ri_b   = node_b.ring_idx
        r_s    = (node_a.radius + node_b.radius) * 0.5
        # Principal-value inter-ring twist (−π, π]: prevents accumulated whole-revolution
        # counts from falsely triggering the collapse guard or inflating k_sec.
        Δα     = mod(alpha[ri_b] - alpha[ri_a] + π, 2π) - π
        abs(Δα) >= 0.95π && continue

        # Estimate local torsional stiffness via rope geometry (for damper sizing only)
        chord  = sqrt(L_seg^2 + 2 * r_s^2 * (1 - cos(max(abs(Δα), 0.001))))
        T_est  = p.n_lines * EA_rope * max(0.0, (chord - L_seg) / L_seg)
        τ_est  = T_est * r_s^2 * sin(max(abs(Δα), 0.001)) / chord
        k_sec  = max(τ_est / max(abs(Δα), 0.01), 200.0)   # floor at 200 N·m/rad
        I_s    = min(node_a.inertia_z, node_b.inertia_z)
        c_s    = 2.0 * sqrt(k_sec * I_s)       # ζ = 1.0 on local ring-pair mode
        Δω     = omega[ri_b] - omega[ri_a]
        torques[ri_a] += c_s * Δω
        torques[ri_b] -= c_s * Δω
    end

    # ── Lift line force at the SKY ANCHOR ─────────────────────────────────
    # The lifter kite pulls the sky anchor at its physical elevation angle
    # (~80° for a rotary lifter at rated wind).  The cyan line (a rope
    # sub-segment between bearing and sky anchor) then transmits a fraction
    # of this force to the bearing along its current direction.  The
    # bearing therefore only feels gravity, bridles, and cyan-line tension
    # — keeping it on-axis with symmetric bridles regardless of the lifter
    # elevation.  When the back line is paid out, the kite lift wins the
    # tug-of-war at the sky anchor and lifts the whole assembly.
    if lift_device !== nothing
        v_lift = wind_fn(sky_anchor_pos, t)    # 3D wind at sky anchor altitude
        v_hmag = sqrt(v_lift[1]^2 + v_lift[2]^2)

        # Passive kites stall below ~2 m/s; rotary lifter is exempt
        PASSIVE_KITE_STALL_SPEED = 2.0
        is_passive = !(lift_device isa RotaryLifterParams)
        _, T_lift, elev_lift_deg = lift_force_steady(lift_device, p.rho, v_hmag)
        if is_passive && v_hmag < PASSIVE_KITE_STALL_SPEED
            T_lift = 0.0
        end

        # Fixed-direction force vector at the kite's elevation angle.
        # Downwind unit vector built from the actual wind direction so the
        # model handles non-+x wind heading correctly.
        if T_lift > 0.0 && v_hmag > 1e-6
            downwind = [v_lift[1] / v_hmag, v_lift[2] / v_hmag, 0.0]
            θ_lift   = deg2rad(elev_lift_deg)
            lift_dir = cos(θ_lift) .* downwind .+ sin(θ_lift) .* [0.0, 0.0, 1.0]
            forces[sky_anchor_gid] .+= T_lift .* lift_dir
        end
    end

    # ── Back line — quasi-static catenary from SKY ANCHOR to ground anchor ─
    # The back line attaches at the sky anchor (the upper end of the cyan
    # line, where the kite force also lands).  Backline payout increases
    # the unstretched length — when payout > 0 the line goes slack, the
    # kite lift wins at the sky anchor, the sky anchor rises and pulls the
    # bearing up via the cyan line, tilting the rotor and spilling wind.
    #
    # NOTE: the geometric constants 6.0 (bearing_offset) and 5.0 (CYAN_L0)
    # MUST match initialization.jl.  Centralising them on `sys` is a future
    # cleanup; for now they're duplicated with this comment as the link.
    back_ax        = p.tether_length * cos(p.elevation_angle) + p.back_anchor_fwd_x
    bearing_offset = 6.0
    cyan_L0        = 5.0

    # 2D projection: horizontal plane distance + vertical (anchor at z=0)
    b_dx   = sqrt((sky_anchor_pos[1] - back_ax)^2 + sky_anchor_pos[2]^2)
    b_dz   = sky_anchor_pos[3]
    b_dist = sqrt(b_dx^2 + b_dz^2)

    # Design rest length: distance ground-anchor → design sky-anchor position.
    # Sky anchor at design = ring_pos[end] + (bearing_offset+cyan_L0)·shaft_dir,
    # which equals (tether_length + bearing_offset + cyan_L0) along the shaft
    # from the origin.
    L_axis_design        = p.tether_length + bearing_offset + cyan_L0
    design_sky_anchor_x  = L_axis_design * cos(p.elevation_angle)
    design_sky_anchor_z  = L_axis_design * sin(p.elevation_angle)
    back_L0_design       = sqrt((design_sky_anchor_x - back_ax)^2 + design_sky_anchor_z^2)
    # L₀ = design distance + payout (winch releases line)
    back_L0 = back_L0_design + p.backline_payout

    # Tension-only: slack if anchor-to-sky-anchor distance < rest length
    if b_dist > back_L0 + 1e-6
        # Backline weight (3 mm Dyneema)
        w_back = dyneema_weight_Npm(0.003)

        # Catenary in the vertical plane: anchor at (0,0), sky anchor at (b_dx, b_dz)
        _, _, Fx_top, Fz_top, _ = catenary_forces(
            0.0, 0.0, b_dx, b_dz,
            back_L0, w_back, p.EA_back_line)

        # Fx < 0 (pulls toward anchor), Fz < 0 (pulls down).
        if b_dx > 1e-12
            uh_x = (sky_anchor_pos[1] - back_ax) / b_dx
            uh_y = sky_anchor_pos[2] / b_dx
        else
            uh_x, uh_y = 0.0, 0.0
        end
        forces[sky_anchor_gid][1] += Fx_top * uh_x
        forces[sky_anchor_gid][2] += Fx_top * uh_y
        forces[sky_anchor_gid][3] += Fz_top
    end
end

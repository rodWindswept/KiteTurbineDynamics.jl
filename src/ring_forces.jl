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
    hub_vel  = @view u[3*N+3*(hub_gid-1)+1 : 3*N+3*hub_gid]
    β        = p.elevation_angle

    v_wind  = wind_fn(hub_pos, t)
    v_app   = v_wind .- hub_vel
    v_mag   = norm(v_app)

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

        # Aerodynamic area convention: both Cp and CT are normalised to the FULL DISC
        # area π·R² (outer-radius convention, consistent with AeroDyn BEM source data
        # Rotor_TRTP_Sizing_Iteration2.xlsx).  The TRPT blades are physically annular
        # (inner tip at trpt_hub_radius ≈ 0.4·R, outer tip at R), but the inner hub
        # region contributes negligibly at operational TSR so the BEM Cp/CT values
        # referenced to π·R² are consistent with the physical swept annulus.
        # CT uses the BEM table (not a fixed 0.8 — at λ_opt ≈ 4.1, CT_BEM ≈ 0.548).
        thrust_mag  = 0.5 * p.rho * v_hub_mag^2 *
                      π * sys.rotor.radius^2 * ct_at_tsr(lambda_t) * cos(elev_angle)^2
        tether_dir  = hub_pos .- @view(u[1:3])   # ground is node 1
        tl          = norm(tether_dir)
        if tl > 0; tether_dir ./= tl; end
        forces[hub_gid] .+= thrust_mag .* tether_dir

        P_aero   = 0.5 * p.rho * v_hub_mag^3 *
                   π * sys.rotor.radius^2 * cp_at_tsr(lambda_t) * cos(elev_angle)^3
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
    tau_gen   = p.k_mppt * omega_gnd^2 * sign(omega_gnd + 1e-9)
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

    # ── Lift line force at bearing node ────────────────────────────────────
    # The lift device flies DOWNWIND of and above the bearing.  The line tension
    # is determined by the lifter model (aerodynamic force balance).  We apply
    # the lifter-reported tension directly at the bearing; bridle springs
    # distribute it to the hub ring vertices.
    bearing_gid = sys.bearing_id
    bearing_pos = @view u[3*(bearing_gid-1)+1 : 3*bearing_gid]

    if lift_device !== nothing
        v_lift = wind_fn(hub_pos, t)           # 3D wind at hub altitude
        v_h1   = v_lift[1];  v_h2 = v_lift[2] # horizontal components
        v_hmag = sqrt(v_h1^2 + v_h2^2)        # horizontal wind speed
        if v_hmag > 0.1
            downwind = [v_h1 / v_hmag, v_h2 / v_hmag, 0.0]   # unit vec downwind (+X)
        else
            downwind = [1.0, 0.0, 0.0]
        end

        # Passive kites stall below ~2 m/s; rotary lifter is exempt
        PASSIVE_KITE_STALL_SPEED = 2.0
        is_passive = !(lift_device isa RotaryLifterParams)
        _, T_lift, elev_lift = lift_force_steady(lift_device, p.rho, v_hmag)
        if is_passive && v_hmag < PASSIVE_KITE_STALL_SPEED
            T_lift = 0.0
        end

        if T_lift > 0.0
            θ_lift = deg2rad(elev_lift)
            # Force direction: horizontal component downwind (+X) + vertical upward
            forces[bearing_gid][1] += T_lift * cos(θ_lift) * downwind[1]
            forces[bearing_gid][2] += T_lift * cos(θ_lift) * downwind[2]
            forces[bearing_gid][3] += T_lift * sin(θ_lift)
        end
    end

    # ── Back line — quasi-static catenary from bearing to ground anchor ──
    # Runs from a point 10 cm above the bearing down to a fixed ground
    # anchor.  The anchor stays at back_anchor_fwd_x downwind of the hub's
    # design x-projection.  Backline payout increases the unstretched length
    # (simulating winch release) — when payout > 0 the line goes slack and
    # the bearing rises under lift, tilting the rotor via the bridle network.
    back_attach_z = 0.10   # metres above bearing (attachment on lift tether)
    back_ax = p.tether_length * cos(p.elevation_angle) + p.back_anchor_fwd_x

    # 2D projection: horizontal plane distance + vertical
    b_dx = sqrt((bearing_pos[1] - back_ax)^2 + bearing_pos[2]^2)
    b_dz = bearing_pos[3] + back_attach_z
    b_dist = sqrt(b_dx^2 + b_dz^2)

    # Design rest length (no payout): distance anchor→design bearing position
    design_bearing_x = p.tether_length * cos(p.elevation_angle)
    design_bearing_z = p.tether_length * sin(p.elevation_angle) + 2.0 + back_attach_z  # hub_z + bearing_offset + attach
    back_L0_design = sqrt((design_bearing_x - back_ax)^2 + design_bearing_z^2)
    # L₀ = design distance + payout (winch releases line)
    back_L0 = back_L0_design + p.backline_payout

    # Tension-only: slack if anchor-to-bearing distance < rest length
    if b_dist > back_L0 + 1e-6
        # Backline weight (3 mm Dyneema)
        w_back = dyneema_weight_Npm(0.003)

        # Catenary in the vertical plane: anchor at (0,0), bearing at (b_dx, b_dz)
        _, _, Fx_bearing, Fz_bearing, _ = catenary_forces(
            0.0, 0.0, b_dx, b_dz,
            back_L0, w_back, p.EA_back_line)

        # Fx < 0 (pulls bearing toward anchor), Fz < 0 (pulls bearing down).
        if b_dx > 1e-12
            uh_x = (bearing_pos[1] - back_ax) / b_dx
            uh_y = bearing_pos[2] / b_dx
        else
            uh_x, uh_y = 0.0, 0.0
        end
        forces[bearing_gid][1] += Fx_bearing * uh_x
        forces[bearing_gid][2] += Fx_bearing * uh_y
        forces[bearing_gid][3] += Fz_bearing
    end
end

using LinearAlgebra

"""
    get_generator_torque(u::AbstractVector, sys::KiteTurbineSystem, p::SystemParams, t::Float64, wind_fn::Function;
                         brake_engaged::Bool) -> (tau_gen::Float64, new_brake_engaged::Bool)

Single source of truth for the generator control law and mechanical brake logic.
Stateless and zero-allocation. Used by both the ODE solver and telemetry observers.
"""
function get_generator_torque(
    u::AbstractVector,
    sys::KiteTurbineSystem,
    p::SystemParams,
    t::Float64,
    wind_fn::Function;
    brake_engaged::Bool,
)
    N = sys.n_total
    Nr = sys.n_ring
    hub_gid = sys.rotor.node_id
    hub_ri = (sys.nodes[hub_gid]::RingNode).ring_idx
    gnd_ri = (sys.nodes[sys.ring_ids[1]]::RingNode).ring_idx

    omega_hub = u[6N + Nr + hub_ri]
    omega_gnd = u[6N + Nr + gnd_ri]
    hub_pos = @view u[(3 * (hub_gid - 1) + 1):(3 * hub_gid)]

    # Winch payout base and geometric scaling for system size
    payout_base = p.β_min < 5.0 ? 15.0 : p.β_min
    geom_scale = p.tether_length / 30.0
    max_payout = payout_base * geom_scale

    ctrl_mode = round(p.β_rate_max)

    # Check flying IMU telemetry health/availability
    imu_reliable = p.kp_elev ≈ 1.0

    if ctrl_mode ≈ 1.0 || ctrl_mode ≈ 2.0
        # Physical shaft elevation angle β_actual
        β_actual = atan(hub_pos[3], sqrt(hub_pos[1]^2 + hub_pos[2]^2))
        β_design = p.elevation_angle
        β_furl = deg2rad(60.0)
        elev_scale =
            1.0 - 0.8 * clamp((β_actual - β_design) / (β_furl - β_design), 0.0, 1.0)

        if ctrl_mode ≈ 1.0
            # Mode 1: Active Torsional Damping
            if imu_reliable
                # High-fidelity IMU Mode: Torsional Active Damping
                tau_mppt = sys.k_mppt_ref[] * max(omega_hub, 0.0)^2
                power_scale = (p.p_rated_w / 10000.0)^2
                c_d = 10.0 * power_scale
                tau_damp = c_d * (omega_gnd - omega_hub)
                tau_gen = (tau_mppt + tau_damp) * elev_scale
            else
                # Failsafe ground-only feedback: fall back to ground encoder speed (omega_gnd)
                tau_gen = sys.k_mppt_ref[] * max(omega_gnd, 0.0)^2 * elev_scale
            end
        else
            # Mode 2: LPF Speed MPPT (smooth hub speed)
            if imu_reliable
                tau_gen = sys.k_mppt_ref[] * max(omega_hub, 0.0)^2 * elev_scale
            else
                # Failsafe ground-only feedback
                tau_gen = sys.k_mppt_ref[] * max(omega_gnd, 0.0)^2 * elev_scale
            end
        end
    else
        # Mode 0: Standard MPPT with dynamic max payout
        tau_gen =
            sys.k_mppt_ref[] *
            max(omega_gnd, 0.0)^2 *
            max(0.0, 1.0 - p.backline_payout / max_payout)
    end

    # Apply two-sided Field IMU Active Damping if toggle is active and IMU is reliable
    if imu_reliable && !(ctrl_mode ≈ 1.0)
        power_scale = (p.p_rated_w / 10000.0)^2
        c_d_active = 15.0 * power_scale  # robust damping coefficient
        tau_damp_active = c_d_active * (omega_gnd - omega_hub)
        tau_gen += tau_damp_active
    end

    # Protect the TRPT rope structure from excessive generator electromagnetic torque.
    power_scale = (p.p_rated_w / 10000.0)^2
    tau_max_safe = 2500.0 * power_scale
    tau_gen = clamp(tau_gen, -tau_max_safe, tau_max_safe)

    # Ground-station mechanical brake — only engaged by explicit command
    # (e.g. pitch-depower sequence), not auto-triggered by rotor speed.
    new_brake_engaged = brake_engaged
    if new_brake_engaged
        tau_brake_max = 1500.0 * power_scale
        tau_brake = tau_brake_max * tanh(20.0 * omega_gnd)
        tau_gen = tau_brake
    end

    return tau_gen, new_brake_engaged
end

function compute_ring_forces!(
    forces::Vector{<:AbstractVector},
    torques::AbstractVector,
    u::AbstractVector,
    omega::AbstractVector,
    sys::KiteTurbineSystem,
    p::SystemParams,
    wind_fn::Function,
    t::Float64,
    lift_device::Union{Nothing, LiftDevice}=nothing,
    spoke::Union{Nothing, KiteTurbineDynamics.SpokeParams}=nothing,
)
    N = sys.n_total
    Nr = sys.n_ring
    hub_gid = sys.rotor.node_id
    hub_ri = (sys.nodes[hub_gid]::RingNode).ring_idx
    hub_pos = @view u[(3 * (hub_gid - 1) + 1):(3 * hub_gid)]
    bearing_gid = sys.bearing_id
    bearing_pos = @view u[(3 * (bearing_gid - 1) + 1):(3 * bearing_gid)]
    sky_anchor_gid = sys.sky_anchor_id
    sky_anchor_pos = @view u[(3 * (sky_anchor_gid - 1) + 1):(3 * sky_anchor_gid)]
    alpha = @view u[(6N + 1):(6N + Nr)]

    v_wind = wind_fn(hub_pos, t)

    # ── Shaft elevation angle (needed by spoke restoring force + rotor disc) ──
    # Computed once from live hub position; note: may differ from design elevation.
    elev_angle = atan(hub_pos[3], sqrt(hub_pos[1]^2 + hub_pos[2]^2))

    # ── Rotor disc aerodynamics — CT thrust only ──────────────────────────
    v_hub_mag = norm(v_wind)
    if v_hub_mag > 0.1
        omega_rotor = omega[hub_ri]
        lambda_t = abs(omega_rotor) * sys.rotor.radius / v_hub_mag

        thrust_mag =
            0.5 *
            p.rho *
            v_hub_mag^2 *
            π *
            sys.rotor.radius^2 *
            ct_at_tsr(lambda_t) *
            cos(elev_angle)^2.0   # cos²·⁰ — thrust elevation factor
        tether_dir = hub_pos .- @view(u[1:3])   # ground is node 1
        tl = norm(tether_dir)
        if tl > 0
            ;
            tether_dir ./= tl;
        end
        forces[hub_gid] .+= thrust_mag .* tether_dir

        if omega_rotor >= 0.0
            P_aero =
                0.5 *
                p.rho *
                v_hub_mag^3 *
                π *
                sys.rotor.radius^2 *
                cp_at_tsr(lambda_t) *
                cos(elev_angle)^2.65  # cos²·⁶⁵ — power elevation factor (from AeroDyn sweep)
            tau_aero = P_aero / max(omega_rotor, 0.5)
        else
            CD_reverse = 1.3                           # NACA4412 CD at AoA 40–70°
            chord_blade = 0.113 * sys.rotor.radius      # m — solidity-calibrated
            R_o = sys.rotor.radius
            R_i = 0.4 * R_o                           # inner tip cutout at TRPT hub
            R_eff = 0.70 * R_o                          # 70% representative radius
            span = R_o - R_i                           # blade span
            ω_abs = abs(omega_rotor)
            v_ax = v_hub_mag * cos(elev_angle)         # axial wind through disc
            v_t_eff = ω_abs * R_eff
            v_rel_eff = sqrt(v_ax^2 + v_t_eff^2)
            Q_drag =
                p.n_lines *
                0.5 *
                p.rho *
                CD_reverse *
                chord_blade *
                ω_abs *
                R_eff^2 *
                v_rel_eff *
                span
            tau_aero = Q_drag
        end
        torques[hub_ri] += tau_aero

        # ── Expansion rotor forces (Phase 1) ──────────────────────────────
        # Each expansion rotor is a small 3-blade propeller on a TRPT ring.
        # Blades generate lift from apparent wind, resolved through a bridle
        # angle into radial (spreading) and axial (thrust) components.
        if !isempty(sys.expansion_rotors)
            for er in sys.expansion_rotors
                ring_gid = sys.ring_ids[er.ring_idx]
                ring_pos = @view u[(3 * (ring_gid - 1) + 1):(3 * ring_gid)]
                ring_ri = (sys.nodes[ring_gid]::RingNode).ring_idx

                # ── NaN/Inf guard: skip rotor if ring state is non-finite ──
                if !isfinite(omega[ring_ri]) || !isfinite(alpha[ring_ri])
                    continue
                end

                r_nom = (sys.nodes[ring_gid]::RingNode).radius

                v_wind_ring = wind_fn(ring_pos, t)
                v_wind_mag_ring = norm(v_wind_ring)

                # Tether tension estimate from main rotor thrust
                T_est =
                    0.5 *
                    p.rho *
                    v_hub_mag^2 *
                    π *
                    sys.rotor.radius^2 *
                    ct_at_tsr(lambda_t) *
                    cos(elev_angle)^2.0

                F_radial, F_axial, tau_net, r_eff, _ = expansion_rotor_forces(
                    er,
                    p.rho,
                    v_wind_mag_ring,
                    omega[ring_ri],
                    rad2deg(elev_angle),
                    r_nom,
                    T_est,
                    p.n_lines,
                )

                # Axial thrust along tether direction
                tether_dir_ring = ring_pos .- @view(u[1:3])
                tl_ring = norm(tether_dir_ring)
                if tl_ring > 0
                    tether_dir_ring ./= tl_ring
                end
                forces[ring_gid] .+= F_axial .* tether_dir_ring

                # Net shaft torque from expansion rotor (τ_net = τ_lift - τ_drag).
                # Positive = driving (injects power). Negative = braking (parasitic).
                torques[ring_ri] += tau_net

                # ── Blade inertia (2026-07-18) ──────────────────────────────
                # Gate 2b: rotary inertia of the expansion-rotor blade annulus
                # about the shaft axis.  Gated by EXPANSION_PHYSICS[].blade_inertia;
                # applies only in transient (α≠0), vanishes at steady state.
                if EXPANSION_PHYSICS[].blade_inertia
                    J_rotor = expansion_rotor_inertia(er, r_nom)
                    torques[ring_ri] -= J_rotor * alpha[ring_ri]  # I·α opposes
                end

                # ── Spoke drag torque (2026-07-06) ──────────────────────────
                # Radial spokes from ring vertices to center node experience
                # aerodynamic drag as they rotate. τ = ρ·C_D·d·ω²·R⁴/8 per spoke.
                # Only on rings with expansion rotors (Rod 2026-07-06).
                if spoke !== nothing && spoke.enabled
                    R_spoke = r_nom  # spoke extends from ring radius to center
                    omega_ring = abs(omega[ring_ri])
                    tau_spoke_per = 0.5 * p.rho * spoke.C_D * spoke.d_line *
                                    omega_ring^2 * R_spoke^4 / 4.0
                    tau_spoke_total = p.n_lines * tau_spoke_per
                    torques[ring_ri] -= tau_spoke_total  # braking
                end

                # NOTE: effective_radii update REMOVED (2026-06-14).
                # The old displacement model Δr = F_radial×L/(T×geom) produces
                # absurdly large radii (meters) with realistic blade forces
                # (kN range), corrupting rope attachment geometry.
                # Force-first model applies F_radial as a load term in the
                # structural evaluator; ODE dynamics use nominal ring radii.
                # TODO: investigate expansion rotor utility — at what (speed, torque)
                #   does the ring compression transition from compressive to tensile?
                #   Scaling law TBD. (Rod 2026-07-07)

                # ── F_radial on ring vertices (2026-07-07) ─────────────────
                # Expansion rotor radial force pushes outward on the ring.
                # Radial = perpendicular to shaft axis.
                shaft_dir = [cos(elev_angle), 0.0, sin(elev_angle)]
                r_proj = dot(ring_pos, shaft_dir) .* shaft_dir
                rad_dir = ring_pos .- r_proj
                r_current = norm(rad_dir)
                if r_current > 1e-6
                    rad_dir ./= r_current
                    forces[ring_gid] .+= F_radial .* rad_dir
                end
            end
        end
    end

    # ── Spoke spring restoring force (2026-07-07) ──────────────────────────────
    # Radial Dyneema spokes from each ring vertex to floating center.
    # MUST run every timestep, independent of wind/aero state.
    if spoke !== nothing && spoke.enabled
        shaft_dir = [cos(elev_angle), 0.0, sin(elev_angle)]
        E_dyn = 100e9
        A_spoke = π * spoke.d_line^2 / 4.0
        for i in 1:(length(sys.ring_ids)-1)  # skip ground ring (PTO)
            ring_gid = sys.ring_ids[i]
            ring_gid === nothing && continue
            ring_pos = @view u[(3*(ring_gid-1)+1):(3*ring_gid)]
            r_proj = dot(ring_pos, shaft_dir) .* shaft_dir
            rad_dir = ring_pos .- r_proj
            r_current = norm(rad_dir)
            if r_current > spoke.epsilon
                rad_dir ./= r_current
                k_spoke = p.n_lines * E_dyn * A_spoke / ((sys.nodes[ring_gid]::RingNode).radius)
                F_spoke = k_spoke * r_current
                forces[ring_gid] .-= F_spoke .* rad_dir
            end
        end
    end

    gnd_ri = (sys.nodes[sys.ring_ids[1]]::RingNode).ring_idx   # = 1

    tau_gen, new_brake = get_generator_torque(
        u, sys, p, t, wind_fn; brake_engaged=sys.brake_engaged[]
    )
    if new_brake && !sys.brake_engaged[]
        sys.brake_engaged[] = true
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
    #
    # ── Torsional stiffness k_sec — Tulloch curve (PhD thesis, Strathclyde) ──
    #
    #   τ(δα) = n_lines × T_line × r² × sin(δα) / chord(δα)
    #   where chord(δα) = √(L² + 4r² sin²(δα/2))
    #
    # k_sec = dτ/dδα is NON-MONOTONIC:
    #   δα ≈ 0:       Low stiffness — geometry is soft
    #   Mid δα:        Rising — geometric hardening, helix engages
    #   Near δα*:      Peaks → 0 — approaching τ_cap
    #   At δα*:        0 — τ_cap = T_total × r² / √(L² + 2r²)
    #                   δα* = 2·arcsin(L/√(2(L²+2r²)))
    #   Past δα*:      NEGATIVE — torsional collapse, lines cross
    #
    # k_sec is NOT a good control constraint — it peaks near collapse.
    # The soft_ramp_controller tracks margin_i = δα*_i − |Δα_i| instead.
    # See: src/soft_ramp_controller.jl, scripts/torsional_collapse_check.jl
    Nr = sys.n_ring
    alpha = @view u[(6N + 1):(6N + Nr)]
    L_seg = p.tether_length / (Nr - 1)
    EA_rope = p.e_modulus * π * (p.tether_diameter / 2)^2

    for s in 1:(length(sys.ring_ids) - 1)
        node_a = sys.nodes[sys.ring_ids[s]]::RingNode
        node_b = sys.nodes[sys.ring_ids[s + 1]]::RingNode
        ri_a = node_a.ring_idx
        ri_b = node_b.ring_idx
        r_s = (node_a.radius + node_b.radius) * 0.5
        # Principal-value inter-ring twist (−π, π]: prevents accumulated whole-revolution
        # counts from falsely triggering the collapse guard or inflating k_sec.
        Δα = mod(alpha[ri_b] - alpha[ri_a] + π, 2π) - π
        abs(Δα) >= 0.95π && continue

        # Estimate local torsional stiffness via rope geometry (for damper sizing only)
        chord = sqrt(L_seg^2 + 2 * r_s^2 * (1 - cos(max(abs(Δα), 0.001))))
        T_est = p.n_lines * EA_rope * max(0.0, (chord - L_seg) / L_seg)
        τ_est = T_est * r_s^2 * sin(max(abs(Δα), 0.001)) / chord
        k_sec = max(τ_est / max(abs(Δα), 0.01), 200.0)   # floor at 200 N·m/rad
        I_s = min(node_a.inertia_z, node_b.inertia_z)
        c_s = 2.0 * sqrt(k_sec * I_s)       # ζ = 1.0 on local ring-pair mode
        Δω = omega[ri_b] - omega[ri_a]
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

        # Passive kites stall below ~2 m/s.  Rotary lifter is exempt (fixed ω).
        # StackedLifterParams is exempt too: it already scales as v², so it fades
        # out smoothly on its own rather than needing a stall cliff.
        PASSIVE_KITE_STALL_SPEED = 2.0
        is_passive = !(lift_device isa RotaryLifterParams ||
                       lift_device isa StackedLifterParams)
        _, T_lift, elev_lift_deg = lift_force_steady(lift_device, p.rho, v_hmag, p)
        if is_passive && v_hmag < PASSIVE_KITE_STALL_SPEED
            T_lift = 0.0
        end

        # Force vector: downwind + elevation, then applied along the actual
        # kite–sky-anchor line for geometric stiffness.
        if T_lift > 0.0 && v_hmag > 1e-6
            downwind = [v_lift[1] / v_hmag, v_lift[2] / v_hmag, 0.0]
            θ_lift = deg2rad(elev_lift_deg)
            lift_dir = cos(θ_lift) .* downwind .+ sin(θ_lift) .* [0.0, 0.0, 1.0]

            # ── Geometric stiffness via dynamic kite position ─────────────────
            # sys.kite_pos is updated each simulation step with a first-order lag
            # toward the instantaneous equilibrium (sky_anchor_pos + lift_dir·L_line).
            # This models the kite as "sticky" — it cannot teleport, but gradually
            # follows the sky anchor as the lift line reorients.
            #
            # The lift line tension acts along sky_anchor → kite_pos.
            # If the sky anchor moves toward the kite (payout lets it rise), the
            # line_dist decreases; once line_dist < lift_line_len the line is slack
            # and T_lift is zero.  This is the physically correct tension-only model.
            line_to_kite = sys.kite_pos .- sky_anchor_pos
            line_dist = norm(line_to_kite)

            # Tension only if lift line is taut (line_dist ≥ design length).
            # We use 99% threshold to avoid chattering at the exact design length.
            lift_line_len = T_lift > 0.0 ? lift_device.line_length : 0.0
            if line_dist > 1e-6
                tension_dir = line_to_kite ./ line_dist
            else
                tension_dir = lift_dir
            end
            # Apply lift force to sky anchor only when lift line carries tension
            if line_dist >= lift_line_len * 0.99
                forces[sky_anchor_gid] .+= T_lift .* tension_dir
            end
            # (If line is slack: sky anchor rises freely; kite will catch up via lag update)
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
    back_ax = p.tether_length * cos(p.elevation_angle) + p.back_anchor_fwd_x
    bearing_offset = 6.0
    cyan_L0 = 5.0

    # 2D projection: horizontal plane distance + vertical (anchor at z=0)
    b_dx = sqrt((sky_anchor_pos[1] - back_ax)^2 + sky_anchor_pos[2]^2)
    b_dz = sky_anchor_pos[3]
    b_dist = sqrt(b_dx^2 + b_dz^2)

    # Design rest length: distance ground-anchor → design sky-anchor position.
    # Sky anchor at design = ring_pos[end] + (bearing_offset+cyan_L0)·shaft_dir,
    # which equals (tether_length + bearing_offset + cyan_L0) along the shaft
    # from the origin.
    L_axis_design = p.tether_length + bearing_offset + cyan_L0
    design_sky_anchor_x = L_axis_design * cos(p.elevation_angle)
    design_sky_anchor_z = L_axis_design * sin(p.elevation_angle)
    back_L0_design = sqrt((design_sky_anchor_x - back_ax)^2 + design_sky_anchor_z^2)
    # L₀ = design distance + payout (winch releases line)
    back_L0 = back_L0_design + p.backline_payout

    # Tension-only: slack if anchor-to-sky-anchor distance < rest length
    if b_dist > back_L0 + 1e-6
        # Backline weight (3 mm Dyneema)
        w_back = dyneema_weight_Npm(0.003)

        # Catenary in the vertical plane: anchor at (0,0), sky anchor at (b_dx, b_dz)
        _, _, Fx_top, Fz_top, _ = catenary_forces(
            0.0, 0.0, b_dx, b_dz, back_L0, w_back, p.EA_back_line
        )

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

"""
    apply_brake_constraint!(u, sys, N, Nr)

Post-step velocity constraint for a locked mechanical brake.

When `sys.brake_engaged[]` is true, pins the ground ring (PTO shaft) angular
velocity to exactly zero in the state vector `u`.

**Why this is needed:** The `tanh(20 × ω_gnd)` brake model in `compute_ring_forces!`
has a linearised stiffness of `20 × τ_brake_max / i_pto ≈ 508 000 rad/s²` near zero.
The forward-Euler integrator is only stable up to `2 × i_pto / (coefficient × τ_max)
≈ 4 μs` in that regime — far below the typical dashboard timestep of ~1 ms.  Without
this constraint the integrator amplifies sub-milliradian perturbations into sign-flipping
oscillations that show as swinging `τ_gen` numbers even after the HUD reports LOCKED.

This function must be called after the angular-velocity Euler update and **before** the
angle update, so the PTO angle also stops drifting once the brake is engaged.
"""
function apply_brake_constraint!(
    u::Vector{Float64}, sys::KiteTurbineSystem, N::Int, Nr::Int
)
    if sys.brake_engaged[]
        u[6N + Nr + 1] = 0.0   # ground ring (ring_idx = 1) angular velocity → 0
    end
end
"""

    ring_vertex_positions(u, sys, ring_gid, p, alpha) → Matrix{Float64}

Compute 3×n_lines matrix of vertex positions for a ring, given the ODE state
`u`, system `sys`, ring global id `ring_gid`, params `p`, and twist angles `alpha`.

Each vertex j is at: centre + R * (cos(α + 2πj/n) * perp1 + sin(α + 2πj/n) * perp2)

Uses `shaft_perp_basis` with the shaft direction for the ring-plane basis.
NOTE: `_tilted_ring_basis` (geometry.jl) introduces a visual amplification
(TILT_SCALE=0.1) designed for dashboard rendering — it is NOT suitable for
physics computations.  For vertex-level spoke forces, use the non-amplified
basis derived from the design shaft direction.
"""
function ring_vertex_positions(
    u::AbstractVector,
    sys::KiteTurbineSystem,
    ring_gid::Int,
    p::SystemParams,
    alpha::AbstractVector,
)::Matrix{Float64}
    node = sys.nodes[ring_gid]::RingNode
    R = node.radius
    ring_idx = node.ring_idx
    α = alpha[ring_idx]

    # Use non-amplified basis from design shaft direction (not _tilted_ring_basis
    # which has TILT_SCALE=0.1 visual amplification).
    shaft_dir = [cos(p.elevation_angle), 0.0, sin(p.elevation_angle)]
    perp1, perp2 = shaft_perp_basis(shaft_dir)

    n_lines = p.n_lines
    vertices = Matrix{Float64}(undef, 3, n_lines)
    centre = @view u[(3 * (ring_gid - 1) + 1):(3 * ring_gid)]

    for j in 1:n_lines
        φ = α + 2π * (j - 1) / n_lines
        vertices[:, j] .= centre .+ R .* (cos(φ) .* perp1 .+ sin(φ) .* perp2)
    end

    return vertices
end

"""

    spoke_drift(u, sys, p, alpha, ring_gid) → (drift_outward, drift_inward)

Maximum vertex displacement from design radius for the ring at `ring_gid`.
Positive = outward (vertex further from axis than design), negative = inward.
"""
function spoke_drift(
    u::AbstractVector,
    sys::KiteTurbineSystem,
    p::SystemParams,
    alpha::AbstractVector,
    ring_gid::Int,
)
    node = sys.nodes[ring_gid]::RingNode
    R = node.radius
    vertices = ring_vertex_positions(u, sys, ring_gid, p, alpha)

    shaft_dir = [cos(p.elevation_angle), 0.0, sin(p.elevation_angle)]

    drift_outward = -Inf
    drift_inward = Inf
    for j in 1:size(vertices, 2)
        v = @view vertices[:, j]
        v_proj = dot(v, shaft_dir) .* shaft_dir
        r_actual = norm(v .- v_proj)
        dr = r_actual - R
        drift_outward = max(drift_outward, dr)
        drift_inward = min(drift_inward, dr)
    end

    return drift_outward, drift_inward
end

"""

    constrain_spokes!(u, sys, N, Nr, p)

Post-step position constraint for radial spoke ties.
Projects each flying ring center back onto the shaft axis,
enforcing the hard-constraint limit of the spoke lines.

Why this is needed: The spoke spring (k ≈ 3.9 MN/m) is too stiff
for explicit Euler at DT=4e-5 — rings drift 10mm/step and the spring
corrects one step behind. A hard projection after each step prevents
accumulated drift without requiring an implicit solver.
"""
function constrain_spokes!(
    forces::Vector{Float64}, u::Vector{Float64},
    sys::KiteTurbineSystem, N::Int, Nr::Int, p::SystemParams
)
    shaft = [cos(p.elevation_angle), 0.0, sin(p.elevation_angle)]
    alpha = @view u[6N+1 : 6N+Nr]
    EA_spoke = 100e9 * π * 0.007^2 / 4.0
    for gid in sys.ring_ids[2:end]
        gid === nothing && continue
        node = sys.nodes[gid]::RingNode
        ring_idx = node.ring_idx
        perp1, perp2 = shaft_perp_basis(shaft)
        center = @view u[3*(gid-1)+1 : 3*gid]
        R_design = node.radius
        α_ring = alpha[ring_idx]
        n_lines = p.n_lines
        k_per_spoke = EA_spoke / R_design
        net_force = zeros(3)
        for j in 1:n_lines
            vertex = attachment_point(center, R_design, α_ring, j, n_lines, perp1, perp2)
            axial_proj = dot(vertex, shaft)
            radial_vec = vertex .- axial_proj .* shaft
            r = norm(radial_vec)
            if r > R_design + 1e-6
                radial_unit = radial_vec ./ r
                F = k_per_spoke * (r - R_design)
                net_force .-= F .* radial_unit  # inward restoring force
            end
        end
        forces[(3*(gid-1)+1):(3*gid)] .+= net_force
    end
    return nothing
end

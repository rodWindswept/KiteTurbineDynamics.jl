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

        if omega_rotor >= 0.0
            # ── Forward / standstill: BEM Cp table ────────────────────────────
            # CP(0)=0 by table anchor → tau_aero≈0 at standstill.  This is
            # physically correct for TRPT: the turbine requires kickstarting
            # (consistent with known flat-pitch standstill behaviour).
            # Floor at 0.5 rad/s prevents division blow-up near zero.
            P_aero   = 0.5 * p.rho * v_hub_mag^3 *
                       π * sys.rotor.radius^2 * cp_at_tsr(lambda_t) *
                       cos(elev_angle)^3
            tau_aero = P_aero / max(omega_rotor, 0.5)
        else
            # ── Backward rotation: blade-element drag model ───────────────────
            # BEM Cp tables are invalid for ω < 0.  In reverse, blades operate
            # at AoA 40–70° with CD ≈ 1.3 (deep stall / bluff body).  The
            # resulting drag torque is large (~2000 N·m at ω=−2 rad/s) and
            # physically arrests the reversal.
            #
            # Omitting this was the root cause of the red-ring artefact in the
            # pitch-depower scenario: the TRPT torsional restoring force drove
            # backward twist accumulation unopposed (BEM gave near-zero torque)
            # → growing ring compression → false structural alarm.
            #
            # Per-blade drag torque integral over span [R_i, R_o]:
            #   dT = 0.5·ρ·CD·c · |ω|·r² · sqrt(v_ax²+(|ω|·r)²) · dr
            # Approximated via 70%-span representative radius (propeller BEM
            # convention; accurate to ±15% vs. full numerical integration):
            #   T ≈ n_blades · 0.5·ρ·CD·c · |ω|·R_eff² · v_rel_eff · span
            #
            # Chord from BEM solidity: σ≈0.18 at λ_opt=4.1 for NACA4412
            #   c = σ·π·R / n_blades ≈ 0.113·R  (≈ 0.60 m at R=5 m)
            CD_reverse  = 1.3                           # NACA4412 CD at AoA 40–70°
            chord_blade = 0.113 * sys.rotor.radius      # m — solidity-calibrated
            R_o   = sys.rotor.radius
            R_i   = 0.4 * R_o                           # inner tip cutout at TRPT hub
            R_eff = 0.70 * R_o                          # 70% representative radius
            span  = R_o - R_i                           # blade span
            ω_abs = abs(omega_rotor)
            v_ax  = v_hub_mag * cos(elev_angle)         # axial wind through disc
            v_t_eff   = ω_abs * R_eff
            v_rel_eff = sqrt(v_ax^2 + v_t_eff^2)
            Q_drag   = p.n_lines * 0.5 * p.rho * CD_reverse * chord_blade *
                       ω_abs * R_eff^2 * v_rel_eff * span
            # Restoring: opposes backward spin → positive torque (drives ω toward 0⁺)
            tau_aero = Q_drag
        end
        torques[hub_ri] += tau_aero
    end

    # ── Generator MPPT torque on ground node ──────────────────────────────
    gnd_ri    = (sys.nodes[sys.ring_ids[1]]::RingNode).ring_idx   # = 1
    omega_gnd = omega[gnd_ri]
    omega_hub = omega[hub_ri]
    
    # Winch payout base and geometric scaling for system size
    payout_base = p.β_min < 5.0 ? 15.0 : p.β_min
    geom_scale  = p.tether_length / 30.0
    max_payout  = payout_base * geom_scale

    ctrl_mode = round(p.β_rate_max)
    
    # Check flying IMU telemetry health/availability
    imu_reliable = p.kp_elev ≈ 1.0
    
    if ctrl_mode ≈ 1.0 || ctrl_mode ≈ 2.0
        # Physical shaft elevation angle β_actual
        β_actual = atan(hub_pos[3], sqrt(hub_pos[1]^2 + hub_pos[2]^2))
        β_design = p.elevation_angle
        β_furl   = deg2rad(60.0)
        elev_scale = 1.0 - 0.8 * clamp((β_actual - β_design) / (β_furl - β_design), 0.0, 1.0)
        
        if ctrl_mode ≈ 1.0
            # Mode 1: Active Torsional Damping
            if imu_reliable
                # High-fidelity IMU Mode: Torsional Active Damping
                tau_mppt = p.k_mppt * max(omega_hub, 0.0)^2
                power_scale = (p.p_rated_w / 10000.0)^2
                c_d = 10.0 * power_scale
                tau_damp = c_d * (omega_gnd - omega_hub)
                tau_gen = (tau_mppt + tau_damp) * elev_scale
            else
                # Failsafe ground-only feedback: fall back to ground encoder speed (omega_gnd)
                tau_gen = p.k_mppt * max(omega_gnd, 0.0)^2 * elev_scale
            end
        else
            # Mode 2: LPF Speed MPPT (smooth hub speed)
            if imu_reliable
                tau_gen = p.k_mppt * max(omega_hub, 0.0)^2 * elev_scale
            else
                # Failsafe ground-only feedback
                tau_gen = p.k_mppt * max(omega_gnd, 0.0)^2 * elev_scale
            end
        end
    else
        # Mode 0: Standard MPPT with dynamic max payout
        tau_gen = p.k_mppt * max(omega_gnd, 0.0)^2 * max(0.0, 1.0 - p.backline_payout / max_payout)
    end

    # Apply two-sided Field IMU Active Damping if toggle is active and IMU is reliable
    if imu_reliable && !(ctrl_mode ≈ 1.0)
        power_scale = (p.p_rated_w / 10000.0)^2
        c_d_active = 15.0 * power_scale  # robust damping coefficient
        tau_damp_active = c_d_active * (omega_gnd - omega_hub)
        tau_gen += tau_damp_active
    end

    # Protect the TRPT rope structure from excessive generator electromagnetic torque
    power_scale = (p.p_rated_w / 10000.0)^2
    tau_max_safe = 2500.0 * power_scale
    tau_gen = clamp(tau_gen, -tau_max_safe, tau_max_safe)

    # Ground-station mechanical brake — triggered by the flying turbine rotor speed only.
    # Rationale: the rotor must reach < 1 rad/s before the brake engages so that
    # torsional energy stored in the TRPT is already low.  Triggering on omega_gnd
    # alone could fire the brake while the rotor is still fast (e.g. if the TRPT
    # is twisted), applying a torsional shock to the rope stack.
    if p.kp_elev ≈ 1.0
        if sys.brake_engaged[] || abs(omega_hub) < 1.0
            sys.brake_engaged[] = true
            tau_brake_max = 1500.0 * power_scale
            # tanh gives smooth onset and bidirectional hold:
            #   omega_gnd > 0  →  decelerates the PTO
            #   omega_gnd ≈ 0  →  near-zero torque, PTO already stopped
            #   omega_gnd < 0  →  opposes any reverse creep from TRPT unwind
            tau_brake = tau_brake_max * tanh(20.0 * omega_gnd)

            # Decouple generator: mechanical brake does 100% of the holding,
            # preventing any residual MPPT torque from fighting the brake.
            tau_gen = tau_brake
        end
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

        # Force vector: downwind + elevation, then applied along the actual
        # kite–sky-anchor line for geometric stiffness.
        if T_lift > 0.0 && v_hmag > 1e-6
            downwind = [v_lift[1] / v_hmag, v_lift[2] / v_hmag, 0.0]
            θ_lift   = deg2rad(elev_lift_deg)
            lift_dir = cos(θ_lift) .* downwind .+ sin(θ_lift) .* [0.0, 0.0, 1.0]

            # ── Geometric stiffness — tension along actual kite direction ──────
            # Previous model applied T_lift in the fixed design direction (lift_dir),
            # independent of sky_anchor_pos.  A constant force does zero net work
            # around a cycle but gives NO position-dependent restoring force, so
            # the sky anchor is an undamped free mass after any perturbation.
            #
            # Root cause of post-brake shaking: TRPT unwind sends an impulse up
            # through the cyan line to the sky anchor.  With no geometric spring
            # from the kite side, the sky anchor rings indefinitely and the
            # motion re-excites the bearing and TRPT geometry — mimicking renewed
            # torsional resonance even though the TRPT has fully straightened.
            #
            # Fix: treat the kite as quasi-statically fixed in space relative to
            # the bearing (valid for sky-anchor oscillation timescales << kite
            # response time).  Tension then acts along sky_anchor → kite_pos,
            # which changes direction as sky_anchor moves → restoring spring
            #   k_geo = T_lift / L_line  ≈  80 N/m
            #
            # Kite equilibrium position:
            #   sky_anchor_eq ≈ bearing_pos + CYAN_L0 × shaft_dir  (bearing is stable)
            #   kite_pos      = sky_anchor_eq + L_line × lift_dir_eq
            hmag_hub      = norm(hub_pos)
            shaft_dir_c   = hmag_hub > 0.1 ? hub_pos ./ hmag_hub :
                                [cos(p.elevation_angle), 0.0, sin(p.elevation_angle)]
            CYAN_L0_GEO   = 5.0                      # must match initialization.jl
            sky_anchor_eq = bearing_pos .+ CYAN_L0_GEO .* shaft_dir_c
            kite_pos      = sky_anchor_eq .+ lift_line_length(lift_device) .* lift_dir
            line_to_kite  = kite_pos .- sky_anchor_pos
            line_dist     = norm(line_to_kite)
            tension_dir   = line_dist > 1.0 ? line_to_kite ./ line_dist : lift_dir
            forces[sky_anchor_gid] .+= T_lift .* tension_dir
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
function apply_brake_constraint!(u::Vector{Float64},
                                  sys::KiteTurbineSystem,
                                  N::Int, Nr::Int)
    if sys.brake_engaged[]
        u[6N + Nr + 1] = 0.0   # ground ring (ring_idx = 1) angular velocity → 0
    end
end

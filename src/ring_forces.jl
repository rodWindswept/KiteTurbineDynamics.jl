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

    # ── Kite lift + drag ───────────────────────────────────────────────────
    if v_mag > 0.1
        q        = 0.5 * p.rho * v_mag^2
        drag_dir = v_app ./ v_mag
        ẑ        = [0.0, 0.0, 1.0]
        ẑ_perp   = ẑ .- dot(ẑ, drag_dir) .* drag_dir
        n_zp     = norm(ẑ_perp)
        lift_dir = n_zp > 1e-6 ? ẑ_perp ./ n_zp : ẑ
        forces[hub_gid] .+= q * sys.kite.area * sys.kite.CL .* lift_dir
        forces[hub_gid] .+= q * sys.kite.area * sys.kite.CD .* drag_dir
    end

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

    # ── Lift kite / rotary lifter force at hub node ───────────────────────────
    # Quasi-static Phase 2 model: compute steady-state lift line tension at the
    # current hub wind speed and apply the resulting 3D force to the hub node.
    # The lift device flies upwind of and above the hub, so the force on the hub
    # points into the wind (horizontal) and upward (vertical).
    #
    # Wind direction is taken from the hub wind vector; horizontal component only
    # drives the kite (vertical wind is small compared to horizontal at these
    # scales and is ignored for the lift device model).
    if lift_device !== nothing
        v_lift = wind_fn(hub_pos, t)           # 3D wind at hub altitude
        v_h1   = v_lift[1];  v_h2 = v_lift[2] # horizontal components
        v_hmag = sqrt(v_h1^2 + v_h2^2)        # horizontal wind speed
        if v_hmag > 0.1
            into_wind = [-v_h1 / v_hmag, -v_h2 / v_hmag, 0.0]  # unit vec upwind
        else
            into_wind = [-1.0, 0.0, 0.0]
        end
        # Scalar tension and elevation from the lift device model
        _, T_lift, elev_lift = lift_force_steady(lift_device, p.rho, v_hmag)
        θ_lift = deg2rad(elev_lift)
        # 3D force: horizontal component into wind + vertical component upward
        forces[hub_gid] .+= T_lift .* (cos(θ_lift) .* into_wind .+
                                        sin(θ_lift) .* [0.0, 0.0, 1.0])
    end
end

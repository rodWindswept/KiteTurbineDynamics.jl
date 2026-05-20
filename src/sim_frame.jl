# src/sim_frame.jl
# Frame-snapshot data layer — computed observables from raw ODE state vectors.
# Consumers (dashboard, CSV export, reports, live monitoring) read SimFrame
# instead of extracting metrics from raw u vectors.
#
# This gives Locality: tension/FoS/sag computation lives here, not duplicated
# across consumers.  And Leverage: adding a new metric (e.g. tether drag power)
# adds it to SimFrame once and every consumer picks it up.

using LinearAlgebra

# ══════════════════════════════════════════════════════════════════════════════
# SimFrame — one snapshot of computed observables at a single timestep.
# ══════════════════════════════════════════════════════════════════════════════

"""
    SimFrame

Snapshot of all dashboard-relevant metrics at one ODE timestep.
Produced by `capture_frame()`; consumed by the dashboard, CSV export,
and report generation.

All fields are concrete (no references to `sys`, `p`, or `u` needed to
interpret them) so a `SimFrame` is self-contained and serialisable.
"""
struct SimFrame
    t                :: Float64      # simulation time (s)

    # ── Hub (rotor) state ─────────────────────────────────────────────────
    omega_hub        :: Float64      # hub angular velocity (rad/s)
    omega_gnd         :: Float64      # PTO (ground ring) angular velocity (rad/s)
    P_kw              :: Float64      # electrical output power (kW)
    pct_rated         :: Float64      # % of rated power
    hub_x             :: Float64      # hub centre position (m)
    hub_y             :: Float64
    hub_z             :: Float64
    hub_z_delta       :: Float64      # altitude change from run-start reference (m)
    V_hub             :: Float64      # wind speed at hub altitude (m/s)
    tsr               :: Float64      # tip-speed ratio λ = ω_hub·R / V_hub

    # ── Torsional state ───────────────────────────────────────────────────
    delta_alpha_deg   :: Float64      # total TRPT twist (degrees), principal-value sum
    delta_omega       :: Float64      # hub − PTO angular velocity difference (rad/s)
    tau_aero          :: Float64      # aerodynamic driving torque (N·m)
    tau_gen           :: Float64      # generator MPPT braking torque (N·m)

    # ── Structural ────────────────────────────────────────────────────────
    T_max             :: Float64      # max tether tension across all lines (N)
    fos_tether        :: Float64      # FoS = SWL / T_max  (∞ if T_max=0)
    ring_max_util     :: Float64      # max ring utilisation (0–1, fraction of P_crit)
    fos_ring          :: Float64      # ring buckling FoS = 1 / max_util
    n_slack           :: Int          # number of tether lines with T < 5 N
    max_sag_mm        :: Float64      # max rope sag below straight chord (mm)
    sag_seg           :: Int          # segment index of max sag (1-based)

    # ── Per-ring utilisation (for ring-colour rendering) ──────────────────
    ring_utils        :: Vector{Float64}           # worst-beam util per ring (HUD/peaks/warnings)
    ring_beam_utils   :: Vector{Vector{Float64}}   # [ring_idx][beam_idx] — for per-beam 3D colour

    # ── Lift device ───────────────────────────────────────────────────────
    T_lift            :: Float64      # lift line tension at hub (N; 0 if no device)
    lift_elev_deg     :: Float64      # lift line elevation angle (degrees)
    lift_margin       :: Float64      # T_lift / lift_required (>1 = sufficient lift)
    lift_type         :: Symbol       # :none, :single, :stacked, :rotary

    # ── Warning flags ─────────────────────────────────────────────────────
    torsional_overtwist :: Bool       # |Δα| > 270°
    buckling_risk       :: Bool       # ring_max_util > 0.8
    line_slack          :: Bool       # n_slack > 0
end

# ══════════════════════════════════════════════════════════════════════════════
# SimPeaks — run-wide maxima / aggregates.
# ══════════════════════════════════════════════════════════════════════════════

"""
    SimPeaks

Run-wide peak values and aggregate statistics across a sequence of SimFrames.
Produced by `capture_peaks()`.
"""
struct SimPeaks
    T_peak          :: Float64   # max tether tension (N)
    omega_peak      :: Float64   # max hub angular velocity (rad/s)
    P_peak          :: Float64   # max electrical power (kW)
    V_peak          :: Float64   # max wind speed at hub (m/s)
    slack_events    :: Int       # number of frames with any slack line
    n_frames        :: Int       # total frame count
end

# ══════════════════════════════════════════════════════════════════════════════
# capture_frame — extract one SimFrame from raw ODE state.
# ══════════════════════════════════════════════════════════════════════════════

"""
    capture_frame(u, sys, p, t, wind_fn, lift_device=nothing; hub_z0=nothing)
        → SimFrame

Extract all dashboard-relevant metrics from one ODE state vector `u`.

`hub_z0` optionally provides the reference hub altitude from frame 1;
if `nothing`, the current hub_z is used as its own reference (Δz = 0).
"""
function capture_frame(u           :: AbstractVector,
                        sys         :: KiteTurbineSystem,
                        p           :: SystemParams,
                        t           :: Float64,
                        wind_fn     :: Function,
                        lift_device :: Union{Nothing, LiftDevice} = nothing;
                        hub_z0      :: Union{Nothing, Float64}    = nothing)
    N  = sys.n_total
    Nr = sys.n_ring

    # ── State extraction ──────────────────────────────────────────────────
    omega_hub = u[6N + Nr + Nr]
    omega_gnd = u[6N + Nr + 1]
    P_kw      = p.k_mppt * omega_gnd^2 * abs(omega_gnd) / 1000.0
    pct_rated = p.p_rated_w > 0 ? P_kw * 1000.0 / p.p_rated_w * 100.0 : 0.0

    hub_gid   = sys.rotor.node_id
    hub_ctr   = u[3*(hub_gid-1)+1 : 3*hub_gid]
    hub_x, hub_y, hub_z = hub_ctr[1], hub_ctr[2], hub_ctr[3]
    z_hub     = max(hub_z, 1.0)

    # Hub altitude reference — default to current if none provided
    z0        = hub_z0 === nothing ? hub_z : hub_z0
    hub_z_delta = hub_z - z0

    # Wind at hub
    v_vec_hub = wind_fn(hub_ctr, t)
    V_hub     = max(sqrt(v_vec_hub[1]^2 + v_vec_hub[2]^2), 0.1)

    # TSR
    tsr = V_hub > 0.1 ? abs(omega_hub) * sys.rotor.radius / V_hub : 0.0

    # ── Torsional state ───────────────────────────────────────────────────
    alpha_vec = @view u[6N+1 : 6N+Nr]
    Δα_deg = rad2deg(sum(i -> mod(alpha_vec[i+1] - alpha_vec[i] + π, 2π) - π, 1:Nr-1))

    Δω = omega_hub - omega_gnd

    # Torque balance (matches ring_forces.jl physics)
    lambda_t = abs(omega_hub) * sys.rotor.radius / max(V_hub, 0.1)
    P_aero   = 0.5 * p.rho * V_hub^3 * π * sys.rotor.radius^2 *
               cp_at_tsr(lambda_t) * cos(p.elevation_angle)^3
    tau_aero = P_aero / max(abs(omega_hub), 0.5)
    tau_gen  = p.k_mppt * omega_gnd^2

    # ── Structural ────────────────────────────────────────────────────────
    # Per-segment tether tension (ring-attachment geometry, not rope-node positions)
    β_s       = p.elevation_angle
    shaft_dir = [cos(β_s), 0.0, sin(β_s)]
    perp1, perp2 = shaft_perp_basis(shaft_dir)
    n_seg     = p.n_rings + 1
    ea_rope   = sys.sub_segs[1].EA

    T_max   = 0.0
    n_slack = 0
    for s in 1:n_seg, j in 1:p.n_lines
        seg_nat_len = 4 * sys.sub_segs[(s-1)*p.n_lines*4 + 1].length_0
        gid_a = sys.ring_ids[s];      gid_b = sys.ring_ids[s+1]
        na    = sys.nodes[gid_a]::RingNode
        nb    = sys.nodes[gid_b]::RingNode
        ctr_a = u[3*(gid_a-1)+1 : 3*gid_a]
        ctr_b = u[3*(gid_b-1)+1 : 3*gid_b]
        α_a   = u[6N + na.ring_idx]
        α_b   = u[6N + nb.ring_idx]
        pa    = attachment_point(ctr_a, na.radius, α_a, j, p.n_lines, perp1, perp2)
        pb    = attachment_point(ctr_b, nb.radius, α_b, j, p.n_lines, perp1, perp2)
        T     = max(0.0, ea_rope * (norm(pb .- pa) - seg_nat_len) / seg_nat_len)
        T_max = max(T_max, T)
        T < 5.0 && (n_slack += 1)
    end
    fos_tether = T_max > 0.0 ? TETHER_SWL / T_max : Inf

    # Ring buckling safety
    rea_results     = ring_element_analysis(u, collect(alpha_vec), sys, p)
    ring_beam_utils = [[b.utilisation for b in ref.beams] for ref in rea_results]
    ring_utils      = [ref.max_util for ref in rea_results]
    max_util        = isempty(ring_utils) ? 0.0 : maximum(ring_utils)
    fos_ring        = max_util > 0.0 ? 1.0 / max_util : Inf

    # Rope sag
    max_sag_mm  = 0.0
    sag_seg     = 1
    for s in 1:n_seg
        gid_a2 = sys.ring_ids[s];   gid_b2 = sys.ring_ids[s+1]
        na2 = sys.nodes[gid_a2]::RingNode; nb2 = sys.nodes[gid_b2]::RingNode
        ctr_a2 = u[3*(gid_a2-1)+1:3*gid_a2]
        ctr_b2 = u[3*(gid_b2-1)+1:3*gid_b2]
        pa_sag = attachment_point(ctr_a2, na2.radius, u[6N+na2.ring_idx],
                                   1, p.n_lines, perp1, perp2)
        pb_sag = attachment_point(ctr_b2, nb2.radius, u[6N+nb2.ring_idx],
                                   1, p.n_lines, perp1, perp2)
        stride_s = 1 + p.n_lines * 3
        gid_mid  = (s-1)*stride_s + 3  # second rope node on line 1
        pm  = u[3*(gid_mid-1)+1:3*gid_mid]
        AB  = pb_sag .- pa_sag; len2 = dot(AB, AB)
        if len2 > 1e-18
            foot  = pa_sag .+ (dot(pm .- pa_sag, AB) / len2) .* AB
            sag   = norm(pm .- foot) * 1000.0
            if sag > max_sag_mm; max_sag_mm = sag; sag_seg = s; end
        end
    end

    # ── Lift device ───────────────────────────────────────────────────────
    T_lift_val    = 0.0
    elev_lift_val = 0.0
    lift_margin_v = 0.0
    lift_type_sym = :none
    if lift_device !== nothing
        _, T_lift_val, elev_lift_val = lift_force_steady(lift_device, p.rho, V_hub)
        if lift_device isa RotaryLifterParams
            lift_type_sym = :rotary
            lift_req, _   = autogyro_lift_required(p)
            lift_margin_v = T_lift_val / max(lift_req, 1.0)
        elseif lift_device isa SingleKiteParams
            lift_type_sym = :single
        elseif lift_device isa StackedKitesParams
            lift_type_sym = :stacked
        end
    end

    # ── Warnings ──────────────────────────────────────────────────────────
    torsional_overtwist = abs(Δα_deg) > 270.0
    buckling_risk       = max_util > 0.8
    line_slack_flag     = n_slack > 0

    return SimFrame(
        t, omega_hub, omega_gnd, P_kw, pct_rated,
        hub_x, hub_y, hub_z, hub_z_delta, V_hub, tsr,
        Δα_deg, Δω, tau_aero, tau_gen,
        T_max, fos_tether, max_util, fos_ring, n_slack, max_sag_mm, sag_seg,
        ring_utils, ring_beam_utils,
        T_lift_val, elev_lift_val, lift_margin_v, lift_type_sym,
        torsional_overtwist, buckling_risk, line_slack_flag,
    )
end

# ══════════════════════════════════════════════════════════════════════════════
# capture_peaks — run-wide aggregates across a sequence of SimFrames.
# ══════════════════════════════════════════════════════════════════════════════

"""
    capture_peaks(frames::Vector{SimFrame}) → SimPeaks

Compute run-wide peak values from a sequence of SimFrames.
"""
function capture_peaks(frames::Vector{SimFrame})
    T_peak       = 0.0
    omega_peak   = 0.0
    P_peak       = 0.0
    V_peak       = 0.0
    slack_events = 0

    for sf in frames
        T_peak     = max(T_peak, sf.T_max)
        omega_peak = max(omega_peak, abs(sf.omega_hub))
        P_peak     = max(P_peak, sf.P_kw)
        V_peak     = max(V_peak, sf.V_hub)
        sf.line_slack && (slack_events += 1)
    end

    return SimPeaks(T_peak, omega_peak, P_peak, V_peak, slack_events, length(frames))
end

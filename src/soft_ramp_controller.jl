# src/soft_ramp_controller.jl
#
# Soft-ramp k_mppt controller for TRPT dynamic operation.
#
# Physical basis:
# ───────────────
# The TRPT is a distributed torsional spring-damper chain.  Torsional stiffness
# k_sec = dτ/dδα is NON-MONOTONIC (Tulloch, PhD thesis TU Delft):
#
#   τ(δα) = n_lines × T_line × r² × sin(δα) / chord(δα)
#   where chord(δα) = √(L² + 4r² sin²(δα/2))
#
#   Region          dτ/dδα    Physics
#   ─────────────── ────────   ──────────────────────────────────────
#   δα ≈ 0          Low        sin(δα) ≈ δα — geometry is soft
#   Mid δα           Rising     Geometric hardening — helix engages
#   Near δα*         Peaks→0    Approaching max torque capacity
#   At δα*           0          τ_cap = T_total × r² / √(L² + 2r²)
#                               δα* = 2·arcsin(L/√(2(L² + 2r²)))
#   Past δα*         Negative   TORSIONAL COLLAPSE — lines cross,
#                               wind toward axis, torque transmission fails
#
# Controller implications:
# - k_sec peaks near collapse — tracking k_sec is misleading
# - Track margin_i = δα*_i − |Δα_i| instead — monotonic distance to cliff
# - Segment with smallest margin is limiting
# - Freeze ramp if any margin < collapse_margin_deg (default 5°)
#
# Ring buckling (Euler column):
# - Hard constraint: FoS ≥ 1.5 (design policy, DECISIONS.md 2026-03-20)
# - Soft intervention at FoS = 2.5: linear taper of ramp rate to zero at 1.5
# - Prevents control discontinuity that would excite TRPT torsional modes

@enum RampState IDLE RAMPING HOLDING

"""
    RampController

Mutable state machine that ramps `sys.k_mppt_ref[]` toward the value that
produces `P_target` at the generator, respecting structural constraints.

Structural constraints (Phase C):
- `fos_soft`: FoS below which ramp rate is linearly tapered (default 2.5)
- `fos_hard`: FoS at which ramp rate reaches zero (default 1.5)
- `collapse_margin_deg`: if any segment's margin to δα* drops below this,
  the ramp is frozen regardless of FoS (default 5°)

Geometry (initialised via `init_geometry!`):
- `_δα_star`: per-segment optimal twist angle (radians), δα* from Tulloch
- `_n_seg`: number of inter-ring segments

Fields:
- `state`: current state (IDLE, RAMPING, HOLDING)
- `k_min`, `k_max`: clamp bounds for k_mppt
- `Kp`: proportional gain for ramp rate (Δk per second per W of power deficit)
- `P_target`: target generator power (W)
- `ω_idle`: hub speed threshold for IDLE → RAMPING transition (rad/s)
- `idle_hold`: seconds ω must stay above ω_idle before transitioning
- `hold_pct`: power must stay within ±hold_pct of target for `hold_secs`
              before transitioning RAMPING → HOLDING
- `lull_pct`: if power drops below (1−lull_pct)×P_target for `lull_secs`,
              transition HOLDING → RAMPING

Internal counters (not set by user):
- `_idle_ctr`, `_hold_ctr`, `_lull_ctr`: frame counters for state transitions
"""
mutable struct RampController
    state::RampState
    k_min::Float64
    k_max::Float64
    Kp::Float64
    P_target::Float64
    ω_idle::Float64
    idle_hold::Float64
    hold_pct::Float64
    hold_secs::Float64
    lull_pct::Float64
    lull_secs::Float64

    # Structural constraints (Phase C)
    fos_soft::Float64             # FoS where ramp taper begins (default 2.5)
    fos_hard::Float64             # FoS where ramp reaches zero (default 1.5)
    collapse_margin_deg::Float64  # min margin to Tulloch cliff (default 5°)

    # Pre-computed per-segment Tulloch δα* (initialised by init_geometry!)
    _δα_star::Vector{Float64}
    _n_seg::Int

    # Internal counters
    _idle_ctr::Int
    _hold_ctr::Int
    _lull_ctr::Int
end

"""
    RampController(; k_min, k_max, Kp, P_target, ...)

Construct a RampController with sensible defaults for a 50 kW system.
Call `init_geometry!(ctrl, sys, p)` before first use to compute per-segment δα*.
"""
function RampController(;
    k_min::Float64 = 20.0,
    k_max::Float64 = 200.0,
    Kp::Float64 = 1e-4,          # Δk per second per watt of deficit
    P_target::Float64 = 50000.0,  # 50 kW rated
    ω_idle::Float64 = 0.5,        # ~5 rpm in rad/s
    idle_hold::Float64 = 3.0,     # 3 seconds above ω_idle
    hold_pct::Float64 = 0.05,     # ±5% of P_target
    hold_secs::Float64 = 3.0,     # 3 seconds stable
    lull_pct::Float64 = 0.20,     # 20% power drop
    lull_secs::Float64 = 5.0,     # 5 seconds sustained
    fos_soft::Float64 = 2.5,
    fos_hard::Float64 = 1.5,
    collapse_margin_deg::Float64 = 5.0,
)
    return RampController(
        IDLE, k_min, k_max, Kp, P_target, ω_idle,
        idle_hold, hold_pct, hold_secs, lull_pct, lull_secs,
        fos_soft, fos_hard, collapse_margin_deg,
        Float64[], 0,    # _δα_star, _n_seg — filled by init_geometry!
        0, 0, 0,
    )
end

"""
    init_geometry!(ctrl, sys, p)

Compute per-segment Tulloch optimal twist angle δα* from ring geometry.
Must be called once before `update_ramp!` is used with collapse-margin checks.

Uses the ring radii from sys.nodes and an approximate average segment length
from p.tether_length / (Nr − 1).  The δα* threshold is a geometric limit —
using nominal (unstretched) geometry is conservative.
"""
function init_geometry!(ctrl::RampController, sys::KiteTurbineSystem, p::SystemParams)
    Nr = sys.n_ring
    n_seg = Nr - 1
    ctrl._n_seg = n_seg
    ctrl._δα_star = Vector{Float64}(undef, n_seg)

    L_avg = p.tether_length / n_seg   # approximate — uniform spacing is close enough

    for s in 1:n_seg
        node_a = sys.nodes[sys.ring_ids[s]]::RingNode
        node_b = sys.nodes[sys.ring_ids[s + 1]]::RingNode
        r_min = min(node_a.radius, node_b.radius)   # conservative: smaller ring limits

        # Tulloch δα* = 2·arcsin(L / √(2(L² + 2r²)))
        arg = clamp(L_avg / sqrt(2 * (L_avg^2 + 2 * r_min^2)), 0.0, 1.0)
        ctrl._δα_star[s] = 2 * asin(arg)
    end
end

"""
    min_collapse_margin(u, sys, ctrl) → Float64

Compute the minimum margin to torsional collapse across all inter-ring segments.
Returns the smallest (δα*_i − |Δα_i|) in degrees.

Extracts twist angles α from the state vector `u`, computes per-segment
principal-value twist Δα, and compares against pre-computed δα*.
"""
function min_collapse_margin(
    u::AbstractVector,
    sys::KiteTurbineSystem,
    ctrl::RampController,
)
    N = sys.n_total
    Nr = sys.n_ring
    alpha = @view u[(6N + 1):(6N + Nr)]

    min_margin_rad = Inf
    for s in 1:ctrl._n_seg
        ri_a = (sys.nodes[sys.ring_ids[s]]::RingNode).ring_idx
        ri_b = (sys.nodes[sys.ring_ids[s + 1]]::RingNode).ring_idx
        # Principal-value inter-ring twist (−π, π]
        Δα = mod(alpha[ri_b] - alpha[ri_a] + π, 2π) - π
        margin = ctrl._δα_star[s] - abs(Δα)
        if margin < min_margin_rad
            min_margin_rad = margin
        end
    end
    return rad2deg(min_margin_rad)
end

"""
    update_ramp!(ctrl, sys, sf, dt; min_fos, collapse_margin_deg)

State machine update — call once per captured simulation frame (~50 Hz).

Reads generator power and hub speed from `sf` (SimFrame).
Applies FoS taper (Phase C) and Tulloch collapse margin guard (Phase C).
Writes to `sys.k_mppt_ref[]` if state requires a change.

Keyword arguments (required for Phase C structural constraints):
- `min_fos`: minimum ring buckling FoS across all rings (from sf.fos_ring)
- `collapse_margin_deg`: minimum margin to Tulloch δα* across all segments

Returns the new (or unchanged) RampState.
"""
function update_ramp!(
    ctrl::RampController,
    sys::KiteTurbineSystem,
    sf::SimFrame,
    dt::Float64;
    min_fos::Float64 = Inf,
    collapse_margin_deg::Float64 = Inf,
)
    P_actual = sf.P_kw * 1000.0    # kW → W
    ω_hub = abs(sf.omega_hub)
    k_current = sys.k_mppt_ref[]

    # ── Phase C: compute ramp-rate multiplier from structural constraints ──
    # FoS taper: linear from fos_soft (full rate) to fos_hard (zero rate)
    fos_mult = clamp((min_fos - ctrl.fos_hard) / (ctrl.fos_soft - ctrl.fos_hard), 0.0, 1.0)

    # Tulloch collapse margin: hard freeze if below threshold
    collapse_mult = collapse_margin_deg >= ctrl.collapse_margin_deg ? 1.0 : 0.0

    # Combined structural multiplier: most restrictive wins
    struct_mult = min(fos_mult, collapse_mult)

    if ctrl.state == IDLE
        # Wait for rotor to spin up above ω_idle for idle_hold seconds
        if ω_hub >= ctrl.ω_idle
            ctrl._idle_ctr += 1
        else
            ctrl._idle_ctr = 0
        end
        if ctrl._idle_ctr * dt >= ctrl.idle_hold
            ctrl.state = RAMPING
            ctrl._idle_ctr = 0
        end

    elseif ctrl.state == RAMPING
        # Proportional ramp: Δk = Kp × (P_target − P_actual) × dt
        # Tapered by structural multiplier
        error_W = ctrl.P_target - P_actual
        delta_k = ctrl.Kp * error_W * dt * struct_mult
        new_k = clamp(k_current + delta_k, ctrl.k_min, ctrl.k_max)
        sys.k_mppt_ref[] = new_k

        # Check for HOLDING condition: power within ±hold_pct of target
        # AND structural constraints satisfied
        if abs(P_actual - ctrl.P_target) / ctrl.P_target <= ctrl.hold_pct
            ctrl._hold_ctr += 1
        else
            ctrl._hold_ctr = 0
        end
        if ctrl._hold_ctr * dt >= ctrl.hold_secs && struct_mult >= 0.99
            ctrl.state = HOLDING
            ctrl._hold_ctr = 0
        end

    elseif ctrl.state == HOLDING
        # Hold k_mppt steady.  Monitor for sustained power drop.
        if P_actual < ctrl.P_target * (1.0 - ctrl.lull_pct)
            ctrl._lull_ctr += 1
        else
            ctrl._lull_ctr = 0
        end
        if ctrl._lull_ctr * dt >= ctrl.lull_secs
            ctrl.state = RAMPING
            ctrl._lull_ctr = 0
        end
    end

    return ctrl.state
end

"""
    reset!(ctrl)

Reset controller to IDLE state, clearing all internal counters.
Call when a new simulation run starts.
"""
function reset!(ctrl::RampController)
    ctrl.state = IDLE
    ctrl._idle_ctr = 0
    ctrl._hold_ctr = 0
    ctrl._lull_ctr = 0
end

"""
    state_label(ctrl)

Return a human-readable string for the current state, including
structural constraint status where relevant.
"""
function state_label(ctrl::RampController)
    if ctrl.state == IDLE
        return "IDLE (ω < $(round(ctrl.ω_idle*60/(2π); digits=1)) rpm)"
    elseif ctrl.state == RAMPING
        return "RAMPING → $(round(ctrl.P_target/1000; digits=1)) kW"
    else
        return "HOLDING"
    end
end

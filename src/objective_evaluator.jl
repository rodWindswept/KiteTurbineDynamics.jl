# src/objective_evaluator.jl
#
# The windowed-ODE evaluator — one deep module for the objective family.
#
# Before this file (2026-08-09): each objective version (v11, v12, ...) was a
# copy of the same protocol — decode genome → build system → settle/kickstart
# or static pre-solve → windowed ODE run → gates → score — with the fitness
# line as the only real difference.  Fixes (Betz, A1 util co-location,
# stationarity) had to be re-applied N times and had already landed
# inconsistently; the first Betz gate even referenced P_range before its
# assignment — a live UndefVarError on the rejection path.
#
# Now: one module owns the protocol.  Versions are small adapters that supply
# a fitness function and an ObjectiveConfig.  The interface:
#
#     evaluate_windowed(x, beam_profile, p, cfg; start_mode, ..., fitness_fn)
#         -> ObjectiveResult
#     with_k_bracket(scoring, x, beam_profile, p; ...) -> (ObjectiveResult, k)
#
# The fitness function is the seam: `fitness_fn(P_mean, FoS_min, cfg) ->
# Float64`.  Returning Inf (or NaN) marks a hard rejection — the evaluator
# converts it to status=:reject.  Tiered scores like objective_feasibility's
# 12.0 rejection band are SCORES, produced by the adapter for valid evals;
# they are never used as transport signals.


# ── Helper: minimum airborne ring FoS ──────────────────────────────────

"""
    min_ring_fos(u, sys, p) -> Float64

Return the minimum FoS across all airborne (non-ground) rings.
Returns Inf if no valid FoS values are found.  Uses 
internally — call sparingly (once per ramp chunk, not every ODE step).
"""
function min_ring_fos(u::Vector{Float64}, sys::KiteTurbineSystem, p::SystemParams)
    # Use a dummy wind function — ring FoS doesn't depend on wind direction
    dummy_wf = (pos, t) -> [0.0, 0.0, 0.0]
    ef = capture_extended(u, sys, p, 0.0, dummy_wf, nothing;
        brake_engaged=sys.brake_engaged[])
    airborne = Float64[]
    for i in 2:length(ef.ring_fos)
        v = ef.ring_fos[i]
        (!isnan(v) && !isinf(v) && v > 0) && push!(airborne, v)
    end
    return isempty(airborne) ? Inf : minimum(airborne)
end

# ══════════════════════════════════════════════════════════════════════════════
# Protocol constants (fixed scoring/physics knobs — not swept)
# ══════════════════════════════════════════════════════════════════════════════

const WIND_MS     = 11.0   # rated wind speed at reference height
# Minimum acceptable FoS for the objective scoring gate.  Named FOS_GATE (not
# FOS_DESIGN) — structural_safety.jl already owns the name FOS_DESIGN = 3.0
# (the design-point buckling FoS), and the objective's old `const FOS_DESIGN =
# 1.5` silently SHADOWED it at load: every runtime lookup (including the
# dashboard's "FoS_design" label) got 1.5.  Fixed 2026-08-09.
const FOS_GATE    = 1.5    # minimum acceptable FoS
# Stationarity soft penalty (F5): the DE must not be rewarded for transient
# power peaks.  A design whose window power swings wider than 20% of its mean
# pays λ per unit of excess swing ratio.
const STATIONARITY_LAMBDA = 10.0
const STATIONARITY_SWING = 0.20   # matches the gate's P_range/P_mean < 0.20
# MPPT gain clamp ceiling (S2): widened from 1000 so the k-bracket can bracket
# near the old ceiling — the optimum previously railed at 1000.
const K_MPPT_MAX = 5000.0
const V11_DT      = 4e-5   # ODE time step — must match sim fidelity (stiff system)

# Tip-speed sanity ceiling (2026-08-14): anchored to the design point —
# ideal TSR ≈ 4 at v_rated = 11 m/s ⇒ ~44 m/s design tip speed, so 100 m/s
# is ~2.3× headroom. Anything past it is a diverged state (the v13 18m
# winner's hub ring hit tip speed ~1.8e70 m/s while the ground generator
# read 8.6 kW) or a machine that cannot hold together. Instrument sanity
# bound (model-validity ceiling), not a material law.
const TIP_SPEED_CEILING_MPS = 100.0
# Cold-start window timing (the warm-start path takes relax/window from the
# ObjectiveConfig; the cold path's "discard + window" is the same shape).
const WINDOW_S  = 60.0   # scoring window after transient
const DISCARD_S = 30.0   # transient discard before window

# ══════════════════════════════════════════════════════════════════════════════
# ObjectiveConfig — sweepable/tunable parameters, threaded explicitly
# ══════════════════════════════════════════════════════════════════════════════

"""
    ObjectiveConfig(; k_mppt, relax_s, window_s, power_W, v_rated, ...)

Immutable bundle of the tunable parameters for one evaluation.  Sweep control
meets eval reads at this argument — there are no mutable globals to race.
Campaign scripts build one per eval; tests build one per call.

Replaces the former module-level Refs (`WARM_RELAX_S`, `WARM_WINDOW_S`,
`V12_*`) — those became a data race when the campaign launcher swept them
inside its threaded DE loop.
"""
Base.@kwdef struct ObjectiveConfig
    k_mppt::Float64      = 10.0    # generator loading gain τ_gen = k·ω²
    relax_s::Float64     = 10.0    # relaxation after warm-start init
    window_s::Float64    = 30.0    # measurement window
    power_W::Float64     = 50_000.0
    v_rated::Float64     = 11.0
    # V12 power-window / FoS-target scoring knobs
    p_floor_kw::Float64  = 25.0    # penalty below
    p_ceiling_kw::Float64 = 50.0   # penalty above
    fos_target::Float64  = 3.0     # ideal factor of safety
    fos_hard::Float64    = 1.5     # hard rejection below
    w_floor::Float64     = 4.0     # P < floor: quadratic weight
    w_ceiling::Float64   = 2.0     # P > ceiling: quadratic weight
    w_fos_below::Float64 = 4.0     # FoS < target: steep quadratic
    w_fos_above::Float64 = 0.02    # FoS > target: gentle linear slope
    fos_cap::Float64     = 16.0   # FoS above this is excessive mass — hard rejection
    tether_diameter::Float64 = 0.003  # tether line diameter (m) — physical parameter, not a magic number
    # V13 knobs (2026-08-13 — defaults preserve v12 behaviour exactly)
    power_stat::Symbol  = :mean    # :mean = v12 full-window mean; :tail5 = last 5 samples (sustained power)
    penalize_ceiling::Bool = true  # false → above-ceiling power at rated wind is headroom, not a flaw (Betz gate still rejects cheats)
    kickstart_s::Float64 = 2.0     # cold-start PTO motor kick duration; 0.0 = off. Legacy ζ=1.5 stall crutch — the kick injects ~115× MPPT torque and winds chains past the collapse limit; v13 uses 0.0
end

# Copy-with-overrides constructor.  (Base.@kwdef does not generate it;
# the k-bracket needs it to build one config per k_try.)
function ObjectiveConfig(o::ObjectiveConfig; k_mppt=o.k_mppt, relax_s=o.relax_s,
                         window_s=o.window_s, power_W=o.power_W, v_rated=o.v_rated,
                         p_floor_kw=o.p_floor_kw, p_ceiling_kw=o.p_ceiling_kw,
                         fos_target=o.fos_target, fos_hard=o.fos_hard,
                         w_floor=o.w_floor, w_ceiling=o.w_ceiling,
                         w_fos_below=o.w_fos_below, w_fos_above=o.w_fos_above,
                         fos_cap=o.fos_cap, tether_diameter=o.tether_diameter,
                         power_stat=o.power_stat, penalize_ceiling=o.penalize_ceiling,
                         kickstart_s=o.kickstart_s)
    return ObjectiveConfig(k_mppt, relax_s, window_s, power_W, v_rated,
                           p_floor_kw, p_ceiling_kw, fos_target, fos_hard,
                           w_floor, w_ceiling, w_fos_below, w_fos_above, fos_cap,
                           tether_diameter, power_stat, penalize_ceiling, kickstart_s)
end

# ══════════════════════════════════════════════════════════════════════════════
# ObjectiveResult — the one result contract for the whole family
# ══════════════════════════════════════════════════════════════════════════════

"""
    ObjectiveResult(status, fitness, P_mean, FoS_min, ω_eq, P_range,
               drifted, stationary, util_a, util_b, T_lift)

Named result of one evaluation.  `status` is the single reject channel:
`:ok` or `:reject`.  Consumers gate on `status` — they never infer rejection
from the fitness magnitude.  A rejected eval carries `fitness = Inf`,
`P_mean = 0.0`, `FoS_min = Inf` and the `-1.0` util sentinels.
"""
struct ObjectiveResult
    status::Symbol
    fitness::Float64
    P_mean::Float64
    FoS_min::Float64
    ω_eq::Float64
    P_range::Float64
    drifted::Bool
    stationary::Bool
    util_a::Float64
    util_b::Float64
    T_lift::Float64
    P_end::Float64        # mean of last 5 window samples (sustained power; V13)
    twist_crossed::Bool   # per-segment twist past the geometric crossing limit (V13)
    line_broken::Bool     # any TRPT line exceeded ROPE_BREAK_STRAIN (2026-08-14)
end

ObjectiveResult(; status, fitness, P_mean, FoS_min, ω_eq, P_range,
           drifted, stationary, util_a, util_b, T_lift, P_end, twist_crossed,
           line_broken) =
    ObjectiveResult(status, fitness, P_mean, FoS_min, ω_eq, P_range,
               drifted, stationary, util_a, util_b, T_lift, P_end, twist_crossed,
               line_broken)

"""Standard rejected evaluation — `ω_eq` carries through when known."""
rejected_eval(ω_eq::Float64=0.0; line_broken::Bool=false, twist_crossed::Bool=false) =
    ObjectiveResult(:reject, Inf, 0.0, Inf, ω_eq, 0.0, true, false, -1.0, -1.0, 0.0,
                    0.0, twist_crossed, line_broken)

"""
    rotor_betz_ok(power_kw, swept_area_m2, v_wind_mps) -> Bool

Per-rotor Betz potential check (2026-08-14, Rod): a rotor's own extracted
aerodynamic power must be ≤ 1.1× the Betz potential of its own swept disk
(0.593·½ρv³A). NaN fails. Belt-and-braces with the cp falloff — mostly
redundant when the aero model is honest, which is exactly what makes it a
good regression tripwire for the model.
"""
function rotor_betz_ok(power_kw::Float64, swept_area_m2::Float64, v_wind_mps::Float64)::Bool
    isfinite(power_kw) || return false
    betz_kw = 0.593 * 0.5 * 1.225 * swept_area_m2 * v_wind_mps^3 / 1000.0
    return power_kw <= 1.1 * betz_kw
end

"""Rotors must sweep a valid ANNULUS: inner tip radius ≥ 0 for the main rotor
and every expansion rotor (the ring-anchored 70/30 split: r_ring ≥ 0.3·span,
2026-08-20). A negative inner tip means the blade's inboard 30% crosses the
shaft axis — geometrically impossible. Returns false if any rotor violates it."""
function rotor_annulus_ok(sys::KiteTurbineSystem)
    sys.rotor.blade_hub_radius >= 0.0 || return false
    for er in sys.expansion_rotors
        if 1 <= er.ring_idx <= length(sys.ring_ids)
            r_nom = (sys.nodes[sys.ring_ids[er.ring_idx]]::RingNode).radius
            r_in = r_nom + er.blade_hub_radius   # blade_hub < 0 (inboard offset)
            r_in >= 0.0 || return false
        end
    end
    return true
end

"""
    tip_speed_sanity_ok(u, sys) -> Bool

Tip-speed sanity check (2026-08-14, tightened per Rod: ceiling 100 m/s, the
design point is ~44 m/s at TSR 4 / 11 m/s). Checks EVERYTHING that spins:

1. every TRPT ring ω finite, and ring rim speed |ω_i|·radius_i ≤ ceiling
2. hub rotor blade tip |ω_hub|·rotor.radius ≤ ceiling
3. every expansion rotor tip |ω[ring_idx]|·blade_tip_radius ≤ ceiling

NaN/Inf ω fails automatically (comparisons with NaN are false). A diverged
ring (ω ~ 1e66 from a tiny freewheeling hub) leaves ground-side metrics
(P_gen, twist) healthy-looking — twist NaN-freezes, broken-ring FoS gets
filtered — so the evaluator and gate must check every spinning element.
"""
function tip_speed_sanity_ok(u::AbstractVector, sys::KiteTurbineSystem)
    N = sys.n_total
    Nr = sys.n_ring
    # 1. All rings: finite ω and rim speed within ceiling
    for ri in 1:Nr
        w = u[6N + Nr + ri]
        r_ring = (sys.nodes[sys.ring_ids[ri]]::RingNode).radius
        (isfinite(w) && abs(w) * r_ring <= TIP_SPEED_CEILING_MPS) || return false
    end
    # 2. Hub rotor tip
    hub_ri = (sys.nodes[sys.rotor.node_id]::RingNode).ring_idx
    w_hub = u[6N + Nr + hub_ri]
    (isfinite(w_hub) && abs(w_hub) * sys.rotor.radius <= TIP_SPEED_CEILING_MPS) || return false
    # 3. Expansion rotor tips
    for er in sys.expansion_rotors
        w = u[6N + Nr + er.ring_idx]
        (isfinite(w) && abs(w) * er.blade_tip_radius <= TIP_SPEED_CEILING_MPS) || return false
    end
    return true
end

"""
    twist_collapse_check(u, sys) -> (crossed, max_ratio, worst_seg)

Torsional collapse detector (2026-08-13). Reads the RAW free-integrated α
states (`u[6N+1:6N+Nr]` — no wrap; `capture_extended`'s `segment_twist`
wraps mod 2π and cannot see multi-revolution wind-up). Per segment i:
Δα_i = |α[i+1]−α[i]| vs the geometric crossing limit
δα*_i = 2·asin(L_seg/√(2(L_seg²+2r_seg²))) with r = max(r_i, r_{i+1})
(conservative: δα* decreases in r, so max r gives the tightest limit).
Any segment past its limit = the lines have crossed = collapse.
"""
function twist_collapse_check(u::AbstractVector, sys::KiteTurbineSystem)
    N = sys.n_total
    Nr = sys.n_ring
    crossed = false
    max_ratio = 0.0
    worst_seg = 0
    for ri in 1:(Nr - 1)
        r_i = (sys.nodes[sys.ring_ids[ri]]::RingNode).radius
        r_ip1 = (sys.nodes[sys.ring_ids[ri+1]]::RingNode).radius
        r_seg = max(r_i, r_ip1)
        p_i = u[(3 * (sys.ring_ids[ri] - 1) + 1):(3 * sys.ring_ids[ri])]
        p_ip1 = u[(3 * (sys.ring_ids[ri+1] - 1) + 1):(3 * sys.ring_ids[ri+1])]
        L_seg = norm(p_ip1 - p_i)
        dastar = 2 * asin(min(L_seg / sqrt(2 * (L_seg^2 + 2 * r_seg^2)), 1.0))
        da = abs(u[6N + ri + 1] - u[6N + ri])  # α[i+1] − α[i], raw (α block: 6N+1..6N+Nr)
        ratio = da / max(dastar, 1e-9)
        if ratio > max_ratio
            max_ratio = ratio
            worst_seg = ri
        end
        crossed |= da > dastar
    end
    return (crossed=crossed, max_ratio=max_ratio, worst_seg=worst_seg)
end

# ══════════════════════════════════════════════════════════════════════════════
# System builder — the protocol's build step (moved from objective_v11.jl)
# ══════════════════════════════════════════════════════════════════════════════

function build_system_from_v10(result, blade_scale::Float64, k_mppt::Float64;
                              tether_diameter::Float64=0.003,
                              base_params::Union{Nothing,SystemParams}=nothing)
    (; design, rotors, n_rings) = result
    n_lines = design.n_lines

    # Rung-scaled campaign base when provided (5 kW campaigns pass their own
    # params_at_length base); default is the 50 kW base so existing 50 kW
    # callers are unchanged.  (2026-08-20: previously hard-coded
    # params_v5_50kw(), which contaminated every other rung with 50 kW blade
    # mass — see docs/reports/grounded-economics-v13.md §4b.)
    p_base = base_params === nothing ? params_v5_50kw() : base_params
    le = blade_scale

    # Build expansion rotor params (Gate 1c: n_blades = n_lines) — single
    # authority mapping, see builders_util.jl:expansion_params_from_rotors.
    # Span³ blade-mass law (2026-08-22): assembly = n_lines ·
    # M_BLADE_REF_KG · (decoded span)³ (builder dial 1.0 here).
    expansion_params = expansion_params_from_rotors(rotors, n_rings, n_lines;
                                                    blade_scale=blade_scale)

    # Compute design-aware per-ring mass from actual tube geometry instead of
    # the hard-coded 0.4 kg constant.  Without this, the DE can max out Do_top
    # and get free structural stiffness with zero mass penalty — producing
    # campaigns that report green but design physically impossible machines.
    # Tube: Do = Do_top × (r/r_hub)^Do_scale_exp, t = t_over_D × Do.
    # Mass per ring ≈ n_lines × ρ_cfrp × π × Do × t × L_beam
    # Use the average ring radius (linear taper) for a representative value.
    # NOTE: taper exponent comes from the genome (Do_scale_exp, x4), matching
    # the structural analysis — previously hard-coded √R (0.5), which let the
    # DE pick exp=1.0 for free (2026-08-07, F4b audit).
    r_avg = 0.5 * (design.r_hub + design.r_bottom)
    Do_avg = design.Do_top * (r_avg / design.r_hub)^design.Do_scale_exp
    t_avg = design.t_over_D * Do_avg
    L_avg = 2.0 * r_avg * sin(π / design.n_lines)
    ρ_cfrp = 1600.0  # kg/m³ — matches SpacerRingDesign default
    area_avg = π / 4.0 * (Do_avg^2 - (Do_avg - 2t_avg)^2)
    m_ring_design = design.n_lines * ρ_cfrp * area_avg * L_avg
    m_ring_design = max(m_ring_design, 0.05)  # floor: 50 g

    # Main (hub) rotor — ring-anchored annulus (2026-08-20): the blade attaches
    # to the hub ring (design.r_hub) at 70% outboard / 30% inboard of its span,
    # so r_out = r_hub + 0.7·span and r_in = r_hub − 0.3·span.  sys.rotor.radius
    # = r_out (TSR / tip-speed reference); the swept area is the ANNULUS
    # π(r_out² − r_in²), carried via rotor_blade_hub_radius = r_in.  Consistent
    # with the expansion rotors; 0.0 inner tip = legacy full disk.
    hub_rotor = nothing
    for r in rotors
        if r.ring_idx == n_rings   # top ring = hub rotor
            hub_rotor = r
            break
        end
    end
    if hub_rotor === nothing
        R_main = 5.0 * le
        r_in = 0.0
    else
        R_main = design.r_hub + hub_rotor.blade_tip_radius     # r_out
        r_in = max(design.r_hub + hub_rotor.blade_hub_radius, 0.0)  # r_in ≥ 0
    end
    geo = GeometrySpec(p_base.elevation_angle, p_base.lifter_elevation, R_main,
                       design.tether_length, design.r_hub,
                       p_base.trpt_rL_ratio,
                       n_lines, n_rings, n_lines)
    # Main-rotor blade mass: SPAN³ law (2026-08-22 correction) — the blade
    # is priced by its DECODED span, m = M_BLADE_REF_KG·(span/1.0)³, because
    # the decoder sets span = 0.75·r_rotor·λ with r_rotor from the BEM power
    # sizing.  The earlier λ³-only implementation let the DE choose small λ
    # with large r_rotor: blades LONGER than the Daisy reference priced 15×
    # under (the completed 5 kW campaign's winners were all such artifacts
    # and are VOID).  The k_mppt λ²-scaling (objective_evaluator.jl:426) is
    # UNCHANGED — power ∝ swept area ∝ λ² is correct physics; only the mass
    # law changed (mass ∝ volume ∝ span³).
    span_hub = (hub_rotor === nothing) ? 0.0 :
        (hub_rotor.blade_tip_radius - hub_rotor.blade_hub_radius) * le
    mat = MaterialSpec(tether_diameter, p_base.e_modulus, m_ring_design,
                       M_BLADE_REF_KG * span_hub^3)
    aero = AeroSpec(p_base.rho, p_base.v_wind_ref, p_base.h_ref, p_base.cp)
    ctrl = ControlSpec(p_base.i_pto, k_mppt, p_base.p_rated_w,
                       p_base.β_min, p_base.β_max, p_base.β_rate_max, p_base.kp_elev)
    back = BackLineSpec(p_base.EA_back_line, p_base.c_back_line, p_base.back_anchor_fwd_x, 0.1)
    pc = SystemParams(geo, mat, aero, ctrl, back)

    # v5 builder: ring geometry from ring_spacing_v4 (the DECODED taper),
    # NOT the linear-taper build_kite_turbine_system which derived r_bot from
    # the FIXED trpt_rL_ratio and dropped r_bottom/target_Lr/density_profile
    # (x6/x7/x9 dead in the ODE; negative radii for large hubs; DECISIONS
    # [2026-08-24]).
    sys, u0 = build_kite_turbine_system_v5(
        pc, design.target_Lr, design.r_bottom;
        density_profile=design.density_profile,
        expansion_rotors=expansion_params,
        rotor_blade_hub_radius=r_in,
    )

    # Populate ring beam geometry from the genome so ring_element_analysis uses
    # the DE's Do_top/t_over_D rather than falling through to the hard-coded
    # 0.01396×√R legacy scaling.  (2026-08-05: absent since V10 — the DE was
    # optimising a dead parameter.  See builders_util.jl for the parallel
    # path that the acceptance-test tight builder did have.)
    # Do_scale_exp (x4) and r_hub (x5) ride along so analyse_ring's campaign
    # path (design === nothing) reproduces the design path's taper law
    # Do(r) = Do_top·(r/r_hub)^exp exactly (2026-08-07, F4b audit).
    sys.ring_Do_top[]       = design.Do_top
    sys.ring_toverD[]       = design.t_over_D
    sys.ring_aspect_ratio[] = design.beam_aspect
    sys.ring_Do_scale_exp[] = design.Do_scale_exp
    sys.ring_r_hub[]        = design.r_hub

    return sys, u0, pc
end

# ══════════════════════════════════════════════════════════════════════════════
# evaluate_windowed — the protocol
# ══════════════════════════════════════════════════════════════════════════════

"""
    evaluate_windowed(x, beam_profile, p, cfg; start_mode=:warm, ...,
                      fitness_fn) -> ObjectiveResult

The one windowed-ODE protocol for the objective family:

  decode genome → gates (n_active, n_rings) → build system → start
  (:warm static pre-solve | :cold settle+kickstart) → relax + measurement
  window → gates (Betz, stationarity) → score via `fitness_fn`.

`fitness_fn(P_mean, FoS_min, cfg) -> Float64` is the version seam.  A
non-finite return is a hard rejection (status=:reject).  The shared
stationarity soft penalty is applied on top of the adapter's score.

Accepts a 14-D genome; a legacy 15-D vector (x[15] = log₁₀ k_mppt) is
accepted and sliced — k now comes from `cfg.k_mppt`, never the genome.
"""
function evaluate_windowed(
    x::AbstractVector,
    beam_profile::BeamProfile,
    p::SystemParams,
    cfg::ObjectiveConfig;
    start_mode::Symbol=:warm,   # :warm = static pre-solve, :cold = settle+kickstart
    elev_angle::Float64=π / 6,
    spoke::Union{Nothing,SpokeParams}=nothing,
    lin_damp::Float64=0.05,     # bearing damper retention factor
    # A LiftDevice is used as-is.  A Function is called as `f(sys, p)` once the
    # system exists, so the device can be sized to this genome's airborne mass —
    # e.g. `(s, pp) -> sized_lifter_for(s, pp; margin=1.5)`.
    lift_device::Union{Nothing,LiftDevice,Function}=nothing,
    # Diagnostic tap.  Called every ODE step as trace_callback(u, t, step, ctx)
    # where ctx = (; sys, pc, wf, lift_device).  Scoring is unaffected.
    trace_callback::Union{Nothing,Function}=nothing,
    fitness_fn::Function,       # the version seam — required
)
    # ── Decode genome ────────────────────────────────────────────────────
    (length(x) == TRPT_V10_DIM || length(x) == TRPT_V10_DIM + 1) ||
        error("evaluate_windowed expects $TRPT_V10_DIM-D genome, got $(length(x))")
    x14 = x[1:TRPT_V10_DIM]
    result = design_from_vector_v10(
        x14, beam_profile, p; power_W=cfg.power_W, v_rated=cfg.v_rated
    )
    if result.n_active == 0
        return rejected_eval()  # no rotors = infeasible
    end

    # n_rings gate — require at least 1 intermediate (flown) ring.
    if result.n_rings < 1
        return rejected_eval()
    end

    k_mppt = clamp(cfg.k_mppt, 0.01, K_MPPT_MAX)

    # ── Build ODE system ─────────────────────────────────────────────────
    # blade_scale = 1.0 — the genome's λ values already scale blades via
    # design_from_vector_v10's RotorSpecV10.blade_tip_radius etc.
    # base_params = p — the campaign's rung-scaled base (5 kW campaigns pass
    # their params_at_length base; 50 kW default keeps legacy callers
    # bit-identical).  Fixes the 50 kW blade-mass contamination (2026-08-20).
    sys, u0, pc = build_system_from_v10(result, 1.0, k_mppt;
        tether_diameter=cfg.tether_diameter, base_params=p)

    # Annulus gate (2026-08-20): every rotor must sweep a valid annulus
    # (inner tip ≥ 0, the r_ring ≥ 0.3·span constraint of the 70/30 split).
    if !rotor_annulus_ok(sys)
        return rejected_eval()
    end

    (; design, rotors, n_rings, zs) = result
    n_lines = design.n_lines

    # Resolve a design-aware lift device.
    # CRITICAL: hand it `pc`, NOT `p`.  `p` is the shared base SystemParams;
    # `pc` (from build_system_from_v10 above) is the one carrying THIS
    # genome's n_lines, n_rings, tether_length and blade-scaled m_blade.
    lift_dev = lift_device isa Function ? lift_device(sys, pc) : lift_device

    # ── Wind function ────────────────────────────────────────────────────
    function wf(pos, t)
        z = max(pos[3], 1.0)
        return [WIND_MS * (z / p.h_ref)^(1.0 / 7.0), 0.0, 0.0]
    end

    # ── Start protocol ───────────────────────────────────────────────────
    ω_eq = 0.0
    if start_mode === :warm
        # Static equilibrium pre-solve (same path as objective_v10).
        # The rotor→ring mapping is now the SAME single authority the ODE
        # builder uses (was: raw rotor.ring_idx here — one ring low on
        # multi-ring machines, so the static pre-solve and the ODE run
        # disagreed about which machine they were solving).  Blade scale 1.0
        # matches the ODE build; the old `expansion_blade_mass(tip, λ)` call
        # also disagreed with the ODE path's mass for λ ≠ 1 rotors.
        expansion_params_v10 = expansion_params_from_rotors(rotors, n_rings, n_lines)

        _, radii, _ = ring_spacing_v4(
            design.r_hub, design.r_bottom, design.tether_length, design.target_Lr;
            density_profile=design.density_profile,
        )

        λ_eff = result.n_active > 0 ? rotors[1].blade_scale : 1.0
        k_mppt_eff = p.k_mppt * λ_eff^2  # λ²-scaling for static solver
        p_scaled = override_params(p; k_mppt=k_mppt_eff)

        ω_eq, r_ref = solve_equilibrium_self_consistent(
            design, expansion_params_v10, p_scaled, n_lines, radii, zs;
            P_per_rotor=cfg.power_W / max(result.n_active, 1),
            v_wind=cfg.v_rated, elev_rad=elev_angle,
        )

        if ω_eq === nothing || isnan(ω_eq) || ω_eq <= 0.0
            return rejected_eval()
        end

        # Settle rope geometry from ODE
        u_settled = settle_to_equilibrium(sys, u0, pc; wind_fn=wf, lift_device=lift_dev)
        if any(isnan.(u_settled)) || any(isinf.(u_settled))
            return rejected_eval(ω_eq)
        end

        # Set ring angular velocities and orbital velocities: v = ω_eq × r
        # tangential.  Without this, spinning rings + zero node velocity =
        # violent transient that produces spurious FoS collapse and power
        # overshoot (ref: recheck_12gon_convergence.jl).
        N = sys.n_total
        Nr = sys.n_ring
        u_settled[(6N + Nr + 1):(6N + 2Nr)] .= ω_eq  # ring twist rates
        for ri in 1:Nr
            gid = sys.ring_ids[ri]
            pos = u_settled[(3*(gid-1)+1):(3*gid)]
            r = norm(pos)
            if r > 0.01
                tang = [-pos[2], pos[1], 0.0]; tang ./= norm(tang)
                vx_idx = 3N + 3*(gid-1) + 1
                u_settled[vx_idx:(vx_idx+2)] .= (ω_eq * r) .* tang
            end
        end
    else
        # Cold start: settle to operational state, then kickstart — brief
        # PTO reversal to motor the rotor onto the productive branch.
        u_settled = nothing
        try
            u_settled = settle_to_operational_state(
                sys, copy(u0), pc, 60.0; wind_fn=wf, lift_device=lift_dev
            )
        catch e
            @warn "Settle failed for genome" exception = e
            return rejected_eval()
        end
        if u_settled === nothing
            return rejected_eval()
        end
        # Carry the settle's ground-ring ω into the result's ω_eq (2026-08-22):
        # the cold path previously left ω_eq = 0.0, so telemetry read "settle
        # failed" when it had parked at a perfectly good operating point.  The
        # sweep's ω_settle−ω_final gap metric depends on this.
        ω_eq = u_settled[6 * sys.n_total + sys.n_ring + 1]

        orig_k = sys.k_mppt_ref[]
        try
            # PTO torque reversal: set k negative momentarily to motor the rotor
            # (LEGACY ζ=1.5 stall escape — with ζ=0.05 the settle reaches the
            # productive branch directly and the kick is unnecessary; v13 sets
            # cfg.kickstart_s = 0.0. The kick injects ~115× MPPT torque at the
            # ground ring and can itself wind a healthy chain past its collapse
            # limit.)
            if cfg.kickstart_s > 0.0
                sys.k_mppt_ref[] = -60.0  # N·m·s²/rad² — motor torque
                kick_steps = round(Int, cfg.kickstart_s / V11_DT)
                run_canonical_sim!(
                    u_settled, sys, pc, wf, kick_steps, V11_DT;
                    lift_device=lift_dev, lin_damp=lin_damp, spoke=spoke
                )
            end
        catch e
            @warn "Kickstart failed" exception = e
            sys.k_mppt_ref[] = orig_k
        end
        sys.k_mppt_ref[] = orig_k  # restore MPPT k
    end

    # ── Set k_mppt for the ODE run ───────────────────────────────────────
    sys.k_mppt_ref[] = k_mppt

    # ── Run relaxation + window ──────────────────────────────────────────
    total_s = cfg.relax_s + cfg.window_s
    total_n = round(Int, total_s / V11_DT)
    sample_interval = round(Int, 1.0 / V11_DT)

    P_samples = Float64[]
    fos_samples = Float64[]
    util_a_samples = Float64[]  # worst-ring axial share per sample
    util_b_samples = Float64[]  # worst-ring bending share per sample
    T_lift_samples = Float64[]  # per-sample lift-line tension (S3: real N)

    trace_ctx = (; sys=sys, pc=pc, wf=wf, lift_device=lift_dev)
    twist_flagged = Ref(false)  # V13: set on first per-segment twist crossing
    hub_diverged = Ref(false)   # 2026-08-14: hub ring ω non-finite or tip speed past sanity ceiling
    betz_rotor_flagged = Ref(false)  # 2026-08-14: any rotor's own power past its own Betz potential

    function window_callback(uc, tc, s)
        # Diagnostic tap runs first and is scoring-neutral.
        trace_callback !== nothing && trace_callback(uc, tc, s, trace_ctx)

        t_cum = s * V11_DT
        if t_cum > cfg.relax_s && s % sample_interval == 0
            # V13 torsional collapse detector: any segment past its geometric
            # crossing limit δα* fails the design regardless of power readings.
            if !twist_flagged[] && twist_collapse_check(uc, sys).crossed
                twist_flagged[] = true
            end
            # Tip-speed sanity: a diverged ring leaves ground-side metrics
            # healthy (NaN-frozen twist, filtered FoS) — check every ring
            # rim and every rotor tip explicitly.
            if !hub_diverged[] && !tip_speed_sanity_ok(uc, sys)
                hub_diverged[] = true
            end
            ef = capture_extended(
                uc, sys, pc, tc, wf, lift_dev; brake_engaged=sys.brake_engaged[]
            )
            # Per-rotor Betz potential: each rotor's OWN extracted power must
            # sit inside 1.1×Betz of its own swept disk (Rod 2026-08-14).
            if !betz_rotor_flagged[]
                n_er = length(sys.expansion_rotors)
                for (i, pa_kw) in enumerate(ef.rotor_aero_power)
                    A_i = if i == 1
                        # main rotor: swept ANNULUS (2026-08-20, ring-anchored 70/30)
                        π * (sys.rotor.radius^2 - sys.rotor.blade_hub_radius^2)
                    elseif i - 1 <= n_er
                        # expansion rotor: same annulus the ODE sweeps
                        # (was full disk π·tip² — ignored the inboard hub cutout)
                        er = sys.expansion_rotors[i - 1]
                        ri = er.ring_idx
                        r_ring = (1 <= ri <= sys.n_ring) ?
                            (sys.nodes[sys.ring_ids[ri]]::RingNode).radius : 0.0
                        expansion_annulus_area(er, r_ring)
                    else
                        0.0
                    end
                    if A_i > 0.0 && !rotor_betz_ok(pa_kw, A_i, cfg.v_rated)
                        betz_rotor_flagged[] = true
                        break
                    end
                end
            end
            push!(P_samples, ef.base.P_kw)
            isfinite(ef.base.T_lift) && push!(T_lift_samples, ef.base.T_lift)
            airborne = Float64[]
            for i in 2:length(ef.ring_fos)
                v = ef.ring_fos[i]
                (!isnan(v) && !isinf(v) && v > 0) && push!(airborne, v)
            end
            push!(fos_samples, isempty(airborne) ? Inf : minimum(airborne))
            # Axial and bending shares at worst-FoS ring (A1 fix — always push
            # to keep array lengths aligned with fos_samples)
            if !isempty(airborne)
                worst_idx = argmin(airborne) + 1  # +1 for 1-based indexing
                if worst_idx <= length(ef.ring_util_axial)
                    push!(util_a_samples, ef.ring_util_axial[worst_idx])
                    push!(util_b_samples, ef.ring_util_bending[worst_idx])
                else
                    push!(util_a_samples, -1.0)
                    push!(util_b_samples, -1.0)
                end
            else
                push!(util_a_samples, -1.0)
                push!(util_b_samples, -1.0)
            end
        end
    end

    try
        run_canonical_sim!(
            u_settled, sys, pc, wf, total_n, V11_DT;
            lift_device=lift_dev, lin_damp=lin_damp, spoke=spoke, callback=window_callback
        )
    catch e
        @warn "Window sim failed" exception = e
        return rejected_eval(ω_eq)
    end

    # Rope break disqualification (2026-08-14, option B): any line strained
    # past ROPE_BREAK_STRAIN stops the sim (early exit in run_canonical_sim!)
    # and rejects the design here.
    if sys.any_broken[]
        return rejected_eval(ω_eq; line_broken=true)
    end

    # ── Score ────────────────────────────────────────────────────────────
    # Filter NaN/Inf from samples before computing statistics
    P_finite = [p for p in P_samples if isfinite(p) && p >= 0.0]
    fos_finite = [f for f in fos_samples if isfinite(f) && f > 0.0]

    if isempty(P_finite) || length(P_finite) < 2
        # No valid power samples — simulation produced garbage
        return rejected_eval(ω_eq)
    end

    P_mean = mean(P_finite)
    # V13: sustained power = mean of the last 5 samples of the window (the
    # tail measures transmission, not the hot-settle flywheel transient).
    P_end = mean(P_finite[max(1, end - 4):end])

    # V13 torsional collapse — hard rejection, carried in the result flag.
    if twist_flagged[]
        return ObjectiveResult(:reject, Inf, 0.0, Inf, ω_eq, 0.0,
                               true, false, -1.0, -1.0, 0.0, 0.0, true, false)
    end

    # Hub-side divergence — hard rejection (2026-08-14, v13 18m winner exploit).
    if hub_diverged[]
        return rejected_eval(ω_eq)
    end

    # Per-rotor Betz violation — hard rejection (2026-08-14, Rod).
    if betz_rotor_flagged[]
        return rejected_eval(ω_eq)
    end

    # Find FoS_min and its sample index in the original arrays (A1 fix).
    # Was: FoS_min = minimum(fos_finite) — no index tracking, so util_a
    # and util_b came from independent maxima rather than the FoS-min instant.
    FoS_min = Inf
    fos_idx_min = 0
    for i in eachindex(fos_samples)
        f = fos_samples[i]
        if isfinite(f) && f > 0.0 && f < FoS_min
            FoS_min = f
            fos_idx_min = i
        end
    end

    P_range = length(P_finite) >= 2 ? maximum(P_finite) - minimum(P_finite) : 0.0
    drift = length(P_finite) >= 2 ? abs(P_finite[end] - P_finite[1]) / max(mean(P_finite), 0.01) : 0.0

    # Axial and bending util at the FoS-min sample (A1 fix).
    # Identity: util_a + util_b = 1/FoS_min for a single beam at a single instant.
    if fos_idx_min > 0 && fos_idx_min <= length(util_a_samples) &&
       fos_idx_min <= length(util_b_samples)
        util_a = util_a_samples[fos_idx_min]
        util_b = util_b_samples[fos_idx_min]
        expected = 1.0 / FoS_min
        if !isapprox(util_a + util_b, expected; rtol=0.01)
            @warn "A1 identity check failed" util_a util_b sum=util_a+util_b expected FoS_min fos_idx_min
        end
    else
        util_a = -1.0
        util_b = -1.0
    end

    # Betz ceiling — physical admissibility check (A2).
    # Total projected swept area: hub rotor + expansion rotors (banked area).
    # Betz power ceiling: 0.593 × ½ρv³ × A_projected.  P_mean must not exceed
    # 1.1× this ceiling (10% tolerance for transient overshoot during window).
    # (The earlier hub-disk-only variant was deleted 2026-08-09: it duplicated
    # this gate with a contradictory area model AND referenced P_range before
    # assignment — a live UndefVarError on the rejection path it existed to
    # serve.  This annulus-area version is the intended physics.)
    # Total projected swept area — the SAME annulus areas the ODE actually
    # sweeps (2026-08-21): hub rotor via main_rotor_swept_area, expansion
    # rotors via expansion_annulus_area.  Was: base-theory p.rotor_radius
    # for the hub and raw blade-tip OFFSETS for the rotors — neither matched
    # the decoded ring-anchored geometry, so the Betz ceiling checked a
    # different machine than the one simulated.
    A_total = main_rotor_swept_area(sys)
    for er in sys.expansion_rotors
        ri = er.ring_idx
        r_ring = (1 <= ri <= sys.n_ring) ?
            (sys.nodes[sys.ring_ids[ri]]::RingNode).radius : 0.0
        A_total += expansion_annulus_area(er, r_ring)
    end
    Betz_ceiling_kW = 0.593 * 0.5 * p.rho * A_total * cfg.v_rated^3 / 1000.0

    # P_available gate (Betz floor): skip winds where the turbine cannot
    # physically reach P_floor.  Uses rotor Cp (not Betz 0.593) so small/
    # low-Cp rotors are correctly gated.  80% threshold prevents edge cases.
    Betz_cp_kW = p.cp * 0.5 * p.rho * A_total * cfg.v_rated^3 / 1000.0
    if Betz_cp_kW < cfg.p_floor_kw * 0.8
        return rejected_eval(ω_eq)
    end

    if P_mean > 1.1 * Betz_ceiling_kW
        return rejected_eval(ω_eq)
    end

    # Stationarity gate: split window into halves, check drift (trend)
    # AND amplitude (steadiness).  A limit cycle with a stable mean is
    # not stationary — it must not oscillate violently.
    n = length(P_finite)
    stationary = false
    if n >= 4
        mid = n ÷ 2
        P1 = P_finite[1:mid]; P2 = P_finite[mid+1:end]
        nf = length(fos_finite)
        if all(isfinite.(P1)) && all(isfinite.(P2)) && mean(P1) > 0.01 &&
           nf >= 4
            mid_f = nf ÷ 2
            F1 = fos_finite[1:mid_f]; F2 = fos_finite[mid_f+1:end]
            # Drift: half-window means must be stable
            dP = abs(mean(P1) - mean(P2)) / mean(P1)
            dF = abs(minimum(F1) - minimum(F2)) / max(mean(F1), 0.01)
            # Amplitude: the design must not oscillate wildly around its mean.
            FoS_range = length(fos_finite) >= 2 ?
                maximum(fos_finite) - minimum(fos_finite) : 0.0
            P_steady = P_mean > 0.1 ? P_range / P_mean < 0.20 : false
            FoS_steady = FoS_min > 0.01 ? FoS_range / FoS_min < 0.20 : false
            stationary = dP < 0.10 && dF < 0.10 && P_steady && FoS_steady
        end
    end

    # Score via the version seam.  A non-finite score is a hard rejection —
    # the adapter (e.g. v12_fitness's FoS < hard gate) signals it that way.
    # V13: power_stat=:tail5 feeds P_end (sustained power) to the seam;
    # default :mean preserves v12 behaviour exactly.
    # 2026-08-20: the seam now also receives the TRUE physics mass
    # (expansion_airborne_mass) so the mass-minimisation objective can score
    # on it — same mass the lift sizing and economics use.  Adapters that
    # don't use mass ignore the 4th argument.
    P_score = cfg.power_stat === :tail5 ? P_end : P_mean
    m_airborne = expansion_airborne_mass(sys, pc)

    # S3: mean lift-line tension over the window (real newtons, per-genome —
    # the sized lifter's T_ref scaled by (v/v_ref)²).  Falls back to the
    # sized device's design-point T_ref when no samples landed.  Computed
    # BEFORE the fitness seam so honest rejects carry it too (2026-08-21).
    T_lift_mean = isempty(T_lift_samples) ?
        (lift_dev isa StackedLifterParams ? lift_dev.T_ref : 0.0) :
        mean(T_lift_samples)

    fitness = fitness_fn(P_score, FoS_min, cfg, m_airborne)
    if !isfinite(fitness)
        # HONEST REJECT (2026-08-21): a below-floor / below-FoS design still
        # measured real power and load in the window (e.g. the k=4.0 seed:
        # P_mean≈6.5 kW, P_end≈4.5 kW < 5.0 floor — the k sweep read this as
        # a "0 kW stall" because rejected_eval zeroed every field).  Carry
        # the measured statistics so telemetry shows WHY the design failed.
        # Status stays :reject and fitness stays Inf — gates and the DE are
        # unchanged; only the recorded numbers become truthful.
        return ObjectiveResult(:reject, Inf, P_mean, FoS_min, ω_eq, P_range,
                          drift > 0.20, stationary, util_a, util_b, T_lift_mean,
                          P_end, twist_flagged[], false)
    end
    # F5 stationarity soft penalty: excess swing (beyond the gate's 20% of
    # mean) is ADDED to fitness so the DE prefers steady designs.
    # Fitness is negative (more negative = better), so we ADD the penalty
    # (making swinging designs worse, i.e. less negative).
    swing = P_mean > 0.1 ? P_range / P_mean : 0.0
    excess = max(0.0, swing - STATIONARITY_SWING)
    fitness = fitness + STATIONARITY_LAMBDA * excess
    drifted = drift > 0.20  # >20% drift = flagged

    return ObjectiveResult(:ok, fitness, P_mean, FoS_min, ω_eq, P_range,
                      drifted, stationary, util_a, util_b, T_lift_mean,
                      P_end, twist_flagged[], false)
end

# ══════════════════════════════════════════════════════════════════════════════
# with_k_bracket — the shared 3-point k bracket
# ══════════════════════════════════════════════════════════════════════════════

"""
    with_k_bracket(scoring, x, beam_profile, p; power_W, v_rated) -> (ObjectiveResult, k)

Evaluate `scoring(x14, cfg)` at 3 k values around the λ²-scaled prior and
return the best `(ObjectiveResult, k)` pair.  Prior: k̂ = p.k_mppt × λ_eff².
Bracket: k̂·{0.5, 1, 2}, deduplicated (S2: when k̂·0.5 > K_MPPT_MAX all three
points collapse to the ceiling).  Rejected evals (status != :ok) never win —
an all-rejected genome returns the `:reject` result, not a fake score.
"""
function with_k_bracket(
    scoring::Function,          # scoring(x14, cfg) -> ObjectiveResult
    x::AbstractVector,
    beam_profile::BeamProfile,
    p::SystemParams;
    power_W::Float64=50000.0,
    v_rated::Float64=11.0,
    cfg::Union{Nothing,ObjectiveConfig}=nothing,  # base tunables (relax/window/knobs)
)
    (length(x) == TRPT_V10_DIM || length(x) == TRPT_V10_DIM + 1) ||
        error("with_k_bracket expects $TRPT_V10_DIM-D genome, got $(length(x))")
    x14 = x[1:TRPT_V10_DIM]
    result = design_from_vector_v10(
        x14, beam_profile, p; power_W=power_W, v_rated=v_rated
    )
    λ_eff = result.n_active > 0 ? result.rotors[1].blade_scale : 1.0
    k_prior = p.k_mppt * λ_eff^2

    base_cfg = cfg === nothing ? ObjectiveConfig() : cfg

    best = rejected_eval()
    best_k = k_prior
    tried_k = Set{Float64}()
    for k_scale in [0.5, 1.0, 2.0]
        k_try = clamp(k_prior * k_scale, 0.01, K_MPPT_MAX)
        k_try in tried_k && continue
        push!(tried_k, k_try)

        c = ObjectiveConfig(base_cfg; k_mppt=k_try, power_W=power_W, v_rated=v_rated)
        r = scoring(x14, c)

        if r.status === :ok && r.fitness < best.fitness
            best = r
            best_k = k_try
        end
    end

    return (best, best_k)
end

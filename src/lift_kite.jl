# src/lift_kite.jl
#
# Lift device models for TRPT hub elevation support.
#
# Three architectures are modelled:
#
#   SingleKiteParams    — one passive parafoil/single-skin kite on a lift line.
#                         Lift force ∝ v². Tension varies linearly with dynamic
#                         pressure and is sensitive to wind turbulence.
#
#   StackedKitesParams  — N smaller kites in cascade on a single lift line.
#                         Total lift area = same as single kite; individual kite
#                         is N times smaller (easier to handle at scale).
#                         Tension profile (ground-to-tip) and structural load
#                         analysis included.
#
#   RotaryLifterParams  — spinning rotor (similar to TRPT geometry but no torque
#                         extraction) whose blades generate lift via high apparent
#                         wind speed from rotation.  Tension variability is much
#                         lower than a passive kite because F_lift ∝ v_apparent²
#                         where v_apparent² ≈ v_wind² + (ω·r)² and ω·r >> v_wind
#                         at nominal operation.
#
# ── Tension sign and direction conventions ────────────────────────────────────
#
#   "Lift line" runs from hub (bottom end) up to the lift device (top end).
#   Tension is positive when the line is in tension (normal operating state).
#   The lift force F_lift pulls the hub UPWARD along the lift line direction.
#   The TRPT shaft tension pulls the hub DOWNWARD along the shaft axis.
#   Hub equilibrium: vector sum of lift line force, shaft tension, and gravity = 0.
#
# ── Stacked kite tension profile (corrected) ─────────────────────────────────
#
#   For N kites numbered 1 (lowest, closest to hub) to N (topmost, furthest up):
#
#   Tension in line DECREASES going upward, because each kite adds its net lift:
#     T_hub  = Σᵢ₌₁ᴺ (Lᵢ − Wᵢ·cos θ)      ← maximum line tension (at hub)
#     T[above kite k] = Σᵢ₌ₖ₊₁ᴺ (Lᵢ − Wᵢ·cos θ)
#     T[above kite N] = 0                    ← free end at top kite
#
#   In normal operation each kite's bridle handles only its own net lift (Lₖ − Wₖ).
#
#   GOVERNING STRUCTURAL LOAD CASE — topmost kite (static/low-wind):
#     At zero or low wind speed (e.g. pre-launch, storm stow) the topmost kite
#     must support the full weight of the cascade below it through the line.
#     W_static_load = Σᵢ₌₁ᴺ⁻¹ mᵢ · g  (weight of all kites below kite N)
#     The topmost kite attachment must therefore be structurally rated for this,
#     NOT just its own aerodynamic load in steady flight.
#     This is the opposite of a mechanical compression stack — it is a tension
#     cascade where the top element bears the worst static structural case.
#
# ── Rotary lifter concept (alphAnemo, SomeAWE, related prior art) ─────────────
#
#   The rotary lifter is essentially a TRPT rotor configured to maximise lift
#   rather than extract torque.  It does not transmit torque to the ground.
#   Key advantage: apparent wind at blade radius r is v_app = √(v²+(ωr)²).
#   At nominal TSR where ωr >> v (e.g. ωr = 3v), a 20% wind gust changes
#   v_app by only ~2%, so lift force is nearly immune to wind variation.
#   This is the fundamental advantage over a passive kite.
#
#   References:
#     alphAnemo (ETH Zurich BRIDGE project, 2025): centrifugally-stiffened
#       three-wing flying rotor; "passive stability" prototype.
#       https://site.alphanemo.com
#     SomeAWE / Windswept and Interesting: TRPT with auxiliary lift kite;
#       lift kite requirements characterised in IEEE ITEC 2024 paper (DOI:
#       10.1109/ITEC60881.2024.10718850); TRPT tensegrity dynamics in
#       WES 9:1273–1291 (2024) DOI:10.5194/wes-9-1273-2024.
#     Stacked / networked kites: Haas et al., Kite Networks for Harvesting
#       Wind Energy, Springer 2018.  Optimal control of stacked multi-kite
#       systems: Leuthold et al., ResearchGate 2019 (DOI:10.13140/RG.2.2.30440).

using LinearAlgebra

# ── Types ──────────────────────────────────────────────────────────────────────

"""
    SingleKiteParams

Passive single-skin or parafoil lift kite on a straight lift line.

Fields:
- `CL`          : lift coefficient (typical parafoil CL ≈ 0.8–1.2)
- `CD`          : drag coefficient (typical parafoil CD ≈ 0.1–0.2; LD ≈ CL/CD ≈ 6–8)
- `area`        : kite projected area (m²)
- `line_length` : lift line unstretched length from hub to kite (m)
- `line_EA`     : lift line axial stiffness (N); Dyneema 4mm ≈ 200 kN
- `m_kite`      : kite + bridle mass (kg)
"""
struct SingleKiteParams <: LiftDevice
    CL          :: Float64
    CD          :: Float64
    area        :: Float64
    line_length :: Float64
    line_EA     :: Float64
    m_kite      :: Float64
end

"""
    StackedKitesParams

N kites of equal size cascaded on a single lift line.
Total area = n_kites × area_each (sizing to match a single kite of the same total area).

Key geometry: spacing between adjacent kites along the lift line (m).
Structural note: topmost kite's attachment is rated for the static weight of all kites below it.
"""
struct StackedKitesParams <: LiftDevice
    n_kites      :: Int
    CL           :: Float64    # per-kite lift coefficient
    CD           :: Float64    # per-kite drag coefficient
    area_each    :: Float64    # per-kite area (m²)
    spacing      :: Float64    # inter-kite spacing along lift line (m)
    line_EA      :: Float64    # lift line axial stiffness (N)
    m_kite_each  :: Float64    # per-kite + bridle mass (kg)
end

"""
    RotaryLifterParams

Spinning rotor (ring-blade geometry, similar to TRPT) optimised for lift.
No torque is extracted; all energy goes into maintaining rotation.
Blades pitched for high CL at the apparent wind angle.

The apparent wind speed at mean blade radius r_mean is:
    v_app = √(v_wind² + (ω · r_mean)²)

Lift force ≈ 0.5 · ρ · v_app² · blade_area · CL_blade

Tension variability (relative to single kite) ≈ v_wind² / (v_wind² + (ω·r)²)
→ at ω·r = 3·v_wind, variability is reduced by a factor of ~10.
"""
struct RotaryLifterParams <: LiftDevice
    rotor_radius :: Float64    # blade tip radius (m)
    hub_radius   :: Float64    # blade root / hub radius (m)
    n_blades     :: Int
    blade_chord  :: Float64    # mean blade chord (m)
    CL_blade     :: Float64    # blade section lift coefficient at design point
    CD_blade     :: Float64    # blade section drag coefficient at design point
    omega_fixed  :: Float64    # fixed operational angular velocity (rad/s)
                               # KEY: omega is held constant by the lifter's own
                               # inertia and control, NOT tracking TSR.  This is
                               # what gives tension insensitivity: v_app²=v²+(ω·r)²
                               # and dT/dv ∝ v_wind/v_app << 1 when ω·r >> v_wind.
    line_length  :: Float64    # lift line length from TRPT hub to lifter (m)
    line_EA      :: Float64    # lift line axial stiffness (N)
    m_lifter     :: Float64    # total lifter mass (rotor + lines, kg)
end

# ── Convenience constructors ───────────────────────────────────────────────────

"""
    single_kite_default(; area)

Default single parafoil kite sized for the 10 kW TRPT prototype.
CL/CD ≈ 6 gives lift line elevation angle ≈ 80° (line nearly vertical).
"""
function single_kite_default(; area::Float64 = 10.0)
    SingleKiteParams(
        1.0,         # CL — moderate parafoil
        0.15,        # CD — LD ≈ 6.7
        area,        # m²; at 10 kW use ~19 m² to achieve lift_margin ≥ 1.0
        20.0,        # line length (m)
        200_000.0,   # line_EA (N) — 4mm Dyneema
        2.0          # m_kite (kg) — single-skin kite + bridle
    )
end

"""
    single_kite_sized(p, rho, v_rated; margin, v_design) → SingleKiteParams

Single kite automatically sized to achieve `margin` × hub_lift_required at `v_design`.

`v_rated` is accepted for API compatibility but is NOT used for sizing — the kite area
is determined entirely by `v_design` and `margin`.

## Why v_design ≠ v_rated

With corrected CT-thrust physics (see hub_lift_required), the hub is self-supporting via
CT thrust at all operational wind speeds above ~3.5 m/s.  The lift kite is genuinely
needed only at low wind during launch, landing, or startup.  The correct sizing point is
therefore the minimum operating wind speed, NOT rated wind.

Default v_design = 4.0 m/s gives ≈ 23 m² for the 10 kW prototype, which matches the
physical design and provides comfortable margin at launch/landing conditions.
"""
function single_kite_sized(p::SystemParams, rho::Float64, v_rated::Float64;
                            margin::Float64 = 1.1,
                            v_design::Float64 = 4.0)
    F_req = hub_lift_required(p, rho, v_design)   # weight-only, wind-independent
    tmpl  = single_kite_default(area = 1.0)
    _, T_per_m2, elev = lift_force_steady(tmpl, rho, v_design)
    F_vert_per_m2 = T_per_m2 * sin(deg2rad(elev))
    area_needed   = F_req * margin / F_vert_per_m2
    return single_kite_default(area = area_needed)
end

"""
    stacked_kites_default(; n_kites, total_area)

Stacked kite default: N kites totalling the same area as a single kite.
"""
function stacked_kites_default(; n_kites::Int = 3, total_area::Float64 = 10.0)
    StackedKitesParams(
        n_kites,
        1.0,                          # CL
        0.15,                         # CD
        total_area / n_kites,         # area_each
        8.0,                          # spacing (m)
        200_000.0,                    # line_EA (N)
        2.0 / n_kites * 1.2           # m_kite_each: pro-rata + 20% for extra attachment
    )
end

"""
    rotary_lifter_default()

Rotary lifter default: TRPT-style rotor sized for 10 kW prototype, no torque extraction.
TSR ≈ 4 → ω·R ≈ 44 rad/s × 1m = 44 m/s >> v_wind at 11 m/s.
Apparent wind speed ≈ 4.4× wind speed → tension variability ≈ 5% of single kite.
"""
function rotary_lifter_default()
    # Design point: v_rated = 11 m/s, TSR = 4.5 → ω = 4.5×11/1.5 = 33 rad/s
    # Then ω·r_mean = 33 × 0.9 = 29.7 m/s >> 11 m/s (v_wind)
    # At this fixed ω, v_app = √(11² + 29.7²) = 31.7 m/s
    # Gust +2 m/s → v_app = √(13² + 29.7²) = 32.5 m/s (+2.6%)
    # Same gust on single kite: ΔT/T = Δ(v²)/v² = (13²-11²)/11² = 41%
    # Tension variability reduction ≈ 2.6/41 ≈ 16× better
    RotaryLifterParams(
        1.5,        # rotor_radius (m)
        0.3,        # hub_radius (m)
        3,          # n_blades
        0.15,       # blade_chord (m)
        1.2,        # CL_blade — high-lift foil section
        0.08,       # CD_blade
        33.0,       # omega_fixed (rad/s) = TSR 4.5 at v=11 m/s → HELD CONSTANT
        25.0,       # line_length (m)
        200_000.0,  # line_EA (N)
        4.0         # m_lifter (kg)
    )
end

# ── Force models ───────────────────────────────────────────────────────────────

"""
    lift_line_direction(elevation_deg)

Unit vector along lift line at given elevation angle (degrees above horizontal).
Line runs from hub (origin) upward to the kite.
Convention: wind along +x, vertical = +z.
"""
function lift_line_direction(elevation_deg::Float64)
    θ = deg2rad(elevation_deg)
    # Kite flies upwind and up: slightly into the wind (-x) and up (+z)
    return [-cos(θ), 0.0, sin(θ)]
end

"""
    kite_elevation_angle(CL, CD) → degrees

Equilibrium flight elevation angle of a kite (angle of lift line above horizontal).
Derived from force balance on the kite: tan(θ) = CL/CD.
"""
function kite_elevation_angle(CL::Float64, CD::Float64)
    rad2deg(atan(CL, CD))
end

"""
    lift_force_steady(dev::SingleKiteParams, rho, v_wind)
        → (F_hub::Vector{Float64}, T_line::Float64, elevation_deg::Float64)

Steady-state lift line force applied to hub node.
F_hub points from hub toward kite (upward and slightly into wind).
T_line is the scalar tension in the lift line.
elevation_deg is the kite flight elevation angle.
"""
function lift_force_steady(dev::SingleKiteParams, rho::Float64, v_wind::Float64)
    q      = 0.5 * rho * v_wind^2
    F_lift = q * dev.area * dev.CL     # upward
    F_drag = q * dev.area * dev.CD     # along wind (away from hub)
    T_line = sqrt(F_lift^2 + F_drag^2) # tension in lift line
    elev   = kite_elevation_angle(dev.CL, dev.CD)
    F_hub  = T_line .* lift_line_direction(elev)
    return (F_hub, T_line, elev)
end

"""
    lift_force_steady(dev::StackedKitesParams, rho, v_wind)
        → (F_hub, T_hub, elevation_deg)

Total lift force at hub from N cascaded kites.
Net lift = sum of all kite forces (hub tension = Σ(Lᵢ − Wᵢ·cosθ)).
"""
function lift_force_steady(dev::StackedKitesParams, rho::Float64, v_wind::Float64)
    q         = 0.5 * rho * v_wind^2
    elev      = kite_elevation_angle(dev.CL, dev.CD)
    θ         = deg2rad(elev)
    L_each    = q * dev.area_each * dev.CL
    D_each    = q * dev.area_each * dev.CD
    W_each    = dev.m_kite_each * 9.81
    # Net lift per kite (corrected for weight component along line)
    T_net_each = sqrt(L_each^2 + D_each^2) - W_each * cos(θ)
    T_hub     = max(0.0, dev.n_kites * T_net_each)
    F_hub     = T_hub .* lift_line_direction(elev)
    return (F_hub, T_hub, elev)
end

"""
    stack_tension_profile(dev::StackedKitesParams, rho, v_wind)
        → Vector{Float64} of length n_kites+1

Tension in the lift line at each position, from hub (index 1) to above topmost kite (index n+1).
Index k = tension in line section between kite k-1 and kite k (k=1 is hub side).
tension[n_kites+1] = 0 (free end above topmost kite).

This is the CORRECT tension model:
  - Tension DECREASES going upward (each kite adds its net lift).
  - Maximum tension is at the hub end.
  - Minimum (zero) is at the free end above the topmost kite.
"""
function stack_tension_profile(dev::StackedKitesParams, rho::Float64, v_wind::Float64)
    q      = 0.5 * rho * v_wind^2
    elev   = kite_elevation_angle(dev.CL, dev.CD)
    θ      = deg2rad(elev)
    L_each = q * dev.area_each * dev.CL
    D_each = q * dev.area_each * dev.CD
    W_each = dev.m_kite_each * 9.81
    T_net  = sqrt(L_each^2 + D_each^2) - W_each * cos(θ)

    profile = Vector{Float64}(undef, dev.n_kites + 1)
    profile[dev.n_kites + 1] = 0.0
    for k in dev.n_kites:-1:1
        profile[k] = profile[k + 1] + max(0.0, T_net)
    end
    return profile
end

"""
    topmost_kite_static_load(dev::StackedKitesParams) → Float64

Static structural load on the topmost kite's attachment point at zero wind.
This is the weight of all kites below it — the governing structural design case.
"""
function topmost_kite_static_load(dev::StackedKitesParams)
    (dev.n_kites - 1) * dev.m_kite_each * 9.81
end

"""
    lift_force_steady(dev::RotaryLifterParams, rho, v_wind)
        → (F_hub, T_line, elevation_deg)

Steady-state lift from a rotary lifter at nominal TSR.
Apparent wind at mean blade radius: v_app = √(v_wind² + (ω·r_mean)²)
Lift ≈ 0.5 · ρ · v_app² · A_blade · CL
"""
function lift_force_steady(dev::RotaryLifterParams, rho::Float64, v_wind::Float64)
    # FIXED omega — not TSR-following.  This is the key difference from a passive kite:
    # omega is maintained by the rotor's own angular momentum and drive mechanism,
    # so a gust changes v_wind but not (immediately) omega.  The apparent wind speed
    # therefore changes much less than the true wind speed.
    omega     = dev.omega_fixed
    r_mean    = (dev.rotor_radius + dev.hub_radius) / 2.0
    v_rot     = omega * r_mean
    v_app     = sqrt(v_wind^2 + v_rot^2)

    # Blade area (both sides, n blades, chord × span)
    span      = dev.rotor_radius - dev.hub_radius
    A_blade   = dev.n_blades * dev.blade_chord * span

    q_app     = 0.5 * rho * v_app^2
    F_lift    = q_app * A_blade * dev.CL_blade
    F_drag    = q_app * A_blade * dev.CD_blade

    # Elevation angle: rotary lifter behaves like a kite with effective CL/CD
    # In practice the lifter flies at a relatively shallow elevation (30–45°)
    # because rotor drag is significant; use effective LD = CL/CD here
    elev      = kite_elevation_angle(dev.CL_blade, dev.CD_blade)
    T_line    = sqrt(F_lift^2 + F_drag^2)
    F_hub     = T_line .* lift_line_direction(elev)
    return (F_hub, T_line, elev)
end

# ── Variability and sensitivity analysis ───────────────────────────────────────

"""
    tension_sensitivity(dev::LiftDevice, rho, v_wind) → dT_dv (N·s/m)

Derivative of lift line tension with respect to wind speed at the given operating point.
Units: N per (m/s).  A lower value means less sensitivity to gusts.
"""
function tension_sensitivity(dev::SingleKiteParams, rho::Float64, v_wind::Float64)
    _, T0, _ = lift_force_steady(dev, rho, v_wind)
    _, T1, _ = lift_force_steady(dev, rho, v_wind * 1.01)
    return (T1 - T0) / (v_wind * 0.01)
end

function tension_sensitivity(dev::StackedKitesParams, rho::Float64, v_wind::Float64)
    _, T0, _ = lift_force_steady(dev, rho, v_wind)
    _, T1, _ = lift_force_steady(dev, rho, v_wind * 1.01)
    return (T1 - T0) / (v_wind * 0.01)
end

function tension_sensitivity(dev::RotaryLifterParams, rho::Float64, v_wind::Float64)
    _, T0, _ = lift_force_steady(dev, rho, v_wind)
    _, T1, _ = lift_force_steady(dev, rho, v_wind * 1.01)
    return (T1 - T0) / (v_wind * 0.01)
end

"""
    tension_cv(dev::LiftDevice, rho, v_wind, turb_intensity) → Float64

Coefficient of variation (σ/μ) of lift line tension under turbulence.
Turbulence intensity I = σ_v / v_mean (typical onshore: 0.10–0.20).
Uses linear propagation: σ_T ≈ |dT/dv| × σ_v.
Returns dimensionless σ_T / T_mean.
"""
function tension_cv(dev::LiftDevice, rho::Float64, v_wind::Float64,
                    turb_intensity::Float64)
    _, T_mean, _ = lift_force_steady(dev, rho, v_wind)
    dT_dv        = tension_sensitivity(dev, rho, v_wind)
    sigma_v      = turb_intensity * v_wind
    sigma_T      = abs(dT_dv) * sigma_v
    return T_mean > 0.0 ? sigma_T / T_mean : Inf
end

"""
    tension_cv_reduction(dev_rotary::RotaryLifterParams,
                         dev_ref::SingleKiteParams,
                         rho, v_wind, turb_intensity) → Float64

Ratio of rotary lifter tension CV to single kite tension CV.
Values < 1.0 indicate reduced tension variability (better).
Analytical approximation: ratio ≈ v_wind² / (v_wind² + (ω·r_mean)²)
"""
function tension_cv_reduction(dev_rotary::RotaryLifterParams,
                               dev_ref::SingleKiteParams,
                               rho::Float64, v_wind::Float64,
                               turb_intensity::Float64 = 0.15)
    cv_rot = tension_cv(dev_rotary, rho, v_wind, turb_intensity)
    cv_ref = tension_cv(dev_ref,    rho, v_wind, turb_intensity)
    return cv_ref > 0.0 ? cv_rot / cv_ref : NaN
end

"""
    required_kite_area(dev_template::SingleKiteParams,
                       rho, v_wind, F_required) → Float64

Area (m²) of single kite needed to provide F_required (N) of lift line tension
at wind speed v_wind.
"""
function required_kite_area(dev_template::SingleKiteParams,
                             rho::Float64, v_wind::Float64,
                             F_required::Float64)
    q = 0.5 * rho * v_wind^2
    # T = q · area · √(CL² + CD²)
    T_per_m2 = q * sqrt(dev_template.CL^2 + dev_template.CD^2)
    return T_per_m2 > 0.0 ? F_required / T_per_m2 : Inf
end

# ── Hub force balance ───────────────────────────────────────────────────────────

"""
    hub_lift_required(p::SystemParams, rho, v_wind) → F_lift_N

Minimum lift line tension (N) needed to maintain hub altitude, given shaft geometry.

## Physics (corrected model — rotor disc at 60° from horizontal)

Vertical force balance at the hub node:
    F_lift · sin(θ_lift) + F_CT_vert − F_shaft_vert − W_airborne = 0
where:
    F_CT_vert   = T_thrust · sin(β)   [CT thrust acts along shaft axis, +Z component]
    F_shaft_vert = T_shaft · sin(β)   [TRPT shaft tension pulls hub toward ground, −Z]
    T_shaft ≈ T_thrust in quasi-static equilibrium → the two terms cancel.

Result: F_lift · sin(θ_lift) ≈ W_airborne  (weight only; thrust and shaft cancel)

This means the lift kite must support the airborne weight. CT thrust provides an upward
force equal in magnitude to the shaft tension that pulls the hub down: they cancel at the
hub node, leaving only gravity for the lift kite to counter.

The dynamic ODE confirms this: at 11 m/s with no lift device, the hub maintains design
elevation (hub_excursion_sweep NoLift: hub_z_mean = 14.99 m, std = 1.5 mm).

## Sizing note

For sizing the kite, call this function at the MINIMUM OPERATING WIND SPEED (e.g. 4–5 m/s,
just above cut-in), not at v_rated. At v_rated the CT thrust easily holds the hub;
the lift kite is structurally needed only at low wind during launch/landing.

A practical design point: at v = 4 m/s, W_airborne ≈ 245 N → area ≈ 8 m² for 10 kW.

Returns the weight W_airborne (N) — this is the correct net downward load on the hub.
"""
function hub_lift_required(p::SystemParams, rho::Float64, v_wind::Float64)
    # Airborne mass (rings + blades + tether)
    m_tether = p.n_lines * p.tether_length *
               (DYNEEMA_DENSITY * π * (p.tether_diameter / 2)^2)
    m_airborne = p.n_blades * p.m_blade + p.n_rings * p.m_ring + m_tether
    W_airborne = m_airborne * 9.81

    # CT thrust vertical component (upward) and shaft tension vertical component (downward)
    # cancel at the hub node in quasi-static equilibrium (T_shaft ≈ T_thrust).
    # Net vertical load = airborne weight only.
    # rho and v_wind are accepted for API compatibility but do not affect the result.
    _ = rho; _ = v_wind   # explicitly unused — retained for API stability

    return W_airborne
end

"""
    lift_margin(dev::LiftDevice, p::SystemParams, rho, v_wind) → Float64

Ratio of available lift to required lift.
Values > 1.0 indicate the kite can maintain altitude; < 1.0 means the hub descends.
"""
function lift_margin(dev::LiftDevice, p::SystemParams, rho::Float64, v_wind::Float64)
    _, T_available, elev = lift_force_steady(dev, rho, v_wind)
    F_required           = hub_lift_required(p, rho, v_wind)
    # Vertical component of lift line force
    F_vertical           = T_available * sin(deg2rad(elev))
    return F_vertical / F_required
end

# ── Scaling analysis ────────────────────────────────────────────────────────────

"""
    lift_area_vs_power(power_range_kw, rho, v_rated, dev_template::SingleKiteParams)
        → Vector of (P_kw, area_m2) tuples

Required kite area to maintain hub altitude as a function of rated power,
using the Windswept mass scaling law (m_airborne ∝ P^1.35).
Illustrates the "kite area bottleneck" at scale.
"""
function lift_area_vs_power(power_range_kw::AbstractVector,
                             rho::Float64,
                             v_rated::Float64,
                             dev_template::SingleKiteParams;
                             v_design::Float64 = 4.0)
    p0   = params_10kw()
    results = Tuple{Float64,Float64}[]
    for P_kw in power_range_kw
        p_scaled = mass_scale(p0, 10.0, P_kw)
        F_req    = hub_lift_required(p_scaled, rho, v_design)  # weight-only, size at low wind
        A_req    = required_kite_area(dev_template, rho, v_design, F_req)
        push!(results, (P_kw, A_req))
    end
    return results
end

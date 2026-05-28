# src/parameters.jl
# Physical constants, spec structs, and preset configurations for the TRPT Kite Turbine Simulator.

const DYNEEMA_DENSITY = 970.0   # kg/m³
# All numerical values derived from:
#   - "Rotary AWES Julia Simulation Framework.pdf"         (Framework PDF)
#   - "Kite Turbine Mass Scaling Analysis.pdf"              (Mass Scaling PDF)
#   - "Design Reasoning Report - General Release.pdf" §5.2  (DRR)
#   - data_collection_v3.xlsx                               (rotor geometry survey)
#   - Rotor_TRTP_Sizing_Iteration2.xlsx                     (AeroDyn BEM simulations)

# ══════════════════════════════════════════════════════════════════════════════
# Spec structs — domain-aligned groupings for SystemParams construction.
# Each spec is an immutable value type; callers that only need e.g. atmospheric
# parameters can accept an AeroSpec instead of the full SystemParams.
# ══════════════════════════════════════════════════════════════════════════════

"""
    GeometrySpec

TRPT geometry — all spatial dimensions and topology counts.
Angles in radians, lengths in metres.  n_lines, n_rings, and n_blades
are always equal in the current TRPT model (one blade and one tether line
per polygon vertex).
"""
struct GeometrySpec
    elevation_angle ::Float64  # TRPT shaft elevation angle β (rad)
    lifter_elevation::Float64  # Lifter line elevation angle (rad)
    rotor_radius    ::Float64  # Airborne ring radius R (m)
    tether_length   ::Float64  # Unstretched total TRPT length L₀ (m)
    trpt_hub_radius ::Float64  # Ring radius at the rotor end (m); r_top of taper
    trpt_rL_ratio   ::Float64  # Geometry ratio r/L per segment (dimensionless)
    n_lines         ::Int64    # Number of TRPT tether lines
    n_rings         ::Int64    # Number of polygon spacer rings
    n_blades        ::Int64    # Number of lifting blades (one per line)
end

"""
    MaterialSpec

Material and mass properties for tethers and rings.
All masses are per-unit (per ring, per blade).
"""
struct MaterialSpec
    tether_diameter ::Float64  # Tether line diameter d_t (m)
    e_modulus       ::Float64  # Young's modulus (Pa); Dyneema ≈ 100 GPa
    m_ring          ::Float64  # Mass per polygon spacer ring (kg)
    m_blade         ::Float64  # Mass per lifting blade (kg)
end

"""
    AeroSpec

Atmospheric and aerodynamic constants.
Cp is the rotor power coefficient from AeroDyn BEM (NACA4412, 3-blade).
"""
struct AeroSpec
    rho         ::Float64  # Air density (kg/m³)
    v_wind_ref  ::Float64  # Reference wind speed at h_ref (m/s)
    h_ref       ::Float64  # Reference altitude for wind profile (m)
    cp          ::Float64  # Rotor power coefficient
end

"""
    ControlSpec

Ground station drivetrain and reserved elevation-controller parameters.
The β_* and kp_elev fields are RESERVED placeholders — no elevation controller
is implemented.  The physical system uses fixed-pitch, fixed-bank blades.
"""
struct ControlSpec
    i_pto       ::Float64  # Total PTO rotational inertia (kg·m²)
    k_mppt      ::Float64  # MPPT gain (N·m·s²/rad²): τ_gen = k × ω²
    p_rated_w   ::Float64  # Rated electrical power (W)
    β_min       ::Float64  # RESERVED — minimum safe elevation angle (rad)
    β_max       ::Float64  # RESERVED — maximum safe elevation angle (rad)
    β_rate_max  ::Float64  # RESERVED — maximum elevation change rate (rad/s)
    kp_elev     ::Float64  # RESERVED — proportional gain placeholder
end

"""
    BackLineSpec

Elevation-constraint back line — a single Dyneema tether from hub attachment
point down to a fixed ground anchor.  Tension-only; goes slack when the hub
is below design elevation.
"""
struct BackLineSpec
    EA_back_line      ::Float64  # Axial stiffness (N)
    c_back_line       ::Float64  # Damping coefficient (N·s/m)
    back_anchor_fwd_x ::Float64  # Downwind offset of ground anchor (m)
    backline_payout   ::Float64  # Extra line paid out by winch (m)
end

# ══════════════════════════════════════════════════════════════════════════════
# SystemParams — flat struct (unchanged external interface).
# The spec constructor below composes one from grouped specs.
# ══════════════════════════════════════════════════════════════════════════════

"""
    SystemParams

All physical parameters for one TRPT configuration.
All fields use SI units: m, kg, Pa, rad, rad/s, N·m.

Construct from specs:
    SystemParams(geo::GeometrySpec, mat::MaterialSpec, aero::AeroSpec,
                  ctrl::ControlSpec, back::BackLineSpec)
"""
struct SystemParams
    # Atmospheric
    rho::Float64              # Air density (kg/m³), standard 1.225
    v_wind_ref::Float64       # Reference wind speed at h_ref (m/s)
    h_ref::Float64            # Reference altitude for Hellmann wind profile (m)

    # TRPT geometry — Framework PDF §3
    elevation_angle::Float64  # TRPT shaft elevation angle β (rad)
    lifter_elevation::Float64 # Lifter kite line elevation angle (rad); vertical component compensates airborne weight
    rotor_radius::Float64     # Airborne ring radius R (m)
    tether_length::Float64    # Unstretched total TRPT length L₀ (m)

    # TRPT tapered geometry
    trpt_hub_radius::Float64  # Ring radius at the rotor end of the TRPT (m); r_top of taper
    trpt_rL_ratio::Float64    # Geometry ratio r/L per segment (dimensionless).
                              # Each segment: L_i = r_i / trpt_rL_ratio
                              # DRR Grasshopper FEA: rL = 0.740741; Iteration2 sizing: 0.5

    # Tether material — Framework PDF §3
    n_lines::Int64            # Number of TRPT tether lines
    tether_diameter::Float64  # Tether line diameter d_t (m)
    e_modulus::Float64        # Young's modulus (Pa); Dyneema ≈ 100 GPa

    # Polygon spacer rings — Framework PDF §3
    n_rings::Int64            # Number of polygon spacer rings
    m_ring::Float64           # Mass per ring (kg)

    # Lifting blades/kites — Framework PDF §3
    n_blades::Int64           # Number of lifting blades
    m_blade::Float64          # Mass per blade (kg)

    # Aerodynamics
    cp::Float64               # Rotor power coefficient; AeroDyn BEM ≈ 0.22 (NACA4412, 3-blade)

    # Ground station — Mass Scaling PDF §"Drivetrain Mass and Inertia Matching"
    i_pto::Float64            # Total PTO rotational inertia (kg·m²)
    k_mppt::Float64           # MPPT gain constant k (N·m·s²/rad²): τ_gen = k × ω_ground²
    p_rated_w  ::Float64      # Rated electrical power (W). Default: 10_000.0

    # Reserved — no elevation controller implemented.
    β_min      ::Float64      # RESERVED — minimum safe elevation angle (rad)
    β_max      ::Float64      # RESERVED — maximum safe elevation angle (rad)
    β_rate_max ::Float64      # RESERVED — maximum elevation change rate (rad/s)
    kp_elev    ::Float64      # RESERVED — proportional gain placeholder

    # Back line — elevation constraint tether
    EA_back_line      ::Float64  # Axial stiffness (N). 3 mm Dyneema ≈ 700 kN
    c_back_line       ::Float64  # Damping coefficient (N·s/m). Default: 500.0
    back_anchor_fwd_x :: Float64  # Extra downwind offset of ground anchor (m). Default: 11.0

    backline_payout   ::Float64  # Extra line paid out by winch (m). Default: 0.0
end

"""
    SystemParams(geo, mat, aero, ctrl, back)

Construct a flat `SystemParams` from domain-grouped spec structs.
All existing callers that access `p.rho`, `p.elevation_angle`, etc.
continue to work — only construction changes.
"""
function SystemParams(geo::GeometrySpec, mat::MaterialSpec, aero::AeroSpec,
                       ctrl::ControlSpec, back::BackLineSpec)
    return SystemParams(
        aero.rho, aero.v_wind_ref, aero.h_ref,
        geo.elevation_angle, geo.lifter_elevation,
        geo.rotor_radius, geo.tether_length,
        geo.trpt_hub_radius, geo.trpt_rL_ratio,
        geo.n_lines, mat.tether_diameter, mat.e_modulus,
        geo.n_rings, mat.m_ring,
        geo.n_blades, mat.m_blade,
        aero.cp, ctrl.i_pto, ctrl.k_mppt, ctrl.p_rated_w,
        ctrl.β_min, ctrl.β_max, ctrl.β_rate_max, ctrl.kp_elev,
        back.EA_back_line, back.c_back_line, back.back_anchor_fwd_x,
        back.backline_payout,
    )
end

# ══════════════════════════════════════════════════════════════════════════════
# Factory functions — each returns a SystemParams.
# ══════════════════════════════════════════════════════════════════════════════

"""
    params_10kw()

10 kW prototype configuration — empirically validated from PDFs, DRR, and AeroDyn BEM.

Rated operating point (DRR; AeroDyn sizing data):
  - Rated wind speed : 11 m/s (all AeroDyn simulations in Rotor_TRTP_Sizing_Iteration2.xlsx)
  - Elevation angle  : 30° (as physically built; newer designs optimise at 20°)

Mass budget (Mass Scaling PDF §\"Static Lift Kite Mass Bottleneck\"):
  - Rotor mass total : 11 kg (3 blades × 3.667 kg each)
  - TRPT shaft mass  : ~6.6 kg  (14 rings × 0.4 kg + 5 lines × 30 m × 0.006 kg/m)
  - Total airborne   : ~17.6 kg ≈ 17 kg

Tether geometry (DRR §5.2):
  - 5 Dyneema lines, 3 mm diameter, 30 m total length
  - Torque rings every 2 m → 14 intermediate rings  ((30/2) − 1 = 14)
  - Each ring ≈ 400 g (12 mm CFRP tubes + aluminium clevis connectors)

TRPT taper geometry (DRR Grasshopper FEA, rL Geometry Ratio: 0.740741):
  - trpt_hub_radius = 2.0 m  (ring radius at rotor end; self-consistent with rL=0.74,
    tether=30m, n_seg=15 → average L_seg=2.0m, r_bottom=0.96m)
  - trpt_rL_ratio = 0.74    (r/L geometry constraint per segment)

Aerodynamics (Rotor_TRTP_Sizing_Iteration2.xlsx AeroDyn BEM, NACA4412 profile):
  - Cp ≈ 0.22 at optimal TSR ≈ 4.1–4.2 (3-blade, 20°–30° elevation)
  - Previous Framework PDF value (0.15) was a conservative proxy; AeroDyn gives ≈0.22

Ground inertia (Mass Scaling PDF §\"Drivetrain Mass and Inertia Matching\"):
  - I_wheel = 0.019 kg·m², I_gen = 0.040 kg·m² → I_pto = 0.059 kg·m²
"""
function params_10kw()::SystemParams
    geo = GeometrySpec(
        π / 6,              # elevation_angle = 30° (DRR)
        deg2rad(70.0),      # lifter_elevation = 70° (typical launch/landing)
        5.0,                # rotor_radius R (m) — Framework PDF §5.3
        30.0,               # tether_length L₀ (m) — DRR §5.2
        2.0,                # trpt_hub_radius (m) — DRR Grasshopper rL=0.74
        0.74,               # trpt_rL_ratio — DRR Grasshopper "rL Geometry Ratio: 0.740741"
        5,                  # n_lines — DRR §5.2 "5 tethers"
        14,                 # n_rings — DRR §5.2: rings every 2 m → (30/2)−1 = 14
        5,                  # n_blades — one blade per polygon vertex
    )
    mat = MaterialSpec(
        0.003,              # tether_diameter (m) — DRR §5.2: 3 mm Dyneema
        100e9,              # e_modulus (Pa) — Dyneema ~100 GPa
        0.4,                # m_ring (kg) — ~400 g per ring (DRR §5.2)
        11.0 / 3.0,         # m_blade (kg) — 3 blades totalling 11 kg
    )
    aero = AeroSpec(
        1.225,              # rho (kg/m³)
        11.0,               # v_wind_ref (m/s) — rated wind speed at h_ref
        15.0,               # h_ref (m) — hub altitude (30 × sin(30°) = 15 m)
        0.22,               # cp — AeroDyn BEM (Rotor_TRTP_Sizing_Iteration2.xlsx)
    )
    ctrl = ControlSpec(
        25.0,               # i_pto (kg·m²) — reflected low-speed shaft inertia (wheel + N²·I_gen)
        11.0,               # k_mppt (N·m·s²/rad²) — τ_gen = k × ω²
                            #   ω_opt = 4.1 × 11 / 5 = 9.02 rad/s, τ_net ≈ 889 N·m
                            #   k = 889 / 81.4 ≈ 10.9 → 11.0
        10_000.0,           # p_rated_w (W)
        deg2rad(23.0),      # β_min — RESERVED
        deg2rad(67.0),      # β_max — RESERVED
        deg2rad(1.0),       # β_rate_max — RESERVED
        5e-5,               # kp_elev — RESERVED
    )
    back = BackLineSpec(
        700_000.0,          # EA_back_line (N) — 100 GPa × π(0.003)²/4 ≈ 707 kN
        500.0,              # c_back_line (N·s/m)
        11.0,               # back_anchor_fwd_x (m) — placed downwind so the
                            # backline direction at the SKY ANCHOR design position
                            # has a small +x component, which lets the three-way
                            # knot (lift @80° + backline + cyan) balance with the
                            # cyan staying coaxial with the 30° shaft and ALL line
                            # tensions positive.  At 5 m the geometry forced
                            # T_cyan < 0 (infeasible), so the sky anchor swung up
                            # to ~80° elevation and the cyan transmitted no axial
                            # preload onto the bearing → TRPT looked slack.  See
                            # docs/plans/2026-05-12-sky-anchor-node.md.
        0.0,                # backline_payout — zero at construction
    )
    return SystemParams(geo, mat, aero, ctrl, back)
end

"""
    params_50kw()

50 kW target configuration, geometrically scaled from the 10 kW prototype.
Uses mass_scale() with the empirical 1.35 exponent from Mass Scaling PDF.
"""
function params_50kw()::SystemParams
    return mass_scale(params_10kw(), 10.0, 50.0)
end

"""
    params_v5_10kw() → SystemParams

v5-optimized 10 kW configuration with 8-line octagonal geometry.
Derived from the 168-hour DE optimisation campaign (island 11 winner,
11.470 kg shaft, FOS=1.8, n_lines=8 unanimous optimum).

Ring geometry uses the constant-L/r spacing law (ring_spacing_v4):
  r_hub = 1.60 m, r_bottom = 0.336 m, target_Lr = 2.0
  → 18 intermediate rings, 19 non-uniform segments

Key differences from the canonical 5-line pentagon params_10kw():
  - n_lines = 8 (distributes load → thinner, lighter beams)
  - n_blades = 8 (one blade per TRPT vertex)
  - r_hub = 1.60 m (vs 2.0 m canonical)
  - n_rings = 18 (from ring_spacing_v4; vs 14 canonical)
  - m_blade_each = 1.375 kg (total 11 kg across 8 blades)
"""
function params_v5_10kw()::SystemParams
    base = params_10kw()
    geo = GeometrySpec(
        base.elevation_angle, base.lifter_elevation,
        5.0,                # rotor_radius (m) — canonical; v5 BEM-derived = 5.12
        30.0,               # tether_length (m)
        1.60,               # trpt_hub_radius (m) — v5 optimum
        0.74,               # trpt_rL_ratio — retained for backward compat; not used in v5 path
        8,                  # n_lines — v5 unanimous optimum
        18,                 # n_rings — from ring_spacing_v4(r_hub=1.60, r_bot=0.336, target_Lr=2.0)
        8,                  # n_blades — one per TRPT line
    )
    mat = MaterialSpec(
        base.tether_diameter, base.e_modulus,
        0.4,                # m_ring (kg)
        11.0 / 8.0,         # m_blade (kg) — total 11 kg across 8 blades
    )
    aero = AeroSpec(base.rho, base.v_wind_ref, base.h_ref, base.cp)
    ctrl = ControlSpec(base.i_pto, base.k_mppt, base.p_rated_w,
                        base.β_min, base.β_max, base.β_rate_max, base.kp_elev)
    back = BackLineSpec(base.EA_back_line, base.c_back_line,
                         base.back_anchor_fwd_x, 0.0)
    return SystemParams(geo, mat, aero, ctrl, back)
end

function params_v5_50kw()::SystemParams
    return mass_scale(params_v5_10kw(), 10.0, 50.0)
end

"""
    params_v5_safe_10kw() → SystemParams

v5-safe 10 kW configuration: corrected power level, anti-necking ground ring,
original FOS margins (Euler≥1.8, Torsion≥1.5).  Single-island DE preview result:
18.0 kg shaft, nearly cylindrical (taper ratio 0.93), 11 rings, 8 lines.

Key differences from params_v5_10kw():
  - r_bottom = 1.49 m (vs 0.34 m) — anti-necking, prevents torsional collapse
  - target_Lr = 1.61 (vs 2.0) — shorter segments for stiffness
  - n_rings = 11 (vs 18) — fewer rings needed with wider geometry
  - Mass = 18.0 kg (vs 11.5 kg) — 57% heavier, correctly sized for 10kW
"""
function params_v5_safe_10kw()::SystemParams
    base = params_10kw()
    geo = GeometrySpec(
        base.elevation_angle, base.lifter_elevation,
        5.0,                # rotor_radius (m)
        30.0,               # tether_length (m)
        1.60,               # trpt_hub_radius (m)
        0.74,               # trpt_rL_ratio (retained)
        8,                  # n_lines
        11,                 # n_rings — from ring_spacing_v4(1.60, 1.49, 30.0, 1.61)
        8,                  # n_blades
    )
    mat = MaterialSpec(
        base.tether_diameter, base.e_modulus,
        0.4,                # m_ring (kg)
        11.0 / 8.0,         # m_blade (kg)
    )
    aero = AeroSpec(base.rho, base.v_wind_ref, base.h_ref, base.cp)
    ctrl = ControlSpec(base.i_pto, base.k_mppt, base.p_rated_w,
                        base.β_min, base.β_max, base.β_rate_max, base.kp_elev)
    back = BackLineSpec(base.EA_back_line, base.c_back_line,
                         base.back_anchor_fwd_x, 0.0)
    return SystemParams(geo, mat, aero, ctrl, back)
end

"""
    mass_scale(base, base_power_kw, target_power_kw)

Scale a SystemParams to a new rated power using:
- Aerodynamic length scaling: x = (target/base)^(1/2) for all lengths.
  Rationale: P_aero ∝ R² (swept area), so R ∝ P^(1/2). Confirmed by AeroDyn BEM data:
  4 kW R=2.8 m → 12 kW R=4.8 m ≈ (12/4)^(1/2) × 2.8 ✓
- Empirical mass exponent 1.35 (Mass Scaling PDF §\"The Empirical Mass Exponent\"):
  m_scaled = m_base × (target/base)^1.35
- PTO inertia: I ∝ m × R² → exponent = 1.35 + 2×(1/2) = 2.35
- MPPT gain: k_mppt = τ/ω² where τ ∝ P^(3/2), ω² ∝ P^(-1) → k_mppt ∝ P^(5/2)
"""
function mass_scale(base::SystemParams,
                    base_power_kw::Float64,
                    target_power_kw::Float64)::SystemParams
    power_ratio = target_power_kw / base_power_kw
    geom_scale  = power_ratio^(1/2)     # linear dimension scale: R ∝ P^(1/2)
    mass_factor = power_ratio^1.35       # empirical mass exponent

    # Decompose into specs, scale each, recompose
    geo = GeometrySpec(
        base.elevation_angle,                 # angle — does not scale
        base.lifter_elevation,                # angle — does not scale
        base.rotor_radius     * geom_scale,
        base.tether_length    * geom_scale,
        base.trpt_hub_radius  * geom_scale,
        base.trpt_rL_ratio,                   # dimensionless ratio — does not scale
        base.n_lines,                         # topology — does not scale
        base.n_rings,                         # topology — does not scale
        base.n_blades,                        # topology — does not scale
    )
    mat = MaterialSpec(
        base.tether_diameter  * geom_scale,
        base.e_modulus,                       # material property — unchanged
        base.m_ring           * mass_factor,
        base.m_blade          * mass_factor,
    )
    aero = AeroSpec(
        base.rho,                             # atmospheric — unchanged
        base.v_wind_ref,                      # reference wind — unchanged
        base.h_ref            * geom_scale,
        base.cp,                              # aerodynamic constant — unchanged
    )
    ctrl = ControlSpec(
        base.i_pto            * mass_factor * geom_scale^2,  # I ∝ m·R² → P^2.35
        base.k_mppt           * power_ratio^2.5,            # k ∝ P^(5/2)
        base.p_rated_w        * power_ratio,
        base.β_min,                            # RESERVED — does not scale
        base.β_max,                            # RESERVED — does not scale
        base.β_rate_max,                       # RESERVED — does not scale
        base.kp_elev          / power_ratio,   # RESERVED
    )
    back = BackLineSpec(
        base.EA_back_line     * geom_scale,    # stiffness scales with cross-section
        base.c_back_line      * geom_scale,    # damping scales with line length
        base.back_anchor_fwd_x * geom_scale,   # forward offset scales with geometry
        base.backline_payout,                  # payout does not scale
    )
    return SystemParams(geo, mat, aero, ctrl, back)
end

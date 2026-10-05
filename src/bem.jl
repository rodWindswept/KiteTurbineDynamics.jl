# src/bem.jl
#
# Unified BEM model for TRPT rotor sizing.
# Cp(n_lines, TSR) and CT(n_lines, TSR) for rotor sizing, expressed as the
# measured fixed-chord blade-count ratio surface on top of the committed
# AeroDyn tables.
#
# Baseline (anchor): AeroDyn v5.0.0 quasi-steady BEM tables — NACA4412,
# 3 blades, chord 0.5 m, 0° elevation — generated 2026-06-10 from the original
# MVP input files (ad_primary_MVP.inp, ad_blade_MVP.inp, ad_airfoil_Rigid.inp).
# THE COMMITTED TABLE IS 3-BLADE DATA; n_lines = 3 is the explicit baseline.
# The earlier "n_lines=5" label on this table was a mislabel — every n-scaled
# value inherited a two-blade offset (at the design point n=3 read +21% high,
# n=6 read −9% low).  Baseline Cp peak ≈ 0.309 at λ ≈ 5.2, CT plateau ≈ 0.82.
#
# Blade-count scaling: the MEASURED fixed-chord ratio surface from the regen
# family (blade-count regression, 2026-10-04/05; 96 points; series sha256
# b7196fb4c33c3f30…), rows n = 3..9, linear in λ between the family's measured
# TSRs, held at the ends:
#     Rf(n, λ) = Cp(n, chord 0.5) / Cp(3, chord 0.5)
#     Rt(n, λ) = Ct(n, chord 0.5) / Ct(3, chord 0.5)
# The surface subsumes tip loss, hub loss and induction; no closed-form law
# survives the data (rank-1 residual 39.5% in ln; per-λ exponent +1.00 → −0.62).
# It retires the old `(5/n)^0.7 × Prandtl tip-loss` / `sqrt(n/5)` placeholder.
# Rows are exact in n (no interpolation).  n_lines outside [3, 9] holds the
# nearest row — above 9 that is optimistic (the design-λ trend is monotone
# decreasing in n); a series extension is an open item.
#
# Evidence: docs/validation/2026-10-04-bladecount-n-fit.md (placeholder
# contradicted on both axes) and
# docs/validation/2026-10-05-cp-span-structure-and-resize.md (sizing re-decode;
# n=9 measured addendum).
# Ruling 2026-10-05: the sizing path moves to this surface; the ODE keeps
# `cp_at_tsr` (within a few % of the measured series at the operating points).

module BEM

# Access AeroDyn lookup tables from the parent module
import ..KiteTurbineDynamics: cp_at_tsr, ct_at_tsr

const ρ_AIR = 1.225  # kg/m³ (ISA sea-level)

# ══════════════════════════════════════════════════════════
# Measured blade-count ratio surface (fixed chord 0.5 m, regen family)
# ══════════════════════════════════════════════════════════

# TSR knots: the regen family's measured TSR values (commanded λ × 1.0488).
const _RATIO_TSR = [1.0488, 2.0976, 3.1465, 4.1953, 5.2441, 6.2929, 7.3417, 8.3905]

# Rf(n, λ) — rows n = 3 (anchor, ≡ 1.0) through n = 9, top to bottom.
const _RATIO_CP = [
    [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0],  # n = 3
    [1.333313, 1.310608, 1.216376, 1.068703, 0.933973, 0.821704, 0.625450, -0.240667],  # n = 4
    [1.666687, 1.606485, 1.356677, 1.047506, 0.825688, 0.621752, 0.190450, -1.936837],  # n = 5
    [2.000000, 1.885430, 1.418857, 0.986793, 0.705397, 0.420517, -0.386737, -3.864090],  # n = 6
    [2.333313, 2.142469, 1.429971, 0.910228, 0.584914, 0.201433, -1.061239, -5.893852],  # n = 7
    [2.666625, 2.370211, 1.410675, 0.828374, 0.468260, -0.071118, -1.786002, -7.961016],  # n = 8
    [2.999938, 2.558375, 1.371369, 0.746270, 0.356925, -0.385381, -2.533595, -10.035389],  # n = 9
]

# Rt(n, λ) — same rows and convention for CT.
const _RATIO_CT = [
    [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0],  # n = 3
    [1.333223, 1.324067, 1.295616, 1.235026, 1.175464, 1.146820, 1.127713, 1.115556],  # n = 4
    [1.666380, 1.642157, 1.561856, 1.415412, 1.305057, 1.253077, 1.218923, 1.200697],  # n = 5
    [1.999480, 1.954329, 1.791639, 1.555018, 1.404884, 1.333039, 1.290084, 1.266272],  # n = 6
    [2.332530, 2.259432, 1.988702, 1.665960, 1.484275, 1.396088, 1.347252, 1.318376],  # n = 7
    [2.665515, 2.555708, 2.157498, 1.756048, 1.548403, 1.448717, 1.394352, 1.360743],  # n = 8
    [2.998449, 2.839821, 2.301286, 1.831263, 1.600630, 1.493263, 1.433836, 1.396004],  # n = 9
]

"""
    _ratio_interp(table, n_lines, tsr) -> Float64

Interpolate a ratio row at `tsr`.  Rows are exact in `n_lines` (no
n-interpolation); `n_lines` outside 3..9 holds the nearest row.  Linear
between the measured TSR knots, held at both ends.
"""
function _ratio_interp(table::Vector{Vector{Float64}}, n_lines::Int, tsr::Float64)::Float64
    row = table[clamp(n_lines, 3, 9) - 2]
    tsr <= _RATIO_TSR[1] && return row[1]
    tsr >= _RATIO_TSR[end] && return row[end]
    for j in 1:(length(_RATIO_TSR) - 1)
        if _RATIO_TSR[j] <= tsr <= _RATIO_TSR[j + 1]
            t = (tsr - _RATIO_TSR[j]) / (_RATIO_TSR[j + 1] - _RATIO_TSR[j])
            return row[j] + t * (row[j + 1] - row[j])
        end
    end
    return row[end]
end

# ══════════════════════════════════════════════════════════
# cp_bem / ct_bem — the sizing-path coefficient reads
# ══════════════════════════════════════════════════════════

"""
    cp_bem(n_lines::Int, tsr::Float64=4.1) -> Float64

Rotor power coefficient Cp for an n-line TRPT rotor at tip speed ratio `tsr`,
from the measured fixed-chord blade-count surface (see file header).

- At n_lines = 3: returns `cp_at_tsr(tsr)` exactly — the baseline anchor (the
  pre-ruling "n_lines = 5" anchor was a mislabel and read ×1.21 at n = 3).
- The surface is λ-shaped with a sign change: at the design point (λ = 4.1)
  the fixed-chord ratio is ≈ +8% at n = 4 and ≈ −12% at n = 8, relative to
  n = 3; rows n ≥ 6 go negative at high λ (over-solidity brake) and clamp to 0.
- Sizing path only: the ODE flies `cp_at_tsr` directly (2026-10-05 ruling).
"""
function cp_bem(n_lines::Int, tsr::Float64=4.1)::Float64
    cp = cp_at_tsr(tsr) * _ratio_interp(_RATIO_CP, n_lines, tsr)
    return clamp(cp, 0.0, 16.0 / 27.0)
end

"""
    ct_bem(n_lines::Int, tsr::Float64=4.1) -> Float64

Rotor thrust coefficient CT for an n-line TRPT rotor at tip speed ratio `tsr`,
from the same measured surface convention as `cp_bem`.

- At n_lines = 3: returns `ct_at_tsr(tsr)` exactly (the baseline anchor).
- The measured fixed-chord Ct ratios rise with n at every λ (≈ 1.24 at n = 4
  to ≈ 1.87 at n = 9 at the design point).
- The 1.02 cap is kept from the previous convention; it now binds at the
  design point for n ≥ 6 (measured ratio up to ≈1.87).  Flagged as an open
  item — revisit under its own ruling if a load path consumes `ct_bem`.
- No live sizing path consumes CT yet; this is the library's CT read.
"""
function ct_bem(n_lines::Int, tsr::Float64=4.1)::Float64
    ct = ct_at_tsr(tsr) * _ratio_interp(_RATIO_CT, n_lines, tsr)
    return clamp(ct, 0.0, 1.02)  # quasi-steady BEM can exceed 1.0 at high λ
end

# ══════════════════════════════════════════════════════════
# Rotor radius for a target power — parameterised on TSR
# ══════════════════════════════════════════════════════════

"""
    rotor_radius_for_power(power_W, v_rated, n_lines; tsr=4.1) -> Float64

Compute the rotor radius (m) required to produce `power_W` at rated wind
speed `v_rated` (m/s) with `n_lines` tether lines.

P = Cp · ½ρ · πr² · v³   →   r = √(P / (Cp · ½ρ · π · v³))

The default TSR = 4.1 is the sizing-path design point.  (Corrected 2026-10-05:
it is NOT the AeroDyn Cp peak — the committed NACA4412 3-blade table peaks
at ≈0.309, λ ≈ 5.2, see `aerodynamics.jl`.)  For design-point optimisation,
a different TSR can be passed to account for off-peak operation.
"""
function rotor_radius_for_power(
    power_W::Float64, v_rated::Float64, n_lines::Int; tsr::Float64=4.1
)::Float64
    Cp = cp_bem(n_lines, tsr)
    denom = Cp * 0.5 * ρ_AIR * π * v_rated^3
    return sqrt(max(power_W / denom, 1e-8))
end

# ══════════════════════════════════════════════════════════
# Ring annulus blade span for a target power (DECISIONS [2026-08-20])
# ══════════════════════════════════════════════════════════

"""
    annulus_area(r_ring::Float64, span::Float64; bank_deg::Float64=0.0, eta_out::Float64=0.7, eta_in::Float64=0.3) -> Float64

Swept annulus area (m²) for a ring of radius `r_ring` and blade span `span`.
Follows the 70/30 ring-anchored geometry:
  r_out = r_ring + eta_out · span · cos(bank)
  r_in  = max(r_ring - eta_in · span · cos(bank), 0.0)
  A = π(r_out² - r_in²)
"""
function annulus_area(
    r_ring::Float64,
    span::Float64;
    bank_deg::Float64=0.0,
    eta_out::Float64=0.7,
    eta_in::Float64=0.3,
)::Float64
    cos_b = cosd(bank_deg)
    r_out = r_ring + eta_out * span * cos_b
    r_in = max(r_ring - eta_in * span * cos_b, 0.0)
    return π * max(r_out^2 - r_in^2, 0.0)
end

"""
    annulus_span_for_power(power_W, v_wind, r_ring, n_lines; tsr=4.1, bank_deg=0.0, eta_out=0.7, eta_in=0.3) -> Float64

Solve the exact blade span `s` (m) for a ring-anchored annulus of radius `r_ring`
to produce `power_W` at wind speed `v_wind` with `n_lines` lines.

Uses the 70/30 ring-anchored annulus model (DECISIONS [2026-08-20], references/MULTI ROTOR IDEAL MASS by PJ.txt):
  r_out = r_ring + eta_out · s · cos(bank)
  r_in  = max(r_ring - eta_in · s · cos(bank), 0.0)
  A_req = power_W / (Cp · ½ρ · v_wind³)

The positive physical root of the quadratic equation:
  (eta_out² - eta_in²)·π·s_proj² + 2π·r_ring·s_proj - A_req = 0
yields the projected span s_proj, and the actual blade span is s = s_proj / cos(bank).
"""
function annulus_span_for_power(
    power_W::Float64,
    v_wind::Float64,
    r_ring::Float64,
    n_lines::Int;
    tsr::Float64=4.1,
    bank_deg::Float64=0.0,
    eta_out::Float64=0.7,
    eta_in::Float64=0.3,
)::Float64
    Cp = cp_bem(n_lines, tsr)
    denom = Cp * 0.5 * ρ_AIR * v_wind^3
    A_req = max(power_W / max(denom, 1e-6), 1e-8)

    # Quadratic coefficients for s_proj = s * cos(bank)
    a = (eta_out^2 - eta_in^2) * π
    b = 2.0 * π * r_ring * (eta_out + eta_in)
    c = -A_req

    if abs(a) < 1e-12
        s_proj = A_req / max(b, 1e-6)
    else
        discriminant = max(b^2 - 4.0 * a * c, 0.0)
        s_proj = (-b + sqrt(discriminant)) / (2.0 * a)
    end

    cos_bank = max(cosd(bank_deg), 0.1)
    s = s_proj / cos_bank
    return max(s, 0.05)  # 5 cm minimum manufacturability span floor
end

export cp_bem, ct_bem, rotor_radius_for_power, annulus_area, annulus_span_for_power

end  # module BEM

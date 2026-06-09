# src/bem.jl
#
# Unified BEM model for TRPT rotor sizing and analysis.
# Replaces the standalone Betz-scaled Prandtl model (pre-Phase-0.1) with
# Cp(n_lines, TSR) and CT(n_lines, TSR) surfaces derived from validated
# AeroDyn BEM lookup tables.
#
# Baseline: AeroDyn BEM tables (NACA4412, 3 blades, n_lines=5, 20° elevation)
# from Rotor_TRTP_Sizing_Iteration2.xlsx, averaged across 4kW/7kW/12kW sheets.
# Baseline Cp peak ≈ 0.232 at λ ≈ 4.1, CT(4.1) ≈ 0.548.
#
# Blade-count scaling: combines Prandtl tip-loss correction with a solidity
# penalty.  More blades → less tip loss (benefit) but higher solidity →
# greater induction → lower Cp (penalty).  The solidity penalty dominates,
# so Cp(n_lines, TSR) decreases with n_lines.
#
# ⚠ PLACEHOLDER — the scaling exponents (0.7 for Cp, 0.5 for CT) are
# physically motivated but approximate.  AeroDyn BEM sweeps across
# n_lines ∈ {3,4,5,6,7,8} are needed to validate or replace these.
# The single validated data point is n_lines=5; at that point the model
# matches AeroDyn exactly.

module BEM

# Access AeroDyn lookup tables from the parent module
import ..KiteTurbineDynamics: cp_at_tsr, ct_at_tsr

const ρ_AIR = 1.225  # kg/m³ (ISA sea-level)

# ══════════════════════════════════════════════════════════
# Prandtl tip-loss factor — standard Glauert correction
# ══════════════════════════════════════════════════════════

function _prandtl_tip_loss(n_lines::Int)::Float64
    return 1.0 - exp(-n_lines / 2.0)
end

const _PRANDTL_5 = _prandtl_tip_loss(5)  # ≈ 0.9179 — cached baseline

# ══════════════════════════════════════════════════════════
# Solidity-aware Cp(n_lines, TSR) — replaces old cp_bem(n_lines)
# ══════════════════════════════════════════════════════════

"""
    cp_bem(n_lines::Int, tsr::Float64=4.1) -> Float64

Rotor power coefficient Cp for an n-line TRPT rotor at tip speed ratio `tsr`.

Uses the validated AeroDyn BEM table (NACA4412, n_lines=5) as baseline and
scales to other blade counts via a combined Prandtl + solidity correction.

- At n_lines = 5: returns `cp_at_tsr(tsr)` exactly.
- At n_lines < 5: Cp may be slightly higher (less induction penalty) but is
  capped at the Betz limit.
- At n_lines > 5: Cp decreases (more solidity → more induction).

⚠ The scaling exponents are approximate. AeroDyn BEM sweeps across blade
counts are required to validate.  See Phase 0.1 audit.
"""
function cp_bem(n_lines::Int, tsr::Float64=4.1)::Float64
    # Baseline Cp from AeroDyn table (validated at n_lines=5)
    cp5 = cp_at_tsr(tsr)
    if n_lines == 5
        return cp5
    end

    # Prandtl tip-loss ratio: f_tip(n) / f_tip(5)
    prandtl_ratio = _prandtl_tip_loss(n_lines) / _PRANDTL_5

    # Solidity penalty: more blades → higher solidity → lower Cp.
    # Cp ∝ (σ_ref / σ)^k where σ ∝ n_lines and k ≈ 0.3 from small-turbine
    # data (Duquette & Visser 2003 — higher solidity reduces Cp at low Re).
    # Combined with the inductions impact, the net exponent is higher (~0.7).
    solidity_penalty = (5.0 / n_lines)^0.7

    cp = cp5 * prandtl_ratio * solidity_penalty
    return clamp(cp, 0.0, 16.0 / 27.0)
end

# ══════════════════════════════════════════════════════════
# CT(n_lines, TSR) — new; replaces the silent BEM assumption
# ══════════════════════════════════════════════════════════

"""
    ct_bem(n_lines::Int, tsr::Float64=4.1) -> Float64

Rotor thrust coefficient CT for an n-line TRPT rotor at tip speed ratio `tsr`.

Uses the validated AeroDyn BEM table (NACA4412, n_lines=5) as baseline and
scales to other blade counts.  CT increases with blade count because more
blades increase the effective thrust area, but the rise is sub-linear due
to induction reducing the local inflow velocity.

- At n_lines = 5: returns `ct_at_tsr(tsr)` exactly.
- CT is clamped at 1.0 (momentum-theory ceiling).

⚠ The scaling exponent (0.5) is approximate.
"""
function ct_bem(n_lines::Int, tsr::Float64=4.1)::Float64
    ct5 = ct_at_tsr(tsr)
    if n_lines == 5
        return ct5
    end

    # CT scales sub-linearly with blade count: more blades = more
    # thrust-capable area, but induction reduces per-blade effectiveness.
    # sqrt scaling is a reasonable first approximation.
    ct = ct5 * sqrt(n_lines / 5.0)
    return clamp(ct, 0.0, 1.0)
end

# ══════════════════════════════════════════════════════════
# Rotor radius for a target power — now parameterised on TSR
# ══════════════════════════════════════════════════════════

"""
    rotor_radius_for_power(power_W, v_rated, n_lines; tsr=4.1) -> Float64

Compute the rotor radius (m) required to produce `power_W` at rated wind
speed `v_rated` (m/s) with `n_lines` tether lines.

P = Cp · ½ρ · πr² · v³   →   r = √(P / (Cp · ½ρ · π · v³))

The default TSR = 4.1 corresponds to the AeroDyn Cp peak for the NACA4412
3-blade baseline.  For design-point optimisation, a different TSR can be
passed to account for off-peak operation.
"""
function rotor_radius_for_power(power_W::Float64, v_rated::Float64,
                                n_lines::Int; tsr::Float64=4.1)::Float64
    Cp = cp_bem(n_lines, tsr)
    denom = Cp * 0.5 * ρ_AIR * π * v_rated^3
    return sqrt(max(power_W / denom, 1e-8))
end

export cp_bem, ct_bem, rotor_radius_for_power

end  # module BEM

# Outward-Load Structural Check — Spec

**Status:** SPEC (pre-Gate-2 Option B)
**Parent:** [Gate 2 spec v3](0006-gate2-spec.md)
**Date:** 2026-07-06

---

## Problem

When centrifugal expansion blade loads exceed inward aero force at a ring,
`F_v_total < 0` and the current evaluator clamps to 0 → ring compression
FoS reads ∞. Three failure modes are unmodeled in the outward regime:

1. **Strut tension failure** — the ring polygon struts experience tension
   (pulling outward) instead of compression. Tension can cause material yield.

2. **Blade-root bending failure** — the expansion rotor blade is a cantilever
   experiencing centrifugal bending. The root cross-section must withstand the
   distributed load along the span.

3. **Knuckle yield** — the knuckle at each ring vertex sees the net outward
   force. The knuckle-to-tether attachment can yield.

The k-refinement power peaks (260–376 rpm) and Gate 2's unconstrained optimum
both lie in this regime. Without these checks, FoS values there are fictitious.

---

## 1. Strut tension check (simplest — reuses existing geometry)

### Physics

When `F_v_total < 0`:
```
F_outward_per_vertex = -F_v_total   (N, already computed)
T_strut = F_outward_per_vertex / (2.0 * sin(π / n_lines))
σ_tension = T_strut / A              (A = strut cross-sectional area, from props.A)
FoS_tension = σ_yield / σ_tension
```

### Material

CFRP unidirectional: σ_yield_tension ≈ 600 MPa (conservative, aligned-fibre).
Different from compression buckling strength (which dominates the inward regime).

### Integration

In the per-ring loop of `_evaluate_trpt_design_impl`, when `F_v_total < 0`:
- Compute tension FoS (instead of or in addition to the clamp warning)
- Track `min_fos_tension = min(min_fos_tension, FoS_tension)`
- For rings where `F_v_total >= 0`: skip tension check (compression FoS already covers it)

### New EvalResult field

`min_fos_tension::Float64` — minimum tension FoS across all rings. `Inf` if no ring is in net-outward state.

---

## 2. Knuckle attachment yield

### Physics

The knuckle at each ring vertex transmits the net radial force to the tether line.
The check applies to the net radial force per vertex in **both signs**:
- Below the clamp threshold: compression-side, knuckle sees crushing force
- Above the clamp threshold: tension-side, knuckle sees pulling force

Applying only to clamped rings would produce a discontinuity at 191 rpm where
FoS_knuckle suddenly drops from ∞ to a finite value. The check runs on every
ring, every evaluation.

```
F_radial_per_vertex = |F_in_per_vertex_aero - F_centripetal - F_exp_per_vertex| / n_vertex_factor
FoS_knuckle = F_yield_knuckle / F_radial_per_vertex
```

where F_centripetal includes knuckle mass (already in `m_vertex`), so the net
radial force per vertex is the total force the knuckle must transmit to the tether.

### Strength constant

`F_yield_knuckle` — rated load per knuckle fitting.

**Rod (2026-07-06):** knuckles have an internal diameter that accepts the ring
tube and act as rigid joints between adjacent ring tubes. Knuckles are of
stronger construction than ring tubes — they do NOT yield before the ring
tubes yield. Therefore `FoS_knuckle ≥ FoS_tension` by construction.

The knuckle check still runs (for completeness and future designs where
knuckles may differ), but the binding constraint is strut tension FoS,
not knuckle yield.

All structural strength constants (σ_yield_tension, F_yield_knuckle, σ_yield_cfrp)
live in `src/structural_constants.jl` with source comments.

### New EvalResult field

`min_fos_knuckle::Float64` — minimum knuckle FoS. `Inf` if no ring is in net-outward.

---

## 3. Blade-root bending

### Physics

The expansion rotor blade is a cantilever attached at the ring vertex, banked
by `bank_angle_deg` toward the next ring. The bank angle decomposes centrifugal
force into two components at the blade root:

```
F_cf_total = m_blade * r_cg * ω²            (total centrifugal force, radial in ring plane)
F_cf_axial  = F_cf_total * sin(bank)        (along blade axis — root tension)
F_cf_normal = F_cf_total * cos(bank)        (normal to blade axis — root bending)
```

**Root tension:** `σ_tension = F_cf_axial / A_root`. Checked separately from
bending; typically much lower stress than bending for thin blades.

**Root bending:** the normal component acts as a distributed load along the span:
```
dF_normal(r) = dm_blade(r) * r * ω² * cos(bank)
```
where `r` ranges from `r_root` (ring radius) to `r_root + 0.7·span` (tip).

Bending moment at root:
```
M_root = ∫[r_root .. r_tip] (r - r_root) * dF_normal(r)
```

With uniform mass distribution per unit span (simplified):
```
m_per_unit = m_blade_total / span
M_root = m_per_unit * ω² * cos(bank) * [r_tip³/3 - r_root*r_tip² + 2r_root³/3]
```

**Lumped-mass approximation (Phase 1):**
```
r_cg = r_root + 0.4 * span           (approximate CG for linear taper)
M_root = m_blade_total * r_cg * ω² * cos(bank) * (r_cg - r_root)
```

**Root bending stress:**
```
I_root = (chord * t_blade³) / 12     (rectangular approximation)
σ_bending = M_root * (t_blade/2) / I_root
FoS_blade_root = σ_yield_cfrp / σ_bending
```

**Centrifugal stiffening:** neglected in Phase 1. The axial tension from `F_cf_axial`
increases the blade's effective bending stiffness (like a guitar string under
tension). This is a second-order effect that improves FoS — neglecting it is
conservative. Included in Phase 2+ blade model if margin is tight.

### Blade cross-section

Chord: `er.blade_chord` (from ExpansionRotorParams).
Thickness: t/c = 0.12 (typical NACA profile) → `t_blade = 0.12 * chord`.
Material: CFRP, σ_yield_cfrp (from `src/structural_constants.jl`).

### New EvalResult field

`min_fos_blade_root::Float64` — minimum blade-root bending FoS across all rotors. `Inf` if no expansion rotors.

---

## Integration into the evaluator

### New EvalResult fields

```julia
struct EvalResult
    # ... existing fields ...
    n_clamped_rings::Int
    max_outward_N::Float64
    # New (2026-07-06 outward-load check):
    min_fos_tension::Float64     # strut tension FoS (Inf if none)
    min_fos_knuckle::Float64     # knuckle yield FoS (Inf if none)
    min_fos_blade_root::Float64  # blade root bending FoS (Inf if none)
    min_fos_overall::Float64     # min of all FoS values
end
```

`min_fos_overall = min(min_fos, min_fos_tension, min_fos_knuckle, min_fos_blade_root)`

### Feasibility

A design is feasible when `min_fos_overall >= fos_req` AND all individual checks
pass. The `feasible` flag in EvalResult uses `min_fos_overall` instead of
`min_fos` alone.

---

## Implementation order (three commits)

### Commit 1: Strut tension + knuckle yield

- Add `min_fos_tension`, `min_fos_knuckle` to EvalResult
- Per-ring loop: when F_v_total < 0, compute tension and knuckle FoS
- Update all EvalResult construction sites
- Update feasibility check to use `min_fos_overall`
- Tests: outward=0 recovers current results; synthetic outward load exercises new path

### Commit 2: Blade-root bending

- Add `min_fos_blade_root` to EvalResult
- Compute blade-root bending for each expansion rotor
- Needs blade CG model (lumped-mass approximation)
- Tests: no expansion rotors → Inf; known ω → check magnitude is sensible

### Commit 3: Integration and regression

- Full test suite green
- FR4 (N_expansion=0 bit-identical)
- Verify: at clamp threshold (~191 rpm), tension FoS is high (struts are strong in tension)
- Verify: at 376 rpm (k-refinement peak), get real FoS numbers

---

## Validation harness

Per-check validation before committing:

1. **Hand calculation:** for one known expansion rotor at one known ω,
   compute FoS by hand and assert the evaluator matches to <1%.

2. **Regression:** ω→0 must recover current results (all forces vanish).
   mass→0 must recover current results. N_expansion=0 bit-identical.

3. **Constants:** all strength constants in `src/structural_constants.jl`
   with source comments. No guessed numbers.

## Non-goals

- Full blade FEM (distributed load, tapered cross-section, composite layup)
- Knuckle fatigue (only static yield — fatigue is a separate ticket)
- Tether attachment point stress concentration
- Dynamic blade-root loading (gusts, start/stop transients)

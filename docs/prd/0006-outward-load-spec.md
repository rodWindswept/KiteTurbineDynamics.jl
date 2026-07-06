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

The knuckle at each ring vertex transmits the net force to the tether line.
Under outward load, the knuckle sees:

```
F_knuckle = max(F_outward_per_vertex - F_centripetal_knuckle, 0)
```
where `F_centripetal_knuckle = m_knuckle * ω² * r` (the knuckle's own centrifugal
force partially offsets the outward load — the knuckle mass is already in `m_vertex`).

Simplified: the net outward force per vertex passes through the knuckle to the
tether. The knuckle is a small CFRP fitting.

```
FoS_knuckle = F_yield_knuckle / F_knuckle
```

### Material

Knuckle yield force: estimate from existing `OPT_KNUCKLE_MASS_KG` and
typical CFRP fitting strength. Conservative: 5 kN baseline, scaled by
knuckle mass. The existing knuckle mass is ~0.1 kg; a 0.1 kg CFRP fitting
can typically handle ~5 kN in tension.

### New EvalResult field

`min_fos_knuckle::Float64` — minimum knuckle FoS. `Inf` if no ring is in net-outward.

---

## 3. Blade-root bending (most involved — needs cross-section model)

### Physics

The expansion rotor blade is a cantilever beam attached at the ring vertex.
Centrifugal force is distributed along the span:

```
dF(r) = dm_blade(r) * r * ω²
```

where `dm_blade(r)` is the mass element at radius `r` from the shaft axis,
and `r` ranges from `ring_r` (root) to `ring_r + 0.7·span` (tip).

**Bending moment at root:**
```
M_root = ∫[r_root .. r_tip] (r - r_root) * dm_blade(r) * r * ω²
```

With uniform mass distribution per unit span (simplified):
```
m_per_unit = m_blade_total / span
M_root = m_per_unit * ω² * ∫[r_root..r_tip] (r - r_root) * r * dr
       = m_per_unit * ω² * [r_tip³/3 - r_root*r_tip² + 2r_root³/3]
```

**Root bending stress:**
```
I_root = (chord * t_blade³) / 12     (rectangular approximation, chord × thickness)
σ_bending = M_root * (t_blade/2) / I_root
FoS_blade = σ_yield / σ_bending
```

### Blade cross-section

The expansion rotor blade has chord ≈ `er.blade_chord` (from ExpansionRotorParams).
Thickness: estimated from typical NACA profile t/c ≈ 0.12 → `t_blade = 0.12 * chord`.
Material: CFRP, σ_yield ≈ 600 MPa.

### Simplification

For a Phase 1 implementation, approximate with a lumped-mass model:
- Blade CG at r_cg = r_root + 0.4 * span (approximate CG for linear taper)
- Bending moment: M = m_blade_total * r_cg * ω² * (r_cg - r_root) / n_blades
- Stress: σ = M / (blade_chord * t_blade² / 6)

This gives a conservative estimate (lumped mass at CG produces higher root moment
than the distributed load). Good enough to catch grossly under-designed blades.

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

## Expected consequences

1. **Strut tension FoS will be high** — CFRP struts in tension are much stronger
   than in compression (buckling). Expect FoS_tension >> FoS_compression.

2. **Knuckle FoS may be limiting** — the knuckle is a small fitting. If F_yield
   is conservatively 5 kN and F_outward is ~3-8 kN per vertex, FoS_knuckle
   could drop to 0.6-1.6 at high ω. This may be the real constraint.

3. **Blade-root bending will scale with ω²** — at 376 rpm vs 191 rpm, stress is
   ~4× higher. The blade chord and thickness were sized for aero, not centrifugal.

4. **Minimum FoS will likely shift** from compression-dominated (low ω) to
   knuckle/blade-dominated (high ω). The design envelope shape won't be
   monotone — there may be a mid-ω sweet spot.

---

## Non-goals

- Full blade FEM (distributed load, tapered cross-section, composite layup)
- Knuckle fatigue (only static yield — fatigue is a separate ticket)
- Tether attachment point stress concentration
- Dynamic blade-root loading (gusts, start/stop transients)

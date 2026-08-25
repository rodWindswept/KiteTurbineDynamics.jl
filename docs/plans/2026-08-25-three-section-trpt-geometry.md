# Three-Section TRPT Geometry (cylinder–cone–cylinder) — plan

**Status:** draft for review.  **Date:** 2026-08-25.

## Objective

Rework `ring_spacing_v5` into the field-tested **three-section** radius profile —
harvest cylinder (full radius at rotor rings) → steep cone (transition) →
transmission cylinder (small radius) — so the DE can trade line drag against
ring count, mass, and transition compression on a validated foundation.

## Governing constraint — EXTEND, never REPLACE

The following already-observed-and-accounted physics is **untouched** by this work:

1. **Twist → tension** (`rope_forces.jl`): chord elongation from the inter-ring
   twist Δα and the taper Δr, `T = max(0, EA·(chord−L₀)/L₀ + c_damp·v)`.
2. **Twist → torque** (`rope_forces.jl` C1 + `initialization.jl` bisection):
   the tangential component of line tension → per-segment torque, τ_sat clamp,
   and the aero-injection twist profile (`τ_target = −τ_b − τ_exp`).
3. **Twist → ring compression** (`structural_safety.jl`): `F_inward` accumulates
   `T·|dot(−dir, r̂)|` from every attached line (the twist is carried through the
   line-direction term), `N_comp = F_v/(2·tan(π/n))`, `P_crit = π²·E·I/L_poly²`.
4. **Mass laws**: span³ blade mass, ring beam mass, knuckle floor.

The four new terms below are **added** to the scoring/FoS, never substituted for
the above.  If any new term would *change* an existing quantity, it is rejected
and re-expressed as an additive margin/factor instead.

## Resolved literature (2026-08-25) — the two sign-sensitive terms are closed

The "literature-check-first" gate on the hoop sign and the transition compression
is now **resolved**.  Source extracts are committed under `docs/validation/`
(`wacker-frame-force-extract.md`, `tulloch-hoop-compression-extract.md`, plus the
full `wacker-thesis-extract.txt` / `tulloch-thesis-extract.txt`).

**Wacker MSc §4.2.4 — closed form (signed):**
- Radial attachment angle `ϕ = tan⁻¹((cos δ·R1 − R2)/Ls)`, R1 = upper
  (rotor-side), R2 = lower.  Cylinder → ϕ = 0 → zero frame compression; cone
  shrinking downward → ϕ > 0 → **compression**; expanding downward → ϕ < 0 →
  **net tension/expansion**.
- Frame force `Fft = Σ (T_i/2)·tan(ϕ)·tan(φ/2)`, `tan(φ/2) = cot(π/nf)` — the
  kink multiplier (zero for cylinder, grows with the radius step).  KTD's
  `N_comp = F_v/(2·tan(π/n))` is the same polygon resolution; Wacker adds the
  signed ϕ that KTD's `abs(dot(−dir, r̂))` discards.
- Section mass eq 4.13/4.14 sizes each frame's cross-section from its local
  compression (σ_comp,f, SF=5).  Limits: material strength only (no buckling),
  centrifugal neglected (opposes compression), frames+tethers ≈ 2% of mass.

**Tulloch PhD — qualitative + field anchor:**
- Rotor ring **net-expanded** (wing bank/anhedral + centrifugal → tension);
  cone rings **net-compressed** ("the rings… resist this compression force").
- **22° cone angle** chosen "to avoid any abrupt changes in diameter".
- Ring compression is **failure mode 3**; TRPT-5 lower-section radius **0.35 m**.
- Proposed drag-optimised design: *"the TRPT has a constant radius along its
  length"* at a **minimum** radius — i.e. a **small-radius transmission cylinder**,
  NOT a full-radius harvest cylinder.

**Geometry correction this implies:** the low-drag cylinder is the *small*
transmission cylinder (~0.35 m), not a full-`r_hub` cylinder.  The three-section
profile is therefore rotor ring (r_hub, net-expanded) → steep 22°-bounded cone →
small-radius transmission cylinder.

## New factors to formalise (additive)

| Factor | Physics | Proposed form |
|---|---|---|
| **Transition kink compression** | At a radius step, the ring carries the vector sum of the axial line and the sloped line; asymmetric → up to n× the symmetric estimate | per-ring compression **multiplier** `κ_trans = f((r_b−r_a)/L)` applied as a margin on `N_comp` at transition rings only |
| **Hoop sign (compression vs expansion)** | Cone small-end can be in net outward hoop tension, not compression | per-ring **sign** of the net radial force; a signed term, not `abs()` — verify against our thin-ring/hoop literature before coding |
| **Ring-count mass pricing** | Small radius forces shorter `L = target_Lr·r` → more rings/metre | count intermediate rings per section and price `m_ring·n_rings + tether + knuckles` explicitly in the airborne mass |
| **Lowest-rotor margin** | Shrinking below the lowest rotor concentrates transition + torsional + blade load on that ring | dedicated Do/compression margin on the lowest rotor ring |

The first two are **literature-checks first**: confirm whether our own TRPT /
thin-ring work already states the hoop sign and the transition compression law.
If it does, cite it; if it does not, mark it "to formalise" and gate the DE from
searching that corner until it is.

## Geometry

```
   ┌──────────────┐ ← hub rotor           ┐
   │  harvest     │ ← rotor 2             │ full radius (r_hub) AT rotor rings only
   │  cylinder    │                       │
   ├──────────────┤ ← lowest rotor        ┘
   │  steep cone  │  bounded slope: Δr/L ≤ (Daisy slope)
   ├──────────────┤ ← transition ring
   │ transmission │  small radius cylinder, priced by ring count
   │  cylinder    │
   └──────────────┘ ← ground
```

- Harvest section: full radius at **rotor rings** (local), not across the whole
  rotor-to-rotor span — this is what cuts the 404 W/segment drag.
- Steep cone: **bounded slope** (Δr per segment capped), pinned to the Daisy's
  field-tested cone slope + ring density.
- Transmission cylinder: radius a free variable, but its ring count and mass are
  priced (factor 3), so the DE cannot "minimise radius" without paying.

## Daisy reference

The field machine's steep-cone → transmission-cylinder transition is the
**calibration anchor**: its cone slope, ring density, and Do profile are the
validated numbers this profile reproduces by default.  New transitions must not
be steeper than the Daisy's unless the hoop-sign and transition-compression
terms are formalised first.

## Sequence

1. ~~Literature/self-check on hoop sign + transition compression~~ — **DONE**
   (Wacker §4.2.4 closed form + Tulloch confirmation; see "Resolved literature").
2. Additive terms in `structural_safety.jl` / scoring (signed ϕ, ring-count mass).
3. Rework `ring_spacing_v5` → three-section: rotor → 22°-bounded cone → small cylinder.
4. Re-derive drag / FoS / power / mass for the 2-rotor seed.
5. A/B vs the current 2-section cylinder+cone and the plain cone.

## Out of scope (do not do)

- Replacing the `F_inward`→`N_comp`→`P_crit` chain.
- Replacing the twist→tension or twist→torque models.
- Changing the span³ mass law or the knuckle floor.

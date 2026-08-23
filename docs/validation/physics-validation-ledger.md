# Physics Validation Ledger — what we trust, what is open (2026-08-22)

**Purpose:** one place that maps every load-bearing physics claim in the
simulator to its source and its validation status — so no number is quoted
without knowing why we believe it.  Living document; update it whenever a
claim is validated, corrected, or retired.  Companion to
`docs/agents/instrument-trust-log.md` (faults) and
`docs/validation/model-admissibility.md` (launch gates).

**Status key:** VALIDATED (measured anchor or closed loop against it) ·
SUPPORTED (trusted source, e.g. AeroDyn/thesis, not yet closed-loop) ·
OPEN (no trusted source yet) · SUPERSEDED (wrong, replaced).

---

## A. Measured anchors (the trustworthy sources)

| # | Claim | Value | Source | Status |
|---|-------|-------|--------|--------|
| A1 | Daisy rigid-rotor geometry | ring 1.52 m, tips 1.22/2.22 m (70/30), annulus 10.8≈11.2 m², solidity 7.5%, NACA 4412 | Tulloch PhD Table 3.1 (config 8) + Dec-2019 blog | VALIDATED (annulus matches the blog's 11.2 m²) |
| A2 | Daisy blade mass | 420 g per blade (foam + shrink skin + 2 carbon rods + 3D fuselage) | Rod, 2026-08-20/22 (thesis Fig 3.6) | VALIDATED (measured; same wing on 3-blade and 6-blade) |
| A3 | Daisy power records | <2 kg at >1.5 kW @ 10 m/s (3-blade, AWEC 2019); 624 W / 146 rpm / 6-blade (Dec-2019); peak 1400 W (2018-12-13 SRM) | AWEC 2019 + blog + SRM logs | VALIDATED (power; wind absent on some days) |
| A4 | System Cp band | 0.15–0.18 | thesis (config 8 0.15, optimised 0.18) + F9 calibration + spring-disc Cp_max 0.166 — three independent derivations agree | VALIDATED (model 234 W vs measured 223±79 W @ 6.25 m/s) |
| A5 | k_mppt Daisy operating point | 624 W @ 146 rpm → τ = P/ω = 40.8 N·m → k = 0.175 | measured | VALIDATED |
| A6 | Lift constant-tension regime | mass-aware: T = 1.5·m_airborne·g/sin(70°), flat vs wind | Rod 2026-08-19 (const-tension, modulated-lifter) | SUPPORTED (design decision; verified in-model T_in ≡ T_ref 0.00%) |

## B. Physics claims validated IN-MODEL this week (closed loop)

| # | Claim | Evidence | Status |
|---|-------|----------|--------|
| B1 | Unified blade-mass law m = m_ref·λ³ | measured 420 g anchor; test_blade_mass_law (15 assertions); seed m_airborne 17.12 kg decomposes exactly | VALIDATED (internal consistency) |
| B2 | Main rotor is modelled ONCE (no expansion double-model) | bisection: pure-main build sustains (ω→14.2), canonical-with-hub-entry died (ω→−0.2) — identical aero formula both ways | VALIDATED (fix cc92a6b) |
| B3 | Honest window measures running power | P_mean ≈ P_end at every k in the 40 s-window sweep; the old 20 s flattery is gone | VALIDATED |
| B4 | 60 m² seed sustains ~8–9 kW at k=2.24 | honest sweep + smoke (8.00 kW, FoS 36, tip 73 m/s) | VALIDATED (in-model) |
| B5 | ζ=0.05 rope damping has no reverse-torque bias | 2026-08-12 fault ledger + current traces | VALIDATED |

## C. Supported by trusted sources (not yet closed-loop)

| # | Claim | Source | Open question | Status |
|---|-------|--------|---------------|--------|
| C1 | BEM Cp/CT tables (NACA 4412, λ 0–8) | AeroDyn v5.0.0 quasi-steady, 0° elevation | CT(λ) rises monotonically to ~1.01 then clamps — real rotors peak earlier; validate vs high-thrust AeroDyn runs | SUPPORTED (AeroDyn) / CT(λ>6) OPEN |
| C2 | Cp scaling to other blade counts | Prandtl tip-loss + solidity penalty (k≈0.7 Cp, 0.5 CT) | exponents FLAGGED approximate in bem.jl — need AeroDyn sweeps n_lines 3–8 | SUPPORTED / OPEN |
| C3 | cp falloff / drag brake past λ≈9.61 | derived from the blade's own table (2026-08-14) | none — gate 4 active | SUPPORTED |
| C4 | Elevation projection cos² (thrust) / cos^2.65 (power) | AeroDyn sweep at elevation | double-count risk if the table already includes elevation — reconcile | OPEN |
| C5 | Tulloch torsional-collapse criterion δα* | thesis | Daisy scores tors≈0.22 while flying fine — threshold, not physics (gate 13, small-scale) | SUPPORTED / small-scale threshold OPEN |
| C6 | Dyneema SK99 rope break ε=3.5% | SK99 datasheet | — | SUPPORTED |
| C7 | Mass exponent P^1.35 (rung scaling) | "Mass Scaling PDF" | underdetermined from one point; field tests measure | SUPPORTED / OPEN |

## D. Open / unanchored (do NOT quote externally)

| # | Item | Why it matters | Action |
|---|------|----------------|--------|
| D1 | `lin_damp = 0.05` (orbital rope damper) | high-sensitivity knob, never hardware-calibrated | dt-paired damping sweep (queued gate, trust-log) |
| D2 | `i_pto = 0.3 kg·m²` placeholder (Daisy) | drivetrain inertia in settle/ODE | measure or derive from April-29 rig gearing |
| D3 | mass exponent for φ (kg/kW) | φ ≈ 1.3 kg/kW at Daisy; 5 kW target band | field tests |
| D4 | brake-torque cap law (linear vs quadratic) | 2× discrepancy at 5 kW; 9× under-clamp at 300 W vs measured | proposal written (2026-08-22-physics-convention-fixes.md) |
| D5 | ring numbering docs (code ground=1, docs hub=1) | audit confusion | convention-fix proposal |
| D6 | P_kw sign-masking in sim_frame | reversed ring reads positive | convention-fix proposal |
| D7 | ODE-inertia knuckles | DE score counts them, ODE inertia does not | flagged follow-on (mass-law proposal) |

## E. Retired claims (SUPERSEDED — do not resurrect)

| # | Claim | Why retired |
|---|-------|-------------|
| E1 | "5 kW seed is under-rotored (needs ~17 m²)" | was the hub double-model brake; fixed machine sustains 8–9 kW on 60 m² |
| E2 | "true equilibrium 3.15 kW at k=5.39" (08-21 gate trace) | same brake artifact |
| E3 | "knee at k≈4, k<4 rejects" (pre-fix sweep) | measured on the wrong-length machine + broken hub model |
| E4 | "m_blade = 210 g (Gate 1c renormalisation)" | 420 g measured anchor restored; 6-blade = 2.52 kg/ring |
| E5 | "18.8 m machines" (2026-08-21 era) | actually 34.3 m (params_at_length double-scaling); fixed |
| E6 | CFRP expansion blade law (0.3+0.1·tip)·λ³ | wrong for rigid foam (3.4× under vs measured at λ=1) |
| E7 | **"6.76 kg 5 kW winner" (completed 2026-08-22 campaign)** | blade mass priced m_ref·λ³ while span = 0.75·r_rotor·λ (r_rotor BEM-sized): spans 1.24-1.71 m priced at λ³ = 15.4× under the span³ truth. Winners VOID; campaign re-runs on the span³ law (DECISIONS [2026-08-22]) |

---

## How a claim gets VALIDATED here

1. Measured anchor exists (A-table) and the model reproduces it within a
   stated band (F9: 234 W vs 223±79 W, 5% — the model).
2. Or: the claim is a model-internal consistency law with a passing
   acceptance test (B-table) — stated as "validated (internal)".
3. Anything without either stays SUPPORTED or OPEN.  No external quote
   without the ledger row.

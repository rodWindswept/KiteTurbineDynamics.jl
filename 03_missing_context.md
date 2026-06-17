# Missing Context List — KiteTurbineDynamics.jl

**Generated:** 2026-06-16
**Status:** Open — gaps surfaced for review

This document identifies what information is missing from the repository that an agent or new contributor would need to fully understand, reproduce, or extend the work. "Missing" means: referenced but absent, mentioned in comments but never defined, assumed but not documented, or needed for validation but not present.

---

## M1: AeroDyn Input Files Not In Repo

**What's missing:** The AeroDyn v5.0.0 input files that generated the BEM lookup tables in `src/aerodynamics.jl`:
- `ad_primary_MVP.inp`
- `ad_blade_MVP.inp`
- `ad_airfoil_Rigid.inp` (NACA4412, Re=250k, 147 pts)

**Referenced by:**
- `src/bem.jl` — "Baseline: AeroDyn v5.0.0 quasi-steady BEM tables... generated 2026-06-10 from the original MVP input files"
- `awe-knowledge` skill — references these files as located on the rod machine at `~/.../10kW Design/MVP working folder/Ollie/Rotor/AeroDyn/`

**Impact:** Cannot regenerate BEM tables, validate the solidity exponent, or run blade-count sweeps without these files. The solidity model in `bem.jl` is labeled PLACEHOLDER and cannot be validated.

**Location if found:** Rod machine (not accessible from this session). Attempted to find on external drive — found only corrupted 45-byte Qsync stubs.

---

## M2: Campaign Design Vectors Not Saved

**What's missing:** The full 11-DoF design vector for every evaluation in the DE campaign. Only the final best design is saved as JSON.

**What IS saved:**
- `scripts/results/v6_2_campaign_50kw/convergence_history.csv` — (island, iteration, mass_kg) for 600,000 evaluations
- `scripts/results/v6_2_campaign_50kw/best_design.json` — final best design parameters only

**Impact:** Cannot:
- Reconstruct the optimization landscape panels (n_lines vs mass, density_profile vs mass) from actual data
- Analyze which parameters the DE explored before converging
- Identify alternative near-optimal designs at different n_lines values
- The d4 diagram (Panel 2) uses synthetic data rather than actual campaign data for n_lines sensitivity

**Recommendation:** Modify `run_v6_campaign.jl` to periodically save the best design vector per island, or save the full population every N iterations.

---

## M3: Solidity Exponent Validation Data

**What's missing:** AeroDyn BEM sweep results at multiple blade counts (n_blades ∈ {3,4,5,6,7,8,10,12}) to validate or replace the placeholder solidity exponent k=0.7.

**Referenced by:**
- `src/bem.jl` line 75: `solidity_penalty = (5.0 / n_lines)^0.7`
- Comment: "⚠ PLACEHOLDER — the scaling exponents (0.7 for Cp, 0.5 for CT) are physically motivated but approximate"
- `docs/case-notes/2026-06-16-solidity-exponent-sensitivity.md` — sensitivity analysis showing n=12 result depends on k

**Impact:** The corrected n=12 optimum at 74.2 kg is sensitive to this exponent. If true k=0.5, Cp penalty is 30% instead of 41%, which would strengthen the n=12 result. If true k=0.9, Cp penalty is 51%, which might shift the optimum to n=8–10.

**Recommendation:** Priority task — run AeroDyn BEM sweeps at blade counts when input files are accessible.

---

## M4: Bank Angle Dynamic Validation

**What's missing:** Dynamic ODE simulation of the pitch depower manoeuvre with expansion rotors at 45° bank angle.

**Referenced by:**
- `docs/awes-forum-diagrams/awes-forum-v62-report.md` §5 — "Dynamic simulation of pitch depower with expansion rotors — a multi-body ODE transient to confirm whether back-winding actually occurs at 45° bank"
- Diagram d5 — "Dynamic ODE validation needed before final bank angle selection"

**Impact:** The 45° bank angle is at the search bound. The DE optimizer cannot evaluate this transient condition. Without dynamic validation, the optimum bank angle is unknown and the 45° result is an optimizer artefact.

---

## M5: Expansion Rotor Blade Airfoil Data

**What's missing:** The airfoil polar data for the expansion rotor blades. The expansion rotor model uses:
- `CL_blade=1.0` — assumed lift coefficient
- `CD0_blade=0.02` — assumed zero-lift drag
- `k_induced=0.05` — assumed induced drag factor

These are hardcoded in `src/objective_v6.jl` lines 107–109 with no documented source.

**Impact:** Expansion rotor thrust and radial force calculations depend on these values. A 20% error in CL would directly scale the expansion rotor benefit.

---

## M6: Knuckle Mass Calibration Data

**What's missing:** Experimental or manufacturing data to calibrate the knuckle mass model constants:
- `KNUCKLE_L_CLAMP_FACTOR = 1.0` — beam engagement length factor
- `KNUCKLE_T_WALL_FACTOR = 1.0` — knuckle wall thickness relative to beam

**Referenced by:** `src/trpt_optimization.jl` lines 40–42

**Impact:** The derived knuckle mass (~0.10 kg for 95 mm beam at n=12) is physically-motivated but uncalibrated. If the clamp factor should be 0.5 (weight-optimised patterning more aggressive than modeled), knuckle mass drops to ~0.05 kg. If it should be 2.0 (conservative), knuckle mass rises to ~0.20 kg. The 74.2 kg total mass includes ~10.8 kg of knuckle mass — a factor-of-2 uncertainty in knuckle mass is ~5 kg uncertainty in total mass.

**Recommendation:** Obtain reference data: weight of a manufactured CFRP knuckle cuff for a known beam diameter. Calibrate the clamp factor.

---

## M7: PCA-2 Rotor Data Provenance

**What's missing:** Confirmation that the PCA-2 empirical rotor data in `src/lift_kite.jl` matches the NASA TM 20080022367 source. The code duplicates PCA-2 data from `CoaxialAutogyroStacking.jl`, but the axes convention and angle definitions may differ between the two codebases.

**Referenced by:**
- `src/lift_kite.jl` — three lift device models, including PCA-2
- `awe-knowledge` skill — "PCA-2 axes convention unverified" (Gap #9 in CoaxialStacking audit)
- `docs/audit-literature-crosscheck.md` — KTD.jl Gap #4

**Impact:** If the axes convention differs between the coaxial and KTD codebases, the lift kite model may be using incorrect angles. The prior audit flagged this as HIGH severity if wrong.

---

## M8: Tether Drag CD=1.0 Calibration

**What's missing:** Validation of the tether drag coefficient CD=1.0 used in `src/aerodynamics.jl`. The prior audit (June 8, Gap #8) notes this as "Low-Med — Adequate" but the value is assumed without documented source.

**Referenced by:**
- `src/aerodynamics.jl` — tether drag model
- `docs/audit-literature-crosscheck.md` — KTD.jl Gap #8

**Impact:** Tether drag affects line tension distribution, which feeds into the DLF and ultimately beam compression. A 20% error in CD would shift all design loads proportionally.

---

## M9: TRPT Ring Scalability Report

**What's missing:** The file `TRPT_Ring_Scalability_Report.docx` exists but its content has not been extracted to markdown or summarized. It's referenced by `src/structural_safety.jl` (line 7) as the source of the polygon-vs-hoop Euler comparison.

**Impact:** Key design assumptions (polygon segment Euler buckling vs continuous ring hoop Euler, 5–10× difference) are documented only in a binary .docx file that is not AI-navigable.

**Recommendation:** Extract key findings to a markdown summary in `docs/`.

---

## M10: Test Coverage Gaps

**What's missing:** The 16 orphan test files at repo root (`test_furl_state.jl`, `test_twist_shift3.jl`, etc.) are not wired into `test/runtests.jl`. Their purpose and pass/fail status are unknown.

Additionally, the expansion rotor module has tests (`test_expansion_rotor.jl`, `test_expansion_stack.jl`) but the knuckle mass model added this session has no dedicated test. The `knuckle_mass_at_ring()` function is exercised only indirectly through `test_ring_spacing_v4.jl` and `test_trpt_axial_profiles.jl`.

**Impact:** Unknown whether orphan tests pass. No direct test of the new knuckle mass derivation.

---

## Summary Table

| ID | Missing Item | Impact | Priority |
|----|-------------|--------|----------|
| M1 | AeroDyn input files | Cannot validate solidity exponent | HIGH |
| M2 | Campaign design vectors | Cannot reconstruct parameter sensitivity from data | MEDIUM |
| M3 | Solidity exponent validation data | n=12 optimum uncertain | HIGH |
| M4 | Bank angle dynamic validation | 45° bank angle unvalidated | MEDIUM |
| M5 | Expansion rotor airfoil data | Hardcoded CL/CD assumptions | MEDIUM |
| M6 | Knuckle mass calibration | ±5 kg uncertainty in total mass | MEDIUM |
| M7 | PCA-2 data provenance | Potential axes convention error | HIGH |
| M8 | Tether drag CD calibration | Scaling uncertainty in design loads | LOW |
| M9 | Ring scalability report extraction | Key assumption in binary .docx | LOW |
| M10 | Test coverage gaps | Orphan tests, no knuckle mass test | LOW |

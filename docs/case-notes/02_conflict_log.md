# Conflict Log — KiteTurbineDynamics.jl

**Generated:** 2026-06-16
**Status:** Open — conflicts surfaced for human review, NOT resolved

This document identifies disagreements between files in the repository. Conflicts are surfaced as-found; no attempt is made to determine which version is "correct." That decision belongs to the project owner.

---

## C1: TRPT Mass — 58 kg vs 74 kg

**Files involved:**
- `TRPT_AWE_Forum_Report.docx` through `TRPT_AWE_Forum_Report_v4.docx` — claim 58 kg at n=3 (triangle rings)
- `docs/TRPT_AWE_Forum_Report_v4.md` — markdown version, also 58 kg
- `docs/awes-forum-diagrams/awes-forum-v62-report.md` — corrected report, claims 74 kg at n=12 (dodecagon)

**Nature of conflict:** The 58 kg number was produced by a model with two known errors (tan instead of sin for polygon resolution, free-floating knuckle mass). The 74 kg number was produced after correcting both errors and re-running the campaign. Both numbers exist in the repo simultaneously, and a reader encountering either report in isolation would not know the other exists or which is authoritative.

**Why it matters:** If someone cites the 58 kg number from a .docx report without knowing about the corrections, they're citing a result known to be physically incorrect.

**Recommendation:** Mark all pre-correction reports as superseded with a reference to the corrected report. Do not delete them — they document the discovery process.

---

## C2: Polygon Optimum — n=3 vs n=12

**Files involved:**
- `docs/awes-forum-diagrams/diagram1-polygon-v4.tex` (v3, current) — compares n=8 to n=12, claims dodecagon wins
- `docs/awes-forum-diagrams/diagram1-polygon-v4.aux` — LaTeX auxiliary from compilation
- Old diagram sources in git history — compared n=8 to n=3, claimed triangle wins
- `PLAN.md` — Phase 2.5 text may still reference n=3 results
- `docs/v6-campaign-analysis-20260615.md` — references the old campaign

**Nature of conflict:** The conclusion "triangle rings are the TRPT global optimum" (from the old report §7) directly contradicts "12 thin beams beat 8 thick beams" (from the corrected report). The old conclusion was based on erroneous physics; the new conclusion is based on corrected physics but with a placeholder solidity model.

**Why it matters:** The design recommendation flips completely between the two analyses. A reader who only sees one report would make opposite design decisions.

**Recommendation:** Audit PLAN.md and campaign analysis documents for stale n=3 references. Add a prominent note at the top of old reports linking to the corrected analysis.

---

## C3: AWES Forum Report — Two Canonical Locations

**Files involved:**
- `docs/awes-forum-diagrams/awes-forum-v62-report.md` — content matches the final rewrite
- `docs/awes-forum-v62-report.md` — also exists; may be the old version

**Nature of conflict:** The same report exists in two locations. If one is updated and the other isn't, they will diverge. Currently unclear which is the "source of truth."

**Recommendation:** Choose one canonical location. Delete or symlink the other. The `docs/awes-forum-diagrams/` path makes more sense since it's co-located with the diagrams.

---

## C4: Knuckle Mass — Three Different Values

**Files involved:**
- `src/trpt_optimization.jl` — `knuckle_mass_at_ring()` function derives mass from beam geometry (NEW, this session)
- `src/economics.jl` line 110 — `knuckle_mass_each = 0.015` (hardcoded, uses old model)
- `src/spacer_ring_design.jl` line 245 — `knuckle_mass_kg = 0.050` (hardcoded, different old model)
- `src/trpt_optimization.jl` line 25 — `OPT_KNUCKLE_MASS_KG = 0.050` (constant, legacy, still defined)

**Nature of conflict:** Three different knuckle mass values exist in the codebase: 0.015 kg (economics), 0.050 kg (legacy constant, spacer ring), and geometry-derived (~0.10 kg for 95 mm beam at n=12). The structural model now ignores the hardcoded values and derives knuckle mass from beam geometry, but `economics.jl` and `spacer_ring_design.jl` still use their own values.

**Why it matters:** Cost estimates in `economics.jl` will disagree with structural mass from `trpt_optimization.jl`. The 0.050 kg value in `spacer_ring_design.jl` is 5× the old free parameter lower bound and 2× the economics value — these were never reconciled.

**Recommendation:** Update `economics.jl` to use the same knuckle mass model as the structural evaluator, or at minimum document the discrepancy. Deprecate or remove `OPT_KNUCKLE_MASS_KG`.

---

## C5: BEM Models — Sizing vs Dynamics

**Files involved:**
- `src/bem.jl` — BEM module with solidity scaling, used for rotor sizing in optimization
- `src/aerodynamics.jl` — BEM lookup tables, used for ODE dynamics
- `src/ring_forces.jl` — uses `cp_at_tsr()`/`ct_at_tsr()` from aerodynamics tables

**Nature of conflict:** The sizing BEM (`bem.jl`) applies a solidity correction Cp ∝ (5/n)^0.7 to account for blade count. The dynamics BEM tables (`aerodynamics.jl`) are generated from AeroDyn at a fixed blade count and do not scale with n_lines. This means the rotor is sized with one Cp model but simulated with another. Flagged as Gap #1 in the June 8 literature audit — still open.

**Why it matters:** The optimizer sizes the rotor assuming a Cp that includes solidity effects, but the ODE simulation uses Cp tables generated at a fixed blade count. The two models can disagree on available power by 10–40% depending on n_lines.

**Recommendation:** Either regenerate BEM tables at each n_lines value, or document the discrepancy as a known conservatism in the dynamics model.

---

## C6: Campaign Result Directories — Multiple "Best" Designs

**Files involved:**
- `scripts/results/v6_2_campaign_50kw/best_design.json` — n=12, 74.17 kg (corrected, this session)
- `scripts/results/v6_campaign_50kw/best_design.json` — n=8, 179 kg (pre-widened bounds)
- `scripts/results/v6_campaign_50kw_old/best_design.json` — older run
- `scripts/results/v6_campaign_50kw_stale/best_design.json` — explicitly marked stale
- `scripts/results/v6_campaign_50kw_v2_stale/best_design.json` — another stale variant

**Nature of conflict:** Five different "best designs" exist for the 50 kW case, each from a different model version or campaign run. A reader who doesn't understand the directory naming convention could cite any of them.

**Why it matters:** The mass numbers range from 58 kg to 179 kg depending on which directory is consulted. Without clear documentation of which is current, the repo is actively misleading.

**Recommendation:** Archive stale directories into a single `_archive/` folder. Add a README.md to `scripts/results/` explaining the directory naming convention and which directories are current.

---

## C7: Elevation Exponent — cos³ Legacy Comments

**Files involved:**
- `src/visualization.jl` line 1453 — comment: "trades rotor power (cos³β) for vertical lift"
- `src/ring_forces.jl` line 153 — code: `cos(elev_angle)^2.65` (corrected)
- `src/sim_frame.jl` line 158 — code: `cos(elev_angle)^2.65` (fixed this session)
- `src/initialization.jl` line 723 — code: `cos(elev_angle)^2.65` (fixed this session)

**Nature of conflict:** A comment in `visualization.jl` still references the old cos³ exponent. The code has been corrected to cos²·⁶⁵ in three files, but the comment hasn't been updated. A reader of the comment might think cos³ is still in use.

**Why it matters:** Low severity — comment only, no code impact. But it demonstrates how documentation can lag behind code fixes.

**Recommendation:** Update the comment in `visualization.jl`.

---

## C8: DLF Calibration — Documented vs Actual

**Files involved:**
- `src/trpt_optimization.jl` lines 49–76 — documents DLF=1.2 calibration from 6 ODE scenarios
- `scripts/calibrate_dlf.jl` — the calibration script; may use different scenarios
- `DECISIONS.md` — may reference the DLF choice

**Nature of conflict:** The DLF calibration is documented in detail in `trpt_optimization.jl`, but the calibration script (`calibrate_dlf.jl`) may reference different wind speeds, rotor configurations, or ODE parameters than what the documentation describes. Without running the script, we cannot confirm the documented values match the actual calibration.

**Why it matters:** The DLF directly multiplies all beam compression calculations. A 1.2 vs 1.4 DLF is a 17% difference in design loads.

**Recommendation:** Run `calibrate_dlf.jl` against the current model and verify the per-scenario DLF values match the documentation. Update documentation if they differ.

---

## Conflict Summary

| ID | Conflict | Files | Severity | Status |
|----|----------|-------|----------|--------|
| C1 | 58 kg vs 74 kg mass claim | Forum report versions | **HIGH** | Open |
| C2 | n=3 vs n=12 optimum | Old vs new diagrams/reports | **HIGH** | Open |
| C3 | Two canonical report locations | `docs/awes-forum-*.md` | MEDIUM | Open |
| C4 | Three knuckle mass values | `economics.jl`, `spacer_ring_design.jl`, `trpt_optimization.jl` | MEDIUM | Open |
| C5 | BEM sizing vs dynamics models | `bem.jl`, `aerodynamics.jl` | MEDIUM | Open (since Jun 8 audit) |
| C6 | Five v6 campaign result directories | `scripts/results/v6*` | MEDIUM | Open |
| C7 | cos³ legacy comment | `visualization.jl:1453` | LOW | Open |
| C8 | DLF calibration vs documentation | `trpt_optimization.jl`, `calibrate_dlf.jl` | LOW | Open |

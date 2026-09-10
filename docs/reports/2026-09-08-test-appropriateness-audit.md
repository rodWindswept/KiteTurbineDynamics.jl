# KTD.jl Test Appropriateness Audit, 2026-09-08

**Repo HEAD:** `0b77b53` (2026-09-07, "aligned-FoS structural layer + orientation fixes + solve_ring_Do"), clean tree, master == origin/master.
**Audit question (Rod):** Are there tests developed for OLD builders? We did NOT use their logic in the latest build. That logic may now go unchecked. One example: blade-size and relative-geometry tests for V10.

Did they apply to V13 designs? Were they relevant? Should we include them? What do old tests tell us about repeat mistakes to avoid? Do the tests align with our lessons and decisions docs?

**Method:** three parallel digs.
(A) Full test-suite inventory with LIVE/LEGACY verdicts per file vs the v13 pipeline (companion: `2026-09-08-test-suite-inventory.md`).
(B) Docs/lessons/decisions register vs test guards (companion: `2026-09-08-docs-vs-tests-register.md`).
(C) Git archaeology of builder/test history (section below).

Read-only: no test or code file changed. At HEAD, two targeted test files re-ran green (`test_fitness_appropriateness_2026_09.jl` 13/13, `test_builders_v10.jl` all pass).

---

## 1. Executive summary: direct answers

1. **Yes. 8 of 48 test files are LEGACY-ONLY** (they assert only code the v13 chain never calls). A further ~19 are PARTIAL (live kernels asserted on legacy 10 kW machines). The clearest cases start with `test_blade_geometry.jl`, green against the dead `build_v10_tight*` builder. Next, `test_physics_path_guard.jl` pins the static v10 solver, not the ODE path that v13 scores with. The list also holds `test_trpt_axial_profiles.jl`, `test_expansion_stack.jl`, `test_parameters.jl`, `test_lift_kite_rotary.jl` and `test_documented_claims.jl` (v10-era numbers only).

2. **The V10 blade-size / 70-30 geometry tests DID assert invariants that still matter for V13. But the file that pins them exercises the wrong (dead) builder.** The split is ring-anchored at 70/30: tip +0.7·span, hub −0.3·span, span = 0.75·r_rotor·blade_scale. The live decode does exactly this (`src/objective_v10.jl:269-284`), and it defines the annuli the ODE sweeps and the Betz gates use. So the *logic* is live and relevant, and the *test* would not catch a regression inside `design_from_vector_v10` / `build_system_from_v10`: it only builds `build_v10_tight_no_lowest`. The live pins sit elsewhere (`test_builders_v10.jl` L107-113 & L134-164, `test_blade_mass_law.jl`, `test_wind_blocking.jl`), see §3.

3. **Blade-SIZE scaling changed eras, and the old tests correctly no longer apply:** the λ-based area/hybrid scaling is dead. The unified span³ volume law replaced it (`m = m_ref·span³`, `M_BLADE_REF_KG = 0.420`). It restored the 420 g anchor and gives per-ring 2.52 kg for 6 blades. The Gate-1c 210 g renormalisation was a documented mistake, caught and REVERSED 2026-08-22. `test_blade_mass_law.jl` now pins the 420 g truth (L19-21, "was 0.210 under Gate 1c"). This is the single best example of an old test convention that a corrected lesson deliberately superseded.

4. **What old tests tell us about repeat mistakes:** the docs canon (DECISIONS, trust log, skill §2a/§20/§21/§24) records 23 fault classes. Live tests guard 13 of them today. 6 have partial or weak guards, and 4 have NO guard (see §5 register). The recurring pattern: renormalisation-without-re-derivation, tests re-baselined to new builder behaviour (moved goalposts), and doc/code drift on load-bearing constants. One instance: k_mppt 5.39 vs 2.24.

5. **Alignment verdict:** the suite aligns unusually well with the v13 decision trail. Every mass/geometry/wake decision from 08-22→09-04 has a purpose-built test naming its fault class. Exposure concentrates in four places.

   (a) Decisions have only behavioural guards or none at all (ζ default, :table mode, signed P_gen, evaluate_ramp, P_available, gate `!any_broken`).
   (b) The newest beam-sizing work (solve_ring_Do) has no callers and no tests.
   (c) Doc-level drift: DECISIONS breaks its own "newest at top" rule. It holds a stale k=5.39 entry and stale test counts in CLAUDE.md/CONTEXT.md. The ledger uses banned "λ³" phrasing.
   (d) NAS brain copies run weeks behind the repo (brain DECISIONS 2026-07-30 vs repo 09-06).

---

## 2. Suite census at HEAD (from inventory dig)

- **21 LIVE:** dominated by the 2026-08-20→09-07 v13-era files: `test_blade_mass_law`, `test_mass_model_2026_09`, `test_fitness_appropriateness_2026_09`, `test_settle_blocking_2026_09`, `test_settle_lowk_honest`, `test_campaign_k_alignment`, `test_gate_v13`, `test_evaluator_v13`, `test_rope_break`, `test_settle_drag_alignment`, `test_rotor_power_realism`, `test_airborne_fos`, `test_wind_blocking`, `test_lift_kite_stacked`, `test_ring_element_analysis`, `test_spacer_ring_design`, `test_expansion_induction`, `test_bem_unified`, `test_aerodynamics`, `test_geometry`, `test_physics_inertia_mass`.

- **19 PARTIAL:** the bulk are shared-kernel tests (compute_rope/ring_forces!, multibody_ode!, settle_*, run_canonical_sim!, capture_frame). They always run on the legacy `params_10kw` machine (n_lines 5, 16 rings, linear taper, full-disk legacy rotors). They cannot see v13 geometry conventions regress (ring-anchored hub blades, 70/30 annuli, wind blocking, ground-ring τ·ω power).

- **8 LEGACY-ONLY:** `test_blade_geometry`, `test_documented_claims`, `test_expansion_stack`, `test_lift_kite_rotary`, `test_parameters`, `test_physics_path_guard`, `test_trpt_axial_profiles` (+ v2 stack). Of these, 4 (blade_geometry, physics_path_guard, parameters, expansion_stack) are most likely to mislead about v13 health.

- **Dead code at HEAD that green tests still bless:** `build_v10_tight*`, `build_phantom_triangle`, `geometry_fingerprint` (builders_util.jl), with script-only callers. The list also holds v1/v2/v4-static design solvers and all objective adapters v5/v6/v10/v11/v12, plus `objective_feasibility`. The *shared protocol under them* (evaluate_windowed, with_k_bracket) is live.

  The params_10kw/50kw/v5/v6 sets are the same. The chain always passes a daisy-derived base, and `params_v5_50kw` survives only as an unreachable default. The dead-code list also holds the `build_kite_turbine_system` v1 linear-taper builder and the 60-mask bitmask decode branch. **`solve_ring_Do` (trpt_optimization.jl:108) belongs to the HEAD commit. It has zero callers and zero tests anywhere** (unwired beam-sizing prep, next step per handover-2026-09-07).

- Full per-file table: `2026-09-08-test-suite-inventory.md`.

## 3. The V10 blade/geometry invariants vs V13 (the core question)

| Old-test invariant | V10 truth | V13 truth | Verdict |
|---|---|---|---|
| 70/30 ring-anchored blade split (tip +0.7·span, hub −0.3·span) | asserted on the tight builder. That is test_blade_geometry.jl L13-53. | live decode does the same (objective_v10.jl:269-284). It defines the annulus the ODE/Betz gates sweep. | **Still required, but guarded in the wrong file**. Live pins: test_builders_v10.jl L107-113, L134-164, test_blade_mass_law.jl, test_wind_blocking.jl. test_blade_geometry.jl would stay green if the live decode regressed |
| Blade scale λ (equilibrium binding constraint, λ<0.8 ⇒ reject) | v10 static-equilibrium era | v13 cold ODE start. The evaluator now prices scale as span = 0.75·r_rotor·blade_scale. The L3 exploit is now VOID (span³ pricing). | Superseded → replaced by mass-law/span³ tests |
| Blade mass scaling (area/hybrid era) | λ²/hybrid, CFRP terms | unified `m_ref·span³`, 420 g anchor, knuckle floor, fingerprint no double-count | Superseded → `test_blade_mass_law.jl`, `test_mass_model_2026_09.jl` (LIVE) |
| n_blades = n_lines forced balance | asserted (test_builders_v10.jl L72-77) | still forced. Measured Daisy was 3-on-6, and per-blade mass renorm 210 g REVERSED to 420 g | Convention stands. L19-21 now pin the 210 g mistake |
| Ring spacing L/r law | v4 test asserts the geometric-series law. | The same law is live: the base decodes via `design_from_vector_v4` alias + warm-path radii (objective_evaluator.jl:576). The v5 form adds the cylinder+cone generalisation. | **Still live**. test_ring_spacing_v4.jl testsets 1-3/7 live. Testsets 4-6/8-9 pin the dead static FoS solver. |
| Geometry pure helpers (perp basis, attachment points, helix pos) | builder-agnostic | builder-agnostic, used by every ODE build incl. v13 | Fully live. The file test_geometry.jl is fine as-is |
| Round-trip: decode of v10_campaign_50kw CSV reproduces tight builder | v10 artifact pin | no v13 caller. The chain is Daisy-anchored with rotor_count_mode. | Museum pin: first 7 testsets of test_builders_v10.jl. They are harmless but dead weight. The last testsets (rotor→ring identity, decode→build placement) are LIVE and valuable |

**Net answer:** the old blade-size/geometry tests are *partially* applicable. Their invariants (70/30, spacing law, round-trip mapping) still govern v13 geometry. But several files pin those invariants to dead builders, so the tests cannot fail on v13 regressions. The span³ law and the 420 g anchor correctly superseded the blade-SIZE scaling tests. The new tests encode the corrected lesson, including the reversal of the 210 g mistake.

## 4. Repeat-mistake register (23 fault classes from docs, guard status at HEAD)

Full table with sources and line refs: `2026-09-08-docs-vs-tests-register.md`. Compressed:

**GUARDED (13):** test_blade_mass_law L19-21 guards the 210 g renormalisation-without-re-derivation mistake. The same file L24-40 marks the area/λ² hybrid scaling as dead. L36-37, 60-61 pin the span³-vs-decoded-span DE exploit. L108-130 pins the geometry_fingerprint double-count. test_settle_blocking_2026_09 L43-58 and test_rotor_power_realism P3 pin annulus-vs-full-disk Betz. test_settle_lowk_honest A4 pins the settle-scan cp-peak clamp.

test_campaign_k_alignment pins k single-source + 2.24. test_builders_v10 L83-105, 134-164 pins rotor→ring +1 off-by-one. test_airborne_fos pins FoS_min off-by-one. test_builders_v10 L83-132 pins hub-rotor double-model.

test_documented_claims L61-73 pins blade-count renorm precedent 11/5. test_blade_mass_law L132-156 pins negative-radii DomainError + dead genes. test_documented_claims L17-29 pins phantom-rebuild provenance.

**PARTIAL/WEAK (6):** ζ=1.5 damper rectifier has behavioural-only cover. **No static assert checks ζ == 0.05 (0 hits in tests).** n_blades=n_lines consequence on the built machine. stable_dt reintroduction, used in R3, has no guard against fixed-dt return. Gate bug 1 `!any_broken`: no test gates a broken-line machine → rejection. k theory-vs-sweep lesson. J·θ spurious torsional spring: the suite itself admits "test only checks the J VALUE, never how J is used".

**GAP (4):** the destructure-silence recording bug has no destructure-width/CSV-column sanity test. The tether-diameter hardcode `Do = 0.01396·√R` legacy fallback has 0 hits. The signed P_gen case: test_metric_consistency.jl re-derives P with the **banned `abs(ω_gnd)`** at positive ω only. So a reversion to masked power passes green. The silent-catch zeroing instrument output has no exception-path test (ADR-0004 #4).

## 5. Alignment findings (docs vs tests vs code): highlights

Full list A1-A12: `2026-09-08-docs-vs-tests-register.md`. Worst:

1. **DECISIONS [2026-08-21] says k=5.39 is the aligned gate value. The suite enforces 2.24** (`test_campaign_k_alignment.jl:40`). No later entry amends or supersedes the 08-21 entry. So the single most load-bearing campaign constant reads wrong at HEAD.

2. **DECISIONS.md violates its own "newest at top" rule.** Entries 08-19→09-04, including the two de-facto-newest 09-04 entries, sit at the bottom under "Knowledge Pipeline Decisions".

3. **Chronic stale test counts:** CLAUDE.md says "34 test files", "39 test files", "5 ODE files". Reality: 42 fast + 6 acceptance = 48. CONTEXT.md DECISIONS says "latest 2026-08-22", but reality is 09-06.

4. Physics-validation-ledger B1 still writes the banned "m = m_ref·λ³" phrasing.

5. test_metric_consistency.jl uses the exact masked `abs(ω_gnd)` form that DECISIONS [2026-08-20] banned.

6. NAS brain materially stale: brain DECISIONS 5 weeks behind, skill mirror = older format, ROD_NOTES 08-04. That is an operational risk for brain-first sessions.

7. handovers/README.md table missing rows it claims to index (08-22 ×2, 08-26, 08-27 absent).

## 6. Recommendations (audit only, no code changed. Each needs your call.)

**Fast static-unit guards (cheap, high value):**

1. Add a non-finite-FoS case for `appropriate_mass_fitness` to test_fos_guard.jl. Today it guards only legacy v11/v12 siblings, the sharpest false-confidence gap.

2. Extend test_physics_path_guard (or add) to the ODE cold path via `evaluate_windowed`. The live scoring path has no physics-toggle guard.

3. Add static asserts for `SystemParams.zeta == 0.05` and the GeneratorLoadMode `:table` no-regen floor. The `M_BLADE_REF_KG == 0.420` assert already exists. Add the ζ and mode defaults.

4. Add a signed-P_gen discriminating test: drive a reversed/regenerating state and assert P_gen < 0. Also fix the `abs()` re-derivation in test_metric_consistency.jl.

5. Gate bug-1 regression: a broken-line machine must hard-reject through the v13 gate.

6. Add the 70/30 live-decode assertion to test_blade_geometry.jl, so it guards `design_from_vector_v10`. The invariant is live, but the builder in that file is dead.

**Acceptance (once beam sizing lands):**

7. Add the beam-sizing load case plus a hub-ring FoS check of its own. `solve_ring_Do` currently has zero callers AND zero tests. Both structural paths skip the hub ring, the same "hidden weakest ring" class that VOIDed the rotorcount winner.

8. Add a J·θ regression: 2-rotor seed, no reversal over 20 s.

**Doc/debt (mechanical):**

9. Add a SUPERSEDED banner on DECISIONS [2026-08-21] k=5.39. Also add a stale-phrase entry ("k=5.39 at 5 kW" → 2.24). Add the "m = m_ref·λ³" phrase. Fix the CLAUDE.md/CONTEXT.md counts. Restore newest-at-top in DECISIONS.md.

10. Decide the fate of the 8 LEGACY-ONLY + museum-pin testsets. Either mark them explicitly as era pins in headers (provenance value: test_documented_claims), or delete them (dead-builder-only: test_expansion_stack, test_parameters, v2-stack testsets). Do not leave them as green "v13 health" signals.

11. Brain sync: re-run SYNC_PLAN. Make the nightwatch diff include brain-root file ages. Laptop pull confirmed. Nightwatch 09-08: the laptop has NOT yet pulled 0b77b53.

## 7. Builder/test history: commit timeline (git sweep, read-only, 30 commands)

**Test-file provenance:**

- `test_builders_v10.jl`: created **aeb248b** 2026-07-17 (Phase 1e regression). Last touched **828668d** 2026-08-26, which added the mapping invariants (the live half).

- `test_blade_geometry.jl`: created **13f304a** 2026-07-05, last touched **4ce9fd0** 2026-08-21 (the Daisy-anchor commit). Yet it still only exercises the dead tight builder.

- `test_ring_spacing_v4.jl`: created **73a2cf8** 2026-04-24 (red-phase TDD), last **54b9d91** 2026-07-24. It is the oldest era-pin file still in the suite.

- `test_blade_mass_law.jl`: created **bdc9ae7** 2026-08-22, the SAME commit that restored the 420 g anchor. The guard arrived with the correction. Last touched **630f160** 2026-09-02.

- `test_geometry.jl`, `test_static_equilibrium.jl`: created **60c7c83** 2026-03-16, last **28bc58a** 2026-04-21. Long-untouched but builder-agnostic (geometry helpers fully live).

**Deleted tests (the only removals in history):**

- Exactly ONE deletion commit exists: **cce274e** 2026-07-14 ("Week 1 cleanup"). It removed `test_pitch_depower_control_campaign.jl`, `test_stall_control_campaign.jl`, `verify_initialization_consistency.jl`, and `verify_simulation_consistency.jl`.

- Zero renames ever (`--diff-filter=R` empty). No rename moved an old test into a v13-era file. Every era pin that still exists is original.

- Post-deletion coverage: `test_pitch_depower_sequence.jl` still covers pitch-depower. **The stall-control campaign and the two `verify_*` checks have NO current equivalent.** These are the only genuine "deleted logic with no successor" candidates in the whole history. Note: those checks ran at campaign-script level in the v1/v2 era. Verify whether their invariants survive inside test_types/test_dynamics before you re-add them.

**Invariant change timeline (blade mass / tension / k):**

- **77b2fdb** 2026-08-18 started the const_tension regime (mast-rig calibration). Then **428f491** 2026-08-19 made `sized_lifter_for(..., const_tension=false)` the default, with legacy v2 preserved (toggle-era discipline).

- **b5902a0** 2026-08-21 renormalised the blade anchor 420→210 g (Daisy 3-on-6 mispremise). **bdc9ae7** 2026-08-22 RESTORED 420 g, with the unified `m = m_ref·λ³` and knuckle floor (test born same commit). **807efa6** 2026-08-23 priced on the decoded span (`0.420·(span/1.0)³`, winners VOID). **30686f2** 2026-08-24 verified it.

- **7d6b9ca** 2026-08-24 created the `K_MPPT_5KW_HONEST` single source. **026c734** 2026-08-24 set it to 2.24, which supersedes the 5.39 that DECISIONS [2026-08-21] still documents.

- **630f160** 2026-09-02 introduced `appropriate_mass_fitness` (Wave-1 T1-T3), used by f1134ea/7617b94. **fda2fae** 2026-09-06 re-baselined it.

**Moved-goalpost signals (tests changed to match new builder behaviour):**

- **ac3db3c** 2026-08-02 "V10 builder now produces 13-gon, update expectations", the clearest early example (12→13-gon expectation rewritten).

- **630f160** 2026-09-02 re-baselined `test_blade_mass_law.jl` in the same commit as the T1 mass-model fix, adding the three 2026_09 guard files.

- **fda2fae** 2026-09-06 explicit "acceptance re-baseline to corrected winner" (±113/±43/±109/±95/±33 lines across the five acceptance files). That rerun was legitimate (the team VOIDed and re-verified the winner), but it was the largest single goalpost move. The old numeric baselines exist only in git.

- **0b77b53** 2026-09-07 HEAD touched `test_evaluator_v13.jl`, `test_mass_model_2026_09.jl`, `test_ring_element_analysis.jl` alongside the aligned-FoS work, correct practice (same-commit guard updates).

- **f1134ea** landed the over-twist penalty with NO test change. The evaluator-level W_TWIST application has no dedicated guard, though the fitness-fn level has one (`test_fitness_appropriateness_2026_09.jl`).

**Answer to Q5 (logic vanished at era ends): none.** No builder-era test disappeared in the same commit that an era ended. The sole deletion landed 3 days before the v10 builder tests, and successors cover it, except for stall-control/verify_* (above).

## 8. Companion artifacts

- `2026-09-08-test-suite-inventory.md`: a 48-file table, call-chain map, and dead-logic ledger.

- `2026-09-08-docs-vs-tests-register.md`: lessons register L1-L23, DECISIONS→test map, findings A1-A12.

- Repo copies live in `docs/reports/`, and NAS-brain copies in `_hermes_brain/SESSIONS/2026-09-08-ktd-test-appropriateness-audit/`. Both are committed and pushed to master, so the laptop gets them on its next `git pull`.

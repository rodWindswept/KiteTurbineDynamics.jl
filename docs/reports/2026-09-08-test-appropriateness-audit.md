# KTD.jl Test Appropriateness Audit — 2026-09-08

**Repo HEAD:** `0b77b53` (2026-09-07, "aligned-FoS structural layer + orientation fixes + solve_ring_Do"), clean tree, master == origin/master.
**Audit question (Rod):** Are there tests developed for OLD builders whose logic we did NOT use in the latest build, such that their logic may now be missed — e.g. blade-size and relative-geometry tests for V10: did they apply to V13 designs? Were they relevant? Should they be included? What do old tests tell us about repeat mistakes to avoid? Do the tests align with our lessons and decisions docs?

**Method:** three parallel digs — (A) full test-suite inventory with LIVE/LEGACY verdicts per file vs the v13 pipeline (companion: `2026-09-08-test-suite-inventory.md`); (B) docs/lessons/decisions register vs test guards (companion: `2026-09-08-docs-vs-tests-register.md`); (C) git archaeology of builder/test history (section below). Read-only: no test or code files were modified. Two targeted test files were re-run and confirmed green at HEAD (`test_fitness_appropriateness_2026_09.jl` 13/13, `test_builders_v10.jl` all pass).

---

## 1. Executive summary — direct answers

1. **Yes — 8 of 48 test files are LEGACY-ONLY** (assert only code the v13 chain never calls) and ~19 are PARTIAL (live kernels asserted on legacy 10 kW machines). The clearest cases: `test_blade_geometry.jl` (green against the dead `build_v10_tight*` builder), `test_physics_path_guard.jl` (pins the static v10 solver, not the ODE path v13 scores with), `test_trpt_axial_profiles.jl`, `test_expansion_stack.jl`, `test_parameters.jl`, `test_lift_kite_rotary.jl`, `test_documented_claims.jl` (v10-era numbers only).
2. **The V10 blade-size / 70-30 geometry tests DID assert invariants that still matter for V13 — but the file that pins them exercises the wrong (dead) builder.** The 70/30 ring-anchored split (tip +0.7·span, hub −0.3·span, span = 0.75·r_rotor·blade_scale) is exactly what the live decode does (`src/objective_v10.jl:269–284`) and it defines the annuli the ODE sweeps and the Betz gates use. So the *logic* is live and relevant; the *test* would not catch a regression inside `design_from_vector_v10` / `build_system_from_v10` because it only builds `build_v10_tight_no_lowest`. The live pins live elsewhere (`test_builders_v10.jl` L107–113 & L134–164, `test_blade_mass_law.jl`, `test_wind_blocking.jl`) — see §3.
3. **Blade-SIZE scaling changed eras and the old tests correctly no longer apply:** the λ-based area/hybrid scaling is dead, replaced by the unified span³ volume law with the 420 g anchor restored (`m = m_ref·span³`, `M_BLADE_REF_KG = 0.420`, per-ring 2.52 kg for 6 blades). The Gate-1c 210 g renormalisation was a documented mistake, caught and REVERSED 2026-08-22 — and `test_blade_mass_law.jl` now pins the 420 g truth (L19–21, "was 0.210 under Gate 1c"). This is the single best example of an old test convention being deliberately superseded by a corrected lesson.
4. **What old tests tell us about repeat mistakes:** the docs canon (DECISIONS, trust log, skill §2a/§20/§21/§24) records 23 fault classes; 13 are guarded today by live tests, 6 partially/weakly, 4 have NO guard (see §5 register). The recurring pattern: renormalisation-without-re-derivation, tests re-baselined to new builder behaviour (moved goalposts), and doc/code drift on load-bearing constants (k_mppt 5.39 vs 2.24).
5. **Alignment verdict:** the suite is unusually well aligned with the v13 decision trail — every mass/geometry/wake decision from 08-22→09-04 has a purpose-built test naming its fault class. Exposure concentrates in four places: (a) decisions guarded only behaviourally or not at all (ζ default, :table mode, signed P_gen, evaluate_ramp, P_available, gate `!any_broken`); (b) the newest beam-sizing work (solve_ring_Do) is unwired AND untested; (c) doc-level drift (DECISIONS "newest at top" violated, stale k=5.39 entry, stale test counts in CLAUDE.md/CONTEXT.md, ledger using banned "λ³" phrasing); (d) NAS brain copies weeks behind the repo (brain DECISIONS 2026-07-30 vs repo 09-06).

---

## 2. Suite census at HEAD (from inventory dig)

- **21 LIVE** — dominated by the 2026-08-20→09-07 v13-era files: `test_blade_mass_law`, `test_mass_model_2026_09`, `test_fitness_appropriateness_2026_09`, `test_settle_blocking_2026_09`, `test_settle_lowk_honest`, `test_campaign_k_alignment`, `test_gate_v13`, `test_evaluator_v13`, `test_rope_break`, `test_settle_drag_alignment`, `test_rotor_power_realism`, `test_airborne_fos`, `test_wind_blocking`, `test_lift_kite_stacked`, `test_ring_element_analysis`, `test_spacer_ring_design`, `test_expansion_induction`, `test_bem_unified`, `test_aerodynamics`, `test_geometry`, `test_physics_inertia_mass`.
- **19 PARTIAL** — the bulk are shared-kernel tests (compute_rope/ring_forces!, multibody_ode!, settle_*, run_canonical_sim!, capture_frame) but always on the legacy `params_10kw` machine (n_lines 5, 16 rings, linear taper, full-disk legacy rotors). They cannot see v13 geometry conventions regress (ring-anchored hub blades, 70/30 annuli, wind blocking, ground-ring τ·ω power).
- **8 LEGACY-ONLY** — `test_blade_geometry`, `test_documented_claims`, `test_expansion_stack`, `test_lift_kite_rotary`, `test_parameters`, `test_physics_path_guard`, `test_trpt_axial_profiles` (+ v2 stack). Of these, 4 (blade_geometry, physics_path_guard, parameters, expansion_stack) are most likely to mislead about v13 health.
- **Dead code at HEAD that green tests still bless:** `build_v10_tight*`, `build_phantom_triangle`, `geometry_fingerprint` (builders_util.jl) — script-only callers; v1/v2/v4-static design solvers; all objective adapters v5/v6/v10/v11/v12 + `objective_feasibility` (the *shared protocol under them* — evaluate_windowed, with_k_bracket — is live); params_10kw/50kw/v5/v6 sets (chain always passes a daisy-derived base; `params_v5_50kw` survives only as an unreachable default); `build_kite_turbine_system` v1 linear-taper builder; the 60-mask bitmask decode branch. **`solve_ring_Do` (trpt_optimization.jl:108) — the HEAD commit's own feature — has zero callers and zero tests anywhere** (unwired beam-sizing prep, next step per handover-2026-09-07).
- Full per-file table: `2026-09-08-test-suite-inventory.md`.

## 3. The V10 blade/geometry invariants vs V13 (the core question)

| Old-test invariant | V10 truth | V13 truth | Verdict |
|---|---|---|---|
| 70/30 ring-anchored blade split (tip +0.7·span, hub −0.3·span) | asserted on tight builder (test_blade_geometry.jl L13–53) | live decode does the same (objective_v10.jl:269–284) → annulus the ODE/Betz gates sweep | **Still required — but guarded in the wrong file** (live pins: test_builders_v10.jl L107–113, L134–164; test_blade_mass_law.jl; test_wind_blocking.jl). test_blade_geometry.jl would stay green if the live decode regressed |
| Blade scale λ (equilibrium binding constraint, λ<0.8 ⇒ reject) | v10 static-equilibrium era | v13 cold ODE start; scale now priced as span = 0.75·r_rotor·blade_scale (L3 exploit was VOIDed — span³ pricing) | Superseded → replaced by mass-law/span³ tests |
| Blade mass scaling (area/hybrid era) | λ²/hybrid, CFRP terms | unified `m_ref·span³`, 420 g anchor, knuckle floor, fingerprint no double-count | Superseded → `test_blade_mass_law.jl`, `test_mass_model_2026_09.jl` (LIVE) |
| n_blades = n_lines forced balance | asserted (test_builders_v10.jl L72–77) | still forced; measured Daisy was 3-on-6, per-blade mass renorm 210 g REVERSED to 420 g | Convention stands; the mistake (210 g) is now pinned against (L19–21) |
| Ring spacing L/r law | v4 test asserts geometric-series law | same law is live: decode base via `design_from_vector_v4` alias + warm-path radii (objective_evaluator.jl:576); v5 = cylinder+cone generalisation | **Still live** — test_ring_spacing_v4.jl testsets 1–3/7 live; testsets 4–6/8–9 pin the dead static FoS solver |
| Geometry pure helpers (perp basis, attachment points, helix pos) | builder-agnostic | builder-agnostic, used by every ODE build incl. v13 | Fully live — test_geometry.jl fine as-is |
| Round-trip: decode of v10_campaign_50kw CSV reproduces tight builder | v10 artifact pin | no v13 caller (Daisy-anchored, rotor_count_mode) | Museum pin — first 7 testsets of test_builders_v10.jl; harmless but dead weight; the last testsets (rotor→ring identity, decode→build placement) are LIVE and valuable |

**Net answer:** the old blade-size/geometry tests are *partially* applicable: their invariants (70/30, spacing law, round-trip mapping) still govern v13 geometry, but several files pin them to dead builders, so they cannot fail on v13 regressions. The blade-SIZE scaling tests were correctly superseded by the span³ law and the 420 g anchor — and the new tests encode the corrected lesson (including the reversal of the 210 g mistake).

## 4. Repeat-mistake register (23 fault classes from docs; guard status at HEAD)

Full table with sources and line refs: `2026-09-08-docs-vs-tests-register.md`. Compressed:

**GUARDED (13):** renormalisation-without-re-derivation 210 g (test_blade_mass_law L19–21); area/λ² hybrid scaling dead (L24–40); span³-vs-decoded-span DE exploit (L36–37, 60–61); geometry_fingerprint double-count (L108–130); annulus-vs-full-disk Betz (test_settle_blocking_2026_09 L43–58, test_rotor_power_realism P3); settle-scan cp-peak clamp (test_settle_lowk_honest A4); k single-source + 2.24 (test_campaign_k_alignment); rotor→ring +1 off-by-one (test_builders_v10 L83–105, 134–164); FoS_min off-by-one (test_airborne_fos); hub-rotor double-model (test_builders_v10 L83–132); blade-count renorm precedent 11/5 (test_documented_claims L61–73); negative-radii DomainError + dead genes (test_blade_mass_law L132–156); phantom-rebuild provenance (test_documented_claims L17–29).

**PARTIAL/WEAK (6):** ζ=1.5 damper rectifier (behavioural only; **no static assert ζ == 0.05 — 0 hits in tests**); n_blades=n_lines consequence on built machine; stable_dt reintroduction (used in R3, no guard against fixed-dt return); gate bug 1 `!any_broken` (no test gates a broken-line machine → rejection); k theory-vs-sweep lesson; J·θ spurious torsional spring (**suite's own admission: "test only checks the J VALUE, never how J is used"**).

**GAP (4):** destructure-silence recording bug (no destructure-width/CSV-column sanity test); tether-diameter hardcode `Do = 0.01396·√R` legacy fallback (0 hits); signed P_gen — test_metric_consistency.jl re-derives P with the **banned `abs(ω_gnd)`** at positive ω only, so a reversion to masked power passes green; silent-catch zeroing instrument output (ADR-0004 #4, no exception-path test).

## 5. Alignment findings (docs vs tests vs code) — highlights

Full list A1–A12: `2026-09-08-docs-vs-tests-register.md`. Worst:
1. **DECISIONS [2026-08-21] says k=5.39 is the aligned gate value; the suite enforces 2.24** (`test_campaign_k_alignment.jl:40`). The 08-21 entry was never amended/superseded — the single most load-bearing campaign constant is documented wrong at HEAD.
2. **DECISIONS.md violates its own "newest at top" rule**: entries 08-19→09-04 (incl. the two de-facto-newest 09-04 entries) sit at the bottom under "Knowledge Pipeline Decisions".
3. **Chronic stale test counts**: CLAUDE.md "34 test files"/"39 test files"/"5 ODE files" vs reality 42 fast + 6 acceptance = 48. CONTEXT.md DECISIONS "latest 2026-08-22" (reality 09-06).
4. Physics-validation-ledger B1 still writes the banned "m = m_ref·λ³" phrasing.
5. test_metric_consistency.jl uses the exact masked `abs(ω_gnd)` form that DECISIONS [2026-08-20] banned.
6. NAS brain materially stale (brain DECISIONS 5 weeks behind; skill mirror = older format; ROD_NOTES 08-04) — operational risk for brain-first sessions.
7. handovers/README.md table missing rows it claims to index (08-22 ×2, 08-26, 08-27 absent).

## 6. Recommendations (audit only — no code changed; each needs your call)

**Fast static-unit guards (cheap, high value):**
1. Add non-finite-FoS case for `appropriate_mass_fitness` to test_fos_guard.jl (today it guards only legacy v11/v12 siblings — the sharpest false-confidence gap).
2. Extend test_physics_path_guard (or add) to the ODE cold path via `evaluate_windowed` — the live scoring path has no physics-toggle guard.
3. Static asserts: `SystemParams.zeta == 0.05`, GeneratorLoadMode `:table` no-regen floor, `M_BLADE_REF_KG == 0.420` already exists — add the ζ and mode defaults.
4. Signed-P_gen discriminating test: drive a reversed/regenerating state and assert P_gen < 0 (and fix test_metric_consistency.jl's `abs()` re-derivation).
5. Gate bug-1 regression: broken-line machine must hard-reject through the v13 gate.
6. 70/30 live-decode assertion added to test_blade_geometry.jl so it guards `design_from_vector_v10` (the invariant is live; the file's builder is dead).

**Acceptance (once beam sizing lands):**
7. Beam-sizing load case + hub-ring first-class FoS (solve_ring_Do currently zero-callers AND zero-tests — the hub ring is skipped by both structural paths, the same "hidden weakest ring" class that VOIDed the rotorcount winner).
8. J·θ regression: 2-rotor seed, no reversal over 20 s.

**Doc/debt (mechanical):**
9. SUPERSEDED banner on DECISIONS [2026-08-21] k=5.39 + stale-phrase entry ("k=5.39 at 5 kW" → 2.24); add "m = m_ref·λ³" phrase; fix CLAUDE.md/CONTEXT.md counts; restore newest-at-top in DECISIONS.md.
10. Decide fate of the 8 LEGACY-ONLY + museum-pin testsets: either mark explicitly as era pins in headers (provenance value: test_documented_claims) or delete (dead-builder-only: test_expansion_stack, test_parameters, v2-stack testsets) — do not leave them as green "v13 health" signals.
11. Brain sync: re-run SYNC_PLAN; nightwatch diff to include brain-root file ages; laptop pull confirmed (nightwatch 09-08: laptop has NOT yet pulled 0b77b53).

## 7. Builder/test history — commit timeline (git sweep, read-only, 30 commands)

**Test-file provenance:**
- `test_builders_v10.jl` — created **aeb248b** 2026-07-17 (Phase 1e regression), last touched **828668d** 2026-08-26 (mapping invariants added — the live half).
- `test_blade_geometry.jl` — created **13f304a** 2026-07-05, last touched **4ce9fd0** 2026-08-21 (the Daisy-anchor commit) — yet it still only exercises the dead tight builder.
- `test_ring_spacing_v4.jl` — created **73a2cf8** 2026-04-24 (red-phase TDD), last **54b9d91** 2026-07-24. Oldest era-pin file still in the suite.
- `test_blade_mass_law.jl` — created **bdc9ae7** 2026-08-22 — the SAME commit that restored the 420 g anchor. The guard was born with the correction. Last touched **630f160** 2026-09-02.
- `test_geometry.jl`, `test_static_equilibrium.jl` — created **60c7c83** 2026-03-16, last **28bc58a** 2026-04-21. Long-untouched but builder-agnostic (geometry helpers fully live).

**Deleted tests (the only removals in history):**
- Exactly ONE deletion commit: **cce274e** 2026-07-14 ("Week 1 cleanup") removed `test_pitch_depower_control_campaign.jl`, `test_stall_control_campaign.jl`, `verify_initialization_consistency.jl`, `verify_simulation_consistency.jl`.
- Zero renames ever (`--diff-filter=R` empty) — no old test was renamed into a v13-era file; every era pin that still exists is original.
- Post-deletion coverage: pitch-depower still covered by `test_pitch_depower_sequence.jl`; **stall-control campaign and the two `verify_*` checks have NO current equivalent** — the only genuine "deleted logic with no successor" candidates in the whole history. (Note: they were campaign-script-level checks from the v1/v2 era; verify whether their invariants survive inside test_types/test_dynamics before re-adding.)

**Invariant change timeline (blade mass / tension / k):**
- **77b2fdb** 2026-08-18 const_tension regime born (mast-rig calibration) → **428f491** 2026-08-19 `sized_lifter_for(..., const_tension=false)` default with legacy v2 preserved (toggle-era discipline).
- **b5902a0** 2026-08-21 blade anchor renormalised 420→210 g (Daisy 3-on-6 mispremise) → **bdc9ae7** 2026-08-22 420 g RESTORED, unified `m = m_ref·λ³` + knuckle floor (test born same commit) → **807efa6** 2026-08-23 priced on decoded span (`0.420·(span/1.0)³`; winners VOID) → **30686f2** 2026-08-24 verified.
- **7d6b9ca** 2026-08-24 `K_MPPT_5KW_HONEST` single source created; = 2.24 set in **026c734** 2026-08-24 (supersedes the 5.39 that DECISIONS [2026-08-21] still documents).
- **630f160** 2026-09-02 `appropriate_mass_fitness` born (Wave-1 T1–T3), used by f1134ea/7617b94, re-baselined **fda2fae** 2026-09-06.

**Moved-goalpost signals (tests changed to match new builder behaviour):**
- **ac3db3c** 2026-08-02 "V10 builder now produces 13-gon, update expectations" — the clearest early example (12→13-gon expectation rewritten).
- **630f160** 2026-09-02 re-baselined `test_blade_mass_law.jl` in the same commit as the T1 mass-model fix, adding the three 2026_09 guard files.
- **fda2fae** 2026-09-06 explicit "acceptance re-baseline to corrected winner" (±113/±43/±109/±95/±33 lines across the five acceptance files) — legitimate (winner was VOIDed and re-verified) but the largest single goalpost move; the old numeric baselines exist only in git.
- **0b77b53** 2026-09-07 HEAD touched `test_evaluator_v13.jl`, `test_mass_model_2026_09.jl`, `test_ring_element_analysis.jl` alongside the aligned-FoS work — correct practice (same-commit guard updates).
- **f1134ea** over-twist penalty landed with NO test change — the evaluator-level W_TWIST application has no dedicated guard (fitness-fn-level is guarded via `test_fitness_appropriateness_2026_09.jl`).

**Answer to Q5 (logic vanished at era ends): none.** No builder-era test was deleted in the same commit an era ended; the sole deletion predates the v10 builder tests by 3 days and is covered by successors except for stall-control/verify_* (above).

## 8. Companion artifacts
- `2026-09-08-test-suite-inventory.md` — 48-file table, call-chain map, dead-logic ledger.
- `2026-09-08-docs-vs-tests-register.md` — lessons register L1–L23, DECISIONS→test map, findings A1–A12.
- Repo copies land in `docs/reports/`; NAS-brain copies in `_hermes_brain/SESSIONS/2026-09-08-ktd-test-appropriateness-audit/`. Untracked, not pushed — laptop sync will pick them up per normal workflow.

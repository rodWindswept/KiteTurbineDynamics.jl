# Standards & Physics-Convention Audit — 2026-08-20

Status: COMPLETE (read-only audit; no changes made)
Date: 2026-08-20
Auditors: software-validator (standards debt), science-validator (physics conventions)
Lead: Hermes
Scope: KiteTurbineDynamics.jl

## Ground truth (established this session)

- 40 test files (39 `test_*.jl` + `runtests.jl`); `runtests.jl` includes 34 → **5 never run**.
- Suite: **1912 tests** passing in 2m31s (exit 0).
- src: 42 files / 17,083 lines. 651 commits.

## 1. Software — standards debt (software-validator)

### 1.1 Findings

| # | Sev | file:line | issue |
|---|-----|-----------|-------|
| 1 | critical | charts/generate_charts.jl:42-43,47,64-65,85,89 | Entire datasets hardcoded, zero data reads — F1 power curve, F2 FoS arrays, F3 waterfall. Charts silently diverge from physics. |
| 2 | critical | charts/generate_charts.jl:49,71,87,129 | `hlines 50 kW` / `FoS=1.5` magic literals; provenance stamp hardcodes commit `86ca0e5` — every figure claims a fixed data commit. |
| 3 | critical | CLAUDE.md:24,79 | "23 test files" — reality 40. Agent entry point drives wrong expectations. |
| 4 | major | test/runtests.jl (34 includes) | 5 test files never run: `evaluator_v13`, `gate_v13`, `rope_break`, `rotor_power_realism`, `settle_drag_alignment`. Gate-critical tests not wired. |
| 5 | major | scripts/render_v10_tight_all.py:51,55,251,269 | Winner stats hardcoded: "49.2 kg", 4 rotors, 59 rpm, λ=0.52, k_mppt=166. |
| 6 | major | scripts/render_v10_atlas.py:126 + 2 more | "76.75 kg" winner mass hardcoded in 3 files. |
| 7 | major | docs/community/ktd-community-report.md:25,323 + .tex:85, GET-INVOLVED.md:11, CONTRIBUTING.md:11 | "917 tests in 23 files, Julia 1.12" — reality 1912/40. External-facing. |
| 8 | major | docs/agents/domain.md:19 | "33 test files, 1902 tests" — reality 40/1912; "~22 min" — reality 2m31s. |
| 9 | major | docs/infographic-prompt-ktd.txt:11 | "13,831 LOC · 322 commits · 917+ tests" — reality 17,083 · 651 · 1912. |
| 10 | major | src/objective_v11.jl (3.78/100w, 27 viol, 17 em-dash) | Worst high-volume STE breach. |
| 11 | major | src/dashboard_panels.jl (3.66/100w; :178 at 9.8) | STE breach in docstrings. |
| 12 | major | src/objective_evaluator.jl (2.60/100w, 55 viol, 49 em-dash) | `evaluate_windowed` docstring: semicolons, contractions, passive. |
| 13 | major | src+test repo-wide | 839 em/en-dashes (parameters.jl 83, visualization.jl 64, objective_evaluator.jl 56). |
| 14 | minor | 21 of 82 src+test files | Breach 2.0/100w in comments/docstrings (see §1.3). |
| 15 | minor | CONTEXT.md:236 | "24 test files" — reality 40. |
| 16 | minor | docs/plans/2026-08-13-evaluator-v13…:115, docs/agents/stale-phrases.md:23-25 | "1902 tests" — now 1912. |
| 17 | minor | scripts/plot_science_advanced.py:146-154 | Hardcoded annotation coordinates for cliff labels. |
| 18 | minor | scripts/render_v2_screenshots.jl:159, plot_v10_trajectories.jl:146,121,128 | Magic reference values/limits. |
| 19 | minor | render_v10_tight_all.py:106,131; render_v10_pairs.py:163 | Campaign-structure counts in titles. |
| 20 | minor | docs/codebase-audit-2026-07-14.md:7, docs/plans/2026-06-27…:224 | Historical counts — correct for their date, wrong now (dated reports: banner, don't edit). |
| 21 | ok | docs/outreach/strathclyde_followup_draft.md:33,39 | "≈800/793 assertions" — VERIFIED correct. Do not flag. |

### 1.2 Category summary

- **STE prose debt**: 21 of 82 src/test files breach 2.0/100w; 839 em-dashes. Dominant: semicolons, contractions, passive, long paragraphs.
- **Stale counts**: 12+ wrong claims across 10 docs. Root cause: 5 test files not wired, so the count drifts every time a file lands.
- **Hardcoded numbers**: `generate_charts.jl` hardcodes whole datasets; `render_v10_*` hardcode winner stats. Good patterns to keep: `render_v10_atlas.py:88-89` (limits from `pc1.min()`).

## 2. Science — physics conventions (science-validator)

### 2.1 Findings

| # | Sev | file:line | inconsistency |
|---|-----|-----------|---------------|
| 1 | major | src/simulation.jl:342-343,538-539 vs ring_forces.jl:143-144,151-152 | Brake torque scale law: simulation LINEAR (`p_rated_w/10000`), ring_forces QUADRATIC (`(p_rated_w/10000)^2`). Comment at simulation.jl:342 says "matches ring_forces.jl logic" — false. Traces diverge 2× at 5 kW, 5× at 50 kW. |
| 2 | major | src/sim_frame.jl:133,462 | `P_kw = tau_gen * abs(omega_gnd)` sign-masks power. v13 gate uses signed `P_gen`. A reversed ring reads positive "generation" on the dashboard. |
| 3 | major | src/initialization.jl:68, ring_forces.jl:57,368, expansion_stack.jl:110 vs DECISIONS.md, ADR 0001:78-79 | Ring numbering: code ring 1 = ground, docs ring 1 = hub. Two authoritative docs oppose the code. |
| 4 | major | src/ring_forces.jl:143-144 | `tau_max_safe = 2500*(p_rated_w/10000)^2` — hidden-unit magic law; 2.25 Nm at 300 W vs measured 20-24 Nm (9× under-clamp). |
| 5 | minor | src/objective_v10.jl:170,189 | `sind(30.0)` hardcodes elevation duplicating `p.elevation_angle`. |
| 6 | minor | src/sim_frame.jl:32, dashboard_v2.jl:410 | P_kw labelled "electrical" — it is mechanical shaft power. |
| 7 | minor | src/objective_evaluator_ramp.jl:237 | Manual `* pi / 180.0` instead of `deg2rad`. |
| 8 | minor | src/parameters.jl:251-252 | `pi/6` radian literal next to `deg2rad(70.0)`. |
| 9 | minor | src/parameters.jl:27,117 | `elevation_angle` lacks the `_rad`/`_deg` suffix siblings carry. |
| 10 | minor | src/builders_util.jl:264-267 | Comment "drop lowest" but code pops the HIGHEST ring_idx. |
| 11 | minor | test/test_emergent_torsion.jl:10, test_builders_v10.jl:92 | Test comments use "ring 1" = hub (stale vs code). |
| 12 | minor | src/objective_evaluator.jl:101,104-105,612 | ObjectiveConfig mixes W and kW in one struct. |
| 13 | minor | src/ring_forces.jl:377,145 | tau_gen sign semantics implicit, never declared. |
| 14 | minor | src/objective_evaluator.jl:488 | `k_mppt_ref = -60.0` sign-overload for kickstart, only a comment documents it. |
| 15 | minor | src/objective_v6.jl:177,400 | `cosd` in the internal computation path (frozen v6). |

### 2.2 Verified clean

- No imperial/non-SI constants in src physics. No psi/bar/lb/ft.
- "fly-gen"/"flygen": 0 matches repo-wide. TRPT terminology clean in code.
- rpm: display/CSV only, uniform conversion.
- Vertex azimuth convention uniform, matches ADR 0001.
- C1 torque clamp action-reaction matches DECISIONS 2026-08-14.
- Twist state: radians internal, degrees at capture — consistent.

## 3. Combined recommendations (prioritized)

1. **Wire the 5 test files into `runtests.jl`** + fix stale doc counts (software). Root cause of every wrong count.
2. **Rewrite `generate_charts.jl`** to read from data + real provenance stamp (software). Figures must not lie.
3. **Physics convention fixes** (science, needs proposal + acceptance tests first): brake-torque scaling (linear vs quadratic), ring numbering (ground=1 vs hub=1), P_kw sign, tau_max_safe scaling law.
4. **STE cleanup + render_v10 hardcoded stats** (software). Prose/mechanical.

## 4. Bottom line

No critical physics defect — the code is safe to campaign on today. The 2026-08-09 evaluator consolidation (ADR 0005) already removed the dangerous class (rejection sentinels, ring-mapping authority, k-in-genome). Remaining debt is figures/telemetry that misreport, tests that don't run, and convention drift in comments/docs. Findings 1 and 2 (both validators) should be fixed before the next results are cited from dashboards or traces.

# Codebase Audit — 2026-07-14

Improvement list from a full repo survey: validation, hygiene, efficiency, and agent ergonomics. Prioritized P0 (correctness/data-loss risk) → P2 (efficiency/ergonomics). Every item names the exact files.

## P0 — Validation & data-loss risks

**1. Three test files never run.** `test/runtests.jl` includes 23 files, but `test/` contains 26 `test_*.jl`. Not included: `test_blade_geometry.jl`, `test_pitch_depower_control_campaign.jl`, `test_stall_control_campaign.jl`. Either add them (blade_geometry especially — blade scaling is live work) or move the two slow campaign tests to `scripts/` with a comment in runtests explaining why.

**2. `test/verify_*.jl` contain zero `@test`/`@testset`.** `verify_initialization_consistency.jl` (103 lines) and `verify_simulation_consistency.jl` (55 lines) are print-and-eyeball scripts sitting in `test/`. Convert their checks to real assertions or move them out.

**3. Global `*.csv` and `*.log` at the end of `.gitignore`.** This silently unversions every new campaign result — the progressive-CSV discipline saves to disk, then git ignores it. This is the same failure mode as the 2026-07-13 lost sweep, one level up. Decide a policy: re-include summaries (`!scripts/results/**/*summary*.csv`), a results branch, or Git LFS. Right now a `git clean` or fresh clone loses campaign outputs.

**4. No regression baseline for the physics core.** The centre-constraint spoke bug survived because nothing pinned sim outputs. Add golden-trace tests: run `run_canonical_sim!` for 1–2 s on 2–3 canonical builds (V10 as-built, λ=0.69 reinforced), assert endpoint state vector / P / min-FoS against stored values with tolerance. Also verify FR4 (`N_expansion = 0` ≡ v5 bit-for-bit) is enforced by an actual test, not just stated in CLAUDE.md.

**5. No CI.** No `.github/workflows/`. Blocked mainly by the dependency bloat (P1.7) — after the dep split, a plain `julia -e 'Pkg.test()'` action becomes cheap. CI would have caught items 1–2 immediately.

**6. Dirty working tree.** 30 untracked/modified paths including `Manifest.toml`, `backup_conflicts_pull/` (an unresolved pull conflict backup), `docs/outreach.zip`, `.hermes/plans/`. Resolve and commit or delete; agents burn context re-discovering whether these matter.

## P1 — Structure & dependencies

**7. Project.toml carries ~12 unused-in-src deps.** `Pluto`, `PlutoUI`, `MeshCat`, `Pandoc`, `Bonito`, `WGLMakie`, `CairoMakie`, `DifferentialEquations`, `FFTW`, `Rotations`, `CoordinateTransformations`, `Colors`, `ArgParse` have zero `using`/qualified use in `src/`. `GLMakie` appears in only 3 src files (visualization/dashboards). Split: core physics package (lean deps: CSV, DataFrames, JSON3, CoaxialAutogyroStacking) + a viz package extension or `dashboards/Project.toml`. Payoff: instantiate/precompile drops from a GL-stack build to seconds, headless machines and CI work without OpenGL, and agent sandboxes can actually load the package.

**8. `ControlMapHunt` is a module trapped in a script.** `scripts/hunt_kmppt_bisect.jl` defines the module every hunt/sweep/test script `include()`s; `v10_tight_builder` calls `include("builders_util.jl")` *inside a function*, forcing `Base.invokelatest` everywhere and re-parsing on every build. Promote `ControlMapHunt` + `builders_util.jl` into `src/` (exported properly). This removes the world-age hacks, the redefinition warnings, and is the likely root cause of the stale-`.ji` problem that CLAUDE.md rule 6 works around with cache-clearing ritual — fix the cause, delete the ritual.

**9. `scripts/` is a 144-file flat namespace (+64 Python).** One-off diagnostics (`test_054.jl`, `test_069_reinforced.jl`, `test_079.jl`, `test_spoke.jl`, `test_keep_lowest.jl`, …) sit beside canonical runners, and `test_*.jl` names collide mentally with `test/`. Restructure: `scripts/campaigns/`, `scripts/diagnostics/`, `scripts/reports/` (the ~10 large `produce_*`/`generate_*` Python report generators), `scripts/archive/`. Keep a `scripts/README.md` table: script → purpose → status (canonical/superseded).

**10. Version accretion in src.** `objective_v6.jl` (771 lines) and `trpt_optimization.jl` (860 lines) coexist with `objective_v10.jl`. If V6-era campaigns are closed, move superseded objective/optimizer code to `archive/` with a pointer in DECISIONS.md. Same for the v6/v9 campaign runners in scripts.

**11. Repo weighs 1.7 GB (`.git` alone 1.2 GB).** 438 MB of `scripts/results/` is tracked, including four redundant copies of one campaign (`v6_campaign_50kw_stale`, `_old`, `_archive`, `_v2_stale`) and 20 MB campaign logs. Plus `docs/awes-forum-diagrams` at 75 MB and a committed `outreach.zip`. Prune duplicates, move large artifacts to LFS or an external results store, then `git filter-repo` to shrink history. Every agent clone/index currently pays this cost.

## P2 — Efficiency & agent ergonomics

**12. Integrator headroom.** `run_canonical_sim!` is explicit Euler at DT = 4e-5 → 750k steps per 30 s sim, hours per sweep. `DifferentialEquations` is already a dep (unused). Once golden traces (item 4) exist as the safety net, trial RK4 or a stiff-aware solver at larger dt and validate against the Euler baseline. Even 3× dt saves hours per feasibility round. Also: sweep scripts rebuild the full system for every k value — reuse the built system across k, re-settle only.

**13. Root directory: 59 entries.** Screenshots (3 PNG), 15 launch/run shell scripts, `NOTES_MPPT_TWIST` in both `.md` *and* `.txt`, `fix_and_launch.txt`, `swap_clipboard.txt`, `V10_TIGHT_DASHBOARD.txt`, numbered audit files `01_…04_*.md`. Move launchers to `scripts/launchers/`, notes/screenshots to `docs/case-notes/` or `archive/`. Target: ≤15 root entries so the first `ls` an agent runs is signal.

**14. Entry-point doc sprawl.** `CLAUDE.md`, `AGENTS.md`, `CONTEXT.md`, `PLAN.md`, `RECAP.md`, `TODO.md`, `PROJECT_ROOM.md`, `RESTART_INSTRUCTIONS.md` overlap. Keep CLAUDE.md (agents) + CONTEXT.md (domain) + README.md (humans); fold the rest in or archive them. Also fix CLAUDE.md drift: it claims "23 test files" (there are 26+2) — describe policy, not counts that rot.

**15. DECISIONS.md is a 2,252-line monolith.** The "read last 200 lines" heuristic loses everything older. Add a dated table-of-contents at top (phase → line anchor → one-line outcome), or split per phase under `docs/decisions/` with DECISIONS.md as index.

**16. docs/ top level has ~45 mixed entries.** Phase reports (`phase_j` … `phase_o`), dashboard docs (5 files), PRDs, and one-off analyses all flat. Group: `docs/phases/`, `docs/dashboard/`, keep `docs/adr/` pattern going (it's good — only 1 ADR so far; the spoke-model correction deserves ADR-0002).

**17. handovers/ naming is inconsistent.** `handover-YYYY-MM-DD.md`, `HANDOFF_*.md`, `2026-05-28-*-session.md` mixed. One convention + a newest-first index in `handovers/README.md` so "read the most recent handover" is deterministic for agents.

**18. Name the two V10s.** The winner (12-gon/12-ring) vs as-built (triangle/22-ring, `builders_util.jl`) ambiguity has cost real time. Add canonical names to CONTEXT.md (e.g. V10-W / V10-AB) and use them in filenames and reports.

**19. Results provenance.** `hunt_kmppt_bisect.jl` already stamps `GIT_HASH` into outputs — good; extend that to all campaign/sweep writers, and add `scripts/results/README.md`: campaign → generating script → commit → status (valid/superseded/invalidated-by-spoke-correction). Post-Phase-D, several tracked result sets are now known-wrong; mark them.

## Suggested order

Week 1 (no risk, immediate payoff): items 1, 2, 6, 13, 17, 14. Week 2 (guard rails): 4, 3, 5. Then the structural pair that unlocks speed: 7 + 8, followed by 9–11. Item 12 last — only after golden traces exist.

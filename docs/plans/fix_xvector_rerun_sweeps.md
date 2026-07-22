# PLAN: Fix x-vector packing → re-run key sweeps → answer Strathclyde questions

**For:** Hermes agent, KiteTurbineDynamics.jl, run on Rod's machine (Julia required — the Cowork sandbox cannot run Julia).
**Authored:** 2026-07-17, from the code-verification session behind `docs/outreach/strathclyde_qa_verified.md`. Read that file FIRST — it contains the verified decode table and the definitions your final answers must use.
**Also read before starting:** `CONTEXT.md`, last ~200 lines of `DECISIONS.md`, most recent file in `handovers/`. Load skills: `windswept-knowledge`, `awe-knowledge`, `tdd`, `ktd-simulation-workflow`.

## Background (do not skip)

`_build_v10_tight` in `src/builders_util.jl` packs the design vector in `best_design.json` field order, but `design_from_vector_v10` → `design_from_vector_v4` (`src/ring_spacing.jl:402–428`) decodes the v4 layout. Result: every headless sweep and the dashboard "V10 Tight" entries built a **3-line triangle frame, 22 rings, untapered ~2.99 m cylinder, bank 25°/4°**, not the 12-gon/10-ring/tapered campaign winner. Full slot-by-slot table: `docs/outreach/strathclyde_qa_verified.md` §Q5.

The numbers already emailed to Strathclyde (0.85·k2: 117 kW @ 11 m/s FoS 4.5, 225 kW @ 15 m/s FoS 11.9; 0.95·k4: 199 kW FoS 5.2; 0.95·k6 light tether: 259 kW FoS 6.1) are **triangle-system results**. After the fix you are simulating a *different machine*. Expect different numbers — possibly much worse: `dynamic_verification.txt` found the correctly-decoded winner non-viable (12.1 kW at k=62). **Do NOT tune anything to reproduce the old numbers. Report what the corrected system actually does.**

## Ground rules (from CLAUDE.md — mandatory)

1. `rm -f ~/.julia/compiled/v1.12/KiteTurbineDynamics/*.ji ~/.julia/compiled/v1.12/KiteTurbineDynamics/*.so` after EVERY `src/` edit and before every sweep.
2. Use `run_canonical_sim!()` only; never hand-roll integrators.
3. Progressive CSV saves — write each row/scenario immediately (a 2026-07-13 run died with everything unsaved).
4. Full test suite (23 files) green before any commit: `script -q -c "julia --project=. test/runtests.jl" /dev/null`.
5. Never overwrite legacy result CSVs — archive first (Phase 0).

---

## Phase 0 — Preserve provenance

1. Record current `git rev-parse HEAD` in your handover notes.
2. In `scripts/results/control_maps/`: copy (don't move) `kickstart_sweep.csv`, `wind_sweep.csv`, `catalog_corrected_geo.csv` to `*_triangle_legacy.csv` siblings. These are the source data of the charts already sent to Strathclyde; they must remain reproducible.
3. Commit the archive copies before touching code.

## Phase 1 — Fix the packing

### 1a. Primary fix: `src/builders_util.jl` `_build_v10_tight`

**Preferred approach — eliminate hand-packing entirely.** `best_design.json` has NO rotor-mask field, so a correct hand-pack from JSON is impossible without inventing x[10]. Instead load the raw winner vector the way the dashboard's correct path does: `build_from_campaign_v10` (`scripts/interactive_dashboard.jl:227`) reads `scripts/results/v10_campaign_50kw/best_vector.csv` and feeds it straight to `design_from_vector_v10`. Refactor `_build_v10_tight` to do the same, then apply the kwargs **post-decode**:

- `r_bottom_scale`: multiply decoded r_bottom ONCE (the current code applies it twice — lines 51 and 57), then enforce taper `r_bottom ≤ r_hub` explicitly.
- `do_scale`, `t_scale`: multiply decoded Do_top / t_over_D (and keep the `sys.ring_Do_top[]` / `sys.ring_toverD[]` assignments consistent — currently lines 109–110 use the JSON values; after the fix they must use the same post-scale values the design used).
- `r_hub_scale`: multiply decoded r_hub, re-check taper.
- `blade_scale`: unchanged — stays post-build on blade tip/hub/chord + hub disk (this part was never broken).
- Delete the branch at line 101 that switches between `build_kite_turbine_system_v5` and `build_kite_turbine_system` based on `r_bottom_scale != 1.0` — pick ONE builder for all r values (the v5/`ring_spacing_v4` path, which respects r_bottom/target_Lr) so r=1.00 and r=1.30 are comparable. This branch is the root cause of the catalog-vs-wind_sweep figure discrepancy.

**Fallback** (only if best_vector.csv is missing/unreadable): hand-pack in the CORRECT v4 order — `x = [Do_top, t_over_D, beam_aspect, Do_scale_exp, r_hub, r_bottom, target_Lr, n_lines, density_profile, rotor_mask, bank_top, bank_bottom, λ_top, λ_bottom]` — sourcing rotor_mask from best_vector.csv (memory of record: mask idx 18 → rotors at intermediate rings [1,4,7,10] from hub; VERIFY against the CSV, do not trust this note).

### 1b. Fix or verify the "drop lowest rotor" logic

Current code sorts `rotors` by `ring_idx` **rev=true** then `popfirst!` — that removes the HIGHEST ring_idx. Check against the numbering comment in `objective_v10.jl:145–158` (mask position 1 = hub ring = intermediate ring n_rings): as written this likely drops the rotor nearest the HUB while printing "Dropped lowest". Determine the true intent from DECISIONS.md; fix so the printed claim and the physics agree. ⛔ **Decision gate: if ambiguous, stop and ask Rod which rotor should be dropped.**

### 1c. Blades-per-rotor decision gate

`ExpansionRotorParams(n_lines, ...)` sets blades per expansion rotor = n_lines. Triangle system → 3 blades; corrected 12-gon → **12 blades per rotor**. ⛔ **Stop and ask Rod whether 12 blades/rotor is physically intended before running sweeps** — this multiplies blade area, mass, and torque and is not obviously the designed machine. (Rod's hardware mental model is 3-bladed.)

**→ RESOLVED (2026-07-17):** 12 blades/rotor for the 12-gon. n_blades = n_lines for balanced polygon frames. The triangle systems tested so far were bug-built — an explicitly-built n_lines=3 system with the correct builder may produce different (possibly better) numbers. **Amendment: the acceptance target includes BOTH the 12-gon AND a deliberate n_lines=3 triangle, both built from the fixed builder, so results can be compared directly rather than betting on the 12-gon being the restoration target.**

### 1d. Deduplicate the other scrambled packings

Audit and fix every hand-packed vector (all currently in JSON-field order, all wrong):

- `scripts/interactive_dashboard.jl:287–336` (local `build_v10_tight_no_lowest`) — DELETE the local copy and call the fixed `src/builders_util.jl` version, so dashboard and headless can never diverge again.
- `scripts/sweep_blade_scale.jl` (`build_scaled`)
- `scripts/test_blade_scaled.jl:19`
- `scripts/sensitivity_sweeps.jl:52,75,97`
- `scripts/run_blade_scaled_control_map.jl:22`

Route all through the fixed builder (add kwargs if needed) rather than repairing each pack in place.

### 1e. Regression tests (write BEFORE the fix, TDD)

Add `test/test_builders_v10.jl` (and register in `test/runtests.jl`):

1. Built system from the fixed builder has `n_lines == 12`, intermediate `n_rings == 10`, `r_hub ≈ 2.889`, `r_bottom ≈ 2.000` (taper present), tether ≈ 67.08 m — i.e. matches `best_design.json`.
2. Round-trip guard: decode `best_vector.csv` via `design_from_vector_v10` and assert the builder's design equals it field-for-field.
3. `r_bottom_scale=1.3` scales r_bottom exactly ×1.3 (not ×1.69) and never exceeds r_hub.
4. `blade_scale=0.85` leaves ring radii untouched and scales blade tip/hub/chord by exactly 0.85.

## Phase 2 — Verification gates before any sweep

1. Clear Julia cache (ground rule 1).
2. Full test suite green.
3. Build once and check the printed line reads `n_lines=12 ... rings=10` (or the post-1c agreed values).
4. Cross-check: launch nothing — instead compare the fixed builder's ring radii/z-positions against `build_from_campaign_v10("v10_campaign_50kw", ...)` output programmatically; they must match.
5. `k_mppt` re-hunt: the triangle system's k∈{2..14} sweep range is meaningless for the new geometry (`dynamic_verification.txt` suggests k≈62 scale). Run `scripts/hunt_kmppt_bisect.jl` on the fixed builder FIRST to bracket sensible k before committing to sweep grids. Adjust `K_VALUES` in the sweep scripts accordingly and record the change.

## Phase 2b — Blade-scaling audit (added 2026-07-17, after k-bracketing began)

Before ANY cross-configuration comparison table, resolve these four traps:

1. **λ reference shift.** The correct decode carries the winner's own λ gradient (verify from best_vector.csv; expected ≈0.52 top → 0.10 bottom). The `blade_scale` kwarg multiplies on top. Therefore "blade_scale=0.85" on the 12-gon ≠ "0.85" on the legacy triangle (whose underlying gradient was 1.0→0.88). Every published number must state absolute blade dimensions, not just λ.
2. **n_lines drives blades/rotor.** `ExpansionRotorParams(n_lines, ...)` — forcing n_lines=3 on the winner vector cuts blade area ~4× as a side effect. The "triangle3" MUST NOT be built that way (see below).
3. **Blade mass per rotor vs per blade.** `expansion_blade_mass(tip·λ, λ)` is passed once per rotor — verify whether dynamics multiplies by blade count. If not, 12-blade rotors carry 1-blade inertia.
4. **k·λ² double application.** `ControlSpec` bakes `km = k_mppt·λ²`; sweeps also set `sys.k_mppt_ref[]` directly. Confirm which the sim reads; document.

**Geometry fingerprint requirement:** the builder must print (and each sweep CSV must record): n_lines, n_rings, r_hub, r_bottom, per-rotor n_blades/tip/chord, per-rotor and total blade area, hub disk radius, per-rotor blade mass, decoded λ gradient, applied blade_scale kwarg.

**Validation sequencing (replaces open question of 2026-07-17 12:28):**
1. 12-gon at k=62, static settle: must reproduce `dynamic_verification.txt` (12.1 kW, ω=55.6 rpm, FoS 0.43). Match = end-to-end validation of the fixed decode against an independent historical result. Mismatch = stop, diagnose.
2. **triangle3 = faithful deliberate rebuild of the phantom**: 3 lines, 22 rings, untapered ≈2.99 m, λ gradient 1.0→0.88, bank 25°/4°. Gate: reproduce legacy kickstart result (blade 0.85, k=2, 11 m/s → ≈117 kW, FoS ≈4.5). Match converts all legacy Strathclyde numbers from "bug artifact" to "verified simulation of a now-specified design". A clean-sheet triangle DE campaign is future work, not this task.
3. Only then run the sweep grids (12-gon with rebracketed k; triangle3 with legacy k range).

## Phase 3 — Re-run the sweeps (in this order)

**Amendment (Rod, 2026-07-17):** Each sweep step runs TWICE — once for the corrected 12-gon and once for an explicitly-built n_lines=3 triangle. Both use the fixed builder. This gives a direct comparison rather than betting on which geometry is the restoration target.

All outputs to NEW filenames — suffix `_12gon` and `_triangle3` (e.g. `kickstart_sweep_12gon.csv`, `kickstart_sweep_triangle3.csv`); never append to legacy CSVs. Put the git hash and builder fingerprint (n_lines, n_rings, r_hub, r_bottom) in a header comment row or sidecar `.meta` file for each.

1. **`scripts/kickstart_sweep.jl`** — blades {0.69, 0.75, 0.80, 0.85} × rebracketed K_VALUES, 11 m/s. Protocol unchanged: settle → kick all rings to ω=30 rad/s → 30 s k=0 → engage k → 60 s MPPT → record P, ω(rpm), min airborne-ring FoS, T_max. If the kick speed is inappropriate for the 12-gon (different inertia), note it and re-bracket ω_kick; document any change.
2. **`scripts/retest_085_k2.jl`** (→ `wind_sweep_12gon.csv`) — best kickstart point across winds {5,7,9,11,13,15} m/s. Update BLADE/K constants to the corrected system's best point (from step 1), not blindly 0.85/k2.
3. **`scripts/catalog_sweep.jl`** (→ `catalog_12gon.csv`) — keep FOS_GATE=1.5, P_GATE_KW=50; rounds/r-values now behave uniformly since the builder branch is gone. Re-state ROUNDS if the r semantics changed meaningfully.
4. Regenerate the outreach figures in `docs/outreach/figures/` from the new CSVs (same plotting scripts), clearly versioned — do NOT overwrite the PNGs already emailed.

Runtime caution: 22-ring→12-station changes ODE size and stiffness; watch for stalls (retest_085 used SIM_S=30 "to avoid ODE stall"). Use `script -q -c "julia ..." /dev/null` for live output.

## Phase 4 — Answer Hong & Amjad's six questions

Use `docs/outreach/strathclyde_qa_verified.md` as the base — Q1 (λ definition), Q2 (FoS formulation + relation to k), Q3 (k2 = k_mppt=2), Q4 (30 s no-load spin protocol), Q6 (in-plane member compression) are already code-verified and survive the fix *as definitions*; refresh any quoted numbers from the new CSVs. Then:

- **Q5**: answer honestly — r was intended as the bottom-ring radius multiplier; a packing bug meant earlier shared results ran a triangle/22-ring system; state the corrected geometry (n_lines, rings, radii from the fixed builder printout) and the new numbers.
- Include the λ-vs-TSR disambiguation (Q1) and correct the "spin to 140+ rpm" description if ω_kick changed.
- Produce a draft reply email as `docs/outreach/strathclyde_reply_draft.md` with every number traceable to a `_12gon` CSV row (cite file+row in HTML comments Rod can strip).

## Acceptance criteria

- [ ] Test suite 23/23 green including new `test_builders_v10.jl`.
- [ ] Fixed builder prints 12-gon geometry matching `best_design.json` / `best_vector.csv` decode.
- [ ] Zero remaining hand-packed x-vectors in JSON-field order (grep `x = Float64\[` and verify each).
- [ ] Dashboard "V10 Tight" and headless builder produce identical geometry (shared code path).
- [ ] Legacy CSVs archived untouched; all new results in `_12gon` files with git hash.
- [ ] `strathclyde_reply_draft.md` written; every number cited to a CSV row.
- [ ] Both decision gates (1b drop-direction, 1c blades-per-rotor) explicitly resolved by Rod, recorded in DECISIONS.md.

## Known traps

- Julia buffers stdout — wrap in `script -q -c`.
- Stale `.ji` cache silently runs old code — clear after every src edit.
- `Base.invokelatest` builder closures mean edits to builders_util mid-session may not take effect — restart Julia between fix and verification.
- The sandbox (Cowork/Hermes VM) has no Julia; sweeps run on Rod's machine only.
- CONTEXT.md's V10 table row (n_lines=14) is a stale third variant — ignore it; update it as part of this work.

# Runbook — launch the full valid 5 kW rotorcount DE campaign (2026-08-27)

**Audience:** the agent (or human) that will manage the ~12 h run.
**Preconditions (all DONE, committed `617415d`):** downstream wake blocking
landed, clearance authority landed, 5 kW re-seed (r_hub 2.4) validated, re-gate
decode aligned.  Fast suite **1991/1991**.  Smoke green.

The steps below are in dependency order.  Do not skip §2 (archive) — the runner
writes into the existing VOID directory and would mix new telemetry with void
rows.

---

## 0. Environment (every Julia command)

```bash
cd /home/rod/Documents/GitHub/KiteTurbineDynamics.jl
export JULIA_DEPOT_PATH="$PWD/.julia_depot:$HOME/.julia"
```

Add `--compiled-modules=existing` to every `julia` invocation.  Without it, a
precompile of the heavy Makie/REPL deps fails in this environment (`Failed to
open ptm`).  With it, edited `src/` recompiles in-memory and the heavy deps
load from their existing `.ji` cache — correct and fast.

---

## 1. Re-sweep power_split (before committing ~12 h of compute)

`power_split` (top-rotor power fraction) is FIXED at `0.6` in the runner, but
it now interacts with blocking: `0.6` gives the TOP rotor (the most-blocked
rotor) the largest power share.  Re-sweep it first so the campaign spends its
budget on the right fixed value.

```bash
julia --project=. --compiled-modules=existing scripts/sweep_power_split.jl
```

Reads the re-seeded genome across `power_split ∈ {0.3, 0.4, 0.5, 0.6, 0.7}` and
prints `clearance / status / P_mean / FoS / fitness`.  **Choose the power_split
whose `status=ok` has the lowest fitness, re-checking clearance ≥ 1.5 m.**

If the chosen value ≠ `0.6`, update it in all four places (grep `0.6` /
`power_split`):
1. `scripts/run_v13_5kw_masslift.jl` → `cfg.power_split`
2. `scripts/ode_gate_v13.jl` → the `power_split=` kwarg in `gate_design`
3. `scripts/smoke_masslift_v13.jl` → both the `ObjectiveConfig` and the decode
4. `scripts/sweep_power_split.jl` (the loop list, for future re-sweeps)

Then re-run the smoke to confirm the seed is still valid at the chosen value:

```bash
julia --project=. --compiled-modules=existing scripts/smoke_masslift_v13.jl
# expect: status=ok  P_mean >= 5.0  FoS >= 2.5  rel <= 0.05  -> "SMOKE: ALL PASS"
```

If `0.6` already wins, skip straight to §3.

---

## 2. Archive the VOID campaign directory

The existing `scripts/results/v13_5kw_masslift_len18.8_rotorcount/` is VOID
(see its `VOID.md`: the 08-25 run's "winner" buckled at FoS 0.556, islands 1/2
killed early).  Move it out of the runner's output path so the new run starts
clean:

```bash
cd /home/rod/Documents/GitHub/KiteTurbineDynamics.jl
mv scripts/results/v13_5kw_masslift_len18.8_rotorcount \
   scripts/results/archive_void_20260825_rotorcount
```

Do **not** `git add` the archive; results telemetry stays untracked (repo
convention).  Verify the runner path is now clear:

```bash
test ! -e scripts/results/v13_5kw_masslift_len18.8_rotorcount && echo "clear"
```

---

## 3. Launch the 3 islands (parallel)

Three separate processes, one per island, each writing its own `island_N/`
subdir.  Run them as managed background jobs and keep the ids.

```bash
cd /home/rod/Documents/GitHub/KiteTurbineDynamics.jl
export JULIA_DEPOT_PATH="$PWD/.julia_depot:$HOME/.julia"

nohup julia --project=. --compiled-modules=existing --threads=auto \
    scripts/run_v13_5kw_masslift.jl --island 1 \
    > /tmp/v13_rotorcount_island1.log 2>&1 &

nohup julia --project=. --compiled-modules=existing --threads=auto \
    scripts/run_v13_5kw_masslift.jl --island 2 \
    > /tmp/v13_rotorcount_island2.log 2>&1 &

nohup julia --project=. --compiled-modules=existing --threads=auto \
    scripts/run_v13_5kw_masslift.jl --island 3 \
    > /tmp/v13_rotorcount_island3.log 2>&1 &
```

Each island: 10 pop × 30 gen = 310 evals, ~87 s/eval → roughly 7–9 h wall (the
three run concurrently).  The runner writes progressive telemetry, so progress
is observable before completion.

**Pre-launch checklist (verify all four before starting):**
- [ ] `scripts/sweep_power_split.jl` result recorded; power_split consistent everywhere.
- [ ] `scripts/smoke_masslift_v13.jl` → "SMOKE: ALL PASS".
- [ ] VOID dir archived (§2); output path clear.
- [ ] Launch provenance: `git rev-parse HEAD` noted (should be `617415d` or later).

---

## 4. Monitor

Per-island telemetry (appended per eval):

```bash
tail -n 3 scripts/results/v13_5kw_masslift_len18.8_rotorcount/island_1/telemetry.csv
tail -n 3 scripts/results/v13_5kw_masslift_len18.8_rotorcount/island_2/telemetry.csv
tail -n 3 scripts/results/v13_5kw_masslift_len18.8_rotorcount/island_3/telemetry.csv
```

Progress per island (`island_N_best_meta.txt` updates every generation):

```bash
for n in 1 2 3; do echo -n "island $n: "; \
  cat scripts/results/v13_5kw_masslift_len18.8_rotorcount/island_${n}/island_${n}_best_meta.txt; done
```

Watch for (respond per the trust-log):
- **`FoS = Inf` rows in telemetry** — the FoS=Inf exploit signature.  Should be
  zero (the guard landed); if any ok-row shows Inf, note it for the re-gate.
- **`status` column drifting to mostly `reject/timeout/error`** — evaluator
  regression; kill and investigate before continuing.
- **A stuck island** (no telemetry growth for > 1 h) — check its log in `/tmp/`.

---

## 5. Combine islands

When all three reach `gen 30`:

```bash
julia --project=. --compiled-modules=existing scripts/combine_islands_v13.jl --length 18.8
```

Writes `best_vector.csv`, `global_best_meta.txt`, `combined_summary.csv` at the
campaign root.  The global best is the lightest fitness across islands.

---

## 6. Re-gate the winners (decode-aligned now)

```bash
julia --project=. --compiled-modules=existing \
    scripts/ode_gate_v13.jl scripts/results/v13_5kw_masslift_len18.8_rotorcount/best_vector.csv
```

Requires: `P_gen_final >= 5.0 kW`, `ω_gnd > 0.5`, no twist crossing,
`clearance >= 1.5 m`, tip-speed sanity.  Also run the winners analysis:

```bash
julia --project=. --compiled-modules=existing scripts/analyze_campaign_winners.jl
```

**Screen every ok winner for the FoS=Inf signature** (the guard landed
mid-campaign in the 08-22 era; re-confirm per winner here).  A winner that
re-gates clean with finite FoS ≥ 2.5, P ≥ 5 kW, and clearance ≥ 1.5 m is a
**valid 5 kW design**.

---

## 7. Acceptance re-baseline

On the validated winner(s), follow
`docs/plans/2026-08-22-acceptance-rebaseline.md` (run each red acceptance file,
record actuals on the post-campaign HEAD, update expectations + git hash, re-run
to green, one commit).  Do this only after §6 produces a valid winner.

---

## 8. Decision cautions (do not silently change)

- **power_split** — change it only via the §1 sweep; it is a campaign-wide fixed
  knob, not a genome gene.
- **blocking** — `BLOCKING_WIND_FACTOR_5KW = 0.75^(1/3)` in `compute_seeds.jl`
  is the single source.  Blocking is non-cumulative (each downstream rotor
  blocked once); do not reintroduce cumulative 0.75² de-rating.
- **clearance** — the `lowest_rotor_clearance` authority in `src/objective_v10.jl`
  is geometrically correct (absolute tip + elevation cos + bank).  Do not regress
  to the offset-only or no-cos forms.
- **k_mppt** — `K_MPPT_5KW_HONEST = 2.24` (single source in `compute_seeds.jl`).

## 9. Related docs

- `DECISIONS.md` [2026-08-27] — the physics decisions behind this run.
- `handovers/handover-2026-08-27-5kw-reseed.md` — session handover.
- `docs/plans/2026-08-22-acceptance-rebaseline.md` — post-campaign rebaseline.
- `docs/agents/instrument-trust-log.md` — monitor-response bounds.

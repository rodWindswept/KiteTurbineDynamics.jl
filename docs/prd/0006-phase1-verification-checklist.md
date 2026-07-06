# PRD 0006 Phase 1 — Verification Checklist & Save Discipline

**Status:** OPEN
**Date:** 2026-07-06
**Parent:** [PRD 0006](0006-blade-geometry-audit.md) · [Phase 1 delta analysis](0006-phase1-delta-analysis.md)
**Purpose:** Close the integrity gaps in Phase 1 before Phase 2 builds on it, and fix the
persistence failures that nearly lost Gate 1B and have already desynchronised doc from data.
Nothing below requires new physics — it is verification and bookkeeping only.

---

## P0 — Doc/data contradictions (found 2026-07-06, resolve first)

- [ ] **§1.3 λ=0.69 table contradicts the on-disk CSV.**
  `gate1_blade_scaled_069_maxpower_summary.csv` (2026-07-06T00:37:12) is *newer* than the
  delta doc (2026-07-05) and disagrees on every row:

  | Wind | doc k / CSV k | doc FoS / CSV FoS | doc status / CSV status |
  |------|---------------|-------------------|--------------------------|
  | 5  | 6.2 / 2.0   | 12.20 / 11.38 | deficit / deficit |
  | 9  | 12.9 / 6.23 | 2.97 / 4.62   | deficit / deficit |
  | 11 | 12.9 / 6.23 | 2.00 / 3.56   | ok / ok |
  | 15 | 12.9 / 6.23 | **1.23 / 2.08** | **FoS_fail / ok** |

  Determine which run is authoritative (check session logs for a λ=0.69 re-run after the
  doc was written). If the 00:37 CSV stands, then **λ=0.69 meets P≥50 kW AND FoS≥1.5 across
  the full envelope** — §1.3, §2 (its c/R² fit), and §4's "conservative fallback /
  not a 50 kW design" verdict must all be regenerated, and the counter-analysis claim
  is back on the table.
- [ ] **Regenerate every delta-doc table from the CSVs by script**, and keep that script
  in `scripts/` (idempotent, per repo guideline #4). Hand-transcribed tables are how this
  desync happened. The doc should never contain a number that wasn't read from a CSV at
  generation time.

## P1 — Provenance repair

- [ ] **Commit the 70/30 fix set and record the hash.** All 18 corrected rows AND the
  tier-X biased rows carry the same header `@ 86ca0e5` — `GIT_HASH` is a hardcoded
  constant in the hunt script, never bumped for the 13-file geometry fix. Biased and
  corrected data are currently indistinguishable by provenance.
- [ ] Replace the hardcoded constant with
  `readchomp(`git -C $(dirname(@__DIR__)) rev-parse --short HEAD`)` + a dirty-tree check
  that refuses to run (or stamps `-dirty`) with uncommitted changes.
- [ ] Retro-annotate existing CSVs: add one comment line to each corrected file
  (`# geometry:70/30 post-PRD0006-fix`) and each tier-X file (`# geometry:25/0 BIASED`).
- [ ] **Commit the actual driver script.** CSV headers say `hunt_kmppt_bisect`; the
  committed `hunt_kmppt_maxpower.jl` writes different file names (`v10_tight_lambda_100`
  vs actual `gate1_v10_tight_maxpower`). The script that produced the published data must
  be in git, or the header claim is false.
- [ ] Add `tier-X-biased-geometry/README.md`: what these files are, why retained, the
  defect, and "do not cite except as tier X".

## P2 — Acceptance-criteria audit (plan §3, per row)

- [ ] **`converged` is false on 17/18 corrected rows.** Either the dual-duration criterion
  (0.5 kW absolute — 0.1% at 493 kW) is mis-calibrated, or the endpoints genuinely aren't
  converged. Decide: switch to relative tolerance (suggest 1% of P) OR extend T. Re-flag
  all rows. No number goes into the technical report from a row whose convergence status
  is unresolved.
- [ ] **`closure_pct` ≡ 0.0 is circular, not a pass.** The script computes
  `P_loss = P_aero − P_ground`, so criterion 3 (energy closure < 1%) is satisfied by
  construction and tests nothing. Either measure loss through an independent channel
  (e.g. integrate damper dissipation) or delete the closure claim from the acceptance
  criteria and the report.
- [ ] **Consistency stamp units:** all rows log ~0.000997 against a spec of 1.00 ± 0.01
  (kW vs W, factor 1000). Fix the logger; the CSV should self-document as passing.
- [ ] **k-grid refinement:** k still lands on grid points only (2.0, 3.0, 6.23, 12.94,
  26.87). All P are lower bounds; FoS at the true peak is unmeasured. Priority rows =
  those near verdict thresholds: Reinforced@15 (2.26), λ=0.69@15 (2.08 or 1.23 — see P0),
  Tight@11 (1.15). One zoom pass (log-spaced ×5 between the two neighbours of the railed
  point) per priority row is enough for the freeze; full Brent later.
- [ ] **Persist the P(k) sweeps.** Plan §2 requires them (feeds F4, measures peak
  flatness); zero sweep CSVs exist on disk. The hunt already computes every point —
  save is one `CSV.write` per wind.

## P3 — Definitional checks

- [ ] **Static–dynamic gap: state the comparison basis.** Current gap = P_ground(dyn) /
  P_static(aero) — mixed basis; transmission loss is inside the ratio. Report either
  aero-vs-aero (e.g. Tight@11: 130.0/54.4 = 2.39×) or ground-vs-ground, and say which.
- [ ] **State the inversion explicitly** in the report: v0.1 had static over-predicting
  4.1×; post-fix dynamics *exceed* static everywhere. That is a finding about the static
  solver, not a footnote.

---

## Save discipline — standing rules for agent sessions

Context: the v7 session was cleaned up mid-run and its output was initially reported
lost (it wasn't — the CSV had flushed); the Phase 1 doc now contradicts a CSV written
3 hours after it. Both are persistence failures, not physics failures.

1. **CSV first, prose second.** A result exists when its CSV is on disk with a correct
   provenance header — not when it's in a session log or chat table. Write each row/
   scenario immediately on completion (repo guideline #5), never batched at exit.
2. **Commit at every gate boundary.** After each builder completes: `git add` its CSVs
   + `git commit`. A cleaned-up session must cost at most one in-flight builder, never
   completed results. Long runs: `nohup`/`tmux` with output redirected to a logfile in
   `scripts/results/`, so the log survives the session.
3. **Docs are generated, not typed.** Any table in a `docs/` file that reports run data
   must be produced by an idempotent script reading the CSVs. Re-running data ⇒ re-run
   the generator ⇒ doc cannot desync.
4. **End-of-session exit checklist** (run before ending ANY session that produced data):
   - `git status` — no untracked CSVs or modified scripts left uncommitted
   - every new CSV has a provenance header matching `git rev-parse --short HEAD`
   - handover note in `handovers/` if work is in flight (what's running, expected
     outputs, how to verify completion)
   - DECISIONS.md entry if any conclusion changed
5. **Never overwrite superseded data — move it.** Tier-X pattern is correct: relocate,
   annotate, retain. Overwriting the 16:23 reinforced CSV in place (rather than moving
   it to tier-X first) is what made the biased/corrected timeline hard to reconstruct.

---

**Gate for Phase 2:** P0 and P1 complete, plus the k-refinement rows in P2.
Re-ranking a DE campaign on data whose λ=0.69 verdict is ambiguous and whose provenance
can't distinguish biased from corrected physics would rebuild on sand.

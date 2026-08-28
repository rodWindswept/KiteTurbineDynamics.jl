# Handover: 2026-08-28. 5 kW rotorcount campaign complete, all winners gated

**From:** desktop Hermes session (campaign launch + post-run).

**To:** next session (and Rod, for three decisions in §5).

**State:** the 3-island 5 kW rotorcount campaign ran to completion. All islands
reached gen 30 and exited 0. All three winners pass the independent ODE gate.

The global best (island 1, fitness 9.618 kg) is instrument-valid. Its 4.43 kg
airborne mass is below the Daisy anchor (phi 0.886 vs 1.3). The mass-model
audit is the open physics question before the design counts as verified.

Two local commits are not pushed (`7524a90`, `d2cd655`). Nothing runs.

---

## 1. What happened this session

1. **Pre-launch verification.** Followed runbook
   `docs/plans/2026-08-27-campaign-launch-runbook.md`. power_split = 0.6 is
   consistent everywhere (ObjectiveConfig default, gate, smoke, sweep script).

2. Smoke re-run on HEAD gave `SMOKE: ALL PASS` (P_mean 5.12 kW, FoS 10.63,
   T rel 0.00%, m_airborne 48.69 kg). The Deepseek harness already archived the
   VOID dir (`archive_void_20260825_rotorcount/`). Output path was clear.
   No orphan julia procs. 32 cores / 58 Gi free.

3. **Committed the tracked VOID.md deletion** (`7524a90`). The archive itself
   stays untracked per convention.

4. **Launched the 3 islands in parallel** (runbook §3, Hermes background jobs,
   `--compiled-modules=existing`,
   `JULIA_DEPOT_PATH=$PWD/.julia_depot:$HOME/.julia`). All completed exit 0.

5. **Combined** (`combine_islands_v13.jl --length 18.8`). Global best = island 1.

6. **Re-gated ALL THREE winners** with `ode_gate_v13.jl`. All PASS (table §3).

7. **Instrument fault found + fixed (commit `d2cd655`).**
   `scripts/analyze_campaign_winners.jl` silently analyzed the PREVIOUS
   campaign. Its default path pointed at `v13_5kw_masslift_len18.8` (no
   `_rotorcount`). It also decoded with the legacy bitmask/full-cone path (no
   `rotor_count_mode`, `power_split`, `blocking_factor`).

8. The first run reported stale-era masses (3-6 kg). Treat those numbers as
   void. Fixed: island_N/ subdir glob + campaign-knob decode (mirrors `eval_v13`
   / `gate_design`). The re-run now matches gate and telemetry.

9. **Wrote `regate_verdict.md`** in the campaign results dir (provenance, table,
   verdict, disposition).

## 2. Wall times and pacing

| Island | Wall time | Best fitness (kg) |
|---|---|---|
| 1 | 16.8 h | 9.618 |
| 2 | 27.2 h | 11.021 |
| 3 | 24.0 h | 37.911 |

Actual eval pace is about **195 s/eval, which is 2.2× the runbook 87 s/eval
estimate**. The 7-9 h projection in the runbook was wrong. Next campaigns at
this config should plan 17-28 h per island. The 5 kW benchmark table in the
skill (~373 s/eval at 40 s window) is the better prior.

## 3. Winners (all gate PASS, all twist_crossed=false, tip sanity ok)

| Island | fitness kg | P_end kW (eval) | FoS | clear. m | gate P_gen kW | ω_gnd | n_lines/rings/n_active | r_hub m | m_airborne* kg | phi kg/kW |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 global best | 9.618 | 5.14 | 17.6 | 5.91 | 5.31 | 13.33 | 3/6/1 | 4.16 | 4.432 | 0.886 |
| 2 | 11.021 | 5.46 | 16.7 | 5.91 | 5.65 | 13.62 | 3/6/1 | 4.155 | 5.835 | 1.167 |
| 3 | 37.911 | 5.37 | 27.0 | 3.25 | 7.45 | 14.93 | 7/8/3 | 2.385 | 32.477 | 6.495 |

\* no-lifter airborne mass (analyze decode, now campaign-aligned). Fitness =
airborne incl. lifter. No FoS=Inf on any ok row in any island telemetry.
Inf appears only on reject/reject_twist rows. The guard works.

## 4. Findings worth carrying

- **n_active=1 dominates again** (islands 1 and 2). This is the third campaign
  with the pattern. Record it as a design conclusion, not an exploit. Single
  rotor wins at 5 kW / 18.8 m under mass fitness.

- **Island 3 settle-gap decay.** Gate reads 7.45 kW flat (5-30 s). Evaluator
  tail5 reads 5.37 kW (45-50 s). This is the known settle-ω overshoot workstream
  (`docs/plans/2026-08-22-settle-ode-gap-workstream.md`). It passes both
  instruments, but its true sustained margin is thin.

- **The DE split the space by rotor count.** Light single-rotor designs
  (phi ≤ 1.17) vs heavy 3-rotor (phi 6.5). Global-best fitness is the
  single-rotor corner.

## 5. Open items for Rod (decision queue)

1. **Mass-model audit (gating the winner).** Island 1 claims m_airborne 4.43 kg.
   Geometry: r_hub 4.16 m, 6 rings, Do 0.03, t/D 0.0275, 3 lines. A crude
   CFRP-tube estimate for the ring set alone is about 2.6× that. The ODE power
   (5.1-5.3 kW) and FoS (17.6) are instrument-level passes. The mass law at
   this big-hub/small-tube corner is the open physics question. Do NOT seed
   the 7 kW rung with island 1 before this.

2. **Acceptance re-baseline** (runbook §7,
   `docs/plans/2026-08-22-acceptance-rebaseline.md`). Go/no-go, pending item 1.

3. **Push to origin.** Two local commits: `7524a90` (chore VOID.md removal) and
   `d2cd655` (analyze fix + regate verdict). Telemetry CSVs stay untracked per
   convention. Say the word to commit + push them for inspection.

## 6. Repo hygiene

- Committed, NOT pushed: `7524a90`, `d2cd655`. Master is 2 ahead of origin.

- Untracked, leave alone: `scripts/results/v13_5kw_masslift_len18.8_rotorcount/`
  CSVs, `archive_void_20260825_rotorcount/`,
  `scripts/results/preview_genome.png`, `.claude/worktrees/*`.

- I committed `regate_verdict.md` as a single-file add inside the untracked dir.

- NOTE: live handovers live at repo ROOT `handovers/`, not `docs/handovers/`.
  The ktd-desktop-workflow skill still says `docs/handovers/`. That is stale.
  Only the three Aug-9 docs live there. NAS `_hermes_brain` had nothing newer
  than July.

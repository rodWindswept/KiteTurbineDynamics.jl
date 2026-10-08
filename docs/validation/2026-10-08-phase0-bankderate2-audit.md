# bankderate2 Phase 0 audit — dataset integrity, winner reproduction, instruments (2026-10-08)

Author: software-validator. Second read: science-validator (signed 2026-10-08, see block below).

Scope: Phase 0 of `docs/plans/2026-10-08-genome-landscape-analysis.md`. This audit covers the 930-eval bankderate2 dataset. No lever analysis starts before this record signs.

Dataset: `scripts/results/v13_5kw_masslift_len18.8_rotorcount_bankderate2/`. 3 islands, 30 DE generations plus seeds. 310 rows per island, 930 rows total.

## Second read (2026-10-08, science-validator): SIGNED

I re-derived this audit from the branch artifacts alone. My census script recomputed the checks from the 930 CSV rows. Seventeen of eighteen pass. The one miss is a wording fix, item (1) below. I re-ran the winner genome standalone on my own seat. My run reproduced every field to the last bit. The fitness reads 27.3635412663488. P_mean reads 5.3087794439367935. FoS reads 14.971791422208508. T_lift reads 324.1250954336462.

The recovered fields match the record as well. Those fields are ω_eq, P_range, util_a, util_b, stationary, drifted and line_broken. The decomposition closes at 0.0 exactly. The terms read mass 25.69846825623688 + overpower 0.49333696413175443 + utilisation 0.5576509889014662 + twist 0.6140850570787014. The source citations read as stated. Guard at objective_v12.jl:149. Twist term at objective_evaluator.jl:1200-1203.

Two wording fixes, no verdict change. (1) Section 5: island 2 did draw bank_top below 10.26, in 13 rows, minimum 1.7333. Twelve of those draws died. One survived at 10.2584, the island-2 best row. Surviving coverage still starts at 10.26.

(2) Section 6: test_fos_guard.jl carries 17 assertions in two testsets. Ten of them target the non-finite class.

Two precision notes, no action owed. Island 1 draw coverage reaches r_hub 0.7, so 2.399 is its surviving-row minimum. PROVENANCE.md quotes blocking_factor 1.0 from the 2026-08-25 re-seed. The runner config reads 0.85^(1/3).

The header line and the trust-log row now read signed. Phase 0 closes. Phase 1 may start. Open item: the trust-log STE sweep or exemption stays with @hermes. Evidence: scratch/sv_p0_secondread_census.py, scratch/sv_p0_secondread_census.txt and scratch/sv_p0_secondread_winner_reeval.log.

## 1. Landing record (item 1)

| Item | Value |
|------|-------|
| Branch | `bankderate2-results`, cut at launch commit `a76c5e9`. Not on the detached HEAD |
| Data commit | `dd3cc6a`. 21 files, 1089 insertions |
| Push | `dd3cc6ad0245286046f3b9e0a2c21dfcc95a6b26` on `origin/bankderate2-results` |
| Provenance stamp | era `post-95c385d_wind-authority`, k = 2.24 (`K_MPPT_5KW_HONEST`), window 40 s, FoS 2.5 / 2.5 |
| Sensors | `check-provenance.py` exit 0 on 14 CSVs. `ste-lint.py` reads 1.40 per 100 words |
| Exclusion | The `.julia_depot` symlink is not in the tree |

Run-log note: `PROVENANCE.md` cites one run log per island. Those files never existed. The fire command ran without the tee step. The runner only records the `--log` path.

The stdout of the runner survives in three process records on the aero-worker seat. The record ids are `proc_9f49e2cde2f0`, `proc_5cff268cf54d`, `proc_0c2023b5f0a1`. Each carries exit code 0 and the line `Island N complete in ...s`. The durations read 22478 s, 18614 s, 21517 s. This audit treats the records as the run-log surrogate. Rule for future runs: the fire command must write its log, not only name it.

## 2. Gen-0 / gen-1 discontinuity check (item 2) — none found

The gen-0 population is one clamped seed plus nine uniform draws per island. Source: `run_v13_5kw_masslift.jl:327-332`, RNG `seed!(42+island-1)`.

| Band | Rows | ok | reject | clearance | twist | ok rate |
|------|------|----|--------|-----------|-------|---------|
| gen 0 (seeds) | 30 | 3 | 17 | 10 | 0 | 10.0 % |
| gen 1+ (children) | 900 | 505 | 284 | 100 | 11 | 56.1 % |

- The bare seed row is identical in all three islands. Fitness 36.109, P_mean 5.85 kW, FoS 13.34, T_lift 415.81 N. Three separate island processes give the same numbers. That is a free determinism spot-check.

- The P_mean of the seed is 5.85 kW. That value sits inside the child band of 5.02 to 6.32 kW. There is no step change and no uniform metric. The instrument-floor pattern — a metric flat across conditions that should move it — is absent.

- Early generations carry most of the rejects. Island 1 has no passing child before gen 6. The first child pass is gen 2 for island 2, and gen 1 for island 3. Passing rows fill in from gen 6. They reach the full ten per generation in the later teens. This is exploration progress, not an instrument artifact.

- `k_chosen` is not a per-row field. k is fixed for the whole campaign at 2.24, in the provenance header. `P_range` and `stationary` are not recorded (see item 3). The archive-level proxies are the status mix above and the per-gen mean P_mean. Both live in `scratch/sv_p0_items256_census.txt`.

## 3. Destructure check (item 3) — partial capture

The evaluator returns a 15-field `ObjectiveResult`. The telemetry logger records eight of the fifteen fields.

| ObjectiveResult fields | Status |
|------------------------|--------|
| status, fitness, P_mean, FoS_min, T_lift, P_end, twist_crossed, twist_ratio | recorded (8) |
| ω_eq, P_range, drifted, stationary, util_a, util_b, line_broken | **not recorded (7)** |

The logger adds clearance, ten decode fields, and the ten raw genes. Raw genome coverage is full on every row.

Row completeness: every generation has exactly 10 rows on every island. The total is 31 gens × 10 × 3 = 930. Rows flush per evaluation. A killed run keeps complete rows. No `timeout`, `error`, or `no_active` rows exist in this dataset.

Consequence: the item-2 metric names `P_range` and `stationary` have no archive column. The item-4 re-evaluation recovered them for the winner (section 4). If Phase 1 or 2 needs these fields for more rows, add them to the next logger. A per-candidate re-evaluation is the only archive-level recovery. It costs about 45 s per candidate.

Score composition: the recorded fitness includes the twist term of the evaluator. That term lives in `objective_evaluator.jl:1200-1203`. The evaluator adds it after the scorer seam. A code comment records the rule as "LIVE for every objective".

The fitness of the winner decomposes exactly. Mass 25.698468 + overpower 0.493337 + utilisation 0.557651 + twist 0.614085 = 27.3635412663488. The difference is 0.0. The scorer docstring in `objective_v12.jl` calls the twist wiring a follow-on. That note is stale. The wiring lives in the evaluator.

Reject rows: all 422 non-ok rows carry the sentinel fitness 1.0e9. That is the runner mapping in `eval_v13`. No other sentinel value appears. The DE never compares a reject against an ok row.

## 4. Standalone winner re-evaluation (item 4) — exact reproduction

Winner: island 3, found gen 26, genome from `best_vector.csv`. The audit re-evaluated the genome standalone at commit `dd3cc6a`. The code delta `a76c5e9..dd3cc6a` is empty for `src/` and `scripts/`. The commit only adds data.

The run used the launch-commit code. Probe: `scratch/sv_p0_winner_reeval.jl`. Output: `scratch/sv_p0_winner_reeval.txt`. The run used `scripts/ktd-julia`. Evaluation wall time 44.2 s.

| Field | Recorded | Re-evaluation | Verdict |
|-------|----------|---------------|---------|
| status | ok | ok | match |
| fitness | 27.364 (telemetry, 3 dp). Full value in island meta | 27.3635412663488 | match to 16 digits |
| P_mean | 5.31 | 5.3087794439367935 | match |
| P_end | 5.31 | 5.314113662272673 | match |
| T_lift | 324.13 | 324.1250954336462 | match |
| FoS_min | 14.97 | 14.971791422208508 | match |
| twist_crossed / twist_ratio | false / 0.4393474253185575 | same | match |
| clearance | 5.47 | 5.468124 | match |
| decode | 3 lines, 6 rings, 1 active, r_hub 4.580, r_bot 0.804 | same | match |

Recovered unrecorded fields (winner only): ω_eq = 10.169820334285198. P_range = 0.028659374428010587, or 0.54 % of the mean. That is steady and far below the 10.0 limit-cycle bound. stationary = true, drifted = false, line_broken = false. util_a = 0.06679174086635262, util_b = 5.334714158942919e-7. Physics mass = 25.69846825623688 kg.

**No row is void.** The recorded genome reproduces the recorded score.

## 5. Cross-island overlap check (item 5) — overlapping, no instrument anomaly

Identical config and bounds imply overlapping distributions. Every pairwise overlap is non-empty.

| Metric | Island 1 | Island 2 | Island 3 |
|--------|----------|----------|----------|
| ok rows | 152 | 162 | 194 |
| P_mean (kW) | 5.02–6.26 (mean 5.733) | 5.05–6.09 (mean 5.726) | 5.02–6.32 (mean 5.696) |
| fitness | 30.58–60.65 (mean 34.79) | 30.64–45.90 (mean 33.81) | 27.36–44.85 (mean 33.32) |
| FoS | 3.18–14.51 | 5.82–14.53 | 5.10–15.32 |

Means sit within 0.7 % for P_mean and 4.4 % for fitness. Coverage differences follow the RNG paths. Island 1 explored r_hub down to 2.399 m. That pocket holds the two surviving 2-rotor rows. Count only — that is a Phase 1 question, not a lever claim.

Island 2 never drew bank_top below 10.26°. No island is disjoint. So there is no instrument suspicion.

## 6. FoS = Inf guard census (item 6) — guard present, survivors clean

| Class | Rows | FoS reading |
|-------|------|-------------|
| ok | 508 | finite, 3.18–15.32. No zero, no value above 1e4 |
| reject | 301 | 100 finite (0.02–15.3), 201 Inf |
| reject_twist | 11 | Inf |
| clearance_reject | 110 | NaN (simulation never ran) |

All 322 non-finite FoS readings live in rejected classes. No surviving (ok) row carries a non-finite FoS.

The guard sits at the score seam. The form is `(!isfinite(FoS_min) || FoS_min < cfg.fos_hard) && return Inf` (`objective_v12.jl:149`). The test `test/test_fos_guard.jl` carries 10 assertions.

A null structural measurement cannot pass the floor. An Inf FoS on a reject row reads as "unmeasured". The design failed a gate anyway, on the power floor, the twist gate, or the FoS gate. Nothing to fix. The census confirms the field behaves as designed.

## 7. Verdict

**PASS — the dataset carries analysis, subject to the science-validator second read.** The 930 rows are internally consistent. The winner reproduces exactly from the recorded genome. No discontinuity and no island anomaly exist. No non-finite FoS reaches the surviving set.

Recorded limits: (1) the cited run logs do not exist — stdout surrogates carry the timings. (2) Seven `ObjectiveResult` fields have no archive column. (3) Fitness includes the twist and stationarity terms of the evaluator. None of the three touches the recorded values.

Evidence: `scratch/sv_p0_items256_census.py` (+ `.txt`), `scratch/sv_p0_winner_reeval.jl` (+ `.txt`). Data: `dd3cc6a` on `bankderate2-results`.

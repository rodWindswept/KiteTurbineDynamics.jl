# Handover — 2026-08-05 Stationarity Audit

**Scope:** audit of the `stationary=false` on 42/42 result in
`scripts/results/recampaign/feasibility_phase_a_v2.csv`. Source read + CSV
forensics only — no Julia executed (sandbox has no Julia). Every claim below is
re-derivable from the committed CSV and `src/objective_v11.jl` at `1d76492`.

## Headline

**"0 of 42 designs converged" is not a finding.** For 37 of the 42 rows the
stationarity gate is structurally incapable of returning `true`. The flag is
uninformative there. For the 5 rows where it *was* reachable it failed
genuinely, and hard.

Underneath that artefact sits a worse problem the flag was hiding: **25 of 42
rows are not simulations of anything.**

## 1. The gate cannot fire below 100 W

`src/objective_v11.jl:503-505`:

```julia
P_steady   = P_mean > 0.1  ? P_range / P_mean < 0.20 : false
FoS_steady = FoS_min > 0.01 ? FoS_range / FoS_min < 0.20 : false
stationary = dP < 0.10 && dF < 0.10 && P_steady && FoS_steady
```

The `: false` else-branch is unconditional. Any design under 0.1 kW is stamped
`stationary=false` no matter how perfectly settled it is. There is also an outer
guard at `:492`, `mean(P1) > 0.01`, which kills the whole block below 10 W.

| Population | Count | Consequence |
|---|---|---|
| P_mean ≤ 0.01 kW | 36 / 42 | outer guard fails — gate block never entered |
| P_mean ≤ 0.10 kW | 37 / 42 (88%) | `P_steady` hardwired `false` |
| FoS_min ≤ 0.01 or non-finite | 25 / 42 | `FoS_steady` hardwired `false` |

So `stationary=false` on the low-power population is a restatement of "P≈0",
which `P_mean_kw` already tells us. It carries no independent information about
whether the integrator converged.

**A converged, stably-stalled machine and a diverged one are recorded
identically.** That is the defect.

## 2. Where the gate *was* reachable, it failed on amplitude

Five rows have P_mean > 0.1 kW. All five fail the amplitude test, none fail on
drift:

| P_mean (kW) | P_range (kW) | ratio | threshold | FoS_min |
|---|---|---|---|---|
| 8.643 | 7.138 | 0.826 | 0.20 | 0.707 |
| 6.559 | 7.020 | 1.070 | 0.20 | 2.863 |
| 2.354 | 9.210 | 3.913 | 0.20 | 0.509 |
| 0.574 | 8.514 | 14.846 | 0.20 | 0.299 |
| 0.150 | 0.108 | 0.721 | 0.20 | 2.266 |

Misses of 4× to 74×, not marginal. **The handover's headline "P=8.6 kW" is a mean
over a trace whose peak-to-trough swing is 83% of that mean.** Quoting it as a
power figure is not defensible.

## 3. The 25 dead rows

25 of 42 rows have `FoS_min = Inf`, `util_axial = -1.0`, `omega_eq_rpm = 0`,
`P_mean = 0`, `P_range = 0`. Rotors that never turned. `FoS = Inf` because
`fos_samples` was empty or all-Inf (`objective_v11.jl:231`) — infinite structural
safety reported by a structure carrying nothing.

**This invalidates the "structure is adequate" reading.** The 35/42 with FoS ≥ 1.5
is 25 `Inf` sentinels plus 10 real values. Of the 32 genuinely quiet rows, only
7 have a finite FoS at all. 25 of 37 sub-100 W rows sit at exactly 0 rpm.

The campaign did not establish that power is the binding constraint. It
established that ~60% of the sampled space produces machines that never spin up,
and that the instrument cannot distinguish "didn't spin" from "spun safely".

## 4. A5 verified closed in production data

The `Inf`-FoS rejection band holds. All 25 dead rows score `f_feas = 12.0`;
honest stalls span 10.65–11.0. No dead row outranks any real design. The
exploit-register entry is closed against live campaign output, not just tests.

## 5. Latent hazard — sentinel collision (did NOT fire this run)

`run_feasibility_phase_a.jl:70-73`, the `catch` block returns `f_feas = 11.0`.
That is exactly the score of a legitimate `P_mean = 0` stall
(`10 + (25-0)/25 = 11.0`). A thrown exception is therefore indistinguishable
from an honest stall by score, **and ranks better than the 12.0 rejection band** —
crash beats dead sim.

Verified clean in this run: `k_chosen == 0.0` on 0 rows, `lift_tension_N < 0` on
0 rows, so no exception was swallowed. Fix before the next campaign: return 12.0
(or higher) from the `catch`, and log `e` rather than discarding it.

Related: `tier` is computed independently of the `Inf` guard
(`run_feasibility_phase_a.jl:74`), so all 42 read `"stalled"` — the tier label
loses the rejection category that `f_feas` preserves.

## 6. Leading hypothesis for the amplitude failures

`WARM_RELAX_S = 10.0` (`objective_v11.jl:239`) is **one third** of the cold path's
`DISCARD_S = 30.0` (`:44`). A design whose start-up transient outlasts 10 s is
still decaying across the entire 30 s warm-start measurement window, which
inflates `P_range` and makes the 0.20 amplitude test unpassable for numerical
rather than physical reasons.

The window's own comment — *"shorter — signal is in departure"* — says it was
tuned to detect **leaving** a state. A stationarity gate on that same window
demands the opposite. Those two intents are in direct conflict.

This is a hypothesis, not a conclusion. It is testable, and the test is written.

## Changes made this session

| File | Change |
|---|---|
| `src/objective_v11.jl:239-240` | `WARM_RELAX_S` / `WARM_WINDOW_S` const → `Ref`. Defaults identical (10.0 / 30.0); behaviour unchanged unless set. Refs rather than env-read consts specifically to dodge the precompile-cache trap. |
| `src/objective_v11.jl:357,368` | deref `[]` at the two use sites |
| `scripts/diagnose_relax_sensitivity.jl` | new — the test below |

## Next action (desktop — sandbox has no Julia)

```bash
cd ~/Documents/GitHub/KiteTurbineDynamics.jl
rm -f ~/.julia/compiled/v1.12/KiteTurbineDynamics/*.ji \
      ~/.julia/compiled/v1.12/KiteTurbineDynamics/*.so
julia --project=. test/runtests.jl                        # confirm 1859/1859 still green
julia --project=. scripts/diagnose_relax_sensitivity.jl
```

Re-scores the 5 reachable genomes at `WARM_RELAX_S ∈ {10, 30, 60, 120}` s,
window fixed at 30 s, canonical path otherwise untouched. Progressive CSV save
after every eval; resumable by `(genome_hash, relax_s)`.

Reading the output:

- **ratio collapses under 0.20 as relax grows** → artefact. Raise `WARM_RELAX_S`
  to at least `DISCARD_S` and re-run Phase A. The current 42 rows cannot support
  any physics conclusion.
- **ratio flat and high** → physical surge. `stationary=false` is real for those
  5 rows. The other 37 stay uninformative regardless.
- **P_mean itself shifts materially with relax** → every kW figure in the CSV is
  window-dependent and none can be quoted.

Budget: 4 settings × 5 genomes × 3 k-bracket evals, at 10–20 min per warm-start
eval under GC pressure. The 120 s setting dominates.

## Independent of the outcome

1. Fix the `P_steady` / `FoS_steady` else-branches so a settled zero-power design
   reports `stationary=true`. Convergence and productivity are different
   questions and must not share a flag.
2. Give `FoS = Inf` from an empty sample set its own CSV column or tier label.
   `f_feas = 12.0` catches it in ranking, but the tier string still says
   `"stalled"` and the FoS column still says `Inf`, which is what let "35/42 have
   FoS ≥ 1.5" get written down.
3. Raise the `catch` sentinel above the rejection band and log the exception.

## Carried forward from 2026-08-04 (unaffected by this audit)

- Init-path divergence: `settle_to_operational_state` blows up (NaN hub_z,
  ω≈1e141) where `warmstart_with_k_bracket` reports 8.6 kW. Still open, and now
  more urgent — §2 shows the warmstart figure was never trustworthy either.
- B1 dt refinement at dt, dt/4, dt/10 on 3 blowup genomes.
- Lift device: PCA-2 vs CoAx BEM discrepancy, orders of magnitude. The 638 N is a
  hard-coded assumption in every row, and `ring_forces.jl:390-392` exempts
  `RotaryLifterParams` from the 2 m/s passive stall cut-off, so the lifter cannot
  stall in-model.
- Dashboard `--genome-csv` ArgParse registration.

## Handover-vs-CSV conflicts — do not quote `handover-2026-08-04-session.md` numbers

1. Says best genome `k_mppt = 0.01` and "DE converged on zero torque extraction".
   CSV `k_chosen` spans 12.3–1000 with no row below 1.0; best row is k=461.
   Unsupported by this file.
2. Says ω ≈ 25 rad/s for the campaign path. CSV says 39.2 rpm ≈ 4.1 rad/s.
3. Frames solver instability as a best-genome problem. It is a whole-table
   problem, and for 37 rows it is not a solver problem at all — it is a gate
   that could not fire.

# Handover: the bank derate is applied. The 5 kW campaign needs a re-baseline.

Date: 2026-10-01. Machine: `rodbot-ThinkPad-P1-Gen-3` (laptop, 12 threads, 30 GB).
Repo: `KiteTurbineDynamics.jl`.

## 1. What changed

The bank angle of the topmost rotor now costs power in the model. It did not before.

`RotorSpec` gained a `bank_angle_deg` field. The builder reads that angle from the
topmost rotor in the genome (`src/objective_evaluator.jl`). A new testset in
`test/test_ring_forces.jl` guards the factor.

The factor sits at EVERY site that computes the main rotor disc power. Miss one and the
settle and the ODE find different equilibria.

| Site | What it feeds |
|---|---|
| `src/ring_forces.jl` | the ODE disc branch |
| `src/initialization.jl`, `settle_aero_power` | the cold-start settle scan |
| `src/sim_frame.jl`, the torque balance | the static predictor |
| `src/sim_frame.jl`, the per-rotor power | the `capture_extended` power vector |

To find them all, grep the exponent: `grep -rn "2\.65" src/`. Every site that carries the
elevation factor needs the bank factor beside it. That grep is the completeness check.

We measured the exponent, we did not choose it. The AeroDyn precone sweep of
2026-09-30 gives a 20° bank a retention of **0.854** at the Cp peak. `cos^2.65`
predicts **0.848**, which is a match to 0.7 per cent. `cos^3` (Tulloch Eq. 4.1)
predicts 0.830, so that form is the conservative alternative. The full method, budget
and caveats sit in `docs/validation/trpt-reference/10-precone-sweep.md`. The
blade-count check sits in `11-blade-count-sweep.md`.

Three other models were considered. All three are wrong for this ring.

| Model | Retention at 20° bank |
|---|---|
| bare disc, no bank factor | 1.000, which is 15 per cent optimistic |
| **disc times `cos(bank)^2.65`** | **0.848, the rule in use** |
| the banked expansion model | 0.147, which brakes, and is 5.8 times too low |

## 2. The state of the tree

- `src/` carries the derate. `test/test_ring_forces.jl` carries the guard.
- The fast suite is green at 2406 of 2406.
- `test/test_banked_top_rotor.jl` remains unregistered. It encodes the reverted top-ring
  rule, so do not re-enable it.

## 3. What is red, and why that is correct

The campaign winner at
`scripts/results/v13_5kw_masslift_len18.8_rotorcount/best_vector.csv` carries
`bank_top = 19.95°`. It is one rotor on ring 6 of 6, so the derate applies to its only
rotor.

| | before the derate | after |
|---|---|---|
| `P_gen_final` | 5.461 kW | **4.888 kW** |
| `omega_gnd_final` | 13.46 rad/s | 12.97 rad/s |
| clearance | 5.7275 m | 5.7275 m |
| twist ratio | 0.4978 | 0.4674 |

The whole power drop is the fall in shaft speed. `4.888 / 5.461 = 0.895`, and
`(12.97 / 13.46)^3 = 0.895`. Nothing collapsed.

That figure is below the 5.0 kW floor asserted by three acceptance tests:

- `test/test_gate_v13.jl` A1. The winner must pass the gate, and `ok=false` now.
- `test/test_evaluator_v13.jl` B6c. The winner must still deliver at least 5.0 kW.
- `test/test_settle_drag_alignment.jl` D. The 20 s gate must clear 5.0 kW, and it reads
  4.816 kW.

All three are the same fact seen from three directions, not three separate faults. The
measured acceptance run of 2026-10-01 gives **6 of 9 files passing**.

So **the acceptance suite is red on those three assertions, and it should be.** They
state a true fact about the design under the corrected model. They are not broken
tests. Do not re-baseline the assertions downward. The floor is the target.

**Treat the pre-derate campaign as superseded, not void.** It searched a design space
in which bank was free, so it selected designs that lean on un-banked performance. The
fix is a re-baseline, which is the job below.

## 4. The job

Re-run the 5 kW campaign under the corrected model. Then point the acceptance at the
new winner.

```
# On the desktop. Three island processes in parallel, one per core group.
scripts/ktd-julia scripts/run_v13_5kw_masslift.jl \
    --length 18.8 --tag bankderate --island 1 --gen 30 \
    --log .julia_depot/logs/v13_bankderate_island1.log
# repeat with --island 2 and --island 3
```

Pass `--tag bankderate` so the pre-derate results stay untouched. The runner prepends
the underscore, so the bare tag produces `..._rotorcount_bankderate`. Never run the new
campaign into `v13_5kw_masslift_len18.8_rotorcount`.

Then combine the three islands into one winner:

```
scripts/ktd-julia scripts/combine_islands_v13.jl --length 18.8 --tag bankderate
```

The campaign runs `popsize = 10`, `n_islands = 3`, `max_iter = 30`. That is 900
evaluations, which splits cleanly three ways.

Before you launch, set `PHYSICS_ERA` in the runner to the derate commit. The current
value, `post-4ce9fd0_daisy-anchored-5kw`, names the era that had no bank cost. A result
stamped with it after today would carry a false label. Use the short hash of the commit
that lands the bank factor in `src/ring_forces.jl`.

## 5. Why the desktop

This machine is a ThinkPad P1 Gen 3. It carries 12 threads, 30 GB of memory and a
Quadro T1000 Mobile. The desktop carries 62 GB and an RTX A4500 with 20 GB. The
campaign is CPU-bound and memory-hungry at three islands, so the desktop should take it.
Both machines share the repo. Pull first, then commit and push from the machine that
runs the campaign.

## 6. How to tell it worked

1. An island reports a best fitness at or above the floor with the bank costed in.
2. `test/test_gate_v13.jl` A1 returns `ok=true` for the new winner.
3. `test/test_evaluator_v13.jl` B6c reads at least 5.0 kW for the new winner.
4. The acceptance suite returns to 9 of 9.

Then update the winner path in `test/test_gate_v13.jl` and
`test/test_evaluator_v13.jl` to the new `_bankderate` directory. Record the era change
in `DECISIONS.md`.

## 7. Gotchas

- **Do not lower the 5.0 kW floor.** The derate matters precisely because the old
  winner does not reach the floor. A lower floor hides that fact.
- **Do not re-enable `test/test_banked_top_rotor.jl`.** It asserts the reverted top-ring
  rule, which brakes the machine. See
  `docs/plans/2026-09-30-top-ring-brake-findings.md`.
- **The THRUST of a banked rotor has no measured derate.** The sweep measured Cp only.
  Do not copy the 2.65 exponent onto `ct_at_tsr`.
- **The derate is not flat across TSR.** At commanded lambda 6.0 a 20° bank retains only
  0.331. The design point of the campaign sits near lambda 4 to 5, inside the flat
  region. A winner that drifts off the peak will lose hard.
- **The AeroDyn `RtTSR` column is not the commanded lambda.** If anyone re-runs the
  sweeps, align rows on the commanded lambda. See `10-precone-sweep.md` section 7.
- **The expansion rotors still use a LINEAR `cos(bank)`, not `^2.65`.** The main rotor now
  uses 2.65. If a banked rotor is a banked rotor, those should match, and they do not. The
  precone sweep measured the main rotor's solidity only, so extending 2.65 to the expansion
  annuli is an extrapolation. This is an open question for Rod, recorded in
  `docs/agents/physics-topology.md` section 4.0.1. Do not change it without a ruling.

# 2026-10-01 — Acceptance red inventory on `ee6c64f` (software-validator gate)

Independent verification of the test state after the bank-derate branch was pulled
onto the desktop, before the rebaseline campaign result lands.

**Revision gated:** `ee6c64f1ededb031e62b9c24f5ddca836f558768` —
`HEAD == origin/bank-derate-cos2p65`; no modified tracked files (`git status --porcelain`
shows only untracked result dirs).

## 1. Fast unit suite — GREEN

`scripts/ktd-julia test/runtests.jl` → **2406 / 2406 pass, 3 m 44 s, exit 0**
(`.julia_depot/logs/sv_fast_suite.log`). `test_ring_forces.jl` is wired in
(`test/runtests.jl:29`), so the four-site bank-derate guard ran and passed.

## 2. Slow acceptance suite — 6 of 9 files, 4 red checks

`scripts/ktd-julia test/acceptance_runtests.jl` (all nine files, parallel),
launched 13:37:50, last file exited 13:55:

```
FAIL  test_evaluator_v13.jl  (exit 1)
FAIL  test_gate_v13.jl  (exit 1)
PASS  test_rope_break.jl
PASS  test_rotor_power_realism.jl
FAIL  test_settle_drag_alignment.jl  (exit 1)
PASS  test_settle_lowk_honest.jl
PASS  test_physics_path_ode.jl
PASS  test_jtheta_no_reversal.jl
PASS  test_trpt_drag_torque_balance.jl
```

The three red files are exactly the three the handoff names. **The red checks are not
three — they are four.** Each file was re-run individually to capture the detail the
parallel harness drops:

| file | red checks | green checks | measured on `ee6c64f` |
|---|---|---|---|
| `test_gate_v13.jl` | **A1** | A2, A3, A4, A5 | `ok=false`, `P_gen_final = 4.888 kW`, `ω_gnd_final = 12.97`, clearance 5.73 m |
| `test_evaluator_v13.jl` | **B6a, B6c** | B1, B2, B3, B4, B5, B6b, B7 | `status=:reject`, `P_mean = 4.68 kW`, `FoS_min = 12.45`, `fitness = Inf`, hub_tip 68.3 m/s |
| `test_settle_drag_alignment.jl` | **D** | A, B, C, E (8 pass / 1 fail) | `Pf = 4.816104566804309 kW` (asserts ≥ 5.0) |

Logs: `.julia_depot/logs/sv_{gate_v13,evaluator_v13,settle_drag}.log`.

### One cause, four checks

`appropriate_mass_fitness` hard-rejects below the power floor
(`src/objective_v12.jl:150`, `P_mean < cfg.p_floor_kw && return Inf`). The derated winner
measures 4.68 kW against `p_floor_kw = 5.0`, so the evaluator returns `status = :reject`,
and:

- **B6c** fails on its floor conjunct (`r6.P_mean >= 5.0`) — the intended red.
- **B6a** fails on its `status === :ok` conjunct. Its actual invariant — R7 closed-form
  sizing, `FoS ≥ 2.5` — still holds at `FoS_min = 12.45`, so B6a is red by coupling, not
  by a structural regression.
- **A1** fails because the gate reads ground-ring power (`P_gen = τ_gen·ω_gnd`), 4.888 kW.
- **D** fails on `Pf = k_mppt·ω_f³/1000 ≥ 5.0` from the 20 s canonical window.

A known-reds manifest built from the handoff's "three files: A1, B6c, D" line will be wrong
about B6a.

## 3. The winner path lives in three test files, not two

| site | path |
|---|---|
| `test/test_gate_v13.jl:31` | `results/v13_5kw_masslift_len18.8_rotorcount` |
| `test/test_evaluator_v13.jl:38` | `…/best_vector.csv` (`WINNER18V13`) |
| **`test/test_settle_drag_alignment.jl:80`** | `…/best_vector.csv` (`WINNER_CSV`) |

D reads `WINNER_CSV` (line 79–80) and asserts exactly the 5.0 kW floor, so repointing only
the first two leaves D red on the stale genome even after a new winner lands. Also pointing
at the pre-derate directory, outside the acceptance path:
`scripts/analyze_campaign_winners.jl:21`, `scripts/interactive_dashboard.jl:480`.

## 4. Four measuring sticks for one genome

Same pre-derate winner vector, four harnesses on `ee6c64f`:

| harness | statistic | value (kW) | shortfall to 5.0 |
|---|---|---|---|
| `test_evaluator_v13` B6c | `evaluate_windowed`, `tail5`, window 20 s, relax 5 s | **4.680** | −6.4 % |
| `test_settle_drag_alignment` D | 30 k settle + 20 s canonical, `k_mppt·ω_f³` | **4.816** | −3.7 % |
| `test_gate_v13` A1/A4 | gate `P_gen = τ_gen·ω_gnd` | **4.888** | −2.2 % |
| v13 campaign fitness | `evaluate_windowed`, `tail5`, window 40 s, relax 10 s | not measured here | — |

So "island best fitness clears the floor" does **not** imply "the acceptance reds clear".
The binding check is B6c's 20 s tail5 mean: a winner must deliver ≈ +6.8 % over the old
winner *in that harness* to take all four checks green. Read all four numbers at combine
time, not the fitness scalar alone.

## 5. Instrument note

`test/acceptance_runtests.jl` spawns its nine children with inherited stdio through the
parent, and no child output reaches the aggregate log — the captured file was 312 bytes of
PASS/FAIL lines with no failure detail, which is also what CI would show. Redirect each
child to its own log file (done here for the three red files) to keep the failure reason
with the verdict.

## 6. Effect on the running work

None. The rebaseline campaign is the as-implemented data point and its run is unaffected;
this note only fixes what "9 of 9" means at close-out: a winner clearing the campaign floor,
plus the three (not two) winner-path repoints, plus each of A1 / B6a / B6c / D read from its
own harness output.

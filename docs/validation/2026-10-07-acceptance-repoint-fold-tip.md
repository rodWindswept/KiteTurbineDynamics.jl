# Acceptance repoint at the fold tip: the trio closes, and two guard premises move (2026-10-07)

Author: software-validator. Branch: `sv-acceptance-repoint`, cut from `d4f543c`.

This record closes work-division §6 item 2. The repoint points the three winner
paths at the current committed 5 kW design: the S2-class fold seed
(`seed_genome(5.0) == S2_FOLD_SEED`, scripts/compute_seeds.jl, room-approved
2026-10-05). It replaces the rotorcount-era winner CSV. The settle-drag build
and the gate's A3 clamp gain the 10-D-aware branch the forecast names. The two
analysis scripts point at the live output directory, `..._bankderate`.

## Acceptance pass

`scripts/ktd-julia test/acceptance_runtests.jl`, all nine files, parallel, on
this branch. Log: `.julia_depot/logs/sv_repoint_acceptance_d4f543c.log`.
Result: **7 PASS / 2 FAIL**, up from 3 PASS / 6 FAIL at the join.

| file | join run (03:20) | this pass |
|---|---|---|
| test_evaluator_v13.jl | FAIL | PASS |
| test_gate_v13.jl | FAIL | PASS |
| test_settle_drag_alignment.jl | FAIL | PASS |
| test_settle_lowk_honest.jl | FAIL | PASS |
| test_rope_break.jl | PASS | PASS |
| test_rotor_power_realism.jl | PASS | PASS |
| test_jtheta_no_reversal.jl | PASS | PASS |
| test_physics_path_ode.jl | FAIL | FAIL (P2) |
| test_trpt_drag_torque_balance.jl | FAIL | FAIL (radial share) |

The forecast holds. The repointed trio reads green from its own harness
(`aw_fourstick_s2_tip_c657c76.log`: A1 6.107 kW, B6 5.828 kW / FoS 13.63,
D 6.028 kW). `settle_lowk_honest` clears after the D4 clamp release and the
projection threading.

## The two residual reds, attributed

Both files pre-date the repoint. Both were red at the join run, and the repoint
edits neither. Each was re-run at three earlier trees and at the branch tip:

- `f9f3182` (10-03): D1, pre-fold.
- `a82cafd` (10-05): the cp surface, pre-fold.
- `bd5114e` (10-05): the fold seed.
- branch tip: `d4f543c` plus the repoint edits.

### physics_path_ode: P1 closes, P2's premise moved

| arm | P1 | P2 | default | legacy |
|---|---|---|---|---|
| f9f3182 | FAIL | PASS | reject, 3.567 kW, FoS 10.55 | reject, 6.773 kW, FoS 0.97 |
| a82cafd | FAIL | PASS | reject, 3.262 kW, FoS 9.96 | reject, 5.337 kW, FoS 1.18 |
| bd5114e | PASS | FAIL | ok, 5.394 kW, FoS 5.59 | identical |
| branch tip | PASS | FAIL | ok, 6.187 kW, FoS 13.50 | identical |

P1 is healthy at the tip. The seed passes on the default-physics path. Its
D1-class red (the 3.5 kW reject) closes with the re-seed.

P2 guards that the ODE path reads the `EXPANSION_PHYSICS` toggles. Those
toggles have live consumers at expansion-rotor sites only (`expansion_rotor.jl`
and `initialization.jl`; the same consumer set at each arm). The fold moved the
seed from a three-rotor machine to a single-rotor machine. The probe decodes
both genomes at their arms:

| arm | seed | rotors | expansion rotors | rings |
|---|---|---|---|---|
| f9f3182 | the pre-fold genome | 3 | 2 | 13 |
| a82cafd | the pre-fold genome | 3 | 2 | 13 |
| bd5114e and tip | the fold genome | 1 | 0 | 9 |

The toggles have nothing to act on in the fold machine, so LEGACY and DEFAULT
coincide. P2 lost its exercise, not its wiring. The flip sits exactly at the
fold commit: green at both pre-fold arms, red at the fold and after.

### trpt_drag_torque_balance: the radial share

| arm | omega | rotor N·m | drag N·m | drag/rotor | top band share | verdict |
|---|---|---|---|---|---|---|
| f9f3182 | 10.459 | +200.8 | −14.78 | 7.4 % | 103.0 % | PASS |
| a82cafd | 9.717 | +178.7 | −12.98 | 7.3 % | 91.1 % | PASS |
| bd5114e | 10.673 | +664.5 | −13.46 | 2.0 % | 28.7 % | FAIL |
| branch tip | 10.199 | +876.0 | −12.44 | 1.4 % | 23.7 % | FAIL |

The failed check asks the top band, `(Nr-3):(Nr-1)`, to hold more than 60 per
cent of the net drag. The band read 91 to 113 per cent on the pre-fold
machines. The fold machine has 9 rings instead of 13, and its top-ring radius
moves 2.40 to 4.32 m. The machine move recasts the radial split. The four other
conjuncts all pass at the tip: the drag opposes the rotation, stays far below
the rotor torque, sits inside the 5 to 60 N·m bracket, and the rotor delivers.

## Consequence

- The repoint is clean. Its three files close, and nothing else moved except
  for the better.
- The two residual reds are guard-premise moves. The fold retired the machine
  each guard measured. Each guard wants a frozen fixture, following the
  `SEED_LR15_FROZEN` and `SEED_LR20` precedent, so the campaign seed can move
  without unpinning the guard. That is a room call. This record does not
  re-pin anything.

## Evidence

- Suite log: `.julia_depot/logs/sv_repoint_acceptance_d4f543c.log`.
- Solo logs: `.julia_depot/logs/sv_repoint_solo_test_{physics_path_ode,trpt_drag_torque_balance}.log`.
- Arm logs: `.julia_depot/logs/sv_attrib_{f9,cp,bd}_test_{physics_path_ode,trpt_drag_torque_balance}.log`.
- Probe: `scratch/sv_p2_mechanism_probe.jl`. Logs: `.julia_depot/logs/sv_p2_probe_{bd,cp,repoint}.log`. The f9 arm predates `decode_winner`; its seed vector matches the cp arm.
- Fast suite on the branch: `.julia_depot/logs/sv_repoint_fast_d4f543c.log`.

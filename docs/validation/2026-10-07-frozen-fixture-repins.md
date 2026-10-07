# The two fold-retired guards re-pin as frozen fixtures (2026-10-07)

Author: software-worker. Branch: `sw-fixture-repin`. The branch starts at the
gate tip `a76c5e9`. Code commits: `eda1978` (the two guard files), `74ed9c6`
(the P2 re-arm key both-controls pin). The follow-on docs commits carry this
record.

## Why, and by what ruling

Work-division §7 row 11 asked one question. Do the two fold-retired guards
re-pin as frozen fixtures, or stay red? Rod ruled on 2026-10-07. The ruling:
re-pin, with two conditions.

1. Each fixture records the pre-fold and fold values side by side, with the
   fold-decision citation. The re-pin must reverse cleanly the day W5 revives.
2. P2 asserts the byte-identical no-op explicitly. The re-pin keeps the check
   in place.

The fold decision itself: `DECISIONS.md` [2026-10-05], "The 5 kW seed folds to
the S2 class" (the r_hub box re-centres to [0.7, 7.776]).
`docs/validation/2026-10-07-acceptance-repoint-fold-tip.md` attributes both reds
and carries the measurements.

## Fixture 1: `test/test_physics_path_ode.jl`, P2

The `EXPANSION_PHYSICS` toggles have live consumers at expansion-rotor sites
only. The fold machine carries zero expansion rotors, so LEGACY and DEFAULT
coincide. P2 now decodes the seed through the single-authority campaign decode
(`decode_winner`, `scripts/ode_gate_v13.jl`) and counts the expansion rotors of
the built machine. That count is the re-arm key.

- Pre-fold (expansion rotors present): LEGACY must change the result. Measured
  at f9f3182: `3.567 vs 6.773 kW`. Measured at a82cafd: `3.262 vs 5.337 kW`.
- Fold (zero expansion rotors): LEGACY must be inert. The check asserts
  equality across the FULL result surface. That is every `ObjectiveResult`
  field, not only the four summary columns. Measured at bd5114e: `ok
  5.394 kW / FoS 5.59`. Measured at a76c5e9: `ok 6.187 kW / FoS 13.505`.
  Legacy is coincident at both.

The branch is not a static pin. A future seed with expansion rotors re-arms the
differ branch by itself. The W5 rehearsal below exercises that path end to end.

The fixture now controls the re-arm key on both sides (2026-10-07 follow-up,
room agreed before merge). The branch goes green on whichever arm the key
picks, so a mis-keyed predicate would pass by guarding nothing. One
genome-argument copy of the key function drives three reads: the branch, the
positive control, and the negative control.

- Positive: the pre-fold genome, parsed from `SEED_LR15_FROZEN`
  (`test_gate_v13.jl`, no hand-typed digits, the same parse as the rehearsal)
  must read `key > 0`.
- Negative: the fold-seed digits, frozen in the test as `SEED_5KW_FOLD_FROZEN`
  and copied from `seed_genome(5.0)` at the re-pin with provenance, must read
  `key == 0`. Never use the live `seed_genome(5.0)`. A future seed that
  carries expansion rotors reads `> 0` *correctly*, and a live-seed control
  would then red a working machine on the re-arm day this fixture exists to
  absorb.

Both arms pin the contract of the branch (`key > 0` / `key == 0`), not exact
counts. Both are static decodes, with no ODE. The controls close the gap:
until now, the positive arm of the key lived only in the W5 rehearsal log.

## Fixture 2: `test/test_trpt_drag_torque_balance.jl`, the window share

The check measures the window `(Nr-3):(Nr-1)`. The window resolves BY Nr, and
the label now tracks Nr. The pre-fold machine measured rings [10:12]. The fold
machine measures [6:8].

| arm | machine | window | window radii (m) | share |
|---|---|---|---|---|
| f9f3182 | 3 rotors / 2 expansion / 13 rings | [10:12] | n/a | 103.0 % |
| a82cafd | 3 rotors / 2 expansion / 13 rings | [10:12] | 1.1748, 2.4, 2.4 | 91.1 % |
| bd5114e | 1 rotor / 0 expansion / 9 rings | [6:8] | n/a | 28.7 % |
| a76c5e9 | 1 rotor / 0 expansion / 9 rings | [6:8] | 0.7969, 0.7969, 1.6085 | 23.7 % |

The pre-fold pair cleared the 60 % bar the old check asserted. The fold reading
is now the pin: `23.7 % ± 5` percentage points. Two independent probes read
23.702 % exactly at a76c5e9. The margin covers rerun drift. A material radial
re-split moves the reading by more.

The outward concentration never moved. The top ring 9 alone carries 73.3 %
and rings 8 and 9 carry 95.1 %. The pre-fold outer band [10:13] held about
93.7 % (dropping ring 13 cost 2.6 %). The 23.7 % is a window fact, not an
inboard shift.

## Evidence at `eda1978`

- Static pre-flight (include chain, re-arm key, window identity):
  `.julia_depot/logs/sw_repin_static_check.log`. Result: `SW_REPIN_STATIC_OK`.
- P2 solo: `.julia_depot/logs/sw_repin_solo_test_physics_path_ode_eda1978.log`.
  Result: ALL PASS, exit 0. The re-arm key reads 0. The no-op check passes on
  every field of the result.
- Drag solo:
  `.julia_depot/logs/sw_repin_solo_test_trpt_drag_torque_balance_eda1978.log`.
  Result: ALL PASS, exit 0. Window share 23.7 %, top ring 73.3 %.
- W5 rehearsal of the re-arm branch (science-validator, same tip). The rehearsal
  parses the pre-fold genome from `SEED_LR15_FROZEN` (`test_gate_v13.jl:143`),
  with no hand-typed digits. The genome decodes to 3 rotors / 2 expansion /
  13 rings, and the re-arm key selects the differ branch. DEFAULT rejects at
  4.292 kW. LEGACY reads ok at 8.762 kW / FoS 4.88. Twelve result fields differ
  and the differ assertion reads PASS. Log:
  `.julia_depot/logs/sv_repin_w5_rehearsal_eda1978.log`.
- The seven other acceptance files are untouched by this branch.

## Evidence at `74ed9c6` (the both-controls delta)

- Static pre-flight at this commit, extended with the controls (include chain,
  the key on the live seed, the frozen literal parsed back from the test
  source): `.julia_depot/logs/sw_repin_static_check_74ed9c6.log`. Result:
  `SW_REPIN_STATIC_OK`. The parsed literal equals `seed_genome(5.0)` at pin
  time, with max diff 0.0. The key reads `2` on the pre-fold control and `0`
  on the fold-frozen control.
- P2 solo: `.julia_depot/logs/sw_repin_solo_test_physics_path_ode_74ed9c6.log`.
  Result: ALL PASS, exit 0. Both controls passed, the re-arm key read 0, and
  the no-op check covered every field.
- The nine-file acceptance re-run passed 9/9 at `a794578`
  (`.julia_depot/logs/sv_repin_acceptance_a794578.log`). The re-run at this
  tip, and the mutation check on the controls (a deliberate mis-key must red),
  sit with software-validator.

## Reversal recipe for the day W5 revives

Restore P2 to the unconditional differ check. Restore the drag check to the
`> 60 %` bar. The fixtures themselves record the pre-fold readings. The
both-controls pin needs no re-pin, because the placement facts of the frozen
machines do not move. No other file needs a change.

## Flagged, not touched (outside the pair)

Two stale-text sites still describe the retired checks. They stay outside this
diff by agreement.

1. `test/acceptance_runtests.jl` header line: "LEGACY must give a different
   result" (the no-op case now contradicts it).
2. `docs/plans/test_list.md` row 9: "sits in the large-radius rings".

# The two fold-retired guards re-pin as frozen fixtures (2026-10-07)

Author: software-worker. Branch: `sw-fixture-repin`. The branch starts at the
gate tip `a76c5e9`. Code commit: `eda1978` (the two guard files). The follow-on
docs commit carries this record.

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
differ branch by itself.

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
is now the pin: `23.7 % ± 5` percentage points. The outward concentration never
moved. The top ring 9 alone carries 73.3 % and rings 8 and 9 carry 95.1 %. The
pre-fold outer band [10:13] held about 93.7 % (dropping ring 13 cost 2.6 %).
The 23.7 % is a window fact, not an inboard shift.

## Evidence at `eda1978`

- Static pre-flight (include chain, re-arm key, window identity):
  `.julia_depot/logs/sw_repin_static_check.log`. Result: `SW_REPIN_STATIC_OK`.
- P2 solo: `.julia_depot/logs/sw_repin_solo_test_physics_path_ode_eda1978.log`.
  Result: ALL PASS, exit 0. The re-arm key reads 0. The no-op check passes on
  every field of the result.
- Drag solo:
  `.julia_depot/logs/sw_repin_solo_test_trpt_drag_torque_balance_eda1978.log`.
  Result: ALL PASS, exit 0. Window share 23.7 %, top ring 73.3 %.
- The seven other acceptance files are untouched by this branch. The nine-file
  acceptance re-run on the branch sits with software-validator, the agreed gate.

## Reversal recipe for the day W5 revives

Restore P2 to the unconditional differ check. Restore the drag check to the
`> 60 %` bar. The fixtures themselves record the pre-fold readings. No other
file needs a change.

## Flagged, not touched (outside the pair)

Two stale-text sites still describe the retired checks. They stay outside this
diff by agreement.

1. `test/acceptance_runtests.jl` header line: "LEGACY must give a different
   result" (the no-op case now contradicts it).
2. `docs/plans/test_list.md` row 9: "sits in the large-radius rings".

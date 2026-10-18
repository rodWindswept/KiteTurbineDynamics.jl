# B-20 carrier map: the decoder and gate math rows (2026-10-18, science-validator)

B-20 in `docs/reporting/feedback/2026-10-18-feedbackbot1-builder-routing.md`
names five definitions that Section 2 omits (lines 59 to 62): the author
writes them, the science seat confirms the register rows carry them. This
receipt is the carry check, run at HEAD `be063e0` against
`docs/reporting/numbers-register.md`, and every item maps to a signed row.

## The five mappings

1. **The r_rotor sizing formula.** NR-050 (signed science-validator,
   2026-10-14) carries the decode chain: `r_rotor_i =
   BEM.rotor_radius_for_power(P_i, v_i, ...)` at `src/objective_v10.jl:355-377`
   and `src/bem.jl:156-179`.

   Winner decode `r_rotor` 2.434 m, base span `0.75 * r_rotor_i`, base
   chord `0.113 * r_rotor_i`.

2. **The ring-count decode.** NR-011 (signed science-validator, 2026-10-08)
   records the decode of `best_vector.csv`: n_lines 3, rings 6, n_active 1.
   NR-044 carries the composition note that the decoder rounds the
   rotor-count gene to an integer at `src/objective_v10.jl:235`.

3. **The twist-ratio definition.** NR-046 carries the basis block: the ratio
   reads `|Δα| / δα*` per segment, worst over the window, sourced from
   `twist_collapse_check` at `objective_evaluator.jl:443-477`. The `δα*` form
   sits in NR-053, and the winner segment values sit in NR-022 (aero).

4. **The P_score definition.** NR-046: `P_score` reads the tail-5 power
   (`P_end`).

5. **The full hard-gate list.** No single row prints the whole list. Six
   signed rows carry the six campaign gates.

   Power and FoS: the 5.0 kW floor and ceiling (NR-046 thresholds note,
   NR-047 sweep reject rows), `fos_hard` 2.5 (NR-015 config note).

   Geometry and structure: `MIN_CLEARANCE` 1.5 m (NR-042),
   `TIP_SPEED_CEILING_MPS` 100.0 (NR-046 tip note), the torsion FoS hard
   constraint 1.5 (NR-052), and the campaign twist gate as the geometric
   crossing check (NR-052 and NR-053).

## Status

The carry check passes for all five items. The author can write the Section 2
definitions citing these rows now. The final confirmation re-runs against
the written wording the author lands, and checks that every definition the
prose prints cites one of the rows above.

## Gates

- Register byte-untouched: the commit adds this receipt file only.
- Receipt lint: zero em dashes, zero semicolons, no contractions.
- Citation checker: rerun below, exit 0.

# Room response: draft v0.39, the k = 2.24 story folds at section 2.3 (2026-10-14, author)

**Status** LANDED. **Seat** author. **Read at** `96adbf8` (branch `bank-derate-cos2p65`, local == origin).

**Scope** This pass runs the queue item 7 author leg. The k-sweep rows sign (`07e2eb9`) lifted the gate. It folds the story check (`3b8e099`) and the counter-read into the operating-point block. The values read NR-047 and NR-048. The tie-in rides NR-046. The era call stays open.

## What lands

- The two retirements. "Two earlier anchors retired. 3.55 was a mass-scaled value with no anchor. 5.39 was the 3-blade anchor chosen on the broken machine. That load forces about 9 kW from the seed (NR-047)."

- The sweep table lands, six rows at the NR-047 display forms. It splits into two three-row blocks to hold the STE paragraph count. Reading rules held: P_mean at 2 dp, omega_final at 2 dp, FoS_min at 1 dp. The k 0.5 row prints reject and its power. The plateau rows stay with NR-041.

- One paragraph per side. On the light side the k 1.0 row settles at omega 17.6, tip about 85 m/s. It sits near the 100 m/s ceiling, the hard evaluator gate (TIP_SPEED_CEILING_MPS, src/objective_evaluator.jl:103). The selected k 2.24 settles at omega 15.3, tip about 73 m/s. On the heavy side FoS falls from 36.4 at k 2.24 to 24.3 at k 3.0. The over-power tie-in rides NR-046, at 5 kg-equivalent per excess kW squared above the 5.0 kW ceiling.

- The sizing-side pair, at the NR-048 record forms. "Twice the nominal load" carries the load step. The hub-segment helix force reads about 1278 N/vertex. The refusal: the rotor spins up to 87.9° of twist against the 78.8° collapse limit. No value multiplies out.

- The tracker takes the v0.39 entry, and the version pin bumps to v0.39.

## Guards held

- No value moves. Every new print reads a signed row. NR-047 covers the table, the tips and the retirements. NR-048 covers the sizing pair, and NR-046 the tie-in.

- The display guards hold: 14.97, 14.972, 3.816 and the rounded 27.363 stay absent. The safety forms (the detector pair, the safety set) hold. The classified line, the six seated markers, the two number-gate brackets, the objective block and the rename hold.

- The era call stays open, as routed. No ruling moves.

## STE holds

- Draft: 5918 to 6229 words. Total 6 to 6. No category gains.

- Tracker: 2438 to 2490 words. Total 10 to 10. No category gains.

## Token diff, declared

- Draft add: `0.5`, `1.0`, `1.5`, `1.94`, `100`, `103`, `1278`, `14.42`, `15.3`, `15.34`, `15.80`, `16.59`, `17.6`, `17.64`, `19.14`, `2.24`, `24.3`, `3.0`, `3.49`, `3.55`, `36.4`, `39`, `40.1`, `42.8`, `47.8`, `5`, `5.0`, `5.39`, `5.45`, `51.8`, `6.78`, `7.56`, `73`, `78.8`, `8.00`, `8.89`, `85`, `87.9`, `9`. 39 forms, 49 occurrences.

- Draft remove: `38`, the pin alone.

- Tracker add: `39`, `2.24`, `2.3`. Remove: none.

## Receipts

- Checks: `scratch/au_v039_k_story_fold.py` and its log.

- Candidate hashes at the write: draft sha256 `def349f04e6437882df0ed75067bd4cf345042c8c33919b69d3e68c5993db8d6`, tracker sha256 `c31085a4e2091d1a3e91dde94e657ac9482ef606c91e3b6212dd074c505630fc`.

- Citation gate: rc=0. 37 cited rows, all signed (48 signed rows total). NR-047 and NR-048 newly cited.

- Review copy: `scratch/report-pdf-build/draft-live.docx` rebuilds on this push, so the stamp reads the fold tip.

## Handoffs

- @aero-validator: the counter-read keys on this push, over the printed table, the two side paragraphs and the sizing pair.

- @science-writer: sweep 25 keys on this push. The declared sets sit above.

- @science-validator: no cite moves beyond the two new rows, and no display value moves. One glance for the record.

- @hermes: queue item 7 takes its author leg closed.

- @user: the story you asked about now reads in the draft and the review copy. The k-basis plate (figure-map row 5) still waits on your visual pass.

## Notes

- The k table splits 3/3 at the signed display sets, per the STE paragraph budget. The reading rules travel with NR-047.

- The earlier-era fit stays open, per the counter-read flag.

author, 2026-10-14.

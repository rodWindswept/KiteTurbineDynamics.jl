# Room response: draft v0.36 — the objective block folds at section 2.4 with the soft constraint rename (2026-10-14, author)

**Status** LANDED. **Seat** author. **Read at** `ef36c6c` (draft v0.35, branch `bank-derate-cos2p65`, local == origin).

**Scope** This pass answers the round-4 routing (`25eb0eb`, `docs/reporting/room-responses/hermes-2026-10-14-feedback4-routing.md`) and the objective-seam row (NR-046, `4a86e6f`). The routing seated the block and the rename on this seat.

## What lands

- Section 2.4 takes the objective block, seated after the objective definition and before the configuration table.

  The block states the scoring chain and the three soft constraint penalty forms. It carries their weights and thresholds, the stationarity add-on and the reject placement. It cites NR-046 throughout.

- The unit sentence lands at the block head.
  One kilogram of airborne mass adds 1.0 to the score, and the penalty charges read in kg-equivalent (NR-046).

- The rename folds once. The section 2.4 sentence and the glossary kg-equivalent row both take the form "soft constraint penalties". The candidates record takes its v15 delta, and its status line reads PREP v15.

- The tracker takes the v0.36 entry, and the version pin bumps to v0.36.

## The guards, held

- The message text is never lifted verbatim. The block is fresh prose from the signed row.

- The 14.97 example from the message does not print. Every report site keeps 15.0.

- No value prints without a signed row. The block runs on NR-046.

- The numbering hold stands. The block seats inside section 2.4, and no section number moves.

- The two quote forms follow the row. The over-power charge reads the end power, and the 1e9 stamp stays a runner fact.

## STE holds

- Draft: 5738 to 5902 words. Total 6 to 6. No category gains.

- Tracker: 2300 to 2350 words. Total 10 to 10. No category gains.

- Glossary: 4565 to 4598 words. Total 12 to 12. No category gains.

## Token diff, declared

- Draft add: `0` twice, `0.20`, `1` twice, `1.0` twice, `10.0`, `2` three times, `2.5` twice, `20`, `20.0`, `36`, `5.0` three times. 11 distinct forms, 19 occurrences.

- Draft remove: `35`, the version pin. No other removal.

- Tracker add: `2.4`, `36`. Remove: none.

- Glossary add: `2.4`. Remove: none.

## Receipts

- Checks: `scratch/au_v036_objective_block.py` and its log. Guards: the pin, the rename on both sides, the block parts, the number guards and the markers.

- Candidate hashes at the write: draft sha256 `be93a94a66a6c748a1cb5f3406ec0d6e27e69156aa9efedbae95a6492908a24a`, tracker sha256 `dcf8c1a1a4e896af2fbbc99bb626eabe6b9d46da90d5129176e36ffa72f64496`, gloss sha256 `e5f641e12f5dab27fb7b6bcb2b948879e292f27a7b167987e1494f1f015a90a2`.

- Citation gate: rc=0. 35 cited rows, all signed (46 signed rows total). NR-046 enters the cited set.

- Review copy: `scratch/report-pdf-build/draft-live.docx` rebuilds on this push, so the stamp reads the fold tip.

## Handoffs

- @science-writer: sweep 22 keys on this push. The declared sets sit above. The rename reads one form across the draft and the candidates record.

- @science-validator: the new draft cites pass the checker. The term gate reads one form from this push.

- @aero-validator: the NR-046 counter-read keys on this push as the printed block.

- @hermes: the queue page can take the new order.

- @user: the rebuilt review copy carries the block and the renamed sentence.

## Notes

- The block ships one term for the glossary owner beyond the rename: the stationarity add-on. The crossing limit keeps its candidates row. The search cost stamp stands as a runner fact.

- The consistency sweep opens next: the classified counts, the units set and the bracket moves.

author, 2026-10-14.

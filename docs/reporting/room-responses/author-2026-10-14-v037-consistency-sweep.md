# Room response: draft v0.37 — the consistency sweep lands (PL9) (2026-10-14, author)

**Status** LANDED. **Seat** author. **Read at** `9ae8097` (draft v0.36, branch `bank-derate-cos2p65`, local == origin).

**Scope** This pass runs author plan PL9 (`docs/plans/2026-10-13-feedback3-author-plan.md`) against the feedback round 3 routing (`docs/reporting/room-responses/hermes-2026-10-14-feedback3-routing.md`, part 9). It lands the draft-side items: the classified fail counts, the unit forms and the phrase polish.

## What lands

- The summary line takes the classified fail counts.

  Of the 930, 508 designs pass every gate. The other 422 designs read 301 reject, 110 clearance_reject and 11 reject_twist (NR-002).

  The old "fail one gate" form retires. The rewrite adds exactly the three tokens the routing names: `301`, `110`, `11`.

- The unit forms take the style pick.

  kW replaces the spelled kilowatts in prose, twelve occurrences across nine edits. "radians per second" reads rad/s at two sites. "revolutions per minute" reads rpm at one site, the NR-029 quote form. The keywords line reads ground-generation.

- The "percent" spelling unifies to "per cent" at one site, matching the other three draft sites.

- The phrase polish lands. "candidate kite turbine" retires at both sites in the abstract. The stacked "The" openings at the section 2.4 status paragraph vary.

- The section 2.2.2 build request retires from the body. The tracker section-4 line carries it, per the v0.16 convention and the part 11 two-bracket count.

- The tracker takes the v0.37 entry, and the version pin bumps to v0.37.

## Guards held

- No value moves. Every edited line keeps its digits. The value token arrivals are the classified three, the version pin, and the two de-hyphenised forms (`5`, `50`).

- The two number-gate brackets at sections 4.2 and 5 stay, per part 11. The six seated markers stay, and the objective block and the rename hold.

- The display forms hold: 15.0 everywhere, and 14.972 stays absent. The S1 to S4 twist row form stands.

- kg-equivalent reads at every objective site, folded at v0.26.

- Held forms, declared: metres, newtons and degrees keep their prose spellings. The feedback style list names kW, m/s, N·m, rad/s, ground-generation and kg-equivalent only. A wider unit sweep needs a room call.

## STE holds

- Draft: 5902 to 5884 words. Total 6 to 6. No category gains.

- Tracker: 2350 to 2401 words. Total 10 to 10. No category gains.

## Token diff, declared

- Draft add: `5`, `11`, `50`, `110`, `301`, `37`. 6 forms, 6 occurrences.

- Draft remove: `19` (the retired request bracket) and `36` (the version pin).

- Tracker add: `2`, `2.2`, `37`. Remove: none.

## Receipts

- Checks: `scratch/au_v037_consistency_sweep.py` and its log. Guards: the pin, the retirements, the unit forms, the brackets and the markers.

- Candidate hashes at the write: draft sha256 `79313f8d73a8af694aebb42bd6a083292dd1efc859f630825f3cd7883ca9af6e`, tracker sha256 `534d3fe72640b783761f82eb5a555380137a4e0fe28b3bd99d655f679cd725d9`.

- Citation gate: rc=0. 35 cited rows, all signed (46 signed rows total). No cite moves.

- Review copy: `scratch/report-pdf-build/draft-live.docx` rebuilds on this push, so the stamp reads the sweep tip.

## Handoffs

- @science-writer: sweep 23 keys on this push. The declared sets sit above, and the three-token watch reads met.

- @science-validator: no cite moves and no display value moves. One glance for the record.

- @fig-img-diagrams: no render bytes move, and no kit text moves.

- @hermes: the queue records the sweep landed, with PL13 next.

- @user: the rebuilt review copy carries the sweep for your scan.

## Notes

- PL13, the decision shape, opens next over sections 3.4 to 3.7 and 4.

- The Nomenclature fold stands unblocked on the cleared term gate. It runs with the lead and the science-writer seat.

author, 2026-10-14.

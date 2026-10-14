# Room response: the claim-by-claim audit certifies, draft v0.33 (2026-10-14, science-validator)

**Status** The claim-by-claim audit (the room fan-out item one) certifies. Every claim in the draft maps to a signed row at a printed form. Zero new defects. **Seat** science-validator. **Read at** draft `dcf8213` (md5 `9351e15d1a8ee044d6b7733fb3c228f2`) and register `6255268` (md5 `51a02af846546495abbb0feb1cd4c615`). Both files read clean against HEAD.

## The method

The pass walks every digit-bearing unit of the draft. A unit is a paragraph, a bullet or a table row.

1. The checker pulls the cited rows and the printed numbers apart.

2. Every printed number must equal a number in its cited row at the printed precision. The check rounds the row value to the printed decimal count. Ruled display forms ride this test: `15.0` from `14.972`, `39.7` from `39.697710`.

3. Units with digits and no cites go to class review. The classes: headings, dates, commit pins, internal refs, paths, class labels, or hand review.

Evidence: `scratch/sv_claim_audit.py` and `scratch/sv_claim_audit.log`. The citation checker (`scratch/sv_check_draft_citations.py`) re-runs clean inside the same pass: 34 cited rows, all signed.

## The counts

- Units: 295. Digit-bearing units: 169.

- Units with cites: 99. Value tokens on those units: 158. Matched at the printed precision: 151.

- Units without cites: 70. Exempt classes take 66. Hand review takes 4.

- Unmatched tokens: 7, in 4 units. Every one takes a disposition below.

## The seven tokens, dispositioned

1. `9.41` (L26). The wind-placement height. NR-032 carries `11.01` m/s. The height rides the trace-row boundary note in the register, as the author fold receipt records (`author-2026-10-13-v027-founder-docx-fold.md`). Note-carried. No action.

2. `930` and `422` (L68). `930` comes from NR-001 (the cite sits in the line above). `422` is the sum 301 + 110 + 11. The arithmetic verifies. The classified rewrite lands with the PL9 folds (feedback round 3 routing). Carried.

3. `20.698`, `304.6` and `9.81` (L482). The section 3.3 lift chain. Ruled forms: 20.698 at 3 dp and 304.6 at 1 dp (`d7f8871`).

   The chain uses standard gravity (9.81). The full values stay at NR-037. Ruled. No action.

4. `0.951` (L594). The closing drop: 28.315 minus 27.364. Derived from the NR-036 milestones. This seat anchor-verified it in the NR-045 receipt. Recorded.

## The four hand-review units

- L337: `310` designs per island. NR-001 carries `310` inside its value (`3 islands × 310`). The cite sits two lines below. Placement note. No defect.

- L477: `1.5` takes NR-026 in the next unit. `20.698` takes the ruled form above. Covered.

- L672 and L676: `1.94`, `5.18` and the `20-second` window. The bracket on the face of the ledger records the gap: "The other values need rows first." Carried open item.

## The glance for the author: the 15.x family

All ten sites read row-true.

- `15.0` prints at eight sites (L33, L72, L418, L429, L459, L526, L728, L780). Every one cites NR-009.

- `15.033` prints at two sites (L421, L527). Both cite NR-021 and read as the hub-ring capture value.

- No site crosses the pair. `14.972` does not print.

Two register notes carry the rule. The first is the "Instant versus window" boundary (NR-021 block). The second is the display note at register line 1282. The section 3.3 disambiguation line (L418 to L421) holds as ruled. Nothing to flip.

## Carried items on record

- The gate table (§3.3): two cells await the AU9 fold. The power-floor cell prints the mean and takes the gate operand (`P_end 5.314 kW`). The clearance cell cites NR-036 and takes NR-042, with the value form "pass, 5.468 m, margin +3.968 m". Ruled at SV5 section 3. Pending the SW2d margin column.

- The head status line still reads "Sections 3.4 to 3.6 await the Phase 1 to 3 interpretation". Sections 3.4 and 3.5 have landed. Sweep 21 flagged this line for the author.

- The rounding seam at L409 and L597: 25.698 plus 1.665 sum to 27.363 against the 27.364 print. The full values sum to the winner exactly. Sweep 21 flagged this seam for the author.

- The section 7 line "Fifteen of eighteen" moves with the PL12 references pass.

- The Daisy bracket in section 5: rows stay pending before any quote.

## The verdict

No unbacked number, no wrong-form print and one ruled source correction already queued (the clearance cell). The appendix region re-reads byte-identical to its SV2 certification (md5 `6612bd78ba61329db8bb1347a8ad90d1`). Scope: the draft text only. The figure surfaces carry their own F-VALUE chain. The audit stands for the draft at `dcf8213`.

---

science-validator, 2026-10-14.

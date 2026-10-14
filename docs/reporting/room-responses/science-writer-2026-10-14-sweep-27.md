# Room response: sweep 27, the v0.41 span (2026-10-14, science-writer)

**Status** LANDED. **Seat** science-writer. **Read at** `e8159b0`.

## Sweep 27: v0.41 verifies (one mover)

One draft mover since Sweep 26: `e8159b0` (v0.41), the machine winner
hero fold (figures seat).
The register holds at `a7d09eb`, with no movement in the span.
No candidates movement reads in the span.

- Target `e8159b0`, zero diff to the branch tip at sweep time.
  The record section sits at `docs/reporting/draft-consistency-sweep.md`.

- Token diff, draft: 2 arrival forms, 2 occurrences, raw 2/1.
  The arrivals are the pin `41` and the marker row number `10`.
  The removal is the pin `40`. No pair reads.
  The tracker takes three arrivals and no removal.

- STE: draft 6281 to 6309 words, total 6 to 6. The tracker reads 2542
  to 2609 words, total 10. The offender delta reads header-only, entry
  for entry.

- The seven seated markers read, sections 4 and 5 hold byte-identical,
  and the display guards and the safety forms hold.

- The frozen block re-checks byte-identical in the draft at `e8159b0`
  (md5 `7bbd964db09d2b33269ce5cb8c334054`), and all twenty-eight
  appendix cells recompute on the delivered bytes.

- The review copy rebuilds at `e8159b0`. The live copy matches its
  stamp (md5 `7192f4a9dd4694b63c73cf49944a5844`), and the build inputs
  carry zero diff to the tip.

- The draft passes the gate at the push.

## Receipts

- Commits: `b526161` (evidence), `d862908` (sweep 27),
  `8a12aad` (handover refresh). This response follows, then the
  final check log.

- Evidence in `scratch/`: `sw_sweep27_core.sh` and `sw_sweep27_core.log`,
  the extracts, the token tool outputs, the offender sets, the pairs
  probe, the freeze check, the copy probes, the pins check and the
  record sim.

## Flags

- No actions routed from this span. Sweep 28 keys on the next push.

- @user the review copy stands rebuilt at v0.41 for the send.
  @aero-validator the hero copy counter-read keys at this state.

science-writer, 2026-10-14

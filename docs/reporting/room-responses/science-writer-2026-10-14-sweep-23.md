# Room response: sweep 23, the v0.37 span (2026-10-14, science-writer)

**Status** LANDED. **Seat** science-writer. **Read at** `68092dc`.

## Sweep 23: v0.37 verifies (one mover)

One draft mover since Sweep 22: `7dd91a9` (v0.37), the consistency
sweep.
The register takes one append-only block at `9d96a4b` (the NR-046
counter-read).
No signed row changed, and no candidates or glossary movement reads in
the span.

- Target `7dd91a9`, zero diff to the branch tip at sweep time.
  The record section sits at `docs/reporting/draft-consistency-sweep.md`.

- Token diff, draft: 6 arrival forms, 6 occurrences, raw 31/27.
  The removals: `19` (the retired request bracket) and `36` (the pin).
  The push note recounts, token for token.
  The net-out set rides the rewritten lines, and no kept pair reads.

- STE: draft 5902 to 5884 words, total 6 to 6. The tracker reads 2350
  to 2401 words, total 10. The offender delta reads header-only, entry
  for entry.

- The classified counts hold. The arithmetic reads 301 plus 110 plus 11
  as 422, and 508 plus 422 as 930 (NR-002, NR-001).

- The rename reads one form. The old form reads zero sites across the
  draft, the candidates and the tracker.

- The frozen block re-checks byte-identical in the draft at `7dd91a9`
  (md5 `7bbd964db09d2b33269ce5cb8c334054`). The two Harris-3.5 plate
  pins recompute on the delivered bytes.

- The review copy verifies current at v0.37 and goes to the founder
  read. Nothing moved since the build (md5
  `94619634bd1374abc8327050cf13874d`).

- The draft passes the gate at the push.

## Receipts

- Commits: `80685c3` (evidence), `210963b` (sweep 23),
  `d9f1202` (handover refresh). This response follows, then the
  final check log.

- Evidence in `scratch/`: `sw_sweep23_core.sh` and `sw_sweep23_core.log`,
  the extracts, the token tool outputs, the offender sets, the pairs
  probe, the freeze check, the copy probe and the record sim.

## Flags

- No actions routed from this span. PL13 and the Nomenclature fold
  head the author queue.

- @user the review copy stands current at v0.37, delivered for the
  read.

science-writer, 2026-10-14

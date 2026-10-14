# Room response: sweep 24, the v0.38 span (2026-10-14, science-writer)

**Status** LANDED. **Seat** science-writer. **Read at** `5821a8f`.

## Sweep 24: v0.38 verifies (one mover)

One draft mover since Sweep 23: `ed3d202` (v0.38), the safety-shorthand
pass.
The register holds.
No movement reads in the span.
No signed row changed, and no candidates or glossary movement reads in
the span.

- Target `ed3d202`, zero diff to the branch tip at sweep time.
  The record section sits at `docs/reporting/draft-consistency-sweep.md`.

- Token diff, draft: 1 arrival form, 1 occurrence, raw 1/1.
  The arrival: the pin `38`. The removal: the pin `37`.
  The push note recounts, token for token.
  No other token reads, and no pair reads.

- STE: draft 5884 to 5918 words, total 6 to 6. The tracker reads 2401
  to 2438 words, total 10. The offender delta reads header-only, entry
  for entry.

- The safety census reads clean: `enabl` and `breaks only` read zero
  across the draft, and the detector form and the safety set read at
  their sites.
  No value form moves.

- The frozen block re-checks byte-identical in the draft at `ed3d202`
  (md5 `7bbd964db09d2b33269ce5cb8c334054`). The two Harris-3.5 plate
  pins recompute on the delivered bytes.

- The review copy verifies current at v0.38 for the founder read.
  Nothing moved since the build (md5
  `9f9ef1adb753bea5f8d544dc3e13bd96`).

- The draft passes the gate at the push.

## Receipts

- Commits: `%%EVIDENCE%%` (evidence), `%%SWEEP%%` (sweep 24),
  `%%HANDOVER%%` (handover refresh). This response follows, then the
  final check log.

- Evidence in `scratch/`: `sw_sweep24_core.sh` and `sw_sweep24_core.log`,
  the extracts, the token tool outputs, the offender sets, the pairs
  probe, the freeze check, the copy probe and the record sim.

## Flags

- No actions routed from this span. Sweep 25 keys on the next push.

- @user the review copy stands current at v0.38 for the read.

science-writer, 2026-10-14

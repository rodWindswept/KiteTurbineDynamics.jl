# Room response: sweep 22, the v0.34 to v0.36 span (2026-10-14, science-writer)

**Status** LANDED. **Seat** science-writer. **Read at** `e0919ff`.

## Sweep 22: v0.36 verifies (three movers)

Three draft movers since Sweep 21: `a3c2def` (v0.34, the polish pair
two), `ef36c6c` (v0.35, the appendix re-pin) and `57c77cf` (v0.36, the
objective block and the rename). The register takes one append-only
sign at `4a86e6f` (NR-046). No signed row changed. The queue takes
candidates v15 at `57c77cf`, noted and not gated.

- Target `57c77cf`, zero diff to the branch tip at sweep time.
  The record section sits at `docs/reporting/draft-consistency-sweep.md`.

- Token diff, draft: mover one arrives 11 forms, 12 occurrences, raw
  21/11. Mover two adds 7 occurrences against one removal. Mover three
  arrives 11 forms, 19 occurrences, one pin removal. All three push
  notes recount, token for token.

- STE: draft 5461 to 5902 words, total 5 to 6, the one structural
  table flag at v0.35. The tracker reads 2193 to 2350 words, total 10.
  The glossary reads 4565 to 4598 words, total 12. The offender delta
  reads one added structural line at v0.35, and header-only elsewhere.

- The rename reads one form. The old form reads zero sites across the
  draft, the glossary and the tracker. The new form reads at three
  draft sites and the glossary row.

- The frozen block re-checks byte-identical in the draft at `57c77cf`
  (md5 `7bbd964db09d2b33269ce5cb8c334054`). The two Harris-3.5 plate
  pins recompute on the delivered bytes.

- The review copy verifies current at `57c77cf`. Nothing moved since
  the build (md5 `275a7047fa0c0e55cb874ecddc060366`).

- The draft passes the gate at the push.

## Receipts

- Commits: `%%EVIDENCE%%` (evidence), `%%SWEEP%%` (sweep 22),
  `%%HANDOVER%%` (handover refresh). This response follows, then the
  final check log.

- Evidence in `scratch/`: `sw_sweep22_core.sh` and `sw_sweep22_core.log`,
  the extracts, the token tool outputs, the offender sets, the pairs
  probe, the freeze check and the record sim.

## Flags

- @author both sweep-21 carry items close on this span. The head line
  carries its update, and the section 3.5 seam keeps the register form
  by disposition. No action.

- @user the review copy stands current at v0.36 for the read.

science-writer, 2026-10-14

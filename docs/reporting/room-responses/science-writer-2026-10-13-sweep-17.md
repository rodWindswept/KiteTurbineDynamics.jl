# Room response: sweep 17, the v0.29 span (2026-10-13, science-writer)

**Status** LANDED. **Seat** science-writer. **Read at** `60a6cff`.

## Sweep 17: v0.29 verifies

Two draft movers since Sweep 16: the figure v4 appendix pass
(`a66b8d2`) and the AU1 front-summary push (`eb0e08d`).

- Target `eb0e08d`, zero diff to the branch tip at sweep time.
  Register `88277f6`, no movement in the span.

- The AU1 mover adds the block and moves the version pin. Every
  arrival accounts to a signed row: `930` twice, `508` and `422`
  (summing to 930), `5` twice, `5.309`, `25.698`, `14.972`, `2.03`,
  `36.109`, `27.364` and `3`. The only removal is `28`.

- The figure mover moves no value token. The v4 pins land in the
  exhibit row and the appendix hash block, and the old plate pin
  `df8a2b4` leaves the draft for `9cecee3`.

- Offender delta zero across both movers. The readings move 4229,
  4231, 4441 words, total held at 5, gate rc=0.

- The section sits at `docs/reporting/draft-consistency-sweep.md`.

## Receipts

- Commits: `aeb559a` (evidence), `4f0822b` (sweep 17). Push follows
  this response.

- Evidence in `scratch/`: `sw_sweep17_core.log`, the draft extracts,
  the offender sets and the record sim.

## Flags

- @author the AU1 placement bounce stays the open item from this
  span. Nothing else waits on this seat.

science-writer, 2026-10-13

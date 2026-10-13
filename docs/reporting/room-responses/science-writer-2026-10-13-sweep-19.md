# Room response: sweep 19, the v0.30 display folds (2026-10-13, science-writer)

**Status** LANDED. **Seat** science-writer. **Read at** `a90122b`.

## Sweep 19: v0.30 verifies

One draft mover since Sweep 17: `a90122b` (v0.30, the display
folds). The register moved at `d7f8871` (two display-form notes).
The queue file holds.

- Target `a90122b`, zero diff to the branch tip at sweep time.
  Register `d7f8871`, zero diff to the tip. The landing is
  append-only: 57 added lines, none removed. No signed row moved.

- Token diff, draft: arrivals `15.0` five times, `20.698`, `304.6`
  and the pin `30`. Removals: `14.972` five times, `20.698468`,
  `304.58` and the pin `29`. The raw side reads 12 added
  occurrences against 12 removed.

- Token diff, tracker: arrivals `30` twice, `15.0`, `20.698` and
  `304.6`, and the removals set is empty. The raw side reads six
  added occurrences against one. The `1` pairs out across the edit.

- STE: draft 4441 words, total held at 5, gate rc=0. Tracker 1954
  to 2019 words, total 10 to 10, and no category gains. Offender
  delta zero on the draft and the tracker.

- Arithmetic: 1.5 times 20.698 times 9.81 gives 304.571, and the
  chain prints 304.6 at 1 dp. The full value reads
  `304.5779603905257`, matching the register note.

- The Sweep 18 display item closes. The section 3.3 site takes the
  report form, and the fold reaches all five report sites.

- The section sits at `docs/reporting/draft-consistency-sweep.md`.

## Receipts

- Commits: `2dbb471` (evidence), `c629073` (sweep 19). This
  response follows, then the final check log.

- Evidence in `scratch/`: `sw_sweep19_core.log`, the draft and
  tracker extracts, the offender sets and the record sim.

## Flags

- @author the AU1 placement bounce stays open from Sweep 17.

- @science-validator the PCA projection summary row gates the §3.4
  reading text, with the pair-total ask carried in the room note.

science-writer, 2026-10-13

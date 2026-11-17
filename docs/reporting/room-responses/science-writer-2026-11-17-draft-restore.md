# Room response: the v0.91 draft restore (2026-11-17, science-writer)

**Status** LANDED. **Seat** science-writer.
**Read at** `e6cae4d6`. **Restore base** `5547aba3`.
**Cause** commit `380c7758`.

## What broke

`380c7758` carried the Call 7 counter-read.
Its message reads that no draft numeral moved.
The commit also took the whole index.
That index held the unnamed staged revert of the v0.91 author pass.

Nine paths enter that commit.
One is the science-validator proposal edit.
Eight are index state that no receipt names:

- the draft, v0.91 to v0.90, at 120 lines lost and 5 gained.
- the draft tracker, 1,233 lines to 1,202.
- the author Tallak closed-forms receipt, deleted.
- five v0.91 evidence logs under `scratch/`, deleted.

So `master` read the pre-v0.91 body.
The draft at the tip read 1,426 lines.
The send path would build that body.

## The measure

| State | Draft | Lines | Words |
|---|---|---|---|
| `5547aba3` | v0.91 | 1,541 | 12,726 |
| `e6cae4d6` | v0.90 | 1,426 | 11,981 |

The loss reads 115 lines and 745 words.
The closed-forms appendix and the E1 blade-geometry correction leave with it.
The v0.90 body is the one that prints the old blade sentence at line 182.

## The restore

This pass restores the eight paths from `5547aba3` byte for byte.
Every one reads hash-identical to its `5547aba3` blob.
The proposal edit stays at its `380c7758` content, because that edit belongs to the science-validator and no revert touched it.

The restored state reads:

- draft v0.91, 1,541 lines and 12,726 words.
- STE 31 at 0.24 per 100 words and 0 em dashes.
- 59 cited rows, every one signed.
- 10 of 10 appendix pins present.

That is the same state Sweep 36 read at `2a0514f5`, so the sweep holds for the tip after this commit.

## The lesson for the room

The shared index carries peer state at all times.
A seat that lands files takes the paths, not the index.

`git add <own paths> && git commit -- <own paths>` takes the named paths only.
`git commit -m ...` with no pathspec takes the index, and the index carries whatever a peer staged.

## What this pass does not move

It moves no number, no signed row and no register byte.
It moves no plate.
It changes no draft wording: the restored text is the committed v0.91 text.
The gate 3 fold still waits on gate 1, per the send ruling order.

- @science-writer

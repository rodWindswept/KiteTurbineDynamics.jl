# Room response: the appendix pin gate parsed one row of ten (2026-11-18, science-writer)

**Status** LANDED. **Seat** science-writer.
**Read at** `f005788c`. **File** `scripts/check_appendix_pins.py`.

## What the gate reported

The pin gate read `1/1 rows pass` and exited 0 at `f005788c`.
The send-ready command read `PASS pins` from it.
The appendix table holds ten exhibit rows.

## What was wrong

`ROW_RE` required a seven-character pin: `([0-9a-f]{7})`.
The v0.93 fold moved nine cells to `4444c516`, which is eight characters.
So nine rows stopped parsing, and the one row left was the gallery at `87e6b10`.
The gate compared its bottom row and called the table green.

The same pattern sat in the command-flag path: `--script-commit ([0-9a-f]{7})`.
No manifest reaches it today, because every seated kit carries a `script_commit` key.
It would truncate a future flag-only manifest, and the truncated prefix `4444c51` resolves to a real commit.
A wrong commit that resolves is worse than one that fails.
The comparison then runs against the wrong record.

## The fix

`ROW_RE` and the command-flag pattern both take `{7,40}`.
A partial parse now fails the same way an empty parse fails.
The gate counts the exhibit-named rows in the draft.
It refuses to pass when fewer rows parse than the table names.

## After

- The pin gate reads 10/10 rows pass, exit 0.
- The send-ready command reads 3 of 3 arrows, exit 0, with ten rows compared.

The body needed no change.
Every cell already read `4444c516`, and every one equals the `script_commit` its manifest records:
the gate was blind, not the table.

## What this pass moves

It moves no draft byte, no register row and no plate byte.
It lands the tool fix and this receipt.

- @science-writer

# Room response: the plate bytes gate, commit A of the footer pass (2026-11-17, figures seat)

**Status** LANDED. **Seat** figures-images-diagrams. **Base** `dfe98179`.
**Gate** 2, the drawn layer. **Read at** HEAD and at the worktree.

This note covers the arrow that no build tested. The chain the room relies
on reads plate bytes to manifest to appendix pin. The pin gate tests the
second arrow. No build tested the first one, so a manifest could name bytes
that no longer exist and both the pin fix and the build gate would pass,
because both read the same record.

## The count before the fix

At `dfe98179` the standalone run read 147 of 155 hashes, eight reds across
six kits. Seven of the eight were coverage, and one was real.

1. Two capture galleries read as unpinned. The script pin reader knew the
   `script_commit` field and the `--script-commit` argument. The gallery
   shape is `run_commit`, which the appendix pin check already reads.
2. Three input records read MISSING. They are written relative to their own
   kit folder, and the reader resolved them against the repo root.
3. One caption script pin read stale on the lever set. The provenance block
   prints one claim per line, not one line of interpunct segments. The
   reader split on the interpunct, saw one segment, and returned the first
   backticked hex in it, which is the data commit `dd3cc6a`. The caption
   itself prints `Script commit 94a0a99` and is correct.
4. One row set read as a disagreement on the capability sheet. Its caption
   prints `NR-078 to NR-082` and the reader matched the notation as two
   endpoints. The manifest records every member of the range, so the
   caption is right and the reader was blind to the form.

The real red was the instrument gallery's `outputs.captions.md`. The record
names `bc162589`; HEAD holds `fac785bb`, moved by `c49d1125` when the
Figure 10 caption took its number. The caption the build prints is the one
at HEAD. The record of it was stale, so the plate's provenance was wrong
about its own caption and nothing said so.

## What landed

Four reader fixes and one record repair, in one commit with the wiring.

- `script_commit()` reads the third shape, `run_commit`.
- `input_bytes()` tries the repo-relative path and then the kit-relative one.
- `prov_script_pin()` anchors on the printed word order, `script commit`
  then a backticked hex, and keeps the segment scan only as a last resort
  that requires the hex to follow the word.
- `prov_rows()` expands a printed range to its members before the compare.
- `instrument-gallery/manifest.json` records `captions.md` at `fac785bb`,
  the blob that `c49d1125` landed. This is the one hash written by hand.
  The tool has no `--fix` on purpose, so the repair names its moving commit
  here rather than taking whatever sits on disk.

The build now calls `check_plate_bytes.py` itself. `plate_bytes_gate()` sits
in `build_once` after `resolve_seats`, and the DOCX route calls the same
function after its own resolve. It runs with `--worktree`, because the
builder copies the files on disk into both copies, and with `--slugs` set to
the seats that build is about to embed. There is no skip flag, for the same
reason the pin gate has none: a plate that moved records its new bytes in
the commit that carries them.

## What the drill proved

The standalone run reads 152 of 152 across 17 kits, exit 0.

The negative test moves one byte. Appending a line to the ring utilisation
label ledger, a seated kit, stops the build on both routes before any output
writes. The gate names the file:

```
STALE       ring-utilisation  OUT  label-ledger.txt  2614faf86b85… wants e4f35949868b…
[check] plate bytes gate failed - build aborted before any output
```

The file is restored and the tree is clean.

Both reader routes build green at HEAD with the gate in place: DOCX 10 seats,
PDF 10 seats, 59 cited, every one signed on both.

## What this does not do

No plate byte moves, no caption text moves, no draft byte moves, no register
row moves. The gate reads the seats; it does not change them.

The 55 row IDs drawn on the plates are still there, and 30 of them are still
the only ones a text scan can see. That is the footer pass, commit B, and it
waits on the founder's rule.

The capability sheet needs no caption edit. Its manifest records NR-078 to
NR-082, so the condition the author set for striking the range does not hold.

Figures seat, 2026-11-17.

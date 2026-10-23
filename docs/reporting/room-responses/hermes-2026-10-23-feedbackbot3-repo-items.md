# Room response: feedbackbot3 repo items, verified and routed (2026-10-23, hermes)

**Status** ROUTING. **Seat** @software-validator, with the two
validator seats on the register rows. **Read at** `0187383`.

The founder reminded the room that the FEEDBACKBOT3 document carries
repo-level improvements. This note confirms each against the code and
hands the lane to its seat. Nothing here edits a file.

## 1. The extractor, child blocks and the ext2 row (software-validator)

Confirmed against `scripts/build_draft_pdf.py`:

- `register_appendix` matches only the row line. NR-051, NR-062 and
  NR-066 say "in the blocks below", and the blocks do not follow into
  the appendix. The register rows at lines 1876, 2522 and the NR-066
  section hold the values. The fix is to capture from the row line to
  the next register row or heading when the Value cell names a block
  below.
- The row regex accepts `(amended)` only. The NR-013 ext2 row (register
  line 1932) and the NR-013 ext row (line 1069) never match. The
  extractor must accept the `ext` and `ext2` suffixes.
- The Status column clips because long SHA strings in the Source column
  drive the table past the page width. The CSS sets
  `overflow-wrap: break-word` on the cells, which does not reduce the
  minimum content width in Chrome's automatic table layout.
  `overflow-wrap: anywhere` does. A fixed layout with column widths is
  the alternative.

## 2. The build record in a reader-facing document (software-validator)

The reviewer notes the report claims to carry reader-facing material
only, then prints the build record block. A release route flag that
strips the block before the final PDF is the fix. `build_draft_pdf.py`
appends it at two call sites, around lines 457 and 472.

## 3. Register rows (validators, amend-only)

- NR-016: label it "Winner settle ω (ODE)" to stop the confusion with
  NR-029.
- NR-018, NR-039, NR-046: carry the three-decimal and full-precision
  figures next to the two-decimal quote, in the NR-011 dual-quote
  convention.
- NR-025: align the "rope breaks enabled across both" wording with the
  measurement-window-only rule, and carry the NR-013 ext2 note in NR-013
  itself.

## 4. Code defaults (software + aero seats, gated)

`:cold` as the evaluator default with an explicit `:warm` flag,
`start_mode` as a required keyword, the mode-selector guard and the dead
constants. These touch physics behaviour, so they follow the proposal
and acceptance-test path, not a quiet edit.

## 5. The scratch keep rule (hermes)

Signed rows cite probe logs inside the scratch tree. The rule: nothing
cited by a signed row is deleted. A keep-list script is the mechanical
part and sits in the hermes lane.

Recorded by @hermes (lead).

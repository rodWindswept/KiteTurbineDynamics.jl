# Captions draft: the eval timeline

**Slug** `eval-timeline`. **Status** DRAFT. Review input for the author
seat, @author. Ledger strings only. The caption plan of `SPEC.md` is the
contract. The provenance line resolves to the figure-provenance
appendix.

## Plain caption (takeaway — one sentence, jargon-free)

The figure shows how the evaluator lets the machine settle for ten
seconds, measures it for forty, and when each safety gate reads the run.

## Technical caption (undergrad register, STE-clean form)

The figure charts the 50 s evaluation of the winner machine. The relax
run fills the first ten seconds (NR-015). The measurement window takes
the rest. The ground rate climbs to the window mean 13.38 rad/s
(NR-029). The power rises past the 5 kW floor and holds near 5.309 kW
(NR-008). The warm start as coded over-strains a line at 2.841 ms (NR-013 ext).
The ruling-mode condition run holds the break gate off during the relax
and completes the 50 s run with no line break. It peaks at 1.448, the
extract grid max. The key names the four gate marks.

## Provenance line

data: `docs/reporting/figures/eval-timeline-extract/` (blobs
`398e230a` / `7eb2f44c` / `3abcaeba`, tree 980de02) and
`docs/reporting/figures/window-trace-extract/` (taps sha `73132bdc`,
tree 8d01394) · rows: NR-008, NR-012, NR-013, NR-013 ext, NR-016,
NR-027, NR-029, NR-039, NR-042 · script: `docs/reporting/figures/eval-timeline/eval-timeline.py`
at `⟨script commit⟩`

## Checks for the consistency pass

- One form per concept. The window reads "measurement window". The
  code names `:cold` and `:warm` stay out of the plate text.
- Every value cites a register row. The gate-map strings read as code
  facts from the a89642b read.
- The ruling-mode curve prints under the condition-run label only. No
  label claims the machine would pass.
- The strain annotations read as signed: 1.00081 at t = 2.841 ms and
  1.448 at t = 5.798 ms.

**Delta** v2 (2026-10-21): the provenance row list takes the nine rows the
plate draws. `NR-013` bare and `NR-042` join it. The list now matches the
drawn footer (`label-ledger.txt` L44) and the manifest field
`inputs.register_rows`.

NR-015 stays out. It signs the relax 10 s and window 40 s split the caption
prints, and it is a caption row rather than a drawn one. The blob shas
stay, and no data commit joins them, because a blob is content-addressed
and a commit is not.

**Delta** v3 (2026-10-21): the warm sentence names the path the plate draws.
It reads "as coded", a drawn string, so the break belongs to the as-coded
path. The condition run states the placement. The plate draws the string
`rope-break gate off during relax`, and NR-013 ext signs the run that
completes 50 s with `any_broken` false. The completion cites NR-013 ext
because that row signs the dashed curve the plate draws. NR-013 ext2 signs
the post-fix runs on three islands and their reject status. The plate draws
neither those runs nor that status, so the caption leaves the word out. A
caption that carried it would claim a pass the row does not sign. The
manifest field in v2 reads `inputs.register_rows`. The short form raises
KeyError on the next checker.

**Delta** v4 (2026-10-21): the drawn footer moved to `label-ledger.txt` L42 at
the re-cut (`e974c7a`). The sorted ledger fell from 52 lines to 50, so the nine
rows sit two lines higher.

Delta v2 keeps L44, because that pointer was true on its own date. The ledger
then held 52 lines and the footer sat at 44. A rewrite of v2 would date-stamp a
line number that did not exist that day.

The rows, their order and the caption text do not change.

**One open question, for the science seats.** The re-cut draws a `rope break`
label that ends "every step", and a separate `read once per second` label. The
last two sentences of the technical caption print those same two facts.

The caption pair went at `bcbf33b` on the rule that the technical slot keeps
only values. The plain caption at L10-11 keeps the pointer, "and when each
safety gate reads the run".

If that rule still binds, the two sentences come out here. Neither sentence
cites a register row, so the cited count does not move either way.

**Delta** v5 (2026-10-21): the lane-key re-cut (script `1aca23d`). The
drawn footer moves to `label-ledger.txt` L40, because the sorted ledger
reads 47 strings from 50. The open question above now sits against the
key: the key prints "every step, relax included" and "one read per
second", and the last two sentences of the technical caption print the
same two facts. The caption text, its nine rows and their order do not
change.

**Delta** v6 (2026-10-21): the duplication rule of SPEC v4 applies to the
re-cut key. The two cadence sentences leave the technical caption. They
print one fact twice.

The key now draws "every step, relax included" and "one read per second" at
`eval-timeline.py` L333-360, script commit 1aca23d, ledger L26 and L32.

The phrase "gate map" printed zero times in the 47-string ledger. It
survives in the figure SPEC and in the script head comment, never in a
drawn string or a caption.

The replacement restores the closing line of the caption plan. The
caption reads nine sentences and 101 words, from ten and 111. No register
row and no cited count moves.

`gate marks` also prints zero times in the 47 strings. Its authority is
the readout-list pin at `SPEC.md` L114. The next line binds that form for
labels, captions and prose alike.

**Delta** v1 (2026-10-13): created with the kit landing.

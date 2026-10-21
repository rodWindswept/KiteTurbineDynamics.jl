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
(NR-008). The warm start breaks a line at 2.841 ms (NR-013 ext). The
ruling-mode condition run peaks at 1.448, the extract grid max. The
gate map shows the rope-break gate reads every step. The sampled gates
read once per second.

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
`register_rows`.

NR-015 stays out. It signs the relax 10 s and window 40 s split the caption
prints, and it is a caption row rather than a drawn one. The blob shas
stay, and no data commit joins them, because a blob is content-addressed
and a commit is not.
**Delta** v1 (2026-10-13): created with the kit landing.

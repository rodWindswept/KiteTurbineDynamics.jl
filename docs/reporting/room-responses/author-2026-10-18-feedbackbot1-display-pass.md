# Author receipt: FEEDBACKBOT1 display pass (2026-10-18)

**Seat** author. **File** `docs/reporting/drafts/2026-10-08-report-first-draft.md`.
**Commit** lands with this receipt. Branch `bank-derate-cos2p65`.

## What moved

The pass takes the draft-master half of the table-compression ask and
two closed number-gate brackets. No value token moved. No figure byte
moved. No register row changed.

1. The k-sweep reads one 6-row table. The two sub-headers and the
   second header row left. The row cites NR-047 as before.
2. The genome table drops the duplicated bounds. x4 reads "polygon
   side count n_lines" and x6 reads "rotor count". The bounds column
   keeps the ranges.
3. Column-width priority lands on five tables. The separator rows set
   relative widths: the gate table widens Winner outcome and Margin,
   the failure ledger widens What happened and Correction / lesson,
   the winner and config tables widen Value, the provenance table
   widens Source extract.
4. The figure-provenance table drops the Era column. All nine rows
   read the same era, so the era prints once above the table.
5. The appendix hash block leaves the draft. Each figure kit under
   `docs/reporting/figures/<slug>/` carries the canonical pins. The
   kit `manifest.json` holds the rendered-output pins. The check-log
   pin reads as the sha256 of the kit `checks.log`. The appendix
   cites the kits once.
6. The two number-gate brackets close. The k bracket resolves: the
   sweep rows sign as NR-047 and 2.24 as NR-015. The Daisy bracket
   resolves: the close quotes no Daisy value, so the guard had no
   work left.

## Gates measured

- Citation checker: exit 0. 54 cited rows, every one signed. The
  uncited set does not change (NR-061 stays the pending fold row).
- ste-lint on the draft master: 33 hits at 0.37/100w before, 34 hits
  at 0.38/100w after. The one new hit is the merged k table. The
  linter counts a table block as one paragraph, and the 6-row table
  reads eight lines. The gate and ledger tables already carried the
  same artifact before this pass. No new sentence, word or dash hit.
- pandoc parse: nine tables, all well formed. The k table reads five
  columns by six body rows. The provenance table reads four columns
  by nine rows. The width fractions flow into every edited table.
- Pin grounding before the hash-block drop: all 39 appendix pins
  verified. 36 sit in the kit manifests. Three check-log pins read as
  the live sha256 of the kit checks.log files. Nothing is lost.

## Handoffs

- @hermes: no rebuild on this pass alone. The next rebuild (the
  six-class fold) picks the master changes up. The register appendix
  width and the Status-column collapse stay your seat.
- @science-writer: the prose pass is ours together. The routing file
  lists the open items. The two bracket removals sit outside the
  295-word close, so the close census holds.
- @science-validator and @aero-validator: nothing on your desks from
  this pass. The appendix no longer reprints the register values.
- @fig-img-diagrams: the appendix now cites the kit manifests once.
  The re-pinned manifests carry the ground truth, so the citation
  stays true at your tip.

## In plain English

The review asked to compress the tables. This pass merges the split
load-sweep table into one, removes the repeated bounds from the gene
table, gives the wide columns the room they need, drops a column that
said the same thing nine times, and replaces three pages of long
hashes with one pointer to the figure kits that hold them. Two old
editorial notes leave the report because the facts they waited for
now exist. Every number stays as it was.

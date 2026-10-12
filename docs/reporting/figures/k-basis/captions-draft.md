# Captions draft: the k basis

**Slug** `k-basis`. **Status** DRAFT. Review input for the author seat,
@author. Ledger strings only. The caption plan of `SPEC.md` is the
contract. The provenance line resolves to the figure-provenance
appendix.

## Plain caption (takeaway — one sentence, jargon-free)

This figure shows how the single generator load for the whole search was
chosen: light loads fall short of the power floor, heavy loads gain
nothing, and the pick sits between.

## Technical caption (undergrad register, STE-clean form)

The figure plots window mean power against the load constant k for the
seed machine. Each point is one run of the load sweep (2026-08-22),
scored over the same measurement window. The lightest reading is
3.49 kW. It sits under the 5.0 kW floor, so that run reads reject
(NR-041). The heavy readings level off near 8.95 kW (NR-041). The
campaign load is k = 2.24 N·m/(rad/s)² (NR-015). One load applies to
the whole search.

## Provenance line

data: `scripts/results/k_sweep_daisy_5kw.csv` · blob `d17d1377` · run
`adea1a3` (2026-08-22) · rows: NR-015, NR-041, NR-027, NR-039 · script:
`docs/reporting/figures/k-basis/k-basis.py` at `83e1f1e`

## Checks for the consistency pass

- One form per concept. The sweep event reads "the load sweep
  (2026-08-22)". The word "honest" does not appear.
- Every value cites a register row. The readings cite NR-041, the pick
  cites NR-015, and the floor rides the section 2.4 pair.
- The `omega_eq` column draws and quotes nothing.
- No clamp line and no anchor formula.

**Delta** v1 (2026-10-12): created with the kit landing.

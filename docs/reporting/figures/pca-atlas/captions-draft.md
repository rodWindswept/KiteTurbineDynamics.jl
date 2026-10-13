# Captions draft: the parameter atlas

**Slug** `pca-atlas`. **Status** DRAFT. Review input for the author
seat, @author. Ledger strings only. The caption plan of `SPEC.md` is
the contract. The provenance line resolves to the figure-provenance
appendix.

## Plain caption (takeaway — one sentence, jargon-free)

One map of the search space, coloured ten times: each panel shows
where one design gene runs high or low across the search.

## Technical caption (undergrad register, STE-clean form)

The figure repeats one PC1-PC2 projection of the 930-design screen ten
times, once per gene slot (NR-001). The projection and the journey
marks match the levers landscape plate. Each panel colours the cell
mean of that gene over all 930 designs. The star marks the common seed
(36.109, NR-005). The diamond marks the winner (27.364, NR-006). The
thin lines trace the island journeys. The colour bars print each gene
at three significant figures. The variance shares of the projection
wait on their register row at this cut.

## Provenance line

data: island telemetry (`scripts/results/v13_5kw_masslift_len18.8_rotorcount_bankderate2/island_{1,2,3}/telemetry.csv`) · data commit `dd3cc6a` · run `a76c5e9` · rows: NR-001, NR-005, NR-006 · row want: PCA projection summary · script: `docs/reporting/figures/pca-atlas/pca-atlas.py` at `3d36c7a`

## Checks for the consistency pass

- One form per concept. The panels read by gene slot (x1..x10). The
  journey marks read "the common seed" and "the winner".
- Every value cites a register row. The projection carries the row
  want.
- The panel titles read the genome glossary names.

**Delta** v1 (2026-10-13): created with the kit landing.

# Captions: the parameter atlas

**Slug** `pca-atlas`. **Status** GENERATE. **Date** 2026-10-13.
**Cite fix and re-cut** 2026-10-14.

Site: the report at §3.4, beside the levers reading. Reading order: the
landscape, then the atlas. The wording comes from the figures seat,
STE-gate checked. Values cite NR-001, NR-005, NR-006 and NR-044.

The provenance line resolves to the figure-provenance appendix (draft
v0.15).

The split: the plain and technical captions carry the scientific text
only. The provenance line carries the audit tokens: data commit, run,
rows and script commit. The report prints the scientific captions. The
plate stamp and the appendix carry the provenance.

## Plain caption (takeaway — one sentence, jargon-free)

One map of the search space, coloured ten times: each panel shows
where one design gene runs high or low across the search.

## Technical caption (undergrad register, STE-clean form)

The figure repeats one PC1-PC2 projection of the 930-design screen ten
times, once per gene slot (NR-001). The projection and the journey
marks match the levers landscape plate. Each panel colours the cell
mean of that gene over all 930 designs. The star marks the common seed
(36.109, NR-006). The diamond marks the winner (27.364, NR-005). The
thin lines trace the island journeys. The colour bars print each gene
at three significant figures. The projection reads NR-044: PC1 22.4 per cent, PC2
17.3 per cent.

## Provenance line

data: island telemetry (`scripts/results/v13_5kw_masslift_len18.8_rotorcount_bankderate2/island_{1,2,3}/telemetry.csv`) · data commit `dd3cc6a` · run `a76c5e9` · rows: NR-001, NR-005, NR-006, NR-044 · script: `docs/reporting/figures/pca-atlas/pca-atlas.py` at `e23f226`

## Checks for the consistency pass

- One form per concept. The panels read by gene slot (x1..x10). The
  journey marks read "the common seed" and "the winner".
- Every value cites a register row. The projection reads NR-044.
- The panel titles read the genome glossary names.

**Delta** v4 (2026-10-14): the seating header refines. The caption text stands.

**Delta** v3 (2026-10-14): the cites take the register mapping. The
provenance line takes the re-cut script commit. Caption text only.

**Delta** v2 (2026-10-13): NR-044 signs. The row-want sentences now
cite the row. Caption text only, no render moves.

**Delta** v1 (2026-10-13): created with the kit landing.

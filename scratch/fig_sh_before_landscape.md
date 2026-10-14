# Captions draft: the levers landscape

**Slug** `pca-landscape`. **Status** DRAFT. Review input for the author
seat, @author. Ledger strings only. The caption plan of `SPEC.md` is
the contract. The provenance line resolves to the figure-provenance
appendix.

## Plain caption (takeaway — one sentence, jargon-free)

One seed, three islands: this figure maps the search journeys in gene
space and shows where the light machines live.

## Technical caption (undergrad register, STE-clean form)

The figure projects the 930-design screen of the v13 5 kW campaign on
its first two principal components (NR-001). The axes come from a
z-scored matrix of the ten genes. Colour is the cell mean of the search
objective in kg-equivalent. Bright reads lower. Three lines trace the
island best-so-far paths, one step per generation. The common seed
starts at 36.109 (NR-006). The winner ends at 27.364 (NR-005). The
PC1 inset reads larger main-rotor blades, wider ring spacing and a
wider ground ring to the right, and more TRPT lines and more rotors to
the left. The PC2 inset reads a deeper second-rotor bank, smaller
second blades and rings biased toward the ground upward. The variance
shares read PC1 22.4 per cent and PC2 17.3 per cent (NR-044).

## Provenance line

data: island telemetry (`scripts/results/v13_5kw_masslift_len18.8_rotorcount_bankderate2/island_{1,2,3}/telemetry.csv`) · data commit `dd3cc6a` · run `a76c5e9` · rows: NR-001, NR-005, NR-006, NR-044, NR-045 · script: `docs/reporting/figures/pca-landscape/pca-landscape.py` at `e23f226`

## Checks for the consistency pass

- One form per concept. The seed reads "the common seed". The winner
  reads "the winner (island 3)" where the island matters.
- Every value cites a register row. The variance shares cite NR-044.
- The sentinel rows draw nothing, so no caption claims them.

**Delta** v3 (2026-10-14): the cites take the register mapping. The
provenance line takes NR-045 and the re-cut script commit. The
objective form reads kg-equivalent. Caption text only.

**Delta** v2 (2026-10-13): NR-044 signs. The row-want sentences now
cite the row. Caption text only, no render moves.

**Delta** v1 (2026-10-13): created with the kit landing.

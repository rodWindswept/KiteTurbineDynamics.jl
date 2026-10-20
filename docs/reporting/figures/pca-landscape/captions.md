# Captions: the levers landscape

**Slug** `pca-landscape`. **Status** GENERATE. **Date** 2026-10-13.
**Cite fix and re-cut** 2026-10-14.

Site: the report at §3.4, beside the levers reading. Reading order: the
landscape, then the atlas. The wording comes from the figures seat,
STE-gate checked. Values cite NR-001, NR-005, NR-006, NR-044 and NR-045.

The provenance line resolves to the figure-provenance appendix (draft
v0.15).

The split: the plain and technical captions carry the scientific text
only. The provenance line carries the audit tokens: data commit, run,
rows and script commit. The report prints the scientific captions. The
plate stamp and the appendix carry the provenance.

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

data: island telemetry (`scripts/results/v13_5kw_masslift_len18.8_rotorcount_bankderate2/island_{1,2,3}/telemetry.csv`) · data commit `dd3cc6a` · run `a76c5e9` · rows: NR-001, NR-005, NR-006, NR-044, NR-045 · script: `docs/reporting/figures/pca-landscape/pca-landscape.py` at `d0e410d`

## Checks for the consistency pass

- One form per concept. The seed reads "the common seed". The winner
  reads "the winner (island 3)" where the island matters.
- Every value cites a register row. The variance shares cite NR-044.
- The sentinel rows draw nothing, so no caption claims them.

**Delta** v5 (2026-10-20): the provenance line takes `d0e410d`, not `e23f226`. The T4 render pass (`d0e410d`, landed `f696930`) re-cut this plate, and the manifest `script_commit` reads `d0e410d`. The four recorded output hashes match the files on disk, so `d0e410d` is the state that built the bytes. Caption text only, no render moves. (figures seat)

**Delta** v4 (2026-10-14): the seating header refines. The caption text stands.

**Delta** v3 (2026-10-14): the cites take the register mapping. The
provenance line takes NR-045 and the re-cut script commit. The
objective form reads kg-equivalent. Caption text only.

**Delta** v2 (2026-10-13): NR-044 signs. The row-want sentences now
cite the row. Caption text only, no render moves.

**Delta** v1 (2026-10-13): created with the kit landing.

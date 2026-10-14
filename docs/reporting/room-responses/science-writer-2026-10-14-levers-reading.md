# Room response: the levers reading, supplied for the section 3.4 fold (2026-10-14, science-writer)

**Status** LANDED (supply). **Seat** science-writer. **Read at** `ec56301`.

This response changes no draft line, no register row and no glossary row.
The fold sits with @author.

## What this supplies

This response supplies the reading text for section 3.4 (the levers).
The gates stand met. NR-044 signed at `2ad023c`, the founder passed
the first cut, and the F-VALUE counter-read signed at `331f60d`.

The text mirrors the kit axis names from the label ledgers.
The kits are `pca-landscape` and `pca-atlas`.

It prints only signed rows: NR-001, NR-005, NR-006, NR-044 and NR-045.
The shares print at the drawn precision (22.4, 17.3, 39.7 per cent).
The axis loadings print at the row form, four decimals, the top trio per axis.

## The reading text (fold-ready)

<!-- LEVERS-READING-Start -->
The two plates map the same search in two views.
They project the 930 designs of the campaign onto the first two
principal components of the ten-gene search (NR-001).
Those axes hold 22.4 and 17.3 per cent of the variance in the search,
39.7 per cent together (NR-044).

The horizontal axis is PC1 — blade scale against unit count.
Its inset reads larger main-rotor blades, wider ring spacing and a wider ground ring to the right.
It reads more TRPT lines and more rotors to the left.
The top loadings read -0.5385 for the TRPT line count, -0.5222
for the rotor count and +0.5180 for the main-rotor blade scale (NR-044).

The vertical axis is PC2 — second-rotor and clustering settings.
Its inset reads a deeper second-rotor bank, smaller second blades and
rings biased toward the ground upward.
It reads even rings, a shallow second bank and larger second blades downward.
The top loadings read +0.5621 for the second-rotor bank, -0.5605
for the second-rotor blade scale and -0.5018 for the ring density profile (NR-044).

The colour is the mean search objective in each cell, in kg-equivalent.
Bright reads lower, and only feasible designs shade the field.
The low-objective cells gather toward the upper right, where the winner sits.

Three lines trace the island best-so-far paths, one step per generation (NR-045).
Each island ran 31 generations.
All three start at the common seed, 36.109 kg-equivalent (NR-006).
Island 3 reaches the winner value, 27.364, at generation 26 and holds
it to the end (NR-005).
Islands 1 and 2 finish lower in the field.

The atlas repeats the projection ten times, once per gene slot.
Each panel colours the mean value of one gene across the field.
The star marks the common seed and the diamond marks the winner.
The atlas lets a reader follow one gene at a time across that ground.

The two plates fix the search frame.
They show where the search went, how light the designs get and how
each gene tracks across that ground.
The gene-level effects wait on the landscape extracts.
<!-- LEVERS-READING-END -->

The block covers the two landed plates.
The thrive and fail status view stays a proposed row (row 22).
If it lands, the reading gains its pass.

## Gate-sim

- Fold-sim: the sim applies the block to the v0.31 draft (`76655cb`)
  and retires the section 3.4 bracket, at `scratch/sw_levers_fold_sim.md`.
  STE words 4538 to 4882, total held at 5, rc=0.
  The offender set moves by the header line alone.
  The sim adds one guidance-only hook line: `em_dash x2`, both inside
  the frozen axis names.

- Token watch, insertion-only, on the sweep pattern.
  Net arrivals: `0.5180`, `0.5621`, `17.3`, `22.4`, `26`, `27.364`, `3`,
  `31`, `36.109`, `39.7`, `5018`, `5222`, `5385`, `5605` and `930`.
  Net removals: none.
  The raw side reads 17 added occurrences against 2 removed.

- The `1` and `2` of the retired bracket pair out against the block.
  The minus-signed loadings read as their fraction part under the
  pattern. `5385` stands for -0.5385.

- Freeze check: the block reads byte-identical between this receipt
  and the sim region (`scratch/sw_levers_freeze_check.py`, output in
  `scratch/sw_sweep20_final_checks.log`).
  Block md5 `7bbd964db09d2b33269ce5cb8c334054`, sim md5 `9e1f673fba06cc4aed4fb8b80c368149`.

## Flags

- @author the fold position sits with the section plan.
  The closing line about the landscape extracts can merge with the
  PL5 stub line.

- @science-validator three candidate glossary terms ride the v14
  candidates record for Track D: principal component, loading and
  variance share. The block glosses each at first mention.

- @aero-validator the fresh counter-read on the re-cut levers pins is
  the last gate before the fold (figure map, rows 20 and 21).

## Deltas

- v1 (2026-10-14): created.

science-writer, 2026-10-14

#!/usr/bin/env python3
"""Apply the receipt lint fixes to the template by anchor regions (science-writer, 2026-10-14).

Replaces the 'What this supplies' and 'Gate-sim' regions between their headings,
and the 'first use' phrase. All-or-nothing with asserts.
"""
import pathlib

p = pathlib.Path.home() / "Documents/GitHub/KiteTurbineDynamics.jl" / "scratch/sw_levers_receipt_template.md"
t = p.read_text()
a1 = t.find("## What this supplies")
assert a1 != -1, "anchor 1"
b1 = t.find("## The reading text")
assert b1 != -1, "anchor 2"
s1 = """## What this supplies

This response supplies the reading text for section 3.4 (the levers).
The gates stand met. NR-044 signed at `2ad023c`, the founder passed
the first cut, and the F-VALUE counter-read signed at `331f60d`.

The text mirrors the kit axis names from the label ledgers.
The kits are `pca-landscape` and `pca-atlas`.

It prints only signed rows: NR-001, NR-005, NR-006, NR-044 and NR-045.
The shares print at the drawn precision (22.4, 17.3, 39.7 per cent).
The axis loadings print at the row form, four decimals, the top trio per axis.

"""
t = t[:a1] + s1 + t[b1:]
a2 = t.find("## Gate-sim")
assert a2 != -1, "anchor 3"
b2 = t.find("## Flags")
assert b2 != -1, "anchor 4"
s2 = """## Gate-sim

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
  Block md5 `%%BLOCKMD5%%`, sim md5 `%%SIMMD5%%`.

"""
t = t[:a2] + s2 + t[b2:]
c = t.count("at first use.")
assert c == 1, f"first use count {c}"
t = t.replace("at first use.", "at first mention.")
p.write_text(t)
print("template v2 edits applied")

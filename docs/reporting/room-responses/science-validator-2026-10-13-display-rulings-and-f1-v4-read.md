# Room response: display rulings and the F1 v4 read (2026-10-13, science-validator)

**Status** The display notes take the founder call. The FoS sites fold to 15.0 and the section 3.3 lift chain takes report forms. The F1 v4 plate reads clean from this seat. **Seat** science-validator. **Read at** HEAD `0415d18`. Committed bytes plus fresh runs.

## 1. The FoS call: every report display site reads 15.0

The founder call lands in the tracker as a standing rule. The factor of safety prints at 1 dp in the report, and full precision stays internal (`2ebbd22`, tracker display forms). This seat takes the call into the register note.

The note update replaces the last sentence of the FoS note (`8fb529e`). That sentence kept the row-form sites at 14.972. The call covers the report display sites, so they fold. The sweeps now read one basis.

Fold list at `0415d18` (each 14.972 becomes 15.0):

- Line 72, the front summary block: "Its minimum factor of safety is 14.972 (NR-009)."

- Lines 412 to 413, section 3.3: "Its factor of safety reads 14.972 (NR-009)."

- Line 422, the section 3.3 table: "| Minimum factor of safety | 14.972 | NR-009 |".

- Line 452, the section 3.3 gates table: "pass, 14.972 minimum" reads "pass, 15.0 minimum".

- Line 637, section 5: "its factor of safety 14.972 (NR-008, NR-009)".

Token set for the fold: remove five `14.972`, add five `15.0`. The abstract already reads 15.0, and no other site prints the value.

Boundary: the capture hub ring reading (15.033, NR-021) keeps its form. It is the other number on the disambiguation line, not the machine factor of safety. The room can widen the call in one line if it reads the rule to cover every ring reading.

## 2. The section 3.3 lift chain: report forms

The chain printed the 6 dp operand:

"The vertical load is 1.5 × 20.698468 × 9.81 = 304.58 newtons."

The ruled forms:

- The sizing mass prints at `20.698`. That is 3 dp, the report mass form. The sentence above the chain reads 20.698 kilograms.

- The vertical load prints at `304.6`. That is 1 dp, the force form. NR-010 reads 324.1 N at 1 dp.

- The chain holds as displayed. The rounded operands give 304.571. Both the rounded operands and the full value read 304.6 at 1 dp.

- The 2 dp forms disagree on the last digit (304.57 against 304.58). The result takes the coarser form, and the two bases agree there.

Token set: remove `20.698468` and `304.58`. Add `20.698` and `304.6`. No signed row moves. NR-037 keeps 20.69846825623688 and 304.5779603905257. The full values stay internal.

## 3. The F1 v4 read: the plate census and the register note

The v4 re-cut (`a66b8d2`, generator `9cecee3`) reads clean from this seat.

- The census (evidence) extracts the drawn text from the built PDF, the mutool text layer. Every decimal readout maps to a signed row: 1.499 (NR-043), 4.580 and 0.804 (NR-011), 7.088 (NR-017). The 5 m bar reads as the drawn scale. No other number prints. The integer tokens read as labels and row codes alone.

- The dimension and its label draw: "blade span", "1.499 m". The drawn source line reads the row list NR-011 · NR-017 · NR-043. A seat spot-check of the built PNG finds the dimension, the extension lines and the label leader in place.

- The kit check script re-ran clean. Its rc reads 0, and the re-run log matches the committed log byte for byte. The five md5s and the five manifest hashes recompute. Evidence: `scratch/sv_f1_v4_check_rerun.log`.

- The register note reads back. The NR-043 row cites the signed row (`88277f6`) and the drawn form 1.499 m at three decimals. The re-cut record carries `9cecee3` and delta v2. The no-other-geometry claim holds over the landing: the kit files, the additive element-library line, the map, and the draft alone.

- The draft appendix carries the v4 pins. The exhibit row reads NR-011, NR-017, NR-043 at `9cecee3`, and the four hash lines match the manifest.

Nothing to move for the figures seat. The next build picks the plate bytes.

## 4. Gates and evidence

- STE: this receipt reads 0.13/100w, rc=0. The register moves 1.02 to 1.00 per100w, additions only, zero deletions.

- Evidence: `scratch/sv_display_sites_check.py` and its log, `scratch/sv_f1_v4_census_check.py` and its log, `scratch/sv_f1_v4_check_rerun.log`, `scratch/sv_lint_register_baseline.txt` and `scratch/sv_lint_register_after.txt`.

## Handoffs

- @author: the fold list above at the next pass. The sweeps can then re-account.

- @fig-img-diagrams: the census holds, and the footer row list carries NR-043 as planned. Nothing to move.

- @user: the report reads 15.0 for the factor of safety at every site. The lift chain reads 304.6 newtons. The full precision stays internal.

---

science-validator, 2026-10-13.

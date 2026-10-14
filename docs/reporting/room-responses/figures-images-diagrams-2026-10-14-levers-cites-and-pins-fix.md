# Room response: the levers cites and pins fix (2026-10-14, figures seat)

**Status** LANDED. The fix pass for the two defects routed by the F-VALUE
counter-read. **Seat** figures-images-diagrams. **Read at** `6255268`.
**Script commit** `e23f226` (the recut generators).

## 1. What lands

- **Defect one, the cite map.** The NR-005 and NR-006 cites take the
  register mapping on both kits, ten lines across six files. NR-005
  carries the winner value 27.364 at gen 26. NR-006 carries the common
  seed 36.109. Text only. This fix alone moves no render byte.
- **Defect two, the stamp re-cut.** Both drawn row lists take NR-044.
  The landscape list takes NR-045 too. The landscape projection stamp
  leaves the pending form and reads "variance shares NR-044". The
  manifest register rows take the same sets. The row_wants fields
  empty.
- **The checks.** The landscape gains the two drawn share checks (22.4
  and 17.3) and the generation-count check (31 per island, NR-045). A
  drift now fails the run.
- **The forms.** The landscape colour line and both strip caption tiers
  read kg-equivalent. The drawn labels keep their (kg) form, per the
  round-3 routing. NR-045 joins the landscape rows table, the readout
  list, the drawn precision and the caption provenance. The subtitle
  count keeps.
- **The pins.** The kit notes carry the v3 hash blocks. The reproduce
  commands cite the new stamp.

## 2. Evidence

- Two full runs stay byte-identical across all five outputs per kit.
  Log: `scratch/fig_pca_fix_check.log`. Precheck log:
  `scratch/fig_pca_fix_precheck.log`. Run-A md5s:
  `scratch/fig_pca_fix_runA.md5`. Edit scripts:
  `scratch/fig_pca_fix_edit.py`, `scratch/fig_pca_fix_docs_edit.py`,
  `scratch/fig_pca_fix_map_edit.py`.
- F-LABEL re-walked: 46 and 37 strings, set-equal to the SVG text
  layers in both directions. The kit-note hash blocks recompute from
  the live bytes.
- Vision rounds: the precheck set and the delivered set. The journey
  inset reads 31 generations each.

## 3. Records updated

- `register-status.md` on both kits: the cite rows, the NR-045 row and
  closure, the drawn precision, the v3 hash block, the dates.
- `SPEC.md` on both kits: the readout lists, the deltas v3, the
  counter-read lines.
- `captions-draft.md` on both kits: the cites, the provenance lines,
  the deltas v3.
- `machine-evolution-strip/captions.md`: the kg-equivalent form and the
  form note. Text only. No strip render moves.
- `figure-map.md`: rows 20 and 21, delta v26.
- No draft surfaces change. The draft master carries no levers rows
  yet. The fold adds them.

## 4. Handoffs

- @aero-validator: the re-census on the new pins, one command.
- @author: the caption text and the plates are released. The section
  3.4 pointers may ride.
- @science-writer: the reading mirrors the same axis names. The cites
  take the register mapping.

---

figures-images-diagrams, 2026-10-14.

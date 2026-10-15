# Room response: the corner-grid F-CITE and F-VALUE counter-reads (2026-10-15, aero-validator)

The corner machines close at the aero desk.

**Status** The pass closes clean. 153 checks, 0 fail (148 static, 5 repro). Two cite findings ride the figures seat.

**Seat** aero-validator. **Read at** `ec19c2f` (local == origin). **Kit** `docs/reporting/figures/machine-corner-grid/` at script commit `a4b4057`.

**Evidence** `scratch/av_cg_cite_value.py` and its log. `scratch/av_cg_repro_check.py` and its log. Run logs `scratch/av_cg_run1.log` and `scratch/av_cg_run2.log`.

This pass answers the figures-seat handoff for the generator landing. It reads committed bytes and the raw bankderate2 telemetry. It recomputes the projection and the four picks from the raw draw columns. It runs the Reproduce command the kit records. The two fresh runs took 22 seconds each.

## 1. The bytes, the pins and the stamps

- The delivered set reads the manifest. The extract reads `03abd0c6…` and the script reads `9fd01644…`. The four output pins recompute.
- The PNG reads 2616 x 1848. That is three times the 872 x 616 figure. The SVG root reads 872 x 616.

- `checks.log` reads ALL OK. The four panel decode lines hold six checks each. The corner order reads OK. Four objective labels draw. One CreationDate replacement reads.

- The window and squareness lines recompute from the manifest scale. The window reads x ±6.211 m and y -0.759 to 19.742 m at 0.060299 m/px. Both axes read 16.583913600 px/m.
- The viewport line re-derives from the layout arithmetic. Panel4 sits at 666. That reads 3 x (206 + 16).

- The stamps read their cites. Stamp 1 carries data commit `dd3cc6a`, the extract id and `[1,99]` (NR-051). Stamp 2 carries rows `NR-044 · NR-051`, script commit `a4b4057`, the engine and the normalised date. Stamp 3 carries the shaft-frame note. The PDF carries the normalised date alone.

- The SVG carries glyph paths. The text layer reads zero (0 `<text`). The recorded R2 item reads as stated.

- The knobs equal the recorded campaign constants. `k_mppt` reads 2.24, the NR-015 value. The blocking factor reads `0.85^(1/3)`. Power reads 5000 W. `v_rated` reads 11. The length reads 18.8 m.

## 2. The extract and the raw rows (panel binding)

- All 32 fields x 4 rows byte-equal the source telemetry rows. The three files read their last touch at `dd3cc6a`. The raw set reads 930 rows and 310 per island.
- The status mix reads 508 ok, 301 reject, 110 clearance-reject and 11 reject-twist.

- The genome vector is byte-equal to the extract at all 40 cells. The tags on the strips bind each panel to its extract row.
- The `r_hub` and `r_bot` columns take round(x1/x2, 3). The `n_lines` column reads the integer gene.
- The extract header resolves. It carries the run-id, the dataset (`dd3cc6a`, launch `a76c5e9`), the era and the computing commit `b02ecdf`.

## 3. The recompute (F-VALUE)

- From the raw draw columns (z-score, SVD): PC1 share 22.4346665772, PC2 17.2630436556, pair total 39.6977102328. These read the NR-044 forms at 10 dp. This pass recomputes them and does not re-read them.

- The anchors gate. The seed reads (0.531, -1.297) at fit 36.109. The winner reads (0.885, 2.869) at fit 27.364 on island 3.

- The [1,99] window re-derives as -5.133 .. 1.671 on pc1 and -2.178 .. 3.125 on pc2. Each corner pick re-derives to the signed tag. The distances read 3.796523, 4.254840, 0.874883 and 0.074376.

- The fits gate at 6 dp as 60.646000, 58.864000, 33.704000 and 33.812000. They print at the NR-051 3-dp forms. The pc columns equal the extract at full precision.

- The composition reads as the mint records. The two low-PC1 picks are many-line two-rotor machines. The two high-PC1 picks are one-rotor machines.

## 4. The drawn-text census (F-VALUE, the plate)

- The delivered PDF carries a text layer. The SVG does not. The census reads the title once, the subtitle once, four corners and four tags. Four `objective X kg` strips read in the NR-051 left-to-right order.

- The census reads the seven legend entries, the `5 m` scale bar and the three stamps. No other digit token prints.
- The retired word reads zero in the drawn text. The stray values all read zero on the plate. They are 4.580, 15.033, 27.364, 36.109, 5.309, 22.4 and 17.3.

## 5. F-REPRO, my runs

- Two fresh runs ran the delivered script at the delivered extract at `a4b4057`. They ran the Reproduce command the kit records, plus `--outdir`. All five outputs read byte-identical across the delivered set and both runs.
- The three-location table from the figures seat reconciles. Its `inplace` md5s equal the delivered md5s at all five entries.

## 6. The findings (2, cite precision)

- `docs/reporting/figures/machine-corner-grid/register-status.md` line 11 cites NR-051 as signed at `8855d9a`. `docs/reporting/figures/figure-map.md` row 23 reads the same cite. That commit is the seat page that follows the sign.
- The sign lands at `cb862df`. The register append (`git -S`), the science-validator seat page and sweep 30 all read that commit. Sweep 30 reads "takes the NR-051 row at `cb862df`, append-only."

- The row convention matches. The NR-044 row cites its sign commit (`2ad023c`).
- The fix: `8855d9a` to `cb862df` at both sites. Text only. No render moves and no re-pins.

## 7. Boundaries

- The vector file was not re-parsed path-by-path. The F-PARSE and F-COUNT class beyond the layout arithmetic rides the counter-run. That run re-executed every in-script check byte-identically.
- The visual checklist (no part against an edge, the legend legibility at print size) rides the pass by Rod.

**Handoffs.**

- @fig-img-diagrams: the two cite lines take `cb862df` at your next touch. Text only.
- @science-validator: the register read. The drawn forms read NR-051 to the signed digits. The recompute at this seat agrees at every anchor.

- @author: the kit reads clean. The fold can take it when the room routes the founder nod. The copy counter-read follows here.
- @hermes: the queue can record the counter-reads closed (row 23).

- @user: the four corner drawings read clean at this desk. Every printed number is the signed number. A fresh run rebuilds them byte for byte. The only find was two lines that name the wrong commit for the sign record. That is a text fix you will not see.

---

aero-validator, 2026-10-15.

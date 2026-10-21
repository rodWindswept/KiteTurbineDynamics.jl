# Room response: NR-074 to NR-077 counter-read (2026-10-21, aero seat)

**Status** The four rows verify. This read ran its own arithmetic, not the
arithmetic of the checker. Script `scratch/av_lever_set_counterread.py` holds
91 checks, 0 fail, plus a full value cross-check of the five committed
extract files, 0 fail.

**Source pins, verified before the read.** The three island telemetry files
on disk match the blobs at data commit `dd3cc6a`. The blobs read island 1
`5a5561cc`, island 2 `b0fce176`, island 3 `21c826b1`. Row totals read 930,
310 per island. The status mix reads 508 ok, 301 reject, 110
clearance_reject and 11 reject_twist.

**What the read confirms, per row.**

- NR-074. All ten rho values at 4 dp, all ten shifts at 3 dp, the rank order
  by absolute rho, and the bin pair populations on every row recompute from
  the 508 ok rows. The `rotor_count` top-bin median reads 59.755 exactly, the
  midpoint of its two designs. The tie structure behind the three
  `blade_scale_top` bins holds. 263 of 508 sit at exactly 1.0, and 305 at or
  above 0.995842.
- NR-075. All 13 census rows verify cell for cell across all three tables.
  `n_active` differs from `rotor_count` on exactly 10 rows, every one
  `clearance_reject`. The x6 gene decodes to 3 while the recorded column
  reads 2, and no ok row moves between the columns. Clearance rejections sit
  91 at two rotors, 19 at three, zero at one.
- NR-076. The three sums 1462.3155, 506.3577 and 141.1349 and the total
  2109.8081 recompute from the recorded columns at recorded precision.
  Shares read 69.31, 24.00 and 6.69. Dominance reads 453, 46 and 9, summing
  to 508. Medians and maxima verify at the printed precision, with the
  maxima order utilisation above over-power above twist. The single zero
  over-power row is real, not a sentinel: island 1, gen 8, idx 4, `P_end`
  exactly 5.0, fitness 33.684.
- NR-077. The 46 bins carry per-gene counts 5/5/5/7/5/2/5/5/3/4 and counts
  run 1 to 506. The four thin bins are exactly `n_lines` 6 (3), 8 (1), 9 (1)
  and `rotor_count` 2 (2). Mean sits above median in 42 of the 46 bins. The
  three thin-bin exceptions are equal by construction, and `target_Lr` q4 is
  the fourth with 102 designs, median 32.068 and mean 31.784 at 3 dp. Among
  the 42 bins holding five or more designs the count is 41 of 42.

**The extract agreement.** The five files under
`docs/reporting/figures/lever-statistics-extract/` match the recomputation
of this read at 1e-12 on every value checked: rho, delta, bin medians, means
and counts, all 13 census cells, all three channel sums, shares, medians,
maxima and dominance counts, plus the full t6 row at island 1 gen 8 idx 4.
The register statement that the raw rows are the basis of the signature
holds.

**One boundary confirmed from the aero side.** Reject-row sentinels never
enter these rows. Every signed value reads either the 508 ok rows or the
status column, so the `twist_ratio` 0.0 defaults and the `FoS` Inf sentinels
on early rejects cannot leak into any signed number. The conditioning
boundary in NR-074 and NR-077 is the right guard.

No signed row changed. The register carries no edit from this read. The
script stays in scratch as evidence.

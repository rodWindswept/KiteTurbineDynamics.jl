# The corner grid builds: the generator lands

**Seat:** figures-images-diagrams (@fig-img-diagrams). **Date:** 2026-10-15.
**Base:** `c35a0cf` (the v0.47 copy counter-read close). **Landing:**
`a4b4057` (the generator), then the records, seat page and readback
commits of this train.

## 1. The generator lands

- The plate: four panels, one per corner of the PC1-PC2 field. Each
  panel is the nearest feasible design to its [1,99] window corner
  (NR-051). One shared scale, one window, the shaft frame.
- The label strips carry the corner name, the identity tag and the
  search objective at its signed 3 dp form: `i1-g13-i1` 60.646,
  `i1-g7-i7` 58.864, `i2-g21-i4` 33.704, `i3-g26-i8` 33.812.
- The generator reads the pinned extract
  (`corner-grid-extract-2026-10-15-picks`, sha256 `03abd0c6…`, byte
  unchanged) and the recorded campaign knobs, with `v_rated`
  threaded. No ODE.
- The plate takes the `-dg` and `-zg` PDF normalise, the fixed form
  from the hero kit. The strip predates it.

## 2. The checks and the F-REPRO walk

- All in-script checks pass: the per-panel decode checks (n_lines,
  rings, n_active, r_hub, r_bot, objective) at all four panels, the
  NR-051 corner order, and the objective labels. The window reads
  x ±6.211 m, y -0.759 to 19.742 m, m_per_px 0.060299, and the axes
  square at 0.0000 ppm.
- F-REPRO: the kit rendered in place and twice into scratch outdirs,
  all at `a4b4057`. All five outputs (png, svg, pdf, manifest,
  checks.log) read byte-identical across the three locations. The
  table sits at `scratch/fig_cg_repro.md5`.
- The vision pass on the delivered stamped render reads clean: four
  machines, the stamps, no clipping.
- The landing check `scratch/fig_cg_landing_check.py`: 43 checks,
  0 fail.

## 3. The records

- SPEC delta D10 records the family mode, corner variant.
- The map: row 23 moves to R2 and takes the landing. Delta v39
  appends.
- The kit gains the captions (plain, technical, provenance line), the
  register note (rows NR-044 and NR-051, the drawn forms, the walk)
  and the README state.
- The delivered set: png, svg, pdf, manifest, checks.log, plus the
  extract and its log from the earlier pass.
- STE per 100 words: map 1.81, SPEC 1.40, README 1.07, captions 1.45,
  kit note 1.58, seat page 0.29, receipt 1.21. The bar is 2.0.
- Readback: every committed blob of this train byte-read at origin.
  Local matches origin.

## 4. The gates ahead

- @aero-validator: the F-CITE and F-VALUE counter-reads queue on the
  delivered bytes (the four panels, the manifest pins, the extract
  sha).
- @science-validator: the register read (the NR-051 forms as drawn).
  No new row mints.
- The visual pass by Rod follows. The appendix row joins when the kit
  seats.

**Handoffs.**

- @aero-validator: the generator lands (`a4b4057`). The corner F-CITE
  and F-VALUE reads can open at your desk.
- @science-validator: the drawn forms read NR-051 to the signed
  digits. The extract certificate stays pinned.
- @author: the kit is unseated. No draft byte moves.
- @hermes: the queue can record the build.
- @user: plain. The four corner machines now draw from their exact
  data, at one scale, with their objectives printed. The checkers
  read them next, and the drawings join the report at the next fold.

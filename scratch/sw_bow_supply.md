# Supply: the bow row, landed at v20 (science-writer seat)

**Date** 2026-10-15. **Target** `docs/reporting/glossary-candidates.md`.
**Base pin** md5 `c0d82058355ce53118d675ed30162b43`, the blob at `c4bd90d`.
**Candidate** md5 `8a4bcbf75a42a8ee6a87e3e097bc9d6d`.
**Word** the founder ruled "up" on 2026-10-15. The row lands.

## 1. The landed row (section 2, after the destructive-resonance row)

| bow | The lateral sag of the column axis off the design line, in the tilted plane. The perpendicular part of the hub weight causes it. The stack does not translate sideways: the bow is a rearrangement in which the lines reorient at near-constant length. The report holds it as an output, not a constraint. The settle calculation and the run must agree on it. | `DECISIONS.md` [2026-09-15] ruling 2, 2026-09-12 handover sections 2 and 5 | supply |

## 2. The landed guard row (section 7, the last row of the table)

| Do not write | Write | Ground |
|---|---|---|
| "bow" as a sideways move, or a stack translation | bow: a line rearrangement at near-constant length. The stack does not translate sideways. | `DECISIONS.md` [2026-09-15] ruling 2 |

## 3. What changed from the v19 staged text

Three items, each from the read at the aero desk.

- **The third sentence.** The staged form could read as a bar on lateral motion.
  That reading sits against the first clause of the entry.
  The bow is the lateral deflection, so the bar contradicts the entry.
  The landed form keeps the operative word and names the rearrangement.

- **The ground cell.** The staged cell named `docs/agents/physics-topology.md`.
  That document carries no bow entry, so the name is wrong there.
  The landed cell cites the 2026-09-15 ruling and the 2026-09-12 handover.

- **The guard row.** It takes the mirror form, so one bar reaches the reader.
  The old form carried a nominalization the linter scores.

## 4. The founder word and the value slot

The founder ruled "up" on 2026-10-15.
In those words: the report states any bow effect, and it prints a value if the
probe gives one.

- **The value.** The row carries no value.
  The probe at the aero seat supplies the winner read.
  The register row signs that read, and the report sentence cites the row.

- **The stations.** The record reads the bow at three named stations.
  The profile max is the per-ring perpendicular offset from the design axis.
  The hub offset is the perpendicular offset of the hub itself.
  The founder form is the midpoint ring belly drop from the common axis.
  Every number carries its value, its station and its state.

- **The founder line.** The founder reads a midpoint ring belly drop of 1.5 m
  from the common axis as highly concerning.
  That figure is the rigid-tilt estimate, and the ruling bars it as a result.
  A read meets the founder line at the same station and the same state.
  A comparison across stations waits for a mapping clause, and the read states
  the map.

- **Depth.** Later revisions of the report go deeper on the bow.

## 5. Grounds, read at the tip

- `DECISIONS.md` [2026-09-15] ruling 2 defines the bow as sag.
  The column axis bends laterally off the design line, in the tilted plane.
  It carries the perpendicular part of the hub weight.

- The ruling states one bar: the bow is not a translation.
  A global sideways move of the stack is very stiff, because the ground anchor
  stretches the lines.

- The real bow is a rearrangement, and the lines reorient at near-constant length.
  The ruling also bars the 1.5 m figure as a printed result, and it names a
  settle/ODE disagreement as a bug, not a design question.

- `handovers/handover-2026-09-12-settle-rebuild-bow-and-static-solver.md`
  section 2 gives the perpendicular weight split.
  Section 5 gives the near-constant line length of the rearrangement, beside
  the stiffness table.

- `docs/plans/ACTIVE.md` carries the open item this row closes for the winner:
  the settle and the ODE agree on the bowed shape.

- `scratch/diag_bow_shape.jl` prints the per-ring `r_perp` table and a
  max-bow line beside the hub offset, so the founder station costs no extra read.
  The station naming in section 4 comes from the science-validator read of
  2026-10-15.

## 6. Evidence set

- `scratch/sw_bow_fold.py` and `.log`: the assertion-guarded fold, 37 checks, 0 fail.
- `scratch/sw_bow_check.py` and `.log`: the independent checker, 39 checks, 0 fail.
- `scratch/sw_bow_ste_variants.py` and `.log`: the wording variants, each linted.
- `scratch/sw_bow_off_base.txt` and `scratch/sw_bow_off_new.txt`: the offender sets.
- `scratch/sw_bow_base.md` and `scratch/sw_bow_new.md`: the pinned base and candidate.

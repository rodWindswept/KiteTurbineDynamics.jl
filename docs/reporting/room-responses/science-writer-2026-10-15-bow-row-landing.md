# Receipt: the bow row lands (science-writer seat)

**Slug** `sw-bow-row-landing`. **Date** 2026-10-15. **Seat** @science-writer.

**Base** glossary candidates md5 `c0d82058355ce53118d675ed30162b43`, at HEAD
`6b6a0e1`. **Result** md5 `8a4bcbf75a42a8ee6a87e3e097bc9d6d`.

## 1. What landed

The founder word is "up" (2026-10-15), so the row staged at v19 lands at v20.

The candidates take the bow row in section 2, after the destructive-resonance
row. Section 7 takes its guard row as the last row of the retire table. The
status line moves to `PREP v20`, and one delta bullet records the landing.

The fold runs assertion guarded (`scratch/sw_bow_fold.py`). It reads 37 checks,
0 fail. The row census moves from 141 to 143, and the line count from 400 to 409.
A line-level diff proves the only changes are the status replace and three
inserts.

**Deltas.** The candidates move v19 to v20, with two rows, one status token and
one delta bullet. The supply takes the stations note. The v19 supply takes a
dated superseded pointer and keeps its text.

## 2. The aero desk read, folded

The desk read the staged third sentence as a bar on lateral motion. That reading
sits against the first clause of the entry, because the bow is the lateral
deflection.

The landed sentence keeps the operative word. It reads: "The stack does not
translate sideways: the bow is a rearrangement in which the lines reorient at
near-constant length."

The guard row mirrors it. The retired form reads `"bow" as a sideways move, or a
stack translation`. The replacement reads `bow: a line rearrangement at
near-constant length. The stack does not translate sideways.`

Both forms follow `DECISIONS.md` [2026-09-15] ruling 2.

## 3. Two corrections from this pass

- **The ground cell.** The staged cell named `docs/agents/physics-topology.md`.
  That document carries no bow entry, so the name is wrong there. The landed
  cell cites the 2026-09-15 ruling and the 2026-09-12 handover sections 2 and 5.
  The checker confirms that both grounds resolve in the tree.

- **The first landed draft tripped the gate.** It added one 21-word row tail,
  one 28-word guard row and two nominalizations. A variant probe over five
  wordings (`scratch/sw_bow_ste_variants.py`) picked the clean form. The file
  now reads 15 offences against a 15-offence baseline, with no added line.

## 4. The stations and the value slot

The row carries no value. The probe at the aero seat supplies the winner read,
and the register row signs it. The report sentence cites that row.

The record reads the bow at three named stations. The profile max is the per-ring
perpendicular offset from the design axis. The hub offset is the perpendicular
offset of the hub itself.

The founder form is the midpoint ring belly drop from the common axis.
Every number carries its value, its station and its state.
A read meets the founder line at the same station and the same state.
A comparison across stations waits for a mapping clause.

That rule comes from the science-validator read of 2026-10-15. Section 4 of the
supply carries it. The September instrument `scratch/diag_bow_shape.jl` prints
the per-ring table and the max-bow line, so the founder station costs no extra
read.

## 5. Scope

The pass changes two files: the candidates and the supply. The register takes no
change, and no draft byte moves.

## 6. Evidence

- The fold reads 37 checks, 0 fail (`scratch/sw_bow_fold.log`).
- The checker reads 39 checks, 0 fail (`scratch/sw_bow_check.log`).
- The variant probe sits in `scratch/sw_bow_ste_variants.py` and its log.
- The offender sets sit in `scratch/sw_bow_off_base.txt` and `scratch/sw_bow_off_new.txt`.
- The pinned base and candidate sit in `scratch/sw_bow_base.md` and `scratch/sw_bow_new.md`.

The checker re-derives the row bytes, the row order, the status token, the delta
block, the census, the grounds in the tree, the scope and the register. It reads
the base from git, not from the fold copy.

**STE** rc=0 at 0.29 per 100 words on the candidates. The offender set reads 15
before the fold and 15 after it. The new supply reads 0.00.

## 7. Handoffs

@author: the row lands, and the shape of the sentence holds. The value waits on
the probe and on the signed register row.

@aero-validator: the desk check closes. The landed text no longer reads as a bar
on lateral motion, and the station rule stands ready for the probe.

@science-validator: nothing opens. The row cites no register row, and the supply
carries the stations note.

@hermes: the queue can record the bow row landed at this seat and the bow call
closed.

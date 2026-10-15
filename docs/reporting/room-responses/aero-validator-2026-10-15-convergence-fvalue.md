# Room response: the F-VALUE counter-read for the convergence kit (2026-10-15, aero-validator)

**Status** F-VALUE PASS. **Seat** aero-validator. **Read at tip** `1c65d27`. **Kit bytes pinned at** `2361771`.

The figures seat handed the F-VALUE check of the row-16 kit to this seat. SPEC v1 reads: "@aero-validator owns this check, at the sign-off commit." This receipt records the pass. The census runs 39 checks. The repro leg runs 2 checks. Zero fail.

**Evidence** `scratch/av_cvp_fvalue.py`, log `scratch/av_cvp_fvalue.log`, repro log `scratch/av_cvp_repro.log`, md5 table `scratch/av_cvp_repro.md5`.

## 1. Pins

- Kit blob identity: all 10 kit files read worktree == HEAD == origin. No kit path moves in `2361771..HEAD`.
- Script: the manifest sha256 matches, and the source commit reads `0db99ac`.

- Input pins 4 of 4. Output pins 4 of 4. The register-status md5 block reads 5 of 5.
- Toolchain: /usr/bin/python3 3.12.3, matplotlib 3.10.8, numpy 2.4.4. All three match the manifest.

- Stamps: `dd3cc6a` (data) and `a76c5e9` (run) resolve. The run commit comes before the data commit, with no `src/` commit between them.
- The drawn era equals the raw telemetry header era (`post-95c385d_wind-authority`).

## 2. F-LABEL

- 39 text nodes, 34 distinct, set-equal to the ledger both ways.
- The duplicate census reads the shared tick numerals only: 0, 10 and 20 twice, 30 three times.

## 3. F-VALUE

- The stdlib recompute reads the three committed telemetry files.
- The status mix reads 508 / 301 / 110 / 11 (NR-002). The split reads 96 / 4 / 201 (NR-055).
- The floor-first overlap reads 34 of 96 (NR-055 basis).

- The per-island counts hold. The subgroup-B rows and reads hold. The 31 x 30 totals hold.
- The series: all 93 rows reproduce from raw telemetry on the strip rule, max deviation 0.0.

- Seed 36.109 reads NR-006. Finals 30.578, 30.637 and 27.364 read NR-003 to NR-005.
- The hold to generation 30 holds. NR-036 milestones read 7 of 7.
- The caption tier prints both island finals with the right rows (NR-003, NR-004). Every drawn legend count maps to the row that holds it.

- Geometry inverts through the tick transforms. The star sits at (generation 26, 27.364) inside 1e-8.
- The label anchors invert to their data slots inside 1e-6 px.
- All 186 bar segments recompute to the drawn counts (max residual 1.6e-7). All 93 curve vertices read back the extract values (max deviation 4.4e-8).

## 4. F-REPRO

- Two fresh runs at `0db99ac`, out of tree, byte-identical to the committed set. All five written outputs read equal across the three locations (15 of 15).
- The run stdout equals the committed `checks.log` byte for byte.

## 5. Boundaries and one query

- The visual pass stays with Rod. The register read stays with @science-validator.
- One query for that read: the parenthetical in NR-006 reads "(gen 1, common seed)". The strip rule records the pick at (gen 0, idx 1), and the seed label prints no generation. The values agree.

- This pass read the committed bytes and the toolchain above. It did not re-render through any other engine.

## Handoffs

- @fig-img-diagrams: the kit clears F-VALUE at this read. The map cell can take the pass at the fold.
- @science-validator: the register read runs beside this pass. One query rides above.

- @author: no fold waits on this pass. The section 3.2 fold keys on the plate and the counter-reads.
- @hermes: the queue can record the aero F-VALUE closed.

Recorded by @aero-validator (aero seat).

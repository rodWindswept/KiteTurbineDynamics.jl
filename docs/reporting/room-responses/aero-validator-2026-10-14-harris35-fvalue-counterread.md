# Room response: the Harris-3.5 counter-read, F-VALUE and F-REPRO on the mechanism pair (2026-10-14, aero-validator)

**Status** The kit gates pass. One defect, routed with fix lines. One query.

**Seat** aero-validator. **Read at** tip `25eb0eb`. Kit bytes pinned at `e4ff3c1`. Script commit `671ab96`.

**Evidence** `scratch/av_fig35_fvalue.py` and its log. 136 checks: 125 ok, 10 defect, 1 query, 0 fail.

This read answers the hand-off from @fig-img-diagrams. It covers figure-map rows 6 and 7. The pass reads committed bytes only. It runs no simulator.

## 1. The kit gates pass

- Pins. Every manifest pin recomputes on both kits. The script, the extract and all four outputs hold on each side.

- Stamps. Both stamps carry the script commit `671ab96` and the authority commit `f8114be`. The authority commit sits in the HEAD ancestry. The CSV header carries the computing commit, the data commit `dd3cc6a` and the capture id.

- The capture tokens `1724859` and `49.99999483862295` read in the register.

- Drift. No kit path moves in `e4ff3c1..HEAD`. Blob identity reads pin == HEAD == origin across all ten kit files.

- F-REPRO. Two fresh runs per kit, out of tree. The five outputs of each kit, the manifest included, stay byte-identical across the runs and against the committed set.

- F-LABEL. The SVG text set equals the ledger set in both directions. The count reads 28 strings and 55 strings.

- Census. Every ledger string classifies as a tick, a readout, a label, a text, a stamp or a drawn value. Zero strings sit unclassified.

## 2. The drawn values hold

Ring plate, five rings:

- Each ring reads `axial + bending = max_util` at residual zero, and `ring_fos = 1 / max_util` at ulp zero.

- Every extract token reads string-equal to its NR-021 chunk for its own ring. A swapped row would break this test.

- The five readouts recompute at the drawn precision: `15.033`, `29.807`, `30.087`, `35.236` and `326,974`.

- The caption bound holds. On the rings other than R5, the largest bending share reads 0.0408 per cent. The printed bound is 0.05 per cent.

Twist plate, five segments:

- Every twist, limit, torque and capacity token reads string-equal to the register. The S4 limit takes its own value, per the 2026-10-09 amend.

- The five torque margins recompute repr-equal to NR-040. S1 carries the least, 2.03.

- The floor arithmetic closes. `asin(1/1.05)` reads 72.247210 degrees, drawn as `72.25`. The basis reads in `DECISIONS.md`.

- The cite surfaces read the right values and the right direction: the notes, the two captions and the status notes.

No drawn value moves between the v1 and v2 renders. The drawn sets read identical on both plates.

## 3. One defect: the appendix re-pin

The draft figure-provenance appendix and the review copy still print the v1 render hashes for both plates. The plates re-rendered at `e4ff3c1`. The v0.23 anatomy delta records the convention: an exhibit row takes the new pins when a kit re-renders.

The review copy proves the defect inside one file. The copy embeds the delivered bytes. The ring PNG starts `f49aaaa1bda8d169` and the twist PNG starts `00cd857a5769be85`. The appendix prints the old block beside them.

Copy pin: `draft-live.docx` md5 `8324be7a204fbce3f3c6c38babcd62dc`. Draft pin: `6220660c65a16d8de4c2f2b1ee1ea84b` at `a3c2def`.

The other two exhibit rows (strip, anatomy) verify current. The defect touches the two plates only.

Ten substitutions clear it. The computed fix lines, verbatim:

```text
- `png` `6f19832088375b96cdc566aff596ccd548f26b629b9782bc56d8831d03c622ba`
+ `png` `f49aaaa1bda8d1699c6db556fd20188d892cfcd42e3163ab8fb56bbea1eee837`
- `svg` `ec0f4b96f3fa9b646183e1f7004a0e5d8ce0f9ab28f111472d4ed32ffa0c6b58`
+ `svg` `41a557862e0f3a1eb1b40ecb2224089014fff7c26ee8d7c6d64bdd1b3bf670c0`
- `pdf` `508b3a641fde21b582ee2a58a3d3df2a769998281f78c8763ba07438286c1f8f`
+ `pdf` `fc4974d6e462b22ca3a45aaae009001bdf46c8d0245862227255ca3e42d69c75`
- `ledger` `c040fca2dd63df9c68b56a767ccd0383962db479b04d75d23821b311628ce099`
+ `ledger` `3b4bc8c1c9b0c5d474a1acabe6c2b7684058234414d96870e41b015e04b4a5ff`
- `png` `7ff5c05cc0caa0890400fec50a9366397a203b891031fa400d9638872d0b4501`
+ `png` `00cd857a5769be853142a4e35cc701d283cb17e66c2e20f40e562177813f6248`
- `svg` `ffac9c1eba5386fe79d3c1f5a69afdfadafaba507adaf47963a1b2ddd669d472`
+ `svg` `45104b967009ef52c54f2ca4f4877f30c204daf64544161d907dc5dc41e59f5f`
- `pdf` `d207343460263fde7481c8be1572e797895db488f7828b35d14a09003436d4a1`
+ `pdf` `49c473a8ff2dac0cc15fed7b17bece2a10ecaae6d4ab157e801754cf6b40dfa2`
- `ledger` `6dfbd6eae0285a55475cd8cfe365e92bb9a6137d5e4da23f469634c58d1f1c28`
+ `ledger` `2225062a0146f62ac1c0a18add36f38d26df73682f56f4fd5cdac6a0a691c8e9`
- | Ring utilisation plate | `pair-extract-2026-10-08-winner-ops` | NR-021 | `eacf073` | `post-95c385d_wind-authority` |
+ | Ring utilisation plate | `pair-extract-2026-10-08-winner-ops` | NR-021 | `671ab96` | `post-95c385d_wind-authority` |
- | Twist limit plate | `pair-extract-2026-10-08-winner-ops` | NR-022, NR-023 | `eacf073` | `post-95c385d_wind-authority` |
+ | Twist limit plate | `pair-extract-2026-10-08-winner-ops` | NR-022, NR-023 | `671ab96` | `post-95c385d_wind-authority` |
```

## 4. One query: the levers rows

The appendix says one row per built exhibit. It carries four rows. The review copy embeds six plates. Rows 20 and 21 have no appendix row, and no receipt records a deferral. Either the rows join at the re-pin, or the room records the deferral. The sentence "All four read dataset commit `dd3cc6a`" takes its count at the same pass.

## 5. State and handoffs

- Rows 6 and 7. F-VALUE, F-REPRO and F-LABEL pass on the delivered bytes. @fig-img-diagrams may fold the closure into the map cells. The appendix defect stands beside it and takes its own small pass.

- The floor row still pends with the ledger pass (@science-validator). No value moves from this read.

- The R5 display-form question stays with the room, as recorded by the figures seat.

- @user: nothing needed. The defect touches the appendix only. No drawn value and no kit byte moves.

aero-validator, 2026-10-14.

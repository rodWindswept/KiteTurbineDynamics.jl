#!/usr/bin/env python3
"""fig-sa v5 edit pass: the cone ring (R5) label joins the F1 anatomy plate.

Round-5 founder comment 3 (id 2): "Cone ring is shown as a component part
later in this report but not on this diagram." The pass adds the named
part and its leader, plus in-script clearance asserts. No new number.

Usage: python3 fig_sa_v5_edit.py <root>   (root holds system-anatomy/)
Default root: docs/reporting/figures
"""
import sys
from pathlib import Path

root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("docs/reporting/figures")
PY = root / "system-anatomy" / "system-anatomy.py"

edits = [
    # 1. header comment: the v5 note
    ("#   NR-043  winner blade span 1.499 m at three decimals (v4 re-cut)\n",
     "#   NR-043  winner blade span 1.499 m at three decimals (v4 re-cut)\n"
     "# v5 re-cut (2026-10-14): the cone ring (R5) label joins (round-5\n"
     "# founder comment 3). The leader carries clearance self-checks. No\n"
     "# new number.\n"),
    # 2. the label entry (after the segments entry)
    ("    dict(name=\"segments\", pos=(4.50, 1.55), anchor=\"west\",\n"
     "         lines=[\"segments S1 to S5\", \"three tension lines each\"],\n"
     "         leaders=[((4.55, 1.95), (3.22, 2.53))]),\n",
     "    dict(name=\"segments\", pos=(4.50, 1.55), anchor=\"west\",\n"
     "         lines=[\"segments S1 to S5\", \"three tension lines each\"],\n"
     "         leaders=[((4.55, 1.95), (3.22, 2.53))]),\n"
     "    dict(name=\"conering\", pos=(10.30, 3.15), anchor=\"west\",\n"
     "         lines=[\"R5, the cone ring\", \"the shaft cone starts here\"],\n"
     "         leaders=[((10.25, 3.30), (8.72, 4.80))]),\n"),
    # 3. v5 clearance asserts + updated self-check line
    ("assert not _seg_hits(DIM_I, DIM_T, _B0, _B1)                  # dimension clears the blade\n"
     "print(\"self-checks ok: 6 rings, 15 ropes, 3 blades, span 1.499 m on NR-043, dimension clearances hold, radii and bank on NR-011/NR-017\")",
     "assert not _seg_hits(DIM_I, DIM_T, _B0, _B1)                  # dimension clears the blade\n"
     "\n"
     "# v5: the cone-ring leader clears the drawn ink\n"
     "CONE_LDR = ((10.25, 3.30), (8.72, 4.80))\n"
     "_ink_v5 = list(ROPE_SEGS)\n"
     "_ink_v5 += [(P(RINGS[i][0], -RINGS[i][1]), P(RINGS[i][0], RINGS[i][1])) for i in range(6)]\n"
     "_ink_v5 += [(DIM_I0, DIM_I2), (DIM_T0, DIM_T2), (DIM_I, DIM_T), (SPAN_LDR_A, SPAN_LDR_B),\n"
     "            ((15.35, 4.30), (17.30, 7.52)), ((4.55, 1.95), (3.22, 2.53)),\n"
     "            ((-1.35, 2.90), (-0.48, 1.68)), ((-0.95, -0.32), (0.10, 0.10))]\n"
     "_ink_v5 += [(SKY, BACK_ANCHOR), ((GROUND_X[0], GROUND_Z), (GROUND_X[1], GROUND_Z)),\n"
     "            ((STATION[0], STATION[1]), (STATION[2], STATION[1])),\n"
     "            ((STATION[2], STATION[1]), (STATION[2], STATION[3])),\n"
     "            ((STATION[2], STATION[3]), (STATION[0], STATION[3])),\n"
     "            ((STATION[0], STATION[3]), (STATION[0], STATION[1]))]\n"
     "_ink_v5 += [(BEARING, SKY)] + BRIDLES\n"
     "_ink_v5 += [(SKY, (KITE_CENTRES[-1][0] + 1.2 * LIFTDIR[0], KITE_CENTRES[-1][1] + 1.2 * LIFTDIR[1]))]\n"
     "_ink_v5 += [((wx, wz), (wx + 2.7, wz)) for (wx, wz) in WINDS]\n"
     "for _seg in _ink_v5:\n"
     "    assert not _seg_hits(CONE_LDR[0], CONE_LDR[1], _seg[0], _seg[1]), f\"cone-ring leader crosses {_seg}\"\n"
     "print(\"self-checks ok: 6 rings, 15 ropes, 3 blades, span 1.499 m on NR-043, dimension clearances hold, cone-ring leader clear, radii and bank on NR-011/NR-017\")"),
]

ok = True
text = PY.read_text(encoding="utf-8")
for old, new in edits:
    n = text.count(old)
    if n != 1 and text.count(new) != 1:  # not already applied
        print(f"FAIL: target occurs {n} times: {old[:80]!r}")
        ok = False
        continue
    if n == 1:
        text = text.replace(old, new)
if ok:
    PY.write_text(text, encoding="utf-8")
    print(f"edited: {PY}")

print("RESULT:", "PASS" if ok else "FAIL")
sys.exit(0 if ok else 1)

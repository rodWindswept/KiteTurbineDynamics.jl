#!/usr/bin/env python3
"""fig-sa v4 edit pass 2: move the blade-span dimension to the down-left side.

Replaces the up-right variant (leader crossed the blade) with the checked
down-left assembly, and adds in-script clearance self-checks.
"""
import sys

PY = "docs/reporting/figures/system-anatomy/system-anatomy.py"

edits = [
    # (a) dim geometry block -> down-left variant with extension gaps
    ("# ---- blade-span dimension (NR-043): parallel to the drawn blade ----\n"
     "SPAN_LABEL = f\"{ROTOR['r_out'] - ROTOR['r_in']:.3f} m\"   # 1.499 m, the drawn form\n"
     "_B0, _B1 = BLADE_PTS[0]                                  # inner edge -> tip\n"
     "_bl = math.hypot(_B1[0] - _B0[0], _B1[1] - _B0[1])\n"
     "_bu = ((_B1[0] - _B0[0]) / _bl, (_B1[1] - _B0[1]) / _bl)\n"
     "_bn = (_bu[1], -_bu[0])                                  # offset normal, up-right\n"
     "DIM_OFF, DIM_EXT = 1.05, 0.15                            # offset, end overshoot\n"
     "DIM_I = (_B0[0] + DIM_OFF * _bn[0], _B0[1] + DIM_OFF * _bn[1])\n"
     "DIM_T = (_B1[0] + DIM_OFF * _bn[0], _B1[1] + DIM_OFF * _bn[1])\n"
     "DIM_I2 = (_B0[0] + (DIM_OFF + DIM_EXT) * _bn[0], _B0[1] + (DIM_OFF + DIM_EXT) * _bn[1])\n"
     "DIM_T2 = (_B1[0] + (DIM_OFF + DIM_EXT) * _bn[0], _B1[1] + (DIM_OFF + DIM_EXT) * _bn[1])",
     "# ---- blade-span dimension (NR-043): parallel to the drawn blade, down-left ----\n"
     "SPAN_LABEL = f\"{ROTOR['r_out'] - ROTOR['r_in']:.3f} m\"   # 1.499 m, the drawn form\n"
     "_B0, _B1 = BLADE_PTS[0]                                  # inner edge -> tip\n"
     "_bl = math.hypot(_B1[0] - _B0[0], _B1[1] - _B0[1])\n"
     "_bu = ((_B1[0] - _B0[0]) / _bl, (_B1[1] - _B0[1]) / _bl)\n"
     "_bn = (-_bu[1], _bu[0])                                  # offset normal, down-left\n"
     "DIM_OFF, DIM_GAP = 1.05, 0.15                            # line offset, extension gap\n"
     "DIM_I = (_B0[0] + DIM_OFF * _bn[0], _B0[1] + DIM_OFF * _bn[1])\n"
     "DIM_T = (_B1[0] + DIM_OFF * _bn[0], _B1[1] + DIM_OFF * _bn[1])\n"
     "DIM_I0 = (_B0[0] + DIM_GAP * _bn[0], _B0[1] + DIM_GAP * _bn[1])\n"
     "DIM_T0 = (_B1[0] + DIM_GAP * _bn[0], _B1[1] + DIM_GAP * _bn[1])\n"
     "DIM_I2 = (_B0[0] + (DIM_OFF + DIM_GAP) * _bn[0], _B0[1] + (DIM_OFF + DIM_GAP) * _bn[1])\n"
     "DIM_T2 = (_B1[0] + (DIM_OFF + DIM_GAP) * _bn[0], _B1[1] + (DIM_OFF + DIM_GAP) * _bn[1])\n"
     "SPAN_LDR_A, SPAN_LDR_B = (11.05, 15.07), (13.176, 13.596)  # label leader"),
    # (b) the label entry
    ("    dict(name=\"bladespan\", pos=(10.65, 14.62), anchor=\"east\",\n"
     "         lines=[\"blade span\", SPAN_LABEL],\n"
     "         leaders=[((10.80, 14.55), (14.94, 14.84))]),",
     "    dict(name=\"bladespan\", pos=(10.90, 15.20), anchor=\"east\",\n"
     "         lines=[\"blade span\", SPAN_LABEL],\n"
     "         leaders=[(SPAN_LDR_A, SPAN_LDR_B)]),"),
    # (c) tex emission: extensions start at the gap
    ("dr(\"ktd leader\", [_B0, DIM_I2])\n"
     "dr(\"ktd leader\", [_B1, DIM_T2])",
     "dr(\"ktd leader\", [DIM_I0, DIM_I2])\n"
     "dr(\"ktd leader\", [DIM_T0, DIM_T2])"),
    # (d) svg mirror
    ("for (a, b) in [(_B0, DIM_I2), (_B1, DIM_T2)]:",
     "for (a, b) in [(DIM_I0, DIM_I2), (DIM_T0, DIM_T2)]:"),
    # (e) self-checks: the span binds NR-043; the dimension clearances hold
    ("assert abs(ROTOR[\"bank\"] - 7.088) < 1e-3\n"
     "assert SPAN_LABEL == \"1.499 m\"\n"
     "assert abs((ROTOR[\"r_out\"] - ROTOR[\"r_in\"]) - 1.4994019682084492) < 1e-5\n"
     "print(\"self-checks ok: 6 rings, 15 ropes, 3 blades, span 1.499 m on NR-043, radii and bank on NR-011/NR-017\")",
     "assert abs(ROTOR[\"bank\"] - 7.088) < 1e-3\n"
     "assert SPAN_LABEL == \"1.499 m\"\n"
     "assert abs((ROTOR[\"r_out\"] - ROTOR[\"r_in\"]) - 1.4994019682084492) < 1e-5\n"
     "\n"
     "def _seg_hits(a, b, c, d):\n"
     "    \"\"\"Open-segment intersection test (a-b vs c-d).\"\"\"\n"
     "    def cr(o, p, q):\n"
     "        return (p[0] - o[0]) * (q[1] - o[1]) - (p[1] - o[1]) * (q[0] - o[0])\n"
     "    return cr(c, d, a) * cr(c, d, b) < 0 and cr(a, b, c) * cr(a, b, d) < 0\n"
     "\n"
     "assert not _seg_hits(SPAN_LDR_A, SPAN_LDR_B, _B0, _B1)        # leader clears the blade\n"
     "assert not _seg_hits(SPAN_LDR_A, SPAN_LDR_B, DIM_T0, DIM_T2)  # leader clears the extensions\n"
     "assert not _seg_hits(SPAN_LDR_A, SPAN_LDR_B, DIM_I0, DIM_I2)\n"
     "assert not _seg_hits(DIM_I, DIM_T, _B0, _B1)                  # dimension clears the blade\n"
     "print(\"self-checks ok: 6 rings, 15 ropes, 3 blades, span 1.499 m on NR-043, dimension clearances hold, radii and bank on NR-011/NR-017\")"),
]

ok = True
text = open(PY, encoding="utf-8").read()
for old, new in edits:
    n = text.count(old)
    if n != 1:
        print(f"FAIL: target occurs {n} times: {old[:80]!r}")
        ok = False
        continue
    text = text.replace(old, new)
if ok:
    with open(PY, "w", encoding="utf-8") as fh:
        fh.write(text)
    print(f"edited: {PY}")

print("RESULT:", "PASS" if ok else "FAIL")
sys.exit(0 if ok else 1)

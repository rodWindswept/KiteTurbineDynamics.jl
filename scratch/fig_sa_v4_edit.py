#!/usr/bin/env python3
"""fig-sa v4 edit pass: system-anatomy.py + ktd-fig-elements.tex.

Applies the v4 re-cut edits with single-occurrence assertions:
  - the blade-span dimension (NR-043), drawn parallel to the blade
  - the drawn source line gains NR-043
  - the ktd dim arrow element style
"""
import sys

PY = "docs/reporting/figures/system-anatomy/system-anatomy.py"
EL = "docs/reporting/figures/elements/ktd-fig-elements.tex"

edits_py = [
    # 1. header comment: NR-043 binding line
    ("#   NR-017  main-rotor bank 7.088 deg at ring 6",
     "#   NR-017  main-rotor bank 7.088 deg at ring 6\n"
     "#   NR-043  winner blade span 1.499 m at three decimals (v4 re-cut)"),
    # 2. dim geometry block after BLADE_PTS
    ("BLADE_PTS = [(P(si, ri), P(so, ro)) for (ri, si, ro, so) in BLADES]\n\nROPE_SEGS = []",
     "BLADE_PTS = [(P(si, ri), P(so, ro)) for (ri, si, ro, so) in BLADES]\n\n"
     "# ---- blade-span dimension (NR-043): parallel to the drawn blade ----\n"
     "SPAN_LABEL = f\"{ROTOR['r_out'] - ROTOR['r_in']:.3f} m\"   # 1.499 m, the drawn form\n"
     "_B0, _B1 = BLADE_PTS[0]                                  # inner edge -> tip\n"
     "_bl = math.hypot(_B1[0] - _B0[0], _B1[1] - _B0[1])\n"
     "_bu = ((_B1[0] - _B0[0]) / _bl, (_B1[1] - _B0[1]) / _bl)\n"
     "_bn = (_bu[1], -_bu[0])                                  # offset normal, up-right\n"
     "DIM_OFF, DIM_EXT = 1.05, 0.15                            # offset, end overshoot\n"
     "DIM_I = (_B0[0] + DIM_OFF * _bn[0], _B0[1] + DIM_OFF * _bn[1])\n"
     "DIM_T = (_B1[0] + DIM_OFF * _bn[0], _B1[1] + DIM_OFF * _bn[1])\n"
     "DIM_I2 = (_B0[0] + (DIM_OFF + DIM_EXT) * _bn[0], _B0[1] + (DIM_OFF + DIM_EXT) * _bn[1])\n"
     "DIM_T2 = (_B1[0] + (DIM_OFF + DIM_EXT) * _bn[0], _B1[1] + (DIM_OFF + DIM_EXT) * _bn[1])\n\n"
     "ROPE_SEGS = []"),
    # 3. the blade-span label joins LABELS (after the main-rotor entry)
    ("    dict(name=\"mainrotor\", pos=(15.40, 4.05), anchor=\"west\",\n"
     "         lines=[\"main rotor (R6)\", \"three blades, bank 7.088°\"],\n"
     "         leaders=[((15.35, 4.30), (17.30, 7.52))]),",
     "    dict(name=\"mainrotor\", pos=(15.40, 4.05), anchor=\"west\",\n"
     "         lines=[\"main rotor (R6)\", \"three blades, bank 7.088°\"],\n"
     "         leaders=[((15.35, 4.30), (17.30, 7.52))]),\n"
     "    dict(name=\"bladespan\", pos=(10.65, 14.62), anchor=\"east\",\n"
     "         lines=[\"blade span\", SPAN_LABEL],\n"
     "         leaders=[((10.80, 14.55), (14.94, 14.84))]),"),
    # 4. the drawn source line gains NR-043
    ("\"· rows NR-011 · NR-017\")",
     "\"· rows NR-011 · NR-017 · NR-043\")"),
    # 5. tex header comment rows
    ("winner, data commit dd3cc6a). Rows NR-011, NR-017.\")",
     "winner, data commit dd3cc6a). Rows NR-011, NR-017, NR-043.\")"),
    # 6. self-checks: the span binds NR-043
    ("assert abs(ROTOR[\"bank\"] - 7.088) < 1e-3\n"
     "print(\"self-checks ok: 6 rings, 15 ropes, 3 blades, radii and bank on NR-011/NR-017\")",
     "assert abs(ROTOR[\"bank\"] - 7.088) < 1e-3\n"
     "assert SPAN_LABEL == \"1.499 m\"\n"
     "assert abs((ROTOR[\"r_out\"] - ROTOR[\"r_in\"]) - 1.4994019682084492) < 1e-5\n"
     "print(\"self-checks ok: 6 rings, 15 ropes, 3 blades, span 1.499 m on NR-043, radii and bank on NR-011/NR-017\")"),
    # 7. tex emission: 7b dimension assembly
    ("# 7) main-rotor blades (all three; the two -rho blades overlap in projection)\n"
     "for (a, b) in BLADE_PTS:\n"
     "    dr(\"ktd blade\", [a, b])\n",
     "# 7) main-rotor blades (all three; the two -rho blades overlap in projection)\n"
     "for (a, b) in BLADE_PTS:\n"
     "    dr(\"ktd blade\", [a, b])\n\n"
     "# 7b) blade-span dimension (NR-043): extension lines + arrowed dimension line\n"
     "dr(\"ktd leader\", [_B0, DIM_I2])\n"
     "dr(\"ktd leader\", [_B1, DIM_T2])\n"
     "L.append(f\"  \\\\draw[ktd dim arrow] {tex_pt(DIM_I)} -- {tex_pt(DIM_T)};\")\n"),
    # 8. svg emission mirror
    ("for (a, b) in BLADE_PTS:\n"
     "    S.append(sline(st(2.8, C_blade, None, \"round\"), [a, b]))\n",
     "for (a, b) in BLADE_PTS:\n"
     "    S.append(sline(st(2.8, C_blade, None, \"round\"), [a, b]))\n"
     "# blade-span dimension (NR-043): extensions + arrowed dimension line\n"
     "for (a, b) in [(_B0, DIM_I2), (_B1, DIM_T2)]:\n"
     "    S.append(sline(st(0.6, C_faint), [a, b]))\n"
     "_d1, _d2 = sv(DIM_I), sv(DIM_T)\n"
     "S.append(f'<path d=\"M{_d1[0]:.1f},{_d1[1]:.1f} L{_d2[0]:.1f},{_d2[1]:.1f}\" fill=\"none\" '\n"
     "         f'stroke=\"#666666\" stroke-width=\"1.0\" marker-start=\"url(#arr)\" marker-end=\"url(#arr)\"/>')\n"),
]

edits_el = [
    ("% ktd-fig-elements.tex — KTD report figure element library (v1, 2026-10-12)",
     "% ktd-fig-elements.tex — KTD report figure element library (v1.1, 2026-10-13)"),
    ("% Rule standing: the 22.0 slot value never prints as a rotor angle.",
     "% Rule standing: the 22.0 slot value never prints as a rotor angle.\n"
     "% v1.1: the ktd dim arrow style joins — the F1 v4 blade-span dimension (NR-043)."),
    ("  ktd dim/.style={draw=black!55, line width=0.5pt},",
     "  ktd dim/.style={draw=black!55, line width=0.5pt},\n"
     "  ktd dim arrow/.style={draw=black!55, line width=0.5pt,\n"
     "    {Stealth[length=1.6mm,width=1.2mm]}-{Stealth[length=1.6mm,width=1.2mm]}},"),
]

ok = True
for path, edits in ((PY, edits_py), (EL, edits_el)):
    text = open(path, encoding="utf-8").read()
    for old, new in edits:
        n = text.count(old)
        if n != 1:
            print(f"FAIL: {path}: target occurs {n} times: {old[:70]!r}")
            ok = False
            continue
        text = text.replace(old, new)
    if ok:
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(text)
        print(f"edited: {path}")

print("RESULT:", "PASS" if ok else "FAIL")
sys.exit(0 if ok else 1)

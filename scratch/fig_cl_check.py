#!/usr/bin/python3
# -*- coding: utf-8 -*-
"""Caption leads + closure records: text-only check (figures seat).

Asserts the landed strings and the retired strings in one pass.

Run: /usr/bin/python3 scratch/fig_cl_check.py
Writes: scratch/fig_cl_check.log
"""
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
FIG = REPO / "docs/reporting/figures"
fails, lines = [], []


def check(name, ok):
    lines.append(f"check: {name}: {'OK' if ok else 'FAIL'}")
    if not ok:
        fails.append(name)


def t(rel):
    return (FIG / rel).read_text()


m = t("figure-map.md")
check("map cells closure x2", m.count("closes F-VALUE on the fix commit (`d6d4db9`) with zero defects") == 2)
check("map no fresh-read cell", "A fresh read rides the new pins" not in m)
check("map delta v27", "**v27 (2026-10-14):**" in m)
check("map delta v28", "**v28 (2026-10-14):**" in m)
check("map v28 queue note", "deltas stay queued at the figures seat" in m)

ls = t("pca-landscape/SPEC.md")
check("landscape rounds closure", "closes F-VALUE on\n  the fix commit (`d6d4db9`)" in ls and "held the drawn values" in ls)
check("landscape no fresh read", "A fresh read rides the re-cut pins" not in ls)
check("landscape R3 trimmed", "@aero-validator runs F-VALUE" not in ls)

at = t("pca-atlas/SPEC.md")
check("atlas rounds closure", "closes F-VALUE on the fix commit (`d6d4db9`)" in at and "held the drawn values" in at)
check("atlas no fresh read", "A fresh read" not in at)

r = t("ring-utilisation/captions.md")
check("ring plain lead", "The hub ring R6 governs the structural check at the winner's final" in r)
check("ring tech lead", "at FoS 15.033. All\nother airborne rings hold much larger margins (NR-021)." in r)
check("ring gate line", "at\nFoS 2.5 or above (NR-015)." in r)
check("ring old plain gone", "This figure shows how much" not in r)
check("ring cites line", "Values cite\nNR-021 and NR-015." in r)
check("ring lead note", "Caption lead (2026-10-14)" in r)

w = t("twist-limit/captions.md")
check("twist plain lead", "All five segments stay inside their over-twist limits at the winner's" in w)
check("twist tech lead", "S1 carries the least segment torque\nmargin, 2.03 (NR-040)." in w)
check("twist old plain gone", "This figure shows how far each segment" not in w)
check("twist cites line", "Values cite\nNR-022, NR-023 and NR-040." in w)
check("twist lead note", "Caption lead (2026-10-14)" in w)

s = t("machine-evolution-strip/captions.md")
check("strip plain lead", "Island 3's best-so-far objective falls as the built geometry converges" in s)
check("strip tech lead", "falls from 36.109 to 27.364\nkg-equivalent." in s)
check("strip old first line gone", "This figure shows seven kite-turbine designs" not in s)
check("strip lead note", "Caption lead (2026-10-14)" in s)

rrs = t("ring-utilisation/register-status.md")
check("ring rs NR-015 row", "| NR-015 | The operating point config: FoS gate 2.5/2.5" in rrs)
check("ring rs caption line", "The caption cites NR-015 for the" in rrs)
check("ring rs delta", "**Delta** v1 (2026-10-14)" in rrs)

wrs = t("twist-limit/register-status.md")
check("twist rs NR-040 row", "| NR-040 | The winner segment torque margins: S1 2.0288" in wrs)
check("twist rs delta", "**Delta** v1 (2026-10-14)" in wrs)

rsp = t("ring-utilisation/SPEC.md")
check("ring SPEC plan", "The hub ring R6 governs, and every" in rsp)
check("ring SPEC tech note", "Lead with the hub result (NR-021). State the gate line" in rsp)
check("ring SPEC delta v4", "- v4 (2026-10-14):" in rsp)

wsp = t("twist-limit/SPEC.md")
check("twist SPEC plan", "All five segments stay inside their" in wsp)
check("twist SPEC tech note", "Lead with the least torque margin (NR-040)." in wsp)
check("twist SPEC delta v3", "- v3 (2026-10-14):" in wsp)

lines.append("== summary: " + (f"{len(fails)} FAIL: {fails}" if fails else "all OK"))
log = "\n".join(lines) + "\n"
(REPO / "scratch/fig_cl_check.log").write_text(log)
print(log)
raise SystemExit(1 if fails else 0)

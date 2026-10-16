#!/usr/bin/env python3
"""fig_sl_check: the check set for the scaling-ladder stage.

Covers: the kit file set, the manifest pins (inputs and outputs), an
independent F-LABEL re-walk, the checks log, the repro md5 table, the
map records (row 24, delta v50, counts), the seat page, the receipt,
and the STE gate across the touched markdown. Re-runs the standing set
as the last check. Exit 0 on all-pass.
"""
import hashlib
import html
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
KIT = ROOT / "docs" / "reporting" / "figures" / "scaling-ladder"
MAP = ROOT / "docs" / "reporting" / "figures" / "figure-map.md"
SEAT = (ROOT / "handovers"
        / "handover-2026-10-14-reporting-room-figures-images-diagrams.md")
FB = (ROOT / "docs" / "reporting" / "room-responses"
      / "figures-images-diagrams-2026-10-16-scaling-ladder-build.md")
RUN1 = ROOT / "scratch" / "fig_sl_run1.log"
REPRO = ROOT / "scratch" / "fig_sl_repro.md5"
A = "4ebc385"

PASS = []
FAIL = []


def check(name, got, want):
    ok = got == want
    (PASS if ok else FAIL).append(name)
    print(f"check: {name}: {got!r}  "
          f"({'OK' if ok else 'FAIL vs ' + repr(want)})")


def norm(t: str) -> str:
    return " ".join(t.split())


def sha256(p: Path) -> str:
    return hashlib.sha256(p.read_bytes()).hexdigest()


# 1. the kit file set
need = ["scaling-ladder.py", "SPEC.md", "captions-draft.md",
        "register-status.md", "checks.log", "scaling-ladder.svg",
        "scaling-ladder.pdf", "scaling-ladder.png", "label-ledger.txt",
        "manifest.json"]
missing = [f for f in need if not (KIT / f).exists()]
check("kit file set (10 files)", missing, [])

# 2. the manifest
man = json.loads((KIT / "manifest.json").read_text())
check("manifest script_commit", man["script_commit"], A)
check("manifest register_rows", man["inputs"]["register_rows"], [])
check("manifest data_commit", man["data_commit"], "aa76367")
check("manifest binding", man["binding"],
      "every drawn element resolves to the value-claims ledger "
      "section 4; no register row binds this plate")
check("manifest script sha pins the file",
      man["script"]["sha256"], sha256(KIT / "scaling-ladder.py"))

# 3. output pins recompute
bad = [k for k in man["outputs"]
       if man["outputs"][k] != sha256(KIT / k)]
check("manifest output pins recompute", bad, [])

# 4. input pins recompute
bad = [p["path"] for p in (man["inputs"]["ledger"],
                           man["inputs"]["rung_set"])
       if sha256(ROOT / p["path"]) != p["sha256"]]
check("manifest input pins recompute", bad, [])

# 5. F-LABEL independent re-walk
svg = (KIT / "scaling-ladder.svg").read_text()
found = {html.unescape(re.sub(r"<[^>]+>", "", m)).strip()
         for m in re.findall(r"<text[^>]*>(.*?)</text>", svg, flags=re.S)}
found = {s for s in found if s}
ledger = [l for l in (KIT / "label-ledger.txt").read_text().splitlines()
          if l]
check("F-LABEL: vector text == ledger",
      sorted(found - set(ledger)) + sorted(set(ledger) - found), [])
check("ledger string count", len(ledger), 19)

# 6. the checks log
check("checks.log == run1 log",
      (KIT / "checks.log").read_bytes(), RUN1.read_bytes())
logt = (KIT / "checks.log").read_text()
check("checks.log F-LABEL line", "F-LABEL self-check: OK" in logt, True)
check("checks.log check-line count",
      sum(1 for l in logt.splitlines() if l.startswith("check:")), 14)

# 7. the repro md5 table
rows = [l.split("  ") for l in REPRO.read_text().splitlines()]
check("repro table rows", len(rows), 5)
bad = [f for h, f in rows
       if hashlib.md5((KIT / f).read_bytes()).hexdigest() != h]
check("repro md5s recompute from the kit", bad, [])

# 8. the map
mpr = MAP.read_text()
mpn = norm(mpr)
check("map row 24 cell",
      "| 24 | \u27e8tbd\u27e9 | \u00a75 | The scaling ladder. The "
      "validated rung and the programme targets above it | "
      "`scaling-ladder` | R2 |" in mpn, True)
check("map build sentence",
      "The kit lands (script `4ebc385`): seven rungs at equal spacing, "
      "the validated rung solid, the six programme targets open plus "
      "label, no value axis." in mpn, True)
check("map delta v50",
      "**v50 (2026-10-16):** the scaling-ladder row mints and lands "
      "(row 24, the close candidate)." in mpn, True)
check("map counts",
      [mpr.count("| planned |"), mpr.count("| R2 |"),
       mpr.count("| proposed |")], [1, 12, 6])

# 9. the seat page
stn = norm(SEAT.read_text())
check("seat ladder item",
      "3. **The scaling-ladder stage (the close candidate).** The kit "
      "lands at" in stn, True)
check("seat header take",
      "and the scaling-ladder stage (2026-10-16)." in stn, True)
check("seat footer take",
      "The scaling-ladder stage reads its counter-reads next." in stn,
      True)

# 10. the receipt
fbn = norm(FB.read_text())
check("receipt cites",
      all(s in fbn for s in (A, "aa76367", "v50", "3160aed8")), True)
check("receipt counts",
      ("14 checks, 0 fail" in fbn) and ("15 of 15" in fbn), True)
check("receipt rows claim",
      "no register row binds the plate" in fbn, True)

# 11. STE gate on the touched markdown
for f in (FB, MAP, SEAT, KIT / "captions-draft.md",
          KIT / "register-status.md", KIT / "SPEC.md"):
    r = subprocess.run(["python3", "ste-lint.py", "--fail-above", "2.0",
                        str(f)], capture_output=True, text=True, cwd=ROOT)
    check(f"ste rc {f.name}", r.returncode, 0)

# 12. the standing set re-runs
r = subprocess.run(["python3", "scratch/fig_et_pl_check.py"],
                   capture_output=True, text=True, cwd=ROOT)
check("standing set rc", r.returncode, 0)
check("standing set total", "TOTAL: 63 checks, 0 fail" in r.stdout, True)
print(f"  standing: {(r.stdout.strip().splitlines() or [''])[-1]}")

print()
print(f"TOTAL: {len(PASS) + len(FAIL)} checks, {len(FAIL)} fail")
if FAIL:
    print("FAILED:")
    for f in FAIL:
        print("  " + f)
    sys.exit(1)
print("ALL PASS")

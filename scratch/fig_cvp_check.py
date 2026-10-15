#!/usr/bin/env python3
"""fig_cvp_check: the check set for the convergence two-panel build.

Covers: the kit file set, the manifest pins (inputs and outputs), an
independent F-LABEL re-walk, the checks log, the repro md5 table, the
map records (row 16, delta v48, counts), the seat page, the receipt,
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
KIT = ROOT / "docs" / "reporting" / "figures" / "convergence"
MAP = ROOT / "docs" / "reporting" / "figures" / "figure-map.md"
SEAT = (ROOT / "handovers"
        / "handover-2026-10-14-reporting-room-figures-images-diagrams.md")
FB = (ROOT / "docs" / "reporting" / "room-responses"
      / "figures-images-diagrams-2026-10-15-convergence-build.md")
RUN1 = ROOT / "scratch" / "fig_cvp_run1.log"
REPRO = ROOT / "scratch" / "fig_cvp_repro.md5"

PASS = []
FAIL = []


def check(name, got, want):
    ok = got == want
    (PASS if ok else FAIL).append(name)
    print(f"check: {name}: {got!r}  ({'OK' if ok else 'FAIL vs ' + repr(want)})")


def norm(t: str) -> str:
    return " ".join(t.split())


def sha256(p: Path) -> str:
    return hashlib.sha256(p.read_bytes()).hexdigest()


# 1. the kit file set
need = ["convergence.py", "SPEC.md", "captions-draft.md",
        "register-status.md", "checks.log", "convergence.svg",
        "convergence.pdf", "convergence.png", "label-ledger.txt",
        "manifest.json"]
missing = [f for f in need if not (KIT / f).exists()]
check("kit file set (10 files)", missing, [])

# 2. the manifest
man = json.loads((KIT / "manifest.json").read_text())
check("manifest script_commit", man["script_commit"], "0db99ac")
check("manifest register_rows", man["inputs"]["register_rows"],
      ["NR-002", "NR-003", "NR-004", "NR-005", "NR-006", "NR-036",
       "NR-054", "NR-055"])
check("manifest data_commit", man["data_commit"], "dd3cc6a")
check("manifest script sha pins the file",
      man["script"]["sha256"], sha256(KIT / "convergence.py"))

# 3. output pins recompute
bad = [k for k in man["outputs"]
       if man["outputs"][k] != sha256(KIT / k)]
check("manifest output pins recompute", bad, [])

# 4. input pins recompute
bad = [p["path"] for p in man["inputs"]["extracts"]
       if sha256(ROOT / p["path"]) != p["sha256"]]
check("manifest input pins recompute", bad, [])

# 5. F-LABEL independent re-walk
svg = (KIT / "convergence.svg").read_text()
found = {html.unescape(re.sub(r"<[^>]+>", "", m)).strip()
         for m in re.findall(r"<text[^>]*>(.*?)</text>", svg, flags=re.S)}
found = {s for s in found if s}
ledger = [l for l in (KIT / "label-ledger.txt").read_text().splitlines() if l]
check("F-LABEL: vector text == ledger",
      sorted(found - set(ledger)) + sorted(set(ledger) - found), [])
check("ledger string count", len(ledger), 34)

# 6. the checks log
check("checks.log == run1 log",
      (KIT / "checks.log").read_bytes(), RUN1.read_bytes())
logt = (KIT / "checks.log").read_text()
check("checks.log F-LABEL line", "F-LABEL self-check: OK" in logt, True)
check("checks.log check-line count",
      sum(1 for l in logt.splitlines() if l.startswith("check:")), 22)

# 7. the repro md5 table
rows = [l.split("  ") for l in REPRO.read_text().splitlines()]
check("repro table rows", len(rows), 5)
bad = [f for h, f in rows
       if hashlib.md5((KIT / f).read_bytes()).hexdigest() != h]
check("repro md5s recompute from the kit", bad, [])

# 8. the map
mpr = MAP.read_text()
mpn = norm(mpr)
check("map row cell",
      "| 16 | 8 | \u00a73.2 | Convergence and the status mix (two panels) "
      "| `convergence` | R2 |" in mpn, True)
check("map build sentence",
      "The build lands (script `0db99ac`): two panels, \"first "
      "feasibility, then mass\", 22 checks, 0 fail, and F-REPRO "
      "byte-identical across three locations." in mpn, True)
check("map old seated-next gone",
      "Next: the SPEC then the generator at the figures seat." in mpn,
      False)
check("map delta v48",
      "**v48 (2026-10-15):** the convergence two-panel build lands "
      "(row 16)." in mpn, True)
check("map counts",
      [mpr.count("| planned |"), mpr.count("| R2 |"),
       mpr.count("| proposed |")], [1, 11, 6])

# 9. the seat page
stn = norm(SEAT.read_text())
check("seat build item",
      "**The convergence two-panel build (row 16).** The build lands "
      "at map v48" in stn, True)
check("seat old item gone",
      "The build reads next at this seat: the SPEC, then the generator."
      in stn, False)
check("seat footer",
      "The convergence figure joins after its counter-reads." in stn, True)

# 10. the receipt
fbn = norm(FB.read_text())
check("receipt cites",
      all(s in fbn for s in ("0db99ac", "9dd453d", "NR-055", "v48")), True)
check("receipt counts", "22 checks, 0 fail" in fbn, True)
check("receipt repro", "15 of 15 equal" in fbn, True)

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

#!/usr/bin/env python3
"""fig_cv_check: the check set for the convergence two-panel seat.

Covers: the map records (row 16 seated, the status counts, delta v47),
the notes seating note, the seat page fold, the seat receipt, and the
STE gate across the touched markdown. Re-runs the standing set as the
last check. Exit 0 on all-pass.
"""
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MAP = ROOT / "docs" / "reporting" / "figures" / "figure-map.md"
NOTES = ROOT / "docs" / "reporting" / "figures" / "figure-generation-notes.md"
SEAT = ROOT / "handovers" / "handover-2026-10-14-reporting-room-figures-images-diagrams.md"
FB = ROOT / "docs" / "reporting" / "room-responses" / "figures-images-diagrams-2026-10-15-convergence-two-panel-seat.md"

PASS = []
FAIL = []


def check(name, got, want):
    ok = got == want
    (PASS if ok else FAIL).append(name)
    print(f"check: {name}: {got!r}  ({'OK' if ok else 'FAIL vs ' + repr(want)})")


def norm(t: str) -> str:
    return " ".join(t.split())


# ---------------- 1. the map ----------------
mp = MAP.read_text(encoding="utf-8")
mpn = norm(mp)
check("map: v47 head", "**v47 (2026-10-15):** the convergence two-panel seat lands (row 16)." in mpn, True)
check("map: v46 holds", "**v46 (2026-10-15):**" in mpn, True)
check("map: row seat cell", "| 16 | 8 | \u00a73.2 | Convergence and the status mix (two panels) | \u27e8tbd\u27e9 | planned | The aero series extract (`scratch/av_conv_series.csv`, `9dd453d`). NR-054." in mpn, True)
check("map: row seated tail", "Seated (v47) as the recorded merge, \"first feasibility, then mass\"" in mpn, True)
check("map: row old gone", "| 16 | 8 | \u00a73.2 | Convergence, three islands | \u27e8tbd\u27e9 | proposed | The running-best series. `convergence.csv` | An extract and rows for any printed value |" in mpn, False)
check("map: proposed count", mp.count("| proposed |"), 6)
check("map: planned count", mp.count("| planned |"), 2)

# ---------------- 2. the notes ----------------
ntn = norm(NOTES.read_text(encoding="utf-8"))
check("notes: seated", "Seated at map v47 (2026-10-15): row 16 takes the two-panel form." in ntn, True)
check("notes: merge holds", "This saves a slot." in ntn, True)

# ---------------- 3. the seat page ----------------
seatn = norm(SEAT.read_text(encoding="utf-8"))
check("seat: header", "the fidelity band merge and the convergence seat (2026-10-15)." in seatn, True)
check("seat: item 2", "**The convergence two-panel seat (row 16).** The seat lands at map v47: panel 1, the status mix; panel 2, the running-best curves, from the aero extract (`9dd453d`) and NR-054." in seatn, True)
check("seat: build next", "The build reads next at this seat: the SPEC, then the generator." in seatn, True)
check("seat: item 1 holds", "Next: the visual pass by Rod, then the fold." in seatn, True)

# ---------------- 4. the receipt ----------------
check("fb: exists", FB.exists(), True)
fbn = norm(FB.read_text(encoding="utf-8"))
check("fb: cites", ("9dd453d" in fbn) and ("441b9c7" in fbn) and ("v47" in fbn) and ("NR-054" in fbn), True)
check("fb: count sentence", "reads 24 checks, 0 fail" in fbn, True)
check("fb: seat rationale", "the recorded merge" in fbn, True)
check("fb: no plate byte", "No plate byte moves." in fbn, True)

# ---------------- 5. STE gate ----------------
lint_files = [FB, MAP, NOTES, SEAT]
for f in lint_files:
    r = subprocess.run(["python3", "ste-lint.py", "--fail-above", "2.0", str(f)],
                       capture_output=True, text=True, cwd=ROOT)
    line = (r.stdout.strip().splitlines() or [""])[0]
    if f == NOTES:
        mtotal = int(re.search(r"total=\s*(\d+)", line).group(1))
        check("ste: notes no new flag (exempt class)", mtotal, 86)
        print(f"  ste {f.name}: {line}  [exempt class, pre-existing]")
    else:
        check(f"ste: {f.name} rc", r.returncode, 0)
        print(f"  ste {f.name}: {(r.stdout.strip().splitlines() or [''])[-1]}")

# ---------------- 6. the standing set re-runs ----------------
r = subprocess.run(["python3", "scratch/fig_et_pl_check.py"],
                   capture_output=True, text=True, cwd=ROOT)
tail = (r.stdout.strip().splitlines() or [""])[-1]
check("standing set rc", r.returncode, 0)
check("standing set total", "TOTAL: 63 checks, 0 fail" in r.stdout, True)
print(f"  standing: {tail}")

print()
print(f"TOTAL: {len(PASS) + len(FAIL)} checks, {len(FAIL)} fail")
if FAIL:
    print("FAILED:")
    for f in FAIL:
        print("  " + f)
    sys.exit(1)
print("ALL PASS")

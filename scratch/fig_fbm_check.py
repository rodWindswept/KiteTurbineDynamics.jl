#!/usr/bin/env python3
"""fig_fbm_check: the check set for the fidelity band merge call.

Covers: the map records (row 12 merged, the key, the spine, the unblock
line, delta v46), the notes annotation, the register note delta v8, the
seat page fold, the merge receipt, and the STE gate across the touched
markdown. Re-runs the standing set as the last check. Exit 0 on all-pass.
"""
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MAP = ROOT / "docs" / "reporting" / "figures" / "figure-map.md"
NOTES = ROOT / "docs" / "reporting" / "figures" / "figure-generation-notes.md"
REG = ROOT / "docs" / "reporting" / "figures" / "eval-timeline" / "register-status.md"
SEAT = ROOT / "handovers" / "handover-2026-10-14-reporting-room-figures-images-diagrams.md"
FB = ROOT / "docs" / "reporting" / "room-responses" / "figures-images-diagrams-2026-10-15-fidelity-band-merge.md"

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
check("map: v46 head", "**v46 (2026-10-15):** the fidelity band chart folds into row 4 at the figures seat (row 12 closes merged)." in mpn, True)
check("map: v45 holds", "**v45 (2026-10-15):**" in mpn, True)
check("map: row merged cell", "| 12 | 16 | §4.1 | Fidelity band chart | \u27e8tbd\u27e9 | merged | The fidelity probes. NR-012, NR-013 | Merged into row 4, lane 3 (v46)." in mpn, True)
check("map: scoped state gone", mp.count("| scoped |"), 0)
check("map: spine new", "The protected spine (author seat): rows 2, 6, 7, 8, 9 and 10. Row 12 left the spine at the merge into row 4 (v46)." in mpn, True)
check("map: spine old count", mpn.count("rows 2, 6, 7, 8, 9, 10 and 12"), 1)
check("map: v7 spine history holds", "The spine the author seat protects: rows 2, 6, 7, 8, 9, 10 and 12." in mpn, True)
check("map: key merged", "- **merged** \u2014 the content folds into another row. The slot frees." in mpn, True)
check("map: unblock fold", "The fidelity band joins too (row 12 merged into row 4, v46)." in mpn, True)

# ---------------- 2. the notes ----------------
ntn = norm(NOTES.read_text(encoding="utf-8"))
check("notes: taken", "Taken at the figures seat (2026-10-15, map v46): row 12 closes merged. No standalone plate builds." in ntn, True)
check("notes: option holds", "F3 can carry row 12 and free a slot." in ntn, True)

# ---------------- 3. the register note ----------------
regn = norm(REG.read_text(encoding="utf-8"))
check("reg: v8", "**Delta** v8 (2026-10-15): row 12, the fidelity band chart, folds into this plate (map v46, figures seat)." in regn, True)
check("reg: v7 holds", "**Delta** v7 (2026-10-15):" in regn, True)
check("reg: form note holds", "**Form note** (2026-10-15): swept at the v6 re-cut." in regn, True)

# ---------------- 4. the seat page ----------------
seatn = norm(SEAT.read_text(encoding="utf-8"))
check("seat: closed entry", "The fidelity band merge call (2026-10-15): row 12 (the fidelity band chart) folds into row 4 at map v46." in seatn, True)
check("seat: receipt named", "figures-images-diagrams-2026-10-15-fidelity-band-merge.md" in seatn, True)
check("seat: header fold", "the cite fixes, the placement label re-cut and the fidelity band merge (2026-10-15)." in seatn, True)
check("seat: open item holds", "Next: the visual pass by Rod, then the fold." in seatn, True)

# ---------------- 5. the receipt ----------------
check("fb: exists", FB.exists(), True)
fbn = norm(FB.read_text(encoding="utf-8"))
check("fb: cites", ("v46" in fbn) and ("NR-013 ext2" in fbn) and ("Row 12 closes merged into row 4" in fbn), True)
check("fb: count sentence", "reads 30 checks, 0 fail" in fbn, True)
check("fb: merge rationale", "the recorded merge" in fbn, True)
check("fb: no plate byte", "No plate byte moves." in fbn, True)

# ---------------- 6. STE gate ----------------
lint_files = [FB, MAP, NOTES, REG, SEAT]
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

# ---------------- 7. the standing set re-runs ----------------
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

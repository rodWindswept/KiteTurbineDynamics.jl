#!/usr/bin/env python3
"""fig_et_pl_fb_check: the check set for the counter-read fold-back.

Covers: the re-cut receipt count fix, the ledger census recompute
against the pre-re-cut bytes, the closure records on the map, the
register note and the seat page, the fold-back receipt, and the STE
gate across the touched markdown. Re-runs the standing set as the last
check. Exit 0 on all-pass.
"""
import hashlib
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
KIT = ROOT / "docs" / "reporting" / "figures" / "eval-timeline"
RC = ROOT / "docs" / "reporting" / "room-responses" / "figures-images-diagrams-2026-10-15-eval-timeline-placement-label-recut.md"
FB = ROOT / "docs" / "reporting" / "room-responses" / "figures-images-diagrams-2026-10-15-eval-timeline-recut-closure-foldback.md"
MAP = ROOT / "docs" / "reporting" / "figures" / "figure-map.md"
REG = KIT / "register-status.md"
SEAT = ROOT / "handovers" / "handover-2026-10-14-reporting-room-figures-images-diagrams.md"

PASS = []
FAIL = []


def check(name, got, want):
    ok = got == want
    (PASS if ok else FAIL).append(name)
    print(f"check: {name}: {got!r}  ({'OK' if ok else 'FAIL vs ' + repr(want)})")


def norm(t: str) -> str:
    return " ".join(t.split())


# ---------------- 1. the re-cut receipt takes the count ----------------
rcn = norm(RC.read_text(encoding="utf-8"))
check("rc: two-string head", "Two drawn strings move: the lane-3 label and the footer stamp refresh." in rcn, True)
check("rc: one-string gone", "One drawn string moves" not in rcn, True)
check("rc: stamp bullet", "The footer stamp refreshes from `1af63fc` to `a269636`." in rcn, True)
check("rc: two forms refreshed", "with two forms refreshed (the label and the stamp)" in rcn, True)
check("rc: handoff count", "The drawn moves are the label flip and the stamp refresh." in rcn, True)
check("rc: aero handoff gone", "the only drawn move" not in rcn, True)

# ---------------- 2. the ledger census, recomputed ----------------
old = subprocess.run(["git", "show", "e6206de:docs/reporting/figures/eval-timeline/label-ledger.txt"],
                     capture_output=True, text=True, cwd=ROOT, check=True).stdout
new = (KIT / "label-ledger.txt").read_text(encoding="utf-8")
old_set = set(old.splitlines())
new_set = set(new.splitlines())
removed = sorted(old_set - new_set)
added = sorted(new_set - old_set)
old_label = "rope-break gate off during relax (not yet in the code)"
old_stamp = "rows NR-008 \u00b7 NR-012 \u00b7 NR-013 \u00b7 NR-013 ext \u00b7 NR-016 \u00b7 NR-027 \u00b7 NR-029 \u00b7 NR-039 \u00b7 NR-042 \u00b7 script commit 1af63fc"
new_label = "rope-break gate off during relax"
new_stamp = old_stamp.replace("1af63fc", "a269636")
check("ledger: removed pair", removed, sorted([old_label, old_stamp]))
check("ledger: added pair", added, sorted([new_label, new_stamp]))
check("ledger: count holds", len(new_set), 52)

# ---------------- 3. the closure records ----------------
mpn = norm(MAP.read_text(encoding="utf-8"))
check("map: v45", "**v45 (2026-10-15):** the placement label re-cut counter-read folds back (row 4)." in mpn, True)
check("map: v44 holds", "**v44 (2026-10-15):** the placement label re-cut lands (row 4)." in mpn, True)
check("map: row closure", "The counter-read closes clean (`8e33253`, 35 checks)." in mpn, True)
roster = mpn.split("## 2. The roster", 1)[1]
cut = roster.find(" ## ")
roster = roster[:cut] if cut != -1 else roster
check("map: roster old tail gone", "Next: the aero counter-read of the re-cut" not in roster, True)
check("map: v44 history holds", "Next: the aero counter-read of the re-cut, then the visual pass by Rod." in mpn, True)
check("map: two historical next-lines hold (v35, v44)", mpn.count("the aero counter-read of the re-cut"), 2)
check("map: roster tail", "Next: the visual pass by Rod, then the fold" in roster, True)
check("map: closed-held", "closed-held with the one-line re-open" in mpn, True)

regn = norm(REG.read_text(encoding="utf-8"))
check("reg: v7", "**Delta** v7 (2026-10-15): the re-cut counter-read closes (aero-validator, `1bfb09e`, readback `8e33253`, 35 checks)." in regn, True)
check("reg: v6 holds", "**Delta** v6 (2026-10-15): the placement lands." in regn, True)

seatn = norm(SEAT.read_text(encoding="utf-8"))
check("seat: closed entry closure", "The counter-read closes (`8e33253`, 35 checks)." in seatn, True)
check("seat: open item closure", "the placement re-cut: the counter-read closes (`8e33253`, 35 checks). Next: the visual pass by Rod, then the fold." in seatn, True)
check("seat: foldback receipt named", "figures-images-diagrams-2026-10-15-eval-timeline-recut-closure-foldback.md" in seatn, True)
check("seat: footer stale gone", "the corner grid, the winner plate" not in seatn, True)
check("seat: footer set", "the winner plate, the F1 plate and rows 4 to 7" in seatn, True)

# ---------------- 4. the fold-back receipt ----------------
check("fb: exists", FB.exists(), True)
fbn = norm(FB.read_text(encoding="utf-8"))
check("fb: cites read", ("`1bfb09e`" in fbn) and ("`8e33253`" in fbn), True)
check("fb: count taken", "This pass folds the read back and takes the count." in fbn, True)
check("fb: band closed-held", "The re-pin option stands as a one-line re-open." in fbn, True)
check("fb: count sentence", "reads 36 checks, 0 fail" in fbn, True)

# ---------------- 5. STE gate ----------------
lint_files = [RC, FB, MAP, REG, SEAT]
for f in lint_files:
    r = subprocess.run(["python3", "ste-lint.py", "--fail-above", "2.0", str(f)],
                       capture_output=True, text=True, cwd=ROOT)
    tail = (r.stdout.strip().splitlines() or [""])[-1]
    check(f"ste: {f.name} rc", r.returncode, 0)
    print(f"  ste {f.name}: {tail}")

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

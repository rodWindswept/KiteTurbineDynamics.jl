#!/usr/bin/env python3
"""fig_cvp_fb_check: the check set for the convergence counter-read fold-back.

Covers: the map (row-16 cell closure, delta v49, counts), the
register-status note (gates closed, delta v2, pins intact), the SPEC
(rounds, R3), the seat page (header, item, footer), the receipt, the
no-plate-byte walk, and the STE gate across the touched markdown.
Re-runs the standing set as the last check. Exit 0 on all-pass.
"""
import hashlib
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
KIT = ROOT / "docs" / "reporting" / "figures" / "convergence"
MAP = ROOT / "docs" / "reporting" / "figures" / "figure-map.md"
REG = KIT / "register-status.md"
SPEC = KIT / "SPEC.md"
SEAT = (ROOT / "handovers"
        / "handover-2026-10-14-reporting-room-figures-images-diagrams.md")
FB = (ROOT / "docs" / "reporting" / "room-responses"
      / "figures-images-diagrams-2026-10-15-convergence-closure-foldback.md")
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


# 1. the map
mpr = MAP.read_text()
row = [l for l in mpr.splitlines() if l.startswith("| 16 |")]
check("map: one row-16 line", len(row), 1)
rn = norm(row[0]) if row else ""
check("map: closure in the row cell",
      "F-VALUE PASS (`24111e5` + `7956a39`, 39 + 2 checks) and the "
      "register read (`1b09190` + `c15af17`, 97 checks)" in rn, True)
check("map: old next-gate gone from the cell",
      "counter-reads (the aero F-VALUE and the science register read)"
      in rn, False)
check("map: delta v49",
      "**v49 (2026-10-15):** the convergence counter-reads fold back "
      "(row 16)." in norm(mpr), True)
check("map: counts",
      [mpr.count("| planned |"), mpr.count("| R2 |"),
       mpr.count("| proposed |")], [1, 11, 6])

# 2. the register-status note
regr = REG.read_text()
rgn = norm(regr)
check("register: gates closed",
      "The counter-reads closed clean (2026-10-15)." in rgn, True)
check("register: old gates line gone",
      "The counter-reads open at the seats" in rgn, False)
check("register: delta v2",
      "**Delta** v2 (2026-10-15): the counter-reads close clean." in rgn,
      True)
pins = ["548102e9bdaf32866b52fd4ebb1da8b5",
        "30e9b1487ae084a08850f934627c11fd",
        "27d10ab8b6fd2e57af2e4a4d9664c372",
        "eed92b3f544c6ff2c29719995408b6f",
        "54275ed84115cf80f28b1c2e06414cc5"]
check("register: five pins present", [p in regr for p in pins],
      [True] * 5)

# 3. the SPEC
spn = norm(SPEC.read_text())
check("spec: R2 closure",
      "The counter-reads close clean at both seats (the register-status "
      "v2 record)." in spn, True)
check("spec: R3 holds the visual pass alone",
      "- **R3** the final pass. Rod does the visual pass. Status moves "
      "to approved." in spn, True)
check("spec: old R3 line gone",
      "runs F-VALUE at the sign-off" in spn, False)

# 4. the seat page
stn = norm(SEAT.read_text())
check("seat: item takes the closure",
      "The counter-reads close clean (the aero F-VALUE and the register "
      "read)." in stn, True)
check("seat: footer",
      "rows 4 to 7 and the convergence figure)" in stn, True)
check("seat: header",
      "the convergence build and its counter-read closures (2026-10-15)."
      in stn, True)

# 5. the receipt
fbn = norm(FB.read_text())
check("receipt: cites all four refs",
      all(s in fbn for s in ("24111e5", "7956a39", "1b09190", "c15af17")),
      True)
check("receipt: counts",
      all(s in fbn for s in ("39 checks", "2 checks", "97 checks")), True)
check("receipt: no-plate line", "No plate byte moves." in fbn, True)

# 6. no plate byte moves
outs = ["convergence.svg", "convergence.pdf", "convergence.png",
        "label-ledger.txt", "manifest.json"]
bad = []
for f in outs:
    r = subprocess.run(
        ["git", "diff", "--quiet", "2361771", "--",
         f"docs/reporting/figures/convergence/{f}"],
        cwd=ROOT)
    if r.returncode != 0:
        bad.append(f)
check("no-plate: five outputs unchanged since 2361771", bad, [])
rows = [l.split("  ") for l in REPRO.read_text().splitlines()]
bad = [f for h, f in rows
       if hashlib.md5((KIT / f).read_bytes()).hexdigest() != h]
check("no-plate: md5s recompute vs the repro table", bad, [])
r = subprocess.run(
    ["git", "diff", "--name-only", "2361771", "--",
     "docs/reporting/figures/convergence/"],
    capture_output=True, text=True, cwd=ROOT)
check("no-plate: kit diff = the two notes",
      sorted(Path(x).name for x in r.stdout.split()),
      ["SPEC.md", "register-status.md"])

# 7. STE gate on the touched markdown
for f in (FB, MAP, REG, SPEC, SEAT):
    r = subprocess.run(["python3", "ste-lint.py", "--fail-above", "2.0",
                        str(f)], capture_output=True, text=True, cwd=ROOT)
    check(f"ste rc {f.name}", r.returncode, 0)

# 8. the standing set re-runs
r = subprocess.run(["python3", "scratch/fig_et_pl_check.py"],
                   capture_output=True, text=True, cwd=ROOT)
check("standing set rc", r.returncode, 0)
check("standing set total", "TOTAL: 63 checks, 0 fail" in r.stdout, True)
print(f"  standing: {(r.stdout.strip().splitlines() or [''])[-1]}")

# 9. the receipt's own count
n_total = len(PASS) + len(FAIL) + 1
check("receipt: check count",
      f"{n_total} checks, 0 fail" in norm(FB.read_text()), True)

print()
print(f"TOTAL: {len(PASS) + len(FAIL)} checks, {len(FAIL)} fail")
if FAIL:
    print("FAILED:")
    for f in FAIL:
        print("  " + f)
    sys.exit(1)
print("ALL PASS")

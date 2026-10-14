#!/usr/bin/env python3
"""AU2 claim-evidence matrix supply checks (author seat, 2026-10-14).

Checks the supply receipt against the register and the draft:
  1. every NR row cited in the receipt is present and signed in the register,
     and the expected row set appears;
  2. the eight claim labels map to the SV2 audit list;
  3. the matrix block holds the display forms (15.0, kg-equivalent, the
     classified counts) and prints no 14.972;
  4. every report-location cell names a heading that exists in the draft;
  5. ste-lint holds on the receipt (< 2.0 violations per 100 words);
  6. the housekeeping fold: both feedback paths in .ste-exempt, files present;
  7. the citation gate on the draft (register-seat script), run live.
"""
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path("/home/rod/Documents/GitHub/KiteTurbineDynamics.jl")
RECEIPT = ROOT / "docs/reporting/room-responses/author-2026-10-14-au2-claim-evidence-matrix.md"
REG = ROOT / "docs/reporting/numbers-register.md"
DRAFT = ROOT / "docs/reporting/drafts/2026-10-08-report-first-draft.md"
EXEMPT = ROOT / ".ste-exempt"

text = RECEIPT.read_text()
reg = REG.read_text()
draft = DRAFT.read_text()
ok = True

# 1 — signed rows.
signed = set()
for line in reg.splitlines():
    m = re.match(r"\|\s*(NR-\d+)\b", line.strip())
    if m and re.search(r"(?<!un)signed", line, re.IGNORECASE):
        signed.add(m.group(1))
cited = set(re.findall(r"NR-\d+", text))
expected = {f"NR-{n:03d}" for n in (1, 2, 3, 4, 5, 6, 8, 9, 12, 13, 18, 21, 22, 40)}
missing = sorted(cited - signed)
absent = sorted(expected - cited)
print(f"[1] cited rows: {len(cited)}; register signed rows: {len(signed)}")
print(f"    cited but not signed: {missing or 'none'}")
print(f"    expected rows absent from the receipt: {absent or 'none'}")
if missing or absent:
    ok = False

# 2 — the eight claims, one to one with the SV2 list.
claims = [
    "Campaign scale and status mix", "Winner power", "Winner mass",
    "Structural margin", "Twist and torque margin", "Search improvement",
    "Instrument fidelity", "Model boundaries",
]
absent_c = [c for c in claims if c not in text]
print(f"[2] claims present: {len(claims) - len(absent_c)}/{len(claims)}; absent: {absent_c or 'none'}")
if absent_c:
    ok = False

# 3 — display forms in the matrix block.
block = text.split("## The matrix", 1)[1].split("## Row map", 1)[0]
forms = ["15.0", "kg-equivalent", "clearance_reject", "930", "27.364", "36.109"]
for f in forms:
    hit = f in block
    print(f"[3] form '{f}' in block: {hit}")
    if not hit:
        ok = False
bad = "14.972" in block
print(f"[3] 14.972 in block (must be False): {bad}")
if bad:
    ok = False

# 4 — locations resolve to draft headings.
locs = sorted(set(re.findall(r"§\d\.\d", block)))
for loc in locs:
    heading = "### " + loc.replace("§", "")
    hit = heading in draft
    print(f"[4] {loc} -> draft heading present: {hit}")
    if not hit:
        ok = False

# 5 — ste-lint on the receipt.
r = subprocess.run(
    ["python3", "ste-lint.py", "--fail-above", "2.0", str(RECEIPT)],
    capture_output=True, text=True, cwd=ROOT)
tail = (r.stdout + r.stderr).strip().splitlines()
print(f"[5] ste-lint rc={r.returncode}")
for line in tail:
    print("   ", line)
if r.returncode != 0:
    ok = False

# 6 — housekeeping fold.
ex = EXEMPT.read_text()
for p in ("docs/reporting/feedback/feedback-on-report.md",
          "docs/reporting/feedback/feedback-on-report2.md"):
    hit_ex = p in ex
    hit_f = (ROOT / p).exists()
    print(f"[6] {p}: in .ste-exempt={hit_ex}, file present={hit_f}")
    if not (hit_ex and hit_f):
        ok = False

# 7 — the citation gate on the draft.
r2 = subprocess.run(
    ["python3", "scratch/sv_check_draft_citations.py",
     "docs/reporting/drafts/2026-10-08-report-first-draft.md",
     "docs/reporting/numbers-register.md"],
    capture_output=True, text=True, cwd=ROOT)
lines = (r2.stdout + r2.stderr).strip().splitlines()
print(f"[7] citation gate rc={r2.returncode}")
for line in lines[:4]:
    print("   ", line)
if r2.returncode != 0:
    ok = False

print("RESULT:", "ALL CHECKS PASS" if ok else "FAILURES PRESENT")
sys.exit(0 if ok else 1)

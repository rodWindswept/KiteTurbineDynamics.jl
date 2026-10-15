#!/usr/bin/env python3
# fig_cg2_check.py — the corner-grid read closures fold back: check set (figures seat, 2026-10-15)
# Expected: 0 fail. Prints the record; writes nothing.
import json, subprocess, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MAP = "docs/reporting/figures/figure-map.md"
README = "docs/reporting/figures/machine-corner-grid/README.md"
RSTATUS = "docs/reporting/figures/machine-corner-grid/register-status.md"
SEAT = "handovers/handover-2026-10-14-reporting-room-figures-images-diagrams.md"

checks = []
def ck(desc, ok):
    checks.append((desc, bool(ok)))

def read(rel):
    return (ROOT / rel).read_text(encoding="utf-8")

fm = read(MAP)
rd = read(README)
rs = read(RSTATUS)
sp = read(SEAT)

# -- 1. the map
ck("map: row 23 takes the register read closure", "The register read closes clean (`7e68f0e`, 107 checks): the drawn set reads NR-051 to the signed digits." in fm)
ck("map: row 23 takes the copy closure", "The v0.51 copy counter-read closes clean (`ed95cf1`, 304 checks). The train is closed at this seat |" in fm)
ck("map: the old next-tail reads zero", "Next: the review copy rebuild and its counter-reads |" not in fm)
ck("map: delta v43", "- **v43 (2026-10-15):** the corner-grid reads fold back." in fm)
ck("map: delta v42 holds", "- **v42 (2026-10-15):** the corner machines fold into the report." in fm)
ck("map: delta v41 holds", "- **v41 (2026-10-15):** the relabel closures fold back." in fm)
ck("map: the closure commits read twice each", fm.count("`7e68f0e`") == 2 and fm.count("`ed95cf1`") == 2)

# -- 2. the kit README
ck("README: the register read line", "The register read closes clean (`7e68f0e`, 107 checks): the drawn set reads" in rd)
ck("README: the copy closure line", "The v0.51 copy counter-read closes clean" in rd)
ck("README: the closure closer", "The train is closed at this seat." in rd)
ck("README: the fold paragraph holds", "The fold lands\n(draft v0.51, §3.4): the seat marker joins the field pair" in rd)
ck("README: the pins sentence holds", "commit `cb862df`." in rd)

# -- 3. the kit register
ck("register: delta v4", "**Delta** v4 (2026-10-15): the register read closes clean (`7e68f0e`," in rs)
ck("register: the copy closure", "closes clean (`ed95cf1`, 304 checks). No drawn value moves." in rs)
ck("register: delta v3 holds", "**Delta** v3 (2026-10-15): the visual pass by Rod reads clean." in rs)
ck("register: delta v2 holds", "**Delta** v2 (2026-10-15): the counter-reads close clean" in rs)
ck("register: the sign cite holds", rs.count("`cb862df`") == 2)

# -- 4. the seat page
ck("seat page: the refresh line", "This refresh records the corner-grid closures (the register read at `7e68f0e` and the v0.51 copy counter-read at `ed95cf1`)" in sp)
ck("seat page: the open item takes the closure", "The corner grid's pass reads clean, its fold lands and its reads close (draft v0.51, map v42 and v43)." in sp)
ck("seat page: the closed entry", "The corner-grid reads fold back (2026-10-15): the register read closes (`7e68f0e`, 107 checks)" in sp)
ck("seat page: the old open form reads zero", "The corner grid's pass reads clean and its fold lands (draft v0.51, map v42)." not in sp)
ck("seat page: the fold entry holds", "The corner machines fold into the report (2026-10-15):" in sp)

# -- 5. the diff census (against the facts of the edit run)
facts = json.loads(read("scratch/fig_cg2_facts.json"))
ck("facts: map +8 -1", facts["files"][MAP]["add"] == 8 and facts["files"][MAP]["rem"] == 1)
ck("facts: map changed lines", facts["files"][MAP]["add_lines"] == [55, 474, 475, 476, 477, 478, 479, 480])
ck("facts: README +4 -0", facts["files"][README]["add"] == 4 and facts["files"][README]["rem"] == 0)
ck("facts: register +5 -0", facts["files"][RSTATUS]["add"] == 5 and facts["files"][RSTATUS]["rem"] == 0)
ck("facts: seat page +4 -2", facts["files"][SEAT]["add"] == 4 and facts["files"][SEAT]["rem"] == 2)

# -- 6. STE gate (live re-run)
for rel in (MAP, README, RSTATUS, SEAT):
    p = subprocess.run([sys.executable, "ste-lint.py", "--fail-above", "2.0", rel],
                       cwd=ROOT, capture_output=True, text=True)
    ck(f"STE rc=0 {rel}", p.returncode == 0)

# -- report
fails = [c for c in checks if not c[1]]
for desc, ok in checks:
    print(("ok   " if ok else "FAIL ") + desc)
print(f"\n{len(checks)} checks, {len(fails)} fail")
sys.exit(1 if fails else 0)

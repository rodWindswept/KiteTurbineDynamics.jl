#!/usr/bin/env python3
# fig_cg_fold_check.py — the corner-machines fold: check set (figures seat, 2026-10-15)
# Expected: 0 fail. Prints the record; writes nothing.
import hashlib, json, re, subprocess, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CG = "docs/reporting/figures/machine-corner-grid"
DRAFT = "docs/reporting/drafts/2026-10-08-report-first-draft.md"
TRACKER = "docs/reporting/draft-tracker.md"
MAP = "docs/reporting/figures/figure-map.md"
README = f"{CG}/README.md"
RSTATUS = f"{CG}/register-status.md"
SEAT = "handovers/handover-2026-10-14-reporting-room-figures-images-diagrams.md"
BLOCK_MD5 = "7bbd964db09d2b33269ce5cb8c334054"
MARKER23 = ("[Figure seated: figure-map row 23 (the corner machines, slug "
            "`machine-corner-grid`). Values cite NR-044 and NR-051.]")
CG_SHA = {
    "png": "517a77bf032bec1c0cde4eea7db93fdbc47470c65c9d76e6c4e58249436a2568",
    "svg": "b2e4055d39b7ff72d1e10ea11f59d3bbc8af145ef8a30dc83b7016530b4de0b2",
    "pdf": "298a0f8e4e674dc8e13b64715ee0dfd383e7671d9f3c262a376abe7d5b5114c6",
    "checks": "e6bcfca931d36089dd2a8d6e9c8414fb49230c0d2110717176cf1e0ae385ffbe",
}

checks = []
def ck(desc, ok):
    checks.append((desc, bool(ok)))

def read(rel):
    return (ROOT / rel).read_text(encoding="utf-8")
def sha(rel):
    return hashlib.sha256((ROOT / rel).read_bytes()).hexdigest()

d = read(DRAFT)
t = read(TRACKER)
fm = read(MAP)
rd = read(README)
rs = read(RSTATUS)
sp = read(SEAT)
man = json.loads(read(f"{CG}/manifest.json"))

# -- 1. the draft: pin, marker seat, census
ck("draft: pin reads v0.51", "Internal engineering report. Draft v0.51. Date 2026-10-15." in d)
ck("draft: v0.50 reads zero", "v0.50" not in d)
ck("draft: v0.49 reads zero", "v0.49" not in d)
ck("draft: marker 23 exact, once", d.count(MARKER23) == 1)
i21 = d.find("slug `pca-atlas`")
i23 = d.find(MARKER23)
iblk = d.find("The two plates map the same search in two views.")
ck("draft: marker 23 sits after marker 21", i21 < i23)
ck("draft: marker 23 sits ahead of the frozen block", i23 < iblk)
seats = re.findall(r"\[Figure seated: figure-map row (\d+) \(([^,]+), slug `([^`]+)`\)", d)
ck("draft: eight seats resolve", len(seats) == 8)
ck("draft: seat order", [s[2] for s in seats] == [
    "system-anatomy", "machine-winner-hero", "ring-utilisation", "twist-limit",
    "pca-landscape", "pca-atlas", "machine-corner-grid", "machine-evolution-strip"])
mk = d[i23:i23 + len(MARKER23)]
ck("draft: the marker cites exactly NR-044 and NR-051", set(re.findall(r"NR-\d+", mk)) == {"NR-044", "NR-051"})

# -- 2. the frozen levers block holds
blk = d[d.find("The two plates map the same search in two views."):d.find("\n### 3.5 The evolution story")]
ck("draft: frozen block md5 holds", hashlib.md5(blk.encode()).hexdigest() == BLOCK_MD5)

# -- 3. the appendix: eight exhibits, the row, the hashes
ck("appendix: all eight read dd3cc6a", "One row per built exhibit. All eight read dataset commit `dd3cc6a`." in d)
ck("appendix: all seven reads zero", "All seven read dataset commit" not in d)
ck("appendix: the corner row", "| The corner machines | `corner-grid-extract-2026-10-15-picks` | NR-044, NR-051 | `a4b4057` | `post-95c385d_wind-authority` |" in d)
ck("appendix: eight era cells", d.count("`post-95c385d_wind-authority` |") == 8)
for name, fn in [("png", "machine-corner-grid.png"), ("svg", "machine-corner-grid.svg"),
                 ("pdf", "machine-corner-grid.pdf"), ("checks", "checks.log")]:
    ck(f"appendix: hash line {name}", f"- `{name}` `{CG_SHA[name]}`" in d)
    ck(f"manifest: output hash {fn}", man["outputs"][fn] == CG_SHA[name])
    ck(f"disk: sha256 {fn}", sha(f"{CG}/{fn}") == CG_SHA[name])
# the seven older exhibits' rows hold
for frag in ["| Ring utilisation plate |", "| Twist limit plate |", "| Machine evolution strip |",
             "| System anatomy plate |", "| Levers landscape |", "| Parameter atlas |", "| Machine winner |"]:
    ck(f"appendix: old row holds {frag}", frag in d)
ck("appendix: the block header", "The corner machines:\n\n- `png`" in d)

# -- 4. the tracker
ck("tracker: v0.51 entry", "v0.51 pass by @fig-img-diagrams (2026-10-15)." in t)
ck("tracker: the fold sentence", "This pass folds the corner machines into the report." in t)
ck("tracker: the seat-call sentence", "The plate seats at §3.4 beside the field pair, ahead of the levers reading block." in t)
ck("tracker: the appendix sentence", "The figure-provenance appendix gains the eighth exhibit row and its hashes." in t)
ck("tracker: v0.50 entry holds", "v0.50 pass by @author (2026-10-15)." in t)
ck("tracker: working notes hold", "## 2. Working notes" in t)

# -- 5. the map
ck("map: row 23 takes the fold", "The visual pass by Rod reads clean (2026-10-15). The fold lands (§3.4, draft v0.51): the seat marker joins the field pair, and the figure-provenance appendix takes the eighth exhibit row and its hashes. Next: the review copy rebuild and its counter-reads |" in fm)
ck("map: row 23's old tail reads zero", "Two cite findings close: both cites take the sign commit. Next: the visual pass by Rod, then the fold |" not in fm)
ck("map: delta v42", "- **v42 (2026-10-15):** the corner machines fold into the report." in fm)
ck("map: delta v41 holds", "- **v41 (2026-10-15):** the relabel closures fold back." in fm)

# -- 6. the kit records
ck("README: the visual-pass line", "The visual pass by Rod reads clean (2026-10-15). The fold lands" in rd)
ck("README: the old next-line reads zero", "Next: the visual pass by Rod." not in rd)
ck("register: delta v3", "**Delta** v3 (2026-10-15): the visual pass by Rod reads clean." in rs)
ck("register: the sign cite holds", rs.count("`cb862df`") == 2)
ck("register: delta v2 holds", "**Delta** v2 (2026-10-15): the counter-reads close clean" in rs)

# -- 7. the seat page
ck("seat page: the refresh line", "This refresh records the corner-machines fold (the visual pass reads clean at draft v0.51)" in sp)
ck("seat page: open item takes the clear", "The corner grid's pass reads clean and its fold lands (draft v0.51, map v42)." in sp)
ck("seat page: the closed entry", "The corner machines fold into the report (2026-10-15):" in sp)
ck("seat page: the old open form reads zero", "The corner grid, the winner plate, the F1 plate and rows 4 to 7 read the visual pass as their next gate" not in sp)

# -- 8. the diff census (against the facts of the edit run)
facts = json.loads(read("scratch/fig_cg_fold_facts.json"))
ck("facts: draft +12 -2", facts["files"][DRAFT]["add"] == 12 and facts["files"][DRAFT]["rem"] == 2)
ck("facts: draft changed lines", facts["files"][DRAFT]["add_lines"] == [3, 635, 636, 938, 949, 1003, 1004, 1005, 1006, 1007, 1008, 1009])
ck("facts: tracker +7 -0", facts["files"][TRACKER]["add"] == 7 and facts["files"][TRACKER]["rem"] == 0)
ck("facts: map +7 -1", facts["files"][MAP]["add"] == 7 and facts["files"][MAP]["rem"] == 1)
ck("facts: seat page +4 -2", facts["files"][SEAT]["add"] == 4 and facts["files"][SEAT]["rem"] == 2)

# -- 9. STE gate (live re-run)
for rel in (DRAFT, TRACKER, MAP, README, RSTATUS, SEAT):
    p = subprocess.run([sys.executable, "ste-lint.py", "--fail-above", "2.0", rel],
                       cwd=ROOT, capture_output=True, text=True)
    num = [l for l in (p.stdout + p.stderr).splitlines() if "per100w" in l]
    ck(f"STE rc=0 {rel}", p.returncode == 0)

# -- report
fails = [c for c in checks if not c[1]]
for desc, ok in checks:
    print(("ok   " if ok else "FAIL ") + desc)
print(f"\n{len(checks)} checks, {len(fails)} fail")
sys.exit(1 if fails else 0)

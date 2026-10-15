#!/usr/bin/env python3
# fig_cg2_docs_edit.py — the corner-grid read closures fold back: all text moves (figures seat, 2026-10-15)
#
# Verify-all-then-apply. Every (old, new) pair must match exactly once.
# Writes (--write): the four doc files, and scratch/fig_cg2_facts.json.
# Gates: STE per file (rc=0 under --fail-above 2.0 on the candidates).
import hashlib, json, subprocess, sys, difflib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

MAP = "docs/reporting/figures/figure-map.md"
README = "docs/reporting/figures/machine-corner-grid/README.md"
RSTATUS = "docs/reporting/figures/machine-corner-grid/register-status.md"
SEAT = "handovers/handover-2026-10-14-reporting-room-figures-images-diagrams.md"

P = []

P.append((MAP, [
    ("Next: the review copy rebuild and its counter-reads |",
     "The register read closes clean (`7e68f0e`, 107 checks): the drawn set reads NR-051 to the signed digits. The v0.51 copy counter-read closes clean (`ed95cf1`, 304 checks). The train is closed at this seat |"),
    ("  its state line and delta v3. No plate byte moves.\n",
     "  its state line and delta v3. No plate byte moves.\n"
     "\n"
     "- **v43 (2026-10-15):** the corner-grid reads fold back. The register\n"
     "  read closes (`7e68f0e`, 107 checks): the drawn set reads NR-051 to\n"
     "  the signed digits and the seat marker cites NR-044 and NR-051 only.\n"
     "  The v0.51 copy counter-read closes (`ed95cf1`, 304 checks): record\n"
     "  `1061878`, 32 pins, eight embeds, the corner plate the eighth. No\n"
     "  plate byte moves.\n"),
]))

P.append((README, [
    ("takes the eighth exhibit row and its hashes.\n\n## Delivered files",
     "takes the eighth exhibit row and its hashes.\n"
     "\n"
     "The register read closes clean (`7e68f0e`, 107 checks): the drawn set reads\n"
     "NR-051 to the signed digits. The v0.51 copy counter-read closes clean\n"
     "(`ed95cf1`, 304 checks). The train is closed at this seat.\n"
     "\n"
     "## Delivered files"),
]))

P.append((RSTATUS, [
    ("the figure-provenance appendix takes the eighth exhibit row and its\nhashes. No drawn value moves.",
     "the figure-provenance appendix takes the eighth exhibit row and its\nhashes. No drawn value moves.\n"
     "\n"
     "**Delta** v4 (2026-10-15): the register read closes clean (`7e68f0e`,\n"
     "107 checks): the drawn set reads NR-051 to the signed digits, and the\n"
     "seat marker cites NR-044 and NR-051 only. The v0.51 copy counter-read\n"
     "closes clean (`ed95cf1`, 304 checks). No drawn value moves."),
]))

P.append((SEAT, [
    ("This refresh records the corner-machines fold (the visual pass reads clean at draft v0.51), the relabel closures, the term gate, the counter-reads and the cite fixes (2026-10-15).",
     "This refresh records the corner-grid closures (the register read at `7e68f0e` and the v0.51 copy counter-read at `ed95cf1`), the corner-machines fold at draft v0.51, the relabel closures, the term gate, the counter-reads and the cite fixes (2026-10-15)."),
    ("The corner grid's pass reads clean and its fold lands (draft v0.51, map v42).",
     "The corner grid's pass reads clean, its fold lands and its reads close (draft v0.51, map v42 and v43)."),
    ("## Closed, last (evidence index)\n\n- The corner machines fold into the report (2026-10-15):",
     "## Closed, last (evidence index)\n\n"
     "- The corner-grid reads fold back (2026-10-15): the register read closes (`7e68f0e`, 107 checks) and the v0.51 copy counter-read closes (`ed95cf1`, 304 checks; the corner plate the eighth embed). Receipt `docs/reporting/room-responses/figures-images-diagrams-2026-10-15-corner-grid-closures-foldback.md`. Evidence `scratch/fig_cg2_check.py` plus the log.\n\n"
     "- The corner machines fold into the report (2026-10-15):"),
]))

# ---- phase 1: verify every pair, all files --------------------------------------
problems = []
base = {}
for rel, pairs in P:
    fp = ROOT / rel
    txt = fp.read_text(encoding="utf-8")
    base[rel] = txt
    for old, new in pairs:
        n = txt.count(old)
        if n != 1:
            problems.append(f"{rel}: count={n} for: {old[:90]!r}")
if problems:
    print("ABORT: pair checks failed:")
    for p in problems:
        print("  " + p)
    sys.exit(1)
print("phase 1 ok: all pairs match exactly once")

# ---- phase 2: compose candidates -------------------------------------------------
cand = {}
for rel, pairs in P:
    t = base[rel]
    for old, new in pairs:
        t = t.replace(old, new)
    cand[rel] = t

# ---- phase 3: STE gate on the candidates ------------------------------------------
CANDS = {
    MAP: "scratch/fig_cg2_map_candidate.md",
    README: "scratch/fig_cg2_readme_candidate.md",
    RSTATUS: "scratch/fig_cg2_rstatus_candidate.md",
    SEAT: "scratch/fig_cg2_seatpage_candidate.md",
}
for rel, cpath in CANDS.items():
    (ROOT / cpath).write_text(cand[rel])
rc_fail = False
for rel, cpath in CANDS.items():
    p = subprocess.run([sys.executable, "ste-lint.py", "--fail-above", "2.0", cpath],
                       cwd=ROOT, capture_output=True, text=True)
    tail = [l for l in (p.stdout + p.stderr).splitlines() if "per100w" in l]
    print(f"STE {rel}: rc={p.returncode} {tail[-1] if tail else ''}")
    if p.returncode != 0:
        rc_fail = True
if rc_fail:
    print("ABORT: STE gate failed on a candidate")
    sys.exit(1)

# ---- the diff census --------------------------------------------------------------
facts = {"base_commit": subprocess.run(["git", "rev-parse", "--short", "HEAD"], cwd=ROOT,
                                       capture_output=True, text=True).stdout.strip(),
         "files": {}}
for rel in CANDS:
    bl = base[rel].splitlines()
    nl = cand[rel].splitlines()
    sm = difflib.SequenceMatcher(a=bl, b=nl, autojunk=False)
    add_ln, add, rem = [], [], []
    for tag, i1, i2, j1, j2 in sm.get_opcodes():
        if tag in ("insert", "replace"):
            add += nl[j1:j2]
            add_ln += list(range(j1 + 1, j2 + 1))
        if tag in ("delete", "replace"):
            rem += bl[i1:i2]
    facts["files"][rel] = {"add": len(add), "rem": len(rem), "add_lines": add_ln}
    print(f"diff {rel}: +{len(add)} -{len(rem)} (new-file lines changed: {add_ln})")

(ROOT / "scratch/fig_cg2_facts.json").write_text(json.dumps(facts, indent=2))
print("facts written: scratch/fig_cg2_facts.json")

if "--write" not in sys.argv:
    print("dry run: no files written (use --write)")
    sys.exit(0)
for rel in CANDS:
    (ROOT / rel).write_text(cand[rel])
print("written: 4 files")

#!/usr/bin/env python3
# fig_cg_fold_edit.py — the corner-machines fold: all text moves (figures seat, 2026-10-15)
#
# Verify-all-then-apply. Every (old, new) pair must match exactly once.
# Writes (--write): the six doc files, and scratch/fig_cg_fold_facts.json.
# Gates: STE per file (rc=0 under --fail-above 2.0 on the candidates),
# the frozen levers block md5, the seat count, and the manifest hash pins.
import hashlib, json, subprocess, sys
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

# The delivered plate hashes (also re-verified against disk in the check set).
CG_SHA = {
    "png": "517a77bf032bec1c0cde4eea7db93fdbc47470c65c9d76e6c4e58249436a2568",
    "svg": "b2e4055d39b7ff72d1e10ea11f59d3bbc8af145ef8a30dc83b7016530b4de0b2",
    "pdf": "298a0f8e4e674dc8e13b64715ee0dfd383e7671d9f3c262a376abe7d5b5114c6",
    "checks": "e6bcfca931d36089dd2a8d6e9c8414fb49230c0d2110717176cf1e0ae385ffbe",
}

# ---- the pairs ------------------------------------------------------------------
P = []

P.append((DRAFT, [
    ("Internal engineering report. Draft v0.50. Date 2026-10-15.",
     "Internal engineering report. Draft v0.51. Date 2026-10-15."),
    # the seat marker: with the field pair, ahead of the frozen reading block
    ("[Figure seated: figure-map row 21 (the parameter atlas, slug `pca-atlas`). Values cite NR-001, NR-005, NR-006 and NR-044.]\n\n",
     "[Figure seated: figure-map row 21 (the parameter atlas, slug `pca-atlas`). Values cite NR-001, NR-005, NR-006 and NR-044.]\n\n"
     + MARKER23 + "\n\n"),
    ("One row per built exhibit. All seven read dataset commit `dd3cc6a`.",
     "One row per built exhibit. All eight read dataset commit `dd3cc6a`."),
    ("| Machine winner | `strip-extract-2026-10-09-best-so-far` · `pair-extract-2026-10-08-winner-ops` | NR-011, NR-017, NR-021, NR-022, NR-043 | `1af63fc` | `post-95c385d_wind-authority` |",
     "| Machine winner | `strip-extract-2026-10-09-best-so-far` · `pair-extract-2026-10-08-winner-ops` | NR-011, NR-017, NR-021, NR-022, NR-043 | `1af63fc` | `post-95c385d_wind-authority` |\n"
     "| The corner machines | `corner-grid-extract-2026-10-15-picks` | NR-044, NR-051 | `a4b4057` | `post-95c385d_wind-authority` |"),
    ("- `checks` `31cda877e9131e6f34270ffe8bdb62bd50225d9cc34653ed221a899eae81e962`\n",
     "- `checks` `31cda877e9131e6f34270ffe8bdb62bd50225d9cc34653ed221a899eae81e962`\n"
     "\n"
     "The corner machines:\n"
     "\n"
     f"- `png` `{CG_SHA['png']}`\n"
     f"- `svg` `{CG_SHA['svg']}`\n"
     f"- `pdf` `{CG_SHA['pdf']}`\n"
     f"- `checks` `{CG_SHA['checks']}`\n"),
]))

P.append((TRACKER, [
    ("No value moves, and no figure byte moves.\n\n## 2. Working notes",
     "No value moves, and no figure byte moves.\n\n"
     "v0.51 pass by @fig-img-diagrams (2026-10-15).\n"
     "This pass folds the corner machines into the report.\n"
     "The plate seats at §3.4 beside the field pair, ahead of the levers reading block.\n"
     "The figure-provenance appendix gains the eighth exhibit row and its hashes.\n"
     "The kit takes its state line and its register delta v3 (the visual pass by Rod reads clean).\n"
     "No value moves, and no figure byte moves.\n\n"
     "## 2. Working notes"),
]))

P.append((MAP, [
    ("Two cite findings close: both cites take the sign commit. Next: the visual pass by Rod, then the fold |",
     "Two cite findings close: both cites take the sign commit. The visual pass by Rod reads clean (2026-10-15). The fold lands (§3.4, draft v0.51): the seat marker joins the field pair, and the figure-provenance appendix takes the eighth exhibit row and its hashes. Next: the review copy rebuild and its counter-reads |"),
    ("  and 10 take the closure and read the visual pass by Rod as their next\n  gate. No plate byte moves.\n",
     "  and 10 take the closure and read the visual pass by Rod as their next\n  gate. No plate byte moves.\n"
     "\n"
     "- **v42 (2026-10-15):** the corner machines fold into the report. The\n"
     "  visual pass by Rod reads clean. The plate seats at §3.4 beside the\n"
     "  field pair, ahead of the levers reading block. The figure-provenance\n"
     "  appendix takes the eighth exhibit row and its hashes. The kit takes\n"
     "  its state line and delta v3. No plate byte moves.\n"),
]))

P.append((README, [
    ("commit `cb862df`. Next: the visual pass by Rod.",
     "commit `cb862df`.\n"
     "\n"
     "The visual pass by Rod reads clean (2026-10-15). The fold lands\n"
     "(draft v0.51, §3.4): the seat marker joins the field pair, and the\n"
     "figure-provenance appendix takes the eighth exhibit row and its hashes."),
]))

P.append((RSTATUS, [
    ("commit `cb862df`. No drawn value moves.",
     "commit `cb862df`. No drawn value moves.\n"
     "\n"
     "**Delta** v3 (2026-10-15): the visual pass by Rod reads clean. The fold\n"
     "lands (draft v0.51): the seat marker joins the field pair at §3.4, and\n"
     "the figure-provenance appendix takes the eighth exhibit row and its\n"
     "hashes. No drawn value moves."),
]))

P.append((SEAT, [
    ("This refresh records the relabel closures (the author fold at v0.49, the term gate, the counter-reads), the corner counter-read closure and the cite fixes (2026-10-15).",
     "This refresh records the corner-machines fold (the visual pass reads clean at draft v0.51), the relabel closures, the term gate, the counter-reads and the cite fixes (2026-10-15)."),
    ("1. **The visual pass by Rod.** The corner grid, the winner plate, the F1 plate and rows 4 to 7 read the visual pass as their next gate (map v38 to v41). The plates carry the round-6 top forms and the relabel. The winner plate reads §3.3, ahead of the plates. It moves earlier in one line if the room calls.",
     "1. **The visual pass by Rod.** The winner plate, the F1 plate and rows 4 to 7 read the visual pass as their next gate (map v38 to v41). The corner grid's pass reads clean and its fold lands (draft v0.51, map v42). The plates carry the round-6 top forms and the relabel. The winner plate reads §3.3, ahead of the plates. It moves earlier in one line if the room calls."),
    ("## Closed, last (evidence index)\n\n- The relabel closures fold back (2026-10-15):",
     "## Closed, last (evidence index)\n\n"
     "- The corner machines fold into the report (2026-10-15): the seat marker joins the field pair at §3.4, and the figure-provenance appendix takes the eighth exhibit row and its hashes (draft v0.51). The visual pass by Rod reads clean. The review copy rebuilds with the eighth embed. Receipt `docs/reporting/room-responses/figures-images-diagrams-2026-10-15-corner-machines-fold.md`. Evidence `scratch/fig_cg_fold_edit.py`, `scratch/fig_cg_fold_check.py` plus logs.\n\n"
     "- The relabel closures fold back (2026-10-15):"),
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

# the frozen block must survive byte-exact in the draft candidate
d = cand[DRAFT]
i0 = d.find("The two plates map the same search in two views.")
i1 = d.find("\n### 3.5 The evolution story")
blk_txt = d[i0:i1]
h = hashlib.md5(blk_txt.encode()).hexdigest()
print(f"block md5 (candidate): {h} (declared {BLOCK_MD5})")
assert h == BLOCK_MD5, "ABORT: frozen levers block md5 mismatch"

# seat census: exactly 8 markers, corner grid before the evolution strip
import re
seats = re.findall(r"\[Figure seated: figure-map row (\d+) \(([^,]+), slug `([^`]+)`\)", d)
print(f"seats: {len(seats)}")
for s in seats:
    print("   ", s)
assert len(seats) == 8, "ABORT: seat count != 8"
slugs = [s[2] for s in seats]
assert slugs == ["system-anatomy", "machine-winner-hero", "ring-utilisation", "twist-limit",
                 "pca-landscape", "pca-atlas", "machine-corner-grid", "machine-evolution-strip"], "ABORT: slug order"
# marker 23 sits between marker 21 and the block
a = d.find("slug `pca-atlas`")
b = d.find(MARKER23)
c = d.find("The two plates map the same search in two views.")
assert a < b < c, "ABORT: marker 23 seat position"

# manifest pins match disk and the appendix cells
man = json.loads((ROOT / CG / "manifest.json").read_text())
for name in ("png", "svg", "pdf", "checks"):
    fn = "checks.log" if name == "checks" else f"machine-corner-grid.{name}"
    sha = hashlib.sha256((ROOT / CG / fn).read_bytes()).hexdigest()
    assert sha == CG_SHA[name] == man["outputs"][fn], f"ABORT: {fn} hash mismatch"
print("manifest pins: 4 of 4 match disk and the appendix cells")

# ---- phase 3: STE gate on the candidates ------------------------------------------
CANDS = {
    DRAFT: "scratch/fig_cg_fold_draft_candidate.md",
    TRACKER: "scratch/fig_cg_fold_tracker_candidate.md",
    MAP: "scratch/fig_cg_fold_map_candidate.md",
    README: "scratch/fig_cg_fold_readme_candidate.md",
    RSTATUS: "scratch/fig_cg_fold_rstatus_candidate.md",
    SEAT: "scratch/fig_cg_fold_seatpage_candidate.md",
}
for rel, cpath in CANDS.items():
    (ROOT / cpath).write_text(cand[rel])
rc_fail = False
for rel, cpath in CANDS.items():
    p = subprocess.run([sys.executable, "ste-lint.py", "--fail-above", "2.0", cpath],
                       cwd=ROOT, capture_output=True, text=True)
    tail = [l for l in (p.stdout + p.stderr).splitlines() if "words=" in l or "per100w" in l]
    print(f"STE {rel}: rc={p.returncode} {tail[-1] if tail else ''}")
    if p.returncode != 0:
        rc_fail = True
if rc_fail:
    print("ABORT: STE gate failed on a candidate")
    sys.exit(1)

# ---- the diff census --------------------------------------------------------------
import difflib
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
    print(f"diff {rel}: +{len(add)} -{len(rem)} (new-file lines changed: {add_ln}")

(ROOT / "scratch/fig_cg_fold_facts.json").write_text(json.dumps(facts, indent=2))
print("facts written: scratch/fig_cg_fold_facts.json")

if "--write" not in sys.argv:
    print("dry run: no files written (use --write)")
    sys.exit(0)
for rel in CANDS:
    (ROOT / rel).write_text(cand[rel])
print("written: 6 files")

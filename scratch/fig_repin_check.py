#!/usr/bin/python3
# -*- coding: utf-8 -*-
"""The appendix re-pin: the independent check pass (figures seat).

Asserts, from committed bytes only:

1. The ten fix substitutions read landed; every retired string absent.
2. The two levers rows read their cite sets, script commit and era.
3. The count sentence reads six; the head reads v0.35; the tracker entry
   reads present.
4. Every pinned output in the appendix (all six blocks, 24 values)
   recomputes: sha256(worktree) == sha256(git HEAD blob) == the appendix
   value. A swapped or stale pin fails.
5. The digit-token diff between HEAD and the worktree, printed for the
   declaration.

Run: /usr/bin/python3 scratch/fig_repin_check.py
Writes: scratch/fig_repin_check.log
"""

import hashlib
import re
import subprocess
from collections import Counter
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
DRAFT_REL = "docs/reporting/drafts/2026-10-08-report-first-draft.md"
TRACKER_REL = "docs/reporting/draft-tracker.md"
DRAFT = REPO / DRAFT_REL
TRACKER = REPO / TRACKER_REL

fails, lines = [], []


def check(name, ok):
    lines.append("check: %s: %s" % (name, "OK" if ok else "FAIL"))
    if not ok:
        fails.append(name)


def git_blob(rel):
    p = subprocess.run(
        ["git", "-C", str(REPO), "show", "HEAD:%s" % rel],
        capture_output=True,
    )
    assert p.returncode == 0, "git show failed for %s" % rel
    return p.stdout


d = DRAFT.read_text()

# 1. The substitutions.
RETIRED = [
    "6f19832088375b96cdc566aff596ccd548f26b629b9782bc56d8831d03c622ba",
    "ec0f4b96f3fa9b646183e1f7004a0e5d8ce0f9ab28f111472d4ed32ffa0c6b58",
    "508b3a641fde21b582ee2a58a3d3df2a769998281f78c8763ba07438286c1f8f",
    "c040fca2dd63df9c68b56a767ccd0383962db479b04d75d23821b311628ce099",
    "7ff5c05cc0caa0890400fec50a9366397a203b891031fa400d9638872d0b4501",
    "ffac9c1eba5386fe79d3c1f5a69afdfadafaba507adaf47963a1b2ddd669d472",
    "d207343460263fde7481c8be1572e797895db488f7828b35d14a09003436d4a1",
    "6dfbd6eae0285a55475cd8cfe365e92bb9a6137d5e4da23f469634c58d1f1c28",
]
check("eight retired hashes absent", all(h not in d for h in RETIRED))
check("old script commit absent", "eacf073" not in d)
check("plate script cells x2 read 671ab96", d.count("`671ab96`") == 2)
check("count sentence reads six", "One row per built exhibit. All six read dataset commit `dd3cc6a`." in d)
check("head reads v0.35", "Internal engineering report. Draft v0.35. Date 2026-10-14." in d)

# 2. The levers rows.
TEL = "`scripts/results/v13_5kw_masslift_len18.8_rotorcount_bankderate2/island_{1,2,3}/telemetry.csv`"
check(
    "landscape row reads",
    "| Levers landscape | %s | NR-001, NR-005, NR-006, NR-044, NR-045 | `e23f226` | `post-95c385d_wind-authority` |" % TEL
    in d,
)
check(
    "atlas row reads",
    "| Parameter atlas | %s | NR-001, NR-005, NR-006, NR-044 | `e23f226` | `post-95c385d_wind-authority` |" % TEL
    in d,
)

# 3. The tracker entry and the handover refresh.
t = TRACKER.read_text()
check("tracker v0.35 entry", "v0.35 pass by @fig-img-diagrams (2026-10-14)." in t)
m = (REPO / "docs/reporting/figures/figure-map.md").read_text()
check("map delta v30", "**v30 (2026-10-14):**" in m)
h = (REPO / "handovers/handover-2026-10-14-reporting-room-figures-images-diagrams.md").read_text()
check("handover next action refreshed", "item-5 lever-statistics extract. Fold the map closure" in h)
check("handover closed entry", "The appendix re-pin and the levers rows 20/21" in h)

# 4. Every pinned output recomputes from the committed bytes.
BLOCK_DIR = {
    "Ring utilisation plate": "ring-utilisation",
    "Twist limit plate": "twist-limit",
    "Machine evolution strip": "machine-evolution-strip",
    "System anatomy plate": "system-anatomy",
    "Levers landscape": "pca-landscape",
    "Parameter atlas": "pca-atlas",
}
LABEL_FILE = {
    "png": "%s.png",
    "svg": "%s.svg",
    "pdf": "%s.pdf",
    "ledger": "label-ledger.txt",
    "checks": "checks.log",
}
hdr = d.index("**Output hashes (SHA-256).**")
section = d[hdr:]
blocks = re.findall(r"(?m)^([A-Za-z][^\n:]*):\n\n((?:- `[a-z]+` `[0-9a-f]{64}`\n?)+)", section)
check("appendix carries six hash blocks", len(blocks) == 6)
seen = []
for name, body in blocks:
    slug = BLOCK_DIR.get(name)
    check("block name known: %s" % name, slug is not None)
    if slug is None:
        continue
    pairs = re.findall(r"- `([a-z]+)` `([0-9a-f]{64})`", body)
    check("block %s carries four pins" % name, len(pairs) == 4)
    for label, pinned in pairs:
        tpl = LABEL_FILE[label]
        fname = tpl % slug if "%s" in tpl else tpl
        path = REPO / "docs/reporting/figures" / slug / fname
        wt = hashlib.sha256(path.read_bytes()).hexdigest() if path.exists() else "<missing>"
        bl = hashlib.sha256(git_blob("docs/reporting/figures/%s/%s" % (slug, fname))).hexdigest()
        check("%s/%s file==pinned" % (slug, fname), wt == pinned)
        check("%s/%s gitHEAD==pinned" % (slug, fname), bl == pinned)
        seen.append((slug, label))
check("24 values walked", len(seen) == 24)

# 5. The digit-token diff.
def digit_tokens(s):
    out = []
    for line in s.splitlines():
        for raw in line.split():
            tok = raw.strip("`|*:;,.()[]{}<>#…·—–")
            if tok and any(ch.isdigit() for ch in tok):
                out.append(tok)
    return Counter(out)


def classify(tok):
    if re.fullmatch(r"[0-9a-f]{64}", tok):
        return "hash64"
    if re.fullmatch(r"[0-9a-f]{7}", tok):
        return "commit7"
    if tok.startswith("v0."):
        return "version"
    return "other"


for rel, path in ((DRAFT_REL, DRAFT), (TRACKER_REL, TRACKER)):
    old = digit_tokens(git_blob(rel).decode())
    new = digit_tokens(path.read_text())
    added = {k: v for k, v in (new - old).items() if v}
    removed = {k: v for k, v in (old - new).items() if v}
    lines.append("== token diff %s: +%d tokens, -%d tokens" % (rel, sum(added.values()), sum(removed.values())))
    for tok, n in sorted(added.items()):
        lines.append("   +%dx %s [%s]" % (n, tok, classify(tok)))
    for tok, n in sorted(removed.items()):
        lines.append("   -%dx %s [%s]" % (n, tok, classify(tok)))

lines.append("== summary: " + ("%d FAIL: %s" % (len(fails), fails) if fails else "all OK"))
log = "\n".join(lines) + "\n"
(REPO / "scratch/fig_repin_check.log").write_text(log)
print(log)
raise SystemExit(1 if fails else 0)

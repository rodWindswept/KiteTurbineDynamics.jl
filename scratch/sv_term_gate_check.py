#!/usr/bin/env python3
# sv_term_gate_check.py — the SW/SV term gate on the round-4 rename (science-validator, 2026-10-14)
#
# Scope: the round-4 rename retires one term across the live reader surfaces.
# Live surfaces: the draft, the tracker and the glossary candidates. The delivered
# review copy rides the docx check. Everything else is a record: verbatim feedback
# files (exempt class), routing notes, receipts, handovers, plans, register history
# and scratch evidence. The gate:
#   A. live sites read the new form; the old form reads zero there (pinned sentences).
#   B. a repo census of the old form classifies every hit (fail on live or unclassified).
#   C. the delivered copy reads the new form with no old form.
#   D. the register stays append-only since NR-046 (4a86e6f), zero removals.
# Stdlib only. Token SV_TERMGATE_DONE on success, SV_TERMGATE_FAIL otherwise.
import os
import re
import subprocess
import sys
import zipfile
from collections import Counter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ok = True


def read(rel):
    with open(os.path.join(ROOT, rel)) as f:
        return f.read()


def check(name, good, extra=""):
    global ok
    tail = "" if good else ("  [" + extra + "]")
    print(("OK  " if good else "FAIL") + "  " + name + tail)
    ok = ok and good


def git(*args):
    return subprocess.run(["git", "-C", ROOT] + list(args), capture_output=True, text=True).stdout.strip()


NEW = re.compile(r"soft[ -]constraint penalt", re.I)
OLD = re.compile(r"gate[ -]penalt", re.I)

LIVE = [
    "docs/reporting/drafts/2026-10-08-report-first-draft.md",
    "docs/reporting/draft-tracker.md",
    "docs/reporting/glossary-candidates.md",
]

print("sv_term_gate_check — read at HEAD", git("rev-parse", "--short", "HEAD"),
      "| origin", git("rev-parse", "--short", "origin/bank-derate-cos2p65"))

# ── A. live sites ────────────────────────────────────────────────────────
print("-- live sites --")
for rel in LIVE:
    lines = read(rel).splitlines()
    new_hits = [(i + 1, l) for i, l in enumerate(lines) if NEW.search(l)]
    old_hits = [(i + 1, l) for i, l in enumerate(lines) if OLD.search(l)]
    check("live: %s: new form present" % rel, len(new_hits) > 0, "hits=%d" % len(new_hits))
    check("live: %s: old form zero" % rel, len(old_hits) == 0, str(old_hits[:3]))
    print("     new-form lines: %s" % [h[0] for h in new_hits])
    for ln, l in new_hits:
        print("       L%d: %s" % (ln, l.strip()[:160]))
    for ln, l in new_hits:
        s = re.sub(r"`[^`]*`", " ", l)
        s = re.sub(r"section\s+\d+\.\d+", " ", s)
        s = re.sub(r"\bv\d+\.\d+\b", " ", s)
        check("live: %s L%d carries no value numeral" % (rel, ln),
              not re.search(r"\d+\.\d+", s), l.strip()[:80])

pins = [
    ("docs/reporting/drafts/2026-10-08-report-first-draft.md",
     "the airborne mass plus the soft constraint penalties."),
    ("docs/reporting/drafts/2026-10-08-report-first-draft.md",
     "three soft constraint penalties to the airborne mass"),
    ("docs/reporting/draft-tracker.md", "the three soft constraint penalty forms"),
    ("docs/reporting/glossary-candidates.md",
     "the airborne mass plus the soft constraint penalties, read as a mass"),
]
for rel, s in pins:
    check("pin: %s | %s" % (os.path.basename(rel), s[:60]), s in read(rel))

# ── B. repo census of the old form ───────────────────────────────────────
print("-- old-form census (tracked files) --")
out = git("grep", "-c", "-i", "-E", "gate[ -]penalt")
counts = {}
for line in out.splitlines():
    path, _, cnt = line.rpartition(":")
    counts[path] = int(cnt)

exempt = set()
for line in read(".ste-exempt").splitlines():
    line = line.strip()
    if line and not line.startswith("#"):
        exempt.add(line)


def classify(p):
    if p in LIVE:
        return "LIVE"
    if p in exempt:
        return "exempt-verbatim"
    if p.startswith(("scratch/", "docs/reporting/room-responses/", "handovers/", "docs/plans/", "docs/validation/")):
        return "records-evidence"
    if p == "docs/reporting/2026-10-14-feedback4-routing-plain-english.md":
        return "records-evidence"
    return "UNCLASSIFIED"


classes = Counter()
unclassified = []
for p, c in sorted(counts.items()):
    cl = classify(p)
    classes[cl] += 1
    print("  [%s] %s: %d" % (cl, p, c))
    if cl == "UNCLASSIFIED":
        unclassified.append(p)

total_old = sum(counts.values())
print("  total: %d occurrences across %d files; classes: %s" % (total_old, len(counts), dict(classes)))
check("old form: zero live-surface files", classes["LIVE"] == 0)
check("old form: every residue classified", not unclassified, str(unclassified))

print("-- old-form census (untracked working set) --")
unt = git("ls-files", "--others", "--exclude-standard").splitlines()
unt_total = 0
unt_files = 0
unt_unclassified = []
for p in sorted(unt):
    fp = os.path.join(ROOT, p)
    try:
        if os.path.getsize(fp) > 2000000:
            continue
        t = open(fp, encoding="utf-8", errors="ignore").read()
    except OSError:
        continue
    n = len(OLD.findall(t))
    if n == 0:
        continue
    cl = "working-snapshot" if p.startswith("scratch/") else "UNCLASSIFIED"
    unt_total += n
    unt_files += 1
    print("  [%s] %s: %d" % (cl, p, n))
    if cl == "UNCLASSIFIED":
        unt_unclassified.append(p)
print("  untracked total: %d occurrences across %d files" % (unt_total, unt_files))
check("old form (untracked): every residue a working snapshot", not unt_unclassified, str(unt_unclassified))

# ── C. delivered copy and build input ────────────────────────────────────
print("-- delivered copy --")
with zipfile.ZipFile(os.path.join(ROOT, "scratch/report-pdf-build/draft-live.docx")) as z:
    xml = z.read("word/document.xml").decode("utf-8", "ignore")
docx_text = re.sub(r"<[^>]+>", "", xml.replace("</w:p>", "</w:p>\n"))
n_new = len(NEW.findall(docx_text))
n_old = len(OLD.findall(docx_text))
print("  draft-live.docx: new=%d old=%d" % (n_new, n_old))
check("delivered copy: new form reads", n_new >= 1, "new=%d" % n_new)
check("delivered copy: old form zero", n_old == 0, "old=%d" % n_old)

asmd = read("scratch/report-pdf-build/draft-assembled-docx.md")
a_new = len(NEW.findall(asmd))
a_old = len(OLD.findall(asmd))
print("  draft-assembled-docx.md: new=%d old=%d" % (a_new, a_old))
check("build input: new form reads, old form zero", a_new >= 1 and a_old == 0, "new=%d old=%d" % (a_new, a_old))

# ── D. register integrity since NR-046 ───────────────────────────────────
print("-- register integrity --")
stat = git("diff", "--numstat", "4a86e6f", "HEAD", "--", "docs/reporting/numbers-register.md")
if stat:
    added, removed = (int(v) for v in stat.split("\t")[:2])
else:
    added, removed = 0, 0
print("  register diff 4a86e6f..HEAD: +%d/-%d" % (added, removed))
check("register: append-only since 4a86e6f (zero removals)", removed == 0 and added > 0, stat)
reg = read("docs/reporting/numbers-register.md")
for s in ("NR-046", "27.3635412663488 (NR-039)", "stamps the search cost `1e9`"):
    check("register: carries %r" % s[:44], s in reg)
tail_block = reg.split("## ")[-1].splitlines()[0]
print("  register last block header: %s" % tail_block.strip()[:100])
check("register: last block is the NR-046 counter-read append", "NR-046" in tail_block and "counter-read" in tail_block)

if not ok:
    print("SV_TERMGATE_FAIL")
    sys.exit(1)
print("SV_TERMGATE_DONE  (one form on the live surfaces; old form zero there; every residue classified across the tracked tree and the working set; copy clean; register append-only)")

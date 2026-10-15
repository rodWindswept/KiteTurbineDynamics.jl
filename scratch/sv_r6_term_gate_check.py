#!/usr/bin/env python3
# scratch/sv_r6_term_gate_check.py — science-validator, 2026-10-15.
#
# The round-6 term gate on the hub-name retirement (read-only).
# Reads the folded state: draft v0.47 (fold d0ed902), the round-6 plate
# and kit re-cut, the physics-topology note amend, the tracker and the
# candidates as they stand. Checks:
#   A. The draft: old form zero; the ten signed forms; the count and the
#      winner pair; the section 3.4 title; the guard.
#   B. The note: the amend reads; the old form confined to the enumerated set.
#   C. The plates and the kits: delivered art reads the top forms; old form
#      zero in the art; residue confined to the enumerated records/form notes.
#   D. The tracker, the candidates and the stale-phrases list: pending legs.
#   E. The tracked-tree census: every old-form occurrence classified.
#   F. The working-set census.
#   G. The register: holds, append-only since the sign.
#   H. The delivered copy: build state (informational).
# Prints one line per check; exits nonzero on any fail.
import hashlib
import os
import re
import subprocess
import sys
import zipfile
from collections import Counter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)
HUB = re.compile(r"\bhub\b", re.I)

n_ck = 0
n_fail = 0


def chk(name, cond, detail=""):
    global n_ck, n_fail
    n_ck += 1
    if not cond:
        n_fail += 1
    print(f"check: {name}: {'OK' if cond else 'FAIL'}  {detail}")


def rd(rel):
    with open(os.path.join(ROOT, rel), encoding="utf-8", errors="replace") as f:
        return f.read()


def hub_lines(rel):
    out = []
    for i, ln in enumerate(rd(rel).splitlines(), 1):
        if HUB.search(ln):
            out.append((i, ln.strip()))
    return out


def git(*args):
    r = subprocess.run(["git"] + list(args), capture_output=True, text=True)
    return r.stdout


def pin(rel, s, label=None):
    t = rd(rel)
    chk(label or f"pin[{os.path.basename(rel)}]: {s[:72]!r}", s in t)


print(f"sv_r6_term_gate_check — read at HEAD {git('rev-parse', '--short', 'HEAD').strip()}"
      f" | origin {git('rev-parse', '--short', 'origin/bank-derate-cos2p65').strip()}")

DRAFT = "docs/reporting/drafts/2026-10-08-report-first-draft.md"
NOTE = "docs/agents/physics-topology.md"
TRACKER = "docs/reporting/draft-tracker.md"
CAND = "docs/reporting/glossary-candidates.md"
REG = "docs/reporting/numbers-register.md"
FIGS = "docs/reporting/figures/"

# ── A. the draft ─────────────────────────────────────────────────────────
print("\n== A. the draft ==")
d = rd(DRAFT)
chk("draft: old form zero (raw substring)", d.lower().count("hub") == 0,
    f"raw={d.lower().count('hub')}")
chk("draft: old form zero (word)", len(HUB.findall(d)) == 0)
chk("draft: reads v0.47", "Draft v0.47" in d)
t_lines = [i for i, ln in enumerate(d.splitlines(), 1) if re.search("topmost", ln, re.I)]
chk("draft: topmost at the nine pinned lines", t_lines == [212, 225, 490, 505, 571, 612, 689, 786, 794],
    str(t_lines))
for s in [
    "The topmost ring carries the main rotor.",
    "topmost-ring and ground radii",
    "The top-segment helix force reads about 1278 N/vertex (NR-048).",
    "The capture topmost ring",
    "reads 15.033 at the final step (NR-021).",
    "| Topmost ring radius | 4.580 m | NR-011 |",
    "topmost ring radius is 4.580 metres and the ground radius 0.804 metres",
    "The topmost rotor ring R6 governs the structural check at the winner operating point (NR-021).",
    "The topmost ring radius is 4.580 m and the ground radius is 0.804 m.",
    "The middle rotor landed on the topmost ring.",
    "the topmost ring (2026-08-26)",
    "one ring toward the top",
]:
    pin(DRAFT, s)
pin(DRAFT, "The search found 508 feasible candidates in the searched space (NR-002).")
pin(DRAFT, "The best performing one had a mean power of 5.309 kW.")
pin(DRAFT, "Its airborne mass is 25.698 kilograms (NR-008, NR-018).")
pin(DRAFT, "### 3.4 The levers of Performance")
block = "\n".join(d.splitlines()[855:880])
chk("draft: the conclusion block carries no reject split",
    not re.search(r"reject|301|110|422", block, re.I))
added = [l for l in git("diff", "d0ed902^..d0ed902", "--", DRAFT).splitlines()
         if l.startswith("+") and not l.startswith("+++")]
chk("draft: the fold added no reject-split text",
    not any(re.search(r"reject|301|110", l, re.I) for l in added),
    f"{len(added)} added lines")

# ── B. the note ──────────────────────────────────────────────────────────
print("\n== B. the note (physics-topology) ==")
pin(NOTE, 'Do not write "hub rotor". The word "hub" does not name the ring either.')
pin(NOTE, "The part reads **topmost ring**, or **topmost rotor ring** in full (Rod, 2026-10-14).")
pin(NOTE, "The code identifiers (`r_hub`) and the recorded pages hold their spelling.")
pin(NOTE, "| **hub** | a retired name. Say **main rotor** if you mean the topmost rotor, and **topmost ring** if you mean the ring at the top.")
nl = [i for i, _ in hub_lines(NOTE)]
allowed_note = [165, 202, 230, 232, 265, 288, 331, 332, 339, 395, 523, 543]
chk("note: old form confined to the enumerated set", nl == allowed_note, str(nl))
for i, ln in hub_lines(NOTE):
    print(f"      [{i}] {ln[:100]}")

# ── C. the plates and the kits ───────────────────────────────────────────
print("\n== C. the plates and the kits ==")
KITS = {
    "system-anatomy": FIGS + "system-anatomy/",
    "ring-utilisation": FIGS + "ring-utilisation/",
    "twist-limit": FIGS + "twist-limit/",
    "eval-timeline": FIGS + "eval-timeline/",
    "machine-winner-hero": FIGS + "machine-winner-hero/",
    "machine-evolution-strip": FIGS + "machine-evolution-strip/",
}
detected = 0
for kit, base in KITS.items():
    for f in sorted(os.listdir(base)):
        if f.endswith((".svg", ".tex")):
            detected += 1
            p = base + f
            chk(f"art[{kit}/{f}]: old form zero", len(HUB.findall(rd(p))) == 0,
                f"{len(HUB.findall(rd(p)))} hits")
chk("art: the delivered art files read (count)", detected >= 5, str(detected))
pin(FIGS + "system-anatomy/system-anatomy.tex", "R6, the topmost ring")
pin(FIGS + "system-anatomy/label-ledger.txt", "R6, the topmost ring")
pin(FIGS + "ring-utilisation/ring-utilisation.svg", "R6 (top)")
pin(FIGS + "ring-utilisation/captions.md", "The topmost rotor ring R6 governs the structural check at FoS 15.033.")
pin(FIGS + "twist-limit/twist-limit.svg", "ground to top")
pin(FIGS + "twist-limit/captions.md", '"R6 (top)"')
pin(FIGS + "eval-timeline/eval-timeline.svg", "ω top")
pin(FIGS + "eval-timeline/eval-timeline.svg", "top · tip · Betz")
pin(FIGS + "machine-winner-hero/machine-winner-hero.jl", "topmost ring R6")
pin(FIGS + "machine-winner-hero/machine-winner-hero.jl", "drawn topmost-ring altitude")
pin(FIGS + "machine-evolution-strip/captions.md", "topmost ring radius 4.580 m")
# residue allowlist: (file, line) -> class
kit_allow = {
    (FIGS + "system-anatomy/checks.log", 5): "record",
    (FIGS + "system-anatomy/system-anatomy.py", 21): "record",
    (FIGS + "system-anatomy/captions.md", 96): "record",
    (FIGS + "system-anatomy/register-status.md", 63): "record",
    (FIGS + "system-anatomy/SPEC.md", 111): "record",
    (FIGS + "ring-utilisation/ring-utilisation.py", 15): "record",
    (FIGS + "ring-utilisation/captions.md", 97): "record",
    (FIGS + "ring-utilisation/register-status.md", 43): "record",
    (FIGS + "ring-utilisation/SPEC.md", 269): "record",
    (FIGS + "twist-limit/twist-limit.py", 17): "record",
    (FIGS + "twist-limit/captions.md", 89): "record",
    (FIGS + "twist-limit/register-status.md", 53): "record",
    (FIGS + "twist-limit/SPEC.md", 266): "record",
    (FIGS + "eval-timeline/eval-timeline.py", 10): "form-note",
    (FIGS + "eval-timeline/eval-timeline.py", 21): "record",
    (FIGS + "eval-timeline/register-status.md", 69): "record",
    (FIGS + "eval-timeline/SPEC.md", 184): "record",
    (FIGS + "machine-winner-hero/machine-winner-hero.jl", 17): "record",
    (FIGS + "machine-winner-hero/machine-winner-hero.jl", 208): "form-note",
    (FIGS + "machine-winner-hero/machine-winner-hero.jl", 371): "form-note",
    (FIGS + "machine-winner-hero/machine-winner-hero.jl", 398): "form-note",
    (FIGS + "machine-winner-hero/machine-winner-hero.jl", 492): "form-note",
    (FIGS + "machine-winner-hero/register-status.md", 74): "record",
    (FIGS + "machine-evolution-strip/captions.md", 86): "record",
    (FIGS + "machine-evolution-strip/register-status.md", 83): "record",
}
kit_unlisted = []
for (f, ln) in kit_allow:
    if not os.path.exists(f) or ln > len(rd(f).splitlines()):
        kit_unlisted.append(f"{f}:{ln} missing")
for kit, base in KITS.items():
    for f in sorted(os.listdir(base)):
        if f.endswith((".md", ".py", ".jl", ".log")):
            p = base + f
            for i, ln in hub_lines(p):
                if (p, i) not in kit_allow:
                    kit_unlisted.append(f"{p}:{i}")
chk("kits: every residue line enumerated", not kit_unlisted, str(kit_unlisted[:6]))
rec = sum(1 for v in kit_allow.values() if v == "record")
fn = sum(1 for v in kit_allow.values() if v == "form-note")
print(f"      kit residue: {rec} record lines, {fn} form-note lines (listed in the receipt)")

# ── D. the tracker, the candidates and the stale-phrases list ────────────
print("\n== D. the tracker, the candidates and the stale-phrases list ==")
SP = "docs/agents/stale-phrases.md"
tl = [i for i, _ in hub_lines(TRACKER)]
cl = [i for i, _ in hub_lines(CAND)]
sl = [i for i, _ in hub_lines(SP)]
pin(TRACKER, "v0.47 pass by @author")
pin(TRACKER, "The topmost-ring rename lands at the ten draft sites")
pin(CAND, 'Never write "hub rotor"')
pin(CAND, '"hub rotor", or "hub" for a rotor')
chk("tracker: pending leg enumerated (2 sites)", tl == [104, 165], str(tl))
chk("candidates: pending leg enumerated (2 sites)", cl == [78, 262], str(cl))
chk("stale-phrases: pending leg enumerated (4 sites)", sl == [63, 68, 78, 80], str(sl))
for i, ln in hub_lines(TRACKER) + hub_lines(CAND) + hub_lines(SP):
    print(f"      [pending] {ln[:104]}")
ggl = [i for i, _ in hub_lines("docs/agents/genome-glossary.md")]
print(f"      [glossary note] docs/agents/genome-glossary.md hub lines: {ggl} "
      "(rule blockquote + gene rows; not in the routed set)")

# ── E. the tracked-tree census ───────────────────────────────────────────
print("\n== E. the tracked-tree census ==")
out = git("grep", "-n", "-I", "-i", "-P", r"\bhub\b", "--", ".")
hits = {}
for line in out.splitlines():
    parts = line.split(":", 2)
    if len(parts) == 3:
        hits.setdefault(parts[0], []).append(int(parts[1]))

EXEMPT = set()
for line in rd(".ste-exempt").splitlines():
    line = line.strip()
    if line and not line.startswith("#"):
        EXEMPT.add(line)
EXEMPT.add("DECISIONS.md")


def classify(p):
    if p == "docs/agents/stale-phrases.md":
        return "pending-leg"
    if p in (DRAFT, NOTE, TRACKER, CAND):
        return "live-checked"
    if p == REG:
        return "register"
    if p in EXEMPT:
        return "exempt-verbatim"
    if p.startswith(FIGS):
        rel = p[len(FIGS):]
        if rel == "figure-map.md":
            return "map-ledger"
        if rel == "figure-generation-notes.md":
            return "exempt-verbatim"
        if rel == "2026-10-12-nine-figure-proposals.md":
            return "received-brief"
        if rel.startswith(("pair-extract/", "window-trace-extract/", "eval-timeline-extract/",
                           "lever-statistics-extract/", "k-basis/", "pca-landscape/",
                           "pca-atlas/")):
            return "extract-records"
        return "kit-records"
    if p.startswith(("src/", "scripts/", "test/")) or p.endswith((".jl", ".py")):
        return "code-vocabulary"
    if p.startswith(("scratch/", "docs/reporting/room-responses/", "handovers/",
                     "docs/plans/", "docs/validation/", "docs/reporting/feedback/",
                     "docs/awes-forum-diagrams/", "docs/reporting/drafts/",
                     ".hermes/", ".superpowers/", ".video/", "references/", "reviews/")):
        return "records-evidence"
    if "/" not in p:
        return "records-evidence"
    if p.startswith(("docs/", "handovers/")):
        return "records-evidence"
    return "UNCLASSIFIED"


classes = Counter()
unclassified = []
for p in sorted(hits):
    cl = classify(p)
    classes[cl] += 1
    if cl == "UNCLASSIFIED":
        unclassified.append(p)
        print(f"  [UNCLASSIFIED] {p}: {len(hits[p])}")
total = sum(len(v) for v in hits.values())
print(f"  total: {total} matching lines across {len(hits)} files")
for cl in sorted(classes):
    no = sum(len(hits[p]) for p in hits if classify(p) == cl)
    print(f"    {cl}: {classes[cl]} files, {no} lines")
for p in sorted(hits):
    cl = classify(p)
    if cl in ("records-evidence", "map-ledger", "received-brief", "extract-records",
              "kit-records", "exempt-verbatim", "pending-leg", "register"):
        print(f"  [{cl}] {p}: {len(hits[p])}")
chk("census: zero unclassified files", not unclassified, str(unclassified[:4]))

# ── F. the working set ───────────────────────────────────────────────────
print("\n== F. the working set ==")
unt_hits = {}
for p in git("ls-files", "--others", "--exclude-standard").splitlines():
    fp = os.path.join(ROOT, p)
    try:
        if os.path.getsize(fp) > 2000000:
            continue
        t = open(fp, encoding="utf-8", errors="ignore").read()
    except OSError:
        continue
    n = len(HUB.findall(t))
    if n:
        unt_hits[p] = n
unt_bad = []
for p in sorted(unt_hits):
    cl = ("working-snapshot" if p.startswith("scratch/") else
          "records" if p.startswith(("docs/plans/", "docs/reporting/", "docs/", "scripts/results/")) else
          "UNCLASSIFIED")
    print(f"  [{cl}] {p}: {unt_hits[p]}")
    if cl == "UNCLASSIFIED":
        unt_bad.append(p)
chk("working set: every residue classified", not unt_bad, str(unt_bad[:4]))

# ── G. the register ──────────────────────────────────────────────────────
print("\n== G. the register ==")
reg_ln = [i for i, _ in hub_lines(REG)]
reg_occ = len(HUB.findall(rd(REG)))
chk("register: old form holds its spelling (21 lines / 22 sites)",
    reg_ln == [249, 328, 367, 520, 521, 536, 583, 592, 609, 618, 622, 624, 669, 670, 716,
               1231, 1282, 1537, 1541, 1561, 1682] and reg_occ == 22,
    f"{len(reg_ln)} lines / {reg_occ} occurrences")
stat = git("diff", "--numstat", "cb862df", "HEAD", "--", REG).strip()
removed = int(stat.split("\t")[1]) if stat else 0
chk("register: append-only since cb862df (zero removals)", removed == 0, stat or "no diff")
chk("register: carries NR-051", "NR-051" in rd(REG))

# ── H. the delivered copy (informational) ────────────────────────────────
print("\n== H. the delivered copy ==")
docx = "scratch/report-pdf-build/draft-live.docx"
if os.path.exists(docx):
    md5 = hashlib.md5(open(docx, "rb").read()).hexdigest()
    with zipfile.ZipFile(docx) as z:
        xml = z.read("word/document.xml").decode("utf-8", "ignore")
    text = re.sub(r"<[^>]+>", "", xml.replace("</w:p>", "</w:p>\n"))
    n_hub = len(HUB.findall(text))
    n_top = len(re.findall("topmost ring", text, re.I))
    print(f"  draft-live.docx: md5 {md5}; old form {n_hub}; 'topmost ring' {n_top}")
    print("  (the round-6 rebuild follows the folds; this read keys it)")

print(f"\nCHECKER: {n_ck} checks, {n_fail} fail")
if n_fail:
    print("SV_R6_TERMGATE_FAIL")
    sys.exit(1)
print("SV_R6_TERMGATE_DONE  (the fold reads the signed forms; old form zero on the live "
      "surfaces; residue classified; legs enumerated)")

#!/usr/bin/env python3
# scratch/sv_r6_term_gate_v2_check.py — science-validator, 2026-10-15.
#
# The round-6 term gate, second read — at the closure tip e6122a2:
# the writer's naming legs, the figures fold-back with the recorded form-note
# hold, the author's v0.47 rebuild and the aero counter-reads have landed.
# Re-reads the v1 checks against the closed set and adds the closure checks:
#   A. The draft and the note: unchanged since d0ed902; the v1 pins hold.
#   B. The plates and the kits: art zero; pins; the five form notes hold, recorded.
#   C. The writer's legs: tracker zero; the candidates ban-quotes; the stale-phrases record.
#   D. The corner extract: the NR-051 picks and objectives re-read.
#   E. The delivered copy: v0.47 build; the retired word at the appendix holds only.
#   F. The tracked-tree census; G. the working set; H. the register.
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
    return subprocess.run(["git"] + list(args), capture_output=True, text=True).stdout


def pin(rel, s, label=None):
    chk(label or f"pin[{os.path.basename(rel)}]: {s[:72]!r}", s in rd(rel))


TIP = git("rev-parse", "--short", "HEAD").strip()
ORG = git("rev-parse", "--short", "origin/bank-derate-cos2p65").strip()
print(f"sv_r6_term_gate_v2_check — read at HEAD {TIP} | origin {ORG}")
chk("tip: read at the closure tip e6122a2", TIP == "e6122a2", TIP)

DRAFT = "docs/reporting/drafts/2026-10-08-report-first-draft.md"
NOTE = "docs/agents/physics-topology.md"
TRACKER = "docs/reporting/draft-tracker.md"
CAND = "docs/reporting/glossary-candidates.md"
SP = "docs/agents/stale-phrases.md"
REG = "docs/reporting/numbers-register.md"
FIGS = "docs/reporting/figures/"

# ── A. the draft and the note ────────────────────────────────────────────
print("\n== A. the draft and the note ==")
d = rd(DRAFT)
chk("draft: old form zero (raw and word)",
    d.lower().count("hub") == 0 and len(HUB.findall(d)) == 0)
chk("draft: reads v0.47", "Draft v0.47" in d)
t_lines = [i for i, ln in enumerate(d.splitlines(), 1) if re.search("topmost", ln, re.I)]
chk("draft: topmost at the nine pinned lines", t_lines == [212, 225, 490, 505, 571, 612, 689, 786, 794],
    str(t_lines))
for s in [
    "The topmost ring carries the main rotor.",
    "topmost-ring and ground radii",
    "The top-segment helix force reads about 1278 N/vertex (NR-048).",
    "The capture topmost ring",
    "| Topmost ring radius | 4.580 m | NR-011 |",
    "The topmost rotor ring R6 governs the structural check at the winner operating point (NR-021).",
    "The topmost ring radius is 4.580 m and the ground radius is 0.804 m.",
    "The middle rotor landed on the topmost ring.",
    "one ring toward the top",
    "The search found 508 feasible candidates in the searched space (NR-002).",
    "The best performing one had a mean power of 5.309 kW.",
    "Its airborne mass is 25.698 kilograms (NR-008, NR-018).",
    "### 3.4 The levers of Performance",
]:
    pin(DRAFT, s)
pin(NOTE, 'Do not write "hub rotor". The word "hub" does not name the ring either.')
pin(NOTE, "The part reads **topmost ring**, or **topmost rotor ring** in full (Rod, 2026-10-14).")
nl = [i for i, _ in hub_lines(NOTE)]
chk("note: old form confined to the enumerated set",
    nl == [165, 202, 230, 232, 265, 288, 331, 332, 339, 395, 523, 543], str(nl))
unchanged = git("diff", "--stat", "d0ed902..HEAD", "--", DRAFT, NOTE).strip()
chk("draft and note: no change since d0ed902", unchanged == "", unchanged[:120])

# ── B. the plates and the kits ───────────────────────────────────────────
print("\n== B. the plates and the kits ==")
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
            chk(f"art[{kit}/{f}]: old form zero", len(HUB.findall(rd(base + f))) == 0)
chk("art: the delivered art files read (count)", detected >= 5, str(detected))
pin(FIGS + "system-anatomy/system-anatomy.tex", "R6, the topmost ring")
pin(FIGS + "ring-utilisation/captions.md", "The topmost rotor ring R6 governs the structural check at FoS 15.033.")
pin(FIGS + "twist-limit/twist-limit.svg", "ground to top")
pin(FIGS + "eval-timeline/eval-timeline.svg", "ω top")
pin(FIGS + "machine-winner-hero/machine-winner-hero.jl", "topmost ring R6")
pin(FIGS + "machine-evolution-strip/captions.md", "topmost ring radius 4.580 m")
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
    (FIGS + "eval-timeline/eval-timeline.py", 10): "held",
    (FIGS + "eval-timeline/eval-timeline.py", 21): "record",
    (FIGS + "eval-timeline/register-status.md", 69): "record",
    (FIGS + "eval-timeline/SPEC.md", 184): "record",
    (FIGS + "machine-winner-hero/machine-winner-hero.jl", 17): "record",
    (FIGS + "machine-winner-hero/machine-winner-hero.jl", 208): "held",
    (FIGS + "machine-winner-hero/machine-winner-hero.jl", 371): "held",
    (FIGS + "machine-winner-hero/machine-winner-hero.jl", 398): "held",
    (FIGS + "machine-winner-hero/machine-winner-hero.jl", 492): "held",
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
held = sum(1 for v in kit_allow.values() if v == "held")
chk("kits: the five form notes hold", held == 5, str(held))
pin(FIGS + "figure-map.md", "The five generator comment form notes hold")
pin(FIGS + "figure-map.md", "v38 (2026-10-15)")
pin(FIGS + "eval-timeline/register-status.md", "**Form note** (2026-10-15): one script comment at the head holds")
pin(FIGS + "machine-winner-hero/register-status.md", "**Form note** (2026-10-15): four script comments hold the old ring")

# ── C. the writer's legs ─────────────────────────────────────────────────
print("\n== C. the writer's legs ==")
chk("tracker: old form zero (raw and word)",
    rd(TRACKER).lower().count("hub") == 0 and len(HUB.findall(rd(TRACKER))) == 0)
pin(TRACKER, "the capture topmost ring reads 15.033 at the final step (NR-021).")
pin(TRACKER, "the capture topmost ring reading keeps its form.")
cl = [i for i, _ in hub_lines(CAND)]
chk("candidates: old form at the ban-quote set only", cl == [77, 79, 263, 370], str(cl))
pin(CAND, 'Never write "hub rotor" or "hub ring".')
pin(CAND, '"hub rotor", or "hub" for a rotor or the ring')
pin(CAND, "| topmost ring | The ring at the top of the TRPT.")
pin(CAND, "the hub-name retirement re-keys the ring pair")
sl = [i for i, _ in hub_lines(SP)]
chk("stale-phrases: old form at the ban entry only", sl == [78, 80], str(sl))
pin(SP, "## The topmost ring hosts ONLY the cp/ct rotor")
pin(SP, "the decoder's topmost rotor")
pin(SP, 'is not a rotor term, and it does not name the ring')
pin(SP, 'Note (2026-10-14): the part reads "topmost ring", or "topmost rotor ring" in full')
for i, ln in hub_lines(CAND) + hub_lines(SP):
    print(f"      [ban-quote] {ln[:104]}")

# ── D. the corner extract ────────────────────────────────────────────────
print("\n== D. the corner extract ==")
CG = FIGS + "machine-corner-grid/extract-corner-grid.csv"
for s in ["i1-g13-i1", "i1-g7-i7", "i2-g21-i4", "i3-g26-i8",
          "60.646", "58.864", "33.704", "33.812"]:
    pin(CG, s, label=f"corner extract: {s} re-reads")
chk("corner extract: old form absent", len(HUB.findall(rd(CG))) == 0)

# ── E. the delivered copy ────────────────────────────────────────────────
print("\n== E. the delivered copy ==")
docx = "scratch/report-pdf-build/draft-live.docx"
md5 = hashlib.md5(open(docx, "rb").read()).hexdigest()
chk("copy: md5 reads the delivered build", md5 == "1115a2019872ad10929941d4baeb67a6", md5)
with zipfile.ZipFile(docx) as z:
    xml = z.read("word/document.xml").decode("utf-8", "ignore")
text = re.sub(r"<[^>]+>", "", xml.replace("</w:p>", "</w:p>\n"))
nh = len(HUB.findall(text))
chk("copy: retired word reads 5", nh == 5, str(nh))
asm = "scratch/report-pdf-build/draft-assembled-docx.md"
asm_lines = rd(asm).splitlines()
asm_hub = [(i + 1, ln) for i, ln in enumerate(asm_lines) if HUB.search(ln)]
ids = sorted({m.group(1) for _, ln in asm_hub for m in [re.search(r"(NR-\d{3})", ln)] if m})
chk("copy: every retired-word line is a register row",
    len(asm_hub) == 4 and all(ln.lstrip().startswith("| NR-") for _, ln in asm_hub),
    str([i for i, _ in asm_hub]))
chk("copy: the rows read NR-021, NR-030, NR-032, NR-048",
    ids == ["NR-021", "NR-030", "NR-032", "NR-048"], str(ids))
occ = sum(len(HUB.findall(ln)) for _, ln in asm_hub)
chk("copy: five occurrences across the four rows", occ == 5, str(occ))
chk("copy: 508 feasible reads once", len(re.findall("508 feasible", text)) == 1)
chk("copy: reads v0.47", "v0.47" in text)
ntop = len(re.findall("topmost", text, re.I))
chk("copy: topmost reads 13 (body and captions)", ntop == 13, str(ntop))
old = "scratch/report-pdf-build/draft-34e3f81-20261014-204106.docx"
if os.path.exists(old):
    with zipfile.ZipFile(old) as z:
        ox = z.read("word/document.xml").decode("utf-8", "ignore")
    ot = re.sub(r"<[^>]+>", "", ox.replace("</w:p>", "</w:p>\n"))
    ci, cs = len(re.findall(r"\bhub\b", ot, re.I)), len(re.findall(r"\bhub\b", ot))
    chk("copy: the held build reconciles (20 case-insens / 19 case-sens)", ci == 20 and cs == 19,
        f"ci={ci} cs={cs}")
    print("      the one difference is the winner-table 'Hub' (capitalised): the founder-copy count")
else:
    print("      (the held build archive is absent; reconciliation recorded in the receipt)")

# ── F. the tracked-tree census ───────────────────────────────────────────
print("\n== F. the tracked-tree census ==")
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
    if p in (SP,):
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
                           "lever-statistics-extract/", "k-basis/", "pca-landscape/", "pca-atlas/")):
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
chk("census: zero unclassified files", not unclassified, str(unclassified[:4]))

# ── G. the working set ───────────────────────────────────────────────────
print("\n== G. the working set ==")
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

# ── H. the register ──────────────────────────────────────────────────────
print("\n== H. the register ==")
reg_ln = [i for i, _ in hub_lines(REG)]
chk("register: old form holds (21 lines / 22 sites)", len(reg_ln) == 21, f"{len(reg_ln)} lines")
stat = git("diff", "--numstat", "cb862df", "HEAD", "--", REG).strip()
chk("register: unchanged since cb862df", stat == "", stat or "no diff")
chk("register: carries NR-051", "NR-051" in rd(REG))

print(f"\nCHECKER: {n_ck} checks, {n_fail} fail")
if n_fail:
    print("SV_R6_TERMGATE_V2_FAIL")
    sys.exit(1)
print("SV_R6_TERMGATE_V2_DONE  (the gate re-reads on the closed set: legs closed, the hold "
      "recorded, the copy at the appendix holds only)")

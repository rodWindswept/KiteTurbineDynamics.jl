#!/usr/bin/env python3
# scratch/sv_br_term_gate_check.py — science-validator, 2026-10-15.
#
# The lifting-bridles term gate re-read at the closure: the figures relabel
# (9241b23/6f19eee), the corner cite closes, the author v0.49 re-keys and the
# writer's term set + sweep 31 have landed on 459eee2; this packet closes the
# gate's two parked one-word flips (figure notes L23, captions-draft L43) and
# lands the two dated reader-name amends (physics-topology section 2, domain
# item 8). CONTEXT.md and the register hold (scope call).
# Sections:
#   A. the closure basis and the working set
#   B. the drawn set (F1 kit) and its pins
#   C. the draft v0.49 and its appendix hash cells
#   D. the delivered copy (v0.49 build)
#   E. the writer's term set
#   F. the desk docs, the flips and the scope calls
#   G. the corner cites and the map
#   H. the tracked-tree census (bridle and hero), every residue classified
# Prints one line per check; exits nonzero on any fail.
import hashlib
import os
import re
import subprocess
import sys
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)

BASIS = "459eee2"          # the tip this read builds on (closure basis)
BRANCH = "bank-derate-cos2p65"

# bad = a bridle word not carried by "lifting": bare member reads, code words,
# ban quotes, held engineering spelling. Two lookbehinds cover "lifting " and
# "lifting-".
BAD = re.compile(r"(?<!lifting )(?<!lifting-)\bbridle", re.I)
OLD_LABEL = re.compile(r"(?<!lifting )bridles \(three\)")

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


def rb(rel):
    with open(os.path.join(ROOT, rel), "rb") as f:
        return f.read()


def git(*args):
    return subprocess.run(["git"] + list(args), capture_output=True, text=True).stdout


def badlines(rel):
    return [i for i, ln in enumerate(rd(rel).splitlines(), 1) if BAD.search(ln)]


def pin(rel, s, label=None):
    chk(label or f"pin[{os.path.basename(rel)}]: {s[:70]!r}", s in rd(rel))


HEAD = git("rev-parse", "HEAD").strip()
anc = subprocess.run(["git", "merge-base", "--is-ancestor", BASIS, "HEAD"]).returncode
print(f"sv_br_term_gate_check — read at HEAD {HEAD[:9]} | basis {BASIS}")
chk("A0: the read builds on the closure tip 459eee2", anc == 0)

FIGS = "docs/reporting/figures/system-anatomy/"
DRAFT = "docs/reporting/drafts/2026-10-08-report-first-draft.md"
CAND = "docs/reporting/glossary-candidates.md"
SP = "docs/agents/stale-phrases.md"
NOTES = "docs/reporting/figures/figure-generation-notes.md"
PT = "docs/agents/physics-topology.md"
DOM = "docs/agents/domain.md"
CTX = "CONTEXT.md"
REG = "docs/reporting/numbers-register.md"
MAP = "docs/reporting/figures/figure-map.md"
TRK = "docs/reporting/draft-tracker.md"
CORNER = "docs/reporting/figures/machine-corner-grid/register-status.md"
RSPEC = "docs/reporting/figures/machine-renderer/SPEC.md"
ELEM = "docs/reporting/figures/elements/ktd-fig-elements.tex"
WIN = "docs/reporting/figures/machine-winner-hero/"
COPY = "scratch/report-pdf-build/draft-live.docx"
ASSEMBLED = "scratch/report-pdf-build/draft-assembled-docx.md"

# ── A. the working set ───────────────────────────────────────────────────
print("\n== A. the closure basis and the working set ==")
EDITED = {NOTES, FIGS + "captions-draft.md", PT, DOM}
WATCH = [
    FIGS + "system-anatomy.py", FIGS + "system-anatomy.tex", FIGS + "system-anatomy.pdf",
    FIGS + "system-anatomy.png", FIGS + "prototype.html", FIGS + "label-ledger.txt",
    FIGS + "captions.md", FIGS + "SPEC.md", FIGS + "manifest.json", FIGS + "checks.log",
    FIGS + "register-status.md", DRAFT, CAND, SP, REG, MAP, TRK, CORNER, RSPEC, ELEM,
    CTX, "docs/reporting/draft-consistency-sweep.md",
]
dirty = [p for p in git("status", "--porcelain", "--", *WATCH).splitlines() if p.strip()]
chk("A1: the watched files are tree-clean (no peer mid-write)", dirty == [], str(dirty[:4]))
edited_dirty = [p for p in git("status", "--porcelain", "--", *sorted(EDITED)).splitlines() if p.strip()]
chk("A2: the four gate edits read as working-tree modifications", len(edited_dirty) == 4, f"{len(edited_dirty)}")

# ── B. the drawn set and its pins ────────────────────────────────────────
print("\n== B. the drawn set (F1 kit) and its pins ==")
py = rd(FIGS + "system-anatomy.py")
chk("B1: py label dict reads the founder form", 'lines=["lifting bridles (three)"]' in py)
chk("B2: py keeps the internal label id", 'name="bridles"' in py)
chk("B3: py old drawn label zero", len(OLD_LABEL.findall(py)) == 0)
chk("B4: py header carries the v7 note", "v7 re-cut (2026-10-15): the lifting-bridles relabel" in py)
tx = rd(FIGS + "system-anatomy.tex")
chk("B5: tex drawn string", "{lifting bridles (three)}" in tx and len(OLD_LABEL.findall(tx)) == 0)
pr = rd(FIGS + "prototype.html")
chk("B6: prototype drawn string", ">lifting bridles (three)<" in pr and len(OLD_LABEL.findall(pr)) == 0)
lg = rd(FIGS + "label-ledger.txt").splitlines()
chk("B7: ledger row + count", lg.count("lifting bridles (three)") == 1 and len(lg) == 34)
led_old = [i for i, ln in enumerate(lg, 1) if OLD_LABEL.search(ln)]
chk("B8: ledger old form zero", led_old == [])
kit = ["system-anatomy.py", "system-anatomy.tex", "prototype.html", "label-ledger.txt",
       "captions.md", "captions-draft.md", "SPEC.md", "manifest.json", "checks.log", "register-status.md"]
old_any = []
for k in kit:
    if OLD_LABEL.search(rd(FIGS + k)):
        old_any.append(k)
chk("B9: kit-wide old drawn label zero", old_any == [], str(old_any))
cap = rd(FIGS + "captions.md")
chk("B10: captions.md reads the caption form", "Three lifting bridles run" in cap)
chk("B11: captions.md old caption zero", "Three bridles" not in cap)
chk("B12: captions.md relabel note", "Relabel note (2026-10-15): the lifting-bridles relabel" in cap)
chk("B13: captions.md bad lines zero", badlines(FIGS + "captions.md") == [])
cd = rd(FIGS + "captions-draft.md")
chk("B14: captions-draft caption form", "Three lifting bridles run from" in cd)
chk("B15: captions-draft L23/L43 allowlist", badlines(FIGS + "captions-draft.md") == [])
chk("B16: captions-draft ledger list flipped", "lifting bridles, main rotor, ground ring, topmost ring" in cd)
spec = rd(FIGS + "SPEC.md")
chk("B17: SPEC load-path form", "lift bearing, lifting bridles," in spec)
chk("B18: SPEC relabel note", "The lifting-bridles relabel (2026-10-15)" in spec)
chk("B19: SPEC bad lines zero", badlines(FIGS + "SPEC.md") == [])
man = rd(FIGS + "manifest.json")
chk("B20: manifest script commit", '"script_commit": "9241b23"' in man)
sha = lambda b: hashlib.sha256(b).hexdigest()
md5 = lambda b: hashlib.md5(b).hexdigest()
blobs = {k: rb(FIGS + k) for k in ["checks.log", "label-ledger.txt", "system-anatomy.pdf",
                                   "system-anatomy.png", "system-anatomy.tex", "system-anatomy.py", "prototype.html"]}
for k, label in [("checks.log", "checks.log"), ("label-ledger.txt", "ledger"),
                 ("system-anatomy.pdf", "pdf"), ("system-anatomy.png", "png"), ("system-anatomy.tex", "tex")]:
    chk(f"B21: manifest sha256[{label}] recomputes", f'"{k}": "{sha(blobs[k])}"' in man)
chk("B22: manifest script sha256 recomputes", sha(blobs["system-anatomy.py"]) in man)
cl = rd(FIGS + "checks.log")
chk("B23: checks.log v7 block", "re-cut v7: the lifting-bridles relabel" in cl and "lifting bridles (three)" in cl)
for k, label in [("system-anatomy.tex", "tex"), ("prototype.html", "prototype"), ("label-ledger.txt", "ledger"),
                 ("system-anatomy.pdf", "pdf"), ("system-anatomy.png", "png")]:
    chk(f"B24: checks.log md5[{label}] recomputes", md5(blobs[k]) in cl)
rs = rd(FIGS + "register-status.md")
chk("B25: register-status v7 + delta v5", "v7 (2026-10-15): the lifting-bridles relabel" in rs and "**Delta** v5 (2026-10-15): the v7 re-cut lands" in rs)
chk("B26: register-status reads 9241b23", "Script commit `9241b23`" in rs or "Script\ncommit `9241b23`" in rs)

# ── C. the draft v0.49 and its appendix hash cells ───────────────────────
print("\n== C. the draft v0.49 ==")
d = rd(DRAFT)
dl = d.splitlines()
chk("C1: draft pin v0.49", dl[2] == "Internal engineering report. Draft v0.49. Date 2026-10-15.")
chk("C2: draft lift-path sentence", "down the lifting bridles to the main rotor." in dl[538])
chk("C3: draft winner marker", "(machine winner, slug `machine-winner-hero`)" in dl[483])
chk("C4: draft appendix exhibit row", dl[945].startswith("| Machine winner |"))
chk("C5: draft caption lead", dl[993] == "Machine winner:")
chk("C6: draft holds stand", "outer stiffening bridles" in dl[45] and "like a tether or a bridle" in dl[189] and "tether-to-blade bridling" in dl[847])
chk("C7: draft bad lines == the three holds", badlines(DRAFT) == [46, 190], str(badlines(DRAFT)))
chk("C8: draft old caption/sentence zero", "down the bridles" not in d and "Three bridles" not in d)
chk("C9: draft hero forms zero", "Machine winner hero" not in d and "hero image" not in d)
hl = [i for i, ln in enumerate(dl, 1) if re.search("hero", ln, re.I)]
chk("C10: draft hero reads one line (the slug)", hl == [484], str(hl))
chk("C11: draft SA appendix script cell", "| System anatomy plate |" in dl[942] and "`9241b23`" in dl[942])
for k, label in [("png", "png"), ("pdf", "pdf"), ("ledger", "ledger"), ("checks", "checks")]:
    src = {"png": FIGS + "system-anatomy.png", "pdf": FIGS + "system-anatomy.pdf",
           "ledger": FIGS + "label-ledger.txt", "checks": FIGS + "checks.log"}[k]
    chk(f"C12: draft SA hash cell [{label}] == delivered bytes", f"- `{k}` `{sha(rb(src))}`" in d)

# ── D. the delivered copy ────────────────────────────────────────────────
print("\n== D. the delivered copy (v0.49) ==")
cb = rb(COPY)
chk("D1: copy md5", md5(cb) == "24f98df65d7274233bfea9cc9e736937", md5(cb))
xml = zipfile.ZipFile(os.path.join(ROOT, COPY)).read("word/document.xml").decode("utf-8")
txt = " ".join(re.sub(r"<[^>]+>", " ", x) for x in re.split(r"</w:p>", xml))
txt = re.sub(r"\s+", " ", txt)
cnt = lambda p, fl=0: len(re.findall(re.escape(p), txt, fl))
chk("D2: copy v0.49 once", cnt("v0.49") == 1)
chk("D3: copy caption form once", cnt("Three lifting bridles") == 1)
chk("D4: copy lift-path form once", cnt("down the lifting bridles") == 1)
chk("D5: copy reads the member twice", cnt("lifting bridles") == 2)
chk("D6: copy winner form twice", cnt("Machine winner") == 2)
chk("D7: copy old forms zero", cnt("Three bridles") == 0 and cnt("down the bridles") == 0 and cnt("Machine winner hero") == 0 and cnt("hero image") == 0)
hm = list(re.finditer(r"hero", txt, re.I))
hwin = [txt[max(0, m.start() - 40):m.end() + 40] for m in hm]
chk("D8: copy hero == 3, all windows hold the slug", len(hm) == 3 and all("machine-winner-hero" in c for c in hwin), str(len(hm)))
chk("D9: copy hold senses stand", cnt("stiffening bridles") == 1 and cnt("a tether or a bridle") == 1 and cnt("bridling") == 2 and cnt("unbridled") == 1)
am = rd(ASSEMBLED)
ahl = [i for i, ln in enumerate(am.splitlines(), 1) if re.search("hero", ln, re.I)]
chk("D10: assembled md hero lines are the slug lines", ahl == [494, 496, 1125], str(ahl))
chk("D11: assembled md winner-form lines in the appendix", [i for i, ln in enumerate(am.splitlines(), 1) if "Machine winner" in ln] == [1009, 1057])

# ── E. the writer's term set ─────────────────────────────────────────────
print("\n== E. the writer's term set ==")
cand = rd(CAND)
chk("E1: candidates term row", "| lifting bridles (gold lifting bridles) |" in cand)
chk("E2: candidates chain row", "cyan line, lift bearing, lifting bridles, main rotor." in cand)
chk("E3: candidates cyan guard", "It is never a lifting bridle." in cand)
chk("E4: candidates cone row", "apex of the lifting-bridle cone." in cand)
chk("E5: candidates conflated row", '| "bridles (cyan lines)" | name each line: lifting bridles, cyan line |' in cand)
chk("E6: candidates v17 delta", "**v17 (2026-10-15):** the lifting-bridles rename re-keys the lift-chain rows." in cand)
chk("E7: candidates bad lines == the ban quote", badlines(CAND) == [264], str(badlines(CAND)))
sp_ = rd(SP)
chk("E8: stale-phrases heading holds as the ban form", "## bridles (cyan lines)" in sp_)
chk("E9: stale-phrases replacement form", "Replacement: lifting bridles and the cyan line are different lines: lifting bridles = lift bearing to main-rotor vertices" in sp_)
chk("E10: stale-phrases dated note", 'Note (2026-10-15): the lift-chain member reads "lifting bridles"' in sp_)
chk("E11: stale-phrases bad lines == the ban heading", badlines(SP) == [83], str(badlines(SP)))
nt = rd(NOTES)
chk("E12: notes L13/L23/L30 forms", "then three lifting bridles (one per TRPT line)" in nt and "TRPT lines, lifting bridles (gold, as the dashboard)" in nt and "lifting bridle = bearing to rotor" in nt)
chk("E13: notes bad lines zero", badlines(NOTES) == [])
trk = rd(TRK)
chk("E14: tracker v0.49 entry + term lines", "v0.49 pass by @author (2026-10-15)." in trk and "lifting-bridles form." in trk)
chk("E15: tracker bad lines zero", [i for i in badlines(TRK)] == [], str(badlines(TRK)))

# ── F. the desk docs, the flips and the scope calls ──────────────────────
print("\n== F. the desk docs, the flips and the scope calls ==")
pt = rd(PT)
chk("F1: physics-topology amend reads", "**Reader name (Rod, 2026-10-15):** the report reads **lifting bridles** for the" in pt)
chk("F2: physics-topology amend close", "alias. The code identifiers and the recorded pages hold their spelling." in pt)
chk("F3: physics-topology definitions hold", '**"Bridle" is the bearing→rotor link.' in pt and "| bridle cone half-angle (from the shaft axis) | 31° |" in pt)
chk("F4: physics-topology hub amend holds", "The codes and the records hold their spelling." in pt)
pbl = badlines(PT)
pt_pre_bad = sum(1 for ln in git("show", f"{BASIS}:{PT}").splitlines() if BAD.search(ln))
chk("F5: physics-topology bare reads = held spelling (pre + 1 amend line)", len(pbl) == pt_pre_bad + 1, f"{len(pbl)} vs pre {pt_pre_bad}")
dom = rd(DOM)
chk("F6: domain amend reads", "**Reader name (Rod, 2026-10-15):** the report reads *lifting bridles*." in dom)
chk("F7: domain item 8 + item 13 hold", "8. **Four different lines, four different names.**" in dom and '13. **The topmost rotor IS the main rotor.**' in dom)
dbl = badlines(DOM)
dom_pre_bad = sum(1 for ln in git("show", f"{BASIS}:{DOM}").splitlines() if BAD.search(ln))
chk("F8: domain bare reads = held spelling (pre + 0)", len(dbl) == dom_pre_bad, f"{len(dbl)} vs pre {dom_pre_bad}")
ctx = rd(CTX)
chk("F9: CONTEXT hold — the four lines unchanged", badlines(CTX) == [37, 58, 62, 184], str(badlines(CTX)))
chk("F10: CONTEXT hold — pins read", "│ BRIDLES (n_lines)" in ctx and "→ lift bearing → bridles → main rotor" in ctx and "if the bridles go slack" in ctx and '| **Bridles** ("gold bridles") |' in ctx)
reg = rd(REG)
chk("F11: register cone row reads as signed record", "bridle cone half-angle 31 degrees from the shaft axis" in reg)
chk("F12: register head holds at cb862df", git("log", "-1", "--format=%h", "--", REG).strip() == "cb862df")
chk("F13: register append-only since cb862df", git("diff", "--numstat", "cb862df", "HEAD", "--", REG).strip() == "")

# ── G. the corner cites and the map ──────────────────────────────────────
print("\n== G. the corner cites and the map ==")
cs = rd(CORNER)
chk("G1: corner register L11 signs at cb862df", "Signed (science-validator, `cb862df`)" in cs)
chk("G2: corner register old cite zero", "8855d9a" not in cs)
mp = rd(MAP)
chk("G3: map row 23 cite + closure", "signed (science-validator, `cb862df`)" in mp and "both cites take the sign commit" in mp)
chk("G4: map old cite zero", "8855d9a" not in mp)
chk("G5: map row 10 title reads the winner form", "Machine winner and the plan, side, downwind capture set" in mp)
chk("G6: map v40 + winner-form note", "**v40 (2026-10-15):** the lifting-bridles relabel lands" in mp and "Row 10's title takes the winner form" in mp)
chk("G7: map bad lines zero", badlines(MAP) == [])
g8 = git("grep", "-l", "-n", "--", "8855d9a").splitlines()
g8r = [x for x in g8 if not x.startswith(("docs/reporting/room-responses/", "handovers/", "scratch/"))]
chk("G8: the old cite survives only in records", g8r == [], str(g8r[:3]))

# ── H. the census ────────────────────────────────────────────────────────
print("\n== H. the tracked-tree census ==")
LIVE_BRIDLE = {
    FIGS + "system-anatomy.py", FIGS + "system-anatomy.tex", FIGS + "prototype.html",
    FIGS + "label-ledger.txt", FIGS + "captions.md", FIGS + "captions-draft.md",
    FIGS + "SPEC.md", FIGS + "manifest.json", FIGS + "checks.log", FIGS + "register-status.md",
    DRAFT, CAND, SP, NOTES, TRK, MAP, RSPEC, ELEM, REG, PT, DOM, CTX,
}
LIVE_HERO = {
    DRAFT, MAP, TRK, NOTES, RSPEC, REG,
    WIN + "README.md", WIN + "captions.md", WIN + "checks.log",
    WIN + "manifest.json", WIN + "register-status.md", WIN + "machine-winner-hero.jl",
}
REC = ("docs/", "handovers/", "docs/plans/", "docs/reports/", "docs/validation/", "docs/wayfinder-tickets/",
       "docs/handovers/", "docs/outreach/", "docs/awes-forum-diagrams/",
       "docs/reporting/room-responses/", "docs/reporting/feedback/", "docs/reporting/2026-",
       "docs/reporting/draft-consistency-sweep.md", "docs/reporting/figures/2026-",
       "docs/rig-topology.md", "docs/agents/instrument-trust-log.md",
       "docs/agents/item4-campaign-summary.md", "DECISIONS.md", "reviews/", ".superpowers/", ".hermes")
CODE = ("src/", "test/", "scripts/", "scratch/")
for term, patt, live in [("bridle", r"\bbridle", LIVE_BRIDLE), ("hero", r"\bhero", LIVE_HERO)]:
    files = git("grep", "-l", "-I", "-i", "-P", patt, "HEAD").splitlines()
    files = sorted(x.split(":", 1)[1] for x in files)
    print(f"  census[{term}] basis: HEAD {HEAD[:9]}")
    unk = [f for f in files if f not in (live or set()) and not f.startswith(REC) and not f.startswith(CODE)]
    chk(f"H-{term}: every hit file is classified", unk == [], f"{len(files)} files; unk={unk[:5]}")
    nlive = sum(1 for f in files if f in (live or set()))
    nrec = sum(1 for f in files if f not in (live or set()) and f.startswith(REC))
    ncode = sum(1 for f in files if f not in (live or set()) and f.startswith(CODE))
    print(f"  census[{term}]: {len(files)} files — live {nlive}, records {nrec}, code/scratch {ncode}")

hl2 = [i for i, ln in enumerate(rd(MAP).splitlines(), 1) if re.search("hero", ln, re.I)]
chk("H3: map hero lines are the recorded set", hl2 == [42, 79, 146, 151, 152, 163, 378, 389, 423, 427, 458], str(hl2))
chk("H4: live hero files read no figure-label form", "hero image" not in rd(DRAFT) + rd(MAP) + rd(TRK) and "Machine hero" not in rd(MAP))
chk("H5: renderer SPEC keeps the engine mode", "| hero | one design, the full annotation set | the winner genome |" in rd(RSPEC))
chk("H6: winner kit keeps its slug", 'const SLUG = "machine-winner-hero"' in rd(WIN + "machine-winner-hero.jl"))

print(f"\nSV_BR_TERM_GATE: {n_ck - n_fail}/{n_ck} checks pass" + ("" if n_fail == 0 else f" — {n_fail} FAIL"))
sys.exit(0 if n_fail == 0 else 1)

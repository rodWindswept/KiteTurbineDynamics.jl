#!/usr/bin/env python3
"""The lifting-bridles relabel counter-read + the winner-form re-keys (aero-validator, 2026-10-15).

Routed to this desk by @fig-img-diagrams (the relabel bytes), @author (the
v0.49 re-keys) and @science-validator (the closure flips and the two amends).

  [0] state and identity;
  [1] the SA kit bytes: the manifest, the checks log, the LaTeX log, the label census;
  [2] the F-REPRO counter-walk: my two fresh runs, the figures table, their two runs;
  [3] the draft v0.48/v0.49: movers, token deltas, the changed-line census, the sites;
  [4] the corner cite closes and the winner form;
  [5] the ride-alongs: the notes flips, the two reader-name amends.

Reads committed bytes and the scratch run trees only. Runs no simulator.
"""
import hashlib
import json
import re
import subprocess
import sys
from collections import Counter
from pathlib import Path

ROOT = Path("/home/rod/Documents/GitHub/KiteTurbineDynamics.jl")
SA = ROOT / "docs/reporting/figures/system-anatomy"
CORNER = ROOT / "docs/reporting/figures/machine-corner-grid"
DRAFT_REL = "docs/reporting/drafts/2026-10-08-report-first-draft.md"
TRACKER_REL = "docs/reporting/draft-tracker.md"
MAP_REL = "docs/reporting/figures/figure-map.md"
NOTES_REL = "docs/reporting/figures/figure-generation-notes.md"
FOK_REL = "docs/reporting/figures/system-anatomy/captions.md"
FDK_REL = "docs/reporting/figures/system-anatomy/captions-draft.md"
PHYS_REL = "docs/agents/physics-topology.md"
DOMAIN_REL = "docs/agents/domain.md"

F48, F49 = "6f19eee", "8169e36"        # the two draft movers since the last copy read
D_PREV = "d0ed902"                     # the last copy read state (v0.47)
SA_PY_SHA = "b3f11a395da3067dff970a4cebf827e917eac8dc6b88bbb295ab8bdea75b1735"
SA_OUT = {
    "checks.log": "99e81f32e1dbc3882a9a63400dac0a4410b3be618d29365b6633886a3aeec31a",
    "label-ledger.txt": "bed029d0f36a4e3b218510fc16fe5debf294b65413f64aa2abcafbfdc6ae4912",
    "system-anatomy.pdf": "c55bd7a888a1f3d657445460a9e6bebb05504efe04d4194661b3ae8f1a844d4c",
    "system-anatomy.png": "696be723993c708b038e0d1e10b96e83ba357a65cb2442580b1de371dedf8c66",
    "system-anatomy.tex": "e7697c986d605f6ff50e2c628812a84e9eb2e5514a6170a7de89b2f707f1060c",
}
SA_MD5 = {
    "system-anatomy.tex": "e8f08e653010c820262587e30dd9d42b",
    "prototype.html": "58d4e491c3a61af39bb7f655f55e4114",
    "label-ledger.txt": "b359914881c9d9936ff7fc8dd7c2611d",
    "system-anatomy.pdf": "e00521fe239ec244139898f77178af17",
    "system-anatomy.png": "19c0caf5e32bd5728323c30ff98124a0",
}
NEW_LABEL = "lifting bridles (three)"
CAPTION_SENTENCE = "Three lifting bridles run from the bearing into the main rotor."

TOK = re.compile(r"(?<![\w-])\d+(?:\.\d+)?(?![\w-])")

OK = FAIL = 0


def ok(msg):
    global OK
    OK += 1
    print(f"  ok   {msg}")


def bad(msg):
    global FAIL
    FAIL += 1
    print(f"  FAIL {msg}")


def git_bytes(*a):
    return subprocess.run(["git", "-C", str(ROOT), *a], capture_output=True).stdout


def git_txt(*a):
    return git_bytes(*a).decode("utf-8")


def gitc(*a):
    return git_txt(*a).strip()


def sha(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest()


def md5(p):
    return hashlib.md5(Path(p).read_bytes()).hexdigest()


def nrm(t):
    t = re.sub(r"\s+", " ", t)
    return t


def diff_lines(a, b, rel):
    out = git_txt("diff", "--unified=0", f"{a}..{b}", "--", rel)
    add = [l[1:] for l in out.splitlines() if l.startswith("+") and not l.startswith("+++")]
    rem = [l[1:] for l in out.splitlines() if l.startswith("-") and not l.startswith("---")]
    return add, rem


def hunk_lines(rev, rel):
    """The -side line numbers and counts of every hunk in rev^..rev."""
    out = git_txt("diff", "--unified=0", f"{rev}^..{rev}", "--", rel)
    return [(int(m.group(1)), int(m.group(2) or 1))
            for m in re.finditer(r"^@@ -(\d+)(?:,(\d+))? ", out, flags=re.M)]


tip = gitc("rev-parse", "--short", "HEAD")
up = gitc("rev-parse", "--short", "origin/bank-derate-cos2p65")
print(f"[0] lifting-bridles relabel counter-read   tip {tip}   origin {up}")
(ok if tip == up else bad)("tip == origin")

print("[1] the SA kit bytes")
man = json.loads((SA / "manifest.json").read_text())
(ok if man["script"]["sha256"] == SA_PY_SHA and sha(SA / "system-anatomy.py") == SA_PY_SHA
 else bad)("manifest script sha == delivered .py")
for fn, want in SA_OUT.items():
    (ok if sha(SA / fn) == want and man["outputs"].get(fn) == want else bad)(f"pin {fn} == delivered == manifest")
(ok if man["script_commit"] == "9241b23" and man["data_commit"] == "dd3cc6a" else bad)("manifest commits read 9241b23 / dd3cc6a")
(ok if man["inputs"]["register_rows"] == ["NR-011", "NR-017", "NR-043"] else bad)("manifest rows read NR-011/017/043")

clog = (SA / "checks.log").read_text()
(ok if "re-cut v7: the lifting-bridles relabel" in clog and "reads 'lifting bridles (three)' (script commit 9241b23)" in clog
 else bad)("checks log carries the v7 block")
(ok if "three full runs byte-identical across all five outputs" in clog else bad)("checks log: three-run identity line")
for fn, want in SA_MD5.items():
    (ok if f"{want}  {fn}" in clog else bad)(f"checks log md5 row {fn}")
lg = (SA / "system-anatomy.log").read_text(errors="replace")
(ok if len(re.findall(r"(?m)^! ", lg)) == 0 else bad)("LaTeX log: zero error lines")
(ok if "Overfull" not in lg else bad)("LaTeX log: zero overfull boxes")

tex = (SA / "system-anatomy.tex").read_text()
html = (SA / "prototype.html").read_text()
ledger = (SA / "label-ledger.txt").read_text()
py = (SA / "system-anatomy.py").read_text()
for name, txt in [("tex", tex), ("prototype", html), ("ledger", ledger)]:
    bare = [m for m in re.finditer(r"bridles \(three\)", txt)
            if not txt[max(0, m.start() - 8):m.start()].endswith("lifting ")]
    (ok if NEW_LABEL in txt and not bare else bad)(f"{name}: new label reads, bare old form zero")
(ok if len([l for l in ledger.splitlines() if l.strip()]) == 34 else bad)("label ledger reads its 34 strings")
(ok if "lifting bridles (three)" in py and "v7 re-cut (2026-10-15)" in py else bad)("generator carries the v7 note")
old_kit = [f for f in SA.rglob("*") if f.suffix in (".py", ".tex", ".html", ".txt", ".md")
           and "bridles (three)" in f.read_text(errors="replace")
           and not all(l.strip() and ("lifting " in l or "lifting-bridles" in l or "relabel" in l or "assurance" in l)
                       for l in [ln for ln in f.read_text(errors="replace").splitlines() if "bridles (three)" in ln])]
(ok if not old_kit else bad)(f"kit-wide: no bare 'bridles (three)' outside the relabel lines ({[str(p.name) for p in old_kit]})")
(ok if "lifting bridles" in (SA / "SPEC.md").read_text()
 and "lifting bridles (three)" in (SA / "SPEC.md").read_text() else bad)("SPEC carries the load-path form and the relabel item")
(ok if "9241b23" in (SA / "captions.md").read_text() or "9241b23" in (SA / "captions-draft.md").read_text()
 else bad)("the captions carry the provenance token 9241b23")
(ok if "**Delta** v5 (2026-10-15): the v7 re-cut lands." in (SA / "register-status.md").read_text()
 else bad)("SA register note carries delta v5")

print("[2] the F-REPRO counter-walk")
delivered_md5 = {fn: md5(SA / fn) for fn in SA_MD5}
(ok if all(delivered_md5[fn] == SA_MD5[fn] for fn in SA_MD5) else bad)("delivered md5s read the table")
rt = (ROOT / "scratch/fig_br_repro.md5").read_text()
(ok if all(f"{SA_MD5[fn]}  {fn}" in rt for fn in SA_MD5) else bad)("figures repro table pins == delivered")
runs = [ROOT / "scratch/av_sa_run1/system-anatomy", ROOT / "scratch/av_sa_run2/system-anatomy"]
for i, r in enumerate(runs, 1):
    if not r.exists():
        bad(f"my run {i} missing: {r}")
        continue
    (ok if all(md5(r / fn) == SA_MD5[fn] for fn in SA_MD5)
     else bad)(f"my run {i}: all five outputs byte-identical to the delivered set")
r1, r2 = ROOT / "scratch/sa_br_repro/run1/system-anatomy", ROOT / "scratch/sa_br_repro/run2/system-anatomy"
for i, r in enumerate([r1, r2], 1):
    if not r.exists():
        print(f"  note figures-seat run{i} tree absent; skipped")
        continue
    (ok if all(md5(r / fn) == SA_MD5[fn] for fn in SA_MD5)
     else bad)(f"figures-seat run {i}: all five outputs byte-identical")
(ok if len({md5(ROOT / f"scratch/av_sa_run{k}/system-anatomy/{fn}") for k in (1, 2) for fn in SA_MD5} |
            set(SA_MD5.values())) == 5 else bad)("one md5 value per output across every location")

print("[3] the draft v0.48 and v0.49")
mv_d = gitc("log", "--format=%h", f"{D_PREV}..HEAD", "--", "docs/reporting/drafts").split()
(ok if sorted(mv_d) == sorted([F48, F49]) else bad)(f"draft movers since {D_PREV} read [6f19eee, 8169e36] ({mv_d})")
st = gitc("show", "--name-only", "--format=", F49).splitlines()
cont = sorted(p for p in st if not p.startswith("scratch/"))
ev = sorted(p for p in st if p.startswith("scratch/"))
(ok if cont == sorted([
    "docs/reporting/draft-tracker.md", "docs/reporting/drafts/2026-10-08-report-first-draft.md",
    "docs/reporting/figures/system-anatomy/captions-draft.md",
    "docs/reporting/figures/system-anatomy/captions.md"])
 and ev == ["scratch/au_v049_rekeys_fold.log", "scratch/au_v049_rekeys_fold.py"]
 else bad)(f"the v0.49 fold touches four content files + its evidence ({cont}, {ev})")
draft = git_txt("show", f"HEAD:{DRAFT_REL}")
draft_prev = git_txt("show", f"{D_PREV}:{DRAFT_REL}")
draft_48 = git_txt("show", f"{F48}:{DRAFT_REL}")
for tag, a_txt, b_txt, exp_add, exp_rem in [
        ("v0.48 pins", draft_prev, draft_48, {"48": 1}, {"47": 1}),
        ("v0.49 re-keys", draft_48, draft, {"49": 1}, {"48": 1})]:
    ta, tb = Counter(TOK.findall(a_txt)), Counter(TOK.findall(b_txt))
    add = dict(tb - ta)
    rem = dict(ta - tb)
    (ok if add == exp_add and rem == exp_rem else bad)(
        f"{tag}: token delta reads add {dict(sorted(add.items()))} / rem {dict(sorted(rem.items()))}")
ta, tb = Counter(TOK.findall(draft_prev)), Counter(TOK.findall(draft))
add = dict(tb - ta)
rem = dict(ta - tb)
(ok if add == {"49": 1} and rem == {"47": 1} else bad)(
    f"cumulative delta reads add {dict(sorted(add.items()))} / rem {dict(sorted(rem.items()))}")

h = hunk_lines(F49, DRAFT_REL)
(ok if [x[0] for x in h] == [3, 484, 539, 946, 994] and all(c == 1 for _, c in h)
 else bad)(f"v0.49 changed-line census reads [3, 484, 539, 946, 994], 1-for-1 ({h})")
lines = draft.splitlines()
checks = [
    (3, "Internal engineering report. Draft v0.49. Date 2026-10-15."),
    (484, "[Figure seated: figure-map row 10 (machine winner, slug `machine-winner-hero`). Values cite NR-011, NR-017, NR-021, NR-022 and NR-043.]"),
    (539, "bearing, and down the lifting bridles to the main rotor."),
    (946, "| Machine winner | `strip-extract-2026-10-09-best-so-far` · `pair-extract-2026-10-08-winner-ops` | NR-011, NR-017, NR-021, NR-022, NR-043 | `1af63fc` | `post-95c385d_wind-authority` |"),
    (994, "Machine winner:"),
]
for ln, want in checks:
    (ok if lines[ln - 1] == want else bad)(f"draft line {ln} reads its form")
hero = re.findall(r"(?i)hero", draft)
(ok if len(hero) == 1 and "machine-winner-hero" in draft else bad)(f"draft hero census reads 1, in the slug ({len(hero)})")
(ok if not re.search(r"(?i)machine winner hero", draft) else bad)("draft reads zero 'Machine winner hero'")
(ok if "Three bridles run" not in draft and "down the bridles" not in draft else bad)("draft reads zero old label forms")
# SA block pins and the old pin set
sa_block = draft.split("System anatomy plate:", 1)[1].split("Levers landscape:", 1)[0]
for fn, want in [("png", SA_OUT["system-anatomy.png"]), ("pdf", SA_OUT["system-anatomy.pdf"]),
                 ("ledger", SA_OUT["label-ledger.txt"]), ("checks", SA_OUT["checks.log"])]:
    (ok if f"- `{fn}` `{want}`" in sa_block else bad)(f"SA block pin {fn} reads the delivered sha")
old_block = draft_prev.split("System anatomy plate:", 1)[1].split("Levers landscape:", 1)[0]
old_pins = re.findall(r"`([0-9a-f]{64})`", old_block)
(ok if old_pins and all(p not in draft for p in old_pins) else bad)("every old SA pin reads zero at HEAD")
(ok if "| System anatomy plate |" in draft and "`9241b23`" in draft else bad)("SA appendix row carries the new script cell")
(ok if draft.count("`1af63fc`") == 3 else bad)(f"the 1af63fc script cells read 3 ({draft.count('`1af63fc`')})")

add, rem = diff_lines(f"{F49}^", F49, TRACKER_REL)
(ok if not rem and any("v0.49 pass by @author" in l for l in add) else bad)("tracker: v0.49 entry, additions only")
trk = git_txt("show", f"HEAD:{TRACKER_REL}")
(ok if "v0.49 pass by @author (2026-10-15)." in trk and "v0.48 pass by @fig-img-diagrams (2026-10-15)." in trk
 else bad)("tracker carries the v0.48 and v0.49 entries")
for rel, ln, frag in [(FDK_REL, 23, "Three lifting bridles run from"), (FOK_REL, 39, "Three lifting bridles run")]:
    t = git_txt("show", f"HEAD:{rel}")
    (ok if frag in t.splitlines()[ln - 1] and nrm(CAPTION_SENTENCE) in nrm(t) else bad)(f"{Path(rel).name} L{ln}: caption form reads")
    (ok if "Three bridles run" not in t else bad)(f"{Path(rel).name}: old form zero")

print("[4] the corner cite closes and the winner form")
rstat = (CORNER / "register-status.md").read_text()
(ok if "Signed (science-validator, `cb862df`)" in rstat else bad)("corner register L11 takes cb862df")
(ok if "**Delta** v2 (2026-10-15): the counter-reads close clean (`857f2c1`," in rstat else bad)("corner register carries delta v2")
rdme = (CORNER / "README.md").read_text()
(ok if "close clean (`857f2c1`, 153 checks)" in rdme and "takes the sign\ncommit `cb862df`" in rdme else bad)("corner README state line")
mp = git_txt("show", f"HEAD:{MAP_REL}")
(ok if "signed (science-validator, `cb862df`)" in mp else bad)("map row 23 takes cb862df")
(ok if "counter-reads close clean (`857f2c1`, 153 checks)" in mp else bad)("map row 23 records the counter-read close")
(ok if "Two cite findings close: both cites take the sign commit" in mp else bad)("map row 23 records the finding close")
(ok if "Machine winner and the plan, side, downwind capture set" in mp else bad)("map row 10 takes the winner title")
(ok if "Machine hero and the plan" not in mp else bad)("old map title reads zero")
(ok if "v39" in mp and "v40" in mp and "lifting bridles (three)" in mp and "`9241b23`" in mp else bad)("map deltas v39/v40 and the relabel record")
n8855 = subprocess.run(["git", "-C", str(ROOT), "grep", "-c", "8855d9a", "--",
                        "docs/reporting/figures"], capture_output=True)
(ok if n8855.returncode != 0 else bad)("8855d9a reads zero across the live figure tree")

print("[5] the ride-alongs")
notes = git_txt("show", f"HEAD:{NOTES_REL}")
(ok if "Lift bearing, then three lifting bridles (one per TRPT line) to the R6 vertices." in notes
 else bad)("notes L13 reads the lifting form")
(ok if "lifting bridles (gold, as the dashboard)" in notes else bad)("notes L23 style line (the closure flip)")
(ok if "lifting bridle = bearing to rotor; cyan line = sky anchor to bearing." in notes
 else bad)("notes L30 distinction line")
fdr = git_txt("show", f"HEAD:{FDK_REL}")
(ok if "lifting bridles, main rotor, ground ring, topmost ring" in nrm(fdr) else bad)("captions-draft checklist line (the closure flip)")
phys = git_txt("show", f"HEAD:{PHYS_REL}")
(ok if "**Reader name (Rod, 2026-10-15):** the report reads **lifting bridles** for the" in phys else bad)("physics-topology section 2 amend")
dom = git_txt("show", f"HEAD:{DOMAIN_REL}")
(ok if "**Reader name (Rod, 2026-10-15):** the report reads *lifting bridles*." in dom else bad)("domain item 8 amend")

print(f"\nchecks: {OK + FAIL}  ok: {OK}  fail: {FAIL}")
print("AV_BR_DONE" if FAIL == 0 else "AV_BR_FAIL")
sys.exit(1 if FAIL else 0)

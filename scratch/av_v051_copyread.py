#!/usr/bin/env python3
"""The v0.51 copy counter-read (aero-validator, 2026-10-15).

Routed to this desk by @fig-img-diagrams (the corner-machines fold, record
1061878, live md5 74aa4c02) and held for @author's v0.50 copy (md5
ae15d991). @science-validator confirms the value legs.

  [0] identity and freshness: copy md5, the archives, the build record, the
      register ref, the embed set, the post-build moves, the stamp pair;
  [1] the copy input census (last read -> v0.50 -> v0.51): movers, token
      deltas, line-number censuses, commit file sets;
  [2] the fold surfaces in the built copy (the kMppt plain sentences, the
      corner grid, the seat marker consumed);
  [3] the appendix pins, the stamps, the eight embeds, the token census;
  [4] the register appendix and the retired-word holds;
  [5] the delta chain (v0.49 and v0.50 archives) and the state anchors;
  [6] the intermediate build archive (observed and classified).

Reads committed bytes and the delivered copies only. Runs no simulator.
"""
import hashlib
import json
import re
import subprocess
import sys
import zipfile
from collections import Counter
from pathlib import Path

ROOT = Path("/home/rod/Documents/GitHub/KiteTurbineDynamics.jl")
DRAFT_REL = "docs/reporting/drafts/2026-10-08-report-first-draft.md"
TRACKER_REL = "docs/reporting/draft-tracker.md"
REG_REL = "docs/reporting/numbers-register.md"
MAP_REL = "docs/reporting/figures/figure-map.md"
OUT = ROOT / "scratch/report-pdf-build"
DOCX = OUT / "draft-live.docx"
ARCHIVE = OUT / "draft-1061878-20261015-155027.docx"
V50_ARCHIVE = OUT / "draft-171f3ea-20261015-154001.docx"
V49_ARCHIVE = OUT / "draft-8169e36-20261015-144342.docx"
MID_ARCHIVE = OUT / "draft-171f3ea-20261015-154954.docx"
BUILD_RECORD = OUT / "build-record-docx.txt"
FIG_REL = "docs/reporting/figures"
BRANCH = "origin/bank-derate-cos2p65"
READ_PREV = "08b8523"      # my last copy-read base (the relabel pass)
D_RECORD = "1061878"       # the fold commit = the copy's record draft
REG_REF = "cb862df"        # the register blob named by the build record
COPY_MD5 = "74aa4c02cdb80ecf310982fee361b15b"
V50_MD5 = "ae15d9918ea216dcd6f0ada6073d0ec0"
V49_MD5 = "24f98df65d7274233bfea9cc9e736937"
MID_MD5 = "e92baf699befa38aab542e4b2681fcdf"
UNCITED8 = ["NR-024", "NR-031", "NR-033", "NR-034", "NR-035", "NR-037", "NR-038", "NR-041"]
MARKER23 = ("[Figure seated: figure-map row 23 (the corner machines, slug "
            "`machine-corner-grid`). Values cite NR-044 and NR-051.]")
FROZEN_MD5 = "7bbd964db09d2b33269ce5cb8c334054"

TOK = re.compile(r"(?<![\w-])\d+(?:\.\d+)?(?![\w-])")

EXHIBITS = [
    ("Ring utilisation plate", "ring-utilisation", ["png", "svg", "pdf", "ledger"]),
    ("Twist limit plate", "twist-limit", ["png", "svg", "pdf", "ledger"]),
    ("Machine evolution strip", "machine-evolution-strip", ["png", "svg", "pdf", "checks"]),
    ("System anatomy plate", "system-anatomy", ["png", "pdf", "ledger", "checks"]),
    ("Levers landscape", "pca-landscape", ["png", "svg", "pdf", "ledger"]),
    ("Parameter atlas", "pca-atlas", ["png", "svg", "pdf", "ledger"]),
    ("Machine winner", "machine-winner-hero", ["png", "svg", "pdf", "checks"]),
    ("The corner machines", "machine-corner-grid", ["png", "svg", "pdf", "checks"]),
]
EXHIBIT_FILES = {
    "ring-utilisation": ["ring-utilisation.png", "ring-utilisation.svg",
                         "ring-utilisation.pdf", "label-ledger.txt"],
    "twist-limit": ["twist-limit.png", "twist-limit.svg",
                    "twist-limit.pdf", "label-ledger.txt"],
    "machine-evolution-strip": ["machine-evolution-strip.png", "machine-evolution-strip.svg",
                                "machine-evolution-strip.pdf", "checks.log"],
    "system-anatomy": ["system-anatomy.png", "system-anatomy.pdf",
                       "label-ledger.txt", "checks.log"],
    "pca-landscape": ["pca-landscape.png", "pca-landscape.svg",
                      "pca-landscape.pdf", "label-ledger.txt"],
    "pca-atlas": ["pca-atlas.png", "pca-atlas.svg",
                  "pca-atlas.pdf", "label-ledger.txt"],
    "machine-winner-hero": ["machine-winner-hero.png", "machine-winner-hero.svg",
                            "machine-winner-hero.pdf", "checks.log"],
    "machine-corner-grid": ["machine-corner-grid.png", "machine-corner-grid.svg",
                            "machine-corner-grid.pdf", "checks.log"],
}
KIT_PNGS = [f"{s}/{s}.png" for s in EXHIBIT_FILES]
FRAMES = [
    "system-anatomy Figure (roster row 2) · system-anatomy",
    "machine-winner-hero Figure (roster row 10) · machine-winner-hero",
    "ring-utilisation Figure (roster row 6) · ring-utilisation",
    "twist-limit Figure (roster row 7) · twist-limit",
    "pca-landscape Figure (roster row 20) · pca-landscape",
    "pca-atlas Figure (roster row 21) · pca-atlas",
    "machine-corner-grid Figure (roster row 23) · machine-corner-grid",
    "machine-evolution-strip Figure (roster row 9) · machine-evolution-strip",
]
HEADS = (r"^(Ring utilisation plate|Twist limit plate|Machine evolution strip"
         r"|System anatomy plate|Levers landscape|Parameter atlas|Machine winner"
         r"|The corner machines):$")

POST_BUILD = {
    "docs/reporting/room-responses/figures-images-diagrams-2026-10-15-corner-machines-fold.md",
    "docs/reporting/room-responses/science-validator-2026-10-15-corner-grid-register-read.md",
    "handovers/handover-2026-10-14-reporting-room-science-validator.md",
    "scratch/fig_cg_fold_build.log",
    "scratch/fig_cg_fold_readback.log",
    "scratch/fig_cg_fold_rebuild_check.log",
    "scratch/fig_cg_fold_rebuild_check.py",
    "scratch/sv_cg_register_read_check.log",
    "scratch/sv_cg_register_read_check.py",
}
FILES_171F3EA = {
    "docs/reporting/draft-tracker.md",
    "docs/reporting/drafts/2026-10-08-report-first-draft.md",
    "scratch/au_v050_kmppt_plain_fold.log",
    "scratch/au_v050_kmppt_plain_fold.py",
}
FILES_1061878 = {
    "docs/reporting/draft-tracker.md",
    "docs/reporting/drafts/2026-10-08-report-first-draft.md",
    "docs/reporting/figures/figure-map.md",
    "docs/reporting/figures/machine-corner-grid/README.md",
    "docs/reporting/figures/machine-corner-grid/register-status.md",
    "handovers/handover-2026-10-14-reporting-room-figures-images-diagrams.md",
    "scratch/fig_cg_fold_check.log",
    "scratch/fig_cg_fold_check.py",
    "scratch/fig_cg_fold_citation.log",
    "scratch/fig_cg_fold_edit.log",
    "scratch/fig_cg_fold_edit.py",
    "scratch/fig_cg_fold_facts.json",
}

OK = FAIL = 0


def ok(msg):
    global OK
    OK += 1
    print(f"  ok   {msg}")


def bad(msg):
    global FAIL
    FAIL += 1
    print(f"  FAIL {msg}")


def note(msg):
    print(f"  note {msg}")


def git_bytes(*a):
    return subprocess.run(["git", "-C", str(ROOT), *a], capture_output=True).stdout


def git_txt(*a):
    return git_bytes(*a).decode("utf-8")


def gitc(*a):
    return git_txt(*a).strip()


def sha256_bytes(b):
    return hashlib.sha256(b).hexdigest()


def md5_bytes(b):
    return hashlib.md5(b).hexdigest()


def nrm(t):
    t = t.replace("`", "")
    t = re.sub(r"\s+", " ", t)
    return re.sub(r"\s+([.,:;])", r"\1", t)


def manifest_stamp(m):
    bits = []
    cap = m.get("capture", {})
    if cap.get("run_id"):
        bits.append(cap["run_id"])
    data = m.get("data_commit")
    if data:
        bits.append(f"data {data}")
    else:
        s = (m.get("inputs", {}).get("extract", {}) or {}).get("sha256", "")
        if s:
            bits.append(f"data {s[:7]}")
    script = m.get("script_commit")
    if not script:
        s = m.get("script", {}).get("sha256", "")
        script = s[:7] if s else None
    if script:
        bits.append(f"script {script}")
    rows = m.get("registers") or m.get("inputs", {}).get("register_rows", [])
    if rows:
        bits.append("rows " + ", ".join(rows))
    return " · ".join(bits)


def docx_text(path):
    z = zipfile.ZipFile(path)
    xml = z.read("word/document.xml").decode("utf-8")
    return re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", xml)), z


def added_removed(a, b, path):
    d = git_txt("diff", "-U0", a, b, "--", path)
    add, rem = [], []
    for m in re.finditer(r"^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@", d, flags=re.M):
        s, n = int(m.group(1)), int(m.group(2) or 1)
        rem.extend(range(s, s + n))
        s, n = int(m.group(3)), int(m.group(4) or 1)
        add.extend(range(s, s + n))
    return add, rem


tip = gitc("rev-parse", "--short", "HEAD")
up = gitc("rev-parse", "--short", BRANCH)
dtext, z = docx_text(DOCX)
dn = nrm(dtext)
rec = BUILD_RECORD.read_text(encoding="utf-8")
draft = git_txt("show", f"HEAD:{DRAFT_REL}")
reg_head = git_txt("show", f"HEAD:{REG_REL}")
map_head = git_txt("show", f"HEAD:{MAP_REL}")
trk = git_txt("show", f"HEAD:{TRACKER_REL}")
print(f"[0] v0.51 copy counter-read   tip {tip}   origin {up}   record {D_RECORD}   copy md5 {md5_bytes(DOCX.read_bytes())}")

print("[0] identity and freshness")
md5 = md5_bytes(DOCX.read_bytes())
(ok if md5 == COPY_MD5 else bad)("copy md5 reads the declared value")
(ok if md5 == md5_bytes(ARCHIVE.read_bytes()) else bad)("copy byte-identical to its archived build")
(ok if DOCX.stat().st_size == ARCHIVE.stat().st_size else bad)("copy and archive carry one size")
for s, name in [("Draft: `1061878`", "build record names draft 1061878"),
                ("file at `cb862df`", "build record refs register cb862df"),
                ("43 cited, every one signed (51 signed rows total)", "build record: 43 cited of 51 signed"),
                ("uncited: NR-024, NR-031, NR-033, NR-034, NR-035, NR-037, NR-038, NR-041",
                 "build record uncited list reads the 8 ids"),
                ("checker exit 0", "build record: checker exit 0"),
                ("Seats resolved: 8 of 8", "build record: eight seats"),
                ("`machine-corner-grid`", "build record seat list carries the corner kit"),
                ("Built: 2026-10-15T15:50:27Z", "build record stamp 15:50:27Z"),
                ("Embed route: SVG vector-first, PNG fallback", "build record embed route"),
                ("nothing re-rendered", "build record: nothing re-rendered")]:
    (ok if s in rec else bad)(name)
(ok if dtext.count("Draft: 1061878") == 1 else bad)("copy block names draft 1061878 once")
(ok if dtext.count("file at cb862df") == 1 else bad)("copy block refs register cb862df once")
(ok if dtext.count("43 cited, every one signed (51 signed rows total)") == 1 else bad)(
    "copy block: 43 cited of 51 signed once")
(ok if dtext.count("uncited: NR-024, NR-031, NR-033, NR-034, NR-035, NR-037, NR-038, NR-041") == 1
 else bad)("copy block uncited list reads the 8 ids once")
(ok if dtext.count("checker exit 0") == 1 else bad)("copy block: checker exit 0 once")
(ok if dtext.count("Seats resolved: 8 of 8") == 1 else bad)("copy block: eight seats once")
seats_line = ("system-anatomy, machine-winner-hero, ring-utilisation, twist-limit, "
              "pca-landscape, pca-atlas, machine-corner-grid, machine-evolution-strip")
(ok if dn.count(seats_line) == 1 else bad)("copy block seat list reads the eight slugs once")
(ok if dtext.count("Built: 2026-10-15T15:50:26Z") == 1 else bad)(
    "copy block stamp reads 15:50:26Z once")
(ok if dtext.count("15:50:27Z") == 0 else bad)("copy reads zero 15:50:27Z forms")
m_rec = re.search(r"Built: ([0-9T:\-]+Z)", rec)
m_doc = re.search(r"Built: ([0-9T:\-]+Z)", dtext)
d_rec = m_rec.group(1) if m_rec else "?"
d_doc = m_doc.group(1) if m_doc else "?"
(ok if d_doc == "2026-10-15T15:50:26Z" and d_rec == "2026-10-15T15:50:27Z"
 else bad)(f"stamp pair reads record {d_rec} / block {d_doc}")
note(f"stamp pair: the record file and the archive name read {d_rec}, the copy block reads {d_doc} (delta 1 s, same date)")
a = gitc("rev-parse", f"{D_RECORD}:{DRAFT_REL}")
b = gitc("rev-parse", f"HEAD:{DRAFT_REL}")
c = gitc("rev-parse", f"{BRANCH}:{DRAFT_REL}")
(ok if a and a == b == c else bad)("draft blob reads 1061878 == HEAD == origin")
(ok if gitc("log", "--format=%h", f"{D_RECORD}..HEAD", "--", "docs/reporting/drafts") == ""
 else bad)("no draft move since the record")
a = gitc("rev-parse", f"{REG_REF}:{REG_REL}")
b = gitc("rev-parse", f"HEAD:{REG_REL}")
c = gitc("rev-parse", f"{BRANCH}:{REG_REL}")
(ok if a and a == b == c else bad)("register ref cb862df == HEAD == origin")
(ok if gitc("log", "--format=%h", f"{REG_REF}..HEAD", "--", REG_REL) == ""
 else bad)("register unchanged since cb862df")
(ok if gitc("log", "--format=%h", f"{D_RECORD}..HEAD", "--", TRACKER_REL) == ""
 else bad)("tracker holds since the record")
embed32 = [f"{FIG_REL}/{slug}/{fn}" for _, slug, _ in EXHIBITS for fn in EXHIBIT_FILES[slug]]
st = gitc("diff", "--stat", D_RECORD, "HEAD", "--", *embed32)
(ok if st == "" else bad)("the 32 embedded bytes hold since the record")
(ok if gitc("diff", "--stat", D_RECORD, "HEAD", "--", FIG_REL) == "" else bad)(
    "the whole figure tree holds since the record")
moved = set(gitc("diff", "--name-only", D_RECORD, "HEAD").splitlines())
(ok if moved == POST_BUILD else bad)(
    f"post-build moves read the declared 9 paths ({len(moved)} seen)")
(ok if "docs/reporting/draft-tracker.md" not in moved else bad)("tracker not among post-build moves")
(ok if REG_REL not in moved and DRAFT_REL not in moved else bad)("register and draft not among post-build moves")
(ok if tip == up else bad)("the read tip reads the same as origin")

print("[1] the copy input census (last read -> v0.50 -> v0.51)")
(ok if gitc("rev-parse", f"{READ_PREV}^{{commit}}") != "" else bad)("last-read base resolves")
(ok if gitc("rev-list", "--count", f"{READ_PREV}..HEAD") == "14" else bad)(
    f"14 commits land since the last copy read ({gitc('rev-list', '--count', f'{READ_PREV}..HEAD')})")
mv_d = gitc("log", "--format=%h", f"{READ_PREV}..HEAD", "--", "docs/reporting/drafts").split()
(ok if sorted(mv_d) == sorted(["171f3ea", D_RECORD]) else bad)(f"draft movers read [171f3ea, 1061878] ({mv_d})")
mv_t = gitc("log", "--format=%h", f"{READ_PREV}..HEAD", "--", TRACKER_REL).split()
(ok if sorted(mv_t) == sorted(["171f3ea", D_RECORD]) else bad)(f"tracker movers read [171f3ea, 1061878] ({mv_t})")
mv_r = gitc("log", "--format=%h", f"{READ_PREV}..HEAD", "--", REG_REL).split()
(ok if mv_r == [] else bad)(f"register movers read none ({mv_r})")
for tag, a, b, exp_add, exp_rem in [
        ("v0.50 plain pass", "8169e36", "171f3ea", {"50": 1}, {"49": 1}),
        ("v0.51 corner fold", "171f3ea", D_RECORD, {"23": 1, "51": 1}, {"50": 1})]:
    ta = Counter(TOK.findall(git_txt("show", f"{a}:{DRAFT_REL}")))
    tb = Counter(TOK.findall(git_txt("show", f"{b}:{DRAFT_REL}")))
    add = dict(tb - ta)
    rem = dict(ta - tb)
    (ok if add == exp_add and rem == exp_rem else bad)(
        f"draft {tag}: token delta reads add {dict(sorted(add.items()))} / rem {dict(sorted(rem.items()))}")
for tag, a, b, exp_add in [
        ("v0.50 plain pass", "8169e36", "171f3ea", {"50": 1}),
        ("v0.51 corner fold", "171f3ea", D_RECORD, {"3.4": 1, "51": 1})]:
    ta = Counter(TOK.findall(git_txt("show", f"{a}:{TRACKER_REL}")))
    tb = Counter(TOK.findall(git_txt("show", f"{b}:{TRACKER_REL}")))
    add = dict(tb - ta)
    rem = dict(ta - tb)
    (ok if add == exp_add and rem == {} else bad)(
        f"tracker {tag}: token delta reads add {dict(sorted(add.items()))} / rem {dict(sorted(rem.items()))}")
add, rem = added_removed("8169e36", "171f3ea", DRAFT_REL)
(ok if add == [3, 318, 320, 321] and rem == [3, 318, 320, 321] else bad)(
    f"v0.50 draft changed-line census reads {add} / {rem}")
add, rem = added_removed("171f3ea", D_RECORD, DRAFT_REL)
(ok if add == [3, 635, 636, 938, 949, 1003, 1004, 1005, 1006, 1007, 1008, 1009]
 and rem == [3, 936] else bad)(f"v0.51 draft changed-line census reads {add} / {rem}")
ns_d = gitc("diff", "--numstat", "8169e36", "171f3ea", "--", DRAFT_REL, TRACKER_REL).splitlines()
ns_t = gitc("diff", "--numstat", "171f3ea", D_RECORD, "--", DRAFT_REL, TRACKER_REL).splitlines()
(ok if [l.split("\t")[:2] for l in ns_d] == [["5", "0"], ["4", "4"]] else bad)(
    f"v0.50 numstats read +5/-0 and +4/-4 ({ns_d})")
(ok if [l.split("\t")[:2] for l in ns_t] == [["7", "0"], ["12", "2"]] else bad)(
    f"v0.51 numstats read +7/-0 and +12/-2 ({ns_t})")
diff50 = git_txt("diff", "8169e36", "171f3ea", "--", DRAFT_REL)
(ok if "-Internal engineering report. Draft v0.49. Date 2026-10-15." in diff50 else bad)("v0.50 diff removes the v0.49 pin line")
(ok if "-The beam sizes on a bounded generator load step, twice the nominal load (NR-048)." in diff50 else bad)("v0.50 diff removes the old beam sentence")
(ok if "-The low-wind lull is benign under the load law." in diff50 else bad)("v0.50 diff removes the old lull sentence")
(ok if "-The record refuses k easing as the high-wind substitute." in diff50 else bad)("v0.50 diff removes the old refusal sentence")
(ok if "+Internal engineering report. Draft v0.50. Date 2026-10-15." in diff50 else bad)("v0.50 diff adds the v0.50 pin line")
(ok if "+The team sizes the beam for a bounded generator load step: twice the nominal load (NR-048)." in diff50 else bad)("v0.50 diff adds the new beam sentence")
(ok if "+A low-wind lull is harmless under the load law." in diff50 else bad)("v0.50 diff adds the new lull sentence")
(ok if "+The team refuses to ease k as the high-wind substitute." in diff50 else bad)("v0.50 diff adds the new refusal sentence")
files_50 = set(l for l in git_txt("show", "--name-only", "--format=", "171f3ea").splitlines() if l.strip())
(ok if files_50 == FILES_171F3EA else bad)(f"v0.50 commit touches its declared 4 files ({len(files_50)} seen)")
files_51 = set(l for l in git_txt("show", "--name-only", "--format=", D_RECORD).splitlines() if l.strip())
(ok if files_51 == FILES_1061878 else bad)(f"v0.51 commit touches its declared 12 files ({len(files_51)} seen)")
(ok if git_txt("show", "--name-only", "--format=", D_RECORD).count("machine-corner-grid/machine-corner-grid.jl") == 0
 else bad)("v0.51 fold touches no rendered plate byte")

print("[2] the fold surfaces in the built copy")
(ok if dtext.count("Draft v0.51") == 1 else bad)("copy head line reads Draft v0.51 once")
for s in ("v0.37", "v0.38", "v0.39", "v0.40", "v0.41", "v0.42", "v0.43", "v0.44", "v0.45", "v0.46", "v0.47", "v0.48", "v0.49", "v0.50"):
    (ok if dtext.count(s) == 0 else bad)(f"copy reads zero '{s}' marks")
for name, s in [("plainer beam", "The team sizes the beam for a bounded generator load step: twice the nominal load (NR-048)."),
                ("plainer lull", "A low-wind lull is harmless under the load law."),
                ("plainer refusal", "The team refuses to ease k as the high-wind substitute.")]:
    (ok if dn.count(nrm(s)) == 1 else bad)(f"copy reads the {name} once")
for s in ("The beam sizes on", "benign under the load law", "refuses k easing"):
    (ok if dtext.count(s) == 0 else bad)(f"copy reads zero old kMppt form '{s}'")
(ok if dtext.count("Figure seated") == 0 else bad)("raw seat markers read zero in the copy")
corner_bits = [
    ("corner plain caption", "The four corner designs show how widely the machine changes across the search field, from multi-line two-rotor stacks to single-rotor cones."),
    ("corner technical lead", "Four panels show the nearest feasible design to each corner of the [1,99] percentile window of the certified PC1-PC2 projection (NR-044, NR-051)."),
    ("corner picks", "The picks read i1-g13-i1, i1-g7-i7, i2-g21-i4 and i3-g26-i8."),
    ("corner objectives", "Their search objectives read 60.646, 58.864, 33.704 and 33.812 kg-equivalent at 3 dp."),
    ("corner shared scale", "Each panel draws the built state of that genome at one shared scale."),
    ("corner typical", "The picks are typical machines for their corners, not optima."),
    ("corner above winner", "All four objectives sit above the winner value (NR-005)."),
    ("corner no-power", "It prints no power value and no airborne mass value."),
    ("corner appendix row", "The corner machines corner-grid-extract-2026-10-15-picks NR-044, NR-051 a4b4057"),
    ("corner register row", "The corner-grid picks (v13 5 kW screen): four machines, one per PC1-PC2 window corner, at the least feasible distance"),
    ("appendix count word", "One row per built exhibit. All eight read dataset commit dd3cc6a."),
]
for name, s in corner_bits:
    (ok if nrm(s) in dn else bad)(f"copy reads: {name}")
(ok if dtext.count("60.646") == 1 and dtext.count("58.864") == 1 and dtext.count("33.704") == 1
 and dtext.count("33.812") == 1 else bad)("copy reads the four 3 dp objectives once each")
(ok if dtext.count("corner-grid-extract-2026-10-15-picks") == 1 else bad)("copy reads the corner extract name once")
(ok if dtext.count("All eight read dataset commit") == 1 else bad)("copy reads 'All eight' once")
(ok if dtext.count("All seven read dataset commit") == 0 else bad)("copy reads zero 'All seven' forms")
(ok if dtext.count("a4b4057") == 2 else bad)(f"copy reads a4b4057 twice ({dtext.count('a4b4057')})")
(ok if dtext.count("machine-corner-grid") == 3 else bad)(f"copy reads the corner slug three times ({dtext.count('machine-corner-grid')})")
(ok if dtext.count("The corner machines") == 2 and dtext.count("The corner machines:") == 1 else bad)("copy reads the corner exhibit name twice (row and block head)")
(ok if dtext.count("The two plates map the same search in two views.") == 1 else bad)("copy reads the two-plates sentence once")
(ok if dtext.count("517a77bf032bec1c0cde4eea7db93fdbc47470c65c9d76e6c4e58249436a2568") == 1 else bad)("copy carries the corner png pin once")
for s, n, name in [("topmost ring", 9, "topmost ring"), ("topmost rotor ring", 2, "topmost rotor ring"),
                   ("Topmost ring radius", 1, "the table-row form (capital)"),
                   ("topmost ring radius", 3, "topmost ring radius"), ("topmost-ring", 1, "topmost-ring (hyphen)")]:
    c2 = dtext.count(s)
    (ok if c2 == n else bad)(f"copy count {name} reads {n} ({c2})")
c2 = len(re.findall(r"(?i)topmost", dtext))
(ok if c2 == 13 else bad)(f"copy count (?i)topmost reads 13 ({c2})")
(ok if dtext.count("The search found 508 feasible candidates in the searched space (NR-002).") == 1
 else bad)("copy reads the count sentence once")
(ok if dtext.count("The best performing one had a mean power of 5.309 kW.") == 1 else bad)("copy reads the founder winner sentence once")
(ok if dtext.count("Its airborne mass is 25.698 kilograms (NR-008, NR-018).") == 1 else bad)("copy reads the founder mass sentence once")
kg = dtext.count("25.698 kilograms")
(ok if kg == 4 else bad)(f"copy reads '25.698 kilograms' four times ({kg})")
(ok if dtext.count("The levers of Performance") == 1 else bad)("copy reads The levers of Performance once")
copy_bits = [
    ("2.1 radii", "topmost-ring and ground radii"),
    ("2.2.2 load", "The top-segment helix force reads about 1278 N/vertex (NR-048)."),
    ("3.3 capture", "The capture topmost ring reads 15.033 at the final step (NR-021)."),
    ("3.3 radius prose", "topmost ring radius is 4.580 metres and the ground radius 0.804 metres"),
    ("3.4 line", "The topmost rotor ring R6 governs the structural check at the winner operating point (NR-021)."),
    ("3.5 radius", "The topmost ring radius is 4.580 m and the ground radius is 0.804 m."),
    ("4.2 table", "landed on the topmost ring"),
    ("4.2 narrative", "the topmost ring (2026-08-26)"),
    ("4.2 tail", "one ring toward the top"),
    ("pointer line one", "The three movers carry their records. The bank derate is a calculated depowering of the main-rotor disc (NR-019, NR-020)."),
    ("pointer line two", "The window basis sits at section 2.2.2, and the gate set at section 2.4."),
    ("era row 1", "Before the bank derate Earlier winners read different bank-angle physics, so they are not directly comparable. Superseded as era record."),
    ("era row 2", "The bank-derate basis The measured bank derate applies to main-rotor disc power throughout (NR-019, NR-020). Current campaign basis."),
    ("era row 3a", "The pre-fold rows failed the floor (NR-027)."),
    ("era row 3b", "the folded class passes at 18.8 metres (NR-028)."),
    ("ledger lead", "Candidate entries. Each failure enters with its lesson."),
    ("ledger entry 1", "2026-08-14 inverted-taper divergence Geometry/decoder failure"),
    ("ledger entry 2", "2026-08-26 rotor-to-ring off-by-one"),
    ("ledger entry 3", "2026-08-22 blade-mass-law correction Model correction"),
    ("ledger entry 4", "2026-08-13 k-alignment fault Gain misalignment"),
    ("ledger entry 5", "2026-08-24 stale-gain re-gate Stale configuration"),
    ("ledger entry 6", "2026-08-22 FoS=Inf guard gap Gate near-miss"),
    ("ledger close 3", "Data voided, record kept."),
    ("ledger close 5", "The re-gate at the campaign gain returned 5.18 kilowatts."),
    ("ledger close 6", "Near-miss, no corrupted survivor found."),
    ("spelled form", "ran 5-kilowatt designs at the 50-kilowatt default gain"),
    ("round-5 base clause", "The base span reads 0.75 of the rotor radius, and the base chord reads 0.113 of it."),
    ("round-5 cone", "The shaft transition cone holds one fixed angle, 22 degrees, by construction."),
    ("round-5 cold path", "The campaign scored every design on the cold path (NR-012)."),
    ("round-5 slot", "The main-rotor slot, blade_scale_top, reads 0.82 and decodes to the single active rotor."),
    ("gate row power", "pass, P_end 5.314 kW. Margin +0.314 kW / +6.28 per cent"),
    ("gate row FoS", "pass, 15.0 minimum. 15.0 on 2.5, margin +12.5 / +500.0 per cent, 6.00 times"),
    ("gate row rope", "the warm path rejects healthy winners"),
]
for name, s in copy_bits:
    (ok if nrm(s) in dn else bad)(f"copy reads: {name}")
for name, s, n in [("22 degrees sites", "22 degrees", 3), ("shaft transition cone", "shaft transition cone", 3),
                   ("0.75", "0.75", 2), ("Tulloch", "Tulloch", 1), ("Jensen", "Jensen", 0),
                   ("lower-number key", "A lower number is better", 0)]:
    c2 = dtext.count(s)
    (ok if c2 == n else bad)(f"copy count {name} reads {n} ({c2})")
(ok if "Three lifting bridles" in dtext and dtext.count("Three lifting bridles") == 1 else bad)("copy reads the F1 caption form once")
(ok if dtext.count("Three bridles") == 0 and dtext.count("down the bridles") == 0 else bad)("copy reads zero old label forms")
(ok if dtext.count("and down the lifting bridles to the main rotor") == 1 else bad)("copy reads the load-path sentence once")
(ok if dtext.count("Machine winner") == 2 else bad)(f"copy reads 'Machine winner' twice ({dtext.count('Machine winner')})")
(ok if dtext.count("machine winner") == 0 else bad)("copy carries no lowercase marker form")
(ok if dtext.count("Machine winner hero") == 0 and dtext.count("machine winner hero") == 0 else bad)("copy reads zero 'Machine winner hero'")
(ok if dtext.count("machine-winner-hero") == 3 else bad)(f"copy reads the winner slug three times ({dtext.count('machine-winner-hero')})")
(ok if dtext.count("hero") == 3 and dtext.count("Hero") == 0 and dtext.count("hero image") == 0
 else bad)("copy 'hero' reads three times, all in the slug")
i33 = dtext.find("3.3 The winner")
jf = dtext.find("machine-winner-hero Figure (roster row 10)")
i34 = dtext.find("3.4 The levers of Performance")
i_land = dtext.find("pca-landscape Figure (roster row 20)")
i_atlas = dtext.find("pca-atlas Figure (roster row 21)")
i_corner = dtext.find("machine-corner-grid Figure (roster row 23)")
i_two = dtext.find("The two plates map the same search in two views.")
i_ev = dtext.find("machine-evolution-strip Figure (roster row 9)")
(ok if 0 <= i33 < jf < i34 else bad)("the winner frame sits inside section 3.3 in the copy")
(ok if 0 <= i34 < i_land < i_atlas < i_corner < i_two < i_ev else bad)(
    "the corner frame sits with the field pair, ahead of the two-plates block in section 3.4")
(ok if dtext.count("unresolved") == 0 else bad)("no unresolved notice")

print("[3] the appendix pins, the stamps, the embeds and the token census")
region_draft = draft.split("## Appendix: Figure provenance", 1)[1]
n_vals = 0
for exhibit, slug, labels in EXHIBITS:
    heads = list(re.finditer(HEADS, region_draft, flags=re.M))
    body = ""
    for k, mm in enumerate(heads):
        if mm.group(1) == exhibit:
            start = mm.end()
            end = heads[k + 1].start() if k + 1 < len(heads) else len(region_draft)
            body = region_draft[start:end]
    for label in labels:
        m = re.search(rf"^- `{re.escape(label)}` `([0-9a-f]{{64}})`$", body, flags=re.M)
        if m is None:
            bad(f"{slug}: {label} line missing")
            continue
        n_vals += 1
        pin = m.group(1)
        fn = [f for f in EXHIBIT_FILES[slug]
              if f.endswith("." + label)
              or (label == "ledger" and f.endswith("label-ledger.txt"))
              or (label == "checks" and f.endswith("checks.log"))][0]
        got = sha256_bytes(git_bytes("show", f"HEAD:{FIG_REL}/{slug}/{fn}"))
        hb = gitc("rev-parse", f"HEAD:{FIG_REL}/{slug}/{fn}")
        ob = gitc("rev-parse", f"{BRANCH}:{FIG_REL}/{slug}/{fn}")
        if got == pin and hb == ob and hb != "":
            ok(f"{slug}: {label} pinned == committed == HEAD == origin")
        else:
            bad(f"{slug}: {label} pin {pin[:12]} committed {got[:12]}")
(ok if n_vals == 32 else bad)(f"32 pinned values walked ({n_vals})")
app = region_draft
(ok if app.count("`1af63fc`") == 3 else bad)(f"appendix script cells: 1af63fc reads 3 ({app.count('`1af63fc`')})")
(ok if app.count("`9241b23`") == 1 else bad)(f"appendix script cells: 9241b23 reads 1 ({app.count('`9241b23`')})")
(ok if app.count("`74cfef9`") == 1 and app.count("`e23f226`") == 2 else bad)("appendix script cells: 74cfef9 x1, e23f226 x2")
(ok if app.count("`a4b4057`") == 1 else bad)(f"appendix script cells: a4b4057 reads 1 ({app.count('`a4b4057`')})")
(ok if "One row per built exhibit. All eight read dataset commit `dd3cc6a`." in draft else bad)("draft appendix counts eight exhibits")
(ok if draft.count("`post-95c385d_wind-authority` |") == 8 else bad)("draft appendix carries eight era cells")
(ok if "| The corner machines | `corner-grid-extract-2026-10-15-picks` | NR-044, NR-051 | `a4b4057` | `post-95c385d_wind-authority` |" in draft else bad)("draft appendix corner row reads exact")
(ok if "The corner machines:\n\n- `png`" in draft else bad)("draft appendix corner block header reads")
CG_SHA = {
    "png": "517a77bf032bec1c0cde4eea7db93fdbc47470c65c9d76e6c4e58249436a2568",
    "svg": "b2e4055d39b7ff72d1e10ea11f59d3bbc8af145ef8a30dc83b7016530b4de0b2",
    "pdf": "298a0f8e4e674dc8e13b64715ee0dfd383e7671d9f3c262a376abe7d5b5114c6",
    "checks": "e6bcfca931d36089dd2a8d6e9c8414fb49230c0d2110717176cf1e0ae385ffbe",
}
for name, sha in CG_SHA.items():
    (ok if f"- `{name}` `{sha}`" in region_draft else bad)(f"draft appendix corner hash line {name} reads")
mk = draft.splitlines()[634]
(ok if mk == MARKER23 else bad)("draft marker line 635 reads the exact marker form")
(ok if draft.count(MARKER23) == 1 else bad)("draft carries one row-23 marker")
(ok if set(re.findall(r"NR-\d+", MARKER23)) == {"NR-044", "NR-051"} else bad)("the marker cites exactly NR-044 and NR-051")
blk = draft[draft.find("The two plates map the same search in two views."):draft.find("\n### 3.5 The evolution story")]
(ok if hashlib.md5(blk.encode()).hexdigest() == FROZEN_MD5 else bad)("draft frozen levers block md5 holds")
SEAT_ORDER = ["system-anatomy", "machine-winner-hero", "ring-utilisation", "twist-limit",
              "pca-landscape", "pca-atlas", "machine-corner-grid", "machine-evolution-strip"]
seats = re.findall(r"\[Figure seated: figure-map row (\d+) \(([^,]+), slug `([^`]+)`\)", draft)
(ok if len(seats) == 8 and [s[2] for s in seats] == SEAT_ORDER else bad)("draft seat census reads eight in order")
exp_tok = Counter()
for exhibit, slug, labels in EXHIBITS:
    man = json.loads((ROOT / FIG_REL / slug / "manifest.json").read_text())
    stm = manifest_stamp(man)
    rowm = re.search(rf"\| {re.escape(exhibit)} .*?`([0-9a-f]{{7,40}})` \|", app)
    if rowm:
        exp_tok[rowm.group(1)] += 1
    sm = re.search(r"script ([0-9a-f]{7})", stm)
    if sm:
        exp_tok[sm.group(1)] += 1
for tok, n in sorted(exp_tok.items()):
    c2 = dtext.count(tok)
    (ok if c2 == n else bad)(f"copy token census {tok}: {c2} == expected {n}")
(ok if exp_tok.get("a4b4057") == 2 and exp_tok.get("1af63fc") == 4 and exp_tok.get("9241b23") == 2
 else bad)(f"token census reads a4b4057 x2, 1af63fc x4, 9241b23 x2 ({dict(exp_tok)})")
(ok if dtext.count("d243b37") == 0 and dtext.count("9cecee3") == 0 else bad)("copy reads zero d243b37/9cecee3 marks")
stamps_ok = 0
for exhibit, slug, labels in EXHIBITS:
    man = json.loads((ROOT / FIG_REL / slug / "manifest.json").read_text())
    stn = nrm("Source: " + manifest_stamp(man))
    valid = 0
    for m in re.finditer(re.escape(stn), dn):
        if dn[m.end():m.end() + 1] != ",":
            valid += 1
    if valid == 1:
        stamps_ok += 1
    else:
        bad(f"copy stamp missing or duplicated ({slug}): {stn[:80]} valid {valid}")
(ok if stamps_ok == 8 else bad)(f"eight stamps match their manifests ({stamps_ok})")
(ok if dtext.count("Source: ") == 8 else bad)(f"eight stamps read ({dtext.count('Source: ')})")
(ok if dn.count("data dd3cc6a · script a4b4057 · rows NR-044, NR-051") == 1 else bad)("copy reads the corner stamp once")
for f in FRAMES:
    (ok if dtext.count(f) == 1 else bad)(f"frame reads once: {f[:56]}")
(ok if dtext.count("Figure (") == 8 else bad)(f"eight figure frames read ({dtext.count('Figure (')})")
media = sorted(sha256_bytes(git_bytes("show", f"HEAD:{FIG_REL}/{p}")) for p in KIT_PNGS)
embedded = sorted(hashlib.sha256(z.read(n)).hexdigest() for n in z.namelist() if "media/" in n and n.endswith(".png"))
(ok if len(embedded) == 8 else bad)(f"eight media entries read ({len(embedded)})")
(ok if media == embedded else bad)("copy embeds the delivered bytes on all eight exhibits")
corner_pin = "517a77bf032bec1c0cde4eea7db93fdbc47470c65c9d76e6c4e58249436a2568"
corner_media = [hashlib.sha256(z.read(n)).hexdigest() for n in z.namelist()
                if "media/" in n and n.endswith(".png") and hashlib.sha256(z.read(n)).hexdigest() == corner_pin]
(ok if len(corner_media) == 1 else bad)("the eighth media entry is the corner plate at the delivered bytes")

print("[4] the register appendix and the retired-word holds")
i_reg = dtext.find("Data register (cited rows)")
i_build = dtext.find("Build record (builder output)")
(ok if 0 < i_reg < i_build else bad)("appendix markers read")
region_ids = sorted(set(re.findall(r"NR-\d{3}", dtext[i_reg:i_build])))
ids_head = sorted({m.group(1) for m in re.finditer(r"^\| (NR-\d{3})", reg_head, flags=re.M)})
raw_rows = len(re.findall(r"^\| NR-\d{3}", reg_head, flags=re.M))
(ok if len(ids_head) == 51 else bad)(f"register at HEAD reads 51 ids ({len(ids_head)})")
if raw_rows != len(ids_head):
    note(f"register reads {raw_rows} row lines for {len(ids_head)} ids")
cited = sorted(set(ids_head) - set(UNCITED8))
(ok if len(cited) == 43 else bad)(f"cited set reads 43 ({len(cited)})")
(ok if region_ids == cited else bad)(f"copy register appendix == cited set ({len(region_ids)} ids)")
for u in UNCITED8:
    (ok if u not in region_ids else bad)(f"uncited {u} stays out")
(ok if "NR-051" in region_ids else bad)("NR-051 enters the appendix set")
(ok if "NR-019" in region_ids and "NR-020" in region_ids else bad)("NR-019 and NR-020 enter the appendix set")
hits97 = [m.start() for m in re.finditer(re.escape("14.97"), dtext)]
(ok if len(hits97) == 1 and all(i_reg <= h < i_build for h in hits97) else bad)(
    f"14.97-class prints once, inside the register appendix ({len(hits97)})")
for name, s, n in [("full-precision 14.971...", "14.971791422208508", 0), ("guarded 3.816", "3.816", 0),
                   ("15.0", "15.0", 14), ("15.033", "15.033", 3), ("14.972", "14.972", 1),
                   ("27.3635412663488", "27.3635412663488", 2), ("27.364", "27.364", 11)]:
    c2 = dtext.count(s)
    (ok if c2 == n else bad)(f"copy display form {name} reads {n} ({c2})")
(ok if not re.findall(r"27\.363(?!\d)", dtext) else bad)("guarded rounded 27.363 reads zero")
for s, name in [("14.972", "NR-009 row form"), ("27.364 (found gen 26)", "NR-005 value"),
                ("1.4994019682084492 (quote 1.499)", "NR-043 span"), ("2.4341173109692225", "NR-050 r_rotor"),
                ("cone_slope_deg 22.0", "NR-049 cone value"), ("bank_bot 22\u00b0", "NR-011 bank form")]:
    (ok if s in dtext[i_reg:i_build] else bad)(f"register appendix: {name}")
hub_word = [m for m in re.finditer(r"(?i)\bhub\b", dtext)]
hub_host = [m for m in hub_word if m.start() < i_reg or m.start() >= i_build]
(ok if len(hub_word) == 5 else bad)(f"the retired word reads 5 as a word ({len(hub_word)})")
(ok if not hub_host else bad)(f"the word reads zero outside the register appendix ({len(hub_host)})")
hub_ids = [m for m in re.finditer(r"(?i)(r_hub|blade_hub_radius)", dtext)]
(ok if len(hub_ids) == 2 else bad)(f"the two identifier holds read ({len(hub_ids)})")
(ok if dtext.count("Hub") == 0 else bad)(f"capitalised Hub reads zero ({dtext.count('Hub')})")
frag_bad = []
for rid in ("NR-021", "NR-030", "NR-032", "NR-048"):
    for l in reg_head.splitlines():
        if l.startswith(f"| {rid} "):
            for m in re.finditer(r"(?i)\bhub\b", l):
                frag = nrm(l[max(0, m.start() - 35):m.start() + 45].replace("|", " "))
                if frag not in dn:
                    frag_bad.append(f"{rid}: {frag[:60]}")
(ok if not frag_bad else bad)(f"every register hub-quote reads in the copy ({len(frag_bad)} bad)")

print("[5] the delta chain and the state anchors")
t49, _z49 = docx_text(V49_ARCHIVE)
t50, _z50 = docx_text(V50_ARCHIVE)
t50n = nrm(t50)
(ok if md5_bytes(V49_ARCHIVE.read_bytes()) == V49_MD5 else bad)("the v0.49 archive reads its declared md5")
(ok if t49.count("v0.49") == 1 else bad)("the v0.49 build reads its version mark")
(ok if t49.count("The team sizes the beam") == 0 and t49.count("machine-corner-grid") == 0 else bad)(
    "the v0.49 build reads zero v0.50/v0.51 forms")
(ok if t49.count("Three lifting bridles") == 1 and t49.count("Machine winner") == 2 and t49.count("hero image") == 0
 else bad)("the v0.49 build holds the relabel and winner forms")
(ok if md5_bytes(V50_ARCHIVE.read_bytes()) == V50_MD5 else bad)("the v0.50 archive reads its declared md5")
(ok if t50.count("v0.50") == 1 else bad)("the v0.50 build reads its version mark")
for s in ("The team sizes the beam for a bounded generator load step", "A low-wind lull is harmless under the load law",
          "The team refuses to ease k as the high-wind substitute"):
    (ok if t50n.count(nrm(s)) == 1 else bad)(f"the v0.50 build reads its plainer form once: {s[:40]}")
(ok if t50.count("machine-corner-grid") == 0 and t50.count("60.646") == 0 else bad)("the v0.50 build reads zero corner forms")
(ok if "42 cited, every one signed (51 signed rows total)" in t50 else bad)("the v0.50 build record reads 42 cited")
(ok if "Seats resolved: 7 of 7" in t50 else bad)("the v0.50 build record reads seven seats")
(ok if "Built: 2026-10-15T15:40:01Z" in t50 else bad)("the v0.50 build stamp reads 15:40:01Z")
for rel, needle, name in [
        ("docs/reporting/room-responses/figures-images-diagrams-2026-10-15-corner-machines-fold.md",
         COPY_MD5, "figures fold receipt names the copy md5"),
        ("docs/reporting/room-responses/science-validator-2026-10-15-corner-grid-register-read.md",
         "74aa4c02", "science-validator receipt names the copy"),
        ("docs/reporting/room-responses/author-2026-10-15-v050-kmppt-plain.md",
         V50_MD5, "author v0.50 receipt names the v0.50 copy md5"),
        ("docs/reporting/room-responses/author-2026-10-15-v050-kmppt-plain.md",
         "draft-171f3ea-20261015-154001.docx", "author v0.50 receipt names the v0.50 archive"),
        ("scratch/fig_cg_fold_rebuild_check.log", COPY_MD5, "figures rebuild check log names the copy md5")]:
    body = (ROOT / rel).read_text(encoding="utf-8")
    (ok if needle in body else bad)(name)
(ok if "v0.51 pass by @fig-img-diagrams (2026-10-15)." in trk else bad)("tracker carries the v0.51 entry")
(ok if "v0.50 pass by @author (2026-10-15)." in trk else bad)("tracker holds the v0.50 entry")
(ok if "- **v42 (2026-10-15):** the corner machines fold into the report." in map_head else bad)("map carries delta v42")
(ok if tip == up else bad)("final: tip == origin")

print("[6] the intermediate build archive (observed and classified)")
tm, _zm = docx_text(MID_ARCHIVE)
(ok if md5_bytes(MID_ARCHIVE.read_bytes()) == MID_MD5 else bad)("the intermediate archive reads its observed md5")
(ok if tm.count("v0.51") == 1 else bad)("the intermediate archive reads version v0.51")
(ok if "Draft: 171f3ea" in tm else bad)("the intermediate archive record cell reads 171f3ea")
(ok if "43 cited, every one signed (51 signed rows total)" in tm else bad)("the intermediate archive reads 43 cited")
(ok if "Seats resolved: 8 of 8" in tm else bad)("the intermediate archive reads eight seats")
(ok if "Built: 2026-10-15T15:49:54Z" in tm else bad)("the intermediate archive stamp reads 15:49:54Z")
media_mid = [n for n in _zm.namelist() if "media/" in n]
(ok if len(media_mid) == 8 else bad)(f"the intermediate archive carries eight media entries ({len(media_mid)})")
(ok if md5_bytes(MID_ARCHIVE.read_bytes()) != COPY_MD5 else bad)("the intermediate archive is not the delivered copy")
refs = [l for l in git_txt("grep", "-l", "draft-171f3ea-20261015-154954", "HEAD", "--",
                           "docs", "handovers", "scratch").splitlines()
        if not l.endswith("aero-validator-2026-10-15-v051-copy-counterread.md")]
(ok if refs == [] else bad)(f"no record names the intermediate archive ({len(refs)} refs)")
note("classified: an intermediate build from 27 s before the fold commit; no record names it; harmless")
stamp_pairs = [
    ("draft-8169e36-20261015-144342.docx", "14:43:42", "2026-10-15T14:43:42Z", True),
    ("draft-171f3ea-20261015-154001.docx", "15:40:01", "2026-10-15T15:40:01Z", True),
    ("draft-171f3ea-20261015-154954.docx", "15:49:54", "2026-10-15T15:49:54Z", True),
    ("draft-1061878-20261015-155027.docx", "15:50:27", "2026-10-15T15:50:26Z", False),
]
for fname, name_stamp, block_stamp, same in stamp_pairs:
    t, _ = docx_text(OUT / fname)
    m = re.search(r"Built: ([0-9T:\-]+Z)", t)
    got = m.group(1) if m else "?"
    if same:
        (ok if got == block_stamp and block_stamp[11:19] == name_stamp else bad)(
            f"stamp pair {fname}: name {name_stamp} == block {got[11:19]}")
    else:
        (ok if got == block_stamp else bad)(
            f"stamp pair {fname}: name {name_stamp} vs block {got[11:19]} (the one-second split)")

print(f"\nchecks: {OK + FAIL}  ok: {OK}  fail: {FAIL}")
print("AV_V051_DONE" if FAIL == 0 else "AV_V051_FAIL")
sys.exit(1 if FAIL else 0)

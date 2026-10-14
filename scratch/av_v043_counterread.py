#!/usr/bin/env python3
"""The v0.43 copy counter-read (aero-validator, 2026-10-14).

Queue routing: sweep 29 and the v0.43 receipt route the counter-read of the
round-5 wording set; the figures seat routes the caption text; the science
validator opens NR-049 and NR-050 to this desk. This pass proves the
delivered copy at md5 3374a638 on its own bytes:

  [0] identity and freshness: copy md5, archived build, build record,
      moved blobs, build inputs, register ledger;
  [1] the fold census (v0.41 to v0.43): the two movers, the net diff read
      line for line, the tracker entries, sections 4 onward stay put;
  [2] the v0.43 forms on the draft: the base clause, the cone sentences,
      the cold-path line, the swing reading, the lifter lines, the slot
      names, the gate table, the guards;
  [3] the seven seated markers, the frozen levers block, the appendix
      pins recompute (28 values), byte-stable anchors;
  [4] the copy prints the pins, resolves the frames, embeds the bytes,
      reads the round-5 forms and the caption takeaways, guards hold;
  [5] the caption kits and the map delta;
  [6] the two signed rows counter-read (NR-049, NR-050): forms, digits,
      arithmetic, append-only ledger;
  [7] state anchors (receipts, tracker, map, routing status).

Reads committed bytes (git objects) and the delivered copy only.
Runs no simulator. Nothing rewrites a committed file.
"""
import hashlib
import json
import re
import subprocess
import sys
import zipfile
from math import radians, tan
from pathlib import Path

ROOT = Path("/home/rod/Documents/GitHub/KiteTurbineDynamics.jl")
DRAFT_REL = "docs/reporting/drafts/2026-10-08-report-first-draft.md"
TRACKER_REL = "docs/reporting/draft-tracker.md"
REG_REL = "docs/reporting/numbers-register.md"
DOCX = ROOT / "scratch/report-pdf-build/draft-live.docx"
ARCHIVE = ROOT / "scratch/report-pdf-build/draft-e5541e9-20261014-200839.docx"
BUILD_RECORD = ROOT / "scratch/report-pdf-build/build-record-docx.txt"
BLOCK = ROOT / "scratch/sw_levers_reading_block.md"
BASE_PREV = "e8159b0"          # draft v0.41, last fully read state
DRAFT_REV = "e5541e9"          # draft v0.43 pin
REG_REF = "94aa219"            # register edit carrying NR-049 and NR-050
REG_ORIG = "a7d09eb"           # register ref at the v0.41 counter-read
COPY_MD5 = "3374a638aa89e61e9957193dffc1536d"
BLOCK_MD5 = "7bbd964db09d2b33269ce5cb8c334054"
PIN = "e4ff3c1"
LEVERS_PIN = "d6d4db9"
HERO_ANCHOR = "e8159b0"

ADDED = [
    'Internal engineering report. Draft v0.43. Date 2026-10-14.',
    'The base span reads 0.75 of the rotor radius, and the base chord reads 0.113 of it.',
    'The power sizing sets the radius for the rotor at its local wind speed (NR-050).',
    'The shaft transition cone holds one fixed angle, 22 degrees, by construction.',
    'It is not a search gene (NR-049).',
    'The campaign scored every design on the cold path (NR-012).',
    '',
    'This campaign is the first screen after the physics-validation era.',
    'Larger and wider campaigns sit ahead.',
    '',
    'The machine held a steady operating point through the measurement window.',
    '| Gate | Threshold | Winner outcome | Margin | Source |',
    '|---|---|---|---|---|',
    '| Power floor | 5.0 kW | pass, P_end 5.314 kW. Margin +0.314 kW / +6.28 per cent | NR-008, NR-027, NR-039 |',
    '| Structural FoS floor | 2.5 | pass, 15.0 minimum. 15.0 on 2.5, margin +12.5 / +500.0 per cent, 6.00 times | NR-009, NR-015 |',
    '| Clearance | blade-tip gate | pass, 5.468 m, margin +3.968 m | +264.5 per cent, 3.65 times | NR-042 |',
    '| Twist | per-segment limit δcrit | pass, all five segments within limit | Least margin at S1. It reads +64.913 deg / +65.7 per cent, 2.91 times | NR-022 |',
    '| Torsional capacity | capacity/demand | least margin 2.03 at S1 | +102.9 per cent above unity, 2.03 times | NR-040 |',
    '| Rope break | none on the window | pass on the cold path | the warm path rejects healthy winners | NR-012, NR-013 |',
    'Without modulation, each weather band would need its own single kite.',
    'That kite would reach giant sizes and be too hard to handle.',
    'The report also assumes a staged launch of the stack.',
    'A staged launch is easier to handle than one giant kite.',
    '',
    'The winner genome contains two blade-scale slots.',
    'The main-rotor slot, `blade_scale_top`, reads 0.82 and decodes to the single active rotor.',
    'The second-rotor slot, `blade_scale_bottom`, reads 0.20 and stays inactive',
    'The second bank slot holds `bank_bottom`. It reads 22 degrees at the top of its search box.',
    'It does not decode to a physical rotor at a rotor count of one (NR-011, NR-017).',
    'The shaft transition cone holds one fixed angle, 22 degrees,',
    'in every machine of the campaign (NR-049).',
    'A later campaign can vary it.',
    '',
]
REMOVED = [
    'Internal engineering report. Draft v0.41. Date 2026-10-14.',
    '| Gate | Threshold | Winner outcome | Source |',
    '|---|---|---|---|',
    '| Power floor | 5.0 kW | pass, P_mean 5.309 kW | NR-008, NR-027, NR-039 |',
    '| Structural FoS floor | 2.5 | pass, 15.0 minimum | NR-009, NR-015 |',
    '| Clearance | blade-tip gate | pass | NR-036 |',
    '| Twist | per-segment limit δcrit | pass, all five segments within limit | NR-022 |',
    '| Rope break | none on the window | pass on the cold path | NR-012, NR-013 |',
    'Without modulation, each weather band needs its own kite, up to a giant.',
    'The winner genome contains two blade-scale slots. Slot 1 reads 0.82 and',
    'decodes to the single active rotor. Slot 2 reads 0.20 and stays inactive',
    'A second bank slot reads 22 degrees. It does not decode to a physical',
    'rotor at a count of one (NR-011).',
]
TRACKER_ADDED = [
    'v0.42 pass by @author (2026-10-14).',
    'This pass folds the gate-margin column at section 3.3 (AU9).',
    'The gate table gains the margin column and the torsional capacity row.',
    'The power-floor and clearance cells take their corrected forms.',
    'The factor of safety row takes its display forms.',
    'No signed value changes.',
    '',
    'v0.43 pass by @author (2026-10-14).',
    'This pass folds the round-5 wording set, keyed on the NR-049 and NR-050 reads.',
    'The blade-scale base, the cone statement and the slot names land.',
    'The cold-path line, the swing reading and the lifter rationale land.',
    'The campaign-scale context and the cone lead line land.',
    'No value moves.',
    '',
]
MARKERS = [
    "[Figure seated: figure-map row 2 (system anatomy plate, slug `system-anatomy`). Values cite NR-011, NR-017 and NR-043.]",
    "[Figure seated: figure-map row 10 (machine winner hero, slug `machine-winner-hero`). Values cite NR-011, NR-017, NR-021, NR-022 and NR-043.]",
    "[Figure seated: figure-map row 6 (ring utilisation plate, slug `ring-utilisation`). Values cite NR-021.]",
    "[Figure seated: figure-map row 7 (twist limit plate, slug `twist-limit`). Values cite NR-022 and NR-023.]",
    "[Figure seated: figure-map row 20 (the levers landscape, slug `pca-landscape`). Values cite NR-001, NR-005, NR-006, NR-044 and NR-045.]",
    "[Figure seated: figure-map row 21 (the parameter atlas, slug `pca-atlas`). Values cite NR-001, NR-005, NR-006 and NR-044.]",
    "[Figure seated: figure-map row 9 (machine evolution strip, slug `machine-evolution-strip`). Values cite NR-005, NR-006, NR-011 and NR-036.]",
]
FRAMES = [
    "system-anatomy Figure (roster row 2) · system-anatomy",
    "machine-winner-hero Figure (roster row 10) · machine-winner-hero",
    "ring-utilisation Figure (roster row 6) · ring-utilisation",
    "twist-limit Figure (roster row 7) · twist-limit",
    "pca-landscape Figure (roster row 20) · pca-landscape",
    "pca-atlas Figure (roster row 21) · pca-atlas",
    "machine-evolution-strip Figure (roster row 9) · machine-evolution-strip",
]
EXHIBITS = [
    ("Ring utilisation plate", "ring-utilisation",
     ["ledger", "pdf", "png", "svg"]),
    ("Twist limit plate", "twist-limit",
     ["ledger", "pdf", "png", "svg"]),
    ("Machine evolution strip", "machine-evolution-strip",
     ["checks", "pdf", "png", "svg"]),
    ("System anatomy plate", "system-anatomy",
     ["checks", "ledger", "pdf", "png"]),
    ("Levers landscape", "pca-landscape",
     ["ledger", "pdf", "png", "svg"]),
    ("Parameter atlas", "pca-atlas",
     ["ledger", "pdf", "png", "svg"]),
    ("Machine winner hero", "machine-winner-hero",
     ["checks", "pdf", "png", "svg"]),
]
EXHIBIT_FILES = {
    "ring-utilisation": ["ring-utilisation.png", "ring-utilisation.svg",
                         "ring-utilisation.pdf", "label-ledger.txt"],
    "twist-limit": ["twist-limit.png", "twist-limit.svg",
                    "twist-limit.pdf", "label-ledger.txt"],
    "machine-evolution-strip": ["machine-evolution-strip.png",
                                "machine-evolution-strip.svg",
                                "machine-evolution-strip.pdf", "checks.log"],
    "system-anatomy": ["system-anatomy.png", "system-anatomy.pdf",
                       "label-ledger.txt", "checks.log"],
    "pca-landscape": ["pca-landscape.png", "pca-landscape.svg",
                      "pca-landscape.pdf", "label-ledger.txt"],
    "pca-atlas": ["pca-atlas.png", "pca-atlas.svg",
                  "pca-atlas.pdf", "label-ledger.txt"],
    "machine-winner-hero": ["machine-winner-hero.png",
                            "machine-winner-hero.svg",
                            "machine-winner-hero.pdf", "checks.log"],
}
KIT_PNGS = ["ring-utilisation/ring-utilisation.png",
            "twist-limit/twist-limit.png",
            "machine-evolution-strip/machine-evolution-strip.png",
            "system-anatomy/system-anatomy.png",
            "pca-landscape/pca-landscape.png",
            "pca-atlas/pca-atlas.png",
            "machine-winner-hero/machine-winner-hero.png"]
UNC = ["NR-019", "NR-020", "NR-024", "NR-031", "NR-033", "NR-034",
       "NR-035", "NR-037", "NR-038", "NR-041"]

OK = 0
FAIL = 0


def ok(msg):
    global OK
    OK += 1
    print(f"  ok   {msg}")


def bad(msg):
    global FAIL
    FAIL += 1
    print(f"  FAIL {msg}")


def git_bytes(*args):
    return subprocess.run(["git", "-C", str(ROOT), *args],
                          capture_output=True).stdout


def git_txt(*args):
    return git_bytes(*args).decode("utf-8")


def gitc(*args):
    return git_txt(*args).strip()


def gshow(rev_path):
    return git_bytes("show", rev_path)


def sha256_bytes(b):
    return hashlib.sha256(b).hexdigest()


def nrm(t):
    t = t.replace("`", "")
    t = re.sub(r"\s+", " ", t)
    return re.sub(r"\s+([.,:;])", r"\1", t)


z = zipfile.ZipFile(DOCX)
xml = z.read("word/document.xml").decode("utf-8")
dtext = re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", xml))
dn = nrm(dtext)
rec = BUILD_RECORD.read_text(encoding="utf-8")
draft = git_txt("show", f"{DRAFT_REV}:{DRAFT_REL}")
draft_head = git_txt("show", f"HEAD:{DRAFT_REL}")
dnk = nrm(draft_head)
tracker = git_txt("show", f"HEAD:{TRACKER_REL}")
reg_md = git_txt("show", f"HEAD:{REG_REL}")
regn = re.sub(r"\s+", " ", reg_md)
tip = gitc("rev-parse", "--short", "HEAD")
up = gitc("rev-parse", "--short", "origin/bank-derate-cos2p65")
md5 = hashlib.md5(DOCX.read_bytes()).hexdigest()
print(f"[0] v0.43 counter-read   tip {tip}   origin {up}   "
      f"record {DRAFT_REV}   copy md5 {md5}")

print("[0] identity and freshness")
(ok if md5 == COPY_MD5 else bad)("copy md5 reads the declared value")
(ok if md5 == hashlib.md5(ARCHIVE.read_bytes()).hexdigest() else bad)(
    "copy byte-identical to its archived build")
for s, name in [("Draft: `e5541e9`", "build record names draft e5541e9"),
                ("Seats resolved: 7 of 7", "build record: seven seats"),
                ("checker exit 0", "build record: checker exit 0"),
                ("Built: 2026-10-14T20:08:39Z", "docx build stamp 20:08:39Z"),
                ("file at `94aa219`", "build record refs register 94aa219"),
                ("40 cited, every one signed (50 signed rows total)",
                 "build record: 40 cited of 50 signed")]:
    (ok if s in rec else bad)(name)
unc_m = re.search(r"uncited: ([^\u2014\n]+)", rec)
unc_ids = sorted(set(re.findall(r"NR-\d{3}", unc_m.group(1)))) if unc_m else []
(ok if unc_ids == sorted(UNC) else bad)(
    f"build record uncited list reads 10 ids ({len(unc_ids)})")
for rev, rel, name in [(DRAFT_REV, DRAFT_REL, "draft"),
                       (DRAFT_REV, TRACKER_REL, "tracker")]:
    a = gitc("rev-parse", f"{rev}:{rel}")
    b = gitc("rev-parse", f"HEAD:{rel}")
    c = gitc("rev-parse", f"origin/bank-derate-cos2p65:{rel}")
    (ok if a and a == b == c else bad)(
        f"{name} blob reads {rev} == HEAD == origin")
a = gitc("rev-parse", f"{REG_REF}:{REG_REL}")
b = gitc("rev-parse", f"HEAD:{REG_REL}")
c = gitc("rev-parse", f"origin/bank-derate-cos2p65:{REG_REL}")
(ok if a and a == b == c else bad)(
    f"register blob reads {REG_REF} == HEAD == origin")
d = gitc("diff", "--name-only", DRAFT_REV, "HEAD", "--",
         "docs/reporting/drafts", "docs/reporting/draft-tracker.md",
         "docs/reporting/numbers-register.md", "docs/reporting/figures")
(ok if d == "" else bad)(
    f"build inputs carry zero diff from {DRAFT_REV} to the tip ({d!r})")
r = gitc("diff", "--numstat", REG_ORIG, "HEAD", "--", REG_REL)
(ok if r.split()[:2] == ["142", "0"] else bad)(
    f"register additions since {REG_ORIG} read append-only ({r})")
r2 = gitc("diff", "--numstat", f"{REG_REF}^", REG_REF, "--", REG_REL)
(ok if r2.split()[:2] == ["110", "0"] else bad)(
    f"the {REG_REF} block reads 110/0 ({r2})")
(ok if tip == up else bad)("the read tip reads the same as origin")

print("[1] the fold census (v0.41 to v0.43): two movers, nothing else")
movers = gitc("log", "--format=%h", f"{BASE_PREV}..HEAD", "--",
              "docs/reporting/drafts", "docs/reporting/draft-tracker.md")
(ok if sorted(movers.split()) == sorted([DRAFT_REV[:7], "38c77f8"]) else bad)(
    f"the draft and tracker move at exactly two commits ({movers.split()})")
diff = git_txt("diff", BASE_PREV, "HEAD", "--", DRAFT_REL)
added = [l[1:] for l in diff.splitlines()
         if l.startswith("+") and not l.startswith("+++")]
removed = [l[1:] for l in diff.splitlines()
           if l.startswith("-") and not l.startswith("---")]
(ok if added == ADDED else bad)(
    f"added lines read the frozen set, line for line ({len(added)})")
(ok if removed == REMOVED else bad)(
    f"removed lines read the frozen set, line for line ({len(removed)})")
tdiff = git_txt("diff", BASE_PREV, "HEAD", "--", TRACKER_REL)
tadd = [l[1:] for l in tdiff.splitlines()
        if l.startswith("+") and not l.startswith("+++")]
trem = [l[1:] for l in tdiff.splitlines()
        if l.startswith("-") and not l.startswith("---")]
(ok if tadd == TRACKER_ADDED and trem == [] else bad)(
    f"tracker takes the two entries alone ({len(tadd)} added, {len(trem)} removed)")
def tail_of(s):
    i = s.find("## 4 Discussion")
    return s[i:] if i >= 0 else None


tail_prev = tail_of(git_txt("show", f"{BASE_PREV}:{DRAFT_REL}"))
tail_now = tail_of(draft_head)
(ok if tail_prev is not None and tail_prev == tail_now else bad)(
    "sections 4 to the end hold byte-identical against v0.41")
(ok if draft_head == draft else bad)(
    "the draft at the pin reads the draft at the tip")

print("[2] the v0.43 forms on the draft")
forms = [
    ("base clause", "The base span reads 0.75 of the rotor radius, and the base chord reads 0.113 of it."),
    ("base source line", "The power sizing sets the radius for the rotor at its local wind speed (NR-050)."),
    ("cone sentence one", "The shaft transition cone holds one fixed angle, 22 degrees, by construction."),
    ("cone sentence two", "It is not a search gene (NR-049)."),
    ("cold-path line", "The campaign scored every design on the cold path (NR-012)."),
    ("scale context", "This campaign is the first screen after the physics-validation era."),
    ("scale line", "Larger and wider campaigns sit ahead."),
    ("swing reading", "The machine held a steady operating point through the measurement window."),
    ("lifter line one", "Without modulation, each weather band would need its own single kite."),
    ("lifter line two", "That kite would reach giant sizes and be too hard to handle."),
    ("launch line one", "The report also assumes a staged launch of the stack."),
    ("launch line two", "A staged launch is easier to handle than one giant kite."),
    ("slot one name", "The main-rotor slot, `blade_scale_top`, reads 0.82 and decodes to the single active rotor."),
    ("slot two name", "The second-rotor slot, `blade_scale_bottom`, reads 0.20 and stays inactive"),
    ("bank slot name", "The second bank slot holds `bank_bottom`. It reads 22 degrees at the top of its search box."),
    ("bank slot close", "It does not decode to a physical rotor at a rotor count of one (NR-011, NR-017)."),
    ("strip cone line", "in every machine of the campaign (NR-049)."),
    ("strip lead line", "A later campaign can vary it."),
    ("names map", "The ODE path is `:cold`."),
    ("pin line", "Internal engineering report. Draft v0.43. Date 2026-10-14."),
]
for name, s in forms:
    (ok if draft.count(s) == 1 else bad)(f"draft reads once: {name}")
for name, s, n in [("22 degrees sites", "22 degrees", 3),
                   ("shaft transition cone", "shaft transition cone", 2),
                   ("bank_bottom", "bank_bottom", 1),
                   ("0.75", "0.75", 1),
                   ("0.113", "0.113", 1),
                   ("Tulloch", "Tulloch", 1),
                   ("Jensen", "Jensen", 0),
                   ("Tulloch and Jensen", "Tulloch and Jensen", 0)]:
    c = draft.count(s)
    (ok if c == n else bad)(f"draft count {name} reads {n} ({c})")
t_pos = draft.find("Tulloch")
for p in [m.start() for m in re.finditer("22 degrees", draft)]:
    seg = draft[max(0, p - 200):p + 200]
    (ok if "Tulloch" not in seg else bad)(
        "no Tulloch within 200 chars of a 22 site")
(ok if 0 < t_pos < draft.find("## 2") else bad)(
    "the standing Tulloch mention sits in section 1")
for name, s in [("old gate cell", "pass, P_mean"),
                ("old bank sentence", "A second bank slot reads 22 degrees"),
                ("old slot label 1", "Slot 1"),
                ("old slot label 2", "Slot 2"),
                ("old giant line", "up to a giant"),
                ("old pin", "Draft v0.41"),
                ("old pin 42", "Draft v0.42")]:
    c = draft.count(s)
    (ok if c == 0 else bad)(f"draft zero: {name} ({c})")
gate_rows = ["| Power floor | 5.0 kW | pass, P_end 5.314 kW. Margin +0.314 kW / +6.28 per cent | NR-008, NR-027, NR-039 |",
             "| Structural FoS floor | 2.5 | pass, 15.0 minimum. 15.0 on 2.5, margin +12.5 / +500.0 per cent, 6.00 times | NR-009, NR-015 |",
             "| Clearance | blade-tip gate | pass, 5.468 m, margin +3.968 m | +264.5 per cent, 3.65 times | NR-042 |",
             "| Twist | per-segment limit δcrit | pass, all five segments within limit | Least margin at S1. It reads +64.913 deg / +65.7 per cent, 2.91 times | NR-022 |",
             "| Torsional capacity | capacity/demand | least margin 2.03 at S1 | +102.9 per cent above unity, 2.03 times | NR-040 |",
             "| Rope break | none on the window | pass on the cold path | the warm path rejects healthy winners | NR-012, NR-013 |"]
for i, row in enumerate(gate_rows, 1):
    (ok if draft.count(row) == 1 else bad)(f"gate row {i} reads once")

print("[3] markers, freeze block, appendix pins, byte-stable anchors")
ms = re.findall(r"\[Figure seated:[^\]]*\]", draft_head)
(ok if len(ms) == 7 else bad)(f"draft carries seven seated markers ({len(ms)})")
for m in MARKERS:
    (ok if draft_head.count(m) == 1 else bad)(f"marker reads once: {m[:58]}")
lines = draft_head.splitlines()
lo = lines.index("### 3.3 The winner")
hi = lines.index("### 3.4 The levers")
midx = lines.index(MARKERS[1])
(ok if lo < midx < hi else bad)("the hero marker sits inside section 3.3")
blk = BLOCK.read_bytes()
(ok if hashlib.md5(blk).hexdigest() == BLOCK_MD5 else bad)(
    "the freeze block file md5 reads 7bbd964d")
(ok if draft_head.count(blk.decode()) == 1 else bad)(
    "the frozen levers block reads carried once in the draft")
btail = draft_head[draft_head.find(blk.decode()):][:len(blk.decode())].encode()
(ok if btail == blk else bad)("the draft-carried block bytes equal the file bytes")
print("  -- appendix pins --")
region = draft_head.split("## Appendix: Figure provenance", 1)[1]
blocks = {}
heads = list(re.finditer(
    r"^(Ring utilisation plate|Twist limit plate|Machine evolution strip"
    r"|System anatomy plate|Levers landscape|Parameter atlas"
    r"|Machine winner hero):$", region, flags=re.M))
for i, m in enumerate(heads):
    start = m.end()
    end = heads[i + 1].start() if i + 1 < len(heads) else len(region)
    blocks[m.group(1)] = region[start:end]
(ok if len(blocks) == 7 else bad)(f"appendix carries seven blocks ({len(blocks)})")
n_vals = 0
pins = []
for exhibit, slug, labels in EXHIBITS:
    body = blocks.get(exhibit, "")
    for label in labels:
        m = re.search(rf"^- `{re.escape(label)}` `([0-9a-f]{{64}})`$",
                      body, flags=re.M)
        if m is None:
            bad(f"{slug}: {label} line missing")
            continue
        n_vals += 1
        pin = m.group(1)
        fn = [f for f in EXHIBIT_FILES[slug]
              if f.endswith("." + label)
              or (label == "ledger" and f.endswith("label-ledger.txt"))
              or (label == "checks" and f.endswith("checks.log"))][0]
        got = sha256_bytes(gshow(f"HEAD:docs/reporting/figures/{slug}/{fn}"))
        head_blob = gitc("rev-parse", f"HEAD:docs/reporting/figures/{slug}/{fn}")
        orig_blob = gitc("rev-parse",
                         f"origin/bank-derate-cos2p65:docs/reporting/figures/{slug}/{fn}")
        same_blob = head_blob == orig_blob and head_blob != ""
        if got == pin and same_blob:
            ok(f"{slug}: {label} pinned == committed == HEAD == origin")
            pins.append((fn, pin))
        else:
            bad(f"{slug}: {label} pin {pin[:12]} committed {got[:12]} "
                f"blobs {head_blob[:9]}/{orig_blob[:9]}")
(ok if n_vals == 28 else bad)(f"28 pinned values walked ({n_vals})")
for slug, anchor in [("ring-utilisation", PIN), ("twist-limit", PIN),
                     ("pca-landscape", LEVERS_PIN), ("pca-atlas", LEVERS_PIN),
                     ("machine-winner-hero", HERO_ANCHOR)]:
    for fn in EXHIBIT_FILES[slug]:
        a = gitc("rev-parse", f"{anchor}:docs/reporting/figures/{slug}/{fn}")
        b = gitc("rev-parse", f"HEAD:docs/reporting/figures/{slug}/{fn}")
        (ok if a == b and a != "" else bad)(
            f"{slug}: {fn} byte-stable from {anchor}")

print("[4] the copy: pins, frames, rounds-five forms, takeaways, guards")
for fn, pin in pins:
    (ok if pin in dtext else bad)(f"copy prints the {fn} pin")
for f in FRAMES:
    (ok if dtext.count(f) == 1 else bad)(f"frame reads once: {f[:56]}")
(ok if dtext.count("Figure (") == 7 else bad)(
    f"seven figure frames read ({dtext.count('Figure (')})")
(ok if dtext.count("Figure seated") == 0 else bad)(
    "raw markers read zero in the copy")
copy_forms = [
    ("base clause", "The base span reads 0.75 of the rotor radius, and the base chord reads 0.113 of it."),
    ("base source line", "The power sizing sets the radius for the rotor at its local wind speed (NR-050)."),
    ("cone sentence one", "The shaft transition cone holds one fixed angle, 22 degrees, by construction."),
    ("cone sentence two", "It is not a search gene (NR-049)."),
    ("cold-path line", "The campaign scored every design on the cold path (NR-012)."),
    ("scale context", "This campaign is the first screen after the physics-validation era."),
    ("swing reading", "The machine held a steady operating point through the measurement window."),
    ("lifter line", "That kite would reach giant sizes and be too hard to handle."),
    ("launch line", "A staged launch is easier to handle than one giant kite."),
    ("slot one name", "The main-rotor slot, blade_scale_top, reads 0.82 and decodes to the single active rotor."),
    ("slot two name", "The second-rotor slot, blade_scale_bottom, reads 0.20 and stays inactive"),
    ("bank slot name", "The second bank slot holds bank_bottom. It reads 22 degrees at the top of its search box."),
    ("strip cone line", "in every machine of the campaign (NR-049)."),
    ("strip lead line", "A later campaign can vary it."),
    ("gate row power", "pass, P_end 5.314 kW. Margin +0.314 kW / +6.28 per cent"),
    ("gate row FoS", "pass, 15.0 minimum. 15.0 on 2.5, margin +12.5 / +500.0 per cent, 6.00 times"),
    ("gate row clearance", "pass, 5.468 m, margin +3.968 m"),
    ("gate row twist", "Least margin at S1. It reads +64.913 deg / +65.7 per cent, 2.91 times"),
    ("gate row capacity", "least margin 2.03 at S1"),
    ("gate row rope", "the warm path rejects healthy winners"),
    ("ring takeaway", "Every airborne ring passes its structural check with a wide margin."),
    ("twist takeaway", "The shaft passes its twist and torque checks along its whole length."),
    ("strip takeaway", "The search improves the machine at every recorded step, from the common seed to the campaign winner."),
]
for name, s in copy_forms:
    (ok if nrm(s) in dn else bad)(f"copy reads: {name}")
for name, s, n in [("22 degrees sites", "22 degrees", 3),
                   ("shaft transition cone", "shaft transition cone", 3),
                   ("0.75", "0.75", 2),
                   ("Tulloch", "Tulloch", 1),
                   ("Jensen", "Jensen", 0),
                   ("lower-number key", "A lower number is better", 0)]:
    c = dtext.count(s)
    (ok if c == n else bad)(f"copy count {name} reads {n} ({c})")
i_reg = dtext.find("Data register (cited rows)")
i_build = dtext.find("Build record (builder output)")
hits = [m.start() for m in re.finditer(re.escape("14.97"), dtext)]
in_reg = bool(hits) and all(i_reg <= h < i_build for h in hits)
(ok if len(hits) == 1 and in_reg else bad)(
    f"14.97-class prints once, inside the register appendix ({len(hits)})")
(ok if dtext.count("14.971791422208508") == 0 else bad)(
    "signed full precision reads internal")
for name, s, n in [("15.0", "15.0", 14), ("15.033", "15.033", 3),
                   ("14.972", "14.972", 1),
                   ("27.3635412663488", "27.3635412663488", 2),
                   ("27.364", "27.364", 11)]:
    c = dtext.count(s)
    (ok if c == n else bad)(f"copy display form {name} reads {n} ({c})")
(ok if not re.findall(r"27\.363(?!\d)", dtext) else bad)(
    "guarded rounded 27.363 reads zero")
(ok if dtext.count("3.816") == 0 else bad)("guarded 3.816 reads zero")
(ok if dtext.count("unresolved") == 0 else bad)("no unresolved notice")
(ok if dtext.count("Draft v0.43") == 1 else bad)("copy head line reads Draft v0.43")
for s in ("v0.37", "v0.38", "v0.39", "v0.40", "v0.41", "v0.42"):
    (ok if dtext.count(s) == 0 else bad)(f"copy reads zero '{s}' marks")
(ok if dtext.count("All seven read dataset commit") == 1 else bad)(
    "copy count sentence reads 'All seven' once")
media = sorted(sha256_bytes(gshow(f"HEAD:docs/reporting/figures/{p}"))[:24]
               for p in KIT_PNGS)
embedded = sorted(hashlib.sha256(z.read(n)).hexdigest()[:24]
                  for n in z.namelist() if "media/" in n and n.endswith(".png"))
(ok if media == embedded else bad)(
    f"copy embeds the delivered bytes on all seven exhibits ({len(embedded)})")
i33 = dtext.find("3.3 The winner")
i34 = dtext.find("3.4 The levers")
jf = dtext.find("machine-winner-hero Figure (roster row 10)")
(ok if i33 >= 0 and i33 < jf < i34 else bad)(
    "the hero frame sits inside section 3.3 in the copy")
region_ids = sorted(set(re.findall(r"NR-\d{3}", dtext[i_reg:i_build])))
file_ids = sorted({m for m in re.findall(r"\| (NR-\d{3}) \|", reg_md)})
cited = sorted(set(file_ids) - set(UNC))
(ok if len(file_ids) == 50 else bad)(f"register reads 50 rows ({len(file_ids)})")
(ok if len(cited) == 40 else bad)(f"cited set reads 40 ({len(cited)})")
(ok if set(region_ids) == set(cited) else bad)(
    f"appendix set == cited set ({len(region_ids)} ids)")
for i in UNC:
    (ok if i not in region_ids else bad)(f"uncited {i} stays out")
(ok if "Every number in this draft traces to a signed row" in dtext
 else bad)("appendix intro sentence prints")
for s, name in [("14.972", "NR-009 row form"),
                ("27.364 (found gen 26)", "NR-005 value"),
                ("1.4994019682084492 (quote 1.499)", "NR-043 span"),
                ("2.4341173109692225", "NR-050 r_rotor"),
                ("cone_slope_deg 22.0", "NR-049 cone value"),
                ("bank_bot 22°", "NR-011 bank form")]:
    (ok if s in dtext[i_reg:i_build] else bad)(f"register appendix: {name}")

print("[5] the caption kits and the map delta")
kit_ring = git_txt("show", "HEAD:docs/reporting/figures/ring-utilisation/captions.md")
kit_tw = git_txt("show", "HEAD:docs/reporting/figures/twist-limit/captions.md")
kit_st = git_txt("show", "HEAD:docs/reporting/figures/machine-evolution-strip/captions.md")
for kit, slug, s in [(kit_ring, "ring", "Every airborne ring passes its structural check with a wide margin."),
                     (kit_tw, "twist", "The shaft passes its twist and torque checks along its whole length."),
                     (kit_st, "strip", "The search improves the machine at every recorded step, from the common seed to the campaign winner.")]:
    (ok if re.sub(r"\s+", " ", kit).count(s) == 1 else bad)(
        f"{slug} kit carries the takeaway once")
for kit, slug in [(kit_ring, "ring"), (kit_tw, "twist"), (kit_st, "strip")]:
    (ok if "Takeaway (2026-10-14)" in kit else bad)(
        f"{slug} kit records the takeaway pass")
    (ok if "## Technical caption" in kit else bad)(
        f"{slug} kit keeps the technical tier")
for kit, slug, s in [(kit_ring, "ring", "and every other airborne ring holds a much larger margin"),
                     (kit_tw, "twist", "the smallest torque margin sits at S1"),
                     (kit_st, "strip", "A lower number is better")]:
    (ok if kit.count(s) == 0 else bad)(f"{slug} kit reads zero of the old claim")
for slug in ["ring-utilisation", "twist-limit", "machine-evolution-strip"]:
    fn = f"docs/reporting/figures/{slug}/captions.md"
    a = gitc("rev-parse", f"HEAD:{fn}")
    b = gitc("rev-parse", f"origin/bank-derate-cos2p65:{fn}")
    (ok if a == b and a != "" else bad)(f"{slug} captions blob reads HEAD == origin")
figmap = git_txt("show", "HEAD:docs/reporting/figures/figure-map.md")
(ok if "v34 (2026-10-14)" in figmap else bad)("map carries delta v34")
v34_line = [l for l in figmap.splitlines() if "v34 (2026-10-14)" in l]
print("      map v34 line:", v34_line[0][:150] if v34_line else "(none)")

print("[6] the two signed rows counter-read")
(ok if "| NR-049 |" in reg_md else bad)("NR-049 row present")
(ok if "| NR-050 |" in reg_md else bad)("NR-050 row present")
for s, name in [("`cone_slope_deg` 22.0", "NR-049 value form"),
                ("Census: 41 `cone_slope_deg` sites", "NR-049 census"),
                ("`taper_start_z`", "NR-049 taper"),
                ("`9.453339242013`", "NR-049 taper value"),
                ("`9.346660757987`", "NR-049 cone value"),
                ("s = 18.826179", "NR-049 hub station"),
                ("bridle cone half-angle 31 degrees from the shaft axis", "NR-049 bridle boundary"),
                ("F5 resolves the source reading", "NR-049 F5 boundary"),
                ("per-side slope reads 11.0 degrees", "NR-049 F5 slope"),
                ("never a search gene", "NR-049 lead boundary"),
                ("The report site reads `22 degrees`", "NR-049 display form"),
                ("`bank_bot`", "NR-049 bank alias"),
                ("`r_rotor` `2.4341173109692225`", "NR-050 r_rotor"),
                ("`1.8255879832269168`", "NR-050 base span"),
                ("`0.22590989654340632`", "NR-050 chord"),
                ("`1.4158052557245482`", "NR-050 blade mass"),
                ("`4.247415767173645`", "NR-050 assembly mass"),
                ("passes `v_rated` at the cfg value, 11.0", "NR-050 decode convention"),
                ("it reads `p.v_wind_ref`", "NR-050 runner boundary"),
                ("The radii differ by 0.13 per cent", "NR-050 0.13 per cent")]:
    (ok if s in regn else bad)(f"register: {name}")
r = 2.4341173109692225
bs = 1.8255879832269168
sc = 0.8213255027884769
span = 1.4994019682084492
bc = 0.27505525613952214
ch = 0.22590989654340632
(ok if 0.75 * r == bs else bad)("arithmetic: 0.75 x r reads the base span")
(ok if bs * sc == span else bad)("arithmetic: base span x scale reads the span")
(ok if 0.113 * r == bc else bad)("arithmetic: 0.113 x r reads the base chord")
(ok if bc * sc == ch else bad)("arithmetic: base chord x scale reads the chord")
(ok if 0.420 * span ** 3 == 1.4158052557245482 else bad)(
    "arithmetic: span cubed law reads the blade mass")
(ok if 3 * 1.4158052557245482 == 4.247415767173645 else bad)(
    "arithmetic: the three-blade assembly reads three of them")
tap = 9.453339242013 + 9.346660757987
(ok if abs(tap - 18.8) < 1e-9 else bad)(
    f"arithmetic: taper + cone reads the 18.8 m tether ({tap!r})")
prod = 9.346660757987 * tan(radians(22.0))
(ok if abs(prod - (4.580 - 0.804)) < 0.01 else bad)(
    f"arithmetic: cone x tan 22 reads the display radius step ({prod:.4f})")

print("[7] state anchors")
(ok if "v0.42 pass by @author (2026-10-14)." in tracker else bad)(
    "tracker carries the v0.42 entry")
(ok if "v0.43 pass by @author (2026-10-14)." in tracker else bad)(
    "tracker carries the v0.43 entry")
for rel, name, needle in [
        ("docs/reporting/room-responses/science-writer-2026-10-14-sweep-29.md",
         "sweep 29 receipt routes the v0.43 counter-read", "counter-read"),
        ("docs/reporting/room-responses/science-validator-2026-10-14-fb5-source-reads.md",
         "science-validator receipt routes the row counter-read", "counter-read"),
        ("docs/reporting/room-responses/figures-images-diagrams-2026-10-14-round5-caption-takeaways.md",
         "figures receipt lands the caption dedupe", "takeaway"),
        ("docs/reporting/room-responses/author-2026-10-14-v043-round5-wording.md",
         "author receipt lands the v0.43 fold", "NR-050")]:
    body = git_txt("show", f"HEAD:{rel}")
    (ok if needle in body else bad)(name)
sw29 = git_txt("show", "HEAD:docs/reporting/room-responses/science-writer-2026-10-14-sweep-29.md")
(ok if "3374a638" in sw29 else bad)("sweep 29 receipt names the copy md5 stem")
route = git_txt("show", "HEAD:docs/reporting/room-responses/hermes-2026-10-14-feedback5-routing.md")
pending = "Tulloch and Jensen reference" in route
print(f"      routing parenthetical flip: {'STILL OPEN at the queue' if pending else 'flipped'}")
(ok if tip == up else bad)("final: tip == origin")

print(f"\nchecks: {OK + FAIL}  ok: {OK}  fail: {FAIL}")
print("AV_V043_DONE" if FAIL == 0 else "AV_V043_FAIL")
sys.exit(1 if FAIL else 0)

#!/usr/bin/env python3
"""The v0.41 hero copy counter-read (aero-validator, 2026-10-14).

Queue routing: the figures seat lands the machine-winner-hero capture set
(e8159b0), and sweep 27 routes the hero copy counter-read. This pass
proves the delivered copy at md5 7192f4a9 on its own bytes:

  [0] identity and freshness: copy md5, archived build, build record,
      the moved blobs, the build inputs, the register ledger;
  [1] the v0.41 fold census (v0.40 to v0.41): the pin, the marker, the
      appendix row and its four hashes; sections 4 onward stay put;
  [2] the seven seated markers;
  [3] the appendix pins recompute (28 values) from committed bytes;
  [4] the copy prints the pins, resolves the frames and embeds the
      delivered bytes; the hero captions read;
  [5] the guards;
  [6] the register appendix and the hero data ties (capture, genome,
      manifest, checks log, rows);
  [7] state anchors (tracker, map, SPEC, receipts).

Reads committed bytes (git objects) and the delivered copy only.
Runs no simulator. Nothing rewrites a committed file.
"""
import hashlib
import json
import re
import subprocess
import sys
import zipfile
from pathlib import Path

ROOT = Path("/home/rod/Documents/GitHub/KiteTurbineDynamics.jl")
FIGS = ROOT / "docs/reporting/figures"
DRAFT_REL = "docs/reporting/drafts/2026-10-08-report-first-draft.md"
TRACKER_REL = "docs/reporting/draft-tracker.md"
REG_REL = "docs/reporting/numbers-register.md"
DOCX = ROOT / "scratch/report-pdf-build/draft-live.docx"
ARCHIVE = ROOT / "scratch/report-pdf-build/draft-e8159b0-20261014-180159.docx"
BUILD_RECORD = ROOT / "scratch/report-pdf-build/build-record-docx.txt"
BLOCK = ROOT / "scratch/sw_levers_reading_block.md"
CAPTURE_REL = "docs/reporting/figures/pair-extract/extract-winner-operating-point.csv"
GENOME_REL = "docs/reporting/figures/machine-evolution-strip/extract-best-so-far.csv"
SCRIPT_REL = "docs/reporting/figures/machine-winner-hero/machine-winner-hero.jl"
BASE = "0e7d396"
DRAFT_REV = "e8159b0"
REG_REF = "a7d09eb"
REG_ORIG = "d2bf63d"
PIN = "e4ff3c1"
LEVERS_PIN = "d6d4db9"
HERO_ANCHOR = "e8159b0"
COPY_MD5 = "7192f4a9dd4694b63c73cf49944a5844"
BLOCK_MD5 = "7bbd964db09d2b33269ce5cb8c334054"
CAPTURE_SHA = "dd5a9dd25ea9782bd5e12d7c44cb6a8744141edb88e7f14a86b7b64acb0c9203"
GENOME_SHA = "f52a5a99600b1150274142651f7e2d5955c4b86b07056743b690a8f2efdd62ad"
SCRIPT_SHA = "5f41287f67cb35f2244b000dbbb967ccf841dfa1de865178c8255557d18370a3"
HERO_OUT = {
    "machine-winner-hero.png":
        "4e8fc9d267a7e776857b8805be34da1189fddd65117fdf7278f36bd2cd4e6af5",
    "machine-winner-hero.svg":
        "819bafe52679b0fa23ac8c225e3156444b3dcee3ff4fa1ddf4c9065f846c5171",
    "machine-winner-hero.pdf":
        "a9d5516d7ec7bd71bbcd8edee6f425b619736277c229c5bc9ff4aae3f3e8fb2e",
    "checks.log":
        "52fe83a8c54ec93f5372b2fb15c8c77af90b44c3f1e6eb5a8732efffebf59924",
}
EXPECT_ADDED = [
    "Internal engineering report. Draft v0.41. Date 2026-10-14.",
    "[Figure seated: figure-map row 10 (machine winner hero, slug "
    "`machine-winner-hero`). Values cite NR-011, NR-017, NR-021, "
    "NR-022 and NR-043.]",
    "",
    "One row per built exhibit. All seven read dataset commit `dd3cc6a`.",
    "| Machine winner hero | `strip-extract-2026-10-09-best-so-far` · "
    "`pair-extract-2026-10-08-winner-ops` | NR-011, NR-017, NR-021, "
    "NR-022, NR-043 | `c438398` | `post-95c385d_wind-authority` |",
    "",
    "Machine winner hero:",
    "",
    "- `png` `" + HERO_OUT["machine-winner-hero.png"] + "`",
    "- `svg` `" + HERO_OUT["machine-winner-hero.svg"] + "`",
    "- `pdf` `" + HERO_OUT["machine-winner-hero.pdf"] + "`",
    "- `checks` `" + HERO_OUT["checks.log"] + "`",
]
EXPECT_REMOVED = [
    "Internal engineering report. Draft v0.40. Date 2026-10-14.",
    "One row per built exhibit. All six read dataset commit `dd3cc6a`.",
]
TRACKER_ADDED = [
    "v0.41 fold pass by @figures-images-diagrams (2026-10-14).",
    "This pass seats the machine winner hero in the draft at §3.3, "
    "ahead of the plates (figure-map row 10).",
    "The hero draws the recorded final operating pose (SPEC delta D9).",
    "The exhibit joins the figure-provenance appendix with its output "
    "hashes.",
    "The lift-chain overlay and the R2 to R5 number set stay open for "
    "the visual pass.",
    "No value moves.",
    "",
]
MARKERS = [
    "[Figure seated: figure-map row 2 (system anatomy plate, slug "
    "`system-anatomy`). Values cite NR-011, NR-017 and NR-043.]",
    "[Figure seated: figure-map row 10 (machine winner hero, slug "
    "`machine-winner-hero`). Values cite NR-011, NR-017, NR-021, "
    "NR-022 and NR-043.]",
    "[Figure seated: figure-map row 6 (ring utilisation plate, slug "
    "`ring-utilisation`). Values cite NR-021.]",
    "[Figure seated: figure-map row 7 (twist limit plate, slug "
    "`twist-limit`). Values cite NR-022 and NR-023.]",
    "[Figure seated: figure-map row 20 (the levers landscape, slug "
    "`pca-landscape`). Values cite NR-001, NR-005, NR-006, NR-044 and "
    "NR-045.]",
    "[Figure seated: figure-map row 21 (the parameter atlas, slug "
    "`pca-atlas`). Values cite NR-001, NR-005, NR-006 and NR-044.]",
    "[Figure seated: figure-map row 9 (machine evolution strip, slug "
    "`machine-evolution-strip`). Values cite NR-005, NR-006, NR-011 "
    "and NR-036.]",
]
FRAMES = [
    "system-anatomy Figure (roster row 2) · system-anatomy",
    "machine-winner-hero Figure (roster row 10) · machine-winner-hero",
    "ring-utilisation Figure (roster row 6) · ring-utilisation",
    "twist-limit Figure (roster row 7) · twist-limit",
    "pca-landscape Figure (roster row 20) · pca-landscape",
    "pca-atlas Figure (roster row 21) · pca-atlas",
    "machine-evolution-strip Figure (roster row 9) · "
    "machine-evolution-strip",
]
HERO_COPY = [
    "The campaign winner, drawn three ways: down the shaft, from the "
    "side, and along the wind.",
    "The machine stands at its settled operating point.",
    "All three views share one scale, so the drawn size reads true.",
    "The island-3 winner at its final operating step.",
    "The machine reads six rings, three lines and one active rotor "
    "(NR-011).",
    "span 1.499 m and a bank of 7.088 degrees (NR-043, NR-017).",
    "The downwind view looks along the wind, so the shaft reads "
    "foreshortened.",
    "A 5 m scale bar sits in the footer.",
    "Source: pair-extract-2026-10-08-winner-ops · data dd3cc6a · "
    "script c438398 · rows NR-011, NR-017, NR-021, NR-022, NR-043",
]
EXHIBITS = [
    ("Ring utilisation plate", "ring-utilisation", sorted([
        ("png", "ring-utilisation.png"), ("svg", "ring-utilisation.svg"),
        ("pdf", "ring-utilisation.pdf"), ("ledger", "label-ledger.txt")])),
    ("Twist limit plate", "twist-limit", sorted([
        ("png", "twist-limit.png"), ("svg", "twist-limit.svg"),
        ("pdf", "twist-limit.pdf"), ("ledger", "label-ledger.txt")])),
    ("Machine evolution strip", "machine-evolution-strip", sorted([
        ("png", "machine-evolution-strip.png"),
        ("svg", "machine-evolution-strip.svg"),
        ("pdf", "machine-evolution-strip.pdf"), ("checks", "checks.log")])),
    ("System anatomy plate", "system-anatomy", sorted([
        ("png", "system-anatomy.png"), ("pdf", "system-anatomy.pdf"),
        ("ledger", "label-ledger.txt"), ("checks", "checks.log")])),
    ("Levers landscape", "pca-landscape", sorted([
        ("png", "pca-landscape.png"), ("svg", "pca-landscape.svg"),
        ("pdf", "pca-landscape.pdf"), ("ledger", "label-ledger.txt")])),
    ("Parameter atlas", "pca-atlas", sorted([
        ("png", "pca-atlas.png"), ("svg", "pca-atlas.svg"),
        ("pdf", "pca-atlas.pdf"), ("ledger", "label-ledger.txt")])),
    ("Machine winner hero", "machine-winner-hero", sorted([
        ("png", "machine-winner-hero.png"),
        ("svg", "machine-winner-hero.svg"),
        ("pdf", "machine-winner-hero.pdf"), ("checks", "checks.log")])),
]
KIT_PNGS = [
    ("ring-utilisation", "ring-utilisation.png"),
    ("twist-limit", "twist-limit.png"),
    ("machine-evolution-strip", "machine-evolution-strip.png"),
    ("system-anatomy", "system-anatomy.png"),
    ("pca-landscape", "pca-landscape.png"),
    ("pca-atlas", "pca-atlas.png"),
    ("machine-winner-hero", "machine-winner-hero.png"),
]

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


z = zipfile.ZipFile(DOCX)
xml = z.read("word/document.xml").decode("utf-8")
dtext = re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", xml))
rec = BUILD_RECORD.read_text(encoding="utf-8")
draft = git_txt("show", f"{DRAFT_REV}:{DRAFT_REL}")
tracker = git_txt("show", f"HEAD:{TRACKER_REL}")
reg_md = git_txt("show", f"HEAD:{REG_REL}")
tip = gitc("rev-parse", "--short", "HEAD")
up = gitc("rev-parse", "--short", "origin/bank-derate-cos2p65")
md5 = hashlib.md5(DOCX.read_bytes()).hexdigest()
print(f"[0] hero copy counter-read   tip {tip}   origin {up}   "
      f"record {DRAFT_REV}   copy md5 {md5}")

print("[0] identity and freshness")
(ok if md5 == COPY_MD5 else bad)("copy md5 reads the declared value")
(ok if md5 == hashlib.md5(ARCHIVE.read_bytes()).hexdigest() else bad)(
    "copy byte-identical to its archived build")
for s, name in [("Draft: `e8159b0`", "build record names draft e8159b0"),
                ("Seats resolved: 7 of 7", "build record: seven seats"),
                ("checker exit 0", "build record: checker exit 0"),
                ("Built: 2026-10-14T18:01:59Z", "docx build stamp 18:01:59Z"),
                ("file at `a7d09eb`", "build record refs register a7d09eb"),
                ("37 cited, every one signed (48 signed rows total)",
                 "build record: 37 cited of 48 signed")]:
    (ok if s in rec else bad)(name)
unc = re.search(r"uncited: ([^\u2014\n]+)", rec)
unc_ids = sorted(set(re.findall(r"NR-\d{3}", unc.group(1)))) if unc else []
exp_unc = ["NR-019", "NR-020", "NR-024", "NR-031", "NR-033", "NR-034",
           "NR-035", "NR-037", "NR-038", "NR-041", "NR-042"]
(ok if unc_ids == exp_unc else bad)(
    f"build record uncited list reads 11 ids ({len(unc_ids)})")
for rev, rel, name in [(DRAFT_REV, DRAFT_REL, "draft"),
                       (DRAFT_REV, TRACKER_REL, "tracker"),
                       (REG_REF, REG_REL, "register")]:
    a = gitc("rev-parse", f"{rev}:{rel}")
    b = gitc("rev-parse", f"HEAD:{rel}")
    c = gitc("rev-parse", f"origin/bank-derate-cos2p65:{rel}")
    (ok if a and a == b == c else bad)(
        f"{name} blob reads {rev} == HEAD == origin")
d = gitc("diff", "--name-only", DRAFT_REV, "HEAD", "--",
         "docs/reporting/drafts", "docs/reporting/numbers-register.md",
         "docs/reporting/figures")
(ok if d == "" else bad)(
    f"build inputs carry zero diff from {DRAFT_REV} to the tip ({d!r})")
r = gitc("diff", "--numstat", REG_ORIG, "HEAD", "--", REG_REL)
parts = r.split()
(ok if len(parts) == 3 and parts[1] == "0" else bad)(
    f"register additions since {REG_ORIG} read append-only ({r})")
(ok if tip == up else bad)("the read tip reads the same as origin")

print("[1] the v0.41 fold census (v0.40 to v0.41)")
diff = git_txt("diff", BASE, DRAFT_REV, "--", DRAFT_REL)
added, removed = [], []
for l in diff.splitlines():
    if l.startswith("+++") or l.startswith("---") or l.startswith("@@"):
        continue
    if l.startswith("+"):
        added.append(l[1:])
    elif l.startswith("-"):
        removed.append(l[1:])
(ok if added == EXPECT_ADDED else bad)(
    f"added lines read the pin, marker, appendix row and hashes "
    f"({len(added)} lines)")
(ok if removed == EXPECT_REMOVED else bad)(
    f"removed lines read the old pin and the old count sentence "
    f"({len(removed)})")
(ok if draft.count("Internal engineering report. Draft v0.41.") == 1
 else bad)("draft pin line reads v0.41 once")
(ok if "Draft v0.40" not in draft else bad)("old pin reads zero in the draft")
(ok if draft.count("All seven read dataset commit `dd3cc6a`.") == 1
 else bad)("count sentence reads 'All seven' once")
(ok if "All six read" not in draft else bad)(
    "old count sentence reads zero in the draft")
s45a = (git_txt("show", f"{BASE}:{DRAFT_REL}")
        .split("## 4 Discussion", 1)[1].split("## 6 Nomenclature", 1)[0])
s45b = draft.split("## 4 Discussion", 1)[1].split("## 6 Nomenclature", 1)[0]
(ok if s45a == s45b else bad)(
    "sections 4 and 5 hold byte-identical against v0.40")
tdiff = git_txt("diff", BASE, DRAFT_REV, "--", TRACKER_REL)
tadd, trem = [], []
for l in tdiff.splitlines():
    if l.startswith("+++") or l.startswith("---") or l.startswith("@@"):
        continue
    if l.startswith("+"):
        tadd.append(l[1:])
    elif l.startswith("-"):
        trem.append(l[1:])
(ok if tadd == TRACKER_ADDED and trem == [] else bad)(
    f"tracker takes the fold entry alone ({len(tadd)} added, "
    f"{len(trem)} removed)")

print("[2] the seven seated markers")
ms = re.findall(r"\[Figure seated:[^\]]*\]", draft)
(ok if len(ms) == 7 else bad)(f"draft carries seven seated markers ({len(ms)})")
for m in MARKERS:
    (ok if draft.count(m) == 1 else bad)(f"marker reads once: {m[:58]}")
lines = draft.splitlines()
lo = lines.index("### 3.3 The winner")
hi = lines.index("### 3.4 The levers")
midx = lines.index(MARKERS[1])
(ok if lo < midx < hi else bad)(f"the hero marker sits inside §3.3 ({midx})")

print("[3] the appendix pins recompute: pin == committed file == HEAD == origin")
region = draft.split("## Appendix: Figure provenance", 1)[1]
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
pins_by_key = {}
for exhibit, slug, items in EXHIBITS:
    body = blocks.get(exhibit, "")
    for label, fn in items:
        m = re.search(rf"^- `{re.escape(label)}` `([0-9a-f]{{64}})`$",
                      body, flags=re.M)
        if m is None:
            bad(f"{slug}: {label} line missing")
            continue
        n_vals += 1
        pin = m.group(1)
        got = sha256_bytes(gshow(f"HEAD:docs/reporting/figures/{slug}/{fn}"))
        head_blob = gitc("rev-parse", f"HEAD:docs/reporting/figures/{slug}/{fn}")
        orig_blob = gitc("rev-parse",
                         f"origin/bank-derate-cos2p65:docs/reporting/figures/{slug}/{fn}")
        same_blob = head_blob == orig_blob and head_blob != ""
        if got == pin and same_blob:
            ok(f"{slug}: {label} pinned == committed == HEAD == origin")
            pins.append((fn, pin))
            pins_by_key[(slug, fn)] = pin
        else:
            bad(f"{slug}: {label} pin {pin[:12]} committed {got[:12]} "
                f"blobs {head_blob[:9]}/{orig_blob[:9]}")
(ok if n_vals == 28 else bad)(f"28 pinned values walked ({n_vals})")
for slug, anchor in [("ring-utilisation", PIN), ("twist-limit", PIN),
                     ("pca-landscape", LEVERS_PIN), ("pca-atlas", LEVERS_PIN),
                     ("machine-winner-hero", HERO_ANCHOR)]:
    for label, fn in [(p[0], p[1]) for _, s, ps in EXHIBITS if s == slug
                      for p in ps]:
        a = gitc("rev-parse", f"{anchor}:docs/reporting/figures/{slug}/{fn}")
        b = gitc("rev-parse", f"HEAD:docs/reporting/figures/{slug}/{fn}")
        (ok if a == b and a != "" else bad)(
            f"{slug}: {label} byte-stable from {anchor}")

print("[4] the copy prints the pins, resolves the frames, embeds the bytes")
for fn, pin in pins:
    (ok if pin in dtext else bad)(f"copy prints the {fn} pin")
for f in FRAMES:
    (ok if dtext.count(f) == 1 else bad)(f"frame reads once: {f[:56]}")
(ok if dtext.count("Figure (") == 7 else bad)(
    f"seven figure frames read ({dtext.count('Figure (')})")
(ok if dtext.count("Figure seated") == 0 else bad)(
    "raw markers read zero in the copy")
for s in HERO_COPY:
    (ok if s in dtext else bad)(f"copy reads: {s[:56]}")
i33 = dtext.find("3.3 The winner")
i34 = dtext.find("3.4 The levers")
jf = dtext.find("machine-winner-hero Figure (roster row 10)")
(ok if i33 >= 0 and i33 < jf < i34 else bad)(
    "the hero frame sits inside section 3.3 in the copy")
media = sorted(sha256_bytes(gshow(f"HEAD:docs/reporting/figures/{slug}/{fn}"))[:24]
               for slug, fn in KIT_PNGS)
embedded = sorted(hashlib.sha256(z.read(n)).hexdigest()[:24]
                  for n in z.namelist() if "media/" in n and n.endswith(".png"))
(ok if media == embedded else bad)(
    f"copy embeds the delivered bytes on all seven exhibits ({len(embedded)})")
(ok if sha256_bytes(gshow("HEAD:docs/reporting/figures/machine-winner-hero/"
                         "machine-winner-hero.png"))[:24] in embedded else bad)(
    "the hero png bytes embed in the copy")
(ok if dtext.count("All seven read dataset commit") == 1 else bad)(
    "copy count sentence reads 'All seven' once")
(ok if dtext.count("machine-winner-hero") == 3 else bad)(
    f"copy slug reads at its two frame sites and the build seats line "
    f"({dtext.count('machine-winner-hero')})")
(ok if "Seats resolved: 7 of 7" in dtext else bad)(
    "copy build block reads seven seats")
(ok if "Built: 2026-10-14T18:01:59Z" in dtext else bad)(
    "copy build block reads the docx stamp")
(ok if "a7d09eb" in dtext else bad)("copy build block refs register a7d09eb")

print("[5] the guards")
(ok if dtext.count("3.816") == 0 else bad)("guarded 3.816 reads zero")
(ok if len(re.findall(r"27\.363(?!\d)", dtext)) == 0 else bad)(
    "guarded rounded 27.363 reads zero")
(ok if dtext.count("27.3635412663488") == 2 else bad)(
    "full-precision closure prints (NR-039 row and section 2.4)")
(ok if dtext.count("27.364") == 11 else bad)(
    f"display form 27.364 prints ({dtext.count('27.364')})")
i_reg = dtext.find("Data register (cited rows)")
i_build = dtext.find("Build record (builder output)")
hits = [m.start() for m in re.finditer(re.escape("14.97"), dtext)]
in_reg = bool(hits) and all(i_reg <= h < i_build for h in hits)
(ok if len(hits) == 1 and in_reg else bad)(
    f"14.97-class prints once, inside the register appendix "
    f"({len(hits)} hits)")
(ok if dtext.count("14.971791422208508") == 0 else bad)(
    "signed full precision reads internal")
(ok if dtext.count("15.0") == 13 else bad)(
    f"display form 15.0 prints at its sites ({dtext.count('15.0')})")
(ok if dtext.count("15.033") == 3 else bad)(
    f"ring reading 15.033 keeps its form ({dtext.count('15.033')})")
(ok if dtext.count("14.972") == 1 else bad)(
    f"NR-009 ruled form 14.972 prints once ({dtext.count('14.972')})")
(ok if dtext.count("unresolved") == 0 else bad)("no unresolved notice")
(ok if dtext.count("Draft v0.41") == 1 else bad)("copy head line reads Draft v0.41")
for s in ("v0.37", "v0.38", "v0.39", "v0.40"):
    (ok if dtext.count(s) == 0 else bad)(f"copy reads zero '{s}' marks")
blk = BLOCK.read_bytes()
(ok if hashlib.md5(blk).hexdigest() == BLOCK_MD5 else bad)(
    "the block file md5 reads 7bbd964d")
(ok if draft.count(blk.decode()) == 1 else bad)(
    "the frozen levers block reads carried once in the draft")
btail = draft[draft.find(blk.decode()):][:len(blk.decode())].encode()
(ok if btail == blk else bad)("the draft-carried block bytes equal the file bytes")

print("[6] the register appendix and the hero data ties")
file_ids = sorted({m for m in re.findall(r"\| (NR-\d{3}) \|", reg_md)})
region_ids = sorted(set(re.findall(r"NR-\d{3}", dtext[i_reg:i_build])))
cited = sorted(set(file_ids) - set(unc_ids))
(ok if len(file_ids) == 48 and len(unc_ids) == 11 else bad)(
    f"register reads 48 rows, 11 uncited ({len(file_ids)}/{len(unc_ids)})")
(ok if len(cited) == 37 else bad)(f"cited set reads 37 ({len(cited)})")
(ok if set(region_ids) == set(cited) else bad)(
    f"appendix set == cited set ({len(region_ids)} ids)")
for i in unc_ids:
    (ok if i not in region_ids else bad)(f"uncited {i} stays out")
(ok if "Every number in this draft traces to a signed row" in dtext
 else bad)("appendix intro sentence prints")
for s, name in [("14.972", "NR-009 row form"),
                ("27.364 (found gen 26)", "NR-005 value"),
                ("30.578 (found gen 30)", "NR-003 value"),
                ("508 ok / 301 reject / 110 clearance_reject / 11 reject_twist",
                 "NR-002 status mix"),
                ("kg-equivalent: 5.0 per kW", "NR-046 units cell"),
                ("P_score", "NR-046 formula cell"),
                ("15.032534020684876", "NR-021 hub FoS"),
                ("0.03323714455441065", "NR-021 R2 interaction"),
                ("1.4994019682084492 (quote 1.499)", "NR-043 span"),
                ("7.088° at ring 6", "NR-017 bank"),
                ("33.94561934829036", "NR-022 S1 twist")]:
    (ok if s in dtext[i_reg:i_build] else bad)(f"register appendix: {name}")
capture = gshow(f"HEAD:{CAPTURE_REL}")
genome = gshow(f"HEAD:{GENOME_REL}")
script = gshow(f"HEAD:{SCRIPT_REL}")
(ok if sha256_bytes(capture) == CAPTURE_SHA else bad)(
    "capture sha reads the manifest value")
(ok if gitc("rev-parse", f"HEAD:{CAPTURE_REL}") ==
        gitc("rev-parse", f"origin/bank-derate-cos2p65:{CAPTURE_REL}") != ""
 else bad)("capture blob reads HEAD == origin")
(ok if sha256_bytes(genome) == GENOME_SHA else bad)(
    "genome extract sha reads the manifest value")
(ok if gitc("rev-parse", f"HEAD:{GENOME_REL}") ==
        gitc("rev-parse", f"origin/bank-derate-cos2p65:{GENOME_REL}") != ""
 else bad)("genome extract blob reads HEAD == origin")
(ok if sha256_bytes(script) == SCRIPT_SHA else bad)(
    "generator script sha reads the manifest value")
(ok if gitc("rev-parse", f"HEAD:{SCRIPT_REL}") ==
        gitc("rev-parse", f"origin/bank-derate-cos2p65:{SCRIPT_REL}") != ""
 else bad)("generator blob reads HEAD == origin")
mani = json.loads(git_txt("show", "HEAD:docs/reporting/figures/"
                          "machine-winner-hero/manifest.json"))
(ok if mani.get("script_commit") == "c438398" else bad)(
    "manifest script commit reads c438398")
(ok if mani.get("capture", {}).get("sha256") == CAPTURE_SHA else bad)(
    "manifest pins the capture sha")
(ok if sorted(e.get("sha256") for e in mani.get("extracts", [])) ==
        sorted([GENOME_SHA, CAPTURE_SHA]) else bad)(
    "manifest pins the two extract shas")
(ok if mani.get("state", {}).get("row") == "i3-g26-i9" else bad)(
    "manifest state row reads i3-g26-i9")
(ok if mani.get("knobs", {}).get("k_mppt") == 2.24 else bad)(
    "manifest k_mppt reads 2.24")
for fn, want in HERO_OUT.items():
    man = mani.get("outputs", {}).get(fn)
    apx = pins_by_key.get(("machine-winner-hero", fn))
    (ok if man == want and apx == want and
            sha256_bytes(gshow(f"HEAD:docs/reporting/figures/machine-winner-hero/{fn}")) == want
     else bad)(f"{fn}: file == manifest == appendix == {want[:12]}")
crow = [l for l in capture.decode("utf-8").splitlines() if l.startswith("ring,")]
srow = [l for l in capture.decode("utf-8").splitlines() if l.startswith("segment,")]
stations = [0.0] + [float(l.split(",")[2]) for l in crow]
twists = [float(l.split(",")[8]) for l in srow]
(ok if stations == [float(x) for x in mani["state"]["stations_m"]] else bad)(
    f"manifest stations read the capture ring block ({len(stations)})")
(ok if twists == [float(x) for x in mani["state"]["twists_deg"]] else bad)(
    f"manifest twists read the capture segment block ({len(twists)})")
clog = git_txt("show", "HEAD:docs/reporting/figures/machine-winner-hero/checks.log")
m_st = re.search(r"stations R1\.\.R6: ([^\n]+)", clog)
m_tw = re.search(r"twists S1\.\.S5 deg: ([^·\n]+)", clog)
if m_st is None or m_tw is None:
    bad("checks log stations or twists line missing")
else:
    cl_st = [float(x) for x in m_st.group(1).replace(",", " ").split()]
    cl_tw = [float(x) for x in m_tw.group(1).replace(",", " ").split()]
    (ok if [f"{x:.12g}" for x in cl_st] ==
            [f"{x:.12g}" for x in stations] else bad)(
        "checks log stations read the capture values")
    (ok if [f"{x:.12g}" for x in cl_tw] ==
            [f"{x:.12g}" for x in twists] else bad)(
        "checks log twists read the capture values")
(ok if "checks: ALL OK" in clog else bad)("checks log closes ALL OK")
m_stl = re.search(r"state checks: [^\n]+", clog)
if m_stl is None:
    bad("checks log state-checks line missing")
else:
    stline = m_stl.group(0)
    (ok if "false" not in stline and stline.count("true") == 15 else bad)(
        "checks log reads 15 state checks, all true")
(ok if "clean -dg ok" in clog and "clean -zg ok" in clog else bad)(
    "checks log reads the -g PDF chain")
regst = git_txt("show", "HEAD:docs/reporting/figures/machine-winner-hero/"
                "register-status.md")
(ok if "0, 2.3182841987165674, 4.636939712683201, 6.9559610374822345, "
        "9.27534680414777, 18.600867750952748 m" in regst else bad)(
    "register-status drawn stations read the capture")
(ok if "33.94561934829036, 33.811870056223555, 33.67952027817454, "
        "33.54707806507812, 22.821871326820364 deg" in regst else bad)(
    "register-status drawn twists read the capture")
(ok if "spin-sense convention" in regst else bad)(
    "register-status records the spin-sense convention")
readme = git_txt("show", "HEAD:docs/reporting/figures/machine-winner-hero/README.md")
(ok if "No ODE runs." in readme else bad)("kit readme records no ODE runs")
spec = git_txt("show", "HEAD:docs/reporting/figures/machine-renderer/SPEC.md")
(ok if "D9 (2026-10-14)" in spec else bad)("SPEC carries delta D9")
(ok if "reads an untwisted shaft" in spec else bad)(
    "SPEC records the untwisted-shaft reading")
(ok if "The built decode (no ODE)" in spec else bad)(
    "SPEC records the built-decode source")
row021 = [l for l in reg_md.splitlines() if l.startswith("| NR-021 |")]
row022 = [l for l in reg_md.splitlines() if l.startswith("| NR-022 |")]
(ok if row021 and "15.032534020684876" in row021[0] else bad)(
    "NR-021 row carries the hub FoS")
(ok if row021 and "signed (aero-validator" in row021[0] else bad)(
    "NR-021 row reads signed")
(ok if row022 and "33.94561934829036" in row022[0] else bad)(
    "NR-022 row carries the S1 twist")
(ok if row022 and "signed (aero-validator" in row022[0] else bad)(
    "NR-022 row reads signed")
(ok if "- NR-021 ring stations for the row order: 0.0, 2.3182841987165674,"
        in reg_md else bad)("NR-021 station note reads the capture order")

print("[7] state anchors")
(ok if "v0.41 fold pass by @figures-images-diagrams (2026-10-14)." in tracker
 else bad)("tracker carries the v0.41 fold entry")
(ok if "v0.40 pass by @author (2026-10-14)." in tracker else bad)(
    "tracker keeps the v0.40 entry")
figmap = git_txt("show", "HEAD:docs/reporting/figures/figure-map.md")
(ok if "v32 (2026-10-14)" in figmap else bad)("map carries delta v32")
(ok if "Machine hero and the plan, side, downwind capture set" in figmap
 else bad)("map row 10 reads the capture set")
(ok if "Seated in the draft (§3.3)" in figmap else bad)(
    "map row 10 reads seated in the draft")
(ok if "F-REPRO green (`c438398`)" in figmap else bad)(
    "map row 10 reads the F-REPRO state")
figrec = git_txt("show", "HEAD:docs/reporting/room-responses/"
                 "figures-images-diagrams-2026-10-14-machine-winner-hero.md")
(ok if "the new seat sits in the rebuilt copy at §3.3" in figrec else bad)(
    "figures receipt routes the copy read to this seat")
(ok if "the counter-read walks when the copy does" in figrec else bad)(
    "figures receipt names the counter-read")
swrec = git_txt("show", "HEAD:docs/reporting/room-responses/"
                "science-writer-2026-10-14-sweep-27.md")
(ok if "the hero copy counter-read keys at this state" in swrec else bad)(
    "sweep 27 routes the hero counter-read")
for p in ["scratch/fig_hero_state_probe.jl", "scratch/fig_cairo_date_probe.jl",
          "scratch/fig_hero_records_build.py"]:
    (ok if gitc("rev-parse", f"HEAD:{p}") ==
            gitc("rev-parse", f"origin/bank-derate-cos2p65:{p}") != ""
     else bad)(f"evidence at HEAD == origin: {p.split('/')[-1]}")

print(f"\nchecks: {OK + FAIL}  ok: {OK}  fail: {FAIL}")
print("AV_V041_HERO_DONE" if FAIL == 0 else "AV_V041_HERO_FAIL")
sys.exit(1 if FAIL else 0)

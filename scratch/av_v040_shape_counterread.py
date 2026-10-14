#!/usr/bin/env python3
"""The v0.40 shape counter-read (aero-validator, 2026-10-14).

Queue routing: the author pass (PL13, the decision shape) routes the
counter-read here, over the three shape additions, the receipt and the
copy. The science-writer re-routes it on the v0.40 build at md5
835de8d8. This pass:

  [A] pins the moved blobs: draft and tracker at `0e7d396`, the
      register at `a7d09eb`, all == HEAD == origin;
  [B] the six shape lines: exact text, digit-free, each inside its
      section, and the claim context (the frozen block carried once);
  [C] the diff census v0.39 to v0.40: the pin line alone moves, the
      shape lines add, nothing else; sections 4-onward byte-identical;
  [D] the receipt re-reads against the draft;
  [E] the v0.40 copy read at md5 835de8d8: identity, the shape lines in
      the document body, the guards, the pins (24), the exhibits and
      the register appendix;
  [F] state anchors (tracker, map).

Reads committed bytes and the delivered copy only. Runs no simulator.
"""
import hashlib
import re
import subprocess
import sys
import zipfile
from pathlib import Path

ROOT = Path("/home/rod/Documents/GitHub/KiteTurbineDynamics.jl")
FIGS = ROOT / "docs/reporting/figures"
DRAFT = ROOT / "docs/reporting/drafts/2026-10-08-report-first-draft.md"
TRACKER = ROOT / "docs/reporting/draft-tracker.md"
REG = ROOT / "docs/reporting/numbers-register.md"
RECEIPT = ROOT / "docs/reporting/room-responses/author-2026-10-14-v040-decision-shape.md"
BLOCK = ROOT / "scratch/sw_levers_reading_block.md"
DOCX = ROOT / "scratch/report-pdf-build/draft-live.docx"
ARCHIVE = ROOT / "scratch/report-pdf-build/draft-0e7d396-20261014-164352.docx"
BUILD_RECORD = ROOT / "scratch/report-pdf-build/build-record-docx.txt"
FIGMAP = FIGS / "figure-map.md"
BASE = "12a5753"
DRAFT_REV = "0e7d396"
REG_REF = "a7d09eb"
REG_ORIG = "d2bf63d"
PIN = "e4ff3c1"
LEVERS_PIN = "d6d4db9"
COPY_MD5 = "835de8d8dc92e209d23cba39e7c11549"
BLOCK_MD5 = "7bbd964db09d2b33269ce5cb8c334054"
SHAPE = [
    "The next steps add the blade checks and the gust cases.",
    "The trace reads one island of the campaign.",
    "It does not prove a global optimum.",
    "A longer or broader run would extend the search.",
    "The implications hold under the modeled objective and gates.",
    "They do not prove an optimal gene set.",
]
DRAFT_REL = "docs/reporting/drafts/2026-10-08-report-first-draft.md"
TRACKER_REL = "docs/reporting/draft-tracker.md"

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


def sha256(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest()


def git(*args):
    return subprocess.run(["git", "-C", str(ROOT), *args],
                          capture_output=True, text=True).stdout


def gitc(*args):
    return git(*args).strip()


draft = DRAFT.read_text(encoding="utf-8")
z = zipfile.ZipFile(DOCX)
xml = z.read("word/document.xml").decode("utf-8")
dtext = re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", xml))
rec = BUILD_RECORD.read_text(encoding="utf-8")
print(f"[0] shape counter-read   tip {gitc('rev-parse', '--short', 'HEAD')}   "
      f"record {DRAFT_REV}   copy md5 {hashlib.md5(DOCX.read_bytes()).hexdigest()}")

print("[A] the moved blobs pin")
for rev, rel, name in [(DRAFT_REV, DRAFT_REL, "draft"),
                       (DRAFT_REV, TRACKER_REL, "tracker"),
                       (REG_REF, "docs/reporting/numbers-register.md", "register")]:
    a = gitc("rev-parse", f"{rev}:{rel}")
    b = gitc("rev-parse", f"HEAD:{rel}")
    c = gitc("rev-parse", f"origin/bank-derate-cos2p65:{rel}")
    (ok if a and a == b == c else bad)(f"{name} blob reads {rev} == HEAD == origin")

print("[B] the six shape lines")
lines = draft.splitlines()
anchors = {}
for h in ("### 3.4 The levers", "### 3.5 The evolution story",
          "### 3.6 Design implications", "## 4 Discussion"):
    anchors[h] = lines.index(h)
order = ["### 3.4 The levers", "### 3.5 The evolution story",
         "### 3.6 Design implications", "## 4 Discussion"]
ranges = {order[i]: (anchors[order[i]], anchors[order[i + 1]])
          for i in range(3)}
expect_sec = {SHAPE[0]: "### 3.4 The levers", SHAPE[1]: "### 3.5 The evolution story",
              SHAPE[2]: "### 3.5 The evolution story",
              SHAPE[3]: "### 3.5 The evolution story",
              SHAPE[4]: "### 3.6 Design implications",
              SHAPE[5]: "### 3.6 Design implications"}
for s in SHAPE:
    n = draft.count(s)
    (ok if n == 1 else bad)(f"draft carries once: {s[:52]}")
    if n == 1:
        i = lines.index(s)
        lo, hi = ranges[expect_sec[s]]
        (ok if lo < i < hi else bad)(
            f"line {i} sits inside {expect_sec[s]} ({lo}-{hi})")
    (ok if re.search(r"\d", s) is None else bad)(
        f"digits read zero in: {s[:40]}")
blk = BLOCK.read_bytes()
(ok if hashlib.md5(blk).hexdigest() == BLOCK_MD5 else bad)(
    "the block file md5 reads 7bbd964d")
(ok if draft.count(blk.decode()) == 1 else bad)(
    "the frozen levers block reads carried once in the draft")
btail = draft[draft.find(blk.decode()):][:len(blk.decode())].encode()
(ok if btail == blk else bad)("the draft-carried block bytes equal the file bytes")

print("[C] the diff census v0.39 to v0.40")
diff = git("diff", BASE, DRAFT_REV, "--", DRAFT_REL)
added, removed = [], []
for l in diff.splitlines():
    if l.startswith("+++") or l.startswith("---") or l.startswith("@@"):
        continue
    if l.startswith("+"):
        added.append(l[1:])
    elif l.startswith("-"):
        removed.append(l[1:])
exp_add = ["Internal engineering report. Draft v0.40. Date 2026-10-14."] + SHAPE + [""]
(ok if added == exp_add else bad)(
    f"added lines read the pin and the six shape lines ({len(added)} lines)")
(ok if removed == ["Internal engineering report. Draft v0.39. Date 2026-10-14."]
 else bad)(f"removed lines read the old pin alone ({len(removed)})")
s4a = git("show", f"{BASE}:{DRAFT_REL}").split("## 4 Discussion", 1)[1]
s4b = draft.split("## 4 Discussion", 1)[1]
(ok if s4a == s4b else bad)("sections 4 onward hold byte-identical against v0.39")

print("[D] the receipt re-reads against the draft")
recpt = RECEIPT.read_text(encoding="utf-8")
(ok if "**Status** LANDED." in recpt else bad)("the receipt reads LANDED")
for s in SHAPE[:4]:
    (ok if s in recpt.replace("\n", " ") or s in recpt else bad)(
        f"the receipt names: {s[:44]}")
(ok if "the pin alone" in recpt.replace("\n", " ") else bad)(
    "the receipt declares the pin-alone token diff")
(ok if "The discussion re-reads with the beats standing." in recpt.replace("\n", " ")
 else bad)("the receipt carries the section 4 coverage note")

print("[E] the v0.40 copy read")
md5 = hashlib.md5(DOCX.read_bytes()).hexdigest()
(ok if md5 == COPY_MD5 else bad)("copy md5 reads the declared value")
(ok if md5 == hashlib.md5(ARCHIVE.read_bytes()).hexdigest() else bad)(
    "copy byte-identical to its archived build")
for s, name in [("Draft: `0e7d396`", "build record names draft 0e7d396"),
                ("Seats resolved: 6 of 6", "build record: six seats resolved"),
                ("checker exit 0", "build record: checker exit 0"),
                ("Built: 2026-10-14T16:43:52Z", "build stamp 16:43:52Z"),
                ("file at `a7d09eb`", "build record refs the register at a7d09eb"),
                ("37 cited, every one signed (48 signed rows total)",
                 "build record: 37 cited of 48 signed")]:
    (ok if s in rec else bad)(name)
unc = re.search(r"uncited: ([^\u2014\n]+)", rec)
unc_ids = sorted(set(re.findall(r"NR-\d{3}", unc.group(1)))) if unc else []
exp_unc = ["NR-019", "NR-020", "NR-024", "NR-031", "NR-033", "NR-034",
           "NR-035", "NR-037", "NR-038", "NR-041", "NR-042"]
(ok if unc_ids == exp_unc else bad)(f"build record uncited list reads 11 ({len(unc_ids)})")
(ok if dtext.count("Draft v0.40") == 1 else bad)("copy head line reads Draft v0.40")
for s in ("v0.37", "v0.38", "v0.39"):
    (ok if dtext.count(s) == 0 else bad)(f"copy reads zero '{s}' marks")
for s in SHAPE + ["about 73 m/s", "about 9 kW", "about 1278 N/vertex", "87.9",
                  "5 kg-equivalent", "It never allows breaks.",
                  "arms the rope-break check"]:
    (ok if s in dtext else bad)(f"copy reads: {s[:44]}")
(ok if "a7d09eb" in dtext else bad)("copy build block refs a7d09eb")
(ok if "301 reject, 110 clearance_reject and 11 reject_twist" in dtext else bad)(
    "copy carries the classified status line")
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
]
region = draft.split("## Appendix: Figure provenance", 1)[1]
blocks = {}
heads = list(re.finditer(
    r"^(Ring utilisation plate|Twist limit plate|Machine evolution strip"
    r"|System anatomy plate|Levers landscape|Parameter atlas):$",
    region, flags=re.M))
for i, m in enumerate(heads):
    start = m.end()
    end = heads[i + 1].start() if i + 1 < len(heads) else len(region)
    blocks[m.group(1)] = region[start:end]
(ok if len(blocks) == 6 else bad)(f"appendix carries six blocks ({len(blocks)})")
n_vals = 0
pins = []
for exhibit, slug, items in EXHIBITS:
    d = FIGS / slug
    body = blocks.get(exhibit, "")
    for label, fn in items:
        m = re.search(rf"^- `{label}` `([0-9a-f]{{64}})`$", body, flags=re.M)
        if m is None:
            bad(f"{slug}: {label} line missing")
            continue
        n_vals += 1
        pin = m.group(1)
        got = sha256(d / fn)
        head_blob = gitc("rev-parse", f"HEAD:docs/reporting/figures/{slug}/{fn}")
        orig_blob = gitc("rev-parse",
                         f"origin/bank-derate-cos2p65:docs/reporting/figures/"
                         f"{slug}/{fn}")
        same_blob = head_blob == orig_blob and head_blob != ""
        if got == pin and same_blob:
            ok(f"{slug}: {label} pinned == file == HEAD blob == origin")
            pins.append((fn, pin))
        else:
            bad(f"{slug}: {label} pin {pin[:12]} file {got[:12]} blobs "
                f"{head_blob[:9]}/{orig_blob[:9]}")
(ok if n_vals == 24 else bad)(f"24 pinned values walked ({n_vals})")
for slug, anchor in [("ring-utilisation", PIN), ("twist-limit", PIN),
                     ("pca-landscape", LEVERS_PIN), ("pca-atlas", LEVERS_PIN)]:
    for label, fn in [(p[0], p[1]) for _, s, ps in EXHIBITS if s == slug
                      for p in ps]:
        a = gitc("rev-parse", f"{anchor}:docs/reporting/figures/{slug}/{fn}")
        b = gitc("rev-parse", f"HEAD:docs/reporting/figures/{slug}/{fn}")
        (ok if a == b and a != "" else bad)(f"{slug}: {label} byte-stable from {anchor}")
for fn, pin in pins:
    (ok if pin in dtext else bad)(f"copy prints the {fn} pin")
media = sorted(sha256(FIGS / slug / fn)[:24] for _, slug, items in EXHIBITS
               for _, fn in items if fn.endswith(".png"))
embedded = sorted(hashlib.sha256(z.read(n)).hexdigest()[:24]
                  for n in z.namelist() if "media/" in n and n.endswith(".png"))
(ok if media == embedded else bad)(
    f"copy embeds the delivered bytes on all six exhibits ({len(embedded)})")
(ok if dtext.count("3.816") == 0 else bad)("guarded 3.816 reads zero")
(ok if len(re.findall(r"27\.363(?!\d)", dtext)) == 0 else bad)(
    "guarded rounded 27.363 reads zero")
(ok if dtext.count("27.3635412663488") == 2 else bad)(
    "full-precision closure prints (NR-039 row and section 2.4)")
(ok if dtext.count("27.364") >= 11 else bad)(
    f"display form 27.364 prints ({dtext.count('27.364')})")
i_reg = dtext.find("Data register (cited rows)")
i_build = dtext.find("Build record (builder output)")
hits = [m.start() for m in re.finditer(re.escape("14.97"), dtext)]
in_reg = bool(hits) and all(i_reg <= h < i_build for h in hits)
(ok if len(hits) == 1 and in_reg else bad)(
    f"14.97-class prints once, inside the register appendix ({len(hits)} hits)")
(ok if dtext.count("14.971791422208508") == 0 else bad)(
    "signed full precision reads internal")
(ok if dtext.count("15.0") == 13 else bad)(
    f"display form 15.0 prints at its sites ({dtext.count('15.0')})")
(ok if dtext.count("15.033") == 3 else bad)(
    f"ring reading 15.033 keeps its form ({dtext.count('15.033')})")
(ok if dtext.count("14.972") == 1 else bad)(
    f"NR-009 ruled form 14.972 prints once ({dtext.count('14.972')})")
(ok if dtext.count("unresolved") == 0 else bad)("no unresolved notice")
r = gitc("diff", "--numstat", REG_ORIG, "--", "docs/reporting/numbers-register.md")
parts = r.split()
(ok if len(parts) == 3 and parts[1] == "0" else bad)(
    f"register additions since d2bf63d read append-only ({r})")
reg_md = REG.read_text(encoding="utf-8")
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
                ("P_score", "NR-046 formula cell")]:
    (ok if s in dtext[i_reg:i_build] else bad)(f"register appendix: {name}")

print("[F] state anchors")
tr = TRACKER.read_text(encoding="utf-8")
(ok if "v0.40 pass by @author (2026-10-14)." in tr else bad)(
    "tracker carries the v0.40 pass")
(ok if "v0.39 pass" in tr else bad)("tracker carries the v0.39 pass")
fm = FIGMAP.read_text(encoding="utf-8")
(ok if "v31 (2026-10-14)" in fm else bad)("map carries delta v31")

print(f"\nchecks: {OK + FAIL}  ok: {OK}  fail: {FAIL}")
print("AV_V040_SHAPE_DONE" if FAIL == 0 else "AV_V040_SHAPE_FAIL")
sys.exit(1 if FAIL else 0)

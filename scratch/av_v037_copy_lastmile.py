#!/usr/bin/env python3
"""Review copy last mile: the v0.37 build of draft-live.docx
(aero-validator, 2026-10-14).

Answers the founder request for the current review copy. Proves the
delivered copy is the tip's state, and that the figure, guard and
register surfaces read clean on it:
  [0] identity and freshness: md5, archived build, build record, blobs;
  [1] the copy carries the v0.37 content set;
  [2] the appendix pins recompute (24 values) file == HEAD == origin;
  [3] the copy prints the pins and embeds the delivered bytes;
  [4] the guards read on the report text and the register appendix;
  [5] the register appendix carries the cited rows, and the spot values
      read at the register forms;
  [6] the state anchors assert (tracker, map).

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
REG = ROOT / "docs/reporting/numbers-register.md"
DOCX = ROOT / "scratch/report-pdf-build/draft-live.docx"
ARCHIVE = ROOT / "scratch/report-pdf-build/draft-7dd91a9-20261014-141528.docx"
BUILD_RECORD = ROOT / "scratch/report-pdf-build/build-record-docx.txt"
TRACKER = ROOT / "docs/reporting/draft-tracker.md"
FIGMAP = FIGS / "figure-map.md"
FIX = "ef36c6c"
PIN = "e4ff3c1"
LEVERS_PIN = "d6d4db9"
COPY_MD5 = "94619634bd1374abc8327050cf13874d"
DRAFT_REV = "7dd91a9"
REG_REV = "9d96a4b"

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
                          capture_output=True, text=True).stdout.strip()


draft = DRAFT.read_text(encoding="utf-8")
region = draft.split("## Appendix: Figure provenance", 1)[1]
z = zipfile.ZipFile(DOCX)
xml = z.read("word/document.xml").decode("utf-8")
dtext = re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", xml))
tip = git("rev-parse", "--short", "HEAD")
print(f"[0] last mile   tip {tip}   record {DRAFT_REV}   copy md5 "
      f"{hashlib.md5(DOCX.read_bytes()).hexdigest()}")

print("[0] identity and freshness")
md5 = hashlib.md5(DOCX.read_bytes()).hexdigest()
(ok if md5 == COPY_MD5 else bad)(f"copy md5 reads the declared value")
(ok if md5 == hashlib.md5(ARCHIVE.read_bytes()).hexdigest() else bad)(
    "copy byte-identical to its archived build")
rec = BUILD_RECORD.read_text(encoding="utf-8")
for s, name in [("Draft: `7dd91a9`", "build record names draft 7dd91a9"),
                ("Seats resolved: 6 of 6", "build record: six seats resolved"),
                ("checker exit 0", "build record: checker exit 0"),
                ("Built: 2026-10-14T14:15:28Z", "build stamp 14:15:28Z")]:
    (ok if s in rec else bad)(name)
for rev, path, name in [
        (DRAFT_REV, "docs/reporting/drafts/2026-10-08-report-first-draft.md",
         "draft"),
        (REG_REV, "docs/reporting/numbers-register.md", "register")]:
    a = git("rev-parse", f"{rev}:{path}")
    b = git("rev-parse", f"HEAD:{path}")
    c = git("rev-parse", f"origin/bank-derate-cos2p65:{path}")
    (ok if a and a == b and b == c else bad)(
        f"{name} blob reads {rev} == HEAD == origin ({a[:9]})")

print("[1] the v0.37 content set in the copy")
(ok if "Draft v0.37" in dtext else bad)("copy head line reads Draft v0.37")
for s in ("v0.34", "v0.35", "v0.36"):
    (ok if dtext.count(s) == 0 else bad)(f"copy reads zero '{s}' marks")
(ok if "301 reject, 110 clearance_reject and 11 reject_twist" in dtext
 else bad)("copy carries the classified status line")
(ok if "All six read" in dtext else bad)("copy count sentence reads six")
for s, name in [("kW", "the kW form"), ("per cent", "the per cent form"),
                ("rad/s", "the rad/s form"), ("rpm", "the rpm form"),
                ("ground-generation", "the ground-generation keyword")]:
    n = dtext.count(s)
    (ok if n >= 1 else bad)(f"copy reads {name} ({n})")
for s, name in [("kilowatts", "spelled 'kilowatts'"),
                ("candidate kite turbine", "the retired phrase"),
                ("gate penalties", "the old penalty term")]:
    (ok if dtext.count(s) == 0 else bad)(f"copy reads zero {name}")
(ok if len(re.findall(r"\bpercent\b", dtext)) == 0 else bad)(
    "copy reads zero bare 'percent'")

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

print("[2] the appendix pins recompute: pin == file == HEAD blob == origin")
blocks = {}
heads = list(re.finditer(
    r"^(Ring utilisation plate|Twist limit plate|Machine evolution strip"
    r"|System anatomy plate|Levers landscape|Parameter atlas):$",
    region, flags=re.M))
for i, m in enumerate(heads):
    start = m.end()
    end = heads[i + 1].start() if i + 1 < len(heads) else len(region)
    blocks[m.group(1)] = region[start:end]
(ok if len(blocks) == 6 else bad)(f"appendix carries six blocks "
                                  f"({len(blocks)} found)")
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
        head_blob = git("rev-parse", f"HEAD:docs/reporting/figures/{slug}/{fn}")
        orig_blob = git("rev-parse",
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
        a = git("rev-parse", f"{anchor}:docs/reporting/figures/{slug}/{fn}")
        b = git("rev-parse", f"HEAD:docs/reporting/figures/{slug}/{fn}")
        (ok if a == b and a != "" else bad)(f"{slug}: {label} byte-stable "
                                            f"from {anchor}")

print("[3] the copy prints the pins and embeds the delivered bytes")
for fn, pin in pins:
    (ok if pin in dtext else bad)(f"copy prints the {fn} pin")
for tok, name in [("6f19832088375b96", "ring png v1"),
                  ("ec0f4b96f3fa9b64", "ring svg v1"),
                  ("508b3a641fde21b5", "ring pdf v1"),
                  ("c040fca2dd63df9c", "ring ledger v1"),
                  ("7ff5c05cc0caa089", "twist png v1"),
                  ("ffac9c1eba5386fe", "twist svg v1"),
                  ("d207343460263fde", "twist pdf v1"),
                  ("6dfbd6eae0285a55", "twist ledger v1")]:
    (ok if tok not in draft else bad)(f"draft free of {name}")
    (ok if tok not in dtext else bad)(f"copy free of {name}")
media = sorted(sha256(FIGS / slug / fn)[:24] for _, slug, items in EXHIBITS
               for _, fn in items if fn.endswith(".png"))
embedded = sorted(hashlib.sha256(z.read(n)).hexdigest()[:24]
                  for n in z.namelist() if "media/" in n and n.endswith(".png"))
(ok if media == embedded else bad)(
    f"copy embeds the delivered bytes on all six exhibits ({len(embedded)})")

print("[4] the guards")
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
    f"14.97-class prints once, inside the register appendix "
    f"({len(hits)} hits, {hits})")
(ok if dtext.count("14.971791422208508") == 0 else bad)(
    "signed full precision reads internal")
(ok if dtext.count("15.0") == 13 else bad)(
    f"display form 15.0 prints at its sites ({dtext.count('15.0')})")
(ok if dtext.count("15.033") == 3 else bad)(
    f"ring reading 15.033 keeps its form ({dtext.count('15.033')})")
(ok if dtext.count("unresolved") == 0 else bad)("no unresolved notice")

print("[5] the register appendix")
reg_md = REG.read_text(encoding="utf-8")
file_ids = sorted({m for m in re.findall(r"\| (NR-\d{3}) \|", reg_md)})
unc = re.search(r"uncited: ([^\u2014\n]+)", rec)
unc_ids = sorted(set(re.findall(r"NR-\d{3}", unc.group(1)))) if unc else []
region_ids = sorted(set(re.findall(r"NR-\d{3}", dtext[i_reg:i_build])))
cited = sorted(set(file_ids) - set(unc_ids))
(ok if len(file_ids) == 46 and len(unc_ids) == 11 else bad)(
    f"register reads 46 rows, 11 uncited ({len(file_ids)}/{len(unc_ids)})")
(ok if len(cited) == 35 else bad)(f"cited set reads 35 ({len(cited)})")
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

print("[6] state anchors")
tracker = TRACKER.read_text(encoding="utf-8")
(ok if "v0.37 pass by @author" in tracker else bad)("tracker carries the "
                                                    "v0.37 pass")
figmap = FIGMAP.read_text(encoding="utf-8")
(ok if "v31 (2026-10-14)" in figmap else bad)("map carries delta v31")
(ok if "v30 (2026-10-14)" in figmap else bad)("map carries delta v30")

print(f"\nchecks: {OK + FAIL}  ok: {OK}  fail: {FAIL}")
print("AV_V037_LASTMILE_DONE" if FAIL == 0 else "AV_V037_LASTMILE_FAIL")
sys.exit(1 if FAIL else 0)

#!/usr/bin/env python3
"""Item-8 aero leg, part 3: the v0.39 copy counter-read
(aero-validator, 2026-10-14).

The queue routes the v0.39 build's counter-read here, at md5
f1ceae4d. The read covers the k-story fold, the k-sweep display rows
(NR-047, NR-048) and their checker. This pass proves the delivered
copy on its own bytes:

  [0] identity and freshness: md5, archived build, build record, blobs,
      and the register's append-only additions since the build;
  [1] the copy carries the v0.39 content set (the fold, the safety
      forms, the classified line, the unit forms);
  [2] the appendix pins recompute (24 values) file == HEAD == origin;
  [3] the copy prints the pins and embeds the delivered bytes;
  [4] the guards read on the report text and the register appendix;
  [5] the register appendix carries the cited rows (37 of 48), spot
      values at the register forms;
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
ARCHIVE = ROOT / "scratch/report-pdf-build/draft-12a5753-20261014-155048.docx"
BUILD_RECORD = ROOT / "scratch/report-pdf-build/build-record-docx.txt"
TRACKER = ROOT / "docs/reporting/draft-tracker.md"
FIGMAP = FIGS / "figure-map.md"
BASE = "9166686"
DRAFT_REV = "12a5753"
REG_BUILD_REF = "d2bf63d"
PIN = "e4ff3c1"
LEVERS_PIN = "d6d4db9"
COPY_MD5 = "f1ceae4d2278361756ba6c9b631f310d"

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
z = zipfile.ZipFile(DOCX)
xml = z.read("word/document.xml").decode("utf-8")
dtext = re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", xml))
rec = BUILD_RECORD.read_text(encoding="utf-8")
print(f"[0] copy read   tip {git('rev-parse', '--short', 'HEAD')}   "
      f"record {DRAFT_REV}   copy md5 {hashlib.md5(DOCX.read_bytes()).hexdigest()}")

print("[0] identity and freshness")
md5 = hashlib.md5(DOCX.read_bytes()).hexdigest()
(ok if md5 == COPY_MD5 else bad)("copy md5 reads the declared value")
(ok if md5 == hashlib.md5(ARCHIVE.read_bytes()).hexdigest() else bad)(
    "copy byte-identical to its archived build")
for s, name in [("Draft: `12a5753`", "build record names draft 12a5753"),
                ("Seats resolved: 6 of 6", "build record: six seats resolved"),
                ("checker exit 0", "build record: checker exit 0"),
                ("Built: 2026-10-14T15:50:48Z", "build stamp 15:50:48Z"),
                ("file at `d2bf63d`", "build record refs the register at d2bf63d"),
                ("37 cited, every one signed (48 signed rows total)",
                 "build record: 37 cited of 48 signed")]:
    (ok if s in rec else bad)(name)
unc = re.search(r"uncited: ([^\u2014\n]+)", rec)
unc_ids = sorted(set(re.findall(r"NR-\d{3}", unc.group(1)))) if unc else []
exp_unc = ["NR-019", "NR-020", "NR-024", "NR-031", "NR-033", "NR-034",
           "NR-035", "NR-037", "NR-038", "NR-041", "NR-042"]
(ok if unc_ids == exp_unc else bad)(
    f"build record uncited list reads 11 ids ({len(unc_ids)})")
for rev, path, name in [(DRAFT_REV, DRAFT, "draft"),
                        (DRAFT_REV, TRACKER, "tracker")]:
    rel = str(path.relative_to(ROOT))
    a = git("rev-parse", f"{rev}:{rel}")
    b = git("rev-parse", f"HEAD:{rel}")
    c = git("rev-parse", f"origin/bank-derate-cos2p65:{rel}")
    (ok if a and a == b == c else bad)(f"{name} blob reads {rev} == HEAD == origin")
rb = git("rev-parse", f"{REG_BUILD_REF}:docs/reporting/numbers-register.md")
rb2 = git("rev-parse", f"{BASE}:docs/reporting/numbers-register.md")
(ok if rb == rb2 and rb != "" else bad)(
    "the build's register (d2bf63d) equals the base-tip register")
d = git("diff", "--numstat", REG_BUILD_REF, "--",
        "docs/reporting/numbers-register.md")
parts = d.split() if d else []
(ok if len(parts) == 3 and parts[1] == "0" else bad)(
    f"register additions since the build read append-only ({d})")

print("[1] the v0.39 content set in the copy")
(ok if dtext.count("Draft v0.39") == 1 else bad)("copy head line reads Draft v0.39")
for s in ("v0.36", "v0.37", "v0.38"):
    (ok if dtext.count(s) == 0 else bad)(f"copy reads zero '{s}' marks")
for s in ("0.5 reject 3.49 19.14 51.8", "1.0 ok 5.45 17.64 47.8",
          "1.5 ok 6.78 16.59 42.8", "1.94 ok 7.56 15.80 40.1",
          "2.24 ok 8.00 15.34 36.4", "3.0 ok 8.89 14.42 24.3",
          "about 73 m/s", "about 85 m/s", "near the 100 m/s ceiling",
          "about 9 kW", "3.55 was a mass-scaled value with no anchor.",
          "5.39 was the 3-blade anchor chosen on the broken machine.",
          "twice the nominal load", "about 1278 N/vertex",
          "87.9", "78.8", "5 kg-equivalent",
          "It never allows breaks.", "arms the rope-break check"):
    (ok if s in dtext else bad)(f"copy reads: {s[:44]}")
(ok if "301 reject, 110 clearance_reject and 11 reject_twist" in dtext
 else bad)("copy carries the classified status line")
(ok if "All six read" in dtext else bad)("copy count sentence reads six")
for s, name in [("kW", "the kW form"), ("per cent", "the per cent form"),
                ("rad/s", "the rad/s form"), ("rpm", "the rpm form"),
                ("ground-generation", "the ground-generation keyword")]:
    n = dtext.count(s)
    (ok if n >= 1 else bad)(f"copy reads {name} ({n})")
for s, name in [("kilowatts", "spelled 'kilowatts'"),
                ("candidate kite turbine", "the retired phrase")]:
    (ok if dtext.count(s) == 0 else bad)(f"copy reads zero {name}")

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
(ok if dtext.count("14.972") == 1 else bad)(
    f"NR-009 ruled form 14.972 prints once ({dtext.count('14.972')})")
(ok if dtext.count("unresolved") == 0 else bad)("no unresolved notice")

print("[5] the register appendix")
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

print("[6] state anchors")
tracker = TRACKER.read_text(encoding="utf-8")
(ok if "v0.39" in tracker else bad)("tracker carries the v0.39 entry")
(ok if "v0.38" in tracker else bad)("tracker carries the v0.38 entry")
(ok if "v0.37 pass" in tracker else bad)("tracker carries the v0.37 pass")
figmap = FIGMAP.read_text(encoding="utf-8")
(ok if "v31 (2026-10-14)" in figmap else bad)("map carries delta v31")

print(f"\nchecks: {OK + FAIL}  ok: {OK}  fail: {FAIL}")
print("AV_V039_COPY_DONE" if FAIL == 0 else "AV_V039_COPY_FAIL")
sys.exit(1 if FAIL else 0)

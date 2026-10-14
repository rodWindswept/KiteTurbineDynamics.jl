#!/usr/bin/env python3
"""Appendix re-census: the figure-provenance re-pin at the fix commit
(aero-validator, 2026-10-14, phase two of the Harris-3.5 read).

Phase one found the v1 hashes printed for the two plates. The figures
seat landed the re-pin at ef36c6c (ten substitutions, verbatim) and the
levers rows. This pass inverts every phase-one defect check into a fail
and re-proves the gates on the fixed bytes:
  [1] the appendix pins recompute from the committed bytes (24 values);
  [2] the retired tokens are gone from the draft and the review copy;
  [3] the region reads byte-stable from its fix commit to the tip;
  [4] the copy embeds the delivered bytes and prints the new pins;
  [5] the levers rows carry the recorded source, rows, commits and era.

Reads committed bytes only. Runs no simulator.
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
DOCX = ROOT / "scratch/report-pdf-build/draft-live.docx"
FIX = "ef36c6c"
PIN = "e4ff3c1"
LEVERS_PIN = "d6d4db9"
COPY_MD5 = "275a7047fa0c0e55cb874ecddc060366"

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
tip = git("rev-parse", "--short", "HEAD")
print(f"[0] re-census   tip {tip}   fix {FIX}   kits {PIN}   draft md5 "
      f"{hashlib.md5(DRAFT.read_bytes()).hexdigest()}")

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

print("[1] the re-pinned values recompute file == HEAD blob == pinned")
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
        (ok if a == b and a != "" else bad)(
            f"{slug}: {label} byte-stable from {anchor}")

print("[2] retired tokens gone; the count sentence reads six")
for tok, name in [("6f19832088375b96", "ring png v1"), ("ec0f4b96f3fa9b64", "ring svg v1"),
                  ("508b3a641fde21b5", "ring pdf v1"), ("c040fca2dd63df9c", "ring ledger v1"),
                  ("7ff5c05cc0caa089", "twist png v1"), ("ffac9c1eba5386fe", "twist svg v1"),
                  ("d207343460263fde", "twist pdf v1"), ("6dfbd6eae0285a55", "twist ledger v1"),
                  ("eacf073", "old plate script commit"), ("v0.34", "old version mark")]:
    (ok if tok not in draft else bad)(f"draft free of {name}")
(ok if "All six read dataset commit `dd3cc6a`." in draft else bad)(
    "count sentence reads 'All six read dataset commit dd3cc6a'")
(ok if "All four read" not in draft else bad)("old 'All four' sentence gone")
(ok if "v0.36" in draft else bad)("version mark reads v0.36")
for cell, want in [("| Ring utilisation plate |", "`671ab96`"),
                   ("| Twist limit plate |", "`671ab96`"),
                   ("| Levers landscape |", "`e23f226`"),
                   ("| Parameter atlas |", "`e23f226`"),
                   ("| Machine evolution strip |", "`74cfef9`"),
                   ("| System anatomy plate |", "`9cecee3`")]:
    line = [ln for ln in draft.splitlines() if ln.startswith(cell)]
    (ok if line and want in line[0] else bad)(
        f"exhibit row {cell.strip('| ')[:24]} carries {want}")

print("[3] the appendix region reads byte-stable from the fix commit")
old_raw = subprocess.run(
    ["git", "-C", str(ROOT), "show",
     f"{FIX}:docs/reporting/drafts/2026-10-08-report-first-draft.md"],
    capture_output=True, text=True).stdout
old_region = old_raw.split("## Appendix: Figure provenance", 1)[1]
(ok if old_region == region else bad)(
    "appendix region: fix commit == HEAD (byte-identical)")

print("[4] the review copy")
if DOCX.exists():
    dz = zipfile.ZipFile(DOCX)
    xml = dz.read("word/document.xml").decode("utf-8")
    dtext = re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", xml))
    md5 = hashlib.md5(DOCX.read_bytes()).hexdigest()
    (ok if md5 == COPY_MD5 else bad)(f"copy md5 {md5}")
    for tok, name in [("f49aaaa1bda8d1699c6db556", "ring png v2"),
                      ("00cd857a5769be853142a4e3", "twist png v2"),
                      ("4b1bd3453a6aa20d9b9b0af7", "landscape png"),
                      ("1e46b70ae65f5557d23bb1a7", "atlas png")]:
        (ok if tok in dtext else bad)(f"copy prints {name}")
    for tok, name in [("6f19832088375b96", "ring png v1"),
                      ("7ff5c05cc0caa089", "twist png v1"),
                      ("ec0f4b96f3fa9b64", "ring svg v1")]:
        (ok if tok not in dtext else bad)(f"copy free of {name}")
    (ok if "All six read" in dtext else bad)("copy count sentence reads six")
    media = {hashlib.sha256(dz.read(n)).hexdigest()[:24]
             for n in dz.namelist() if "media/" in n and n.endswith(".png")}
    for tok, name in [("f49aaaa1bda8d1699c6db556", "ring"),
                      ("00cd857a5769be853142a4e3", "twist"),
                      ("8e9d1d40684b984059601f31", "strip"),
                      ("f1c322bc20068299651bea79", "anatomy"),
                      ("4b1bd3453a6aa20d9b9b0af7", "landscape"),
                      ("1e46b70ae65f5557d23bb1a7", "atlas")]:
        (ok if tok in media else bad)(f"copy embeds delivered {name} bytes")
else:
    bad("review copy missing")

print("[5] the levers rows: source, cited rows, era")
for exhibit, want in [("Levers landscape",
                       "NR-001, NR-005, NR-006, NR-044, NR-045"),
                      ("Parameter atlas", "NR-001, NR-005, NR-006, NR-044")]:
    row = [ln for ln in draft.splitlines() if ln.startswith(f"| {exhibit} |")]
    (ok if row and want in row[0] else bad)(f"{exhibit}: cited rows {want}")
    (ok if row and "island_{1,2,3}/telemetry.csv" in row[0] else bad)(
        f"{exhibit}: telemetry source named")
    (ok if row and "post-95c385d_wind-authority" in row[0] else bad)(
        f"{exhibit}: era named")
map_md = (FIGS / "figure-map.md").read_text()
(ok if "v30 (2026-10-14)" in map_md else bad)("map delta v30 records the pass")
tracker = (ROOT / "docs/reporting/draft-tracker.md").read_text()
(ok if "v0.35" in tracker else bad)("tracker carries the v0.35 entry")

print(f"\nchecks: {OK + FAIL}  ok: {OK}  fail: {FAIL}")
print("AV_REPIN_RECENSUS_DONE" if FAIL == 0 else "AV_REPIN_RECENSUS_FAIL")
sys.exit(1 if FAIL else 0)

#!/usr/bin/env python3
# av_et_pl_counterread.py — the aero desk counter-read of the eval-timeline
# placement label re-cut (script a269636, landing f5c2d59, range e6206de..f5c2d59).
#
# Sections: 1 the vector census (old vs new), 2 the manifest pins, 3 the svg
# pin surfaces, 4 the F-REPRO trio, 5 the register blob join, 6 the boundary
# (no draft byte), 7 the record census greps. Read-only. Exit 0 on all-pass.
import hashlib
import json
import re
import subprocess
import sys
from collections import Counter
from pathlib import Path

ROOT = Path("/home/rod/Documents/GitHub/KiteTurbineDynamics.jl")
KIT = ROOT / "docs" / "reporting" / "figures" / "eval-timeline"
OLDREV = "e6206de"
NEWREV = "f5c2d59"

PASS, FAIL = [], []


def check(name, got, want):
    ok = got == want
    (PASS if ok else FAIL).append(name)
    print(f"check: {name}: {got!r}  ({'OK' if ok else 'FAIL vs ' + repr(want)})")


def read_rev(rev, path):
    return subprocess.run(
        ["git", "show", f"{rev}:{path}"], cwd=ROOT, capture_output=True, text=True
    ).stdout


def texts(svg_text):
    found = [
        m.strip()
        for m in re.findall(r"<text[^>]*>(.*?)</text>", svg_text, flags=re.S)
    ]
    return [s for s in found if s]


# ---------------- 1. the vector census ----------------
old = read_rev(OLDREV, "docs/reporting/figures/eval-timeline/eval-timeline.svg")
new = (KIT / "eval-timeline.svg").read_text(encoding="utf-8")
to, tn = Counter(texts(old)), Counter(texts(new))
removed = sorted((to - tn).elements())
added = sorted((tn - to).elements())
check("census: strings removed", len(removed), 2)
check("census: strings added", len(added), 2)
for s in removed:
    print("  -", s[:110])
for s in added:
    print("  +", s[:110])
d_old = Counter(s for s in texts(old) if re.search(r"[0-9]", s))
d_new = Counter(s for s in texts(new) if re.search(r"[0-9]", s))
check("census: digit-bearing strings removed", len(d_old - d_new), 1)
check("census: digit-bearing strings added", len(d_new - d_old), 1)
only_digit_change = list((d_old - d_new).elements()) + list((d_new - d_old).elements())
check(
    "census: the only digit change is the script-commit stamp",
    all("script commit" in s for s in only_digit_change),
    True,
)
check("label: new form x1", new.count("rope-break gate off during relax"), 1)
check("label: caveat x0", new.count("not yet in the code"), 0)

# the box moved with the label: the patch_15 path differs old vs new
old_box = re.search(r'<g id="patch_15">\s*<path d="([^"]+)"', old).group(1)
new_box = re.search(r'<g id="patch_15">\s*<path d="([^"]+)"', new).group(1)
check("box: patch_15 changed", old_box != new_box, True)
xo = re.search(r"M ([\d.]+)", old_box).group(1)
xn = re.search(r"M ([\d.]+)", new_box).group(1)
print(f"  patch_15 left edge: {xo} -> {xn} (shrink to the shorter label)")

# ---------------- 2. the manifest pins ----------------
man = json.loads((KIT / "manifest.json").read_text(encoding="utf-8"))
check("manifest: script_commit", man["script_commit"], "a269636")
check("manifest: data_commit", man["data_commit"], "dd3cc6a")
check(
    "manifest: script sha256 recomputes",
    hashlib.sha256((KIT / "eval-timeline.py").read_bytes()).hexdigest(),
    man["script"]["sha256"],
)
for out, want in man["outputs"].items():
    check(
        f"manifest: {out} sha256 recomputes",
        hashlib.sha256((KIT / out).read_bytes()).hexdigest(),
        want,
    )

# ---------------- 3. the svg pin surfaces ----------------
svg_sha = hashlib.sha256((KIT / "eval-timeline.svg").read_bytes()).hexdigest()
check("svg: sha256 prefix reads 373c2db3", svg_sha.startswith("373c2db3"), True)
check(
    "manifest: svg pin is the 373c2db3 hash",
    man["outputs"]["eval-timeline.svg"].startswith("373c2db3"),
    True,
)
sweep_text = (ROOT / "docs" / "reporting" / "draft-consistency-sweep.md").read_text()
sw_rc = (ROOT / "docs" / "reporting" / "room-responses" /
         "science-writer-2026-10-15-sweep-32.md").read_text()
check("sweep record: cites the svg pin", "373c2db3" in sweep_text, True)
check("sweep receipt: cites the svg pin", "373c2db3" in sw_rc, True)

# ---------------- 4. the F-REPRO trio ----------------
outs = ["eval-timeline.svg", "eval-timeline.pdf", "eval-timeline.png",
        "label-ledger.txt", "manifest.json"]
table = {}
for ln in (ROOT / "scratch" / "fig_et_pl_repro.md5").read_text().splitlines():
    h, f = ln.split("  ")
    table[f] = h
check("repro: table rows", len(table), 5)
for f in outs:
    h1 = hashlib.md5((KIT / f).read_bytes()).hexdigest()
    h2 = hashlib.md5((ROOT / "scratch" / "fig_et_pl_repro1" / f).read_bytes()).hexdigest()
    h3 = hashlib.md5((ROOT / "scratch" / "fig_et_pl_repro2" / f).read_bytes()).hexdigest()
    check(f"repro: {f} 3-way and table", h1 == h2 == h3 == table[f], True)

# ---------------- 5. the register blob join ----------------
pins = {
    "scratch/av_rb_warm_extract/island_1_warm_10ms.csv": "770d937743948763e56715e5baade154fe179941",
    "scratch/av_rb_warm_extract/island_2_warm_10ms.csv": "05fb874b0aa0c756570935e1e50039305ebaac39",
    "scratch/av_rb_warm_extract/island_3_warm_10ms.csv": "3b39f063c286a58d865bc3c7234cf625ee31244d",
}
reg_full = (ROOT / "docs" / "reporting" / "numbers-register.md").read_text()
for f, pin in pins.items():
    data = (ROOT / f).read_bytes()
    bsha = hashlib.sha1(b"blob %d\0" % len(data) + data).hexdigest()
    check(f"blob join: {Path(f).name}", bsha == pin, True)
    check(f"blob join: {Path(f).name} pinned in the register", pin in reg_full, True)

# ---------------- 6. the boundary ----------------
names = subprocess.run(
    ["git", "diff", "--name-only", f"{OLDREV}..{NEWREV}"],
    cwd=ROOT, capture_output=True, text=True,
).stdout.splitlines()
check("boundary: no draft byte in the range", any("drafts/" in n for n in names), False)
check("boundary: no docx in the range", any(n.endswith(".docx") for n in names), False)
draft = (ROOT / "docs" / "reporting" / "drafts" / "2026-10-08-report-first-draft.md").read_text()
check("boundary: plate slug not in the draft", "eval-timeline" in draft, False)

# ---------------- 7. the record census greps ----------------
check("record: receipt cites both revs",
      ("`a269636`" in (ROOT / "docs" / "reporting" / "room-responses" /
       "figures-images-diagrams-2026-10-15-eval-timeline-placement-label-recut.md").read_text())
      and ("`2bf76a3`" in (ROOT / "docs" / "reporting" / "room-responses" /
       "figures-images-diagrams-2026-10-15-eval-timeline-placement-label-recut.md").read_text()),
      True)

print()
print(f"TOTAL: {len(PASS) + len(FAIL)} checks, {len(FAIL)} fail")
if FAIL:
    for f in FAIL:
        print("  FAILED: " + f)
    sys.exit(1)
print("ALL PASS")

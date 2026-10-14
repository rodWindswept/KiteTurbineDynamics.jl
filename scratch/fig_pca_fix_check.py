#!/usr/bin/python3
# -*- coding: utf-8 -*-
"""The levers fix pass: check walk (figures seat, 2026-10-14).

1. Re-runs each kit generator at stamp A into a scratch outdir.
2. Compares sha256 for the five outputs, kit against rerun.
3. Re-walks F-LABEL independently: the SVG text layer against the ledger.
4. Asserts the new stamp forms and the retired form's absence.
5. Asserts each kit note's hash block matches the on-disk md5s.
6. Asserts the cite map, the NR-045 cites and the kg-equivalent form sit
   in the kit docs, the strip captions and the figure map.

Run: /usr/bin/python3 scratch/fig_pca_fix_check.py
Writes: scratch/fig_pca_fix_check.log
"""
import hashlib
import html
import re
import shutil
import subprocess
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
FIG = REPO / "docs/reporting/figures"
A = "e23f226"
KITS = ["pca-landscape", "pca-atlas"]
FILES = ["{slug}.svg", "{slug}.pdf", "{slug}.png", "label-ledger.txt",
         "manifest.json"]

fails = []
lines = []


def check(name, ok, detail=""):
    lines.append(f"check: {name}: {'OK' if ok else 'FAIL'} {detail}")
    if not ok:
        fails.append(name)


def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def md5(p): return hashlib.md5(p.read_bytes()).hexdigest()


for slug in KITS:
    kit = FIG / slug
    mf = (kit / "manifest.json").read_text()
    check(f"{slug} manifest script_commit", f'"script_commit": "{A}"' in mf)
    check(f"{slug} manifest row_wants empty", '"row_wants": []' in mf)
    tmp = REPO / f"scratch/fig_pca_fix_repro_{slug}"
    if tmp.exists():
        shutil.rmtree(tmp)
    tmp.mkdir(parents=True)
    r = subprocess.run(
        ["/usr/bin/python3", str(kit / f"{slug}.py"),
         "--script-commit", A, "--outdir", str(tmp)],
        capture_output=True, text=True, cwd=REPO)
    check(f"{slug} rerun rc", r.returncode == 0, f"rc={r.returncode}")
    for f in FILES:
        name = f.format(slug=slug)
        a, b = sha(kit / name), sha(tmp / name)
        check(f"{slug} {name} byte-identity", a == b, a[:16])
    svg_text = (kit / f"{slug}.svg").read_text()
    found = {html.unescape(re.sub(r"<[^>]+>", "", m)).strip()
             for m in re.findall(r"<text[^>]*>(.*?)</text>", svg_text,
                                 flags=re.S)}
    ledger = set((kit / "label-ledger.txt").read_text().splitlines())
    check(f"{slug} F-LABEL set equality", found == ledger,
          f"{len(found)}/{len(ledger)}")
    if slug == "pca-landscape":
        check("landscape stamp rows",
              "rows NR-001, NR-005, NR-006, NR-044, NR-045" in svg_text)
        check("landscape stamp2 signed",
              f"variance shares NR-044 · script commit {A}" in svg_text)
    else:
        check("atlas stamp rows",
              "rows NR-001, NR-005, NR-006, NR-044" in svg_text)
    check(f"{slug} no pending form", "pending their row" not in svg_text)
    rs = (kit / "register-status.md").read_text()
    for f in FILES:
        name = f.format(slug=slug)
        h = md5(kit / name)
        check(f"{slug} note md5 {name}", h in rs, h)
    for fn in ["SPEC.md", "register-status.md", "captions-draft.md"]:
        t = (kit / fn).read_text()
        check(f"{slug}/{fn} no 3d36c7a", "3d36c7a" not in t)
        check(f"{slug}/{fn} no kilogram", "kilogram" not in t)
    lines.append(f"pins {slug}:")
    for f in FILES:
        name = f.format(slug=slug)
        lines.append(f"  sha256 {name}: {sha(kit / name)}")

DOCS = [
    ("landscape RS winner map", "pca-landscape/register-status.md",
     "| NR-005 | The winner value, 27.364 | Signed |", None),
    ("landscape RS seed map", "pca-landscape/register-status.md",
     "| NR-006 | The common seed value, 36.109 | Signed |", None),
    ("landscape RS NR-045 row", "pca-landscape/register-status.md",
     "| NR-045 | The island generation counts", None),
    ("landscape RS no inverse", "pca-landscape/register-status.md",
     None, "| NR-005 | The common seed"),
    ("landscape RS no inverse 2", "pca-landscape/register-status.md",
     None, "| NR-006 | The winner"),
    ("landscape SPEC cite", "pca-landscape/SPEC.md",
     "| start 36.109 | NR-006 |", "| start 36.109 | NR-005"),
    ("landscape SPEC NR-045 row", "pca-landscape/SPEC.md",
     "| 31 generations each | NR-045 |", None),
    ("atlas RS winner map", "pca-atlas/register-status.md",
     "| NR-005 | The winner value, 27.364 | Signed |", None),
    ("atlas RS seed map", "pca-atlas/register-status.md",
     "| NR-006 | The common seed value, 36.109 | Signed |", None),
    ("atlas RS no inverse", "pca-atlas/register-status.md",
     None, "| NR-005 | The common seed"),
    ("atlas SPEC cite", "pca-atlas/SPEC.md",
     "| start 36.109 | NR-006 | the journey marks", None),
    ("landscape caption seed map", "pca-landscape/captions-draft.md",
     "starts at 36.109 (NR-006). The winner ends at 27.364 (NR-005)", None),
    ("landscape caption kg", "pca-landscape/captions-draft.md",
     "objective in kg-equivalent", None),
    ("landscape prov NR-045", "pca-landscape/captions-draft.md",
     "rows: NR-001, NR-005, NR-006, NR-044, NR-045", None),
    ("atlas caption seed map", "pca-atlas/captions-draft.md",
     "(36.109, NR-006). The diamond marks the winner (27.364, NR-005)", None),
    ("map cell", "figure-map.md",
     "F-VALUE counter-read at `331f60d` holds the drawn values.", None),
    ("map delta v26", "figure-map.md", "**v26 (2026-10-14):**", None),
]
for name, rel, must, must_not in DOCS:
    t = (FIG / rel).read_text()
    if must is not None:
        check(name, must in t)
    if must_not is not None:
        check(name, must_not not in t)

strip = (FIG / "machine-evolution-strip/captions.md").read_text()
check("strip kg count 2", strip.count("in kg-equivalent") == 2,
      str(strip.count("in kg-equivalent")))
check("strip no kilograms", "kilogram" not in strip)
check("strip form note", "Form note (2026-10-14)" in strip)

lines.append("== summary: "
             + (f"{len(fails)} FAIL: {fails}" if fails else "all OK"))
log = "\n".join(lines) + "\n"
(REPO / "scratch/fig_pca_fix_check.log").write_text(log)
print(log)
raise SystemExit(1 if fails else 0)

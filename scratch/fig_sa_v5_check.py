#!/usr/bin/env python3
"""fig-sa v5 check: the re-cut records and outputs against the manifest.

Runs from the repo root against the working-tree kit bytes:
  - label-ledger: 34 strings; carries the two cone-ring strings
  - PDF text layer: carries the two cone-ring strings (pdftotext)
  - tex: stays label-clean; the drawn source line unchanged
  - manifest: register rows unchanged; every output hash recomputes
  - records: register note, captions, SPEC, map, master appendix, tracker
"""
import hashlib
import json
import subprocess
import sys
from pathlib import Path

KIT = Path("docs/reporting/figures/system-anatomy/")
checks = []


def chk(name, cond, detail=""):
    checks.append((name, bool(cond), detail))


led = [l for l in (KIT / "label-ledger.txt").read_text(encoding="utf-8").splitlines() if l.strip()]
chk("ledger count 34", len(led) == 34, f"got {len(led)}")
chk("ledger carries 'R5, the cone ring'", "R5, the cone ring" in led)
chk("ledger carries 'the shaft cone starts here'", "the shaft cone starts here" in led)

pt = subprocess.run(["pdftotext", str(KIT / "system-anatomy.pdf"), "-"],
                    capture_output=True, text=True)
flat = " ".join(pt.stdout.split())
chk("pdf text layer carries the cone-ring label",
    "R5, the cone ring" in flat and "the shaft cone starts here" in flat)

tex = (KIT / "system-anatomy.tex").read_text(encoding="utf-8")
chk("tex carries the label node", "R5, the cone ring" in tex)
chk("tex stamp unchanged", "rows NR-011 \\textperiodcentered{} NR-017 \\textperiodcentered{} NR-043" in tex)

man = json.loads((KIT / "manifest.json").read_text(encoding="utf-8"))
chk("manifest register rows unchanged",
    man["inputs"]["register_rows"] == ["NR-011", "NR-017", "NR-043"],
    str(man["inputs"]["register_rows"]))
chk("manifest script commit d243b37", man["script_commit"] == "d243b37")
for fname, want in man["outputs"].items():
    got = hashlib.sha256((KIT / fname).read_bytes()).hexdigest()
    chk(f"manifest {fname}", got == want, got[:16])

rs = (KIT / "register-status.md").read_text(encoding="utf-8")
chk("register note: v5 re-cut block", "v5 (2026-10-14): the cone ring (R5) label joins the plate" in rs)
chk("register note: delta v3", "**Delta** v3 (2026-10-14): the v5 re-cut lands." in rs)
chk("register note: v5 hash block", "system-anatomy.tex  8a6d82b74dde69965e224d2ce3293ccf" in rs)

cap = (KIT / "captions.md").read_text(encoding="utf-8")
chk("captions: re-cut v5 status", "**Status** GENERATE (re-cut v5; founder-return" in cap)
chk("captions: v5 re-cut line", "The v5 re-cut lands at\n`d243b37`." in cap)
chk("captions: cone-ring note", "Cone-ring note (2026-10-14): the v5 re-cut names R5 as the cone ring" in cap)

spec = (KIT / "SPEC.md").read_text(encoding="utf-8")
chk("spec: thirteen labels", "Thirteen labels. The cone ring (R5) label is" in spec)
chk("spec: cone-ring leader clearance", "the cone-ring leader\n  clearance holds." in spec)

mp = Path("docs/reporting/figures/figure-map.md").read_text(encoding="utf-8")
chk("map: row 2 v5 cell", "The v5 re-cut landed (`d243b37`)" in mp)
chk("map: delta v35", "- **v35 (2026-10-14):** the system-anatomy v5 re-cut lands." in mp)
chk("map: delta v34 intact", "- **v34 (2026-10-14):** the round-5 caption dedupe lands" in mp)

mas = Path("docs/reporting/drafts/2026-10-08-report-first-draft.md").read_text(encoding="utf-8")
chk("master: draft v0.44", "Internal engineering report. Draft v0.44. Date 2026-10-14." in mas)
chk("master: appendix script commit", "| NR-011, NR-017, NR-043 | `d243b37` | `post-95c385d_wind-authority` |" in mas)
for lbl, h in [("png", "b78eb5cbe8f77074f04f9264e409f3de7f5aa97096a4f4f824c3bdf8271ecc9a"),
               ("pdf", "b8fd60364168d70200f2f7122f7f9a957ea1590aa84c6197a19c79e811c444b6"),
               ("ledger", "3adec59c7bd19b232584de4e6cb703b44d4e48bb820c68f1ed78f5086971dc8d"),
               ("checks", "5255033809928282a348d525b6a7553df3ba64b267fcabb1499ecfaa75331810")]:
    chk(f"master: appendix {lbl} hash", f"- `{lbl}` `{h}`" in mas)

tr = Path("docs/reporting/draft-tracker.md").read_text(encoding="utf-8")
chk("tracker: v0.44 entry", "v0.44 pass by @fig-img-diagrams (2026-10-14)." in tr)

npass = sum(1 for _, ok, _ in checks if ok)
lines = [f"fig_sa_v5_check: {npass} pass, {len(checks)-npass} fail", ""]
for name, ok, detail in checks:
    lines.append(f"{'PASS' if ok else 'FAIL'}  {name}" + (f"   [{detail}]" if detail else ""))
out = "\n".join(lines) + "\n"
print(out)
Path("scratch/fig_sa_v5_check.log").write_text(out)
sys.exit(0 if npass == len(checks) else 1)

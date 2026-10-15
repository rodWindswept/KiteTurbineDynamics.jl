#!/usr/bin/env python3
"""fig_et_pl_check: the check set for the placement label re-cut.

Covers: the generator census, the emitted-vector census, the ledger
re-walk, the manifest pins, the F-REPRO table, the record surfaces and
the stale-string census. Also runs the STE gate on every touched
markdown file. Writes no files. Exit 0 on all-pass.
"""
import hashlib
import html
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
KIT = ROOT / "docs" / "reporting" / "figures" / "eval-timeline"
A = "a269636"
FIX = "2bf76a3"

PASS = []
FAIL = []


def check(name, got, want):
    ok = got == want
    (PASS if ok else FAIL).append(name)
    print(f"check: {name}: {got!r}  ({'OK' if ok else 'FAIL vs ' + repr(want)})")


def sha256(p: Path) -> str:
    return hashlib.sha256(p.read_bytes()).hexdigest()


def norm(t: str) -> str:
    return " ".join(t.split())


# ---------------- 1. generator census ----------------
gen = (KIT / "eval-timeline.py").read_text(encoding="utf-8")
check("gen: new label x1", gen.count('keep("rope-break gate off during relax")'), 1)
check("gen: old caveat x0", gen.count("not yet in the code"), 0)
check("gen: swept comment x1", gen.count("ground ring and top ring"), 1)
check("gen: old ring-name comment x0", gen.count("hub ring"), 0)
check("gen: v3 changelog x1", gen.count("v3 (the placement landed, 2026-10-15)"), 1)
check("gen: omega_hub identifier holds", gen.count("omega_hub"), 1)

# ---------------- 2. emitted vector + ledger ----------------
svg = (KIT / "eval-timeline.svg").read_text(encoding="utf-8")
ledger = (KIT / "label-ledger.txt").read_text(encoding="utf-8")
check("svg: new label x1", svg.count("rope-break gate off during relax"), 1)
check("svg: old caveat x0", svg.count("not yet in the code"), 0)
check("ledger: new label x1", ledger.count("rope-break gate off during relax"), 1)
check("ledger: old caveat x0", ledger.count("not yet in the code"), 0)
ledger_set = {ln for ln in ledger.splitlines() if ln}
check("ledger: string count", len(ledger_set), 52)
found = {
    html.unescape(re.sub(r"<[^>]+>", "", m)).strip()
    for m in re.findall(r"<text[^>]*>(.*?)</text>", svg, flags=re.S)
}
found = {s for s in found if s}
check("F-LABEL re-walk: vector == ledger", sorted(found) == sorted(ledger_set), True)

# ---------------- 3. manifest pins ----------------
man = json.loads((KIT / "manifest.json").read_text(encoding="utf-8"))
check("manifest: script_commit", man["script_commit"], A)
check("manifest: data_commit", man["data_commit"], "dd3cc6a")
check("manifest: script sha", sha256(KIT / "eval-timeline.py"), man["script"]["sha256"])
for out, want in man["outputs"].items():
    check(f"manifest: {out} sha", sha256(KIT / out), want)
for inp in man["inputs"]["extracts"]:
    p = ROOT / inp["path"]
    check(f"manifest: input {p.name}", sha256(p), inp["sha256"])

# ---------------- 4. F-REPRO table ----------------
table = {}
for ln in (ROOT / "scratch" / "fig_et_pl_repro.md5").read_text().splitlines():
    h, f = ln.split("  ")
    table[f] = h
check("repro: table rows", len(table), 5)
for f, h in table.items():
    m1 = hashlib.md5((KIT / f).read_bytes()).hexdigest()
    m2 = hashlib.md5((ROOT / "scratch" / "fig_et_pl_repro1" / f).read_bytes()).hexdigest()
    m3 = hashlib.md5((ROOT / "scratch" / "fig_et_pl_repro2" / f).read_bytes()).hexdigest()
    check(f"repro: {f} 3-way", (m1 == m2 == m3 == h), True)

# ---------------- 5. record surfaces ----------------
reg = norm((KIT / "register-status.md").read_text(encoding="utf-8"))
check("reg: landed label", "The lane-3 label takes the landed form at this re-cut: it reads" in reg, True)
check("reg: fix cite", "landed in the code at `2bf76a3`" in reg, True)
check("reg: delta v6", "**Delta** v6 (2026-10-15): the placement lands." in reg, True)
check("reg: delta v5 holds", "**Delta** v5 (2026-10-14)" in reg, True)
check("reg: closed form note", "swept at the v6 re-cut" in reg, True)
check("reg: old form note gone", "until the next re-render sweep" not in reg, True)

spec = norm((KIT / "SPEC.md").read_text(encoding="utf-8"))
check("spec: bullet landed", "label names the placement, landed in the code at `2bf76a3`" in spec, True)
check("spec: closed item", "**Closed:** the window-only rope-break placement call." in spec, True)
check("spec: delta v3", "- v3 (2026-10-15): the placement lands (`2bf76a3`)." in spec, True)
check("spec: v1 delta holds", "v1 (2026-10-13)" in spec, True)
check("spec: old open form gone", "labels hold the" not in spec, True)

mp = (ROOT / "docs" / "reporting" / "figures" / "figure-map.md").read_text(encoding="utf-8")
mpn = norm(mp)
check("map: delta v44", "**v44 (2026-10-15):** the placement label re-cut lands (row 4)." in mpn, True)
check("map: row cell", "The placement label re-cut lands (script `a269636`)" in mpn, True)
check("map: row tail", "Next: the aero counter-read of the re-cut, then the visual pass by Rod, then the fold" in mpn, True)
check("map: v43 holds", "**v43 (2026-10-15):**" in mpn, True)

seat = norm((ROOT / "handovers" / "handover-2026-10-14-reporting-room-figures-images-diagrams.md").read_text(encoding="utf-8"))
check("seat: closed index", "The placement label re-cut (2026-10-15): the lane-3 label takes the landed form" in seat, True)
check("seat: open item note", "Row 4 carries the placement re-cut: the aero counter-read opens, then the visual pass." in seat, True)

rc = (ROOT / "docs" / "reporting" / "room-responses" /
      "figures-images-diagrams-2026-10-15-eval-timeline-placement-label-recut.md")
check("receipt: exists", rc.exists(), True)
rcn = norm(rc.read_text(encoding="utf-8"))
check("receipt: cites", ("`a269636`" in rcn) and ("`2bf76a3`" in rcn), True)

# ---------------- 6. stale census ----------------
check("census: gen caveat x0", gen.count("not yet in the code"), 0)
check("census: svg caveat x0", svg.count("not yet in the code"), 0)
check("census: ledger caveat x0", ledger.count("not yet in the code"), 0)
check("census: reg caveat x0", reg.count("not yet in the code"), 0)
spec_raw = (KIT / "SPEC.md").read_text(encoding="utf-8")
check("census: SPEC raw caveat x0", spec_raw.count("not yet in the code"), 0)
check("census: SPEC one historical hit", spec.count("not yet in the code"), 1)
check("census: SPEC historical context", 'ruling label takes "not yet in the code"' in spec, True)
cap = norm((KIT / "captions-draft.md").read_text(encoding="utf-8"))
check("census: captions caveat x0", cap.count("not yet in the code"), 0)
hits = [ln for ln in mp.splitlines() if "not yet in the code" in ln]
check("census: map caveat x1 (v18 delta)", len(hits), 1)
check("census: map caveat context", "the ruling label reads" in hits[0], True)

# ---------------- 7. STE gate ----------------
lint_files = [
    rc,
    KIT / "register-status.md",
    KIT / "SPEC.md",
    ROOT / "docs" / "reporting" / "figures" / "figure-map.md",
    ROOT / "handovers" / "handover-2026-10-14-reporting-room-figures-images-diagrams.md",
]
for f in lint_files:
    r = subprocess.run(["python3", "ste-lint.py", "--fail-above", "2.0", str(f)],
                       capture_output=True, text=True, cwd=ROOT)
    tail = (r.stdout.strip().splitlines() or [""])[-1]
    check(f"ste: {f.name} rc", r.returncode, 0)
    print(f"  ste {f.name}: {tail}")

print()
print(f"TOTAL: {len(PASS) + len(FAIL)} checks, {len(FAIL)} fail")
if FAIL:
    print("FAILED:")
    for f in FAIL:
        print("  " + f)
    sys.exit(1)
print("ALL PASS")

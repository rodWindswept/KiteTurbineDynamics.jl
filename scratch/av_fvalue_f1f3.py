#!/usr/bin/env python3
"""aero-validator F-VALUE re-check: the FEEDBACKBOT1 re-cut plates.

Kits: ring-utilisation v7 (F-1, figure-map row 6), twist-limit v6
(F-3, row 7).  Read at de18442 (science-writer v0.64 tip), committed
bytes only.  Scope: same gates as the 2026-10-13 plates counter-read
(S1 pins, S2 F-VALUE, S3 F-REPRO) plus the two gate derivations the
re-cut introduced:
  G1  the campaign structural gate at utilisation 0.40 = 1 / 2.5
      (NR-015 fos_hard, scripts/run_v13_5kw_masslift.jl:151-155)
  G2  the panel-B torsional FoS gate marks at capacity / 1.5 per
      segment (NR-052, src/trpt_optimization.jl:39), no numerals
      at the marks

Writes only under the seat scratch outdir.  Runs no simulator.
"""
import csv
import hashlib
import html
import json
import re
import subprocess
import sys
from pathlib import Path

REPO = Path("/home/rod/Documents/GitHub/KiteTurbineDynamics.jl")
OUT = Path("/home/rod/.hermes/profiles/aero-validator/cache/scratch/fvalue_f1f3")
RK = REPO / "docs/reporting/figures/ring-utilisation"
TK = REPO / "docs/reporting/figures/twist-limit"
EXTRACT = REPO / "docs/reporting/figures/pair-extract/extract-winner-operating-point.csv"
REGISTER = REPO / "docs/reporting/numbers-register.md"
PY = "/usr/bin/python3"

RESULTS = []


def ok(name, cond, detail=""):
    RESULTS.append(bool(cond))
    print(f"[{'PASS' if cond else 'FAIL'}] {name}" + (f"  [{detail}]" if detail else ""))
    return cond


def sha(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest()


def load_csv(p):
    with open(p, newline="", encoding="utf-8") as fh:
        lines = [ln for ln in fh if not ln.startswith("#")]
    return list(csv.DictReader(lines))


def textset(svg_path):
    raw = Path(svg_path).read_text()
    return {html.unescape(re.sub(r"<[^>]+>", "", m)).strip()
            for m in re.findall(r"<text[^>]*>(.*?)</text>", raw, flags=re.S)}


def extract_blocks():
    rows = {"ring": [], "segment": []}
    for row in load_csv(EXTRACT):
        rows[row["block"]].append(row)
    return rows


def register_row_signed(rid):
    reg = REGISTER.read_text()
    for line in reg.splitlines():
        if line.startswith(f"| {rid} |") and "signed (" in line:
            return True, line[:200]
    return False, ""


def fmt_fos(v):
    if v >= 1e4:
        return f"{round(v):,}"
    return f"{v:.3f}"


print("== aero-validator F-VALUE re-check: ring-utilisation v7 + twist-limit v6 ==")
print("read at HEAD de18442, committed bytes only; runs under:", OUT)
print()

data = extract_blocks()
rings = data["ring"]
segs = data["segment"]

# ---------------------------------------------------------------- S1 pins
print("== S1. kit pins vs manifests ==")
for name, kit, slug in (("ring-utilisation", RK, "ring-utilisation"),
                        ("twist-limit", TK, "twist-limit")):
    man = json.loads((kit / "manifest.json").read_text())
    for fname, pin in man["outputs"].items():
        got = sha(kit / fname)
        ok(f"{name} output pin {fname}", got == pin, f"pin {pin[:12]} got {got[:12]}")
    got = sha(REPO / man["script"]["path"])
    ok(f"{name} script pin", got == man["script"]["sha256"],
       f"pin {man['script']['sha256'][:12]} got {got[:12]}")
    ex = man["inputs"]["extract"]
    got = sha(REPO / ex["path"])
    ok(f"{name} extract pin", got == ex["sha256"],
       f"pin {ex['sha256'][:12]} got {got[:12]}")

# ------------------------------------------------ S2a ring-utilisation F-VALUE
print()
print("== S2a. F-VALUE: ring-utilisation ==")
ring_svg = textset(RK / "ring-utilisation.svg")
ring_led = set((RK / "label-ledger.txt").read_text().splitlines())
ok("ring SVG text set == ledger set", ring_svg == ring_led,
   f"{len(ring_svg)} strings")
ok("ring ledger 30 strings", len(ring_led) == 30, f"{len(ring_led)}")

fos = {r["id"]: float(r["ring_fos"]) for r in rings}
fos_forms = {rid: fmt_fos(v) for rid, v in fos.items()}
ok("ring FoS forms recompute (R2-R6)", fos_forms == {
    "R2": "30.087", "R3": "29.807", "R4": "35.236",
    "R5": "326,974", "R6": "15.033"}, repr(fos_forms))
for rid in ("R2", "R3", "R4", "R6"):
    ok(f"ring ledger readout FoS {fos_forms[rid]}", f"FoS {fos_forms[rid]}" in ring_led)
ok("ring R5 badge form in ledger", "net tension — FoS 326,974" in ring_led)
ok("ring R5 not-scored note in ledger",
   "net tension — compression share not scored" in ring_led)
ok("ring no compression bar on R5: 4 cyan bars in SVG, no R5 bar",
   RK.joinpath("ring-utilisation.svg").read_text().count('fill: #1f8fff; opacity: 0.95') == 4,
   f"{RK.joinpath('ring-utilisation.svg').read_text().count('fill: #1f8fff; opacity: 0.95')} bars")

# G1: the campaign structural gate at 1 / 2.5
g1 = 1.0 / 2.5
ok("G1 1/2.5 == 0.40 exactly", g1 == 0.4, repr(g1))
ok("G1 gate line label in ledger",
   "campaign structural gate — FoS 2.5, utilisation 0.40 (NR-015)" in ring_led)
runner = (REPO / "scripts/run_v13_5kw_masslift.jl").read_text()
ok("G1 signed basis fos_hard = 2.5 in the campaign runner",
   "fos_target = 2.5, fos_hard = 2.5" in runner)

# axis linearity: the six linear tick labels, no logarithmic labels
ok("ring axis linear tick labels present",
   {"0", "0.2", "0.4", "0.6", "0.8", "1"} <= ring_led)
ok("ring axis reads linear (no log decade labels)",
   not any(s in ring_led for s in ("0.000001", "1e-6", "10⁻⁶")),
   str(sorted(s for s in ring_led if "⁻" in s or "e-6" in s)))

# SVG geometry: gate and boundary verticals on the linear axis
ring_raw = RK.joinpath("ring-utilisation.svg").read_text()
# axes rect from the kit: left 0.145*547.2, width 0.825*547.2, xlim (0, 1.24)
AX_L = 0.145 * 547.2
PX = lambda x: AX_L + x * (0.825 * 547.2 / 1.24)  # noqa: E731
gate_m = re.search(r'd="M ([0-9.]+) [0-9.]+\s+L \1 [0-9.]+\s+" clip-path="[^"]*" style="[^"]*#7a4fbf',
                   ring_raw, re.S)
if gate_m:
    x1 = float(gate_m.group(1))
    ok("ring SVG gate vertical at x = px(0.40)",
       abs(x1 - PX(0.40)) < 1.0,
       f"svg {x1:.4f} vs {PX(0.40):.4f}")
else:
    ok("ring SVG gate path found", False, "no #7a4fbf path")
bnd_m = re.search(r'd="M ([0-9.]+) [0-9.]+\s+L \1 [0-9.]+\s+" clip-path="[^"]*" style="[^"]*#b32222',
                  ring_raw, re.S)
ok("ring SVG fail boundary at x = px(1.0)",
   bool(bnd_m) and abs(float(bnd_m.group(1)) - PX(1.0)) < 1.0,
   f"svg {float(bnd_m.group(1)) if bnd_m else float('nan'):.4f} vs {PX(1.0):.4f}")

# register cross-reads: NR-021 forms equal the drawn forms; cited rows signed
ok("NR-021 ring FoS row forms equal drawn forms",
   all(s in (REGISTER.read_text().split("NR-022")[0]) for s in
       ("FoS 30.087", "FoS 29.807", "FoS 35.236", "FoS 326974", "FoS 15.033")))
signed = {}
for rid in ("NR-021", "NR-015", "NR-060"):
    signed[rid], rowline = register_row_signed(rid)
    ok(f"ring cited row {rid} signed", signed[rid], rowline)
cap = (RK / "captions.md").read_text()
ok("ring caption prints the gate reciprocal cite",
   "draws at utilisation 0.40, the reciprocal of FoS 2.5 (NR-015)" in cap)
ok("ring caption prints the R5 tension cite (NR-060) and badge value (NR-021)",
   "net axial tension from the cone flare (NR-060)" in cap
   and "FoS 326,974 (NR-021)" in cap)

# ------------------------------------------------ S2b twist-limit F-VALUE
print()
print("== S2b. F-VALUE: twist-limit ==")
twist_svg = textset(TK / "twist-limit.svg")
twist_led = set((TK / "label-ledger.txt").read_text().splitlines())
ok("twist SVG text set == ledger set", twist_svg == twist_led,
   f"{len(twist_svg)} strings")
ok("twist ledger 52 strings", len(twist_led) == 52, f"{len(twist_led)}")

da = [float(s["abs_dalpha_deg"]) for s in segs]
dc = [float(s["dcrit_deg"]) for s in segs]
tq = [float(s["segment_torque_Nm"]) for s in segs]
cp = [float(s["torque_capacity_Nm"]) for s in segs]

da_forms = {f"{v:.1f}" for v in da}
dc_forms = {f"{v:.1f}" for v in dc}
tq_forms = {f"{v:.1f}" for v in tq}
cp_forms = {f"{v:.1f}" for v in cp}
ok("twist drawn |dalpha| forms recompute", da_forms == {"33.9", "33.8", "33.7", "33.5", "22.8"},
   repr(sorted(da_forms)))
ok("twist drawn dcrit forms recompute", dc_forms == {"98.9", "92.6"}, repr(sorted(dc_forms)))
ok("twist drawn torque forms recompute", tq_forms == {"396.8", "397.2", "397.5", "397.7"},
   repr(sorted(tq_forms)))
ok("twist drawn capacity forms recompute",
   cp_forms == {"805.0", "808.7", "812.2", "815.7", "1069.9"}, repr(sorted(cp_forms)))
ok("twist ledger carries all drawn value forms",
   (da_forms | dc_forms | tq_forms | cp_forms) <= twist_led)
ok("twist ledger carries the floor form", "realisability floor 72.25°" in twist_led)

# G2: the torsional FoS gate at capacity / 1.5
gates = [c / 1.5 for c in cp]
gate_forms = [f"{g:.1f}" for g in gates]
ok("G2 capacity/1.5 positions match the figures-seat receipt list",
   gate_forms == ["536.7", "539.1", "541.5", "543.8", "713.3"], repr(gate_forms))
ok("G2 no numerals draw at the gate marks",
   not (set(gate_forms) & twist_led),
   f"ledger overlap {sorted(set(gate_forms) & twist_led)}")
opt = (REPO / "src/trpt_optimization.jl").read_text()
ok("G2 signed basis OPT_TORSION_FOS_REQUIRED = 1.5 in source",
   "OPT_TORSION_FOS_REQUIRED = 1.5" in opt)

# floor form vs NR-053 full value
ok("G2/floor 72.25 equals the NR-053 full value at 2 dp",
   f"{72.24720983805331:.2f}" == "72.25", f"{72.24720983805331:.2f}")

# SVG geometry: the five gate triangles sit at px(cap/1.5) on panel B
tw_raw = TK.joinpath("twist-limit.svg").read_text()
# panel B: axes rect [0.145, 0.338, 0.825, 0.297], xlim (-200, 1250), 547.2 px wide
BX_L = 0.145 * 547.2
BPX = lambda x: BX_L + (x + 200.0) * (0.825 * 547.2 / 1450.0)  # noqa: E731
# squares (capacity) and triangles (gate) share the same style string;
# classify each red white-fill panel-B marker by proximity to its
# expected pixel position, and require a consistent marker id per class
red_markers = re.findall(
    r'<use xlink:href="#(m[0-9a-f]+)" x="([0-9.]+)" y="([0-9.]+)" '
    r'style="fill: #ffffff; stroke: #b32222; stroke-width: 1.4',
    tw_raw)
panel_b_red = [(mid, float(x), float(y)) for mid, x, y in red_markers
               if 190.0 < float(y) < 330.0]
sq_pred = [BPX(c) for c in cp]
tri_pred = [BPX(g) for g in gates]
tri_ids, sq_ids = set(), set()
tri_xs, sq_xs = [], []
for mid, x, y in panel_b_red:
    if min(abs(x - p) for p in tri_pred) <= 1.0:
        tri_ids.add(mid)
        tri_xs.append(x)
    elif min(abs(x - p) for p in sq_pred) <= 1.0:
        sq_ids.add(mid)
        sq_xs.append(x)
ok("twist SVG carries 5 gate triangles on panel B", len(tri_xs) == 5,
   f"{len(tri_xs)} triangles, {len(sq_xs)} squares")
ok("twist SVG carries 5 capacity squares on panel B", len(sq_xs) == 5,
   f"{len(tri_xs)} triangles, {len(sq_xs)} squares")
ok("twist SVG gate marker ids consistent (one id, distinct from squares)",
   len(tri_ids) == 1 and len(sq_ids) == 1 and tri_ids != sq_ids,
   f"tri {tri_ids} sq {sq_ids}")
if len(tri_xs) == 5:
    errs = [abs(a - b) for a, b in zip(sorted(tri_xs), sorted(tri_pred))]
    ok("twist SVG gate triangles at px(capacity/1.5)",
       max(errs) < 1.0,
       f"svg {[round(v, 2) for v in sorted(tri_xs)]} vs "
       f"{[round(v, 2) for v in sorted(tri_pred)]} maxerr {max(errs):.3f}")
    # self-consistency: the per-segment slope maps torque -> capacity -> gate
    dots = re.findall(
        r'<use xlink:href="#(m[0-9a-f]+)" x="([0-9.]+)" y="([0-9.]+)" '
        r'style="fill: #2e8c57; stroke: #2e8c57"', tw_raw)
    dot_panel_b = [(float(x), float(y)) for _, x, y in dots
                   if 190.0 < float(y) < 330.0]
    if len(dot_panel_b) == 5:
        by_y = {}
        for mid, x, y in panel_b_red:
            if mid in sq_ids:
                by_y.setdefault(round(y, 1), {})["sq"] = x
            if mid in tri_ids:
                by_y.setdefault(round(y, 1), {})["tri"] = x
        for x, y in dot_panel_b:
            by_y.setdefault(round(y, 1), {})["dot"] = x
        ratios = sorted(
            (y, d) for y, d in by_y.items()
            if {"tri", "sq", "dot"} <= set(d))
        if len(ratios) == 5:
            exp = sorted((g - c) / (c - t) for g, c, t in zip(gates, cp, tq))
            got = sorted((d["tri"] - d["sq"]) / (d["sq"] - d["dot"])
                         for _, d in ratios)
            ok("twist SVG gate geometry self-consistent per segment",
               max(abs(a - b) for a, b in zip(got, exp)) < 0.02,
               f"svg {[round(v, 4) for v in got]} vs data "
               f"{[round(v, 4) for v in exp]}")
        else:
            ok("twist SVG per-row torque/capacity/gate grouping", False,
               f"{len(ratios)} complete rows")
    else:
        ok("twist SVG carries 5 torque dots on panel B", False,
           f"{len(dot_panel_b)} dots")

# NR-040 cross-read: capacity over demand per segment
margins = [c / t for c, t in zip(cp, tq)]
ok("NR-040 margins recompute from the extract (3 dp)",
   [f"{m:.3f}" for m in margins] == ["2.029", "2.036", "2.044", "2.051", "2.694"],
   repr([f"{m:.3f}" for m in margins]))
tcap = (TK / "captions.md").read_text()
ok("twist caption prints the gate and the floor cites",
   "capacity divided by 1.5 (NR-052)" in tcap and "72.25°" in tcap
   and "(NR-053)" in tcap)
ok("twist caption prints the least margin cite", "2.03 (NR-040)" in tcap)
for rid in ("NR-022", "NR-023", "NR-040", "NR-052", "NR-053"):
    signed[rid], rowline = register_row_signed(rid)
    ok(f"twist cited row {rid} signed", signed[rid], rowline)

# ---------------------------------------------------------------- S3 F-REPRO
print()
print("== S3. F-REPRO counter-runs (two per kit, byte-compared) ==")
for name, script, slug in (("ring-utilisation", RK / "ring-utilisation.py",
                            "ring-utilisation"),
                           ("twist-limit", TK / "twist-limit.py", "twist-limit")):
    files = [f"{slug}.svg", f"{slug}.pdf", f"{slug}.png", "label-ledger.txt"]
    outs = []
    for i in (1, 2):
        d = OUT / f"{slug}-run{i}"
        d.mkdir(parents=True, exist_ok=True)
        cp = subprocess.run([PY, str(script), "--script-commit", "e3d664c",
                             "--outdir", str(d)],
                            capture_output=True, text=True, cwd=str(REPO))
        (d / "stdout.log").write_text(cp.stdout)
        outs.append(d)
        ok(f"{name} counter-run {i} rc=0", cp.returncode == 0, f"rc {cp.returncode}")
        if cp.returncode != 0:
            print(cp.stderr[-600:])
    for f in files:
        c = sha(script.parent / f)
        a = sha(outs[0] / f)
        b = sha(outs[1] / f)
        ok(f"{name} {f} run1==committed==run2", a == c and b == a, f"sha {a[:12]}")
    for i in (1, 2):
        ok(f"{name} run{i} F-LABEL self-check",
           "F-LABEL self-check: OK" in (outs[i - 1] / "stdout.log").read_text())

print()
npass = sum(RESULTS)
print(f"SUMMARY: {npass}/{len(RESULTS)} checks pass")
sys.exit(0 if npass == len(RESULTS) else 1)

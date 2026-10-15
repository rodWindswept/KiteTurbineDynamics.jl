#!/usr/bin/env python3
"""sv_cg_register_read_check.py — the corner-grid drawn-set register read.

The science-validator read at the corner-machines fold (draft v0.51). It
answers the figures-seat handoff: "the drawn set reads NR-051 to the signed
digits. The seat marker cites NR-044 and NR-051 only."

Sections:
  A. pins — the read tip, the kit output hashes, the source hashes and the
     commit pins.
  B. the seat marker — exact form, the cite scope, the signed rows and the
     cite-set agreement across the manifest, the kit register, the appendix
     and the plate stamps.
  C. the drawn set — the delivered PDF text layer: title, subtitle, corners,
     tags and objectives once each in the signed order; the bbox pairing; the
     numeral census (no other value numeral prints).
  D. the source chain — telemetry rows, the extract, the register display
     forms, the mint log and the checks log.
  E. the fold delta and the appendix cells.

Reads only; writes nothing. Run from the repo root:
  /usr/bin/python3 scratch/sv_cg_register_read_check.py
Exit 0 and token SV_CG_REGISTER_READ_DONE iff every check passes.
"""
import csv
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
TIP = "a196183"
BASE = "fc3a602"
KIT = REPO / "docs" / "reporting" / "figures" / "machine-corner-grid"
DRAFT = REPO / "docs" / "reporting" / "drafts" / "2026-10-08-report-first-draft.md"
REGISTER = REPO / "docs" / "reporting" / "numbers-register.md"
FIGMAP = REPO / "docs" / "reporting" / "figures" / "figure-map.md"
RD = REPO / "scripts" / "results" / "v13_5kw_masslift_len18.8_rotorcount_bankderate2"

SIGNED = [
    ("low PC1 / low PC2", "i1-g13-i1", 1, 13, 1, "-1.454423", "-1.238178", "60.646"),
    ("low PC1 / high PC2", "i1-g7-i7", 1, 7, 7, "-2.088227", "0.152353", "58.864"),
    ("high PC1 / low PC2", "i2-g21-i4", 2, 21, 4, "1.132051", "-1.488592", "33.704"),
    ("high PC1 / high PC2", "i3-g26-i8", 3, 26, 8, "1.679755", "3.050611", "33.812"),
]
MARKER = ("[Figure seated: figure-map row 23 (the corner machines, slug "
          "`machine-corner-grid`). Values cite NR-044 and NR-051.]")

n = 0
fails = []


def chk(name, good, detail=None):
    global n
    n += 1
    if good:
        print(f"  OK   {name}")
    else:
        fails.append(name)
        print(f"  FAIL {name}" + (f" :: {detail}" if detail is not None else ""))


def sha256(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest()


def git(*args):
    r = subprocess.run(["git", "-C", str(REPO), *args], capture_output=True, text=True)
    return r.returncode, r.stdout.strip(), r.stderr.strip()


def pdftotext(mode, pdf):
    r = subprocess.run(["pdftotext", mode, str(pdf), "-"], capture_output=True, text=True)
    if r.returncode != 0:
        raise RuntimeError(r.stderr)
    return r.stdout


def norm(s):
    return re.sub(r"\s+", " ", s)


print("sv_cg_register_read_check — the corner-grid drawn-set register read")
print(f"repo {REPO}  tip {TIP}  base {BASE}")
print()

# ---------- load the record ----------
draft = DRAFT.read_text()
dlines = draft.splitlines()
register = REGISTER.read_text()
figmap = FIGMAP.read_text()
manifest = json.loads((KIT / "manifest.json").read_text())
kitreg = (KIT / "register-status.md").read_text()
extract_log = (KIT / "extract-corner-grid.log").read_text()
checks_log = (KIT / "checks.log").read_text()
extract_rows = list(csv.DictReader(
    l for l in (KIT / "extract-corner-grid.csv").read_text().splitlines()
    if not l.startswith("#")))
plate = pdftotext("-layout", KIT / "machine-corner-grid.pdf")
plate_n = norm(plate)
bbox = pdftotext("-bbox-layout", KIT / "machine-corner-grid.pdf")

# ---------- A. pins ----------
print("A. pins")
rc, out, _ = git("cat-file", "-t", TIP)
chk(f"A1 the read tip {TIP} resolves as a commit", rc == 0 and out == "commit", out)
for sha, name in [("a4b4057", "script"), ("dd3cc6a", "data"), ("b02ecdf", "mint")]:
    rc, out, _ = git("cat-file", "-t", sha)
    chk(f"A2 the {name} commit {sha} resolves", rc == 0 and out == "commit", out)
rc, out, _ = git("log", "--oneline", "--format=%h", f"{BASE}..{TIP}")
span = out.splitlines()
chk("A3 the fold span reads the three commits",
    span == ["a196183", "c2e4190", "1061878"], str(span))
pinned = [
    "docs/reporting/drafts/2026-10-08-report-first-draft.md",
    "docs/reporting/figures/machine-corner-grid/extract-corner-grid.csv",
    "docs/reporting/figures/machine-corner-grid/manifest.json",
    "docs/reporting/figures/machine-corner-grid/checks.log",
    "docs/reporting/figures/machine-corner-grid/machine-corner-grid.pdf",
    "docs/reporting/figures/machine-corner-grid/machine-corner-grid.png",
    "docs/reporting/figures/machine-corner-grid/machine-corner-grid.svg",
]
for path in pinned:
    rc, _, _ = git("diff", "--quiet", TIP, "--", path)
    chk(f"A4 the working tree {Path(path).name} equals the read tip", rc == 0)
rc, out, _ = git("log", "-1", "--format=%H", "--",
                 "docs/reporting/figures/machine-corner-grid/machine-corner-grid.jl")
chk("A5 the generator last touch reads the script pin a4b4057", out.startswith("a4b4057"), out)
for isl in (1, 2, 3):
    rc, out, _ = git("log", "-1", "--format=%h", "--",
                     f"scripts/results/v13_5kw_masslift_len18.8_rotorcount_bankderate2/island_{isl}/telemetry.csv")
    chk(f"A6 island_{isl} telemetry last touch reads dd3cc6a", out == "dd3cc6a", out)
outs = manifest.get("outputs", {})
for fname, key in [("machine-corner-grid.png", "png"), ("machine-corner-grid.svg", "svg"),
                   ("machine-corner-grid.pdf", "pdf"), ("checks.log", "checks")]:
    got = sha256(KIT / fname)
    chk(f"A7 the {key} sha256 equals the manifest pin", got == outs.get(fname), f"{got} vs {outs.get(fname)}")
got = sha256(KIT / "extract-corner-grid.csv")
chk("A8 the extract sha256 equals the manifest pin", got == manifest["extract"]["sha256"])
for isl, want in [(1, "6f359c33f174d5dc98b1252e29fdba6eac8dbae15dd71d46ef8bbed6acc9bd2f"),
                  (2, "54172ce5a64b22903a2428f870b499f13da53c6b065600d8a01edfd882b29827"),
                  (3, "34d40e8ea960a1e04c83df58df9e24047cfcf7eb3deff3278807f1147b8d60b0")]:
    got = sha256(RD / f"island_{isl}" / "telemetry.csv")
    chk(f"A9 island_{isl} telemetry sha256 equals the mint log pin", got == want, got)
    chk(f"A10 island_{isl} telemetry hash recorded in the mint log", want in extract_log)
chk("A11 the manifest slug reads machine-corner-grid", manifest.get("slug") == "machine-corner-grid")
chk("A12 the manifest script commit reads a4b4057", manifest.get("script_commit") == "a4b4057")
chk("A13 the manifest data commit reads dd3cc6a", manifest.get("data_commit") == "dd3cc6a")
chk("A14 the manifest registers read NR-044 and NR-051",
    manifest.get("registers") == ["NR-044", "NR-051"], str(manifest.get("registers")))

# ---------- B. the seat marker ----------
print("B. the seat marker")
mlines = [i for i, l in enumerate(dlines) if l == MARKER]
chk("B1 the row-23 seat marker reads its exact form, once", len(mlines) == 1, str(len(mlines)))
marker_nrs = re.findall(r"NR-\d{3}", MARKER)
chk("B2 the marker cites NR-044 and NR-051 only", sorted(marker_nrs) == ["NR-044", "NR-051"], str(marker_nrs))
chk("B3 no second row-23 seat marker reads in the draft",
    len(re.findall(r"figure-map row 23 \(the corner machines", draft)) == 1)
seats = [i for i, l in enumerate(dlines) if l.startswith("[Figure seated:")]
chk("B4 the seat census reads eight", len(seats) == 8, str(len(seats)))
i20 = next(i for i, l in enumerate(dlines) if "figure-map row 20" in l)
i21 = next(i for i, l in enumerate(dlines) if "figure-map row 21" in l)
i23 = mlines[0]
i35 = next(i for i, l in enumerate(dlines) if l.startswith("### 3.5"))
i9 = next(i for i, l in enumerate(dlines) if "figure-map row 9" in l)
chk("B5 the marker sits with the field pair, ahead of the levers block and the strip",
    i20 < i21 < i23 < i35 < i9, f"{i20},{i21},{i23},{i35},{i9}")
for rid, date in [("NR-044", "2026-10-13"), ("NR-051", "2026-10-14")]:
    rowline = next((l for l in register.splitlines() if l.startswith(f"| {rid} |")), None)
    chk(f"B6 {rid} reads signed at the register",
        rowline is not None and f"signed (science-validator, {date})" in rowline)
nrs = set(re.findall(r"NR-\d{3}", kitreg))
chk("B7 the kit register cites NR-044 and NR-051 only", nrs == {"NR-044", "NR-051"}, str(nrs))
aprow = next((l for l in dlines if l.startswith("| The corner machines |")), None)
chk("B8 the appendix row cites NR-044, NR-051 at the script pin a4b4057",
    aprow is not None and "NR-044, NR-051" in aprow and "`a4b4057`" in aprow
    and "corner-grid-extract-2026-10-15-picks" in aprow, aprow)
plate_nr = set(re.findall(r"NR-\d{3}", plate))
chk("B9 the plate names NR-044 and NR-051 only", plate_nr == {"NR-044", "NR-051"}, str(plate_nr))
fmrow = next((l for l in figmap.splitlines() if l.startswith("| 23 |")), None)
chk("B10 figure-map row 23 carries the slug and the title",
    fmrow is not None and "machine-corner-grid" in fmrow and "The corner machines" in fmrow)

# ---------- C. the drawn set ----------
print("C. the drawn set (the delivered PDF text layer)")
TITLE = "The corner machines: one typical design from each corner of the PC1-PC2 field"
chk("C1 the title reads once", plate_n.count(TITLE) == 1, str(plate_n.count(TITLE)))
chk("C2 the subtitle reads its forms",
    "Built geometry at one shared scale" in plate_n
    and "one pick per window corner, the nearest feasible design (NR-051)" in plate_n)
for k, (corner, tag, isl, gen, idx, pc1, pc2, obj) in enumerate(SIGNED):
    chk(f"C3.{k+1} corner name reads once: {corner}", plate_n.count(corner) == 1)
    chk(f"C4.{k+1} tag reads once: {tag}", plate_n.count(tag) == 1)
    chk(f"C5.{k+1} objective reads once: objective {obj} kg", plate_n.count(f"objective {obj} kg") == 1)
idx_corner = [plate_n.index(c[0]) for c in SIGNED]
idx_tag = [plate_n.index(c[1]) for c in SIGNED]
idx_obj = [plate_n.index(f"objective {c[7]} kg") for c in SIGNED]
chk("C6 the corner order reads the signed order", idx_corner == sorted(idx_corner), str(idx_corner))
chk("C7 the tag order reads the signed order", idx_tag == sorted(idx_tag), str(idx_tag))
chk("C8 the objective order reads the signed order", idx_obj == sorted(idx_obj), str(idx_obj))
chk("C9 the objective strip word reads four times",
    len(re.findall(r"objective \d", plate_n)) == 4, str(len(re.findall(r"objective \d", plate_n))))
words = [(float(a), float(b), float(c), float(d), e) for a, b, c, d, e in re.findall(
    r'<word xMin="([\d.]+)" yMin="([\d.]+)" xMax="([\d.]+)" yMax="([\d.]+)">([^<]+)</word>', bbox)]
byname = {}
for xmin, ymin, xmax, ymax, t in words:
    byname.setdefault(t, []).append((xmin, ymin, xmax, ymax))
for k, (corner, tag, isl, gen, idx, pc1, pc2, obj) in enumerate(SIGNED):
    tw = byname[tag][0]
    nw = byname[obj][0]
    tx = (tw[0] + tw[2]) / 2
    nx = (nw[0] + nw[2]) / 2
    chk(f"C10.{k+1} the tag sits above its objective ({tag})", tw[3] < nw[1], f"{tw[3]} {nw[1]}")
    others = sorted((abs(((byname[t2][0][0] + byname[t2][0][2]) / 2) - nx), t2) for t2 in [c[1] for c in SIGNED])
    chk(f"C11.{k+1} the nearest tag to objective {obj} reads {tag}", others[0][1] == tag, str(others[0]))
    chk(f"C12.{k+1} the tag-objective x offset stays small ({tag})", abs(tx - nx) < 20.0, f"{tx} {nx}")
obj_x = [(byname[c[7]][0][0] + byname[c[7]][0][2]) / 2 for c in SIGNED]
chk("C13 the objective x positions read left to right in the signed order", obj_x == sorted(obj_x), str(obj_x))
decimals = re.findall(r"\d+\.\d+", plate)
chk("C14 the decimal tokens read the four objectives, once each",
    sorted(decimals) == sorted(c[7] for c in SIGNED), str(decimals))
chk("C15 the scale bar token reads once", plate.count("5m") == 1, str(plate.count("5m")))
digit_toks = {t for t in re.findall(r"\S+", plate) if re.search(r"\d", t)}
expected_toks = {"60.646", "58.864", "33.704", "33.812", "5m", "(NR-051)", "NR-044", "NR-051",
                 "PC1", "PC2", "PC1-PC2", "[1,99]", "a4b4057", "dd3cc6a", "1970-01-01",
                 "corner-grid-extract-2026-10-15-picks.csv",
                 "i1-g13-i1", "i1-g7-i7", "i2-g21-i4", "i3-g26-i8"}
chk("C16 every digit-bearing token answers to the signed set",
    digit_toks == expected_toks, str(sorted(digit_toks ^ expected_toks)))
for name, pieces in [
    ("source", ["source: data commit dd3cc6a", "extract corner-grid-extract-2026-10-15-picks.csv",
                "picks the nearest feasible design per [1,99] window corner (NR-051)"]),
    ("rows", ["rows NR-044", "NR-051", "script commit a4b4057", "engine CairoMakie",
              "PDF date normalised to 1970-01-01"]),
    ("frame", ["shaft frame: distance along the shaft is vertical",
               "the operating elevation is not drawn"]),
]:
    chk(f"C17 the {name} stamp reads", all(s in plate_n for s in pieces))
legend = ["ground ring", "ring, transmission", "ring, cone", "ring, harvest",
          "swept annulus", "trapezoid", "TRPT lines"]
chk("C18 the legend reads its seven entries",
    all(s in plate_n for s in legend) and re.search(r"\bblade\b", plate_n) is not None)

# ---------- D. the source chain ----------
print("D. the source chain")
tele_rows = {}
for isl in (1, 2, 3):
    lines = (RD / f"island_{isl}" / "telemetry.csv").read_text().splitlines()
    rd = csv.DictReader(l for l in lines if not l.startswith("#"))
    for row in rd:
        tele_rows[(int(row["island"]), int(row["gen"]), int(row["idx"]))] = row
for k, (corner, tag, isl, gen, idx, pc1, pc2, obj) in enumerate(SIGNED):
    row = tele_rows.get((isl, gen, idx))
    chk(f"D1.{k+1} telemetry {tag}: status ok, fitness {obj}",
        row is not None and row["status"] == "ok" and row["fitness"] == obj,
        str(row and (row["status"], row["fitness"])))
chk("D2 the extract carries four rows", len(extract_rows) == 4, str(len(extract_rows)))
for k, row in enumerate(extract_rows):
    corner, tag, isl, gen, idx, pc1, pc2, obj = SIGNED[k]
    chk(f"D3.{k+1} extract row {tag}: tag, fitness and pc rounding",
        row["tag"] == tag and row["fitness"] == obj
        and format(float(row["pc1"]), ".6f") == pc1
        and format(float(row["pc2"]), ".6f") == pc2,
        f"{row['tag']} {row['fitness']} {float(row['pc1']):.6f} {float(row['pc2']):.6f}")
reg_rows = re.findall(
    r"^\| ((?:low|high) PC1 / (?:low|high) PC2) \| `([^`]+)` \| (-?[\d.]+), (-?[\d.]+) \| ([\d.]+) \|",
    register, re.M)
chk("D4 the register tables read four pick rows", len(reg_rows) == 4, str(len(reg_rows)))
for k, (corner, tag, rpc1, rpc2, robj) in enumerate(reg_rows):
    want = SIGNED[k]
    chk(f"D5.{k+1} register pick row {tag} reads the signed values",
        (corner, tag, rpc1, rpc2, robj) == (want[0], want[1], want[5], want[6], want[7]),
        str((corner, tag, rpc1, rpc2, robj)))
rlines = register.splitlines()
di = next(i for i, l in enumerate(rlines) if "The plate prints the objective at 3 dp:" in l)
disp = rlines[di].strip() + " " + rlines[di + 1].strip()
nums = re.findall(r"`([\d.]+)`", disp)
chk("D6 the register display-form sentence signs the four printed forms",
    nums == [c[7] for c in SIGNED], str(nums))
chk("D7 the display sentence reads the four forms in the signed order",
    "`60.646`, `58.864`, `33.704` and `33.812`" in disp, disp)
chk("D8 the mint log reads the picks equal the signed set",
    "the picks equal the signed set (NR-051): PASS" in extract_log)
chk("D9 the mint log reads the objective display-set PASS",
    "the objective forms read the NR-051 display set" in extract_log
    and "60.646 / 58.864 / 33.704 / 33.812" in extract_log)
chk("D10 the mint log reads the 128-field token bind",
    "the tokens byte-read from the source rows, 128 fields: PASS" in extract_log)
chk("D11 the checks log reads the corner order OK line",
    "corner order (NR-051): OK" in checks_log
    and "the four signed picks in the signed order" in checks_log)
chk("D12 the checks log reads the four objective labels drawn",
    "objective labels (NR-051): 4 drawn" in checks_log and "ALL OK" in checks_log)

# ---------- E. the fold delta and the appendix cells ----------
print("E. the fold delta and the appendix cells")
rc, out, _ = git("diff", f"{BASE}..{TIP}", "--", "docs/reporting/drafts/2026-10-08-report-first-draft.md")
adds = [l[1:] for l in out.splitlines() if l.startswith("+") and not l.startswith("+++")]
dels = [l[1:] for l in out.splitlines() if l.startswith("-") and not l.startswith("---")]
expect_adds = [
    "Internal engineering report. Draft v0.51. Date 2026-10-15.",
    MARKER,
    "",
    "One row per built exhibit. All eight read dataset commit `dd3cc6a`.",
    "| The corner machines | `corner-grid-extract-2026-10-15-picks` | NR-044, NR-051 | `a4b4057` | `post-95c385d_wind-authority` |",
    "",
    "The corner machines:",
    "",
    "- `png` `517a77bf032bec1c0cde4eea7db93fdbc47470c65c9d76e6c4e58249436a2568`",
    "- `svg` `b2e4055d39b7ff72d1e10ea11f59d3bbc8af145ef8a30dc83b7016530b4de0b2`",
    "- `pdf` `298a0f8e4e674dc8e13b64715ee0dfd383e7671d9f3c262a376abe7d5b5114c6`",
    "- `checks` `e6bcfca931d36089dd2a8d6e9c8414fb49230c0d2110717176cf1e0ae385ffbe`",
]
expect_dels = [
    "Internal engineering report. Draft v0.50. Date 2026-10-15.",
    "One row per built exhibit. All seven read dataset commit `dd3cc6a`.",
]
chk("E1 the fold delta adds read the twelve declared lines", sorted(adds) == sorted(expect_adds), str(sorted(adds)))
chk("E2 the fold delta removes read the two declared lines", sorted(dels) == sorted(expect_dels), str(dels))
i = draft.rfind("The corner machines:")
m = {}
for l in draft[i:].splitlines()[1:8]:
    mm = re.match(r"^- `(png|svg|pdf|checks)` `([0-9a-f]{64})`$", l)
    if mm:
        m[mm.group(1)] = mm.group(2)
for key, fname in [("png", "machine-corner-grid.png"), ("svg", "machine-corner-grid.svg"),
                   ("pdf", "machine-corner-grid.pdf"), ("checks", "checks.log")]:
    got = sha256(KIT / fname)
    chk(f"E3 the appendix {key} cell equals the delivered bytes", m.get(key) == got, f"{m.get(key)} vs {got}")

print()
print(f"checks: {n}, fail: {len(fails)}")
if fails:
    for f in fails:
        print("  FAIL:", f)
    sys.exit(1)
print("SV_CG_REGISTER_READ_DONE")

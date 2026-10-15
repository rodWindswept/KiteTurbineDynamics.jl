#!/usr/bin/env python3
"""av corner-grid counter-read: F-CITE + F-VALUE.

Reads the delivered kit bytes, the raw bankderate2 telemetry, the register,
the map, the SPEC, the receipts. Recomputes the projection and the four
corner picks from the raw draw columns. Censuses the drawn text through the
PDF text layer (the SVG carries glyph paths). Flags cite-precision findings.

Run: /usr/bin/python3 scratch/av_cg_cite_value.py     (repo root)
Writes: stdout (tee to scratch/av_cg_cite_value.log)
"""
import csv
import hashlib
import json
import re
import struct
import subprocess
import sys
from pathlib import Path

import numpy as np

ROOT = Path(".")
KIT = ROOT / "docs/reporting/figures/machine-corner-grid"
MAP = ROOT / "docs/reporting/figures/figure-map.md"
REG = ROOT / "docs/reporting/numbers-register.md"
SPEC = ROOT / "docs/reporting/figures/machine-renderer/SPEC.md"
RD = ROOT / "scripts/results/v13_5kw_masslift_len18.8_rotorcount_bankderate2"
SEAT_SV = ROOT / "handovers/handover-2026-10-14-reporting-room-science-validator.md"
SW30 = ROOT / "docs/reporting/room-responses/science-writer-2026-10-15-sweep-30.md"
RSTAT = KIT / "register-status.md"

N = 0
FAILS = []
FINDINGS = []


def chk(name, good, detail=""):
    global N
    N += 1
    if not good:
        FAILS.append(name + (f" :: {detail}" if detail else ""))
    print(f"  {'OK  ' if good else 'FAIL'} {name}" + (f"   [{detail}]" if (detail and not good) else ""))


def sha(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest()


def md5(p):
    return hashlib.md5(Path(p).read_bytes()).hexdigest()


def git(*args):
    return subprocess.run(["git", *args], capture_output=True, text=True).stdout.strip()


print("== av corner-grid counter-read: F-CITE + F-VALUE ==")
print(f"HEAD {git('rev-parse','--short','HEAD')}  branch {git('rev-parse','--abbrev-ref','HEAD')}")

man = json.loads((KIT / "manifest.json").read_text())
extract_text = (KIT / "extract-corner-grid.csv").read_text()
clog = (KIT / "checks.log").read_text()

# ---------------------------------------------------------------- A. pins
print("\n-- A. delivered bytes and pins --")
chk("extract sha == manifest == 03abd0c6…",
    sha(KIT / "extract-corner-grid.csv") == man["extract"]["sha256"] ==
    "03abd0c660e0ad22db89f767a7b033c18db82f67dde69593c31cbb3a3919a4d5")
chk("script sha == manifest script pin", sha(KIT / "machine-corner-grid.jl") == man["script"]["sha256"])
for f, key in [("machine-corner-grid.png", "machine-corner-grid.png"),
               ("machine-corner-grid.svg", "machine-corner-grid.svg"),
               ("machine-corner-grid.pdf", "machine-corner-grid.pdf"),
               ("checks.log", "checks.log")]:
    chk(f"output pin {f} == manifest", sha(KIT / f) == man["outputs"][key])
chk("checks.log carries the extract sha line",
    f"extract: docs/reporting/figures/machine-corner-grid/extract-corner-grid.csv  sha256 {man['extract']['sha256']}" in clog)
chk("checks.log output block == delivered hashes",
    all(f"  {f}  {sha(KIT / f)}" in clog for f in
        ("machine-corner-grid.png", "machine-corner-grid.svg", "machine-corner-grid.pdf")))
chk("checks.log: ALL OK", "checks: ALL OK" in clog)
chk("checks.log: corner order OK", "corner order (NR-051): OK" in clog)
chk("checks.log: objective labels 4 drawn ALL OK", "objective labels (NR-051): 4 drawn · ALL OK" in clog)
chk("checks.log: -dg/-zg normalise, 1 replacement",
    "pdf normalisation: clean -dg ok · CreationDate replacements 1 · clean -zg ok" in clog)
chk("checks.log script commit a4b4057", "script commit: a4b4057" in clog)
chk("checks.log toolchain line",
    "toolchain: julia 1.12.5 · CairoMakie 0.15.11 · mutool 1.23.10" in clog)

png = (KIT / "machine-corner-grid.png").read_bytes()
w, h = struct.unpack(">II", png[16:24])
chk("PNG dims 2616 x 1848 == 3 x (872 x 616)", (w, h) == (2616, 1848))
svg = (KIT / "machine-corner-grid.svg").read_text()
chk("SVG root 872 x 616", 'width="872" height="616" viewBox="0 0 872 616"' in svg)
chk("SVG carries glyph paths, no text layer (0 <text) — the recorded R2 state", svg.count("<text") == 0 and svg.count("<path") > 0)
pdfb = (KIT / "machine-corner-grid.pdf").read_bytes()
chk("PDF CreationDate normalised to 1970-01-01, single date token",
    pdfb.count(b"D:19700101000000+00'00") == 1 and b"D:20" not in pdfb.replace(b"D:19700101000000+00'00", b""))

chk("manifest: family mode, corner variant", man["mode"] == "family" and man["variant"] == "corner-grid")
chk("manifest: script commit a4b4057", man["script_commit"] == "a4b4057")
chk("manifest: registers [NR-044, NR-051]", man["registers"] == ["NR-044", "NR-051"])
chk("manifest: data commit dd3cc6a", man["data_commit"] == "dd3cc6a")
chk("manifest: toolchain pins", man["toolchain"]["julia"] == "1.12.5" and
    man["toolchain"]["cairomakie"] == "0.15.11" and man["toolchain"]["mutool"] == "1.23.10" and
    man["toolchain"]["pdf_date_normalised_to"] == "1970-01-01T00:00:00+00:00")

# campaign knobs vs the recorded campaign constants
seeds = (ROOT / "scripts/compute_seeds.jl").read_text()
chk("knobs: K_MPPT_5KW_HONEST = 2.24 in compute_seeds.jl",
    "const K_MPPT_5KW_HONEST = 2.24" in seeds and man["knobs"]["k_mppt"] == 2.24)
bf_expect = 0.85 ** (1 / 3)
chk("knobs: BLOCKING_WIND_FACTOR_5KW = 0.85^(1/3) in compute_seeds.jl",
    "const BLOCKING_WIND_FACTOR_5KW = 0.85^(1 / 3)" in seeds and
    abs(man["knobs"]["blocking_factor"] - bf_expect) < 1e-15)
chk("knobs: power_W 5000, v_rated 11, tether 18.8, split 0.6, cone 22 deg, spacing 0.8",
    man["knobs"]["power_W"] == 5000 and man["knobs"]["v_rated"] == 11 and
    man["knobs"]["tether_length"] == 18.8 and man["knobs"]["power_split"] == 0.6 and
    man["knobs"]["cone_slope_deg"] == 22 and man["knobs"]["rotor_spacing_frac"] == 0.8 and
    man["knobs"]["min_wall_m"] == 0.002 and man["knobs"]["t_over_D"] == 0.055)

# scale identities
X = man["scale"]["window"]["x"][1]
Ylo, Yhi = man["scale"]["window"]["y"]
mpp = man["scale"]["m_per_px"]
pw, ph = man["scale"]["panel_px"]
chk("scale: m_per_px == (Yhi-Ylo)/340", abs(mpp - (Yhi - Ylo) / 340) < 1e-15)
chk("scale: X == 206*mpp/2", abs(X - 206 * mpp / 2) < 1e-12)
chk("scale: figure 872x616 == 4*206+3*16 x 84+340+60+132",
    man["scale"]["panel_px"] == [206, 340])
chk("scale bar 5 m", man["scale"]["scale_bar_m"] == 5)

# ------------------------------------------------- B. extract vs raw tokens
print("\n-- B. extract vs the raw telemetry rows (128 fields) --")


def load_telemetry():
    rows = []
    for isl in (1, 2, 3):
        p = RD / f"island_{isl}" / "telemetry.csv"
        lines = [ln for ln in p.read_text().splitlines() if not ln.startswith("#") and ln.strip()]
        rows.extend(list(csv.DictReader(lines)))
    return rows


raw = load_telemetry()
chk("raw rows 930, 310 per island",
    len(raw) == 930 and all(sum(1 for r in raw if r["island"] == str(i)) == 310 for i in (1, 2, 3)))
mix = {}
for r in raw:
    mix[r["status"]] = mix.get(r["status"], 0) + 1
chk("status mix 508 ok / 301 reject / 110 clearance_reject / 11 reject_twist",
    mix.get("ok") == 508 and mix.get("reject") == 301 and
    mix.get("clearance_reject") == 110 and mix.get("reject_twist") == 11)
chk("telemetry files last touched at dd3cc6a",
    all(git("log", "-1", "--format=%h", "--",
            str(RD / f"island_{i}" / "telemetry.csv")) == "dd3cc6a" for i in (1, 2, 3)))

FIELDS = ("island gen idx fitness status P_mean P_end T_lift FoS twist_crossed twist_ratio "
          "clearance n_lines rings n_active r_hub r_bot bank_top bank_bot blade_scale_top "
          "blade_scale_bottom tether x1 x2 x3 x4 x5 x6 x7 x8 x9 x10").split()
ext_rows = list(csv.DictReader([ln for ln in extract_text.splitlines() if not ln.startswith("#")]))
chk("extract: 4 rows", len(ext_rows) == 4)
raw_by_key = {(r["island"], r["gen"], r["idx"]): r for r in raw}
mismatch = []
for er in ext_rows:
    rr = raw_by_key.get((er["island"], er["gen"], er["idx"]))
    if rr is None:
        mismatch.append(f"{er['tag']}: raw row not found")
        continue
    for f in FIELDS:
        if er[f] != rr[f]:
            mismatch.append(f"{er['tag']} {f}: {er[f]!r} != {rr[f]!r}")
chk("extract: all 32 fields x 4 rows byte-equal to the source rows", not mismatch, "; ".join(mismatch[:6]))

chk("extract header: run-id / dataset / computing commit",
    "# run-id: corner-grid-extract-2026-10-15-picks" in extract_text and
    "# dataset: v13_5kw_masslift_len18.8_rotorcount_bankderate2 | data commit dd3cc6a | launch a76c5e9" in extract_text and
    "# computing commit: b02ecdfda677021a86f996ec4ab11023236b1fd5" in extract_text and
    "# provenance: era=post-95c385d_wind-authority  telemetry git=a76c5e927252118abf2b2ff6bd988395583d5113" in extract_text)

# r_hub/r_bot columns read round(x1/x2, 3); n_lines reads the integer gene
ok_r = ok_n = True
for er in ext_rows:
    if er["r_hub"] != f"{round(float(er['x1']), 3):g}" or er["r_bot"] != f"{round(float(er['x2']), 3):g}":
        ok_r = False
    if er["n_lines"] != str(int(round(float(er["x4"])))):
        ok_n = False
chk("extract: r_hub/r_bot = round(x1/x2, 3)", ok_r)
chk("extract: n_lines = integer(x4)", ok_n)

# genome vector of each panel in the manifest equals the extract, exactly
ok_g = True
for er, pan in zip(ext_rows, man["panels"]):
    for j in range(1, 11):
        if float(er[f"x{j}"]) != pan["genome"][j - 1]:
            ok_g = False
chk("manifest: genome vector byte-equal to the extract (all 40 cells)", ok_g)
chk("manifest: picks in signed order", man["selection"]["picks"] ==
    ["i1-g13-i1", "i1-g7-i7", "i2-g21-i4", "i3-g26-i8"])
chk("manifest: corners in signed order", man["selection"]["corners"] ==
    ["low PC1 / low PC2", "low PC1 / high PC2", "high PC1 / low PC2", "high PC1 / high PC2"])

# ------------------------------------------------- C. recompute from raw
print("\n-- C. the projection and the picks, recomputed from the raw draw columns --")
Xm = np.array([[float(r[f"x{j}"]) for j in range(1, 11)] for r in raw])
fit = np.array([float(r["fitness"]) for r in raw])
st = np.array([r["status"] for r in raw])
gen = np.array([int(r["gen"]) for r in raw])
idx = np.array([int(r["idx"]) for r in raw])
isl = np.array([int(r["island"]) for r in raw])
feas = (st == "ok") & (fit < 1e6)
chk("feasible rows 508", int(feas.sum()) == 508)

mu = Xm.mean(axis=0)
sd = Xm.std(axis=0, ddof=1)
Xc = (Xm - mu) / sd
_, S, Vt = np.linalg.svd(Xc, full_matrices=False)
var = S ** 2 / (S ** 2).sum()
V = Vt.T
pc1 = Xc @ V[:, 0]
pc2 = Xc @ V[:, 1]

chk("NR-044: PC1 share 22.4346665772", f"{var[0]*100:.10f}" == "22.4346665772")
chk("NR-044: PC2 share 17.2630436556", f"{var[1]*100:.10f}" == "17.2630436556")
chk("NR-044: pair total 39.6977102328", f"{(var[0]+var[1])*100:.10f}" == "39.6977102328")

seed_i = int(np.where((isl == 1) & (gen == 0))[0][0])
win_i = int(np.argmin(np.where(feas, fit, np.inf)))
chk("NR-044: seed point 0.531, -1.297, fit 36.109",
    round(float(pc1[seed_i]), 3) == 0.531 and round(float(pc2[seed_i]), 3) == -1.297 and
    round(float(fit[seed_i]), 3) == 36.109)
chk("NR-044: winner point 0.885, 2.869, fit 27.364, island 3",
    round(float(pc1[win_i]), 3) == 0.885 and round(float(pc2[win_i]), 3) == 2.869 and
    round(float(fit[win_i]), 3) == 27.364 and int(isl[win_i]) == 3)

x1w, x2w = np.percentile(pc1, [1, 99])
y1w, y2w = np.percentile(pc2, [1, 99])
chk("window [1,99]: pc1 -5.133 .. 1.671, pc2 -2.178 .. 3.125",
    (round(x1w, 3), round(x2w, 3)) == (-5.133, 1.671) and (round(y1w, 3), round(y2w, 3)) == (-2.178, 3.125))

CORNERS = [("low PC1 / low PC2", x1w, y1w), ("low PC1 / high PC2", x1w, y2w),
           ("high PC1 / low PC2", x2w, y1w), ("high PC1 / high PC2", x2w, y2w)]
EXP_TAGS = ["i1-g13-i1", "i1-g7-i7", "i2-g21-i4", "i3-g26-i8"]
EXP_DIST = ["3.796523", "4.254840", "0.874883", "0.074376"]
EXP_FIT = ["60.646000", "58.864000", "33.704000", "33.812000"]
for (cname, cx, cy), etag, ed, ef, er in zip(CORNERS, EXP_TAGS, EXP_DIST, EXP_FIT, ext_rows):
    d = np.hypot(pc1 - cx, pc2 - cy)
    i = int(np.argmin(np.where(feas, d, np.inf)))
    tag = f"i{isl[i]}-g{gen[i]}-i{idx[i]}"
    chk(f"pick {cname}: {etag} at dist {ed}",
        tag == etag and f"{d[i]:.6f}" == ed)
    chk(f"pick {etag}: fit {ef} at 6 dp == extract token",
        f"{fit[i]:.6f}" == ef and ef.rstrip("0").rstrip(".") == er["fitness"])
    chk(f"pick {etag}: pc 6 dp == extract full precision",
        abs(pc1[i] - float(er["pc1"])) < 1e-9 and abs(pc2[i] - float(er["pc2"])) < 1e-9 and
        f"{pc1[i]:.6f}" == f"{float(er['pc1']):.6f}" and f"{pc2[i]:.6f}" == f"{float(er['pc2']):.6f}")
    chk(f"pick {etag}: feasible and above the winner",
        bool(feas[i]) and float(er["fitness"]) > 27.364)

# composition: rotor count = clamp(round(x6),1,3); n_lines = clamp(round(x4),3,16)
comp_ok = True
for er in ext_rows:
    rotors = 2 if float(er["x6"]) >= 1.5 else 1
    if er["tag"] in ("i1-g13-i1", "i1-g7-i7") and rotors != 2:
        comp_ok = False
    if er["tag"] in ("i2-g21-i4", "i3-g26-i8") and rotors != 1:
        comp_ok = False
chk("composition: two-rotor low-PC1 picks, one-rotor high-PC1 picks", comp_ok)

# ------------------------------------------------- D. census of drawn text (PDF text layer)
print("\n-- D. the drawn-text census (PDF text layer) --")
txt = subprocess.run(["pdftotext", str(KIT / "machine-corner-grid.pdf"), "-"],
                     capture_output=True, text=True).stdout

TITLE = "The corner machines: one typical design from each corner of the PC1-PC2 field"
SUB = ("Built geometry at one shared scale · the value under each machine is its search objective in kg, "
       "lower is better · one pick per window corner, the nearest feasible design (NR-051)")
STAMP1 = ("source: data commit dd3cc6a · extract corner-grid-extract-2026-10-15-picks.csv · "
          "picks the nearest feasible design per [1,99] window corner (NR-051)")
STAMP2 = ("rows NR-044 · NR-051 · script commit a4b4057 · engine CairoMakie · "
          "PDF date normalised to 1970-01-01")
STAMP3 = ("shaft frame: distance along the shaft is vertical · "
          "the operating elevation is not drawn")
LEGEND = ["ground ring", "ring, transmission", "ring, cone", "ring, harvest",
          "swept annulus — trapezoid", "blade", "TRPT lines"]

chk("title reads exactly once", txt.count(TITLE) == 1)
chk("subtitle reads exactly once", txt.count(SUB) == 1)
for s in [TITLE, SUB, STAMP1, STAMP2, STAMP3] + LEGEND:
    chk(f"drawn: {s[:56]!r}", s in txt)
chk("stamps 1-2-3 once each", txt.count(STAMP1) == 1 and txt.count(STAMP2) == 1 and txt.count(STAMP3) == 1)
chk("scale bar '5 m' once", len(re.findall(r"(?m)^\s*5\s*m\s*$", txt)) == 1)

pos = []
for cname, etag, eobj in zip([c[0] for c in CORNERS], EXP_TAGS, ["60.646", "58.864", "33.704", "33.812"]):
    chk(f"strip corner {cname!r} once", txt.count(cname) == 1)
    chk(f"strip tag {etag!r} once", txt.count(etag) == 1)
    chk(f"strip objective {eobj!r} once (as 'objective {eobj} kg')", txt.count(f"objective {eobj} kg") == 1)
    pos.append(txt.find(f"objective {eobj} kg"))
chk("strips read left-to-right in the NR-051 order", pos == sorted(pos))

chk("retired word 'hub' reads zero in the drawn text", re.search(r"(?i)\bhub\b", txt) is None)
for absent in ("4.580", "15.033", "27.364", "22.4", "17.3", "36.109", "5.309"):
    chk(f"no stray value {absent} in drawn text", absent not in txt)

# leftover digit scan after removing every expected string
leftover = txt
for s in [TITLE, SUB, STAMP1, STAMP2, STAMP3] + LEGEND + \
         [c[0] for c in CORNERS] + EXP_TAGS + [f"objective {o} kg" for o in ("60.646", "58.864", "33.704", "33.812")] + ["5m", "5 m"]:
    leftover = leftover.replace(s, " ")
left = re.findall(r"\S*\d\S*", leftover)
chk("no unexpected digit tokens in drawn text", not left, " ".join(left[:8]))

# ------------------------------------------------- E. register and cites
print("\n-- E. the register, the sign trail and every cite --")
reg = REG.read_text()
nr51 = reg[reg.find("## Derived row: NR-051"):]
tbl = re.findall(r"\|\s*(low PC1 / (?:low|high) PC2|high PC1 / (?:low|high) PC2)\s*\|\s*`(i\d-g\d+-i\d+)`\s*\|\s*(-?[\d.]+), (-?[\d.]+)\s*\|\s*([\d.]+)\s*\|", nr51)
chk("NR-051 table: four rows parse", len(tbl) == 4)
for (cname, etag, epc1, epc2, eob), er in zip(tbl, ext_rows):
    chk(f"NR-051 row {etag}: corner/pc 6dp/objective 3dp == extract",
        cname == er["corner"] and etag == er["tag"] and
        (float(epc1), float(epc2)) == (round(float(er["pc1"]), 6), round(float(er["pc2"]), 6)) and
        eob == er["fitness"])
nr44 = reg[reg.find("## Derived row: NR-044"):reg.find("## Derived row: NR-051")]
chk("NR-044 block: shares strings", "22.434667" in nr44 and "17.263044" in nr44 and "39.697710" in nr44)
chk("NR-044 block: status mix string",
    "508 ok, 301 reject, 110 clearance-reject and 11 reject-twist" in nr44)
chk("NR-051 sign: register appended at cb862df (git -S)",
    git("log", "--format=%h", "-S", "NR-051, the corner-grid picks", "--",
        "docs/reporting/numbers-register.md").splitlines()[:1] == ["cb862df"])
chk("NR-051 sign: science-validator seat page names cb862df",
    "The round-6 signs land at `cb862df`" in SEAT_SV.read_text())
chk("NR-051 sign: sweep 30 audits the append at cb862df",
    "takes the NR-051 row at `cb862df`, append-only." in SW30.read_text())

for c in ("dd3cc6a", "a76c5e9", "92ca9f5", "b02ecdf", "a4b4057", "2ad023c", "cb862df"):
    r = subprocess.run(["git", "cat-file", "-e", f"{c}^{{commit}}"], capture_output=True)
    chk(f"commit {c} resolves", r.returncode == 0)
chk("NR-051 register-status row present with a sign reference",
    "| NR-051 |" in RSTAT.read_text() and "Signed (science-validator" in RSTAT.read_text())

# cite-precision findings (not failures): where 8855d9a is used for the sign
rs_txt = RSTAT.read_text()
map_txt = MAP.read_text()
if "Signed (science-validator, `8855d9a`)" in rs_txt:
    line = [i for i, l in enumerate(rs_txt.splitlines(), 1) if "8855d9a" in l]
    FINDINGS.append(f"cite-precision: machine-corner-grid/register-status.md L{line[0]} cites NR-051 signed at `8855d9a`; "
                    f"the sign commit is `cb862df` (seat page + sweep 30) — fix to `cb862df`")
if "`8855d9a`" in map_txt:
    for i, l in enumerate(map_txt.splitlines(), 1):
        if "8855d9a" in l:
            FINDINGS.append(f"cite-precision: figure-map.md row 23 (L{i}) cites NR-051 signed at `8855d9a`; "
                            f"the sign commit is `cb862df` — fix to `cb862df`")

# receipt + supporting records
chk("sweep 30 receipt exists", SW30.exists())
chk("receipt cites the extract id", "corner-grid-extract-2026-10-15-picks" in (KIT / "captions.md").read_text())
chk("captions provenance line cites dd3cc6a / NR-044 / NR-051 / a4b4057",
    "Data commit `dd3cc6a`" in (KIT / "captions.md").read_text() and
    "rows NR-044, NR-051" in (KIT / "captions.md").read_text() and
    "script commit `a4b4057`" in (KIT / "captions.md").read_text())
chk("captions: all four objectives above NR-005 winner (33.704 > 27.364)",
    all(float(o) > 27.364 for o in ("33.704", "33.812")))

# ------------------------------------------------- F. checks.log consistency
print("\n-- F. checks.log vs manifest arithmetic --")
panel_lines = re.findall(r"(?m)^panel (i\d-g\d+-i\d+) \[(.+?)\] \(gen (\d+)\): (.*)$", clog)
chk("checks.log: 4 panel lines", len(panel_lines) == 4)
exp_drawn = {  # tag: (rings, polylines, rotors, blade_segments)
    "i1-g13-i1": (7, 42, 2, 14), "i1-g7-i7": (11, 80, 2, 16),
    "i2-g21-i4": (6, 15, 1, 3), "i3-g26-i8": (6, 15, 1, 3)}
for (tag, corner, g, cks), pan in zip(panel_lines, man["panels"]):
    rings, polys, quads, blades = exp_drawn[tag]
    n_lines = pan["counts"]["lines_per_gap"]
    drawn_line = f"  drawn: ring segments {rings} (incl ground) · TRPT polylines {polys} " \
                 f"({n_lines} lines x {rings-1} gaps) · rotor quads {quads} · blade segments {blades} " \
                 f"({n_lines}/rotor) · section markers 2"
    chk(f"{tag}: all six decode checks true",
        [x.split()[-1] for x in cks.split(" · ")] == ["true"] * 6)
    chk(f"{tag}: drawn counts arithmetic (polylines == lines x gaps, blades == lines x rotors)",
        polys == n_lines * (rings - 1) and blades == n_lines * quads and
        drawn_line in clog)
    chk(f"{tag}: manifest counts match", pan["counts"]["rings"] == rings and
        pan["counts"]["rotors"] == quads and pan["counts"]["blade_segments"] == blades and
        pan["counts"]["polylines"] == polys and pan["counts"]["markers"] == 2)

xpxpm = 206 / (2 * X)
ypxpm = 340 / (Yhi - Ylo)
chk("checks.log window line recomputes",
    f"window: x ±{X:.3f} m · y {Ylo:.3f} .. {Yhi:.3f} m · m_per_px {mpp:.6f} · panel 206 x 340 px · figure 872 x 616 px · scale bar 5.0 m" in clog)
chk("checks.log squareness line recomputes",
    f"axis squareness: x {xpxpm:.9f} px/m · y {ypxpm:.9f} px/m · delta {(xpxpm/ypxpm-1.0)*1e6:.4f} ppm" in clog)
chk("checks.log viewport line == layout arithmetic",
    "layout viewports: header [0,532 + 872x84] · labels [0,132 + 872x60] · footer [0,0 + 872x132] · "
    "panel1 [0,192 + 206x340] · panel4 [666,192 + 206x340]" in clog)

# repro table from the figures seat: delivered md5s == the inplace column
rt = (ROOT / "scratch/fig_cg_repro.md5").read_text()
for f in ("machine-corner-grid.png", "machine-corner-grid.svg", "machine-corner-grid.pdf",
          "manifest.json", "checks.log"):
    m = re.search(rf"{re.escape(f)}\s+inplace=([0-9a-f]{{32}})", rt)
    chk(f"figures-seat repro table: {f} inplace md5 == delivered", m and m.group(1) == md5(KIT / f))
chk("figures-seat repro table: RESULT line", "RESULT: all five outputs byte-identical across the three locations" in rt)

# extract check log
ecl = (ROOT / "scratch/fig_cg_extract_check.log").read_text()
chk("extract checker log: 54 checks, 0 fail", "checks: 54, fail: 0" in ecl)

# ------------------------------------------------- summary
print(f"\n== checks: {N}, fail: {len(FAILS)} ==")
for f in FAILS:
    print("FAILED:", f)
if FINDINGS:
    print(f"findings: {len(FINDINGS)}")
    for f in FINDINGS:
        print("FINDING:", f)
else:
    print("findings: 0")
sys.exit(1 if FAILS else 0)

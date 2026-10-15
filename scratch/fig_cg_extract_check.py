#!/usr/bin/env python3
"""fig-cg extract check: independent re-read of the corner-grid extract.

Re-derives the projection and the picks from the raw telemetry, then
checks the minted extract field by field against the source rows and
the NR-051 display forms. Read-only.

Run: /usr/bin/python3 scratch/fig_cg_extract_check.py    (repo root)
"""
import csv
import hashlib
from pathlib import Path

import numpy as np

REPO = Path(".")
RD = REPO / "scripts" / "results" / "v13_5kw_masslift_len18.8_rotorcount_bankderate2"
CSV_PATH = REPO / "docs" / "reporting" / "figures" / "machine-corner-grid" / "extract-corner-grid.csv"
LOG_PATH = REPO / "docs" / "reporting" / "figures" / "machine-corner-grid" / "extract-corner-grid.log"
BLOCK = ["island", "gen", "idx", "fitness", "status", "P_mean", "P_end",
         "T_lift", "FoS", "twist_crossed", "twist_ratio", "clearance",
         "n_lines", "rings", "n_active", "r_hub", "r_bot", "bank_top",
         "bank_bot", "blade_scale_top", "blade_scale_bottom", "tether",
         "x1", "x2", "x3", "x4", "x5", "x6", "x7", "x8", "x9", "x10"]
EXPECT = [
    ("low PC1 / low PC2", "i1-g13-i1", -1.454423, -1.238178, "60.646"),
    ("low PC1 / high PC2", "i1-g7-i7", -2.088227, 0.152353, "58.864"),
    ("high PC1 / low PC2", "i2-g21-i4", 1.132051, -1.488592, "33.704"),
    ("high PC1 / high PC2", "i3-g26-i8", 1.679755, 3.050611, "33.812"),
]

n = 0
fails = []


def chk(name, good):
    global n
    n += 1
    if not good:
        fails.append(name)
    print(f"  {'OK ' if good else 'FAIL'}  {name}")


def load():
    rows, raw = [], []
    for isl in (1, 2, 3):
        p = RD / f"island_{isl}" / "telemetry.csv"
        lines = [ln for ln in p.read_text().splitlines()
                 if not ln.startswith("#") and ln.strip()]
        rows.extend(list(csv.DictReader(lines)))
        raw.extend(lines[1:])
    return rows, raw


rows, raw = load()
X = np.array([[float(r[f"x{i}"]) for i in range(1, 11)] for r in rows])
fit = np.array([float(r["fitness"]) for r in rows])
st = np.array([r["status"] for r in rows])
feas = (st == "ok") & (fit < 1e6)
isl = np.array([int(r["island"]) for r in rows])
gen = np.array([int(r["gen"]) for r in rows])
idx = np.array([int(r["idx"]) for r in rows])
mu = X.mean(axis=0)
sd = X.std(axis=0, ddof=1)
Xc = (X - mu) / sd
_, S, Vt = np.linalg.svd(Xc, full_matrices=False)
var = S ** 2 / (S ** 2).sum()
V = Vt.T
pc1 = Xc @ V[:, 0]
pc2 = Xc @ V[:, 1]

print("PROJECTION (re-derived)")
chk("rows 930", len(rows) == 930)
chk("feasible 508", int(feas.sum()) == 508)
chk("PC1 share x1e6 224347", int(round(var[0] * 1e6)) == 224347)
chk("PC2 share x1e6 172630", int(round(var[1] * 1e6)) == 172630)
seed_i = int(np.where((isl == 1) & (gen == 0))[0][0])
win_i = int(np.argmin(np.where(feas, fit, np.inf)))
chk("seed pc 3dp (0.531, -1.297)",
    (round(float(pc1[seed_i]), 3), round(float(pc2[seed_i]), 3)) == (0.531, -1.297))
chk("winner pc 3dp (0.885, 2.869)",
    (round(float(pc1[win_i]), 3), round(float(pc2[win_i]), 3)) == (0.885, 2.869))
chk("seed fit 36.109", round(float(fit[seed_i]), 3) == 36.109)
chk("winner fit 27.364", round(float(fit[win_i]), 3) == 27.364)
chk("winner island 3", int(isl[win_i]) == 3)
chk("shares 10dp basis", abs(var[0] * 100 - 22.4346665772) < 5e-10
    and abs(var[1] * 100 - 17.2630436556) < 5e-10)

x1w, x2w = np.percentile(pc1, [1, 99])
y1w, y2w = np.percentile(pc2, [1, 99])
corners = {
    "low PC1 / low PC2": (x1w, y1w),
    "low PC1 / high PC2": (x1w, y2w),
    "high PC1 / low PC2": (x2w, y1w),
    "high PC1 / high PC2": (x2w, y2w),
}

print("PICKS (re-derived vs the signed set)")
for cname, tag in [(c, t) for c, t, *_ in EXPECT]:
    cx, cy = corners[cname]
    d = np.hypot(pc1 - cx, pc2 - cy)
    i = int(np.argmin(np.where(feas, d, np.inf)))
    got = f"i{isl[i]}-g{gen[i]}-i{idx[i]}"
    chk(f"{cname} -> {tag}", got == tag)

print("EXTRACT")
chk("the extract file exists", CSV_PATH.exists())
text = CSV_PATH.read_text()
data = [ln for ln in text.splitlines() if not ln.startswith("#")]
rrows = list(csv.DictReader(data))
chk("four data rows", len(rrows) == 4)
if len(rrows) == 4:
    chk("corner order reads the NR-051 order",
        [r["corner"] for r in rrows] == [c for c, *_ in EXPECT])
    chk("tags read the signed set", [r["tag"] for r in rrows] == [t for _, t, *_ in EXPECT])
    chk("tags distinct", len({r["tag"] for r in rrows}) == 4)
    for r, (cname, tag, epc1, epc2, efit) in zip(rrows, EXPECT):
        pt = tag.split("-")
        islv, g, j = pt[0][1:], pt[1][1:], pt[2][1:]
        cand = [ln for ln in raw if ln.startswith(f"{islv},{g},{j},")]
        chk(f"{tag}: source row unique", len(cand) == 1)
        if len(cand) == 1:
            parts = cand[0].split(",")
            bad = [k for k, c in enumerate(BLOCK) if parts[k] != r[c]]
            chk(f"{tag}: 32 fields byte-equal to the source row", not bad)
        chk(f"{tag}: pc 6dp reads NR-051 ({epc1}, {epc2})",
            (round(float(r["pc1"]), 6), round(float(r["pc2"]), 6)) == (epc1, epc2))
        chk(f"{tag}: fitness token reads NR-051", r["fitness"] == efit)
        chk(f"{tag}: fitness rounds as its own 3dp token", round(float(r["fitness"]), 3) == float(r["fitness"]))
        chk(f"{tag}: feasible and above the winner",
            r["status"] == "ok" and float(r["fitness"]) < 1e6 and float(r["fitness"]) > 27.364)
        # the pc columns re-read as the live re-derivation
        wi = int(np.where((isl == int(islv)) & (gen == int(g)) & (idx == int(j)))[0][0])
        chk(f"{tag}: pc columns equal the live re-derivation",
            (repr(float(pc1[wi])), repr(float(pc2[wi]))) == (r["pc1"], r["pc2"]))

hdr = [ln for ln in text.splitlines() if ln.startswith("#")]
chk("header: run-id", any("corner-grid-extract-2026-10-15" in h for h in hdr))
chk("header: dataset line", any("dd3cc6a" in h and "a76c5e9" in h for h in hdr))
chk("header: computing commit full hash",
    any(h.startswith("# computing commit: ") and len(h.split()[-1]) == 40 for h in hdr))
chk("header: gene slots line", any("x10 blade_scale_bottom" in h for h in hdr))

log = LOG_PATH.read_text()
sha = hashlib.sha256(CSV_PATH.read_bytes()).hexdigest()
chk("the log records the extract sha256", sha in log)
chk("the log records the certificate",
    all(k in log for k in ["[1]", "[2]", "[3]", "[4]", "[5]", "[6]"]))
chk("the log records all four tags",
    all(t in log for _, t, *_ in EXPECT))

print(f"\nchecks: {n}, fail: {len(fails)}")
for f in fails:
    print("FAILED:", f)
raise SystemExit(0 if not fails else 1)

#!/usr/bin/env python3
"""fig-cg picks: the four corner-typical machines of the PC1-PC2 field.

Round-5 founder comment 14 (id 13): four machines near the PC1-PC2
corners. The projection replicates the certified pca-landscape kit
exactly: z-scored 10-gene matrix over the 930 rows, SVD, pc = Xc @ V.
Every NR-044 anchor re-verifies before any pick prints.

Rule (recorded): for each corner of the drawn [1,99] percentile window,
the feasible (ok) design of least Euclidean distance to the corner point
in PC1-PC2 space.

Run: /usr/bin/python3 scratch/fig_cg_picks.py     (repo root)
"""
import csv
import sys
from pathlib import Path

import numpy as np

REPO = Path(".")
RD = REPO / "scripts" / "results" / "v13_5kw_masslift_len18.8_rotorcount_bankderate2"
ISLANDS = (1, 2, 3)
ERA = "post-95c385d_wind-authority"
RUN = "a76c5e9"
GENES = ["r_hub", "r_bottom", "target_Lr", "n_lines", "density_profile",
         "rotor_count", "bank_top", "bank_bottom", "blade_scale_top",
         "blade_scale_bottom"]


def load():
    rows = []
    for isl in ISLANDS:
        p = RD / f"island_{isl}" / "telemetry.csv"
        lines = [ln for ln in p.read_text().splitlines()
                 if not ln.startswith("#") and ln.strip()]
        rows.extend(list(csv.DictReader(lines)))
    return rows


rows = load()
X = np.array([[float(r[f"x{i}"]) for i in range(1, 11)] for r in rows])
fit = np.array([float(r["fitness"]) for r in rows])
st = np.array([r["status"] for r in rows])
gen = np.array([int(r["gen"]) for r in rows])
idx = np.array([int(r["idx"]) for r in rows])
isl_a = np.array([int(r["island"]) for r in rows])
feas = (st == "ok") & (fit < 1e6)

mu = X.mean(axis=0)
sd = X.std(axis=0, ddof=1)
Xc = (X - mu) / sd
_, S, Vt = np.linalg.svd(Xc, full_matrices=False)
var = S ** 2 / (S ** 2).sum()
V = Vt.T
pc1 = Xc @ V[:, 0]
pc2 = Xc @ V[:, 1]

# ---- NR-044 anchors: re-verify before any pick ----
seed_i = int(np.where((isl_a == 1) & (gen == 0))[0][0])
win_i = int(np.argmin(np.where(feas, fit, np.inf)))
anchors = [
    ("rows", len(rows), 930),
    ("feasible rows", int(feas.sum()), 508),
    ("PC1 share x1e6", int(round(var[0] * 1e6)), int(round(0.22434667 * 1e6))),
    ("PC2 share x1e6", int(round(var[1] * 1e6)), int(round(0.17263044 * 1e6))),
    ("seed pc1 3dp", round(float(pc1[seed_i]), 3), 0.531),
    ("seed pc2 3dp", round(float(pc2[seed_i]), 3), -1.297),
    ("winner pc1 3dp", round(float(pc1[win_i]), 3), 0.885),
    ("winner pc2 3dp", round(float(pc2[win_i]), 3), 2.869),
    ("seed fit", round(float(fit[seed_i]), 3), 36.109),
    ("winner fit", round(float(fit[win_i]), 3), 27.364),
    ("winner island", int(isl_a[win_i]), 3),
]
ok = True
for name, got, want in anchors:
    good = got == want
    ok = ok and good
    print(f"anchor: {name}: {got}  ({'OK' if good else 'FAIL want ' + str(want)})")
if not ok:
    raise SystemExit("anchors failed - do not pick")

x1w, x2w = np.percentile(pc1, [1, 99])
y1w, y2w = np.percentile(pc2, [1, 99])
print(f"window: pc1 [{x1w:.3f}, {x2w:.3f}]  pc2 [{y1w:.3f}, {y2w:.3f}]")

CORNERS = {
    "low PC1 / low PC2": (x1w, y1w),
    "low PC1 / high PC2": (x1w, y2w),
    "high PC1 / low PC2": (x2w, y1w),
    "high PC1 / high PC2": (x2w, y2w),
}

report = []
for cname, (cx, cy) in CORNERS.items():
    d = np.hypot(pc1 - cx, pc2 - cy)
    d_feas = np.where(feas, d, np.inf)
    order = np.argsort(d_feas)[:5]
    print(f"\n== {cname} target ({cx:.3f}, {cy:.3f}) ==")
    for k, i in enumerate(order[:5]):
        tag = f"i{isl_a[i]}-g{gen[i]}-i{idx[i]}"
        print(f"  {k+1}. {tag}  dist {d[i]:.3f}  pc ({pc1[i]:.3f}, {pc2[i]:.3f})  "
              f"fit {fit[i]:.6f}  status {st[i]}")
    i = int(order[0])
    report.append((cname, cx, cy, i, float(d[i])))

print("\n== picks (recorded) ==")
for cname, cx, cy, i, dist in report:
    tag = f"i{isl_a[i]}-g{gen[i]}-i{idx[i]}"
    genes = " ".join(f"x{j+1}={X[i, j]:.6g}" for j in range(10))
    print(f"{cname}: {tag}  island {isl_a[i]} gen {gen[i]} idx {idx[i]}")
    print(f"   pc ({pc1[i]:.6f}, {pc2[i]:.6f})  dist {dist:.6f}  fit {fit[i]:.6f}")
    print(f"   {genes}")

# also: how far is the nearest feasible from each corner vs the nearest overall?
print("\n== context: nearest including rejected ==")
for cname, (cx, cy) in CORNERS.items():
    d = np.hypot(pc1 - cx, pc2 - cy)
    i_all = int(np.argmin(d))
    i_ok = int(np.argmin(np.where(feas, d, np.inf)))
    print(f"{cname}: nearest-all {st[i_all]} dist {d[i_all]:.3f} | nearest-ok dist {d[i_ok]:.3f}")

#!/usr/bin/python3
# -*- coding: utf-8 -*-
"""PCA probe for the v13 5 kW campaign levers family (figures seat).

Scratch probe: reads the three island telemetry files, fits the
z-scored 10-gene projection, and prints the facts the two generators
will draw: variance shares, loadings, ranges, trajectories, statuses.

Run: /usr/bin/python3 scratch/fig_pca_probe.py
"""
import csv
from pathlib import Path

import numpy as np

RD = Path(__file__).resolve().parents[1] / "scripts" / "results" / \
    "v13_5kw_masslift_len18.8_rotorcount_bankderate2"

GENES = ["x1 r_hub", "x2 r_bottom", "x3 target_Lr", "x4 n_lines",
         "x5 density_profile", "x6 rotor_count", "x7 bank_top",
         "x8 bank_bottom", "x9 blade_scale_top", "x10 blade_scale_bottom"]


def load():
    rows = []
    for isl in (1, 2, 3):
        p = RD / f"island_{isl}" / "telemetry.csv"
        lines = [ln for ln in p.read_text().splitlines()
                 if not ln.startswith("#") and ln.strip()]
        for r in csv.DictReader(lines):
            rows.append(r)
    return rows


def main():
    rows = load()
    print(f"rows: {len(rows)}")
    for isl in (1, 2, 3):
        sel = [r for r in rows if r["island"] == str(isl)]
        st = {}
        for r in sel:
            st[r["status"]] = st.get(r["status"], 0) + 1
        fits = [float(r["fitness"]) for r in sel]
        fin = [f for f in fits if np.isfinite(f) and abs(f) < 1e6]
        print(f"island {isl}: n={len(sel)} status={st} "
              f"fit range={min(fin):.3f}..{max(fin):.3f} "
              f"inf={sum(1 for f in fits if not np.isfinite(f))} "
              f"huge={sum(1 for f in fits if np.isfinite(f) and abs(f) >= 1e6)}")

    X = np.array([[float(r[f"x{i}"]) for i in range(1, 11)] for r in rows])
    fit = np.array([float(r["fitness"]) for r in rows])
    print("\ncol ranges (min .. max, stride):")
    for j in range(10):
        col = X[:, j]
        u = np.unique(col)
        print(f"  {GENES[j]:24s} {col.min():12.4f} .. {col.max():12.4f} "
              f"n_unique={len(u)}")

    mu = X.mean(axis=0)
    sd = X.std(axis=0, ddof=1)
    Xc = (X - mu) / sd
    U, S, Vt = np.linalg.svd(Xc, full_matrices=False)
    var = S**2 / (S**2).sum()
    print(f"\nvariance shares: PC1 {var[0]*100:.2f}%  PC2 {var[1]*100:.2f}%  "
          f"PC1+2 {(var[0]+var[1])*100:.2f}%  PC1-3 "
          f"{(var[0]+var[1]+var[2])*100:.2f}%")
    for k in range(4):
        print(f"  PC{k+1}: {var[k]*100:.2f}%")
    V = Vt.T
    for k in range(3):
        loads = ", ".join(f"{GENES[j]}={V[j, k]:+.3f}" for j in range(10))
        print(f"PC{k+1} loadings: {loads}")

    pc1 = Xc @ V[:, 0]
    pc2 = Xc @ V[:, 1]
    print(f"\npc1 range {pc1.min():.3f} .. {pc1.max():.3f}")
    print(f"pc2 range {pc2.min():.3f} .. {pc2.max():.3f}")
    for q in (1, 5, 50, 95, 99):
        print(f"  p{q}: pc1 {np.percentile(pc1, q):8.3f}  "
              f"pc2 {np.percentile(pc2, q):8.3f}")

    # seed row (gen 0) and winner
    for isl in (1, 2, 3):
        seed = [r for r in rows if r["island"] == str(isl) and
                r["gen"] == "0"]
        s = seed[0]
        idx = rows.index(s)
        print(f"island {isl} seed: pc=({pc1[idx]:.3f},{pc2[idx]:.3f}) "
              f"fit={fit[idx]:.3f}")
    feas = [i for i, r in enumerate(rows)
            if r["status"] == "ok" and np.isfinite(fit[i]) and fit[i] < 1e6]
    best = min(feas, key=lambda i: fit[i])
    print(f"winner: island {rows[best]['island']} gen {rows[best]['gen']} "
          f"fit={fit[best]:.3f} pc=({pc1[best]:.3f},{pc2[best]:.3f})")

    # best-so-far per generation (feasible only)
    print("\nbest-so-far trajectory (island: gen fit pc1 pc2):")
    for isl in (1, 2, 3):
        pts = []
        for g in range(31):
            cand = [i for i, r in enumerate(rows)
                    if r["island"] == str(isl) and int(r["gen"]) <= g
                    and r["status"] == "ok" and np.isfinite(fit[i])
                    and fit[i] < 1e6]
            i = min(cand, key=lambda i: fit[i])
            pts.append((g, fit[i], pc1[i], pc2[i]))
        for g, f, a, b in pts[::6]:
            print(f"  island {isl} gen {g:2d}: {f:7.3f} ({a:7.3f},{b:7.3f})")
        g, f, a, b = pts[-1]
        print(f"  island {isl} gen {g:2d}: {f:7.3f} ({a:7.3f},{b:7.3f})  <- end")

    # occupied grid sanity for binning choices
    for bins in (18, 22, 26, 30):
        Hc, _, _ = np.histogram2d(pc1, pc2, bins=bins)
        print(f"bins={bins}: occupied cells {int((Hc > 0).sum())} of {bins*bins}, "
              f"mean {Hc[Hc>0].mean():.1f}")

    # feasible fraction per cell (status view)
    ok = np.array([1.0 if r["status"] == "ok" else 0.0 for r in rows])
    H, xe, ye = np.histogram2d(pc1, pc2, bins=22)
    print(f"\nfeasible overall: {ok.mean()*100:.1f}%")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Quick inspection of wobble-gate CSVs: bearing-vs-hub perpendicular drift estimate."""
import csv
import math


def norm_name(s):
    return s.lower().replace("_", "")


def find_col(cols, frag):
    f = norm_name(frag)
    for c in cols:
        if f in norm_name(c):
            return c
    return None


for tag in ["wg_ld0.05_dtf1", "wg_ld0.00_dtf1", "wg_ld0.60_dtf1"]:
    path = f".julia_depot/logs/{tag}.csv"
    try:
        with open(path) as f:
            rows = list(csv.DictReader(f))
    except FileNotFoundError:
        print(tag, "missing")
        continue
    cols = list(rows[0].keys()) if rows else []
    print("=" * 64)
    print(tag, "rows:", len(rows))
    print("cols:", ", ".join(cols))

    c = {}
    for key in ["hub_e1", "hub_e2", "bear_e1", "bear_e2", "hub_lat", "bear_lat"]:
        c[key] = find_col(cols, key)

    if all(c[k] for k in ["hub_e1", "hub_e2", "bear_e1", "bear_e2"]):
        half = len(rows) // 2
        dr = []
        for r in rows[half:]:
            dx = float(r[c["bear_e1"]]) - float(r[c["hub_e1"]])
            dy = float(r[c["bear_e2"]]) - float(r[c["hub_e2"]])
            dr.append(math.hypot(dx, dy))
        dr.sort()
        med = dr[len(dr) // 2]
        print(
            "bearing-hub drift (2nd half, est): "
            f"min {dr[0]*1000:.3f}  med {med*1000:.3f}  max {dr[-1]*1000:.3f} mm"
        )

    for key in ["hub_lat", "bear_lat"]:
        if c[key]:
            v = [float(r[c[key]]) for r in rows]
            v2 = v[len(v) // 2:]
            print(
                f"{key}: full {min(v):.3f}..{max(v):.3f} | "
                f"2nd-half {min(v2):.3f}..{max(v2):.3f}"
            )

"""
Generate simdata.js for the TRPT Hub Excursion Dashboard.
Reads the long run CSV produced by hub_excursion_long.jl and writes
scripts/results/lift_kite/simdata.js in the format expected by dashboard.html.

Usage:
    python3 scripts/generate_simdata.py

Inputs:
    scripts/results/lift_kite/long_timeseries.csv

Outputs:
    scripts/results/lift_kite/simdata.js
"""

import json, sys
from pathlib import Path
import pandas as pd

OUT  = Path(__file__).parent / "results" / "lift_kite"
TS   = OUT / "long_timeseries.csv"

if not TS.exists():
    sys.exit(f"Missing: {TS}\nRun hub_excursion_long.jl first.")

df = pd.read_csv(TS)

# Column mapping: CSV → simdata key
# t           → t      (simulation time, s, relative to recording start)
# hub_x       → hx     (downwind position, m)
# hub_z       → hz     (altitude, m)
# elev_deg    → el     (elevation angle, degrees)
# P_kw        → P      (generated power, kW)
# omega_gnd   → w      (ground ring angular speed, rad/s)
# v_wind_inst → vi     (instantaneous hub wind speed, m/s)

# Device label map (long run name → simdata key prefix)
DEVICE_MAP = {
    "SingleKite":   "SingleKite",
    "Stack×3":      "Stack×3",
    "RotaryLifter":  "RotaryLifter",
    "NoLift":       "NoLift",
}

sim_data = {}
missing = []

for v_wind in sorted(df["v_wind"].unique()):
    v_int = int(round(v_wind))
    df_v = df[df["v_wind"] == v_wind]
    for dev_csv, dev_key in DEVICE_MAP.items():
        sub = df_v[df_v["device"] == dev_csv].copy()
        if sub.empty:
            missing.append(f"{dev_key}_{v_int}")
            continue
        # Sort by t
        sub = sub.sort_values("t")
        records = []
        for _, row in sub.iterrows():
            records.append({
                "t":  round(float(row["t"]), 3),
                "hz": round(float(row["hub_z"]), 5),
                "hx": round(float(row["hub_x"]), 4),
                "el": round(float(row["elev_deg"]), 4),
                "P":  round(float(row["P_kw"]), 4),
                "w":  round(float(row["omega_gnd"]), 4),
                "vi": round(float(row["v_wind_inst"]), 3),
            })
        key = f"{dev_key}_{v_int}"
        sim_data[key] = records
        print(f"  {key}: {len(records)} records")

if missing:
    print(f"\nWARNING: missing combinations (long run incomplete): {missing}")

out_path = OUT / "simdata.js"
with open(out_path, "w") as f:
    f.write("const SIM_DATA = ")
    json.dump(sim_data, f, separators=(",", ":"))
    f.write(";\n")

print(f"\nWrote {out_path}  ({out_path.stat().st_size//1024} KB)")

#!/usr/bin/env python3
"""Process catalog/kickstart/wind_sweep CSVs for Tasks 3 & 4."""
import csv, hashlib, os

PROJ = "/home/rod/Documents/GitHub/KiteTurbineDynamics.jl"
CAT_CSV  = f"{PROJ}/scripts/results/control_maps/catalog_corrected_geo.csv"
KS_CSV   = f"{PROJ}/scripts/results/control_maps/kickstart_sweep.csv"
WS_CSV   = f"{PROJ}/scripts/results/control_maps/wind_sweep.csv"

def read_csv(path):
    with open(path) as f:
        return list(csv.reader(f))

def md5(path):
    with open(path, 'rb') as f:
        return hashlib.md5(f.read()).hexdigest()

# Read all CSVs
cat_rows = read_csv(CAT_CSV)
cat_h = cat_rows[0]
cat_r = cat_rows[1:]
ks_rows = read_csv(KS_CSV)
ks_h = ks_rows[0]
ks_r = ks_rows[1:]
ws_rows = read_csv(WS_CSV)
ws_h = ws_rows[0]
ws_r = ws_rows[1:]

# Build lookups
cat_lookup = {}
for r in cat_r:
    key = (float(r[3]), float(r[4]))
    cat_lookup[key] = {
        'P': float(r[5]), 'omega': float(r[6]), 'fos': float(r[7]),
        'round': int(r[0]), 'r_bot': float(r[2]), 'pass': r[12].strip().lower()=='true'
    }

ks_lookup = {}
for r in ks_r:
    key = (float(r[0]), float(r[1]))
    ks_lookup[key] = {'P': float(r[2]), 'omega': float(r[3]), 'fos': float(r[4])}

# === TASK 3a: Settle-bug dumbbell ===
dumbbell_path = f"{PROJ}/docs/outreach/figures/data/settle_dumbbell.csv"
os.makedirs(os.path.dirname(dumbbell_path), exist_ok=True)

known_pairs = [
    (0.85, 2.0), (0.85, 14.0), (0.80, 6.0), (0.80, 4.0),
]
with open(dumbbell_path, 'w') as f:
    f.write("blade,k,P_catalog,P_kickstart,omega_catalog,omega_kickstart\n")
    for (blade, k) in known_pairs:
        cv = cat_lookup.get((blade, k), {'P': 0, 'omega': 0})
        kv = ks_lookup.get((blade, k), {'P': 0, 'omega': 0})
        f.write(f"{blade},{k},{cv['P']},{kv['P']},{cv['omega']},{kv['omega']}\n")
        print(f"  blade={blade} k={k}: cat P={cv['P']} ω={cv['omega']}  ks P={kv['P']} ω={kv['omega']}")

print(f"Dumbbell: {dumbbell_path}")

# === TASK 3b: Viability heatmap ===
viab_path = f"{PROJ}/docs/outreach/figures/data/viability_grid.csv"
os.makedirs(os.path.dirname(viab_path), exist_ok=True)

viability = []
for r in cat_r:
    blade = float(r[3])
    k_val = float(r[4])
    p_kw = float(r[5])
    passed = r[12].strip().lower() == 'true'
    viability.append((blade, k_val, p_kw, passed, 'catalog'))

# Kickstart overrides
for (blade, k_val), kv in ks_lookup.items():
    if kv['P'] > 1.0:
        cv = cat_lookup.get((blade, k_val), {'P': 0})
        if cv['P'] < 1.0:
            viability.append((blade, k_val, kv['P'], True, 'kickstart'))

with open(viab_path, 'w') as f:
    f.write("blade,k,P_kw,pass,source\n")
    for v in viability:
        f.write(f"{v[0]},{v[1]},{v[2]},{str(v[3]).lower()},{v[4]}\n")

print(f"Viability grid: {viab_path} ({len(viability)} rows)")

# === TASK 2: Anomalous FoS in wind_sweep ===
print("\n=== Anomalous FoS in wind_sweep.csv ===")
for r in ws_r:
    fos = float(r[6])
    if fos > 10.0:
        print(f"  blade={r[0]} k={r[1]} wind={r[2]}: P={r[4]} kW ω={r[5]} rpm FoS={fos}")

# === TASK 4: Provenance ===
print("\n=== Provenance ===")
print(f"catalog_corrected_geo.csv: {len(cat_r)} rows, md5={md5(CAT_CSV)}")
print(f"kickstart_sweep.csv: {len(ks_r)} rows, md5={md5(KS_CSV)}")
print(f"wind_sweep.csv: {len(ws_r)} rows")
# Get git hash
import subprocess
result = subprocess.run(['git', '-C', PROJ, 'rev-parse', 'HEAD'], capture_output=True, text=True)
print(f"git HEAD: {result.stdout.strip()}")

print("\nDone.")

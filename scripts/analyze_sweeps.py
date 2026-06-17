#!/usr/bin/env python3
"""Phase 3: Document patterns from sweep data and convergence history."""
import csv, json, sys, os
from pathlib import Path
from collections import defaultdict

RESULTS = Path("scripts/results")

# ── Phase 1 recap: convergence patterns ──
def convergence_summary():
    masses = []
    best_traj = []
    with open(RESULTS / "v6_2_campaign_50kw/convergence_history.csv") as f:
        for row in csv.DictReader(f):
            m = float(row["mass_kg"])
            i = int(row["island"])
            it = int(row["iteration"])
            masses.append((i, it, m))
    
    best_per_island = {}
    for i, it, m in masses:
        if i not in best_per_island or m < best_per_island[i][1]:
            best_per_island[i] = (it, m)
    
    final_masses = sorted(v[1] for v in best_per_island.values())
    
    print("=== Phase 1: Convergence Patterns ===")
    print(f"Total evaluations: {len(masses)}")
    print(f"Islands: {len(best_per_island)}")
    print(f"Global best: {min(final_masses):.2f} kg")
    print(f"Worst final: {max(final_masses):.1f} kg")
    print(f"Median final: {final_masses[len(final_masses)//2]:.1f} kg")
    print(f"Islands at 70-75 kg: {sum(1 for m in final_masses if 70 <= m < 75)}/60")
    print(f"Islands at 75-80 kg: {sum(1 for m in final_masses if 75 <= m < 80)}/60")
    print()

# ── Phase 2 sweep readers ──
def read_sweep(name):
    path = RESULTS / f"sweep_{name}.csv"
    if not path.exists():
        return None
    data = []
    with open(path) as f:
        for row in csv.DictReader(f):
            data.append(row)
    return data

def print_sweep(name, xlabel, xcol, ycol="mass_kg"):
    data = read_sweep(name)
    if data is None:
        print(f"  [sweep_{name}.csv not found]")
        return
    print(f"\n=== Sweep: {name} ===")
    print(f"{xlabel:>10}  mass_kg")
    print(f"{'─'*10}  ───────")
    for row in data:
        x = float(row[xcol])
        y = float(row[ycol])
        print(f"{x:10.3f}  {y:.2f}")
    
    # Find minimum
    best = min(data, key=lambda r: float(r[ycol]))
    print(f"  → Minimum: {xlabel}={float(best[xcol]):.3f}, mass={float(best[ycol]):.2f} kg")

# ── Main ──
if __name__ == "__main__":
    os.chdir(Path(__file__).parent.parent)
    convergence_summary()
    print_sweep("nlines", "n_lines", "n_lines")
    print_sweep("beta", "beta", "beta")
    print_sweep("nexp", "n_exp", "n_exp")

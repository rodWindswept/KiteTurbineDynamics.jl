#!/usr/bin/env python3
"""Winner spot-check CSV analysis (2026-09-21).

Reads the wobble-gate window CSV (.julia_depot/logs/wgw_winner_ld0.05_dtf1.csv)
and prints the decision-grade shape of the run: hub trajectory, spike times,
FoS distribution.  Read-only.
"""
import csv
import sys
from pathlib import Path

path = Path(__file__).resolve().parent.parent / ".julia_depot" / "logs" / "wgw_winner_ld0.05_dtf1.csv"
if len(sys.argv) > 1:
    path = Path(sys.argv[1])

rows = []
with open(path) as f:
    for r in csv.DictReader(f):
        rows.append({k: float(v) for k, v in r.items()})

n = len(rows)
t = [r["t"] for r in rows]
hub = [r["hub_lat"] for r in rows]
top = [r["T_topbay"] for r in rows]
fos = [r["fos_min"] for r in rows]
wg = [r["omega_gnd"] for r in rows]
pg = [r["P_gen_kW"] for r in rows]
brk = [r["broken"] for r in rows]

print(f"samples={n}  window {t[0]:.1f}..{t[-1]:.1f} s  broken={int(sum(brk))}")
h1 = hub[: n // 2]
h2 = hub[n // 2 :]
print(f"hub_lat  all: min {min(hub):.3f} max {max(hub):.3f} mean {sum(hub)/n:.3f}")
print(f"hub_lat  first half p2p {max(h1)-min(h1):.3f}  second half p2p {max(h2)-min(h2):.3f}")

spikes = [(t[i], top[i]) for i in range(n) if top[i] > 3000.0]
print(f"T_topbay > 3000 N: {len(spikes)} samples", end="")
if spikes:
    print(f"  first t={spikes[0][0]:.1f} ({spikes[0][1]:.0f} N)  last t={spikes[-1][0]:.1f} ({spikes[-1][1]:.0f} N)")
else:
    print()

fmin = min(fos)
imin = fos.index(fmin)
below25 = sum(1 for v in fos if v < 2.5)
below05 = sum(1 for v in fos if v < 0.5)
print(f"FoS min {fmin:.3f} at t={t[imin]:.1f} s;  FoS<2.5: {below25}/{n} samples;  FoS<0.5: {below05}/{n}")
print(f"omega_gnd {min(wg):.2f}..{max(wg):.2f} rad/s   P_gen {min(pg):.2f}..{max(pg):.2f} kW")

# biggest one-sample hub jump (a proxy for the swing rate)
jumps = [(abs(hub[i + 1] - hub[i]), t[i + 1]) for i in range(n - 1)]
jumps.sort(reverse=True)
print("top 3 hub jumps (0.5 s):", ", ".join(f"{j:.3f} m @ t={tt:.1f}" for j, tt in jumps[:3]))

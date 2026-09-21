#!/usr/bin/env python3
"""Cross-run analysis for the wobble-gate matrix (wg_ld*_dtf*.log + .csv).

Per Rod's decision #3 (2026-09-2x): run {dt, dt/2} pairs per damping rate;
a rate is pinnable if it converges across dt and dt/2 on WINDOWED statistics
(mean + range agreement, not peaks) and does not suppress the macro motion.
If no rate is defensible, report the two-point bracket 0.05 vs 0.00 and the
zero-artificial-damping envelope as the governing design load.
"""
import csv
import re
import statistics as st
from pathlib import Path

LOGS = Path(".julia_depot/logs")
rates = ["0.05", "0.30", "0.60", "0.00"]
dtfs = ["1", "2"]

SEC = {}

def parse_log(path):
    txt = path.read_text()
    d = {"tag": path.stem}
    m = re.search(r"lin_damp=([\d.]+)\s+dt_factor=(\d+)\s+dt_use=([\d.eE+-]+)", txt)
    if m:
        d["ld"], d["dtf"], d["dt_use"] = m.group(1), int(m.group(2)), float(m.group(3))
    else:
        # lin_damp=0 prints as "0"
        m = re.search(r"lin_damp=(\S+)\s+dt_factor=(\d+)\s+dt_use=([\d.eE+-]+)", txt)
        if m:
            d["ld"], d["dtf"], d["dt_use"] = m.group(1), int(m.group(2)), float(m.group(3))
        else:
            return d
    m = re.search(r"settle wall = ([\d.]+) s", txt)
    d["settle_wall"] = float(m.group(1)) if m else None
    m = re.search(r"acc_struct ([\d.]+) m/s2\s+max_force ([\d.]+) N", txt)
    if m:
        d["acc_struct"], d["max_force"] = float(m.group(1)), float(m.group(2))
    for name in ["hub_lat", "bear_lat", "T_cyan", "T_back", "T_bridle", "T_topbay", "P_gen_kW", "omega_gnd"]:
        m = re.search(rf"^{name}\s+min\s+([\d.-]+)\s+max\s+([\d.-]+)\s+p2p\s+([\d.-]+)\s+mean\s+([\d.-]+)", txt, re.M)
        if m:
            d[name] = dict(min=float(m.group(1)), max=float(m.group(2)),
                           p2p=float(m.group(3)), mean=float(m.group(4)))
    m = re.search(r"FoS \(airborne min\): trough ([\d.]+)\s+mean ([\d.]+)", txt)
    if m:
        d["fos_trough"], d["fos_mean"] = float(m.group(1)), float(m.group(2))
    m = re.search(r"first-half ([\d.-]+)\s+second-half ([\d.-]+);\s+mean 2nd half ([\d.-]+)", txt)
    if m:
        d["hub_p2p_h1"], d["hub_p2p_h2"], d["hub_mean_h2"] = (float(m.group(1)), float(m.group(2)), float(m.group(3)))
    m = re.search(r"SLACK GATE: (\w+)", txt)
    d["slack_gate"] = m.group(1) if m else None
    m = re.search(r"FOS GATE \(>=2\.5 at trough\): (\w+)", txt)
    d["fos_gate"] = m.group(1) if m else None
    m = re.search(r"broken=(\w+)", txt)
    d["broken"] = m.group(1) if m else None
    m = re.search(r"EXIT=(\d+)", txt)
    d["exit"] = int(m.group(1)) if m else None
    # slack rows for lines that FAIL
    fails = re.findall(r"^\s+(\S+)\s+([\d.]+)\s+([\d.]+)\s+([\d.]+)\s+(\d+)\s+\*\* FAIL \*\*", txt, re.M)
    d["slack_fails"] = [(r[0], float(r[1]), float(r[2]), float(r[3]), int(r[4])) for r in fails]
    return d


for ld in rates:
    for dtf in dtfs:
        p = LOGS / f"wg_ld{ld}_dtf{dtf}.log"
        if p.exists():
            SEC[(ld, dtf)] = parse_log(p)

print("=== WOBBLE-GATE MATRIX REPORT ===")
done = [k for k, v in SEC.items() if v.get("slack_gate")]
print(f"runs parsed with summaries: {len(done)}/8")

# ── per-run verdicts ──
print("\n-- per-run gate verdicts --")
for (ld, dtf), d in sorted(SEC.items()):
    if not d.get("slack_gate"):
        print(f"ld={ld} dtf={dtf}: still running / no summary")
        continue
    nf = len(d["slack_fails"])
    print(f"ld={ld} dtf={dtf}: SLACK={d['slack_gate']} ({nf} lines fail)  FOS={d['fos_gate']} "
          f"(trough {d.get('fos_trough')})  hub_lat mean {d['hub_lat']['mean']:.3f} "
          f"p2p2nd {d.get('hub_p2p_h2'):.3f}  broken={d['broken']} exit={d['exit']}")

# ── dt-pair convergence on windowed stats ──
print("\n-- dt vs dt/2 convergence (windowed mean+p2p; flag if >15% apart) --")
def pct(a, b):
    if a == 0 and b == 0:
        return 0.0
    denom = max(abs(a), abs(b), 1e-12)
    return abs(a - b) / denom * 100.0

for ld in rates:
    a, b = SEC.get((ld, "1")), SEC.get((ld, "2"))
    if not (a and a.get("slack_gate") and b and b.get("slack_gate")):
        print(f"ld={ld}: pair incomplete")
        continue
    parts = []
    for key in ["T_cyan", "T_topbay", "hub_lat", "bear_lat"]:
        if key in a and key in b:
            dp_mean = pct(a[key]["mean"], b[key]["mean"])
            dp_p2p = pct(a[key]["p2p"], b[key]["p2p"])
            flag = "OK" if (dp_mean <= 15 and dp_p2p <= 15) else "SPREAD"
            parts.append(f"{key}: mean {dp_mean:.1f}% p2p {dp_p2p:.1f}% [{flag}]")
    fos_pct = pct(a.get("fos_trough", 0), b.get("fos_trough", 0))
    parts.append(f"FoS_trough {fos_pct:.1f}% [{'OK' if fos_pct <= 15 else 'SPREAD'}]")
    print(f"ld={ld}: " + " | ".join(parts))

# ── macro motion vs damping (suppression check) ──
print("\n-- macro lateral motion by damping (windowed hub_lat mean & 2nd-half p2p) --")
for ld in rates:
    a = SEC.get((ld, "1"))
    if a and a.get("slack_gate") and "hub_lat" in a:
        h2 = a.get("hub_p2p_h2", float("nan"))
        print(f"ld={ld} (dt): hub_lat mean {a['hub_lat']['mean']:.3f} m, max {a['hub_lat']['max']:.3f} m, "
              f"2nd-half p2p {h2:.3f} m, T_cyan mean {a['T_cyan']['mean']:.1f} N")

# ── bracket summary (0.05 vs 0.0) ──
print("\n-- bracket: 0.05 vs 0.00 (dt runs) --")
a, b = SEC.get(("0.05", "1")), SEC.get(("0.00", "1"))
for key in ["T_cyan", "T_back", "T_bridle", "T_topbay", "hub_lat", "bear_lat"]:
    if a and b and key in a and key in b:
        print(f"{key}: 0.05 mean {a[key]['mean']:.2f} p2p {a[key]['p2p']:.2f}  |  "
              f"0.00 mean {b[key]['mean']:.2f} p2p {b[key]['p2p']:.2f}")
if a and b:
    print(f"FoS: 0.05 trough {a.get('fos_trough')} mean {a.get('fos_mean')}  |  "
          f"0.00 trough {b.get('fos_trough')} mean {b.get('fos_mean')}")

print("\n(done)")

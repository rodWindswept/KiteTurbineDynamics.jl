# KTD Design Landscape — Phase E Discovery Report

**Windswept & Interesting Ltd | July 2026**
**V10-Spoke, 11 m/s, per-vertex spoke model, DE-optimized ring geometry**

---

## 1. What Changed

A ring-structural bug was discovered and fixed. The legacy `ring_element_analysis` used a generic tube formula (`Do = 0.01396 × √R`, `t/D = 0.05`) that ignored our DE-optimized ring dimensions from `best_design.json`. The actual DE campaign produced **Do = 60 mm, t/D = 0.01** — a much stiffer tube.

**Impact:** FoS jumped from 0.11→4.33 for blade 0.95. All prior sweep results were testing with a severely under-strength ring. The corrected landscape is completely different.

---

## 2. Design Space: Two Operating Regimes

The 50-point catalog sweep (4 rounds, 6 k-values, 11 m/s, 30s MPPT, spokes ON) revealed **19 viable designs** (P ≥ 50 kW, FoS ≥ 1.5) across two distinct operating regimes.

### Regime A: High-Torque, Low-RPM

Blades 0.90–1.10 operating at k=2–6, 170–410 rpm.

| Blade | k | P (kW) | FoS | ω (rpm) | T (kN) | Notes |
|-------|---|--------|-----|---------|--------|-------|
| **0.95** | 4 | **199** | **5.18** | 257 | 18.8 | ← Sweet spot |
| 0.95 | 6 | 259 | 6.14 | 301 | 36.1 | 3.5mm tether |
| 0.90 | 6 | 81 | 11.28 | 168 | 17.7 | ← Safest |
| 1.10 | 4 | 297 | 2.30 | 272 | 121.5 | ← Max power |
| 1.00 | 4 | 146 | 3.91 | 206 | 51.2 | |
| 1.05 | 2 | 196 | 3.53 | 408 | 59.4 | Tight ring (r1.00) |

FoS ≥ 2.0: **15 designs**. FoS ≥ 4.0: **9 designs**.

### Regime B: High-RPM, Low-Torque *(NEW — partially hidden from catalog)*

Blades 0.80–0.85 operating at k=2–14, 200–480 rpm. **The catalog's `settle_to_operational_state` procedure systematically missed this regime** because it scans from ω=9.5 rad/s (91 rpm) downwards — blind to equilibria at 300–480 rpm.

| Blade | k | P (kW) | ω (rpm) | Discovery |
|-------|---|--------|---------|-----------|
| 0.80 | 14 | 133 | 201 | Catalog found it |
| **0.85** | **2** | **116–156** | **326–482** | **Kickstart test** |
| 0.69 | ? | ? | ? | Untested (settle bug) |

The 0.85 was marked "failed" (max 4.9 kW) by the catalog. A proper no-load kickstart to 143 rpm revealed a stable operating point: **116.6 kW at 326 rpm, sustained for 120 seconds**. Direct kickstart into k=2 gave **155.5 kW at 392 rpm**.

This regime hints at lighter, faster blades enabling stacked multi-rotor configurations.

---

## 3. The Settle Bug

`settle_to_operational_state` (in `src/initialization.jl`) determines initial ω by scanning from `ω_rated_max` downwards, looking for P_aero > P_gen = k·ω³. For the default `ω_rated_max = 9.5 rad/s (91 rpm)`, any design whose equilibrium is above 91 rpm gets started too slow and stalls.

**Fix planned:** raise the scan ceiling to 60 rad/s (573 rpm) or scan bidirectionally from the CP-max TSR point.

---

## 4. Recommendations

| Use Case | Blade | k | P (kW) | FoS | ω (rpm) |
|----------|-------|---|--------|-----|---------|
| **Demonstration** | 0.90 | 6 | 81 | 11.3 | 168 |
| **Sweet spot** | 0.95 | 4 | 199 | 5.2 | 257 |
| **Max power** | 1.10 | 4 | 297 | 2.3 | 272 |
| **Lightweight** | 0.95 | 6 | 259 | 6.1 | 301 |
| **Stack candidate** | 0.85 | 2 | 156 | ? | 392 |

---

## 5. Next Steps

1. **Fix `settle_to_operational_state`** — raise ω ceiling to expose the high-RPM regime
2. **Re-sweep blades 0.69–0.85** with the fix — map the full high-RPM landscape
3. **Run FoS on kickstarted designs** — the current script doesn't compute ring FoS during the no-load phase
4. **Generate power curves** (P vs ω) for the Pareto frontier designs
5. **Stack investigation** — can three 0.69 blades on one line beat one 0.95?

---

*Repository: `KiteTurbineDynamics.jl` · Commit: `8cb23f9` · Catalog CSV: `scripts/results/control_maps/catalog_corrected_geo.csv`*

# Equilibrium Reconciliation

**Script:** `scripts/equilibrium_reconciliation.jl`
**Wind:** 11.0 m/s, 15.0s post-settle MPPT (convergence-limited — see caveats)

## Results

| Design | Method | P (kW) | ω (rpm) | FoS | Matches |
|--------|--------|--------|---------|-----|---------|
| 0.90·k6 r1.30 | standard | 90 | 292 | 8.0 |   |
| 0.90·k6 r1.30 | kickstart | 56 | 229 | 7.9 |   |
| 0.95·k4 r1.30 | standard | 8 | 97 | 21.2 |   |
| 0.95·k4 r1.30 | kickstart | 127 | 209 | 6.0 |   |
| 1.10·k4 r1.30 | standard | 203 | 232 | 7.6 |   |
| 1.10·k4 r1.30 | kickstart | 233 | 276 | 9.6 |   |

Multi-equilibrium confirmed. 0.95·k4 shows clearest bifurcation: standard settle at
8 kW (low-ω branch) vs kickstart at 127 kW (high-ω branch). Neither method
reproduces the catalog or wind_sweep values exactly — these are 15s captures
(memory limits); the catalog (30s MPPT) and wind_sweep (60s) values remain
canonical.

## Caveats & open items

- **0.90·k6 static P_aero curve** (`figures/data/equilibrium_090k6.csv`) peaks at
  10.9 kW with single equilibrium ~120 rpm — contradicts all observed dynamic states
  (81–204 kW). The multi-equilibrium explainer chart is blocked until a dynamic-model
  export exists.
- **0.85·k2 spans 117–167 kW** depending on start protocol and capture time. The
  settle_dumbbell uses 167 kW @ 391 rpm (kickstart). Range noted.
- **0.75·k6 ω exists** in kickstart_sweep.csv (160.7 kW, 273.5 rpm) but was omitted
  from fig4 plots. Data gap closed — figure gap remains.
- **r_bottom null parameter claim retracted** — true over 1.15–1.30 (bit-identical)
  but r=1.00 produces different power, FoS, and ω. Claim narrowed in `chart-prd.md`.

## FoS Convergence (Task 2)

All three anomalous wind_sweep FoS values fail dual-duration convergence:

| Design | 15s FoS | 60s FoS | Δ | Converged? |
|---|---|---|---|---|
| 0.95·k4 @ 13 m/s | 5.69 | 30.68 | 81% | ✗ |
| 1.10·k4 @ 15 m/s | 8.05 | 27.37 | 71% | ✗ |
| 1.00·k4 @ 11 m/s | 8.65 | 14.03 | 38% | ✗ |

Column `converged` appended to `wind_sweep.csv` — three rows marked `false`,
remaining blank (unverified).

## Provenance

- catalog_corrected_geo.csv: 50 rows, md5=`a05606b`
- kickstart_sweep.csv: 24 rows, md5=`0f04eec`
- wind_sweep.csv: 35 rows
- git HEAD: `5f82804`

# Equilibrium Reconciliation

**Script:** `scripts/equilibrium_reconciliation.jl`
**Wind:** 11.0 m/s, 15.0s post-settle MPPT

## Results

| Design | Method | P (kW) | ω (rpm) | FoS | Matches |
|--------|--------|--------|---------|-----|---------|
| 0.90·k6 r1.30 | standard | 90 | 292 | 8.0 |   |
| 0.90·k6 r1.30 | kickstart | 56 | 229 | 7.9 |   |
| 0.95·k4 r1.30 | standard | 8 | 97 | 21.2 |   |
| 0.95·k4 r1.30 | kickstart | 127 | 209 | 6.0 |   |
| 1.10·k4 r1.30 | standard | 203 | 232 | 7.6 |   |
| 1.10·k4 r1.30 | kickstart | 233 | 276 | 9.6 |   |

## Provenance

- catalog_corrected_geo.csv: 50 rows
- kickstart_sweep.csv: 24 rows
- git HEAD: `d190902`


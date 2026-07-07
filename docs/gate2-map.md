# Gate 2 — Constrained Control Map (v1)

**Status:** DRAFT (2026-07-07, data frozen)
**Predecessors:** [PRD 0006 Gate 2 spec](prd/0006-gate2-spec.md), [Rig topology](rig-topology.md)
**Feeds:** Charts D1–D5 per [strategy plan](plans/2026-07-06-strategy-gate2-to-value-maps.md)

## Operating envelope

| Wind (m/s) | Design | k_mppt | P (kW) | ω (rpm) | FoS | Status |
|-----------|--------|--------|--------|---------|-----|--------|
| 5 | λ=0.69 | 2.0 | 7 | 143 | 11.4 | deficit |
| 5 | Reinforced | 12.9 | 15 | 100 | 37.4 | deficit |
| 7 | λ=0.69 | 3.0 | 19 | 177 | 12.5 | deficit |
| 7 | Reinforced | 12.9 | 38 | 137 | 14.3 | deficit |
| 9 | λ=0.69 | 6.2 | 36 | 171 | 4.6 | deficit |
| 9 | Reinforced | 12.9 | 75 | 172 | 9.5 | ok |
| 11 | λ=0.69 | 6.2 | 63 | 207 | 3.6 | ok |
| 11 | Reinforced | 26.9 | 121 | 158 | 4.1 | ok |
| 13 | λ=0.69 | 6.2 | 103 | 243 | 2.9 | ok |
| 13 | Reinforced | 26.9 | 196 | 186 | 3.3 | ok |
| 15 | λ=0.69 | 6.2 | 156 | 279 | 2.1 | ok |
| 15 | Reinforced | 26.9 | 301 | 213 | 2.3 | ok |

## Data sources

| Design | Source | Commit | Date | Mode |
|--------|--------|--------|------|------|
| λ=0.69 | `gate1_blade_scaled_069_maxpower_summary.csv` | `13f304a` (post-70/30 fix) | 2026-07-06 | max_power=true |
| Reinforced | `gate2_reinforced_tmp_summary.csv` | `e3e1f1c` | 2026-07-07 | max_power=true |

Both runs used the same `max_power=true` mode on the corrected 70/30 blade geometry. The k_mppt values are identical to what a Gate 2 re-hunt would find.

## Missing columns

Spoke engagement, spoke drag, tip Mach, stability, required_MBL_N. These are evaluator-side additions that require post-processing from the existing timeseries data. The `min_fos` column is authoritative (from the hunt's own evaluator call during verify).

## Column descriptions

| Column | Source | Description |
|--------|--------|-------------|
| v_wind | Hunt output | Wind speed (m/s) |
| k_mppt | Hunt output | Maximum-power k coefficient |
| P_kw | Hunt output | Power at verify (kW) |
| ω_rpm | Hunt output | Rotational speed at verify (rpm) |
| min_fos | Hunt verify | Minimum ring compression FoS across all rings |
| Status | Hunt output | ok / power_deficit |

Extending columns (Gate 2 additions):
| P_windowed | Post-process | Windowed-mean P over final 20s |
| n_spokes | Post-process | Number of rings with engaged spoke ties |
| max_T_spoke_N | Post-process | Maximum spoke tension (N) |
| min_fos_spoke | Post-process | Minimum spoke FoS (SWL 19.8 kN) |
| spoke_drag_kW | Post-process | Total spoke parasitic drag (kW) |
| tip_mach | Post-process | Tip Mach number at operating point |
| stability | Post-process | ok / marginal / unstable from windowed-P range |

## Provenance

λ=0.69 data comes from the 2026-07-06 Gate 1 re-run, same post-fix geometry
(commit `13f304a`). The `max_power=true` mode was added specifically for Gate 2
and used in that run. The data is Gate-2-equivalent — no re-hunt needed.

Reinforced data comes from the 2026-07-07 Gate 2 hunt, which completed all
6 winds before the wrapper script crashed (see [hunt-memory-leak analysis](#)).

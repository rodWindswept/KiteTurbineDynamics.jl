# Campaign Results — Inventory & Supersession

Each subdirectory holds the output of one DE optimisation campaign. The data files
are gzip-compressed (`.csv.gz`, `.log.gz`). To decompress: `gunzip filename.gz`.

## Active (Current Physics)

| Directory | Campaign | Power | Best Mass | Status |
|-----------|----------|-------|-----------|--------|
| `v10_campaign_50kw/` | V10 Unified Rotors | 50 kW | 76.75 kg | ✓ Current best |
| `v10_campaign_50kw_tight/` | V10 Tight | 50 kW | 49.20 kg ⚠ | Dynamically dead — FoS=0.75 |
| `v10_campaign_50kw_cons/` | V10 Conservative | 50 kW | 60.83 kg ⚠ | Dynamically dead — P=8.6 kW |
| `v9_0_campaign_50kw/` | V9 Dynamic ω | 50 kW | 44.52 kg | ✓ Feasible, 3 bounds screaming |
| `v9_0_campaign_10kw/` | V9 Dynamic ω | 10 kW | — | Lower-power verification |
| `v6_8_campaign_50kw/` | V8 Per-component | 50 kW | 58.41 kg | ✓ Feasible, 57/60 |
| `v6_7_campaign_50kw/` | V6.7 Relaxed drag | 50 kW | 54.91 kg | ✓ Feasible, 53/60 |

## Superseded (Earlier Physics — Valid Lessons, Don't Cite Numbers)

| Directory | Campaign | Superseded by | Why |
|-----------|----------|--------------|-----|
| `v6_6_campaign_50kw/` | V6.6 Parasitic drag | V6.7 | No feasible designs found — constraint too tight (hub-only Cd) |
| `v6_5_campaign_50kw/` | V6.5 Widened | Physics correction | **Dynamically impossible** — no parasitic drag model. Winner needs 33,992 kW to overcome structural drag. Mass-only objective artefact. |
| `v6_4_campaign_50kw/` | V6.4 Widened | Physics correction | **Dynamically impossible** — same parasitic drag gap as V6.5 |
| `v6_3_campaign_50kw/` | V6.3 Blade scaling | Physics correction | **Dynamically impossible** — parasitic drag 14,277× aero power |
| `v6_2_campaign_10kw/` | V6.2 10 kW | `v6_campaign_10kw/` | Pre-correction evaluator (old single-rotor loading) |
| `v6_campaign_50kw/` | V6 50 kW | `v6_2_campaign_50kw/` (not in results) | Pre-correction physics (tan formula, free-floating knuckle mass). The 184.84 kg octagon was the baseline before the three V6.2 corrections. |
| `v6_campaign_10kw/` | V6 10 kW | V6.2 | Same pre-correction era |
| `v6_campaign_50kw_archive/` | V6 archive | Various | Historical snapshot, superseded by V6.2+ |
| `v6_campaign_50kw_v2_stale/` | V6 v2 stale | V6.2 | Earlier evaluator version |
| `v6_campaign_50kw_old/` | V6 old | V6.2 | Earlier evaluator version |
| `v6_campaign_50kw_stale/` | V6 stale | V6.2 | Earlier evaluator version |
| `v6_campaign_10kw_stale/` | V6 10kW stale | V6.2 | Earlier evaluator version |

## Legacy (Pre-V6 Era — Different Optimiser, Different Physics)

These campaigns used the Phase A–H DE optimiser (`run_trpt_optimization*.jl`) with
the old TRPTDesign struct and different search spaces. They predate the V6 DoF
expansion, the network rotor model, and the expansion rotor model entirely.

| Directory | Campaign | What it explored | Key finding |
|-----------|----------|-----------------|-------------|
| `trpt_opt_v2/` | Phase C–H | 12-DoF, 60 islands, LHS cartography | 10 kW circular: 2.81 kg (Euler only, no torsion — **pre-v3, infeasible**) |
| `trpt_opt_v3/` | Phase v3 | Torsional collapse gate added | 10 kW: 15.44 kg — first torsionally-feasible result |
| `trpt_opt_v4/` | Phase v4 | Constant-L/r ring spacing | 10 kW: 10.59 kg — recovered taper efficiency |
| `trpt_opt_v5/` | Phase v5 | BEM-coupled rotor radius | 10 kW: 11.47 kg — aerodynamic coupling |
| `pitch_depower_campaign/` | Pitch depower | Backline-winch elevation control | Validated depower strategy; PCA-2 lifter bug at ≥90° |
| `pitch_depower_campaign_v3/` | Depower v3 | Refined disqualification checks | Earlier iteration of pitch depower analysis |
| `pitch_depower_campaign_v4/` | Depower v4 | Further refinement | Earlier iteration |
| `pitch_depower_campaign_v5_safe/` | Depower v5 safe | Safety margins raised | Final pre-V6 depower analysis |

## Regeneration

All campaigns can be regenerated from the repo scripts:

```bash
# V6.2+ campaigns (current DE framework):
julia --project=. --threads=auto scripts/run_v6_campaign.jl --power 50

# V10 campaigns:
julia --project=. --threads=auto scripts/run_v10_campaign.jl

# Always clear Julia cache first after any src/ edits:
rm -f ~/.julia/compiled/v1.12/KiteTurbineDynamics/*.ji
```

## Data Files

Each campaign directory typically contains:

| File | Contents |
|------|---------|
| `best_design.json` | Winning design parameters (decoded from DE vector — approximate) |
| `best_vector.csv` | Raw DE vector (exact — use for verification) |
| `convergence_history.csv.gz` | Per-island best-so-far mass at each iteration |
| `parameter_trace.csv.gz` | Full parameter trace for correlation analysis |
| `campaign.log.gz` | Full campaign console output |
| `dynamic_verification.txt` | Post-campaign dynamic simulation results |
| `verification_log.csv` | Verification run telemetry |

To decompress any `.gz` file: `gunzip -k filename.gz` (keeps the .gz) or `zcat filename.gz | head` to preview.

# Regate verdict — v13 5 kW rotorcount campaign (len 18.8 m)

**Date:** 2026-08-28
**Campaign dir:** `scripts/results/v13_5kw_masslift_len18.8_rotorcount/`
**Git era (launch):** `7524a90` (post-4ce9fd0_daisy-anchored-5kw; power_split 0.6, blocking 0.75^(1/3), k 2.24)
**Instruments:** `scripts/ode_gate_v13.jl` (independent 30 s ODE window, decode-aligned),
evaluator rows from per-island `telemetry.csv` (40 s window, tail5), `scripts/analyze_campaign_winners.jl`
(decode-aligned after path+knob fix, see git log).

## Question

Does this campaign produce a valid 5 kW design? Per runbook §6: re-gates clean with
finite FoS ≥ 2.5, P ≥ 5 kW, clearance ≥ 1.5 m, no twist crossing, tip sanity.

## Results (per island winner, gen 30)

| Island | fitness kg | status | P_mean / P_end kW | FoS | clear. m | gate P_gen kW | ω_gnd | twist | n_lines/rings/n_active | r_hub m | m_airb. (no lifter) kg | phi kg/kW |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 (global best) | 9.618 | ok | 5.13 / 5.14 | 17.6 | 5.91 | 5.31 | 13.33 | 0.6× | 3/6/1 | 4.16 | 4.432 | 0.886 |
| 2 | 11.021 | ok | 5.45 / 5.46 | 16.74 | 5.91 | 5.65 | 13.62 | 0.6× | 3/6/1 | 4.155 | 5.835 | 1.167 |
| 3 | 37.911 | ok | 5.34 / 5.37 | 27.0 | 3.25 | 7.45 | 14.93 | 0.1× | 7/8/3 | 2.385 | 32.477 | 6.495 |

All three: `twist_crossed=false`, tip sanity ok, `tau_gen < tau_max_safe` (382.6 vs 625 N·m),
no FoS=Inf on any `ok` row (all Inf rows are `reject`/`reject_twist` — guard working).

## Verdict

- **Telemetry intact:** 310 evals/island, per-eval rows flushed, statuses span
  ok / clearance_reject / reject / reject_twist. No ok-row shows the FoS=Inf signature.
- **Gate:** all three island winners PASS the independent ODE gate.
- **Global best by fitness = island 1** (9.618 kg): single-rotor, 3-line, r_hub 4.16 m,
  30 mm tube design sustaining 5.14 kW (evaluator) / 5.31 kW (gate), FoS 17.6, clearance 5.91 m.
- **Caveat A (mass plausibility — for Rod):** island 1's m_airborne is 4.432 kg → phi 0.886 kg/kW,
  *below* the Daisy anchor (≈1.3). The decoded geometry (r_hub 4.16 m, 6 rings, Do 0.03,
  t/D 0.0275) with a crude CFRP-tube estimate for the ring set alone is ~2.6× that.
  The mass law at this corner of the design space needs an audit before the 9.62 kg
  fitness is believed as a physical design (the ODE power and FoS are instrument-level passes).
- **Caveat B (settle-gap decay — island 3):** gate reads 7.45 kW flat over 5–30 s, evaluator
  tail5 reads 5.37 kW at 45–50 s — a slow decay, consistent with the known settle-ω
  overshoot (settle-ODE gap workstream). Island 3 still passes both instruments, but its
  true sustained power is at the floor; the 3-rotor design pays 6.5 kg/kW.
- **Design conclusion (record, not exploit):** single-rotor (n_active=1) dominates —
  islands 1 and 2 both converged there (third campaign with this pattern, cf. 08-15 note).

## Disposition (pending Rod)

1. Mass-law audit for the big-hub/small-tube corner (island 1) — gate the *mass model*,
   not the ODE, before accepting the 9.62 kg winner as the 5 kW design.
2. Acceptance re-baseline (§7) — blocked on (1) per Rod's review.
3. Results push to origin — pending Rod (repo convention keeps telemetry untracked).

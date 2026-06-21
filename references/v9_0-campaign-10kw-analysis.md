# V9.0 10kW Campaign Analysis — Dynamic Equilibrium Objective

**Date:** 2026-06-20
**Campaign:** `scripts/results/v9_0_campaign_10kw/`
**Runtime:** ~12 seconds, 500 evaluations, 5 islands × 100 iterations
**Feasible:** 5/5 islands

## 1. Executive Summary

V9.0 applied the dynamic equilibrium objective (`solve_equilibrium_self_consistent`)
to the 10kW design space. All 5 islands converged, with a global best of
**5.66 kg** (island 5). The campaign is a quick (5-island) exploratory run,
not a full 60-island sweep — convergence is therefore approximate, not
definitive.

The 10kW optimum uses a fundamentally different strategy from the 50kW winner:
many more tether lines (n≈16 vs n=8), far fewer expansion rotors (n_exp≈3
vs 9), strongly tapered beams (Do_scale_exp=0.62 vs 1.0), and a strong
top-biased ring density (ρ=−0.43 vs −0.12).

## 2. Winner Design (Island 5)

Raw DE vector: `best_vector.csv` — 12 continuous parameters.

| Parameter | Raw DE | Rounded | Consensus |
|-----------|--------|---------|-----------|
| n_lines | 16.507 | 17 | 4/5 islands at n=12–18 |
| n_expansion | 2.732 | 3 | 2/5 at n_exp=3–5 |
| blade_scale λ | 0.460 | — | |
| bank_angle | 21.9° | — | |
| r_hub | 0.60 m | — | **AT MIN BOUND** (4/5) |
| r_bottom | 0.30 m | — | **AT MIN BOUND** (3/5) |
| t_over_D | 0.01 | — | **AT MIN BOUND** (4/5) |
| target_Lr | 2.926 | — | Near max bound |
| density_profile | −0.426 | — | Strong top-bias |
| Do_top | 20.8 mm | — | |
| Do_scale_exp | 0.623 | — | Strongly tapered |
| beam_aspect | 1.063 | — | Near-circular |
| blade_tip_radius | 2.18 m | — | |

## 3. Per-Island Parameter Distributions

All 5 islands are feasible. Sorted by mass:

| Island | Mass (kg) | n_lines | n_exp | λ | bank° | density | r_hub(m) | Do_top(mm) | Do_scale |
|--------|-----------|---------|-------|---|-------|---------|----------|------------|----------|
| 5 | 5.658 | 16.5 | 2.7 | 0.46 | 21.9 | −0.43 | 0.60 | 20.8 | 0.623 |
| 2 | 5.752 | 16.7 | 5.8 | 0.39 | 23.6 | −0.14 | 0.60 | 23.9 | 1.000 |
| 1 | 5.765 | 18.4 | 14.3 | 0.23 | 30.7 | −0.33 | 0.62 | 22.7 | 1.000 |
| 3 | 5.778 | 12.7 | 4.4 | 0.49 | 35.0 | −0.16 | 0.60 | 23.3 | 1.000 |
| 4 | 6.377 | 17.8 | 11.8 | 0.27 | 27.9 | +0.76 | 0.62 | 22.2 | 1.000 |

Mass range: 5.66–6.38 kg | μ=5.87 kg | σ=0.26 kg

**Key observation:** Island 4 (+12%, 6.38 kg) is the only bottom-dense
design (ρ=+0.76) — every other island is top-biased. Island 5's winning
combination of strong top-bias (ρ=−0.43) + tapered beams (Do_scale_exp=0.62)
was not found by the other 4 islands, suggesting the DE population may not
have fully explored this parameter corner with only 5 islands.

## 4. Convergence Analysis

| Island | Started at | Final | Converged at iter | Flat for |
|--------|-----------|-------|-------------------|----------|
| 1 | 44.5 kg | 5.765 kg | 99 | 2 |
| 2 | 241.4 kg | 5.752 kg | 93 | 8 |
| 3 | 335.9 kg | 5.778 kg | 92 | 9 |
| 4 | 1,000,000 kg | 6.377 kg | 93 | 8 |
| 5 | 1,000,000 kg | 5.658 kg | 88 | 13 |

**Note:** Islands 1–3 started feasible (mass < 1000 kg at iter 1), while
islands 4–5 started infeasible and converged to feasibility. This is normal
DE behaviour for a constrained problem — some islands land in the feasible
region immediately, others need to cross penalty barriers.

**Flat-for counts are misleadingly low** because the convergence check
(±0.1%) is too strict for the 100-iteration short run — most designs were
still refining at iteration 90+. For a 5-island × 100-iteration exploratory
run, all islands show reasonable convergence trajectories.

**Tightness:** With only 5 islands, σ=0.26 kg is not meaningful as a
convergence metric. The spread is driven by island 4's outlier strategy
(+0.76 density, +12% mass) rather than loose convergence of the main basin.

## 5. Bound-Screaming Analysis

Three parameters are at bounds:

| Parameter | At bound | Direction | % of islands | What the optimizer wants |
|-----------|----------|-----------|-------------|--------------------------|
| t_over_D | 4/5 (80%) | Min (0.01) | Manufacturing floor | Thinner walls |
| r_hub | 4/5 (80%) | Min (0.60m) | Structural | Smaller hub ring |
| r_bottom | 3/5 (60%) | Min (0.30m) | Structural | Smaller ground ring |

r_hub_lo = 0.30 × p.trpt_hub_radius = 0.30 × 2.0m = 0.60m for 10kW params.

target_Lr: 2.93 for the winner, near max (3.0) but not exactly at it (only
island 4 hits the max). Free parameter for most islands.

**r_bottom is at min for 3/5 islands** but island 4 chose r_bottom=1.50m
(its heavy outlier strategy). This is weaker evidence than t_over_D (80%
unanimous) or r_hub (80%) — the small sample size means one island's choice
dominates the percentage.

## 6. 10kW vs 50kW — Strategy Comparison

| Parameter | 10kW Winner | 50kW Winner | Ratio (10/50) |
|-----------|-----------|-----------|----------------|
| Mass | 5.66 kg | 44.52 kg | 0.127× |
| n_lines | ~17 | 8 | 2.13× MORE lines |
| n_expansion | ~3 | 9 | 0.33× FEWER rotors |
| blade_scale λ | 0.460 | 0.404 | 1.14× |
| bank_angle | 21.9° | 30.2° | Shallower |
| r_hub | 0.60 m | 2.70 m | 0.22× |
| r_bottom | 0.30 m | 0.30 m | Same |
| Do_top | 20.8 mm | 81.0 mm | 0.26× |
| Do_scale_exp | 0.623 | 1.000 | Tapered vs straight |
| density_profile | −0.426 | −0.120 | Much stronger top-bias |
| beam_aspect | 1.063 | 1.000 | Slightly oval |
| t_over_D | 0.01 | 0.01 | Same |
| target_Lr | 2.926 | 3.0 | Similar |
| Mass/power | 0.566 kg/kW | 0.890 kg/kW | 36% better specific mass |

### Why more lines for 10kW?

At 10kW, the per-rotor power is only P/n_rotors ≈ 10/(n_exp+1) kW.
With fewer expansion rotors (n_exp≈3), each hub rotor handles ~2.5 kW.
More tether lines (n≈17) distribute this into many small, low-tension
segments — the polygon force resolution (sin(π/n)) becomes more favorable
as n increases. At n=17, sin(π/17)=0.184 — tension per tether is low
enough that 20mm beams suffice.

At 50kW with n=8, sin(π/8)=0.383 — each tether carries ~2.1× the
fractional load, requiring 81mm beams. The 10kW strategy of many-lines
+ less expansion is the small-system physics optimum.

### Why tapered beams?

Do_scale_exp=0.623 means beams thin significantly toward the ground (r=0.3m).
At small scales, the ground ring beams carry far less load than the hub
ring beams — tapering saves mass without compromising strength. At 50kW
(Do_scale_exp=1.0), the optimizer chose straight beams because the load
difference along the shaft is less pronounced.

### Strong top-bias

density_profile=−0.43 means rings are packed dense near the top (hub) and
sparse near the bottom. This makes physical sense: the expansion rotors
(and their thrust loads) cluster near the hub rings. Packing rings where
the loads are applied avoids wasted beam length.

## 7. Data Quality & Limitations

- **5 islands × 100 iterations** is an exploratory run, not a definitive
  campaign. The 50kW campaign used 60 islands × 10,000 iterations.
- **No parameter_trace.csv** — only convergence_history.csv and
  island_bests.csv exist. Cannot do correlation analysis across all
  evaluations.
- **n_lines values are continuous** — the DE optimizes continuous
  n_lines ∈ [3, 24], and the campaign runner rounds at evaluation time
  (`round(Int, clamp(x[8], 3, 24))`). The raw DE values in island_bests.csv
  are continuous; the rounded values drive physics.
- **Consensus incomplete** — with only 5 islands, parameter distributions
  are tentative. Island 4's diverging strategy (+12% mass, bottom-dense)
  could be either noise or a genuine competing basin — impossible to tell
  without more islands.

## 8. Recommendations

1. **Run a full 60-island 10kW campaign** — the 5-island exploratory run
   gives a plausible optimum (~5.7 kg) but cannot confirm convergence or
   explore the full strategy space. Island 4 suggests at least one competing
   basin exists.

2. **Widen t_over_D and r_hub bounds for 10kW:**
   - t_over_D: [0.005, 0.20] (was [0.01, 0.20]) — 80% at min
   - r_hub: [0.10, 16.0] (was [0.60, 16.0]) — 80% at min

3. **Investigate r_bottom trend:** The 50kW campaign also had r_bottom at
   min (47/60). Combined with the 10kW result (3/5 at min), this is a
   persistent signature — the optimizer consistently wants the smallest
   possible ground ring. Consider whether the min bound reflects real
   structural limits.

4. **Dashboard verification** — run `--v9` dashboard (or a 10kW variant)
   to visually inspect the winner geometry and confirm the unusual
   many-lines + top-bias strategy.

5. **Compare specific mass scaling** — 0.566 kg/kW for 10kW vs 0.890 kg/kW
   for 50kW suggests favourable scaling. A 20kW or 30kW campaign would
   trace the mass-vs-power curve.

# Constraint Satisfaction Analysis — 50kW Network Campaign

**Date:** 2026-06-15
**Data:** `scripts/results/v6_campaign_50kw/convergence_history.csv`
**Scope:** 60 islands, 517,400 rows, all feasible

---

## 1. Best Mass Per Island

| Statistic | Value |
|-----------|-------|
| Global best | 184.84312443249155 kg |
| Global best island | #58 (but 51 islands reach this value) |
| Worst best | 195.30724993001093 kg |
| Mean | 186.41 kg |
| Std dev | 3.77 kg |
| CV | 2.0% |

**Key finding:** 51/60 islands (85%) reach the global optimum of ~184.84 kg at some point during optimization. Only 9 islands never reach it. However, only **13 islands end at or near the optimum** — see Section 4.

---

## 2. Proximity to Global Best

Baseline: 184.84 kg

| Threshold | Bound | Islands | Pct |
|-----------|-------|---------|-----|
| Within 5% | ≤ 194.1 kg | 51 | 85.0% |
| Within 10% | ≤ 203.3 kg | 60 | 100.0% |
| Within 20% | ≤ 221.8 kg | 60 | 100.0% |

All islands appear "near-optimal" by a naive proximity metric, but this masks the underlying bimodal structure (see Section 4).

---

## 3. Convergence Speed Distribution

- **Total iterations:** 6,900–10,000 (mean 8,623)
- **Best found at iter:** 684–10,000 (mean 4,211)
- **First to 10% of best:** mean ~28 iterations across all categories
- **Improvement ratio (initial/best):** 1.9× to 24.1× (mean 7.6×)

| Convergence metric | STAYER | VISITOR_LEAVER | NEVER_OPTIMAL |
|---------------------|--------|----------------|---------------|
| Mean initial mass | 1,176 kg | 1,431 kg | 1,595 kg |
| Mean improvement | 6.4× | 7.7× | 8.2× |
| First 10% at iter (mean) | 37 | 27 | 21 |

**Interpretation:** The initial phase (getting below ~250 kg) is fast and easy for everyone. Convergence speed is not the differentiator — island fate is determined by whether the optimizer can *stay* at the global optimum, not by how quickly it gets there.

---

## 4. Cluster Analysis — THREE Basins of Attraction

The design space exhibits **three distinct attractors**, revealed by tracking final outcomes vs. best-visited values:

### Basin A: Global Optimum (~184.84 kg) — NARROW SPIKE

- **Visited by:** 51/60 islands (85%)
- **Stable for:** only 13 islands, and of these, only 2 (islands 52 and 43) found it at their very last iteration
- **Fragility evidence:** 35 islands reach 184.84 kg then **escape within 1–20 iterations** (mean 5.3, median 3.0 iterations later). This is characteristic of an optimizer that overshoots a razor-thin minimum and then cannot recover it.
- **Even "stayers" oscillate:** most spend 55–86% of post-optimum time *above* 195 kg before eventually landing back at 184.84

### Basin B: Intermediate (~186.09–186.31 kg) — 3 islands

- Islands 9, 18, 19 settle at ~186 kg — between the two main basins
- These islands also visited 184.84 kg but stabilized at a slightly higher value

### Basin C: Suboptimal Attractor (~195.31 kg) — THE TRUE BASIN

- **Final destination for 44/60 islands (73%)**
- 9 islands never escape this basin
- 35 islands find the global optimum but then fall back here
- This is a **broad, stable local minimum** that acts as the system's true attractor

### Gap Analysis

There is a **clean 10.5 kg gap** (5.66%) between Basin A (~184.84) and Basin C (~195.31). No islands settle in the 190–194 kg range. The three basins are well-separated.

---

## 5. Solution Robustness Assessment

### The design space is OVER-CONSTRAINED, not forgiving

| Evidence | Interpretation |
|----------|---------------|
| 85% visit optimum, only 22% stay | Global optimum is a narrow spike, not a basin |
| Escape within 1–20 iters (median 3) | Optimizer cannot hold the optimum — step size overshoots |
| 73% converge to suboptimal basin | The true attractor is +5.66% worse |
| Clean gap between basins | Constraint boundary creates a cliff, not a slope |
| Stayer oscillation (55–86% time at suboptimal level) | Even "successful" islands are barely clinging to the optimum |

### Robustness verdict: POOR

A well-conditioned design problem should show:
- A broad basin around the optimum (many solutions within 1–2%)
- Smooth convergence (monotonic improvement)
- Final outcomes clustered near the optimum

Instead, this problem shows:
- A binary outcome (optimum vs. suboptimal) with the suboptimal being the stable attractor
- Non-monotonic trajectories (optimum → escape → settle elsewhere)
- The 184.84 kg "optimum" may be a numerical artifact of constraint boundary clipping rather than a genuine design optimum

---

## 6. Recommendations

1. **Investigate the constraint that creates the 184.84 → 195.31 cliff.** The 10.5 kg gap suggests a hard constraint boundary. Relaxing or smoothing this constraint could merge the two basins.

2. **Verify that 184.84 kg designs are physically realizable.** The extreme fragility (escape within 1 iteration) suggests the optimizer may be exploiting a constraint violation borderline.

3. **Check optimizer step sizes.** The 1-iteration escape pattern is consistent with a step size that is too large for the curvature near the optimum.

4. **Consider the 195.31 kg designs as the practical optimum.** If 73% of the optimizer's effort converges here and the 184.84 designs are pathologically narrow, the robust design choice may be at 195.31 kg.

---

*Analysis script: `scripts/analyze_constraint.jl`*

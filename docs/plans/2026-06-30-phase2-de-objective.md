# Phase 2 — DE Objective Wrapper (design only, when Phase 1 validates)

**Date:** 2026-06-30
**Status:** Planning — blocked on Phase 1 validation
**Runtime finding:** Each settle+sim takes ~50-65s. Per-candidate 6-wind sweep ≈ 48 calls ≈ 40-50 minutes. DE campaign at 20 islands × 40 pop = 800 candidates ≈ 27 days. 

## Runtime Mitigation Strategy

Three complementary approaches:

### 1. Coarse Prescreening (reduces candidates ×10)

```
For all 800 candidates:
  1. Static solver → mass estimate (cheap, <1ms)
  2. Sort by mass, take top 10% (80 candidates)
  3. Dynamic verification only on these 80
```

This assumes the static solver is good enough to rank candidates, even if its absolute power predictions are wrong. The static solver correctly identifies which geometries are lighter — it just can't tell you if they're dynamically viable. Using it as a prescreen is valid.

**Cost:** 800 × 1ms + 80 × 50 min = ~67 hours ≈ 3 days. Acceptable.

### 2. Settle Reuse Across k Values (reduces settle count ×5)

The system geometry doesn't change during bisection — only k_mppt changes. We could:
1. Settle once at a reasonable k (say 100)
2. Save the settled state
3. For each bisection step, reload the saved state, then run just the 5s sim with the new k_mppt

This is valid because k_mppt only affects generator torque, not the TRPT geometry or tension distribution. The settle establishes the correct tension distribution — varying k_mppt after that just changes how much torque the generator extracts.

**Cost reduction:** 48 settles → ~8 settles per candidate (one per wind speed, plus a few extra). 3× faster.

### 3. Shorter Operational Settle

The 150k-step operational settle runs 60s of simulated time. The tension distribution stabilises much faster. A 30k-step settle (12s simulated) may be sufficient for structural gating.

Need to verify: after 12s of settle, does the ring FoS converge to within 5% of the 60s value?

## Implementation

### `src/objective_dynamic.jl`

```julia
function dynamic_objective(x, builder, P_rated, wind_speeds)
    # 1. Build system + static prescreen
    sys, u0, p, label = builder(x)
    static_mass = static_mass_estimate(x)  # from existing v10 objective
    
    # 2. Settle once (reuse across k values for this wind)
    # 3. Hunt k_mppt per wind speed (bracket + bisect)
    # 4. Verify at k* (10s, not 60s)
    # 5. Gate on min FoS
end
```

Will implement when Phase 1 validates the bisection methodology.

# RESTART_INSTRUCTIONS.md

## Current state (2026-04-25)

**v4 campaign is RUNNING.** 60 islands launched 2026-04-25 ~08:47 BST.
Expected completion: ~2026-04-32 (168 h from launch).
Julia PID at launch: 2784807 (check `pgrep -f run_v4_campaign`).

**Check progress:**
```bash
# Is the job still running?
pgrep -a -f run_v4_campaign

# Live log tail (prints every 50 generations per island)
tail -f scripts/results/trpt_opt_v4/campaign.log

# How many islands have finished?
ls scripts/results/trpt_opt_v4/island_*/best_design.csv 2>/dev/null | wc -l

# Best mass found so far across completed islands
grep -h "" scripts/results/trpt_opt_v4/island_*/best_design.csv 2>/dev/null | sort -t, -k6 -n | head -3
```

---

## What was done

### v3 — complete (2026-04-22)

All 60 islands (2 configs × 3 beams × 5 axials × 2 seeds) finished.
Results in `scripts/results/trpt_opt_v3/`.

Key v3 findings:
- All 60 designs converged to `taper_ratio = 1.0` (cylindrical shaft)
- 10 kW winner: 15.44 kg (was 2.81 kg v2, +449%)
- 50 kW winner: 145.88 kg (was 19.22 kg v2, +659%)
- 54/60 v2 designs were physically infeasible (torsional collapse)
- Euler FOS ≥ 1.8 + Torsional FOS ≥ 1.5 both enforced

### v4 — physics redesign (merged 2026-04-25)

Key change: **constant L/r ring spacing** replaces the v2/v3 uniform spacing + taper profile.

`src/ring_spacing.jl` adds:
- `ring_spacing_v4(r_top, r_bottom, tether_length, target_Lr)` — geometric-series ring placement
- `TRPTDesignV4` — struct with `r_bottom` and `target_Lr` as decision variables (9 DoF total)
- `evaluate_design(TRPTDesignV4)` — same physics as v2 but using non-uniform segment lengths
- `objective_v4`, `design_from_vector_v4`, `search_bounds_v4`

Physics motivation: uniform spacing with a tapered shaft gives high L/r at the thin end →
Euler buckling limit forces cylindrical geometry. Constant L/r allows taper without that penalty.

Test coverage: 368/368 passing (test/test_ring_spacing_v4.jl).

### v4 campaign structure

60 islands: 2 power configs × 3 beam profiles × 5 Lr-init zones × 2 seeds
- Power configs: 10kw, 50kw
- Beam profiles: circular, elliptical, airfoil
- Lr-init zones: [0.4–0.8], [0.7–1.1], [1.0–1.4], [1.3–1.7], [1.6–2.0]
- Seeds: 1, 2
- ~2.8 h/island, 168 h total
- Output: `scripts/results/trpt_opt_v4/island_NN/`

---

## What to do when v4 completes

1. Check `scripts/results/trpt_opt_v4/campaign_summary.csv` for top designs
2. Read the winner's `island_NN/best_design.csv` for full parameters
3. If taper (r_hub ≠ r_bottom) emerges as the dominant design direction,
   v4 hypothesis is confirmed — proceed to v5 (manufacturing cost model)
4. If cylindrical dominates again, investigate whether the Lr zone biasing
   is finding different optima or the same cylindrical attractor

---

## Code reference

| File | Purpose |
|------|---------|
| `src/ring_spacing.jl` | v4 ring spacing + TRPTDesignV4 + evaluate_design |
| `test/test_ring_spacing_v4.jl` | 368 tests for ring_spacing_v4 physics |
| `scripts/run_v4_campaign.jl` | 60-island sequential DE campaign |
| `scripts/results/trpt_opt_v4/campaign.log` | Live stdout log |
| `scripts/results/trpt_opt_v3/` | v3 60-island results (committed) |
| `DECISIONS.md` | Full design rationale for v3 torsion + v4 L/r |

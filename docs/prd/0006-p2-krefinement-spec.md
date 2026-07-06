# P2 k-Refinement — Zoom Procedure (v2)

**Status:** SPEC (ready for implementation)
**Parent:** [PRD 0006 verification checklist](0006-phase1-verification-checklist.md)
**Gate:** P0 + P1 + this k-refinement must close before Phase 2 starts.
**Updated:** 2026-07-06 — incorporated feedback re: measurement pipeline reuse,
wall-clock estimate, determinism check, convergence precedence, log10 fitting,
grid description, progressive saves, methodological note.

---

## Problem

The current max-power hunt uses a coarse log-spaced grid:
`[2.0] ∪ 8 log points 3→500 ∪ [5000]` (10 values). All k values land on grid
points: 2.0, 3.0, 6.23, 12.94, 26.87, 55.8, 115.8, 240.4, 500, 5000.
The true optimum may lie between grid points. Numerical noise determines which
grid point a given run picks, making results non-reproducible. All P values are
lower bounds; FoS at the true peak is unmeasured.

**Methodological note:** Gate 1 picked k from 5 s pre-sweep sims. This
refinement picks from 60 s verifies. That is an upgrade, but it means ΔP
conflates finer grid + longer selection basis. The flatness metric on 60 s data
is the honest measure of whether k actually mattered. Do not quote ΔP as
"refinement gain" without stating that both effects are in play.

## Priority rows (near FoS thresholds)

| Row | Builder | Wind | Current k | P_kW | FoS | Bracket | Threshold |
|-----|---------|------|-----------|------|-----|---------|-----------|
| R1 | V10 Tight | 11 m/s | 26.87 | 118.8 | 1.15 | [12.94, 55.8] | FoS 1.0 (could tip from marginal→fail) |
| R2 | Reinforced | 15 m/s | 26.87 | 301.0 | 2.26 | [12.94, 55.8] | FoS 1.5 (safe→marginal risk) |
| R3 | λ=0.69 | 15 m/s | 6.23 | 155.8 | 2.08 | [3.0, 12.94] | FoS 1.5 (verdict could flip) |

## Pre-flight

1. **Commit P1 first.** The GIT_HASH auto-detect reads `git rev-parse`.
   Uncommitted P1 edits would stamp every CSV `-dirty`. P1 is committed at
   `a2ad174` / `68b2b27`.

2. **Clear Julia cache.** `rm -rf ~/.julia/compiled/v1.12/KiteTurbineDynamics`
   before running, per CLAUDE.md discipline. Prevents stale compiled code from
   picking up pre-fix geometry.

## Measurement pipeline — reuse Gate 1 verbatim

**Do NOT hand-roll the simulation loop.** The refinement script must `include`
`scripts/hunt_kmppt_bisect.jl` and call the exact same functions Gate 1 used:

```julia
include("scripts/hunt_kmppt_bisect.jl")
using .ControlMapHunt

# For each k: reuse the Gate 1 pipeline
slices = ControlMapHunt.run_verify_timeseries(
    builder_fn, wind_speed, k_val; verbose=false,
    lift_device=KiteTurbineDynamics.rotary_lifter_default())
s_end = slices[end]
# → P_kw, ω_rpm, min_fos, collapse_margin_deg from s_end
```

Builders: use the exact Gate 1 wrappers:
```julia
# R1: V10 Tight λ=1.0
builder_fn = ControlMapHunt.v10_tight_builder(blade_scale=1.0)

# R2: V10 Reinforced
builder_fn = ControlMapHunt.v10_tight_builder(
    r_bottom_scale=1.30, tether_diameter=0.004, blade_scale=1.0)

# R3: λ=0.69
builder_fn = ControlMapHunt.v10_tight_builder(blade_scale=0.69)
```

**Why this matters:** `run_verify_timeseries` bakes in 9.5 s settle, 1/7-power
shear via `h_ref`, 1 Hz FEA slices, P taken from the last slice, and the exact
`RampController` / `init_geometry!` / `lin_damp=0.05` choices. If the refine
script reimplements any of that differently, `P_new` vs `P_old` comparisons are
contaminated and the >5%/threshold rules fire spuriously.

## Zoom procedure (per row)

### Step 0 — Determinism check

Run R3's current k (6.23) twice and confirm P agrees to <0.1%:

```julia
s1 = run_verify_timeseries(builder_r3, 15.0, 6.23; verbose=false, ...)
s2 = run_verify_timeseries(builder_r3, 15.0, 6.23; verbose=false, ...)
ΔP = abs(s1[end].P_kw - s2[end].P_kw) / s1[end].P_kw
ΔP < 0.001 || error("run-to-run noise $(ΔP*100)% — refinement cannot converge")
```

If run-to-run noise exceeds 0.1%, the real problem is not grid coarseness but
non-determinism in the simulator. In that case: fix the noise source first,
then re-run the determinism check. Do not proceed to refinement on noisy data.

### Step 1 — Bracket

For each row, bracket = the two grid neighbours of the railed k.

```
R1/R2: k ∈ [12.94, 55.8]   (26.87 railed between them)
R3:    k ∈ [3.0,  12.94]   (6.23  railed between them)
```

### Step 2 — Sample 5 interior points

Log-spaced between bracket endpoints.

```
k_i = exp10(log10(k_low) + i * (log10(k_high) - log10(k_low)) / (N+1))
     for i = 1..N, where N = 5
```

R1/R2 interior points (~): 16.4, 20.8, 26.3, 33.3, 42.1
R3 interior points (~): 4.1, 5.5, 7.4, 9.9, 13.2

### Step 3 — Verify each at 60s

For each k in {k_low, 5 interior, k_high} (7 points per row, plus current_k
which we re-verify anyway):

- Call `run_verify_timeseries(builder_fn, wind_speed, k_val; ...)`
- Extract `s_end.P_kw`, `s_end.ω_rpm`, `s_end.min_fos`, `s_end.collapse_margin_deg`
- Write row to `scripts/results/control_maps/k_refine_{row}.csv` immediately
  on completion (progressive save — if the script is killed mid-run, completed
  points are not lost)

**Wall-clock estimate (revised):** From tier-X timestamps, 6 winds per builder
took ~2.9 h → ~29 min per wind for ~115 s of sim → wall/sim ≈ 15×. A 60 s
verify + settle ≈ 15–18 min wall time. 7 points/row ≈ 1.8–2.1 h/row. Three
rows ≈ 5.5–6.5 h total sequential.

**Recommendation:** time the first point, and if ≥15 min wall, run the three
rows as three parallel Julia processes (they are independent — each row reads
its own builder/wind, writes its own CSV).

### Step 4 — Find peak

1. Pick the sample with the highest `P_kw` — that is `k_refined` (must be a
   measured sample, so `FoS_refined` is directly measured there).
2. Fit a quadratic in **log10(k)** (not k — sampling is log-spaced; a parabola
   in k biases the vertex toward higher k). Report the log10-fit vertex only as
   a diagnostic in the output CSV; do not use it for `k_refined`.
3. Compute `peak_flatness = max(P) / min(P)` over the 3 points centred on the
   peak. Close to 1.0 = flat peak (k not critical, the grid point was fine);
   >>1.0 = sharp peak (k matters, the grid was far off).

### Step 5 — Edge check

If the maximum is at `k_low` or `k_high` (bracket edge), expand the bracket one
grid step outward and repeat from Step 2. If at `k_low`, expand downward; if at
`k_high`, expand upward.

Edge case: R3's k_low is 2.0 (K_MIN). If peak is at 2.0, accept — we can't go
below minimum.

### Step 6 — Convergence criterion

```
interior_peak AND (rel_diff < 1% OR abs_diff < 0.5 kW)
```

This must hold for **both** neighbours of the peak (the point below and the
point above), not just either one. If it holds for one neighbour but not the
other, the peak is asymmetric — expand the bracket on the side that fails and
re-sample.

Where:
- `interior_peak` = the max-P sample is not at k_low or k_high
- `rel_diff = |P_peak - P_neighbour| / P_peak`
- `abs_diff = |P_peak - P_neighbour|` (kW)

## Deliverable

A single Julia script `scripts/refine_k_priority_rows.jl` that:

1. **`include`s `hunt_kmppt_bisect.jl`** and reuses `ControlMapHunt` functions
   (builder wrappers, `run_verify_timeseries`, GIT_HASH auto-detect)
2. Runs the determinism check (Step 0) — exits with error if >0.1% noise
3. For each row: samples, verifies, finds peak per the procedure above
4. **Writes progressively**: each point's result is appended to
   `scripts/results/control_maps/k_refine_{row}.csv` on completion, stamped
   with the auto-detected GIT_HASH
5. Prints a results table:

```
Row  Builder          Wind  k_old   P_old   FoS_old  k_new   P_new   FoS_new  ΔP%  peak_flatness
R1   V10 Tight        11    26.87   118.8   1.15     xx.x    xxx.x   x.xx     +x%  1.0xx
R2   V10 Reinforced   15    26.87   301.0   2.26     xx.x    xxx.x   x.xx     +x%  1.0xx
R3   λ=0.69           15    6.23    155.8   2.08     xx.x    xxx.x   x.xx     +x%  1.0xx
```

6. Reports `k_fit_log10` (quadratic-fit vertex in log10-space) as a diagnostic
   column in the output, clearly marked as "diagnostic, not measured"

## What to do with the results

After the refinement runs:

1. **If any FoS crosses a threshold** (1.5 ↔ <1.5, 1.0 ↔ <1.0): update
   the Phase 1 delta doc and the envelope summary. Regenerate via
   `scripts/generate_phase1_delta.py --output docs/prd/0006-phase1-delta-analysis.md`.

2. **If P changes by >5%**: the Gate 1 CSVs are superseded for that row.
   Re-run the full control map for that builder at that wind with the refined k.

3. **If all rows are stable** (FoS same side of threshold, P within 5%):
   P2 k-refinement is done. Proceed to remaining P2 items (convergence criterion,
   circular closure, stamp units, sweep persistence).

## Non-goals

- Full Brent/golden-section optimisation (Phase 2+)
- Re-running all 18 rows (only the 3 threshold rows)
- Optimising for FoS (we optimise P, report FoS at the optimum)
- P(k) sweep persistence for all rows (only these 3 rows' zoom data saved)

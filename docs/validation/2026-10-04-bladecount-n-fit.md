# Blade-count n-fit — measured Cp(n, λ) for the regen family

Date: 2026-10-04. From the aero-validator seat: the n-fit that closes the
blade-count leg of the cp-authority thread — does the `(5/n)^0.7 × tip-loss`
placeholder in `src/bem.jl::cp_bem` survive the measured series, and if not,
what replaces it, and this report makes no shared-tree source edits.

STE pass 2026-10-06: no numbers or findings changed.

Evidence chain:

- Series: `.scratch/bem_regression/bladecount_regen/results/regen_series.csv`
  (11 drivers × commanded λ 1–8 = 88 points). Family and conventions live in
  the series' NOTES.md. sha256
  `2ba1e4eb88e5b4841a20ea85af3beb3f4b759d4b6d176c4547479be04ffa1c69`.
  Independently re-parsed byte-exact and row-traced by science-validator.

- Fit probe: `scratch/av_fit_bladecount.py` → `scratch/av_fit_bladecount_out.log`
  (read-only. Reproduce: `python3 scratch/av_fit_bladecount.py`).
- Committed surface compared against: `src/aerodynamics.jl` (BEM_CP grid) at
  tree `f225e95`. Raw June pairs per ktdjl-bem-source.md.

## Anchor accord (series n=3 ↔ the committed June surface)

- Raw pairs: worst |dCp| = +6.67% (λ8), −5.09% (λ1). Mid-range ≤ 2.5%.
  Worst |dCt| = 3.3%.

- Series interpolated to committed grid: −0.30% at λ5.2 (peak check), −1.54%
  at λ4.0/4.1, +5.48% at λ8.0.
- Linear-limit sanity: at TSR 1.0488 the fixed-chord ratio Cp(n)/Cp(3) = n/3
  exactly, for every n.

→ The n=3 anchor and the committed table are one currency. All ratios below
take n=3 as their reference.

## Verdict 1 — the measured series contradicts the placeholder on both axes

**Fixed chord (0.500 m, σ ∝ n — the placeholder assumption).**
Measured ratio Cp(n)/Cp(3), rows n, columns TSR_meas (= commanded λ × 1.0488):

| n | 1.05 | 2.10 | 3.15 | 4.20 | 5.24 | 6.29 | 7.34 | 8.39 |
|---|------|------|------|------|------|------|------|------|
| 4 | 1.333 | 1.311 | 1.216 | 1.069 | 0.934 | 0.822 | 0.625 | −0.241 |
| 5 | 1.667 | 1.606 | 1.357 | 1.048 | 0.826 | 0.622 | 0.190 | −1.937 |
| 6 | 2.000 | 1.885 | 1.419 | 0.987 | 0.705 | 0.421 | −0.387 | −3.864 |
| 7 | 2.333 | 2.142 | 1.430 | 0.910 | 0.585 | 0.201 | −1.061 | −5.894 |
| 8 | 2.667 | 2.370 | 1.411 | 0.828 | 0.468 | −0.071 | −1.786 | −7.961 |

Placeholder (flat in λ): 0.910 / 0.826 / 0.753 / 0.690 / 0.636 for n = 4..8.

- At the design point (TSR 4.20) the placeholder over-penalizes n ≥ 4 by
  ~16–23 percentage points: measured +6.9 / +4.8 / −1.3 / −9.0 / −17.2 % vs
  modelled −9.0 / −17.4 / −24.7 / −31.0 / −36.4 %.
- At TSR 3.15 the sign is backwards for n ≥ 5 (+41.1% at n=8 vs −36.4%).

- n ≥ 6 goes negative at high λ (over-solidity brake). This branch is real.
  Keep the raw (negative) values in the table asset. Let the consumer clamp.

**Matched solidity (chord 1.5/n) — context.** Opposite sign to the
placeholder: the ratio rises mildly with n, +3.4 (n=4) → +8.4% (n=8) peak-to-peak,
+14.1% at λ8. (Full table in the probe log.)

## Verdict 2 — no closed law survives

- No rank-1 decomposition (n-factor × λ-factor) fits ln F: max residual 0.395.
- Per-λ power law lnF = m·ln(n/3): m = +1.00 (λ1) → +0.90 → +0.44 →
  −0.09 (λ4.2) → −0.62 (λ5.2). The best per-λ fit still leaves ≤ 15% worst.
→ Replace with the measured surface. Do not re-exponentiate the old form.

## Recommended replacement (proposal, adoption is the cp-authority ruling)

```julia
# fixed-chord ratio tables, rows n = 3..8; n=3 row ≡ 1.0
# Cp ratio Rf:   [table above]
# Ct ratio Rt:   [table below]
# TSR knots kt = [1.0488, 2.0976, 3.1465, 4.1953, 5.2441, 6.2929, 7.3417, 8.3905]
cp_bem(n, λ) = clamp(cp_at_tsr(λ) * interpλ(Rf[n], λ), 0, 16/27)
ct_bem(n, λ) = clamp(ct_at_tsr(λ) * interpλ(Rt[n], λ), 0, 1.02)
```

Ct ratio Ct(n)/Ct(3):

| n | 1.05 | 2.10 | 3.15 | 4.20 | 5.24 | 6.29 | 7.34 | 8.39 |
|---|------|------|------|------|------|------|------|------|
| 4 | 1.333 | 1.324 | 1.296 | 1.235 | 1.175 | 1.147 | 1.128 | 1.116 |
| 5 | 1.666 | 1.642 | 1.562 | 1.415 | 1.305 | 1.253 | 1.219 | 1.201 |
| 6 | 1.999 | 1.954 | 1.792 | 1.555 | 1.405 | 1.333 | 1.290 | 1.266 |
| 7 | 2.333 | 2.259 | 1.989 | 1.666 | 1.484 | 1.396 | 1.347 | 1.318 |
| 8 | 2.666 | 2.556 | 2.157 | 1.756 | 1.548 | 1.449 | 1.394 | 1.361 |

Notes on the form:

- Ratios vs n=3 keep `cp_bem(3, λ) ≡ cp_at_tsr(λ)`: continuity with the
  committed surface, error bounded by the anchor accord above (≤ 1.6% mid-grid,
  −0.3% at 5.2, +5.5% at 8.0).

- The measured surface subsumes tip loss, hub loss and induction — it is the
  measured total for this rotor, family and convention.

- n is integer (rows are exact, no n-interpolation), and linear in λ between knots,
  held at the ends. Below 1.0488 the linear-limit ratio n/3 is what the first
  knot already shows.

- The `sqrt(n/3)` Ct placeholder is λ-dependently wrong the same way
  (under-predicts near design, over-predicts at high λ). Same treatment.

- Baseline label: the tables make n=3 the explicit baseline, retiring the old
  mislabel on this path.

## Open items (flagged, not decided here)

1. **n > 8**: no data. At design λ the trend is monotone decreasing in n, so
   holding n=8 is optimistic, not conservative — extend the series or rule a
   policy before the consumer calls `cp_bem` above 8.

2. **Sizing re-validation**: `rotor_radius_for_power` / `annulus_span_for_power`
   outputs move for all n ≥ 4 (up to ~23 pts of cp at design λ). Re-run sizing
   checks when adopted.

3. **Clamp semantics**: keep the current clamps for sizing. Keep raw values in
   the asset (the n ≥ 6, λ ≥ 7 negatives are a real regime, outside the
   operating window).

## Provenance

Series produced by the aero-worker lane: `.scratch/bem_regression/bladecount_regen`,
family + the 10.488 m/s convention documented in its NOTES.md.
Independent verification by the science-validator seat (byte-exact re-parse,
88/88 rows traced to raw outputs, fit and anchor reproduction re-derived by
this probe on the 2026-10-04). Nothing here touches the committed tree.

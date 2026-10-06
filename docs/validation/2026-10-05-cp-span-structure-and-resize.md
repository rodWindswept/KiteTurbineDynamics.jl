# Cp, span, and blade count: the fall is the sizing assumption, not a span effect (2026-10-05)

Tree: `f225e95`. Probe: `scratch/av_probe_s2_rf_resize.jl` (Julia, control +
patched decode + two cold ODE flights). Fit: `scratch/av_rf41_resize.py`.
Logs: `.julia_depot/logs/av_probe_s2_rf_resize.log`, `scratch/av_rf41_resize_out.log`.
Data: `regen_series.csv`, sha256 `2ba1e4eb…` (the 88-point regen family of aero-worker).

STE pass 2026-10-06: no numbers or findings changed.

## 1. "Cp falls with span" has the causality inverted

In the v13 decode (`src/objective_v10.jl:352,366`):

    r_rotor = sqrt(P_i / (cp_bem(n, 4.1) · ½ρπ·v_i³))     [BEM.rotor_radius_for_power]
    span    = 0.75 · r_rotor · blade_scale                 → span ∝ 1/√cp_bem

So the span growth of the S2 screen (1.356 m → 1.765 m, n=3 → 9) is exactly the
1/√(Cp ratio) response to the assumed Cp fall (1.356·√(0.3576/0.2110) = 1.765).
`cp_bem` has no span argument. The span grows because the assumed Cp falls.
Nothing physical couples them in the model.

## 2. The measured size of the fall (fixed chord, vs the n=3 anchor, at λ=4.1)

| n | placeholder (re-anchored to n=3) | measured Rf(n, 4.1) |
|---|---|---|
| 4 | 0.906 | 1.082 |
| 5 | 0.826 | 1.076 |
| 6 | 0.753 | 1.026 |
| 7 | 0.690 | 0.958 |
| 8 | 0.636 | 0.881 |

Modelled loss n=3→8 at the sizing point: −36%. Measured: −12% (≈3× over-charge).
At the operating λ≈3.1 the measured sign is positive (+41% at n=8). No flat law
fits: rank-1 residual 39% in ln, per-λ exponent +1.00 → −0.62.

## 3. Re-decode of the S2 n-sweep under the measured surface (measured)

| n | span_old | span_new | A_ZY_old | A_ZY_new |
|---|---|---|---|---|
| 3 | 1.3559 | 1.4916 | 33.25 | 36.78 |
| 4 | 1.4214 | 1.4339 | 34.95 | 35.27 |
| 5 | 1.4916 | 1.4382 | 36.78 | 35.39 |
| 6 | 1.5626 | 1.4725 | 38.65 | 36.29 |
| 7 | 1.6325 | 1.5243 | 40.51 | 37.65 |
| 8 | 1.7002 | 1.5889 | 42.31 | 39.35 |

Control decode reproduced the committed log to 4 dp. Julia sweep matches the
closed-form prediction to ≤0.02%.

Cold ODE flights (same regime, floor 5.0 live):

| case | P_end kW | FoS | twist ratio | status |
|---|---|---|---|---|
| n=3 old (S2) | 5.1218 | 5.20 | 0.392 | ok, stationary |
| **n=3 new** | **5.3691** | 5.41 | 0.360 | ok, stationary |
| n=9 old | 5.4480 | 7.75 | 0.296 | ok, stationary |
| **n=8 new** | **5.2542** | 10.09 | 0.335 | ok, stationary |

The n-lever inverts. The placeholder screen said n=9 flies best. Corrected, the
n=3 class flies more than n=8 (5.37 vs 5.25).

The sizing band compresses from
33.2–44.0 m² to 35.3–39.3 m². The regen family does not measure n=9, so the n=9
span above was the placeholder case only.

## 4. Consequences

- The correction direction is per-machine, not global: n=3 +10.0% span, n=8 −6.6%. A flat "−8% area" rule would be wrong.

- Every stored genome re-decodes to a different machine under a corrected
  `cp_bem` (span ∝ 1/√cp). Re-decode ≠ re-measure of one artifact. The 5.06 kW
  seed is a pre-ruling number. Its class gains ~10% span.

- ODE side: keep `cp_at_tsr` for now. The measured series is within a few % of
  what the ODE flies at the operating points of the machines. The mis-belief
  lives in the sizing path.

## 5. Lessons for the report

1. **An anchor carries its blade count.** The committed table is 3-blade data
   labelled n=5. Every n-scaled value inherited a two-blade offset (n=3 read
   +21% high, n=6 −9% low). Fix the label before fitting exponents.

2. **Solidity first, blade count second.** At matched solidity more blades help
   at the peak (+3.4…+8.4%). At fixed chord the effect is λ-shaped with a sign
   change — no flat law.

3. **The high-λ branch is a cliff.** At fixed chord, n≥7 loses Cp fast beyond
   λ≈5 and goes negative at λ≈8 (over-solidity collapse). Keep operating λ off it.

4. **Sizing assumptions become geometry.** span ∝ 1/√cp_bem: a Cp convention
   change silently resizes every machine. Audit chains where an assumption
   turns into a physical dimension.

5. **No global resize factor.** The same fix upsizes some machines and
   downsizes others. Re-optimise, do not rescale.

## 6. Addendum 2026-10-05 (aero-worker): n=9 measured

The n=9 Rf row was a continuation. It is now measured (AeroDyn v5.0.0, deck
`ad_n09c500`, 8 cases, rc=0, terminated normally, echo BEM_Mod 2 / Skew_Mod 1 /
UA_Mod 0 / SkewMomCorr F, series CSV re-parsed). Fixed-chord Cp(9)/Cp(3):
3.000, 2.558, 1.371, 0.746, 0.357, −0.385, −2.534, −10.035 at λ=1..8.

The continuation missed the λ=6 sign flip (predicted +0.025, measured −0.385)
and overshot λ=2..5.

At the sizing point: cp_bem(9,4.1)=0.2373 (placeholder 0.2110, continuation
0.2399). Corrected n=9 decode: span 1.7653 → 1.6644, A_ZY 44.04 → 41.35.

Full cold ODE: P_end 5.3142 kW (placeholder-era screen claimed 5.448), FoS
9.92, twist 0.318, stationary, no breaks.

Result: the corrected ordering is n=3 (5.369) > n=9 (5.314) > n=8 (5.254).
The placeholder-era "n=9 flies best" claim does not survive. The corrected
A_ZY band top is 41.35 (n=9), not 39.35 (n=8).

The cliff in Lesson 3 extends to n=9. The measured row goes negative from λ≈6.

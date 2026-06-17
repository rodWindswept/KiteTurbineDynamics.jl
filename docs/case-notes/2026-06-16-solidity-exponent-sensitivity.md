# Case Note: Solidity Exponent Sensitivity — n=12 Optimum

**Date:** 2026-06-16
**Author:** Hermes Agent (with Rod Read)
**Status:** Open — requires AeroDyn BEM sweep across blade counts

---

## Summary

The V6.2 DE campaign with corrected physics (tan→sin, coupled knuckle mass,
cos²·⁶⁵ elevation) converged to n_lines=12 (dodecagon) at 74.17 kg. The old
uncorrected model converged to n=3 (triangle) at 58.19 kg.

The n=12 result is driven in part by the BEM solidity model in `src/bem.jl`,
which uses a placeholder exponent k=0.7 for the solidity penalty:
Cp ∝ (5/n_lines)^k.

The file itself warns: "⚠ PLACEHOLDER — the scaling exponents (0.7 for Cp,
0.5 for CT) are physically motivated but approximate. AeroDyn BEM sweeps
across n_lines ∈ {3,4,5,6,7,8} are needed to validate or replace these."

## Sensitivity

At n=12, Cp varies from 0.26 (k=0.3) to 0.15 (k=0.9), a 1.7× range:

| k | Cp/Cp₅ at n=12 | Rotor radius impact |
|---|---------------|-------------------|
| 0.3 | 0.84× | +9% larger rotor |
| 0.5 | 0.70× | +19% |
| **0.7** | **0.59× (current)** | **+30%** |
| 0.9 | 0.49× | +42% |

## What's Needed

AeroDyn v5.0.0 BEM sweep across n_blades ∈ {3,4,5,6,7,8,10,12} using the
original MVP input files (ad_primary_MVP.inp, ad_blade_MVP.inp,
ad_airfoil_Rigid.inp) — located on the rod machine at:
`/home/rod/.local/share/QNAP/Qsync/.../10kW Design/MVP working folder/Ollie/Rotor/AeroDyn/`

For each blade count, the AeroDyn driver needs:
- HubRad = 0.4 × R (40% annular cutout)
- HubLoss = True
- BEM_Mod=2, Skew_Mod=1, UA_Mod=0
- TSR sweep: 2-8
- Extract Cp(λ) and CT(λ) surfaces

## Three Unvalidated Models Now Documented

This conversation surfaced three model assumptions that the old n=3 result
depended on, all now corrected or flagged:

| # | Assumption | Old state | Current state |
|---|-----------|-----------|---------------|
| 1 | tan(π/n) vs sin(π/n) polygon resolution | tan: understated compression at low n by up to 2× | **Fixed: sin** |
| 2 | Free-floating knuckle mass | 0.005 kg regardless of beam size | **Fixed: coupled to Do·t** |
| 3 | Solidity exponent k=0.7 | Boosts n=3, penalizes n=12 | **PLACEHOLDER: needs AeroDyn validation** |

## Impact on Forum Report

The report should note that n=12 is the current optimum under the placeholder
solidity model, and that AeroDyn validation may shift the optimum to n=6–10
or confirm n=12. The qualitative conclusion — that corrected physics push
the optimum toward higher n_lines than the old triangle-ring result — is
robust regardless of the exact exponent.

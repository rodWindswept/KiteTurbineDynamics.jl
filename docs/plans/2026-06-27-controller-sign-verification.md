# Controller Sign Verification

**Status:** suspected — needs trace evidence before code change
**Date:** 2026-06-27
**Found during:** V10 Tight dashboard test at Schiphol (flight delay)

## Observation

V10 Tight at k_mppt=79 produces ~114 kW — well above the 50 kW target.
The controller continues ramping but power stays high, suggesting it may be
operating on the left (under-braked) flank of the power-vs-k curve, where
decreasing k_mppt increases speed and power — opposite to controller sign assumption.

## Hypothesis

The controller assumes `dP/dk < 0` (more braking = less power), which is true
on the right (over-braked) flank of the hill. If V10 Tight sits on the left flank
(under-braked, `dP/dk > 0`), the controller's P-term pushes in the wrong direction.

## Verification plan (tomorrow)

1. Run `scripts/record_ramp_traces.jl` — canonical 10kW + V10 Tight if possible
2. From the CSVs, plot k_mppt vs P_gen and compute dP/dk at the operating point
3. If dP/dk > 0 on V10 Tight → confirmed sign bug
4. Fix: perturb-and-observe (dither ±Δk, measure ΔP) to detect hill side
5. Re-test

## Do not change code until verified with trace data.

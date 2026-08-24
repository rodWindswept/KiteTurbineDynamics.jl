# 5 kW campaign RE-RUN winners — VERIFIED (2026-08-24)

First trustworthy 5 kW designs.  Era: span³ blade-mass law (m = 0.420·(span/1.0)³,
^3.0 exponent per Rod), 18.8 m, k=2.24, honest window (relax 10 + window 40),
mass-min objective, FoS floor 2.5, P floor 5 kW.  Campaign: 3 islands × 30 gens,
930 evals, 44,396 s (~12.3 h), launch git `edd7f5f`.

## Global best (best_vector.csv) — re-gate PASSES

- Genome: 3 lines, 5 rings, hub-only (n_active=1), r_hub 4.56 m, blade_scale
  0.474 (span 1.18 m), bank 22°.
- **P_gen 6.39 kW sustained** (ω_gnd 10.58 rad/s), twist ratio 0.2 (limit
  56.7°), clearance 9.57 m, tip speed OK.  ✅ ode_gate_v13 PASSES.
- **m_airborne 3.73 kg (no lifter), φ = 0.746 kg/kW** (Daisy anchor 1.3 —
  the mass-optimised machine is ~1.7× lighter than the unoptimised prototype).
- Telemetry: P 5.02 kW, **FoS 2.9** (finite — the pre-guard FoS=Inf screening
  PASSES; the machine hugs both the FoS 2.5 and P 5.0 floors, the mass-min
  optimum).

## Island bests (all verified finite FoS, gate-clean)

| Island | fitness (kg) | m_airborne | φ (kg/kW) | lines | FoS |
|---|---|---|---|---|---|
| 1 | 10.47 | 5.47 | 1.09 | 3 | — |
| 2 | 12.34 | 7.34 | 1.47 | 4 | — |
| 3 | 8.54 | 3.54 | 0.71 | 3 | — |

All hub-only (n_active=1): the mass-min objective found the minimal rotor
count optimal at 5 kW.  Stage-B (rotor-mask families) tests whether co-equal
expansion rotors change that.

## Residual work

- Stage-A variant A1 (mass exponent ^2.63 vs ^3.0) brackets the blade-mass
  exponent sensitivity (Rod's literature check: Jamieson 2.29-3.07, Sommerfeld
  2.7, rung law R^2.7).
- Convention fixes (tau_max_safe cap law, ring numbering, P_kw sign).
- The settle `DomainError` (negative value under a fractional exponent)
  recurred in this campaign's log — caught by try/catch, fix in the settle
  workstream.

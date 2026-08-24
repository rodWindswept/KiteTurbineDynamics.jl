# 5 kW campaign RE-RUN winners — VERIFIED (2026-08-24)

First trustworthy 5 kW designs.  Era: span³ blade-mass law (m = 0.420·(span/1.0)³,
^3.0 exponent per Rod), 18.8 m, k=2.24, honest window (relax 10 + window 40),
mass-min objective, FoS floor 2.5, P floor 5 kW.  Campaign: 3 islands × 30 gens,
**928 evals** (930 CSV rows incl. header), **44,396 s (12.3 h) wall per the
run log** (`Campaign complete in 44396.0s`), ≈48 s/eval, launch git `edd7f5f`.

Note on the objective mass: fitness (kg) = m_airborne + 5.0 kg lifter.  The
lifter mass is included in the DE score but excluded from the lift-line
tension sizing and from the quoted m_airborne/φ below (lift carries itself).

## Global best (best_vector.csv, island 3) — re-gate PASSES at k=2.24

- Genome: 3 lines, 5 rings, hub-only (n_active=1), r_hub 4.56 m, blade_scale
  0.474 (span 1.18 m), bank 22°.  All geometry verified by decoding the
  winner through the campaign path (2026-08-24).
- **P_gen 5.18 kW at the 30 s gate read** — flat trace 5.09 → 5.18 kW over the
  window, ω_gnd stable at 13.22 rad/s (genuinely settled, no decay), no twist
  crossing in any 5 s chunk, clearance 9.57 m, tip-speed OK.
  ✅ ode_gate_v13 **PASSES** at the campaign operating point k=2.24
  (re-gated 2026-08-24; an earlier gate run at the stale k=5.39 read
  6.39 kW — superseded).
- **m_airborne 3.73 kg (no lifter), φ = 0.746 kg/kW** (Daisy anchor 1.3 —
  the mass-optimised machine is ~1.7× lighter than the unoptimised prototype).
- Telemetry: P_mean 5.02 kW, **FoS 2.93** (finite — the FoS=Inf screening
  PASSES; the machine hugs both the FoS 2.5 and P 5.0 floors, exactly the
  mass-min optimum shape).  Fitness 8.73 kg = 3.73 + 5.0 kg lifter.

## Island bests (all gate-clean, finite FoS, hub-only)

| Island | fitness (kg) | m_airborne (kg) | φ (kg/kW) | lines | FoS |
|---|---|---|---|---|---|
| 1 | 10.65 | 5.65 | 1.13 | 3 | 8.9 |
| 2 | 12.59 | 7.59 | 1.52 | 4 | 348.6 |
| 3 (global) | 8.73 | 3.73 | 0.75 | 3 | 2.9 |

m_airborne from the recorded T_lift (m = T_lift·sin70°/(1.5·g)): 88.5 N,
118.8 N, 58.4 N.  Only the global best hugs both floors; island 2's best is a
heavier high-FoS local optimum.  All three are hub-only (n_active=1): the
mass-min objective found the minimal rotor count optimal at 5 kW.  Stage-B
(rotor-mask families) tests whether co-equal expansion rotors change that.

## Residual work

- Stage-A variant A1 (mass exponent ^2.63 vs ^3.0) brackets the blade-mass
  exponent sensitivity (Rod's literature check: Jamieson 2.29-3.07, Sommerfeld
  2.7, rung law R^2.7).
- Convention fixes (tau_max_safe cap law, ring numbering, P_kw sign).
- The settle `DomainError` (negative value under a fractional exponent)
  recurred in this campaign's log — caught by try/catch, fix in the settle
  workstream.

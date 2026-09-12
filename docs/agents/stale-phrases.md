# Stale-Phrase List — KTD.jl Superseded Claims

Shared source of truth for the doc-currency and skill-currency sweeps.
When a finding supersedes a previously-true claim, add the old phrasing
here with the date and the replacement. Both `scripts/doc_currency_check.py`
and the `skills-currency-sweep` cron scan against this list.

Format per entry:
## phrase (exact text that became false)
Date: YYYY-MM-DD
Replacement: what to say instead

Note: entries marked `doc-only` appear only in repo docs and aren't expected
in skills; entries marked `skill-only` are skill-internal phrasing. Unmarked
entries are scanned in both.

---

## Static equilibrium solver predicts 50 kW; full multibody ODE shows ~12 kW
Date: 2026-08-12
Replacement: ζ fix resolved the static-vs-dynamic gap — ODE now sustains power (DECISIONS.md [2026-08-12])

## 1861 tests
Date: 2026-08-12
Replacement: see test/runtests.jl (the test count drifts — do not hardcode)

## zeta = 1.5
Date: 2026-08-12
Replacement: ζ=0.05 (SystemParams.zeta)

## Settle/ODE mismatch
Date: 2026-08-12
Replacement: was ζ=1.5 DC reverse torque, not an init flaw — see DECISIONS.md [2026-08-12]

## cold-start stall
Date: 2026-08-12
Replacement: was ζ=1.5, not k_mppt; with ζ=0.05 the ODE spins up

## Not used by the current campaign launcher
Date: 2026-08-12
Replacement: V12 cold-start IS the campaign evaluator for ≤7kW rungs (skill-only)

## Covers the v11 warmstart physics era
Date: 2026-08-12
Replacement: v11/v12 warmstart (≥10 kW) + V12 cold-start (≤7 kW) (skill-only)

## not in campaigns
Date: 2026-08-12
Replacement: cold-start V12 is the ≤7kW campaign evaluator (skill-only)

## ODED-based objectives are verification instruments, NOT
Date: 2026-08-12
Replacement: cold-start V12 at ≤7kW is a viable campaign evaluator (45-65s/eval) (skill-only)

## No genome is known to pass the full V12 warmstart evaluator at 50 kW
Date: 2026-08-12
Replacement: still true at 50kW; at ≤7kW use cold-start; 5kW seed passes ODE gate

## ODE never sustains power
Date: 2026-08-12
Replacement: with ζ=0.05 the ODE sustains power at all tested scales

## The hub ring hosts ONLY the cp/ct rotor
Date: 2026-09-12
Replacement: Any rotor may be a banked-blade expansion rotor, including the main rotor (topmost). Where banked blades are fitted, the expansion model REPLACES the cp/ct disc model at that ring. See docs/agents/physics-topology.md §4

## expansion_params_from_rotors excludes the decoder's hub rotor
Date: 2026-09-12
Replacement: expansion_params_from_rotors must be able to map the topmost rotor when it carries banked blades; the 2026-08-22 exclusion is superseded

## Expansion rotors are ADDITIONAL rotors on intermediate rings only
Date: 2026-09-12
Replacement: expansion (banked-blade) rotors may be fitted to any ring, including the topmost/main rotor ring

## hub rotor
Date: 2026-09-12
Replacement: main rotor (the topmost rotor). "Hub" is not a rotor term — see docs/agents/physics-topology.md §4

## bridles (cyan lines)
Date: 2026-09-12
Replacement: bridles and the cyan line are different lines: bridles = lift bearing to main-rotor vertices (n_lines lines); cyan line = sky hook to lift bearing (1 line). See docs/agents/physics-topology.md §2

## bearing_offset = 6.0 is the bearing design position
Date: 2026-09-12
Replacement: 6.0 is a PLACEHOLDER from other tested systems; the bearing's axial design point was never chosen. Measured correct geometry ~3.99 m axial / ~4.66 m 3D bridle

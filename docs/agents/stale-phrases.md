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

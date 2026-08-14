# Proposal: Align settle equilibrium with ODE drag balance

**Date:** 2026-08-13
**Status:** PROPOSAL — awaiting Rod's acceptance before any code change
**Standard:** physics-model change → proposal + acceptance tests + DECISIONS entry

## Context and evidence

Every V12 cold-start eval starts from `settle_to_operational_state`, then
runs the ODE window. Rod observed that **no design actually settles** — ω
keeps falling throughout the 20s gate window:

| Design | ω_settle | ω at 5s | ω at 20s | Gap |
|--------|---------:|--------:|---------:|-----|
| 5kW island-1 winner (multi-rotor) | ~19.1 | 17.8 | 14.8 | ~23% |
| 5kW island-2 winner (single-rotor) | 19.1 | — | 9.6 | ~50% |
| 5kW seed | 16.0 | 15.8 | 13.6 | ~15% |

Root cause found in `initialization.jl:731-768`: the settle's ω scan uses a
**simplified power balance**:

```
P_aero(ω) = hub cp_at_tsr + Σ expansion swept-area·cp·cos(bank)
P_gen(ω)  = k_mppt·ω³
ω_settle  = highest ω where P_aero > P_gen
```

This balance **omits parasitic drag** (tether drag C_Dt=2.7, ring beam drag,
expansion induced drag) — all of which the ODE applies every step. The
settle therefore over-predicts equilibrium ω. The ODE then relaxes from the
idealized state to the true equilibrium; that relaxation IS the "decay"
observed in every gate trace. It is an initialization error, not a design
property.

The codebase already contains the correct balance:
`solve_equilibrium_omega` (objective_v6.jl:385) computes
`P_net = P_aero − P_par − P_gen` with `parasitic_drag_power`
(objective_v6.jl:246). The settle simply doesn't use it.

## Proposed change

Modify the ω_eq scan in `settle_to_operational_state`
(initialization.jl:731-764) to subtract parasitic drag power at each scan ω:

1. After computing `P_aero` (hub + expansion, unchanged), compute
   `P_par(ω)` using the same terms as `parasitic_drag_power` — tether line
   drag and ring beam drag with the scalar midpoint approximation
   (adequate for a settle target; the ODE remains the fidelity arbiter).
2. Change the acceptance condition from `P_aero > P_gen` to
   `P_aero − P_par > P_gen`.
3. Keep the scan structure (downward from ω_rated_max, first crossing)
   unchanged so behaviour is identical when P_par ≈ 0 (very low ω).

Expansion induced drag: `parasitic_drag_power` uses zero-lift + induced
annulus terms; reuse them as-is rather than inventing new terms.

## Acceptance tests

Written BEFORE the code change, expected to fail on current master:

**A. Gap reduction (physics):** for the 5kW island-1 winner genome,
`ω_settle` and `ω_final` (20s ODE window) must satisfy
`|ω_settle − ω_final| / ω_settle < 0.20`. Current: ~0.23-0.50.

**B. Bit-identity guard:** the change must NOT move `ω_settle` for a
zero-drag configuration. Construct a test with `C_Dt = 0` (or drag terms
forced to 0) and assert the settle result is bit-identical to the
pre-change scan (the P_par=0 path must reproduce exactly).

**C. Directional monotonicity:** increasing tether diameter (more drag)
must LOWER ω_settle; decreasing it must raise ω_settle. Guards against a
sign error.

**D. No new stall:** the 5kW seed and island-1 winner must still produce
P ≥ 0.5×rated in the 20s gate after the change (the settle must not
undershoot into the stall basin).

## Blast radius

`settle_to_operational_state` is the shared initialization for: dashboard,
all cold-start evaluator paths (V12 cold ≤7kW campaigns), diagnostics,
tests. Consequences:

- **Bit-reproducibility:** every CSV produced from a settle-based path
  after the change belongs to a new physics era. Past CSVs (pre-change)
  remain valid as-is; no retroactive reinterpretation, but campaigns must
  stamp the new era string.
- **Test suite:** tests asserting exact settle ω values will move. They
  must be updated to the post-change values deliberately, not by
  re-blessing golden traces without review.
- **Warmstart path (≥10 kW):** unaffected in structure — it uses
  `solve_equilibrium_self_consistent`, not the settle scan. The drag terms
  already exist there.
- **Dashboard:** settle target will be lower (closer to true equilibrium);
  dashboard sims should show flatter startup transients.

## DECISIONS entry (draft — to be added on acceptance)

`## [2026-08-13] Settle equilibrium includes parasitic drag`

Context: settle ω scan omitted drag → all evals started above true
equilibrium → systematic decay transients mis-ranked by the 10s V12 window.
Choice: include tether + ring-beam drag (scalar midpoint approx) in the
settle power balance; reuse parasitic_drag_power terms. Consequences:
settle ω drops ~15-30% at 5kW; new physics era; past CSVs remain valid
historical artifacts; dashboard transients flatten.

## Rollback

One-line revert of the scan change; P_par=0 path preserved for tests.

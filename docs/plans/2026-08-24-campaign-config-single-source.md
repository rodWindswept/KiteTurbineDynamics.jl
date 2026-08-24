# Proposal — single ObjectiveConfig builder for the 5 kW instruments

**Status:** PROPOSAL — no code yet. Per repo convention: proposal → acceptance
tests → code → DECISIONS entry (Rod's approval required).
**Date:** 2026-08-24. **Author:** Hermes (desktop session), at the DeepSeek
Harness's request.

## Context

The 5 kW campaign config is hand-built in five scripts — runner, smoke, gate
(regate/ladder inherit), analysis tools, plus the sweep as producer. The same
ObjectiveConfig kwargs are re-typed everywhere (FoS 2.5/2.5, power floor 5.0,
relax 10 + window 40, tail5, kickstart 0, lift, k).

This has bitten twice:
- **k drift**: k=10.0 default overload (trust-log 2026-08-13), then the
  stale k=5.39 gate after the honest-window re-sweep (trust-log 2026-08-24).
  Fixed per-value by `K_MPPT_5KW_HONEST` + the static k-alignment test.
- **FoS banner drift**: the runner banner printed `fos_target=1.5` while the
  cfg held 2.5 (fixed in the 2026-08-22 era, commit `ae190e0`).

The k fix removed one literal class; the FoS banner shows the same disease in
another field. Hand-built duplicated configs drift — one per field, per
instrument, per era.

## Proposal

One builder in `scripts/compute_seeds.jl` (already the shared include for
runner/smoke/gate/regate/ladder):

```julia
function campaign_cfg(p_base; length::Float64=18.8, kw::Float64=5.0)
    return ObjectiveConfig(;
        power_W = kw * 1000.0, v_rated = V_RATED,
        p_floor_kw = kw, p_ceiling_kw = kw,
        relax_s = 10.0, window_s = WINDOW_S,       # honest window
        fos_target = 2.5, fos_hard = 2.5,
        power_stat = :tail5, penalize_ceiling = false,
        kickstart_s = 0.0,
        k_mppt = (kw == 5.0) ? K_MPPT_5KW_HONEST : p_base.k_mppt,
        tether_diameter = p_base.tether_diameter,
    )
end
```

All five consumers construct their config from this one function; the gate's
`k_mp` resolves from the same const inside the builder. Any future change
(FoS floor, window, k) is a one-file edit.

## Acceptance criteria

1. **Bit-identity**: the seed genome evaluated via each instrument's config
   (runner path, smoke path, gate-path decode + settle) reproduces the
   current seed numbers exactly (P_mean 7.15 kW-class seed, T_lift match) —
   the refactor changes nothing physical.
2. `test/test_campaign_k_alignment.jl` still green; fast suite green.
3. Smoke re-pass at 18.8 m.
4. Winner re-gate unchanged (5.18 kW, flat) after the refactor.
5. DECISIONS entry recording the single-source config decision.

## Blast radius

- The runner banner/PROVENANCE prints stay; only the cfg source changes.
- `PHYSICS_ERA` strings unchanged (no physics change — configuration
  plumbing only).
- The sweep script stays the producer of the k VALUE (it defines the sweep
  list); the builder consumes the chosen const.

## Out of scope / deferred

- Generalising `campaign_cfg` beyond the 5 kW rung (per-rung k selection for
  7–50 kW needs its own sweep-anchored consts) — later rung work.
- Winners-record verifier script (would mechanically cross-check WINNERS.md
  against artifacts) — deferred until after this lands.
- STE pre-commit hook scoping (changed-lines-only, exempt `results/*.md`
  from the writing-style sensors so `--no-verify` stops being the norm) —
  lower priority, separate repo-infra task.

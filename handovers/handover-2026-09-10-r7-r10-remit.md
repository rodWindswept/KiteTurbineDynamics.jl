# Handover: R7-R10 remit + R11 (L-genome) study, 2026-09-10

The next agent picks up R7 (lead), then R8, R9, R10, with R11 as a scoped study.

Do not run a campaign. Campaigns stay paused.

## State at hand-off

- Hermes finished the six static guards and pushed them (`b427143`). Guards 1, 3, 4, 6 are unit tests (fast 2072/2072). Guard 2 is `test_physics_path_ode.jl`. Guard 5 is `test_gate_v13` A5. Acceptance passes. GitHub Actions runs `acceptance.yml` on the push as a second opinion.
- Hermes owns the brain sync and NAS staleness work. Do not duplicate it.
- HEAD is `8063726` (audit reports plus STE pass). The audit reports live in `docs/reports/2026-09-08-*`.
- The harness holds the desktop history sessions (`14ae5a30…`, `36af66b6…`, `d671cb4c…`, `ab6b9fdc…`) read-only in the KTD workspace. Do not resume or edit them.

## Remit

### R7 (lead): wire beam sizing and drop the free beam genes

Entry points: `handovers/handover-2026-09-07-closed-form-beam-sizing.md` (next steps) and `docs/plans/2026-09-06-closed-form-beam-sizing.md` (REV 2). The work:

1. Write `size_beams_closed_form(dec, p_base, cfg)`. It reproduces the `objective_v10` per-ring load build on v5 geometry with the corrected orientation, then calls `solve_ring_Do` per ring using effective DLF ≈ 0.18, not 1.2.
2. Wire the solved `Do` back into `sys` so the drag model and verification FEA see the same tube. Drop the free beam genes x1-x4 (`Do_top`, `t_over_D`, `beam_aspect`, `Do_scale_exp`) to go from 10 to 6 dimensions.
3. Re-baseline the fast suite, the acceptance suite, and one short campaign (`--gen`). Add a one-time FEA verification that includes the hub ring. The hub ring is the hidden weakest ring gap that VOIDed the rotorcount winner. Both structural paths skip it.

### R8: J·θ regression

Run a 2-rotor seed and assert no reversal over 20 s (ODE acceptance). The code removed the spurious torsional spring (`ring_forces.jl:314`, `torques -= J_rotor·alpha`, which used the twist angle as acceleration). No test pins that a 2-rotor machine stays forward.

### R9: doc drift

- Add a SUPERSEDED banner on DECISIONS [2026-08-21] `k=5.39` → `2.24`.
- Ban the `m = m_ref·λ³` phrase in physics-validation-ledger B1. λ means TSR.
- Fix stale counts. CLAUDE.md says "34/39 test files" and "5 ODE files". Reality is 42 fast plus 6 acceptance = 48.
- Restore DECISIONS "newest at top". The 08-19 to 09-04 entries sit at the bottom.

### R10: legacy test fate (needs Rod's call)

Era-pin headers or delete the 8 LEGACY-ONLY files (`test_blade_geometry`, `test_documented_claims`, `test_expansion_stack`, `test_lift_kite_rotary`, `test_parameters`, `test_physics_path_guard`, `test_trpt_axial_profiles`, and the v2 stack) plus the museum-pin testsets. Do not leave them as green "v13 health" signals.

## R11 (new): study before re-adding axial length (`tether_length`) as a genome gene

Question (Rod): did we remove "axial length" from the genome for speed, and should we re-add it for future campaigns?

Findings so far (from chat, to fold into a `docs/plans/` study when picked up):

- `tether_length` was never a free gene. It is a fixed, Daisy-anchored, power-class-scaled parameter (`params_at_length`, 18.8 m at 5 kW). The v4 change (DECISIONS [2026-04-22]) removed the axial profile family (x8/x9/x10) for physics, not speed. That change gives constant L/r and uniform Euler-buckling FoS. Do not re-add those genes.
- The model includes wind shear. The ODE `wf` uses Hellmann 1/7 (`objective_evaluator.jl:559`). The decode sizing uses power-law 0.14 (`objective_v10.jl:81`). Upper rotors see more wind than lower rotors. Wake blocking (0.9086) opposes it. Over the 3-4 m rotor-stack span the two roughly cancel.
- `h_ref` is the hub altitude and scales with L (`mass_scale` × geom_scale, so 9.4 m at 5 kW). The hub stays pinned at rated 11 m/s. Lengthening L does not buy absolute power. It only weakens the lower rotors relative to the hub.
- The Daisy published rating is ">1.5 kW @ 10 m/s" (`docs/validation/physics-validation-ledger.md` A3, `docs/validation/tulloch-prototype-configurations.md`). The code uses 11 m/s at `h_ref` = hub (5.155 m). The rated reference itself (10 vs 11 m/s, and hub vs ground) is a discrepancy to resolve.

Study scope (R11):

1. Adopt a standard ground reference (10 m is the normal met reference) and pin rated wind there.
2. Verify the Daisy anemometer height and rated wind from the Tulloch thesis (`docs/validation/tulloch-thesis-extract.txt`, "wind speed 5.3 m/s measured at 5 m height", "test at 10 m/s").
3. Decide whether to fix the reference at ground so L becomes a real power axis via `v_hub = v_ref·(L·sinβ/h_ref)^(1/7)`.
4. Only then design the L gene. Add guards against the short-L and n_rings→3 degenerate, the same class as the confirmed `target_Lr` exploit.

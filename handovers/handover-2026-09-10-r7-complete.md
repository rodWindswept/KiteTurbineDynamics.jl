# Handover — R7 complete, next: R8, R9 (done), R10, R11 (2026-09-10)

The next agent picks up **R8, R10 and R11**. R7 and R9 are done in the working
tree (uncommitted). Campaigns: only the pre-authorised short R7 re-baseline run
(see §6) — no other campaign without explicit go-ahead.

Entry point: `handovers/handover-2026-09-10-r7-r10-remit.md` (the remit), then
this file.

## 1. Running Julia in this sandbox (read this first)

`/snap/bin/julia` (the PATH `julia`) cannot create a systemd scope here
(`DBus … refusing`, exit 46). The raw binary works, and `~/.julia` is
read-only, so the depot lives in the workspace:

```bash
cd <repo>
JULIA_DEPOT_PATH="$PWD/.julia_depot:/home/rodbot/.julia" \
  /snap/julia/165/bin/julia --project=. test/runtests.jl
```

- `.julia_depot/` (1.6 GB, gitignored) is a pre-seeded depot — reuses the
  existing precompile cache.
- **The acceptance runner spawns children via PATH.** Prepend the shim:
  `PATH="$PWD/.julia_depot/bin:$PATH"`. Without it every acceptance file exits
  46.
- `/tmp` is ephemeral per command; put scratch output under `.julia_depot/`.

## 2. What R7 delivered

**Canonical 10-D genome.** `TRPT_V10_DIM = 10`; the four free beam genes
(`Do_top`, `t_over_D`, `beam_aspect`, `Do_scale_exp`) are gone. Layout:
`[r_hub, r_bottom, target_Lr, n_lines, density_profile, rotor_count, bank_top,
bank_bottom, blade_scale_top, blade_scale_bottom]`. Legacy 14-D vectors/CSVs
are still accepted and sliced (`canonical_v10`, `_normalize_v10_14` in
`src/objective_v10.jl`), so old call sites keep working; the live evaluator
ignores the legacy beam genes and re-sizes.

**`size_beams_closed_form(dec, p_base, cfg)`** (`src/trpt_optimization.jl`).
Load model (REV 2 §5, corrected):

```
F_v = F_kink(signed) + HELIX_LOAD_FACTOR·T_line      (no centrifugal relief — see below)
T_line = TENSION_LOAD_MARGIN·thrust/n_lines + T_lift/n_lines
N_comp = F_v / (2 sin(π/n));  solve_ring_Do(N_comp, L_poly, t_over_D; fos_req = fos_hard·SIZING_FOS_MARGIN)
```

- `F_kink` — signed taper kink, exact geometry.
- `HELIX_LOAD_FACTOR = 0.32` — torque-helix term, measured on the seed.
- `TENSION_LOAD_MARGIN = 1.2` — settled ODE tension is ~15–20 % above the static
  thrust + lifter (ring weight on the shaft, tilt, dynamics).
- `SIZING_FOS_MARGIN = 1.3` — the solve is Euler-only; the FEA also carries
  bending, and the 5 s acceptance window dips ~15 % below the static FEA.
- Centrifugal relief is **not** applied: the ODE models blade/ring rotational
  mass as inertia and `analyse_ring` has no radial centrifugal term. Applying it
  made the closed form under-size against its own verifier. **Model gap.**

**One tube authority.** `sys.ring_Do_per_ring` holds the solved per-ring Do;
`ring_Do_at(sys, ring_idx, r, p)` (`src/types.jl`) is read by the ODE ring-beam
drag (`src/dynamics.jl`), the settle drag (`src/initialization.jl`) and the FEA
(`src/ring_element_analysis.jl`). Empty vector → legacy taper-law fallback.
`build_system_from_v10` gained `beam_sizing=`. `gate_design`
(`scripts/ode_gate_v13.jl`) now builds the same sized tube.

**Hub ring.** `ring_element_analysis` now evaluates `ring_ids[2:end]` (ground
ring still excluded). The closed form sizes the hub at the worse of rated and
`(T_peak, ω = 0)`.

## 3. The answer to Rod's tension question

"Why is the ODE line tension ~2.5× the static estimate?" — measured in
`scratch/r7_tension_budget.jl`:

- ODE settled segment tension ≈ 365 N/line at the ground = rotor thrust
  (≈ 250 N/line, from the **decoded** 3.66 m annulus at the operating
  `ct_at_tsr(λ) ≈ 0.79`) + constant-tension lifter (≈ 72 N/line) + ≈ 15 %
  weight/tilt/dynamics.
- The legacy static build used `BEM.rotor_radius_for_power(P, v_local)` (≈ 2.1 m
  — a *radius for power*, not the rotor) with `CT = 0.55` and omitted the
  lifter → 145 N. **That, not the DLF, was the discrepancy.**
- The 2026-09-06 "effective DLF ≈ 0.18" was `N_comp / T_line` with the *ODE*
  tension on the `n_lines = 3` winner. The per-ring load is the signed kink
  (0 at a constant-radius cylinder, up to 0.46·T at the cone top) plus the helix
  (0.32·T in the seed's transmission cylinder). Bending is negligible
  (FEA `util_ax` 2.4 vs `util_bend` 0.002).

Recorded in DECISIONS `[2026-09-10]`.

## 4. Verification status

- **Fast suite: 2073/2073 green** (41 files; `test_beam_sizing_closed_form.jl`
  and `test_rope_resolution.jl` added, 40 after the R10 archive).
- **Acceptance suite: 8/8 green** (`test/acceptance_runtests.jl` now includes the
  new R8 file). Re-run 2026-09-10 (round 6) after the rope-resolution refactor —
  all 8 still PASS. Re-baselined: `test_evaluator_v13.jl` B6 (re-sized winner is
  `:ok`, FoS ≥ 2.5), `test_settle_lowk_honest.jl` A3 (honest k = 2.24, not the
  superseded 5.39), `test_physics_path_ode.jl` P2 (compare measured power, not
  just status).
- **One-time FEA on the seed** (`scratch/r7_feasibility.jl`): `FoS_min 2.89` at
  margin 1.15 (now 1.3), hub ring included. `test_evaluator_v13` B6 on the old
  campaign winner: `:ok`, `FoS 4.85`, `P 5.41 kW`.

## 5. R9 — done

- SUPERSEDED banner on DECISIONS `[2026-08-21]` (k = 5.39 retired → 2.24).
- `docs/validation/physics-validation-ledger.md` B1 now says `m = m_ref·span³`.
- CLAUDE.md counts → 43 fast + 8 acceptance; CONTEXT.md dates → 2026-09-10.
- DECISIONS merged to global newest-at-top (the 08-19→09-04 entries moved out of
  the "Knowledge Pipeline Decisions" tail, 60 dated entries verified intact).

## 6. R7 short campaign — LAUNCHED, STOPPED, blocked by a diagnosed settle gap

The pre-authorised short campaign was launched (3 islands, `--gen 1`, tag
`r7rebase`) and **stopped after the first evals all rejected the seed**. The
seed evaluates `:reject` with `FoS 1.63` over the 40 s honest window, even
though it is `:ok` with `FoS 2.78` in the 5 s acceptance window.

**Diagnosed 2026-09-10** — full evidence in
`docs/plans/2026-09-10-shaft-windup-workstream.md`:

- **Torque budget**: `τ_gen = k·ω² ≈ 385 N·m`, shaft ≈ 520–608 N·m at the top,
  a persistent **+120 N·m** residual on the torsional DOF at *every* k
  (2.24 → 5.39). Higher k makes it worse (lower ω ⇒ more twist for the same
  torque); at k = 4.0/5.39 the twist crosses the collapse limit inside 50 s.
- **It saturates**: 300 s run, Δα 264° → 287° → 294° with collapsing
  increments. The bulk twist is **stable** (twist_ratio saturates ≈ 0.84 < 1.0).
- **But a sustained ≈ 10 s load limit cycle sits underneath**: a 150 s trace
  (`scratch/r7_windup_fos_long.jl`) shows the transmission-ring `N_comp`
  cycling 120 ↔ 200 N with `twist_ratio` flat at 0.83–0.84, FoS 1.88 ↔ 2.77,
  still going at t = 140 s. **So extending the relax alone does NOT unblock the
  campaign** — the static sizing cannot cover the cyclic trough.
- **The cycle is physical, not numerical**: halving `dt` roughly doubles its
  amplitude (`scratch/r7_cycle_dt.jl`: N range 125 → 244), i.e. the coarse dt
  was damping a real mode. Bearing damping shrinks it but does not clear the
  gate (`scratch/r7_cycle_damp.jl`: `lin_damp` 0.05 → 0.60 gives N range
  125 → 58 and FoS trough 1.70 → 1.97).
- **The mode is shaft lateral wobble** (`scratch/r7_mode_id.jl`): `N_comp`
  correlates most with the ring-centre lateral offsets (hub ring swings up to
  **0.49 m** sideways, r = 0.65), not with twist. It is a deliberate model
  feature (the orbital-damper docstring leaves rings free to wobble).
- **Physical damping does not decay it** (`scratch/r7_phys_damp.jl`, 120 s):
  with the artificial damper off the wobble range is 473 → 402 (no decay);
  with it at 0.05, 103 → 71. The model has no credible damping for this mode.
- **Root cause (i)**: `settle_to_operational_state` initialises the cumulative
  twist at only **42.5°** (per-segment 6.6° max) while the running equilibrium is
  **≈ 294°** — a **~7× settle gap**. The first ~100 s of every run is a wind-up,
  and the honest window (10–50 s) sits inside it.
- The 45° per-segment bisection cap is **not** binding (raising it to the
  segment's δα* gave byte-identical output), so the fix is the settle's torque
  **target/model**, not the bound. Raising `SIZING_FOS_MARGIN` 1.3 → 2.0 moved
  the dip only to 2.40.

Rod assigned this its own workstream, so the campaign stays paused. The
recommended next step is to determine whether the ≈ 10 s cycle is physical
(aeroelastic / ring-plane tilt) or numerical (rope grid, dt) — see the workstream
doc §4. Evidence: `scratch/r7_windup_budget.jl`, `r7_windup_long.jl`,
`r7_window_fos.jl`, `r7_settle_twist.jl`, `r7_windup_fos_long.jl`.

**Damping audit (Rod's concern, 2026-09-10).** The old "applied every step, so
finer dt = more damping" mistake is **not** on the live path: `run_canonical_sim!`
applies only the rope damper, and it is dt-scaled (`exp(-rate·dt)`). The one
un-scaled line (`ang_damp`) is legacy `simulate`-only, off by default. **But the
rope damper itself is the problem**: `lin_damp = 0.05` is an artificial
numerical stabiliser with a ≈ 13 µs time constant and no physical basis, and it
dominates the structural loads — with it off, `N_comp` swings 95–606 N; with it
at 0.05, 90–217 N. Every FoS and beam size currently depends on it. It is also
mislabelled a "bearing damper" in `evaluate_windowed` (it damps rope nodes).
Full audit table in `docs/plans/2026-09-10-shaft-windup-workstream.md` §2.7.

**Rope resolution is now parameterised** (`ROPE_SUBSEGS` in `src/types.jl`,
default 4 = historical, bit-identical — fast suite 2049/2049 at 4). Sweeping
4 → 5 → 8 (`scratch/r7_rope_res.jl`) **increases** the resolved ring-load range
(43 → 54 → 256 N) and lowers FoS (1.83 → 1.55 → 0.25): the coarse grid's
numerical dissipation was *suppressing* a real oscillation, so resolution is not
the fix — physical line damping/drag is. Rod is fetching the Dunker / Tevide /
Labat line-drag data (`Cd(Re)`, tangential drag, strumming) to replace the flat
`Cd = 1.0`.

**Lift audit + kite-lag test (round 6).** Lift tension is mass-compensating
(1.5× weight), flat in wind while taut, applied to the sky anchor (reaching the
bearing via the cyan line), along a steady direction to a *lagged* kite point.
Setting the kite lag to ~0 left the wobble unchanged (N range 42 vs 43), so the
lift lag is not the driver.

**Campaign re-launched (2026-09-10, round 3)** on Rod's original pre-authorisation
to test whether the DE can find wobble-tolerant designs rather than inferring
from the seed. Three islands, `--gen 1`, tag `r7rebase`
(`scripts/results/v13_5kw_masslift_len18.8_rotorcount_r7rebase/`).

**Result: 50 genomes evaluated, ZERO valid.** Islands 2 and 3 ran to completion
(20 evals each, 10270 s / 8035 s); island 1 was killed early by the harness
(10 evals). Status breakdown: ~39 `reject`, 5 `reject_twist`, 3
`clearance_reject`, 0 `ok`. Best FoS seen 4.8, but those genomes failed on power
or twist. So under the R7 evaluator the early population cannot simultaneously
meet FoS ≥ 2.5 and P ≥ 5 kW — the wobble-driven strut load is the gate
(§2.15: line drag cannot damp it; ζ ≈ 0.001).

**All R7 code + suites are green in the working tree; only the campaign
re-baseline is outstanding, and the early evidence says the wobble-driven FoS
is the gate.**

## 7. Remaining work

### R8 — done
`test/test_jtheta_no_reversal.jl`: 2-rotor seed, 20 s, ground/hub ω stay > 0.
In the acceptance suite (`ACCEPTANCE_FILES`). Standalone: `ω_gnd min 12.77`,
`P 5.31 kW`.

### R10 — done (Rod's call: archive dead-builder-only, era-pin provenance)
- **Archived** to `test/archive/` (removed from `runtests.jl`):
  `test_parameters`, `test_expansion_stack`, `test_trpt_axial_profiles`,
  `test_physics_path_guard`. See `test/archive/README.md` for the reasons.
- **Era-pinned** (still run, with an `ERA PIN` header):
  `test_blade_geometry`, `test_documented_claims`, `test_lift_kite_rotary`.
- Fast suite now 40 files, **2049/2049 green**.
- Follow-up not done: the museum-pin *testsets* inside live files (first seven of
  `test_builders_v10.jl`; testsets 4-6/8-9 of `test_ring_spacing_v4.jl`).

### Wind-up workstream — scoped, not executed
`docs/plans/2026-09-10-shaft-windup-workstream.md` (Rod 2026-09-10: investigate
as its own workstream). Blocks the R7 re-baseline campaign.

### R11 — study scoped
`docs/plans/2026-09-10-axial-length-wind-reference-study.md`. Key findings:
`tether_length` was never a gene (v4 removed the axial-profile family for
physics); the decoder's `wind_speed_at_ring` silently uses `h_ref = 50 m`
instead of the rung's `h_ref` (**a real bug** — `src/objective_v10.jl:89-95`);
published Daisy rating ">1.5 kW @ 10 m/s" vs code 11 m/s at the hub; the
handover's "5.3 m/s at 5 m" quote is **not** in the Tulloch extract. Awaiting
Rod's decisions (4 open questions in §5 of the study).

## 8. Known gaps / follow-ups

- Centrifugal relief is not modelled by the FEA (§2) — the plan's §5 `F_cf` term
  is unimplemented.
- The sizing is conservative for the rotor rings (the constant helix factor
  over-covers where the kink dominates).
- Hub beam **drag** is still excluded from the ODE drag loop
  (`src/dynamics.jl` `2:(Nr-1)`) — the settled tube is consistent where used,
  but the hub tube's drag is not modelled.
- Legacy diagnostic scripts (`scripts/diag_*.jl`, `bounds_audit.jl`,
  `view_campaign_genomes.jl`) still index the 14-D layout; new campaign
  telemetry writes `x1..x10`. They were not updated.
- Scratch evidence (untracked, not shipped): `scratch/r7_index_recon.jl`,
  `r7_sizing_dump.jl`, `r7_tension_budget.jl`, `r7_feasibility.jl`,
  `r7_window_fos.jl` (the wind-up trace), `r7_dlf_calibration.jl` (superseded —
  uses the old `dlf=` kwarg).

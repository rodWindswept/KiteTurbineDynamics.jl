# Validation Report: S2 Fold Flight — the folded seed flown through the launch-gate and wobble-gate instruments
**Date:** 2026-10-05
**Author:** `@hermes`
**Git tree:** `93a3844` (tip of `s2-fold-seed`, the frozen fold tip)
**Target:** The S2-class fold seed (`S2_FOLD_SEED`, `scripts/compute_seeds.jl`), `seed_genome(5.0)`, at the 5 kW rung.

---

## 1. Executive Summary

**Fold-flight verdict: FLIES — with one instrument red that is not the fold's.**

The folded seed flies through both flight instruments on the fold tip, in an
independent worktree (`~/Documents/GitHub/ktd-hermes-foldflight`, detached at
`93a3844`, depot symlinked, no shared-tree writes):

- **Launch-gate flight (`scripts/smoke_masslift_v13.jl`) — reproduced
  bit-for-bit:** `status=ok`, `P_mean 5.36 kW`, `P_end 5.37 kW`, `FoS 5.41`,
  `m_airborne 23.14 kg`. The one red line is the lift reference:
  `T_in 394.3 N` vs `T_exp 362.4 N` → **rel 8.81%** (tolerance 5%).
  `SMOKE: FAILURES — do not launch` hangs on that item alone, exactly as
  `@aero-validator` measured.
- **Trajectory flight (wobble-gate protocol, `scratch/hf_probe_foldflight_wobble.jl`)**: *(numbers landed below — see §2)*.

**Attribution of the lift-reference red.** The fold edit touches no `src/`
(7 files: seeds, tests, bounds_audit, docs) and the same machine reproduces
identically on both trees, so the red is machine/check-level, not
fold-introduced. It reads **8.81%** on the fold and **58.60%** on the
un-folded `a82cafd` tree (`@aero-validator` pair, `av_s2fold_smoke.log` /
`av_prefold_smoke.log`): the fold *narrows* the mismatch from 58.6% to 8.81%
while moving the seed from `status=reject` (3.92 kW, below floor) to
`status=ok`. Last recorded green is August-era (0.00% rel); no smoke run sits
on record between then and 2026-10-05, so the epoch of introduction is
unattributable. The realised tension reads 1.088× the reference — the lifter
fixed-point sizing (m → T → m_lifter → m) is the natural first look; triage is
with `@aero-worker`.

**What the launch gate may claim.** Merge mechanics are unchanged (pure FF,
no `src/` delta). What changes is the gate's claim: `SMOKE: ALL PASS` cannot
be claimed for any launch until the lift-reference line is fixed or
re-baselined with recorded evidence. Flight-worthiness of the fold seed
itself (status, power, FoS, slack, stability) is what this record attests.

---

## 2. Flight Numbers

### 2.1 Launch-gate flight (smoke)

| line | reading |
|---|---|
| L | 18.8 m |
| status | `ok` |
| P_mean / P_end | 5.36 / **5.37 kW** |
| FoS | **5.41** |
| T_in (realised) | **394.3 N** |
| T_exp (1.5·m·g/sin70°) | **362.4 N** |
| rel | **8.81%** → FAIL (tol 5%) |
| m_airborne | 23.14 kg |
| verdict | `SMOKE: FAILURES — do not launch` (lift-reference item only) |

### 2.2 Trajectory flight (wobble gate, ld=0.05, dt 1.0, 120 s relax + 120 s window, breaks ON)

Machine: 9 rings, n_lines=3, 83 nodes, dt_use 2.444e-5 s, 4 909 916 steps per phase, captured 239 samples.

| line | min | max | p2p | mean |
|---|---|---|---|---|
| hub_lat (m) | 0.8028 | 0.8309 | 0.0281 | 0.8236 |
| bear_lat (m) | 1.1057 | 1.1444 | 0.0386 | 1.1344 |
| T_cyan (N) | 205.06 | 206.66 | 1.60 | 206.24 |
| T_back (N) | 223.32 | 225.62 | 2.31 | 223.91 |
| T_bridle (N) | 229.09 | 230.29 | 1.20 | 229.97 |
| T_topbay (N) | 887.91 | 889.13 | 1.22 | 888.80 |
| P_gen (kW) | 5.3705 | 5.3709 | 0.0004 | 5.3708 |
| omega_gnd (rad/s) | 13.4319 | 13.4322 | 0.0004 | 13.4321 |

- **FoS:** trough **5.0595**, mean 5.3836 → FOS GATE pass (≥2.5 at trough).
- **Slack:** SLACK GATE pass — no gated line (TRPT, bridle, cyan, lift) ever
  below threshold; back line 223.3 N minimum, context only.
- **Breaks:** none (`broken=no`).
- **Stationarity:** hub_lat p2p first-half 0.0238 m, second-half **0.0042 m** —
  no limit cycle, no drift; the excursion asymptotes at ≈0.83 m during the
  relax and holds.
- P_gen window mean 5.3708 kW reproduces the smoke's P_end 5.37 kW
  bit-for-bit.

### 2.3 Trajectory flight, ld=0.00 leg (instrument-independence check, same protocol)

Same machine, same horizon, `lin_damp=0.0`:

| line | min | max | p2p | mean |
|---|---|---|---|---|
| hub_lat (m) | 0.8284 | 0.8284 | **0.0000** | 0.8284 |
| bear_lat (m) | 1.1409 | 1.1410 | 0.0000 | 1.1410 |
| T_cyan (N) | 206.35 | 206.37 | 0.019 | 206.36 |
| T_back (N) | 223.67 | 223.67 | 0.004 | 223.67 |
| T_bridle (N) | 230.00 | 230.03 | 0.036 | 230.02 |
| T_topbay (N) | 890.73 | 890.75 | 0.024 | 890.74 |
| P_gen (kW) | 5.3685 | 5.3686 | 0.0000 | 5.3686 |
| omega_gnd (rad/s) | 13.4303 | 13.4303 | 0.0000 | 13.4303 |

- **FoS:** trough **6.9904**, mean 7.7190 → pass. **Slack:** pass (back line
  223.7 N context only). **Breaks:** none.
- **Stationarity:** p2p 0.0000 on every channel — the folded seed holds its
  operating point with NO artificial damping; it does not lean on `lin_damp`.
- **Damper-dependence note:** the ld=0.05 leg reads FoS trough 5.06 / mean
  5.38 against ld=0.00's 6.99 / 7.72 — the two legs converge to slightly
  different equilibria (hub_lat 0.8236 vs 0.8284 m; T_topbay 888.8 vs
  890.7 N) and ring FoS is sensitive to that. Both legs pass the 2.5 gate by
  >2×; the instrument-dependence of the FoS trough reading is the standing
  `lin_damp` question already on the trust log — this pair adds the fold
  seed's readings to it, it does not reopen the gate.

---

## 3. Logs and Reproduction Scripts

- Flight probe: `scratch/hf_probe_foldflight_wobble.jl` — copy of
  `scratch/probe_wobble_gate_run.jl` with ONE change: the Nr sanity floor
  drops 10 → 5. The parent's `@assert Nr >= 10` dates from the 13-ring seed
  era; the folded seed builds a **9-ring** machine (`n_lines=3`), so the
  parent aborts before flight (`hf_foldflight_wobble_ld0.05.log` first
  attempt, `AssertionError: Nr >= 10`). The floor is a sanity check, not an
  instrument requirement — the slack tracker and every index are generic
  over Nr (sibling convention: the island3/winner probes keep `Nr >= 5`
  "as sanity"). All measurement logic is byte-identical to the parent.
- Smoke log: `.julia_depot/logs/hf_foldflight_smoke.log`
- Flight logs: `.julia_depot/logs/hf_foldflight_wobble_ld0.05.log`
  (first attempt aborted by the parent guard), re-run log same name after
  the probe copy; CSV `.julia_depot/logs/hf_foldflight_ld0.05.csv`
- Pre-fold contrast (measured by `@aero-validator`): `av_prefold_smoke.log`
  (`a82cafd`: `status=reject`, P_end 3.92 kW, rel 58.60%),
  `av_s2fold_smoke.log` (`93a3844`: `status=ok`, P_end 5.37 kW, FoS 5.41,
  rel 8.81%).

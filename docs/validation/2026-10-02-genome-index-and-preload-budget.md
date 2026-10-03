# Genome-index clamps, the preload "5.15x", and where the stale pair really lives

**Date:** 2026-10-02 · **Author:** software-validator
**Revision under test:** `deb8c39` on `bank-derate-cos2p65` (working tree: 3 modified
scratch probes + `scripts/combine_islands_v13.jl`; the rest is untracked evidence dirs)

## 1. The fix as first applied is only half right: the index depends on genome LENGTH

`canonical_v10` (`src/objective_v10.jl:142-149`) branches on length, not on a flag:

| genome length | layout | n_lines | rotor count |
|---|---|---|---|
| `>= 14` | legacy 14-D (`x[1..4]` = the four removed beam genes, then the 10) | `x[8]` | `x[10]` |
| `== 10` | canonical 10-D | `x[4]` | `x[6]` |

The campaign's own record files are **not all the same length**: the pre-derate winner
(`…_rotorcount/best_vector.csv`) is **14 fields**; the bank-derate winner
(`…_rotorcount_bankderate/best_vector.csv`) is **10 fields**. So the unconditional
canonical clamp (`x[4]`/`x[6]`) is correct for one winner and wrong for the other.

Measured — `scratch/sv_probe_decode_guard.jl` (10 s, decode only, no settle):

| CSV | clamp style | decoded `n_lines` | decoded `r_bottom` |
|---|---|---|---|
| pre-derate, 14-field | A canonical `x[4]/x[6]` (**as applied**) | 3 | **1.0000 m** ← wrong |
| pre-derate, 14-field | B legacy `x[8]/x[10]` (pre-fix) | 3 | 0.8627 m ✔ |
| pre-derate, 14-field | C length-aware | 3 | 0.8627 m ✔ |
| bank-derate, 10-field | A canonical (`as applied`) | 3 | 0.7969 m ✔ |
| bank-derate, 10-field | B legacy (pre-fix) | 3 | 0.7969 m ✔ |
| bank-derate, 10-field | C length-aware | 3 | 0.7969 m ✔ |

Why style A damages the 14-field path: it writes `x[4]` (legacy `Do_scale_exp`, one of the
four beam genes R7 removed — inert) and `x[6]` (legacy `x[6]` = canonical `x[2]` =
**`r_bottom`**), silently taking the pre-derate winner's ground ring from 0.863 m to 1.0 m.
`n_lines` survives only by luck (`round(clamp(0.9836,3,16)) == 3 ==` the legacy value).

Of the three probes Aero Validator fixed, `probe_wobble_gate_run_winner.jl` and
`probe_wobble_gate_run_winner_nop30k.jl` **default to the 14-field CSV**, so the applied fix
broke their default path. Correct form (now in `scratch/sv_probe_escalation.jl`):

```julia
if length(xr) >= 14
    xr[8]  = Float64(round(Int, clamp(xr[8],  3, 16)))   # legacy n_lines
    xr[10] = Float64(round(Int, clamp(xr[10], 1,  3)))   # legacy rotor mask/count
else
    xr[4]  = Float64(round(Int, clamp(xr[4],  3, 16)))   # canonical n_lines
    xr[6]  = Float64(round(Int, clamp(xr[6],  1,  3)))   # canonical rotor count
end
```
Verified both paths after the change: 14-field → `bank_top 19.9469 bank_bottom 6.6904`,
ω_eq 10.862435, F_top 1807.026 N; 10-field → `bank_top 10.7399 bank_bottom 7.1830`,
ω_eq 11.969522, F_top 1702.071 N.

## 2. On THIS winner the two mis-read genes are inert

`bank_bottom` / `blade_scale_bottom` are read **only** by the gradient at
`objective_v10.jl:338-339`, with `t = n_active > 1 ? (i-1)/(n_active-1) : 0.0`. The winner
has `n_active = 1`, so `t = 0` and the single rotor takes the **top** values. Decoded:
bank 10.7399°, blade scale 0.6994. The clamped genes (`x[8]`, `x[10]`) are never used.

Consequences:
- The decode bug changed **nothing** about the machine the campaign scored; the queued
  full-length re-check would have tested the same winner despite the wrong indices.
- The "four walls" reading is **three**: `n_lines` at its floor (3), rotor count at its
  floor (1), ring spacing at its ceiling (2.10). The fourth — "bottom blade scale at its
  cap 1.0" — is a collapsed-gradient artefact, not a binding constraint. The *operative*
  blade scale is `blade_scale_top = 0.6994`, mid-range in `[0.005, 2.0]`: an interior
  optimum, not a wall.
- The real impact of the bug is on the **14-field path** (r_bottom, above) and on any
  future winner with more than one rotor.

## 2b. The single-rotor reading is conditional on the decode MODE, and `x[6]` is not 1.0 (2026-10-02)

Rod asked whether a single-rotor machine is being double-counted. `scratch/sv_probe_rotor_count.jl`
(real decoder + builder, `scripts/ktd-julia`) answers it:

| path | `n_active` | `length(dec.rotors)` | built | rotor rings |
|---|---|---|---|---|
| bank-derate winner, `rotor_count_mode=true` (campaign) | **1** | **1** | 1 main rotor + **0 expansion rotors** | ring 10 of `n_rings` 10 |
| bank-derate winner, `rotor_count_mode=false` (decoder default) | 2 | 2 | 1 main + 1 expansion | ring 10 (bank 10.74°, wf 0.9473) + ring 7 (bank 7.18°) |
| pre-derate winner, `rotor_count_mode=true` | 1 | 1 | 1 main + 0 expansion | ring 6 of `n_rings` 6 |

So there is no double-count **on the campaign path**: the only rotor sits on the top ring, the
hub-exclusion rule (`builders_util.jl:91`) leaves the expansion list empty, and the annulus is
charged once by the disc model (`ring_forces.jl:223`) with `cos(10.7399°)^2.65 = 0.954249`.

**The hazard is the mode, not the gene.** The winner's canonical `x[6]` is **1.267**, not `1.0`.
`rotor_count_mode=true` (`run_v13_5kw_masslift.jl:170`) rounds it to a count of 1; the
**default** of `design_from_vector_v10` is `false`, which sends the same value to
`decode_rotor_mask` → `VALID_ROTOR_MASKS[2]` = mask 9 → **two rotors**, on rings 10 and 7, with
`bank_bottom = 7.1830°` (the "dead" gene) live and `blocking_factor` applied to the top rotor.
That is exactly the two-rotor machine §2 says the winner is not — and it materialises whenever a
script decodes this CSV without the mode flag. Two in the §5 list do: `scripts/preflight_winner.jl:22,25`
and `scripts/report/grounded_economics_v13.jl:66-68` (the latter's docstring claims "exactly as the
gate does" while omitting all four campaign knobs: `rotor_count_mode`, `cylinder_cone`,
`power_split`, `blocking_factor`). Neither currently points at the bank-derate winner, so the
exposure is latent; the §5 table flags only their index, not the missing mode.

**Correction to the chat framing:** the bank-derate winner is on **ring 10 of 10**
(`n_rings = 10` for the campaign decode at L=18.8), not "ring 6 of 6" — 6 of 6 is the
*pre-derate* winner. Both are `n_active = 1`; only the ring count differs.

## 2c. Single-authority `decode_winner` — guard test landed, and the `grounded_economics_v13.jl` inputs are the wrong era (2026-10-02)

**Guard test landed.** `test/test_winner_decode_invariant.jl` (wired into `test/runtests.jl`;
static, no ODE window, 1.5 s) asserts, for both winners through `decode_winner` (the single
authority added by software-worker in `scripts/ode_gate_v13.jl:100`): `n_active == 1`,
`length(dec.rotors) == 1`, the rotor is on the top ring, the operative bank equals `bank_top`,
`wind_factor == 1.0`, and — after `build_system_from_v10` — `length(sys.expansion_rotors) == 0`.
Measured: **18/18 pass 1.5 s**; full unit suite **2424/2424, 2 m 55 s, exit 0**.
Negative control `scratch/sv_probe_guard_has_teeth.jl` (expect exit 1): the same CSV decoded
WITHOUT `rotor_count_mode` gives `n_active = 2`, `rings = [6, 3]`,
`banks = [10.74, 7.183]` — so the invariant is breakable and the guard has teeth.
Per the agreed framing the default-path disagreement is a comment, not an assertion.

**Open — the `grounded_economics_v13.jl` fix points at the wrong era.** Its `WINNERS` are
`v13_5kw_len18.0 / 21.2 / 25.0`, produced by `scripts/run_v13_5kw.jl`, which **does not set
`rotor_count_mode`** (grep clean) — the bitmask era. Its `best_vector.csv` files carry
`x[10] = 4.2579 / 8.9838 / 0.0`, i.e. values outside the count bound `{1,2,3}`, which a
count-mode DE could not emit. Measured (`scratch/sv_probe_len_winners_decode.jl`):

| CSV | `x[10]` | bitmask decode (era) | `decode_winner` (now used) |
|---|---|---|---|
| `v13_5kw_len18.0/best_vector.csv` | 4.2579 | **2** rotors (mask 65) | **3** rotors |
| `v13_5kw_len21.2/best_vector.csv` | 8.9838 | **2** rotors (mask 257) | **3** rotors |
| `v13_5kw_len25.0/best_vector.csv` | 0.0000 | 1 rotor (mask 1) | 1 rotor |

So the change moved two of its three inputs from 2 rotors to 3; it did not fix a
"1 → 3" error. The pre-fix path gave **2, not 1**, for `len18.0`. Independently: the pre-fix
build also omitted `cylinder_cone`, so it never reproduced the campaign machine's ring count
either (`island_1_best`: 10 rings vs 15 via `decode_winner`). Whether the economics report
should model those legacy winners with the era's decode, or be re-pointed at the
masslift/`rotorcount` winners that `decode_winner` actually models, is a call for the runner's
owner — either way, a report that silently re-counts rotors needs to say which era it models.

## 3. The "5.15x" preload spread is a category difference, not a defect

`scratch/sv_probe_preload_budget.jl` (25 s), bank-derate winner, ω_eq 11.969522 rad/s,
τ_eq 320.9236 N·m, r_hub 3.8347 m:

| term (`initialization.jl:1341`) | value |
|---|---|
| `T_thrust` (main-rotor disc) | **+1562.296 N** (91.8 % of `T_top`) |
| `n_lines · T_bridle · cos θ` | +154.932 N |
| `−W_rotor · sin β` | −15.156 N (β = 0.523599 rad = 30°) |
| sum = `d.T_top` | **+1702.071 N** (delta 0.000e+00) |

- `F_top` = 1702.071 N is the **TRPT shaft tension**, 92 % of it the rotor's own thrust.
  Cross-check: implied `MTR = τ_eq / (r_hub · T_top) = 0.049169`, against the documented
  TRPT value of ~0.05 (CLAUDE.md / TRPTSim).
- The 330.368 N "declared regime" figure is `1.5·m_air·g/sin70°` — the **lifter's lift
  force** (m_air = 21.097 kg), a different line doing a different job. `T_cyan` (the actual
  lift-line tension) is 156.404 N, `T_back` 230.397 N.
- Therefore a gate of the form "F_top must be close to F_regime" would be comparing a
  thrust-loaded shaft to a weight-support requirement. Not added. If a second test is
  wanted, the meaningful one is the implied-MTR band — and that needs an owner ruling on
  the band, not a number invented here.

Also: `elevation_angle` is **radians** (`src/parameters.jl:41,131`; π/6 = 30°), despite the
"degrees at the API boundary" convention. A first pass of the budget print used `sind(β)`
and was off by 14.9 N on the rotor-weight term; the table above uses `sin(β)`.

## 4. Step-4 verification of the escalation answer

`scratch/sv_probe_escalation.jl`, length-aware, both winners: **repair did NOT fire**,
ratio exactly `1.000000` (`F_ax[end]` = 1702.071 N bank-derate; 1807.026 N pre-derate).
Independently reproduces Aero Validator's result. Note the probe compares "loop skipped"
(margin 1.0) with "loop executed" (default margin), so the verdict is about the *outcome*,
which is the question that matters.

## 4b. The settle parks at its scan ceiling, so `omega_eq` is bank-invariant (2026-10-02)

`settle_to_operational_state` walks DOWN from
`omega_scan_top = min(omega_rated_max, lambda_peak * v_mag / rotor.radius)`
and breaks on the FIRST `w` with `P_aero - P_par > P_gen`
(`initialization.jl:2249-2258`). Measured, `scratch/sv_probe_settle_scan_ceiling.jl`:

| genome | `omega_scan_top` | first-test surplus | `omega_eq` returned by the settle |
|---|---|---|---|
| pre-derate winner, bank 19.9469° | **10.862435** | +2.815 kW | 10.862435 |
| pre-derate winner, bank 0° | **10.862435** | +3.828 kW | 10.862435 |
| bank-derate winner, bank 10.7399° | **11.969522** | +1.863 kW | 11.969522 |
| bank-derate winner, bank 0° | **11.969522** | +2.136 kW | 11.969522 |

λ_peak = 5.2 (`BEM_TSR[argmax(BEM_CP)]`), v_mag = 10.99993 m/s. The ceiling and the returned
`omega_eq` agree to six decimals, and the ceiling contains no bank term and no `k_mppt`.
So for both winners the scan's first test passes and the 200-point walk never runs.

Consequences:
- `omega_eq`, `tau_eq = k·omega_eq²`, the design preload and the state the ODE window starts
  from are **bank-invariant**. The derate does sit in `settle_aero_power`
  (`initialization.jl:1037`) — it just never decides anything here.
- A *settle* sweep therefore cannot answer "does keeping bank buy shaft-realisability
  headroom" — both arms start from the identical `omega_eq` and `tau_eq`. That question is
  only answerable from the ODE window, which is what the wobble-gate probe reads.
- The comment on the duplicated derate ("This MUST match the ODE disc branch ... or the
  settle scan and the ODE find different equilibria") keeps the expression correct but its
  stated mechanism is moot for these genomes; do not go looking for a bank effect in the
  settle, and do not "fix" it there.
- At a FIXED ω the derate is exactly multiplicative: measured aero-power ratio
  6.6987/5.6858 = **1.1781** against 1/0.848790 = **1.178148**. So `4.888 / derate = 5.76 kW`
  is exact as fixed-ω bookkeeping — but it is not the machine's operating power at a lower
  bank, which is set by the ODE's own equilibrium. The "shave to 18.5° clears the floor"
  figure stays an estimate, not a re-solve.

## 4c. Bank's footprint in `src/` — four copies of one exponent

`grep` of every consumer of `sys.rotor.bank_angle_deg` (excluding comments):

| site | what it does |
|---|---|
| `ring_forces.jl:223` | ODE disc branch — the authoritative power charge |
| `initialization.jl:1037` | `settle_aero_power` — the settle scan (moot, see 4b) |
| `sim_frame.jl:159` | torque-balance frame (`P_aero` → `tau_aero`) |
| `sim_frame.jl:481` | per-rotor power dial |
| `objective_evaluator.jl:508` → `567`, `initialization.jl:295-305` | threads the value into the `RotorSpec` field only — no second charge |

The bank-sensitive span projection `BEM.annulus_span_for_power` (s = s_proj/cos(bank),
`bem.jl:195`) is called **only** from `test/test_bem_unified.jl`, never on the campaign path,
and the decoder's own span (`objective_v10.jl:369`) has no bank term — so blade mass is
bank-free for campaign machines. Aero Validator's "bank appears in exactly two places" holds
for the force model; the real hazard is that the single constant `cosd(bank)^2.65` is written
four times, two of them in telemetry instruments, with only
`test_settle_drag_alignment.jl` (currently red, pending re-point) watching the pair.


## 5. Stale-pair census (same pattern, `x[8]`/`x[10]` clamps)

Aero Validator's four files are all in `scratch/`. Same two-line pattern also sits in these
non-scratch v13-path files — each needs the length-aware form, and the legacy 14-D scripts
(`run_v10_campaign.jl`, `run_v12_5kw_v3.jl`, `run_v6_campaign.jl`,
`test/test_builders_v10.jl`, `sensitivity_sweeps.jl`, `run_anchor_batch.jl`,
`test/test_multi_rotor.jl`) are correctly written and must be left alone:

| file | line(s) | note |
|---|---|---|
| `scripts/ode_gate_v13.jl` | 97-98 | the ODE gate used to gate winners |
| `scripts/preflight_winner.jl` | 21 | uses the result as `n_lines` → feeds BEM sizing |
| `scripts/report/grounded_economics_v13.jl` | 66 | economics report |
| `scripts/smoke_masslift_v13.jl` | 62-63 | |
| `scripts/preview_genome_geometry.jl` | 117 | |
| `scripts/interactive_dashboard.jl` | 238, 375 | |
| `test/test_gate_v13.jl` | 67-68 | reads a winner CSV at 42 |
| `test/test_evaluator_v13.jl` | 66-67 | already clamps `x[4]` at 69 — `x[8]` still stale |
| `test/test_rope_break.jl` | 57-58 | acceptance suite |
| `test/test_settle_drag_alignment.jl` | 63-64 | acceptance suite |
| `test/test_mass_model_2026_09.jl` | 34 | |

`scratch/` carries ~60 more instances; they are one-shot diagnostics and rank lower, but any
of them pointed at the bank-derate winner will mis-decode the same way.

## 6. Score vs airborne mass — SUPERSEDED BY §8

`fitness = fitness_fn(P_score, FoS_min, cfg, m_airborne)` (`objective_evaluator.jl:1094`), so
the score is a kg-equivalent. Winner: fitness 21.698 against `m_airborne` 21.097 kg **as
measured by a plain `build_system_from_v10`** — but §8 shows that build is on the retired
beam-taper path, and the mass inside the score is 20.2135 kg. The 10.94 kg figure for the
pre-derate shape below is from the same plain build and is **not** comparable to the
campaign's score; on the evaluated mass model the pre-derate shape is 16.23 kg against the
winner's 14.45 kg. Do not use this section's numbers; see §8.


## 7. Which objective the campaign actually scored (2026-10-02)

`run_v13_5kw_masslift.jl:265` calls
`(P, F, c, m) -> appropriate_mass_fitness(P, F, c, m)`. The file's own comment at
:147-150 says the score is "true physics mass" and names `mass_min_fitness` — a different
function (`objective_v12.jl:89-97`) that returns bare `mass`. Verified constants:

| item | value | site |
|---|---|---|
| `p_floor_kw` / `p_ceiling_kw` | **5.0 / 5.0** | `run_v13_5kw_masslift.jl:153` |
| `penalize_ceiling` | `false`, read by exactly one function | `objective_v12.jl:44`, inside `v12_fitness` |
| over-power charge | `5.0 · max(P − 5.0, 0)²`, **unconditional** | `objective_v12.jl:153-154` |
| utilisation charge | `20.0 · (2.5/FoS)²` | `objective_v12.jl:165` |
| `W_OVERPOWER_KG_PER_KW2` | 5.0 | `objective_v12.jl:114` |

So the flag is inert on the campaign path and the effective objective is **"make exactly
5.0 kW at minimum mass"**, with no unpenalised headroom. One evaluator pass reproduces the
record exactly: fitness **21.6983** against the recorded **21.6980**, P_end 5.1145 kW,
FoS 9.3847 (`scratch/sv_probe_score_accounting.jl`).

Decomposition of that score: `21.6983 − 0.0655 (over-power at 5.1145 kW) − 1.4193
(utilisation at FoS 9.3847) = 20.2135 kg` — the mass the campaign scored.

Two consequences:
- The diagnostic scripts (`diag_daisy_seed_stall.jl:96`, `diag_gate_hunt.jl:64`,
  `diag_seg_twist.jl:66`, `diag_lowk_trace.jl:60`, `sweep_power_split.jl:79`) call
  `mass_min_fitness` **through `evaluate_windowed`**, so they still collect the twist penalty
  (see §9) and read `19.4508 + 0.7627 = 20.2135` where the campaign recorded `21.6983` —
  **1.4848 kg (6.8%) low**, exactly the two charges the seam skips. CORRECTION (2026-10-02):
  an earlier draft of this section quoted `21.0971` as what those scripts read and called the
  gap 1.48 kg; `21.0971` is the plain-build mass from a probe that never went through the
  evaluator, and 21.6983 − 21.0971 is 0.6012, so that sentence was internally inconsistent.
  The corrected pair is `20.2135` read / `1.4848 kg` short.
- `v12_fitness` on the same numbers returns **−5.1145**: with `penalize_ceiling=false` it
  subtracts an above-ceiling reward. Anyone re-pointing a script at `v12_fitness` while
  leaving the cfg alone gets a negative score.

## 8. The mass in the score is not the mass the tests and gates measure (2026-10-02)

`evaluate_windowed` builds with `beam_sizing = size_beams_closed_form(result, p, cfg)` and
`min_wall_m = cfg.min_wall_m` (`objective_evaluator.jl:679, 694`). A `build_system_from_v10`
call that supplies neither falls back to the legacy `Do_top·(r/r_hub)^Do_scale_exp` taper.
CORRECTION (2026-10-02, flag raised by hermes): an earlier draft of this section named "the
wobble probes and the gate scripts" as unsized by class. That is wrong — grepped per file,
`probe_wobble_gate_run_{winner,winner_nop30k,island3}.jl` and `scripts/ode_gate_v13.jl:124-127`
**do** pass `beam_sizing`. Measured on the same two genomes
(`scratch/sv_probe_mass_model.jl`), `expansion_airborne_mass` with `include_lifter=false`:

| genome | plain build | evaluator build (closed-form sizing) | solved `Do_per_ring` (m) |
|---|---|---|---|
| bank-derate winner (10-field) | 21.0971 kg | **14.4508 kg** | 0.0341, 0.0119 ×6, 0.0107, 0.0174, 0.0341 |
| pre-derate winner (14-field) | 10.9368 kg | **16.2289 kg** | 0.0414, 0.0142 ×4, 0.0127, 0.0414 |

The plain build reports `ring_Do_per_ring = Float64[]` — i.e. it is on the retired taper
path. **The ranking flips between the two models**: on the plain build the pre-derate shape
is half the weight of the new winner (10.94 vs 21.10 kg); on the model the campaign actually
scored, the new winner is the *lighter* machine (14.45 vs 16.23 kg). The 10.94 kg figure
quoted in this room (and in the earlier report to Rod) comes from the legacy path and should
be withdrawn as a campaign-comparable number.

The pre-derate genome also shows `t_over_D` 0.02772 on the plain path against 0.05500 on the
evaluator path, so the thick/thin wall floor differs between the two as well.

**Open, not resolved:** the decomposed scored mass is 20.2135 kg, which matches neither
build (19.4508 with lifter / 14.4508 without). Residual **0.76 kg (3.9%)**. Most likely the
evaluator reads `expansion_airborne_mass(sys, pc)` on the *post-window* system
(`objective_evaluator.jl:1082`); this has not been tested, so the score's mass term is not
yet reproducible from outside the window.

**CLOSED 2026-10-02 (aero-validator):** the residual is the twist penalty added *after* the
fitness seam, not a mass discrepancy. The mass handed to the seam is `19.450762 kg`,
bit-identical to the evaluated build above — so read the "evaluator build" column as the
**with-lifter** figure (19.4508), which is the one that enters the score; the
`include_lifter=false` column (14.4508) is not the scored mass. Full reconciliation:
`19.450762 + 0.065534 + 1.419288 + 0.762703 = 21.698287`. See §9.

## 9. The twist penalty and the stationarity penalty are live at the evaluator (2026-10-02)

Independently verified in `src/objective_evaluator.jl`:

- `twist_ratio_max = Ref(0.0)` (:831), updated per window sample from
  `twist_collapse_check(uc, sys).max_ratio` (:845-846).
- After the fitness seam (:1094), **unconditionally and for every objective**:
  `if twist_ratio_max[] > 0.0; fitness += W_TWIST_KG * (tr/(1-tr))²; end` (:1132-1134).
  Same weight and form as the fitness's own `twist_ratio` keyword, which is why reading the
  seam alone makes the term look dead.
- Immediately above it, `fitness += STATIONARITY_LAMBDA * excess` (:1126-1127) — a **fifth
  term**, also applied to every objective and not part of either reconciliation quoted in the
  room. The closure to six decimals therefore also proves this term is zero for the winner
  (swing ≤ `STATIONARITY_SWING`); it is not zero for a swinging machine, and it is present
  whether or not the chosen fitness function knows about it.

**Hazard — do not "wire the twist ratio".** `appropriate_mass_fitness` carries its own
`twist_ratio` keyword with the identical weight and form (`objective_v12.jl:147, 158-162`),
and its docstring calls wiring it "a follow-on". Because the evaluator already charges the
window's own maximum, passing a ratio at the seam would charge the same penalty **twice**.
The safe fix is to delete the keyword (or make it `error` when non-zero), not to wire it.


**Sized vs unsized builders — grepped per file, not by class (2026-10-02).** For the nine
files in `test/acceptance_runtests.jl` (corrected after hermes read all nine end-to-end;
`test_settle_lowk_honest.jl` and `test_physics_path_ode.jl` have **no in-file builder** —
they evaluate through `run_at` → `evaluate_windowed` at :105 / :96 respectively):

| file | builder path | sized? |
|---|---|---|
| `test_jtheta_no_reversal.jl` | in-file | **yes** (`beam_sizing` passed) |
| `test_trpt_drag_torque_balance.jl` | `test/settle_case_builders.jl` | **yes** |
| `test_settle_lowk_honest.jl` | none in-file — `run_at` → `evaluate_windowed` | **yes** |
| `test_physics_path_ode.jl` | none in-file — `evaluate_windowed` | **yes** |
| `test_evaluator_v13.jl`, `test_gate_v13.jl` | the included `gate_design` path (`ode_gate_v13.jl:124-127`) | **yes** for that path |
| `test_evaluator_v13.jl` (B5 block), `test_gate_v13.jl` (A3 block) | in-file | no |
| `test_rope_break.jl` (`build_from`) | in-file | no |
| `test_settle_drag_alignment.jl` (`build_from_genome`) | in-file | no |
| `test_rotor_power_realism.jl` (P4 build) | in-file | no |

So **five** of the nine carry an unsized in-file builder (`rope_break`,
`rotor_power_realism`, `settle_drag_alignment`, plus one block each in `evaluator_v13` and
`gate_v13`), not six — an earlier draft of this table wrongly listed `settle_lowk_honest`.
Four are sized throughout or sized on the path that matters. Any expected value generated on
the evaluator path (cold / 40 s / tail5) matches the campaign record; one generated through
an unsized in-file builder will not, because the tube differs (26.0971 vs 19.4508 kg for the
same winner genome). hermes' end-to-end read of all nine found no assertion that reads a
mass term at all — every numeric expectation is a threshold or a band — so the split cannot
flip an existing assertion, only constrain new numbers.

## 11. The search box the campaign actually used (2026-10-02, software-validator)

`tight_bounds(seed, kw)` (`scripts/compute_seeds.jl:137-192`) is seed-derived, and the runner
uses it (`run_v13_5kw_masslift.jl:143`). For blade scale (i = 9, 10): `lo = max(0.05,
seed·0.2)`, `hi = 1.0` hard (`:166-169`, "too many weak-aero stalling turbines above 1.0").
Seed blade scale 0.7 ⇒ **box [0.14, 1.0]**.

Consequences:
- λ* = 0.6552 (aero-validator's bank-free floor-landing prediction) is **inside** the box, as
  are 0.68 / 0.69 / 0.699. Nothing in the bounds blocked the joint move; the search had 86%
  of the box below the seed and moved the gene by 0.0006 (0.7 in, 0.6994 out).
- n_lines box is **[3, 9]** (Rod 2026-09-02) — the winner sits exactly on the true floor of 3.
  Note `src/objective_v10.jl:444` caps n_lines at 16; that is the inherited v5 bound, not the
  box the campaign ran, so "n_lines at its ceiling" statements read against the wrong number.
- bank box is [0, 22]; the winner's 10.74° is mid-box, consistent with it being a trim value
  rather than a bound.

## 10. The post-seam residual is twist — stationarity measured at zero for all three winners (2026-10-02, aero-validator)

§8–9 closed island 3 only, and identified its 0.76 kg residual as the twist charge while
*asserting* the neighbouring post-seam term (stationarity) was zero. `ObjectiveResult`
returns everything needed to measure it instead: the penalty is
`STATIONARITY_LAMBDA(10.0) · max(0, swing − STATIONARITY_SWING(0.20))` with
`swing = P_range / P_mean` (`objective_evaluator.jl:1124-1126`), and `P_mean`, `P_range`,
`P_end`, `FoS_min` all come back on the result. Re-running the three winning genomes through
`evaluate_windowed` on the campaign's own cfg (`scratch/av_probe_score_closure.jl`,
`start_mode=:cold`, `lift_device=lift_for`, 4-arg `appropriate_mass_fitness` seam) gives a
five-term closure that is **exact to the last digit** on every island:

| island | fitness | mass | P_end (kW) | FoS | swing | stationarity | over-power | utilisation | twist | twist_ratio |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 29.317920 | 27.4105 | 5.1711 | 12.8810 | 0.0327 | 0.0000 | 0.1463 | 0.7534 | **1.0077** | 0.5010 |
| 2 | 29.685202 | 27.4650 | 5.1345 | 11.7982 | 0.0255 | 0.0000 | 0.0905 | 0.8980 | **1.2317** | 0.5260 |
| 3 | 21.698287 | 19.4508 | 5.1145 | 9.3847 | 0.0091 | 0.0000 | 0.0655 | 1.4193 | **0.7627** | 0.4662 |

mass + over-power + utilisation + stationarity + twist − fitness = +0.00e+00 for all three.
So the residual *is* the
twist charge, now proven for 1 and 2 as well as 3, and stationarity is not merely small — it
is exactly zero (swing 0.9–3.3 %, an order of magnitude under its 20 % deadband). All three
rows: `status=ok`, `drifted=false`, `stationary=true`, `twist_crossed=false`. The winners sit
at 47–53 % of the geometric crossing limit and none of them crosses it.

**Precision note on the winner pack.** `scratch/hermes_winner_pack.jl` rebuilds the two
flow-through charges from `telemetry.csv`, whose columns are `round(..., digits=2)` at write
time (`run_v13_5kw_masslift.jl:193-196`) — P_end 5.17/5.13/5.11 and FoS 12.88/11.80/9.38. The
window-exact values above differ in the third decimal, which moves 0.002–0.007 kg of
over-power into the twist residual: the pack prints twist 1.009/1.238/0.766 (ratios
0.50/0.53/0.47) against 1.008/1.232/0.763 (0.501/0.526/0.466) here. Immaterial to the story
(mass share is 89.6 % either way, twist 3.5–4.2 %), but the residual should be taken at
window precision if the twist ratio is going to be quoted, and the same caution applies to
any post-hoc decomposition built off the telemetry columns.

**Figures.** The drawn bands are faithful to the charged geometry: ring heights come from the
built `u0`, the hub annulus is drawn at `sys.rotor.radius` / `sys.rotor.blade_hub_radius` —
the same pair `main_rotor_swept_area` charges (`ring_forces.jl:29`) — and expansion annuli at
`r_ring + blade_tip_radius` / `r_ring + blade_hub_radius`. One asymmetry, latent not active
here: `expansion_annulus_area` projects both offsets by `cos(bank)` (`expansion_rotor.jl:198-203`)
while the pack draws them unprojected. For island 2 (banks 6.87° → 2.21° linearly interpolated
across rings, `objective_v10.jl:338`) that is ≤0.4 % on the mid rotor's radius — sub-pixel;
islands 1 (banks 0.09°/0.0°) and 3 (single banked hub rotor, no expansion rotors) are
unaffected. **Bank is not drawn at all**, so the cos^2.65 hub derate — the single largest
modelling assumption on the 10.74°-banked global winner — cannot be interrogated visually from
these figures. The captions do disclose it.

**`ObjectiveResult.twist_ratio` verified against the charge (2026-10-02, later).** With the new
field in place, the same probe re-run prints the logged ratio per winner and the charge it
implies: 0.500965 → 1.007746, 0.526030 → 1.231742, 0.466191 → 0.762703 — identical to the
residual-derived twist to machine precision (Δ 0, 6.7e-16, 3.3e-16). So the column the next
combine writes *is* the charged quantity, and the exact ratios are 0.5010 / 0.5260 / 0.4662
(the pack prints 0.501 / 0.527 / 0.467 — third decimal inside the CSV-rounding envelope). Two
gaps found in the patch, neither active on the winner path: `test/test_evaluator_v13.jl:124`
(`B3d`) asserts `0.0 <= r3.twist_ratio < 1.0`, which the constructor default 0.0 satisfies, so
the guard passes on the very failure mode it was written for — the lower bound must be strict
or the ratio compared against `twist_collapse_check(u, sys).max_ratio` on the same state; and
the seven post-window submits that call `rejected_eval(ω_eq)` (`objective_evaluator.jl:926,
933, 943, 974, 979, 1046, 1050`) take the 0.0 default even though `twist_ratio_max[]` is live
from :851, so a twisted machine rejected on FoS/Betz/drift logs the same number as one measured
at zero twist. Independent suite check: 2424/2424 in 2 m 57.5 s.

## 12. The sizing's silent ω fallback — verified at source (2026-10-02, software-validator)

aero-validator's jagged λ-vs-ring-mass table traces to one line and one substitution.

**The fallback.** `src/trpt_optimization.jl:325`:
`ω_num = (ω_solved === nothing || !isfinite(ω_solved)) ? 0.0 : ω_solved`. A failed or
non-finite `solve_equilibrium_self_consistent` becomes `0.0` with no error, no warning and no
status field on the returned sizing. The failure is absorbed by a value that looks legitimate.

**The repo has already ruled on this exact pattern.** `src/initialization.jl:1313-1321`
documents the same fallback being removed from the preload path — `omega_eq > 0.0 ? omega_eq :
12.983466`, which computed "every design's preload … at a foreign design's speed" — with
measurements from 2026-09-13 and the closing instruction **"Do not reintroduce a fallback
here."** The ruling was applied to the preload consumer and never to the sizing function that
produces the number.

**Why a failure lands on the heaviest load case.** `:343-344`: at the substituted
`ω_num = 0`, `λ_op` is forced to 0 and `ct_op` takes `OPT_CT_RATED = 0.55` (`:40`) — the
maximum thrust coefficient — where the force model at the same state gives
`ct_at_tsr(0.0) = 0.0` (stated explicitly at `initialization.jl:1316`). The sizing therefore
prices a non-rotating or unsolved shaft as the *maximum-thrust* case. That is the mechanism
behind the 18.29 kg ring mass at λ = 0.695.

Two honest qualifications:
- The sign is not guaranteed by construction: the same substituted zero also kills the
  centrifugal term (`∝ ω²`), which pulls ring mass the other way, and both `ω_i = (i == 1 ||
  i == n_rings_tot) ? 0.0 : ω_num` (`:405`) and the FoS call (`:492`) inherit it. Empirically
  the thrust term dominates — 18.29 kg against 10.3–13.3 kg elsewhere — but that direction is
  a property of the numbers, not of the code.
- It cannot invent a light winner (it removes the centrifugal relief that would make one), so
  it does not threaten the recorded winner. It can only wall off a region — which is what it
  did between λ 0.685 and 0.70.

**A second consumer, opposite sign.** `initialization.jl:1615`, inside the realisability
repair: `τ_eq = sys.k_mppt_ref[] * omega_eq^2`. At the fallback that is a placement at zero
torque. One failed number becomes "heaviest rings" in the sizing and "no torque" in placement.

**Auditability.** `omega_eq` is a field of the sizing result (`trpt_optimization.jl:237`) and
`ObjectiveResult` carries its own `ω_eq` (`objective_evaluator.jl:234`), but the island records
store scalars, so **how often this fired across the 930 candidates cannot be recovered from the
existing record** — it needs a sizing-only re-run (no settle, no ODE) over the recorded
genomes. Confirm first whether `r.ω_eq` is the sizing value or the window's measured speed
before counting on it.

**Fix shape.** Per the existing ruling: make the unsolved case `error`, or return `nothing`
and force the caller to decide, and carry a status flag on the sizing result. Do not
substitute a value.

## 13. A 2-rotor decode lands on rings 10 and 7 because the gap mask is still live on the default path (2026-10-02, software-validator)

Rod's question: on a 2-rotor machine over 10 rings the pair should be rings 9+10, not 10+7 —
and wasn't the gap mask retired? Measured (`scratch/sv_probe_ring_pair.jl`, decode only):

| fact | measured |
|---|---|
| `_generate_valid_rotor_masks(10, 2)` size — `N_VALID_MASKS` | **19**, not the 60 its own comment and the file header claim |
| 2-rotor masks in the table | **7**: masks 9, 17, 33, 65, 129, 257, 513 |
| is mask 3 (`0b…0011`, the adjacent top pair) in the table? | **no** — rejected by `i - prev_one <= min_gap` |
| smallest 2nd-rotor offset in any 2-rotor mask | **3 bit positions** (= 2 bare rings) |
| count path, `x[6] = 2`, `positions_raw = [1,2]`, `ring_idx = n_rings - p + 1` | rings **10 and 9** (top two) |
| bitmask path, `x[6] = 1.267` (the winner) | `VALID_ROTOR_MASKS[2]` = mask 9 → rings **10 and 7** |
| bitmask path, `x[6] = 2.0` | `VALID_ROTOR_MASKS[3]` = mask 17 → rings **10 and 6** |
| winner genome, `x[6]` forced to 2.0, `rotor_count_mode=true` | `n_rings` **6** (the harvest-cylinder length `(n_rotors-1)·target_Lr·r_hub` grows), rotors on rings **6 and 5**, `spacing_ok = true`, 1 main + 1 expansion rotor |
| same, `rotor_count_mode=false` | `n_rings` **10**, mask 17, rings **10 and 6** |

So the gap mask **is still in use** — it is reached from `decode_rotor_mask`
(`objective_v10.jl:71-81`), called only when `rotor_count_mode=false` (the function default at
`:225` and the `ObjectiveConfig` default at `objective_evaluator.jl:143`). On that path the pair
Rod expects is **structurally unreachable**: the min-gap rule (`:37-60`) evicts every adjacent
mask, so a 2-rotor machine can only ever be top-ring + ≥3 rings down. The rings 9+10 machine is
the *count* machine (`positions_raw = collect(1:n_rotors)`, `:242`), which replaced the mask and
drops the ring gap in favour of the `spacing_ok` check (`:322-327`) — measured `true` here.
Note the 10/7 pair is not the mask "choosing" a gap for a 2-rotor design: the winner's proxy
1.267 rounds to mask **index 1**, and the sorted table's second entry happens to be the
minimum-gap 2-rotor mask.

Two staleness notes, neither active on the campaign path: `N_VALID_MASKS` is 19 against a
comment (and file header, `:4`) saying 60; and `decode_rotor_mask` clamps the index to
`0..N_VALID_MASKS-1`, so every proxy ≥ 18.5 saturates onto the same mask. Neither changes
§2b's conclusion — the winner's `x[6] = 1.267` is a *count* under the campaign's mode and
rounds to 1; rings 10+7 only exist for a call site that omits `rotor_count_mode`.

## Files

- `scratch/av_probe_score_closure.jl` — five-term score closure at window precision (§10)
- `scratch/sv_probe_decode_guard.jl` — the clamp-style comparison (no settle, ~10 s)
- `scratch/sv_probe_preload_budget.jl` — the T_top decomposition + implied MTR (~25 s)
- `scratch/sv_probe_ring_pair.jl` — mask table vs count-mode ring pairs, both decode modes (§13)
- `scratch/sv_probe_escalation.jl` — escalation verdict, now length-aware

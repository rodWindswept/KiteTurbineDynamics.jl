# Numbers Register — the single source of truth between the simulation and the audience

**Status:** v1 ROWS SIGNED (2026-10-08, science-validator). See the sign-off
block below. A row is usable for reporting only when a validator signs it.
Unsigned rows do not exist for reporting purposes. Writers and figure bots
cite ONLY signed rows, by row ID, in every public post and in every figure
spec.

**Row format:** `ID · claim · value · units · source (commit + file +
row-range or script) · derivation recipe (if derived) · validator signature
· date signed`. A number that changes is superseded by a dated new row —
never edited.

**Sources for v1:** the bankderate2 dataset at
`scripts/results/v13_5kw_masslift_len18.8_rotorcount_bankderate2/`, era
`post-95c385d_wind-authority`, data commit `dd3cc6a` on
`bankderate2-results`, launch commit `a76c5e9`. The Phase 0 signed audit
sits at master `31ca00d`. The 2026-10-08 probes are
`scripts/probe_rapid_vs_ode_winners.jl` (added `89926d8`, revised
`2c6f7d2`) and `scripts/probe_warm_reject_cause.jl` (added `2c6f7d2`).
Both sit on `bank-derate-cos2p65`.

## v1 rows (signed 2026-10-08, science-validator)

| ID | Claim | Value | Units | Source | Status |
|---|---|---|---|---|---|
| NR-001 | Campaign size | 930 (3 islands × 310) | evals | island_*/telemetry.csv | signed (science-validator, 2026-10-08) |
| NR-002 | Status mix | 508 ok / 301 reject / 110 clearance_reject / 11 reject_twist | designs | telemetry `status` column | signed (science-validator, 2026-10-08) |
| NR-003 | Island 1 best fitness | 30.578 (found gen 30) | kg-equivalent | island_1/convergence.csv | signed (science-validator, 2026-10-08) |
| NR-004 | Island 2 best fitness | 30.637 (found gen 30) | kg-equivalent | island_2/convergence.csv | signed (science-validator, 2026-10-08) |
| NR-005 | Island 3 best fitness | 27.364 (found gen 26) | kg-equivalent | island_3/convergence.csv | signed (science-validator, 2026-10-08) |
| NR-006 | All-island start point | 36.109 (gen 1, common seed) | kg-equivalent | convergence.csv | signed (science-validator, 2026-10-08) |
| NR-007 | P_mean range, ok rows | 5.02–6.32 | kW | telemetry, ok only | signed (science-validator, 2026-10-08) |
| NR-008 | Winner P_mean (island 3) | 5.309 / P_end 5.314 | kW | island_3 telemetry / re-eval (§4, Phase 0 audit) | signed (science-validator, 2026-10-08) |
| NR-009 | Winner FoS (island 3) | 14.972 | — | island_3 telemetry / re-eval (§4, Phase 0 audit) | signed (science-validator, 2026-10-08) |
| NR-010 | Winner T_lift (island 3) | 324.1 | N | island_3 telemetry / re-eval (§4, Phase 0 audit) | signed (science-validator, 2026-10-08) |
| NR-011 | Winner geometry (island 3) | n_lines 3, rings 6, n_active 1, r_hub 4.580 m, r_bot 0.804 m, bank_bot 22°, blade scales 0.821326/0.20 (quote 0.82/0.20) | — | decode of best_vector.csv | signed (science-validator, 2026-10-08) |
| NR-012 | Cold-path reproduction | :cold re-eval matches recorded P_mean, P_end, FoS, fitness, T_lift to 3 dp on all three winners | — | probe_rapid_vs_ode_winners.jl | signed (science-validator, 2026-10-08) |
| NR-013 | Rapid-path result on winners | :warm rejects all three winners — rope-break gate (broken=true), transient line over-strain during relax | — | probe_rapid_vs_ode_winners.jl + probe_warm_reject_cause.jl | signed (science-validator, 2026-10-08) |
| NR-014 | Winner window swing | P_range 0.029 on 5.309 kW (0.5%) | kW / % | re-eval (§4, Phase 0 audit) | signed (science-validator, 2026-10-08) |
| NR-015 | Operating point | k 2.24, relax 10 s + window 40 s, FoS gate 2.5/2.5, length 18.8 m | — | runner provenance | signed (science-validator, 2026-10-08) |
| NR-016 | Winner ω (ODE) | 10.170 | rad/s | re-eval (§4, Phase 0 audit) | signed (science-validator, 2026-10-08) |

## Validator sign-off: v1 rows signed (2026-10-08, science-validator)

This block signs all sixteen rows. Verification basis, by group:

- **NR-001 to NR-011, NR-014, NR-016:** transcription checked against the
  signed Phase 0 audit (master `31ca00d`) and the dataset records at data
  commit `dd3cc6a`. `convergence.csv` carries NR-003 to NR-006. The winner
  meta carries fitness. The second-read census and re-eval logs carry the
  remainder (`scratch/sv_p0_secondread_census.txt`,
  `scratch/sv_p0_secondread_winner_reeval.log`).

- **NR-012, NR-013:** reproduced on this seat at `cdef418`, where fitness
  matches the island metas digit for digit on all three winners. The src
  tree and the dataset tree are byte-identical from the data era to
  `cdef418`. Logs: `scratch/sv_regv1_probe_fidelity.log`,
  `scratch/sv_regv1_probe_warmcause.log`,
  `scratch/sv_regv1_precision.log`. The cold path reproduces every winner
  field at the precision the record stores. Island 3 matches the Phase 0
  record at full precision on every field. The warm path rejects all
  three at the rope-break gate (`broken=true`), after a clean build and
  settle.

- **NR-015:** checked against the runner config
  (`scripts/run_v13_5kw_masslift.jl`) and `PROVENANCE.md` at `dd3cc6a`.

Source-line precision fixes at sign-off (no value changed):

- The dataset line now names data commit `dd3cc6a`. Launch commit
  `a76c5e9` does not carry the dataset tree.

- The probe line now pins the probe commits and the branch.

- Winner-row sources (NR-008 to NR-010, NR-014, NR-016) now also name the
  section 4 re-eval of the Phase 0 audit. The telemetry column stores two
  decimals, and `P_range` and `ω_eq` are not record columns.

Precision notes (values unaffected):

- NR-012: "to 3 dp" reads as the probe display precision. The record
  stores P_mean, P_end, FoS and T_lift at two decimals, and fitness at
  three. The verified form: all fields agree at the stored precision.
  Island 3 agrees at full precision.

- NR-006: "gen 1" is the first convergence read. The seed batch reads as
  gen 0 in the telemetry column. The value is exact.

The supersede rule applies. Any later change lands as a dated new row.

## Known boundaries (must accompany any use — Track E)

- Blade integrity is not checked: `min_fos_blade_root` hard `Inf`, full
  beam-on-supports blade model deferred (PRD 0006:147).
- Flown blades carry tether-to-blade bridling that resists thrust/expansion
  more capably than the unbridled-blade model assumes; that bridling adds
  drag not included in the model.
- `start_mode=:warm` is the evaluator default; any consumer that does not
  pass `:cold` measures the instrument, not the machine.

## Aero counter-read: NR-007, NR-008, NR-009, NR-010, NR-011, NR-014, NR-016 (2026-10-08, aero-validator)

This block appends only, under the lead ruling and the amend pattern. The
ruling sits in `handovers/handover-2026-10-08-reporting-room-rulings.md`.
No signed row changed.

Basis: section 4 of the Phase 0 audit
(`docs/validation/2026-10-08-phase0-bankderate2-audit.md`) and the evidence
records below. The counter-read works from committed records only. It runs
no simulator and reads no telemetry.

Evidence: `scratch/sv_p0_winner_reeval.txt`,
`scratch/sv_p0_secondread_winner_reeval.log`,
`scratch/sv_regv1_probe_fidelity.log` and
`scratch/sv_p0_secondread_census.txt`. The arithmetic and gate checks sit
in `scratch/av_counterread_regv1.log`.

- NR-007. The census lists the ok-row power ranges as 5.020 to 6.260,
  5.050 to 6.090 and 5.020 to 6.320 kW. The union reads 5.02 to 6.32 kW.

- NR-008. The cold re-eval records P_mean 5.3087794439367935 and P_end
  5.314113662272673 kW. The row rounds these to 5.309 and 5.314 and
  draws from the re-eval, not the two-decimal telemetry columns.

- NR-009. The cold re-eval records FoS_min 14.971791422208508. The row
  rounds to 14.972.

- NR-010. The cold re-eval records T_lift 324.1250954336462 N. The row
  rounds to 324.1 N.

- NR-011 (decode). The re-eval reads n_lines 3, rings 6 and n_active 1,
  with r_hub 4.580 m and r_bot 0.804 m.

- NR-011 (gene slots). The layout in `src/objective_v10.jl` names slot 8
  bank_bottom and slots 9 and 10 the blade scales. The genome holds 22.0,
  0.8213 and 0.2000 there, and the row shows bank_bot 22 degrees and blade
  scales 0.82 and 0.20.

- NR-014. The cold re-eval records P_range 0.028659374428010587 kW and
  the row quotes 0.029 kW. The ratio to the mean is 0.54 percent. The row
  shows 0.5 percent at one decimal place.

- NR-016. The cold re-eval records omega_eq 10.169820334285198 rad/s, and
  the row quotes 10.170 rad/s. The row takes the ODE path. The rapid path
  carries reject values only, so no rapid value appears in a row.

Verdict: no discrepancy found. The seven rows stand as signed. Full
precision lives in the records cited above.

## Rotor-bank note: NR-011 (2026-10-08, science-validator)

This block appends only, under the lead ruling and the amend pattern. No
signed row changed.

The NR-011 row quotes bank_bot 22°. That value is a genome gene, not a
rotor angle.

Slot 8 holds it. The layout names slot 8 bank_bottom.

The decode threads a bank gradient across the active rotors. The top
rotor takes slot 7, bank_top. The lowest rotor takes slot 8 only when
two or more rotors are active.

The island 3 machine carries one rotor, on the topmost ring. The gradient
collapses to its top value there. So the rotor bank reads 7.088°.
No rotor on this machine carries 22°.

A caption that quotes the main rotor bank uses 7.09°, or 7.088° at three
decimals. The 22° gene drives no drawn blade and no force on this
machine.

Reproduction: probe scratch/sv_probe_rotor_banks.jl, log
scratch/sv_probe_rotor_banks.log, at tip bb619a5.

The probe mirrors the winner-pack chain, discrete-gene rounding then
`design_from_vector_v10` with the campaign knobs, then
`build_system_from_v10`.

Island 3 readings: slot 7 = 7.088°, slot 8 = 22°. The decoded rotor bank
reads 7.088°, at ring 6.

The built rotor bank reads 7.088°. Islands 1 and 2 behave the same way.
Their single rotors carry their slot 7 values, 2.954° and 10.258°.

All three built machines hold zero expansion rotors.

The register keeps NR-011 as signed. This note supplies the threading
fact for caption use.

## Polygon-count rounding note: NR-011 (2026-10-18, science-validator)

This block appends only, under the amend pattern. No signed row changed.

The B-20 candidate the author wrote states that the decoder rounds x4, the polygon side count, to an integer. The source carries that rounding at `design_from_vector_v4`, `src/ring_spacing.jl:475`.

- The rounding. The line reads `n_lines = clamp(Int(round(x[8])), 3, 16)`.

- The layouts. The 14-D layout names x[8] n_lines. The canonical 10-D layout names the same gene x[4].

- The winner. The island-3 decode reads n_lines 3. The value sits inside the clamp and reads as an integer.

- The ring count builds separately. The spacing pass lays the intermediate rings from the length-to-radius target and the density profile. The builder adds the ground ring and the hub ring at the ends. The winner reads six rings, which NR-011 already carries. This note binds the rounding only.

Reading rules:

- The polygon count reads as an integer gene, clamped 3 to 16 at the decode.

- The rounded polygon count does not set the ring count. The spacing pass sets the ring count.

Evidence: source read at the tree tip, `src/ring_spacing.jl:466-483` and `:256-274`, plus the canonical layout comment at `src/objective_v10.jl:19-20`.

## Caption rows: NR-017, NR-018 (2026-10-08, science-validator)

These rows exist for caption binding under F-VALUE. NR-017 binds the hero
blade tag bank annotation. NR-018 binds the score decomposition mass.
This block appends only, under the amend pattern. No signed row changed.

| ID | Claim | Value | Units | Source | Status |
|---|---|---|---|---|---|
| NR-017 | Winner main-rotor bank (island 3) | 7.088° at ring 6. Slot 8 = 22° reaches no rotor at n_active 1 | deg | decode probe d219b6c. Threading src/objective_v10.jl:339 | signed (science-validator, 2026-10-08) |
| NR-018 | Winner airborne mass (island 3) | 25.70 | kg | audit §4 + probe 0c4046b | signed (science-validator, 2026-10-08) |

Sign-off basis:

- NR-017 reproduced on this seat at `1c6f0b2`, log
  `scratch/sv_probe_rotor_banks_1c6f0b2.log`. Decode and built rotor
  agree at 7.088131460323565° on the topmost ring, decode ring 6.

- NR-018 reproduced on this seat from the committed probe (added
  `0c4046b`), log `scratch/sv_mass_recon_1c6f0b2.log`. The reading
  equals the stored value at full precision (the log prints
  25.6984682562368789).

- The off-basis counter-value 25.670101 kg documents the old failure
  mode. The pack rebuild at `9de9222` reads the same value.

## Bank-derate rows: NR-019, NR-020 (2026-10-08, aero-validator)

This block appends only, under the amend pattern. No signed row changed.

The rows carry the measured bank derate. They give the exponent in use
for main-rotor power, and the measured retention.

Sources: `docs/validation/trpt-reference/10-precone-sweep.md` (method,
tables and caveats) and `10-precone-sweep.csv` (84 cases). The sweep ran
on 2026-09-30. The CSV header carries the tool sha256.

The rows cover the topmost (main) rotor only. Numbers and sites
re-checked on this seat at `e9a2f99`.

| ID | Claim | Value | Units | Source | Status |
|---|---|---|---|---|---|
| NR-019 | Bank-derate exponent in use (main-rotor disc power) | 2.65 (power × `cosd(bank)^2.65`, the same exponent the elevation factor uses) | — | one authority `BEM.projection_factor` (`src/bem.jl`, landed `b835ebc`, record `779fa55`). Application sites `src/ring_forces.jl:234-235`, `src/initialization.jl:1033-1037`, `src/sim_frame.jl:158-159, 480-481` (`94223eb`, Rod ruling 2026-10-01). Guard `test/test_ring_forces.jl` "main-rotor bank derate" | signed (aero-validator, 2026-10-08) |
| NR-020 | Measured bank retention at the Cp peak | 0.854 at 20°. `cos^2.65` predicts 0.848 (a match to 0.7 per cent). `cos^3` predicts 0.830 | — | `10-precone-sweep.md` sections 3 to 5. The precone rows of `10-precone-sweep.csv` at commanded lambda 4.0 (Cp 0.22540 vs 0.26386) | signed (aero-validator, 2026-10-08) |

Sign-off basis:

- NR-020 ratios. The values recompute from the recorded Cp columns at
  commanded lambda 4.0, the measured peak. The set reads 0.984, 0.954,
  0.911, 0.854 and 0.784 at 5°, 10°, 15°, 20° and 25°.

- NR-020 fit. The 20° loss reads 14.6 per cent. The sweep quotes it as
  about 15 per cent. The fitted exponent band runs 2.5 to 3.0, with
  2.65 mid-band.

- NR-019. The exponent holds one authority (`projection_factor`).
  The disc-power sites sit above. The recorded completeness check is
  `grep -rn "2\.65" src/`.

- NR-019 threading and ruling. The fast hub-power chain and the sizing
  family carry the same factor since `b835ebc`. Applied 2026-10-01 on
  a ruling by Rod
  (`handovers/handover-2026-10-01-bank-derate-and-5kw-rebaseline.md`).

Boundaries that travel with these rows (quote them with the values):

1. Power only. Thrust carries no measured derate. Never copy the
   exponent onto Ct.

2. Main rotor only. The expansion rotors still use a linear
   `cos(bank)`. Extending 2.65 to them is an open question for Rod
   (`docs/agents/physics-topology.md`, section 4.0.1).

3. Not constant off the peak. A 20° bank retains 0.331 at commanded
   lambda 6.0. The campaign design point sits inside the flat region.

4. A ratio transfer. The retention comes from the measurement rotor
   (Daisy MVP, coned blade, uniform chord). The absolute Cp belongs to
   that rotor, not to the campaign winner.

## Science counter-read: NR-019, NR-020 (2026-10-08, science-validator)

This block appends only, under the lead ruling and the amend pattern. The
ruling sits in `handovers/handover-2026-10-08-reporting-room-rulings.md`.
No signed row changed.

Basis: the bank-derate block at `ba5bbd8`. The rows sit in `a36b7df` and
the STE pass in `631d719`. The counter-read works from committed records.
It runs no simulator and reads no telemetry.

Evidence: `scratch/sv_counterread_bankderate.log` and
`scratch/sv_counterread_ring_forces.log`.

- NR-019 value. The exponent reads 2.65 at every listed site. The
  definition sits in `src/bem.jl:149` and matches the site form.

- NR-019 completeness. The `2.65` grep over `src/` reads 19 lines. The
  authority holds 2, the listed sites 8, comments 5 and other numbers 4.

- NR-019 bounds. The thrust path charges `cos(elev)^2.0` and no bank
  term. The expansion rotors charge a linear `cos(bank)`. Both hold as
  written.

- NR-019 lineage. `b835ebc`, `779fa55` and `94223eb` all sit in the tip
  ancestry. No source commit landed between `e9a2f99` and `ba5bbd8`.

- NR-019 guard. The named testset ran green on this seat. It reads 5 of
  5 checks. The file total reads 10 of 10.

- NR-020 ratios. The five ratios recompute from the committed CSV at
  commanded lambda 4.0. They read 0.98416, 0.95437, 0.91101, 0.85424 and
  0.78432. They round to the recorded set.

- NR-020 fit. `cos^2.65` at 20° reads 0.84797 and `cos^3` reads 0.82977.
  The loss reads 14.58 per cent. The lambda 6.0 bound reads 0.33082.

- STE tokens. The pass at `631d719` holds. The number tokens match
  `a36b7df` one for one, apart from two new bullet labels.

Verdict: no discrepancy found. The two rows stand as signed.

## Mechanism-pair source rows and ODE rows: NR-021 to NR-026 (2026-10-08, aero-validator)

This block appends only, under the amend pattern. No signed row changed.

Rows NR-021 to NR-023 are the source rows of the mechanism pair
(`ring-utilisation`, `twist-limit`). They carry the declared capture: the
winner operating point, the final frame of the measurement window. The
extract sits at `docs/reporting/figures/pair-extract/`. The extract run
reproduced the recorded cold re-eval at full precision — nine of nine
fields exact, including power, FoS, lift tension and twist ratio.

Rows NR-024 to NR-026 serve §2.3 and §3.3. They carry the step law, the
cold-start protocol and the lift margin. They are ready if the final text
prints those values.

| ID | Claim | Value | Units | Source | Status |
|---|---|---|---|---|---|
| NR-021 | Ring check at the winner operating point (island 3): interaction, shares and FoS per checked ring | R2 0.03324, FoS 30.087. R3 0.03355, FoS 29.807. R4 0.02838, FoS 35.236. R5 3.058e-6, FoS 326974. R6 hub 0.06652, FoS 15.033 | — | Extract `docs/reporting/figures/pair-extract/extract-winner-operating-point.csv`, ring block. Emitted by `capture_extended`; `max_util` re-derived via `ring_element_analysis`; A1 identity checked, residual 0.0 at every ring | signed (aero-validator, 2026-10-08) |
| NR-022 | Segment twist and over-twist limit at the winner operating point | \|Δα\|: S1 33.95°, S2 33.81°, S3 33.68°, S4 33.55°, S5 22.82°. δ_crit: S1 to S4 98.86°, S5 92.64°. has_limit true on all five | deg | Extract, segment block. Raw reads from the stored alpha block; `trpt_twist_limit` on the rope_forces C1 call pattern (node radii, mean line rest length) | signed (aero-validator, 2026-10-08) |
| NR-023 | Segment torque pair at the winner operating point | segment_torque: S1 396.8, S2 397.2, S3 397.5, S4 397.7, S5 397.2. torque_capacity: S1 805.0, S2 808.7, S3 812.2, S4 815.7, S5 1069.9 | N·m | Extract, segment block. Capacity = `trpt_torque_capacity_axial` at `trpt_axial_force` of the same state. One instant for both series | signed (aero-validator, 2026-10-08) |
| NR-024 | Evaluator step law | dt = min(4e-5 s, 4e-5 s × sqrt(L_min / 0.5 m) / 1.5). Winner derived step 2.899e-5 s | s | Source read at `f8114be`: `src/initialization.jl:564-595`. Winner value from the extract log | signed (aero-validator, 2026-10-08) |
| NR-025 | Cold-start protocol (campaign setting) | Settle `settle_to_operational_state` (n_op 150000 steps, about 6 s simulated; ω_rated_max 60.0 rad/s), then kickstart off (kickstart_s 0.0; the legacy kick is -60.0 N·m·s²/rad², about 115 times the MPPT torque), then one combined relax+window run, 10 s + 40 s, rope breaks enabled across both. Winner run: 1724859 steps | s, steps | `src/objective_evaluator.jl:774, 840-842, 856-892, 978-989`; `src/initialization.jl:2184-2190`; `scripts/run_v13_5kw_masslift.jl:157` | signed (aero-validator, 2026-10-08) |
| NR-026 | Lifter sizing margin (campaign regime) | margin 1.5 (vertical force at the lift bearing = 1.5 × m_airborne × g); line tension = F_vert / sin(70°), flat at all wind speeds; m_airborne excludes the lifter's own 5 kg (the kite carries itself) | — | `src/lift_kite.jl:197-228`; regime line `scripts/run_v13_5kw_masslift.jl:111` | signed (aero-validator, 2026-10-08) |

## Display amend 2026-10-18 (aero-validator)

The reader-facing register prints each reading at four significant
digits. A reading that a shipped plate already labels keeps the
shipped label form. The ring FoS values, the S5 capacity and the
torque pair print the plate forms.

The manifest file `docs/reporting/register-manifest.md` carries the
full-precision readings. It also carries the axial and bending shares
of NR-021.

The NR-022 notation moves from `abs(dalpha)` to |Δα| and from
`dcrit` to `δ_crit`.

No value changes. Each row keeps its 2026-10-08 sign-off basis. The
2026-10-18 feedback in `docs/reporting/feedback-on-report.md` prompts
this change.

Sign-off basis:

- NR-021 to NR-023. One run, one declared capture. The run is
  `evaluate_windowed :cold` on the island 3 genome of the signed dataset.
  The capture is the final integration step: s = 1724859,
  t = 49.99999483862295 s. The log carries the parity certificate: nine
  of nine recorded fields reproduce at full precision. The two segment
  series are instant-bound to the same capture. The principal emitted
  twist equals the raw read on this capture (no saturation).

- NR-021 ring stations for the row order: 0.0, 2.3182841987165674,
  4.636939712683201, 6.9559610374822345, 9.27534680414777,
  18.600867750952748 m (R1 to R6, cumulative ring-centre separation).

- NR-024. The law replaces the old line-count heuristic (`n_lines ≥ 8 →
  1e-5`). The ceiling calibrates to the stiffest sub-segment mode
  (omega_max about 2e4 rad/s on 0.5 m Dyneema sub-segments;
  build-geometry audit, 2026-08-24).

- NR-025. The winner step count reads from the same extract log. At the
  campaign damping (lin_damp 0.05) the settle reaches the productive
  branch directly, so the kickstart stays off.

- NR-026. The margin closes on signed rows at full precision:
  1.5 × (25.69846825623688 - 5.0) × 9.81 / sin(70°) =
  324.1250954336462 N = NR-010. NR-018 minus the flat 5 kg lifter
  booking is the sizing mass.

Boundaries that travel with these rows:

1. Instant versus window. NR-021 to NR-023 carry one instant. The window
   minimum FoS (14.971791422208508, NR-009) is another instant; the
   capture hub ring reads 15.032534020684876. Quote the capture by name
   with the value.

2. Case A only. All five segments of this capture carry a limit. The
   no-limit (Case B) class does not occur in the winner capture. A
   no-limit illustration needs another capture.

3. Capacity basis. `torque_capacity` is the Tulloch authority quantity.
   The held conservative cap that `rope_forces.jl` applies to Case-B
   segments is a different quantity and does not substitute.

4. NR-025 records the run as executed. The 2026-09-16 window-only breaks
   ruling remains an open item (§4.1 of the draft).

Counter-read requested from science-validator.

## Science counter-read: NR-021 to NR-026 (2026-10-09, science-validator)

This block appends only, under the lead ruling and the amend pattern. No
signed row changed.

Basis: the mechanism-pair block at `a443e26`. The counter-read works from
committed records. It runs no simulator and reads no telemetry. The
computing commit `f8114be` sits in the tip ancestry, and `src/` stays
identical from there to the tip. The csv header names the same commit.

Evidence: `scratch/sv_counterread_pairrows.log` and
`scratch/sv_counterread_pairrows.py`.

- NR-021. Every ring line cross-reads from the extract at full precision.
  The A1 identity reads exact at every ring. The shares sum to `max_util`
  bit for bit, and the ring FoS reads as the inverse of `max_util`. The
  station list matches the record.

- NR-022. The five `abs_dalpha` and five `dcrit` values cross-read. The
  emitted twist equals the raw read at every segment. The `dcrit` values
  recompute bit-exact from the stored geometry. One precision note sits
  below.

- NR-023. The five torque values cross-read. The five capacity values
  recompute bit-exact from the logged `T_sum`, `L_ax` and `l_t`. All five
  segments sit in Case A. Both series bind to the same capture.

- NR-024. The winner step recomputes from the stored chord at full
  precision. The shortest sub-segment is the ground chord over four. The
  law returns `2.8987873697672758e-5` s exactly. The step count reads
  `round(50 / dt) = 1724859`. The final clock accumulates to
  `49.99999483862295` s bit for bit.

- NR-025. The listed source lines read as the row states. The settle call
  passes `60.0` as `ω_rated_max`. The settle loop runs its `n_op` steps at
  the adaptive step. The `~115x` comparison reads in the code comment and
  the instrument trust log. One precision note sits below.

- NR-026. The margin identity closes bit-exact on NR-018 and NR-010:
  `1.5 x (25.69846825623688 - 5.0) x 9.81 / sin(70 deg) = 324.1250954336462` N.

Precision notes. Two wording amends sit below for the aero seat.

1. NR-022 group. The row groups S1 to S4 at `98.85908296054023` deg. The
   extract stores S4 at `98.85908296054016` deg, on a tether length that
   differs in the last place (`2.363334810503142` m). For full digits,
   read S1 to S3 at the group value and S4 at its own value.

2. NR-025 horizon. The row quotes the settle at about 6 s simulated. That
   figure is the nominal at a `4e-5` s step. The winner runs at an
   adaptive step of `2.8987873697672758e-5` s, so its 150000 steps span
   `4.348` s simulated. Suggested wording: `n_op` 150000 steps, about
   4.35 s simulated.

Verdict: no material discrepancy found. The six rows stand as signed, with
the two precision notes above.

## Aero wording amends: NR-022, NR-025 (2026-10-09, aero-validator)

This block appends only, under the lead ruling and the amend pattern. No
signed row changed.

The two precision notes in the science counter-read block (`570be73`)
become the reading and wording rules below. This seat checked both notes
from the committed records.

The extract
`docs/reporting/figures/pair-extract/extract-winner-operating-point.csv`
stores S1 to S3 at `98.85908296054023` deg and S4 at
`98.85908296054016` deg.

The settle span computes as
`150000 x 2.8987873697672758e-5 = 4.348181054650913` s.

- NR-022 full-digit reading. A full-digit quote reads S1 to S3 at the
  group value `98.85908296054023` deg and S4 at its own value
  `98.85908296054016` deg. Drawn precision does not change.

- NR-025 wording. The settle phrase reads "`n_op` `150000` steps, about
  `4.35 s` simulated". The 6 s figure is the nominal at the `4e-5` s
  step. It does not describe the winner run.

The rows keep their signed values. Future quotes use the forms above.

## Length-screen rows: NR-027, NR-028 (2026-10-10, science-validator)

This block appends only, under the amend pattern. No signed row changed.

Both rows answer the review's section 1.5 sub-question. The variant
dirs and the screen runner enter tracking with this block:
`scripts/results/length_variants_island3`,
`scripts/results/length_variants_island3-cpfix` and
`scripts/run_length_variants.jl`.

| ID | Claim | Value | Units | Source | Status |
|---|---|---|---|---|---|
| NR-027 | 10-05 length screen on the pre-fold island-3 genome (both rounds, arrow = round 1 to round 2) | P_mean 18.8 m: 3.7955 → 4.2332; 21.2 m: 3.8645 → 4.3055; 25.0 m: 3.9747 → 4.4122. All six rows FAIL (P<5.0) | kW | `scripts/results/length_variants_island3/variants.csv` (`f225e95`, 2026-10-05T10:10Z); `scripts/results/length_variants_island3-cpfix/variants.csv` (`a82cafd`, 2026-10-05T11:25Z) | signed (science-validator, 2026-10-10) |
| NR-028 | 18.8 m fold comparison at the cpfix era | pre-fold genome 4.2332 (fail), folded class P_end 5.3691 (ok) | kW | Pre-fold: NR-027 round 2. Folded: `scripts/compute_seeds.jl:50-56`; `docs/validation/2026-10-05-s2-fold-flight.md` | signed (science-validator, 2026-10-10) |

Sign-off basis:

- NR-027. This seat read both variant dirs. The `genome_used.csv` file in
  each dir is byte-equal to
  `scripts/results/v13_5kw_masslift_len18.8_rotorcount_bankderate/best_vector.csv`
  (r_hub 3.8347, blade_scale_top 0.6994). The six readings cross-read
  from the `variants.csv` rows. The chunk traces agree at the final
  chunk.

- NR-028. The fold pins r_hub 3.8347 → 4.32 and blade_scale_top
  0.6994 → 1.0 (`S2_FOLD_SEED`, landed `bd5114e`; the fold sits in the
  launch ancestry of `a76c5e9`). The folded reading sits in the fold
  flight record and in the seed provenance. The comparison runs at one
  length and one evaluator basis. The era side sits in
  `docs/validation/2026-10-03-landing-tip-red.md:37`.

Boundaries that travel with these rows:

1. The screen describes the pre-fold design under the post-D1 evaluator.
   It is not evidence about the launched machine. Both the machine (the
   fold) and the eras (the D1 span re-decode, the launch-only physics)
   separate the screen rows from the launch.

2. NR-028 bounds the comparison to 18.8 m. The screen holds no post-fold
   readings at 21.2 m or 25.0 m.

## Operating-point rows: NR-029 to NR-031 (2026-10-11, science-validator)

This block appends only, under the amend pattern. No signed row changed.

These rows answer the section 1.1 request (the window-mean ground-ring
speed as the operating speed) and the section 2.1 table requests (Cp,
tip-speed ratio, window-mean omega). The aero-validator seat proposed
them at `b665e6e`. This seat signs them after an independent re-run.

| ID | Claim | Value | Units | Source | Status |
|---|---|---|---|---|---|
| NR-029 | Winner operating speed, window-mean ground ring | 13.38 (quote 13.38, 127.772 rpm) | rad/s | `scripts/probe_window_trace.jl` (`b665e6e`), parity against the recorded cold re-eval (NR-012) | signed (science-validator, 2026-10-11) |
| NR-030 | Winner delivered torque, window-mean basis | 396.8 (quote 396.76) | N·m | P_mean (NR-008) divided by NR-029. Cross-reads: S1 panel 396.8 (0.0075 % above), S5 hub 397.2 | signed (science-validator, 2026-10-11) |
| NR-031 | Winner operating coefficients: tip-speed ratio, rotor Cp, system coefficient | lambda_gnd 5.566 (quote 5.566, hub value 5.566 agrees inside 1.1e-4), Cp 0.2944 (quote 0.2944), system coeff 0.1016 (quote 0.1016) | - | lambda from NR-029, r_ring 4.580 m, v_ref 11.01 m/s. Cp at lambda 5.566 from the measured n = 3 surface (`src/aerodynamics.jl:263`, anchor `a82cafd`). Coeff from NR-008 divided by 0.5 rho A v^3, A 63.9 m², rho 1.225 | signed (science-validator, 2026-10-11) |

Sign-off basis:

- Re-run. This seat ran `scripts/ktd-julia scripts/probe_window_trace.jl`
  cold. The four parity fields print |diff| = 0.0 against the recorded
  re-eval (target `scratch/sv_p0_winner_reeval.txt`, local): fitness,
  P_mean, P_end and omega_eq. The 52 samples reproduce. Every window
  statistic reproduces to the digit.
- Arithmetic. rpm = 13.380259861740395 x 60 / (2 pi) = 127.7721.
  tau = 5308.7794439367935 / 13.380259861740395 = 396.76205834512626.
  lambda_gnd = 5.565968202980965. Half rho A v cubed = 52.235879109513746
  kW. System coefficient 0.10163090072260127. Ceiling (16/27) x that x
  cos^3(30 deg) = 20.105599243489678 kW.
- Cross-reads. k w^2 = 401.0302328876505 N·m at the window mean (1.08 %
  above the delivered read). k w^3 = 5.365759517981763 kW at the hub
  window mean (1.07 % above NR-008). The bands travel with the rows.

Boundaries that travel with these rows:

1. One trace, one machine, one wind: 11.01 m/s at 9.41 m, cold start,
   k = 2.24.
2. The rotor read (Cp 0.2944) and the system coefficient (0.1016) are
   different coefficients. The draft must not conflate them.
3. The warm and cold omega(t) plus line-strain request stays with the
   aero-worker seat.
4. The offered sentence of the review stands with the measured numbers.
   The run seeds at 10.17 rad/s (NR-016). The machine reaches 13.38 rad/s
   by the relax end.

## Operating-point re-base rows: NR-032 to NR-034 (2026-10-11, science-validator)

This block appends only, under the amend pattern. No signed row changed.

These rows re-base the operating point that NR-029 to NR-031 carry. The
tip radius carries the speed-ratio term. The wind-normal area carries
the ceiling. The aero-validator seat counter-read the tip and area basis
(`av_probe_tipref_counter.jl`, `av_probe_tipref_live.jl`). This seat
reproduced every value before signing.

Findings:

- The blade tips do not sit at the ring radius. The built main rotor
  carries r_out 5.629560432565964 m and r_in 4.130158464357515 m. The
  span reads 1.4994019682084492 m on the 70/30 split. The ring radius
  4.57997905482005 m is the blade attach point, not the tip.

- The code reads the speed ratio at the tip. `ring_forces.jl` computes
  lambda_t = omega x r_out / v. The built radius takes the label "TSR /
  tip-speed reference" (`objective_evaluator.jl`).

- The old coefficient basis carried the wrong area. The value 63.9 m²
  is pi (r_hub^2 - r_bot^2) = 63.86952678906739 m². No rotor sweeps
  that surface. The model swept area is 45.9732554921615 m².

- The ruled Betz basis is the wind-normal area. The ceiling applies
  cos^1 per projection (Rod 2026-10-02). The contract test
  `test_betz_ceiling_projection.jl` pins the form. The wind-normal
  area is 39.491173622830395 m².

| ID | Claim | Value | Units | Source | Status |
|---|---|---|---|---|---|
| NR-032 | Winner tip-speed ratio and rotor Cp, tip reference | lambda_tip 6.842 (quote 6.8415, hub value 6.841 agrees inside 5.5e-5), Cp 0.2258 (quote 0.2258) | - | lambda from the NR-029 window trace, r_out 5.630 m, v_ref 11.01 m/s. Cp at the hub-basis lambda from the measured n = 3 surface (`src/aerodynamics.jl:263`, anchor `a82cafd`). Receipts: `scratch/sv_probe_winner_areas.jl`, `scratch/av_probe_tipref_counter.jl` | signed (science-validator, 2026-10-11) |
| NR-033 | Winner swept-area set | A_raw 45.97 (quote 45.9733), A_bank 45.60, A_zn 39.49 (quote 39.4912), A_zy 39.81 (elevation-only cross-check), A_hub_bot 63.87 (retired basis) | m² | Built radii through `annulus_area` (`src/bem.jl`). A_zn is the ruled wind-normal basis (`objective_evaluator.jl`). Receipts: `scratch/sv_probe_winner_areas.jl`, `scratch/av_probe_tipref_counter.jl` | signed (science-validator, 2026-10-11) |
| NR-034 | Winner Betz ceiling and re-based coefficients | ceiling (16/27) x 0.5 rho A_zn v^3 = 19.13 kW (quote 19.1304), delivered share 0.2775 (quote 27.75 %), system coeff 0.1413 on A_raw and 0.1644 on A_zn | kW / - / - | v_ref 11.01 m/s, rho 1.225. The code gate charges the rounded 0.593 form: 19.14 kW. Arithmetic route: `scratch/sv_rebase_arithmetic.py` | signed (science-validator, 2026-10-11) |

Sign-off basis:

- Re-run. The counter probe rebuilt the winner through the evaluator
  chain. The parity held |diff| = 0.0 on fitness, P_mean, P_end and
  omega_eq against the recorded cold re-eval. The live tap repeated the
  hub power charge over the window (1 Hz, n = 40).

- Arithmetic. Every area and coefficient recomputes on an independent
  route. The chain closes at v = 11.01: 0.5 rho A_zn v^3 =
  32.282569190218894 kW, ceiling 19.130411371981566 kW, share
  0.27750471961685264.

- Cross-reads. The campaign score breakdown records A_axial 45.9733 m².
  The strip extract geometry agrees. The 63.86952678906739 m² value
  recomputes from r_hub and r_bot.

Boundaries that travel with these rows:

1. One trace, one machine, one wind: 11.01 m/s at 9.41 m, cold start,
   k = 2.24. The boundary holds for every row in this block.

2. The NR-031 values stand unchanged. Use them under the label ring
   speed ratio only. Ring speed ratio = the tangential speed of the hub
   ring over the wind: omega x r_ring / v.

3. NR-034 supersedes the ceiling line in the NR-029 to NR-031 block for
   use. That block keeps its arithmetic listing.

4. The old system coefficient (0.1016, NR-031) defers to the NR-034 pair
   for use.

5. Flown-basis edge note: the settled hub carries mean z 8.914 m and
   elevation 28.64 deg. The site profile reads 10.924 m/s there. The tip
   ratio reads 6.895 and Cp 0.2224 on that basis. Receipts:
   `scratch/av_probe_tipref_live.jl`. The note answers the Harris "wind
   at hub height" line.

6. Discriminator. The hub charge reads 5.6595093810122155 kW against the
   delivered 5.3087794439367935 kW, 6.6 % above. A ring-referenced
   reading would need a 28.3 % gap. The tip reference holds on live
   numbers.

## Derived rows: NR-035 and NR-036 (2026-10-11, science-validator)

This block appends only, under the amend pattern. No signed row changed.

The author seat asked for design-point specific power (Harris item
2.10). The figures seat asked for the running-best objective at the
seven strip milestones. Both rows derive from signed rows and the
certified strip extract.

| ID | Claim | Value | Units | Source | Status |
|---|---|---|---|---|---|
| NR-035 | Design-point specific power | 0.2066 (quote 0.2066) | kW/kg | NR-008 (P_mean entry) divided by NR-018. Recipe: 5.309 kW / 25.70 kg. On the mass net of the 5 kg lifter (20.70 kg) the read is 0.2565 | signed (science-validator, 2026-10-11) |
| NR-036 | Island 3 running-best search objective at the seven strip milestones | 36.109 (gen 0), 32.293 (gen 6), 31.661 (gen 10), 30.929 (gen 18), 29.854 (gen 22), 28.315 (gen 25), 27.364 (gen 26) | kg-equivalent | `docs/reporting/figures/machine-evolution-strip/extract-best-so-far.csv` (certified 2026-10-09). This seat re-checked all seven against `island_3/telemetry.csv`: each is an ok row and the least ok fitness of its window. Figure label: search objective | signed (science-validator, 2026-10-11) |

Sign-off basis:

- Both rows recompute from signed rows and the certified extract. The
  extract carries its parity certificate. The seven fitness values
  re-check against the raw telemetry rows.

- The milestone set: the aero-validator amendment [0, 6, 10, 18, 22, 25,
  26] gives seven distinct machines.

Boundaries that travel with these rows:

1. The search objective is not the mass. Penalty terms travel inside the
   value. The draft and the strip label it "search objective (kg)".

2. NR-035 uses the full airborne mass (NR-018). The net basis (5 kg
   lifter excluded) reads 0.2565 kW/kg.

## Figure-brief number check: NR-011, NR-017 (2026-10-12, science-validator)

This block appends only, under the amend pattern. No signed row changed.

The nine figure proposals quote winner values for the anatomy diagram and
the genome strip. This seat re-read each one at `42f2147` on the bank
line. Every value holds with no drift.

- Topology. The decode reads n_lines 3, rings 6, n_active 1 and one rotor.
  R1 sits at the ground datum and R6 is the hub ring. Ring labels run
  ground to hub.

- Segment labels. S1 to S5 are the five segments between rings. A figure
  label "S1" names a segment, never a spacer ring.

- Radii. The quotes 4.580 m and 0.804 m match the decode at
  4.5799790548200496 and 0.8036829846088207.

- Ring radii. The pair-extract segment block carries both values. It reads
  r_b 4.57997905482005 on S5 and 0.8036829846088207 on S1 to S4.

- Bank. The main rotor bank reads 7.0881314603235648 degrees at ring 6.
  Slot 8 holds 22.0 and reaches no rotor. A figure caption quotes 7.088
  degrees. The 22.0 value never appears as a rotor angle.

- Blade scales. The active rotor carries 0.8213255027884769. Slot 10
  holds 0.2 and reaches no rotor.

- Built radii for scale. The evaluator chain reads tip 5.629560432565964 m
  and blade inner edge 4.130158464357515 m. Both equal the NR-032 receipts.

- Knob note. The bank probe omits the decode v_rated knob. Its built-radius
  line reads 5.628174 m. Quote the evaluator chain for art.

- Era. No commit between `bb619a5` and `42f2147` touches `src/`. The
  readings transfer to the figure baseline.

Reproduction: probes `scratch/sv_probe_fignums.jl`,
`scratch/sv_probe_winner_areas.jl` and `scratch/sv_probe_rotor_banks.jl`.
Logs `scratch/sv_probe_fignums_42f2147.log`,
`scratch/sv_probe_winner_areas_42f2147.log` and
`scratch/sv_probe_rotor_banks_42f2147.log`, at tip `42f2147`.

## Derived lift-chain and trace-endpoint rows: NR-037, NR-038 (2026-10-12, science-validator)

This block appends only, under the amend pattern. No signed row changed.

The Figure 6 brief quotes a vertical lift margin of 1.21. No signed row
carried that number. The signed sizing margin reads 1.5 (NR-026). This
block supplies the derived numbers the inset draws on. It also fixes the
label rule. The Figure 3 brief quotes a speed lane of 8 to 12 rad/s. That
range clips the winner trace. NR-038 carries the true endpoints.

| ID | Claim | Value | Units | Source | Status |
|---|---|---|---|---|---|
| NR-037 | Winner lift-line derived set (island 3): vertical load at the lift bearing, sizing mass, airborne weight, load ratio | F_vert 304.6 (quote 304.6), sizing mass 20.70 (quote 20.70), weight 252.1 (quote 252.1), ratio 1.208 (quote 1.21) | N, kg, N, - | Derived on NR-018 and NR-026. Recipe below | signed (science-validator, 2026-10-12) |
| NR-038 | Winner window trace endpoints (island 3): ground ring at window min, max and last, plus the relax end pair | gnd window min 13.36, max 13.38, last 13.38. Last relax sample, t = 9.990 s: gnd 13.36, hub 13.38 | rad/s | `scripts/probe_window_trace.jl` (`b665e6e`). Logs `scratch/sv_probe_window_trace_rerun.log`, `.julia_depot/logs/av_probe_window_trace.log` | signed (science-validator, 2026-10-12) |

Derivation recipe, NR-037:

- Vertical load. F_vert = 1.5 x (25.69846825623688 - 5.0) x 9.81. The read
  is 304.5779603905257 N.
- Airborne weight. W = 25.69846825623688 x 9.81 = 252.1019735936838 N.
- Load ratio. F_vert / W = 1.2081538119230202. Quote 1.21 at two decimal
  places.
- Tension cross-check. F_vert / sin(70 deg) = 324.1250954336462 N. The
  read equals NR-010.

Label rule for Figure 6:

- The figure prints 1.5 as the margin. NR-026 carries that value.
- The ratio 1.21 reads as the vertical load over the total airborne
  weight. State the definition next to the number.
- Do not label 1.21 as a margin. The two bases differ. The margin 1.5
  applies to the mass net of the lifter. The ratio takes the full
  airborne mass as the denominator.

Boundaries that travel with these rows:

1. NR-037 regime: the campaign run. Tension stays flat at all wind speeds
   (`const_tension`, NR-026). The vertical load holds one value at every
   wind speed.
2. NR-038 basis: the NR-029 boundary row. One trace, one machine, one
   wind: 11.01 m/s at 9.41 m, cold start, k = 2.24. The window reads use
   the 41 samples from t = 10 s.

Receipts: `scratch/sv_nr037_arithmetic.py`, `scratch/sv_nr037_arithmetic.log`
and the two trace logs above.

Counter-read requested from the aero seat.

## Aero counter-read: NR-037, NR-038 (2026-10-12, aero-validator)

This block appends only, under the lead ruling and the amend pattern. No
signed row changed.

The receipts sit in `scratch/av_counter_nr037.py`, `scratch/av_counter_nr037.log`
and `scratch/av_counter_nr038_probe.log`.

- NR-037 recomputes bit-exact from NR-018 and NR-026.
  F_vert 304.5779603905257 N, weight 252.1019735936838 N,
  ratio 1.2081538119230202, tension 324.1250954336462 N.
  Every value matches the signed reads, and the tension equals NR-010.

- NR-037 authority. The code path `sized_lifter_for` carries the law.
  The sizing mass nets the flat 5 kg lifter, and the margin reads 1.5.
  The winner evaluation calls the function with `const_tension = true`.

- NR-038. The cold re-run reproduces the four parity fields exact.
  The trace carries 52 samples, and the window set reads 41 of 52.
  The ground ring min, max and last values reproduce at full precision.
  The relax end pair reproduces at t = 9.990119900356282 s.
  The window mean equals NR-029.

- Label rule. The Figure 6 rule stands as written.
  The figure prints 1.5 as the margin, and the ratio 1.21 prints
  with its definition beside it. The figure never labels 1.21 as a margin.

- Citation note. NR-038 cites `scratch/sv_probe_window_trace_rerun.log`.
  No file sits at that path in this checkout.
  The file sits at `.julia_depot/logs/sv_probe_window_trace_rerun.log`,
  and the two depot logs match byte for byte.
  Quote the depot path, or let this note stand as the amend.

Verdict: no material discrepancy. Both rows stand as signed.
The Figure 3 and Figure 6 builds may quote them.

## Reconciled fitness row: NR-039 (2026-10-12, science-validator)

This block appends only, under the amend pattern. No signed row changed.

This block answers item 4 of the full-feedback delta map
(`room-responses/hermes-2026-10-12-full-feedback-delta.md`).

Section 3.2 of the draft carries no sentence that ties the island-3
fitness (NR-005) to the winner airborne mass (NR-018). The two values
describe one machine. NR-005 is the search objective and NR-018 is the
physical airborne mass.

| ID | Claim | Value | Units | Source | Status |
|---|---|---|---|---|---|
| NR-039 | Island-3 fitness decomposition, NR-005 against NR-018 | fitness 27.36 = mass 25.70 + over-power 0.4933 + utilisation 0.5577 + twist 0.6141. Penalty total 1.665 (quote 1.665) | kg-equivalent | `island_3/convergence.csv` gen-26 row + `scratch/sv_p0_winner_reeval.txt` + evaluator chain at launch `a76c5e9` | signed (science-validator, 2026-10-12) |

Sign-off basis:

- Reproduction. This seat recomputed the chain from the stored fields in
  the same order as the evaluator.

- Closure. The recomputed fitness reads 0.0 against the recorded fitness.
  Receipt: `scratch/sv_nr039_fitness_recon.py` and its log.

- Mechanism. The objective reads the true physics mass plus three soft
  penalties.

- Chain sites. The evaluator lines read 1148, 1149, 1161, 1192 to 1194
  and 1200 to 1203 at launch `a76c5e9`.

- Seam and weights. The seam body sits at `src/objective_v12.jl` lines
  145 to 168. The weights sit at lines 114 to 116.

- Over-power charge. The term reads the tail-5 power 5.314113662272673 kW
  against the 5.0 kW ceiling.

- Utilisation and twist charges. The terms read the window FoS
  14.971791422208508 against the floor 2.5, and the twist ratio
  0.4393474253185575 against the crossing limit. The stationarity charge
  reads zero (window swing 0.54 per cent).

- Cross-read. The Phase 0 audit second read carries the same decomposition
  (2026-10-08). The term sum reads 1.665073010111922 against the direct gap
  1.6650730101119215, a rounding gap of 4.4e-16 kg.

Reading rule for section 3.2:

- NR-005 is the search objective, not a mass reading. NR-018 is the
  physical airborne mass of the same machine.

- The draft may read: Island 3 reaches 27.364 kilograms at generation 26
  (NR-005), the search objective. It reads the airborne mass 25.698
  kilograms (NR-018) plus 1.665 kilograms of objective penalties
  (NR-039).

- The strip label "search objective (kg)" (NR-036) stands.

Boundaries that travel with this row:

1. One machine, one capture: the island-3 winner at its recorded cold
   re-evaluation.

2. The decomposition binds to the recorded fitness. Other rows decompose
   on their own fields.

Counter-read requested from the aero seat.

## NR-039 note: the penalize_ceiling flag (2026-10-12, science-validator)

This block appends only, under the amend pattern. No signed row changed.

The aero counter-read (2026-10-12) closed NR-039. It asked for one
candor clause: a reader may connect the runner flag `penalize_ceiling =
false` to the fired over-power charge in the NR-039 decomposition. The
flag does not reach that charge. This seat checked both paths at the tip.

- `penalize_ceiling` governs only the legacy `v12_fitness` window
  penalty. Source: `src/objective_v12.jl:44` (the ceiling branch).
  The campaign runner pins the seam `appropriate_mass_fitness`
  (`scripts/run_v13_5kw_masslift.jl:266`), not that function.

- The fired over-power charge is unconditional. Source:
  `src/objective_v12.jl:153-154` (the excess and the penalty). The
  charge fires with the flag false.

The NR-039 decomposition stands unchanged.

## Derived row: NR-040, winner segment torque margins (2026-10-12, science-validator)

This block appends only, under the amend pattern. No signed row changed.

The author seat asked for the S1 torque margin. The abstract and
section 5 will quote the least margin with its failure mode (Harris
review, item 1.3, 2026-10-10). The row derives from NR-023: capacity
over demand, one instant, segment by segment.

| ID | Claim | Value | Units | Source | Status |
|---|---|---|---|---|---|
| NR-040 | Winner segment torque margin | S1 2.029, S2 2.036, S3 2.044, S4 2.051, S5 2.694. S1 governs (quote 2.03). The S1 to S4 band reads 2.029 to 2.051. | — | NR-023 strings, segment by segment: torque_capacity / segment_torque. Recipe: 805.0 / 396.8 = 2.029. Cross-read: `docs/reporting/figures/pair-extract/extract-winner-operating-point.csv`, segment block, bit for bit | signed (science-validator, 2026-10-12) |

Sign-off basis:

- The five ratios divide the torque capacity by the demand, segment by
  segment. Each input cross-reads the raw extract, bit for bit. S1 is
  the least.

- The Harris review (2026-10-10) reads the S1 to S4 band as 2.03 to
  2.05. This row confirms that band and adds S5 at 2.69.

Reading rule for the abstract and section 5:

- The draft may read: the least segment torque margin is 2.03, at S1
  (NR-040).

- Name the capture with the value. The capture is the winner operating
  point, the final integration step (the NR-021 to NR-023 capture).

Boundaries that travel with this row:

1. One instant, one capture. The ratio is capacity over demand at the
   final integration step. It is not the window minimum.

2. Not a gate result.
   The 2.5 floor is the structural factor-of-safety gate on ring utilisation.
   Whether a torque margin sits under that floor is a separate ruling (work division item 1.3).
   This row carries the ratio only.

3. Case A only. All five segments carry a limit on this capture. The
   capacity basis matches NR-023 boundary 3.

Evidence: `scratch/sv_nr040_torque_margin.py` and its log.

## Aero counter-read: NR-040 (2026-10-12, aero-validator)

This block appends only, under the lead ruling and the amend pattern. No
signed row changed.

The receipts sit in `scratch/av_counter_nr040.py` and its log.

- NR-040 recomputes bit-exact from the extract segment block. S1
  2.0287970973051634, S2 2.036175280501402, S3 2.0435436991749936,
  S4 2.0509817379918016, S5 2.6938375915900292. The five ratios ran
  from the CSV tokens with own arithmetic, not the receipt chain. The
  tokens match the NR-023 strings string-for-string. Extract at blob
  `ac1b8819`.

- Boundary 3 holds on the raw block. `has_limit` reads true on all five
  segments. The Case-A claim reads exact.

- The capture ties to NR-025. The capture line reads s = 1724859 steps,
  the row's winner run, at t = 49.99999483862295 s, the final frame.

- Quote forms. 2.03, 2.05 and 2.69 print as written. The S1 to S4 band
  reads 2.03 to 2.05.

Verdict: no material discrepancy. The row stands as signed. The abstract
and section 5 may quote the least margin 2.03 at S1.

## Derived row: NR-041, honest-window k sweep (2026-10-12, science-validator)

This block appends only, under the amend pattern. No signed row changed.

The row-5 plate (the k basis) draws the load sweep that picked the campaign k. The room asked for register rows on any printed sweep value (the 10-09 consultation). This row binds the ten recorded points to the committed file.

| NR-041 | Honest-window k sweep of the 5 kW seed (2026-08-22): window-mean power by load | P_mean at 2 dp: 3.49 reads reject. Then 5.45, 6.78, 7.56, 8.00, 8.89. Then 8.95 at the last four. | kW | `scripts/results/k_sweep_daisy_5kw.csv`, blob `d17d1377b191dde5b44df7f5534d0cdc4c48d0f3`, landed `adea1a3` (2026-08-22 14:11:49 +0100). Column line and ten data rows | signed (science-validator, 2026-10-12) |

Sign-off basis:

- All ten pairs cross-read the committed file at full stored precision. The quote forms above round to 2 dp.

- The run used the honest window. The relax span reads 10 s. The window span reads 40 s, tail-5 at 35 to 40 s. Source: the sweep script at `adea1a3`.

- The light end rejects on the power floor. The k=0.5 row reads 3.4852 against the 5.0 kW bar. The other nine rows read ok.

- The heavy end reads a plateau. The k 4.0 to 9.0 rows sit in a band, 8.9475 to 8.9511.

- P_mean and P_end agree below 0.5 per cent at every row. The window reads as converged.

Reading rules:

- The plotted basis is P_mean, the window mean. Quote at 2 dp.

- The sweep settings k read as listed. 0.5, 1.0, 1.5, 1.94, 2.24 at the light end. Then 3.0, 4.0, 5.39, 7.0, 9.0.

- k=2.24 holds its own row (NR-015). This row does not re-derive the pick. It carries the values the plate draws.

Boundaries that travel with this row:

1. Era. The sweep ran on the corrected 18.8 m machine, under the unified span-cubed blade-mass law. The values are a 2026-08-22 reading, not a current-tip re-read.

2. Clamp line. The plateau is the clamp-limited branch of its era. P_end over omega_final reads about 625.0 N·m on the k 4.0 to 9.0 rows. That is the era cap form, 2500 x (P / 10^4)^2 at 5 kW. The current tip cap law (D4, `generator_torque_cap`, 2026-10-07) reads 1541.137296501083 N·m at 5 kW. A drawn clamp line prints with its era named.

3. The omega_eq column reads zero on all ten rows. The run predates the cold-path carry that landed in the same commit. Quote nothing from that column. This file does not carry the settle-gap metric.

4. No derivation formula prints. The closed form in the sweep script header does not evaluate (product 3.55). The plate labels values, not arithmetic.

Counter-read requested from the aero seat.

Evidence: `scratch/sv_k_sweep_rows.py` and its log, `scratch/sv_k_sweep_rows.log`.

## Aero counter-read: NR-041 (2026-10-12, aero-validator)

This block appends only, under the amend pattern. No signed row changed.

The receipts sit in `scratch/av_counter_nr041.py` and its log.

- The ten pairs recompute from the committed file at full precision. The
  2 dp quote forms read as written: 3.49 reject, then 5.45, 6.78, 7.56,
  8.00, 8.89, then 8.95 at the last four.

- The reject row holds. k=0.5 reads 3.4852 against the 5.0 kW bar. The
  other nine rows read ok.

- The plateau band holds. The k 4.0 to 9.0 rows read 8.9475 to 8.9511 at
  4 dp.

- The convergence line holds. P_mean and P_end agree below 0.5 per cent
  at every row. The spread runs 0.07 to 0.45 per cent.

- The clamp reading holds in band. P_end over omega_final on the four
  plateau rows reads 624.76 to 625.08. That band sits inside 0.04 per
  cent of the era form 625.0. The current tip law recomputes
  1541.137296501083 from `src/ring_forces.jl:54` at 5 kW.

- Boundary 3 holds. The omega_eq column reads zero on all ten rows.

- Boundary 4 stands. The header closed form evaluates to 3.550 and
  8.520, not the printed anchors. The plate prints no formula.

- The pins hold. The blob reads `d17d1377` at HEAD and at the landing
  commit `adea1a3`. The file sha256 matches the draft manifest pin.

Verdict: no material discrepancy. The row stands as signed. The plate
may draw the ten points, the reject ring and the plateau bracket.

## NR-013 extension: lane-3 strain annotations (2026-10-12, science-validator)

This block appends only, under the amend pattern. No signed row changed.

The F3 plate (row 4) draws two strain annotations on lane 3. The room asked for rows on both.
This block binds both to the committed extract at `21e941d` (2026-10-12). Both re-derive at full stored precision.

| NR-013 ext | Lane-3 strain annotations for the F3 timeline | Warm leg: 1.00081 at t = 2.841 ms, the run ends. Ruling mode: 1.448 at t = 5.798 ms, the grid max | strain over break | `extract-eval-timeline-warm.csv`, blob `ff1ca1b2a809b2d4231d5947765d48ee5aed0496`, and `extract-eval-timeline-warm-rulingmode.csv`, blob `bb0a47202d7e1086000ef494c721c53c782fea23` | signed (science-validator, 2026-10-12) |

Sign-off basis:

- The warm leg reads the last row. The file holds 98 rows.
  The last row sits at t = 2.841 ms with strain 1.00081.
  The latch reads 1 and the run ends.
  The crossing reads 1.00028 at step 97, and the latch lands at step 98. The trip segment is TRPT S4 line 3.

- The ruling mode reads the grid max. The file holds 1823 rows and completes 50 s.
  No latch lands, and any_broken reads false throughout. The grid max strain reads 1.44798 at t = 5.798 ms.
  The per-step read is 1.44819 at t = 5.740 ms. Nothing past 60 ms exceeds 0.677081, so the peak stands.

- The condition run carries the pending 2026-09-16 gate placement. The rope-break gate reads off for t < 10 s and on from t = 10 s.
  That placement is not in the code. As coded the latch reads at any step.
  The run rings and never settles: window means 12.639282 rad/s and 4.958894 kW. The window strain max reads 0.449417.

Reading rules:

- Quote the warm value as 1.00081 at t = 2.841 ms. Quote the ruling value as 1.448 at t = 5.798 ms.
  The second is the extract grid max.

- Print the ruling-mode curve under the condition-run label only. The label names the placement as pending.
  No label or caption claims the machine "would pass".

Boundaries that travel with this row:

1. The plate draws from the two blobs above. A re-run writes new bytes and needs a new block.

2. The drawn 1.448 is the extract grid max. The per-step maximum is a separate reading.
   A caption that prints it names its basis.

3. The warm start as coded is not a clean misread. The transient really crosses the break strain.
   NR-013 already carries the rejection.

4. A fixed-seed redraw draws from its own extract and needs its own rows. This block does not carry them.

Counter-read requested from the aero seat.

Evidence: `scratch/sv_nr013_ext_check.py` and its log, `scratch/sv_nr013_ext_check.log`.

## Aero counter-read: NR-013 extension (2026-10-12, aero-validator)

This block appends only, under the amend pattern. No signed row changed.

The receipts sit in `scratch/av_counter_nr013ext.py` and its log.

- The pins hold. The two blobs read `ff1ca1b2` and `bb0a4720` at `21e941d`
  and at HEAD. The F3 draft manifest pair pins the three input hashes.
  Each hash recomputes from the committed files.

- The warm leg holds. The file carries 98 rows. The last row reads
  t = 2.841 ms, strain 1.000810120, latch 1.

- The first crossing lands at step 97, at strain 1.000277041. The quote
  form stands as 1.00081 at t = 2.841 ms.

- The ruling leg holds. The file carries 1823 rows and completes 50 s.
  `any_broken` reads false at every row.

- The grid max reads 1.447982844 at t = 5.798 ms. The quote form is
  1.448.

- The per-step peak 1.44819 at 5.740 ms cross-reads to the diag log.
  Past 60 ms nothing exceeds 0.677080915 (quote 0.677081).

- The condition-run numbers hold. The window means read omega_gnd
  12.639281787 (quote 12.639282) and P 4.95889427 kW (quote 4.958894).

- The window strain max reads 0.449417229 (quote 0.449417). The stamp
  carries the gate placement and the condition note.

- The trip-segment note cross-reads. The extract README cites TRPT S4
  line 3.

Verdict: no material discrepancy. The block stands as signed. The digits
stay for the F3 plate.

## Display-form note: the objective-score unit (2026-10-13, science-validator)

This block appends only, under the amend pattern. No signed row changed.

Parts 3 and 4 of the feedback round 2 record rule the term for objective
values (`docs/reporting/feedback/feedback-on-report2.md`). The science-writer
plan applies the term at five sites (`docs/plans/2026-10-13-feedback2-science-writer-plan.md`, SW1).
This note signs the display form, so the sweeps read one basis.

- Objective values display as "kg-equivalent". The rows: NR-003 to
  NR-006, NR-036 and NR-039. Figure text that prints them takes the same
  form.

- The defining use reads "kg-equivalent objective score". Value sites
  read "kg-equivalent".

- Physical mass values keep the unit "kg". NR-018 reads 25.698 kg. The
  mass term inside NR-039 reads 25.698 kg.

- The penalty terms inside NR-039 read "kg-equivalent". The total reads
  1.665 kg-equivalent.

- The section 3.2 reading rule keeps its shape. The example reads:
  Island 3 reaches 27.364 kg-equivalent at generation 26 (NR-005), the
  search objective. It reads the airborne mass 25.698 kg (NR-018) plus
  1.665 kg-equivalent of objective penalties (NR-039).

- No numeral moves at any site. The signed unit strings stand as
  recorded. The sweep reads one basis: a fitness value is the airborne
  mass plus penalties, shown as "kg-equivalent".

- New rows with objective values carry "kg-equivalent" in the unit
  column.

The five replacement sites in the science-writer plan quote this form.

## Derived row: NR-042, winner blade-tip clearance and the gate floor (2026-10-13, science-validator)

This block appends only, under the amend pattern. No signed row changed.

The aero seat answered W7 and proposed the row (receipt `docs/reporting/room-responses/aero-validator-2026-10-13-w7-clearance-margin-and-fos-phrase-read.md`). This block signs it under SV5.

| ID | Claim | Value | Units | Source | Status |
|---|---|---|---|---|---|
| NR-042 | Winner blade-tip clearance and the gate floor | floor `1.5`, winner `5.468` at decode. Margin `+3.968` (`3.65` times, `+264.5` per cent) | m | pair-extract log line 11 (`docs/reporting/figures/pair-extract/extract-winner-operating-point.log`, sha256 `7579e84a5724a2a41f9ada08200b0dc59e0a03177ce9193c4978abc1d71474f8`). Runner `scripts/run_v13_5kw_masslift.jl:76` and `:254-257`. Knob probe `scratch/av_probe_clearance_knob.jl` | signed (science-validator, 2026-10-13) |

Sign-off basis:

- Extract pin. The committed extract log recomputes to sha256 `7579e84a5724a2a41f9ada08200b0dc59e0a03177ce9193c4978abc1d71474f8`. Line 11 reads `clearance = 5.468123977660059 m`.

- Gate sites. The runner sets `MIN_CLEARANCE = 1.5` at `:76`. It marks a reading below that floor `status = :clearance_reject` at `:254-257`. The clearance definition sits at `src/objective_v10.jl:414`. The definition reads the ground clearance at the outer tip of the lowest active rotor. The basis is ground offset 1.0 m and elevation 30 degrees.

- Decode note. The runner decodes each candidate twice. The gate path omits `v_rated` and reads `5.4681239776600616` m. The score path passes `v_rated = 11.0` and reads `5.4668473649653162` m. The pair sits 1.28 mm apart. Both forms round to the stored telemetry `5.47` (island 3, generation 26, index 9). The extract mirrors the gate path to 2.7e-15 m.

- Reproduction. This seat re-ran the knob probe at `a7c4dc2`. The output equals the aero run (`scratch/av_w7_clearance_probe_2026-10-13.log`) and this seat's earlier run at `e0b8a92` line for line. Log: `scratch/sv_w7_knob_rerun_2026-10-13.log`.

- Arithmetic. This seat recomputed every quoted form from the committed bytes. Checker: `scratch/sv_sv5_margins_check.py` and its log. Full digits: margin `3.968123977660059` m, ratio `3.645415985106706`, `264.5415985106706` per cent.

Reading rules:

- Quote the winner as 5.468 m at decode. Quote the margin as +3.968 m (3.65 times, +264.5 per cent).

- The section 3.3 clearance cell reads "pass, 5.468 m, margin +3.968 m". The F3 note takes this row for the "≥ 1.5 m" string.

Boundaries that travel with this row:

1. One machine, one capture: the island-3 winner at its recorded decode.

2. The margin is decode geometry, not a flight measurement.

Counter-read requested from the aero seat.

## Display-form note: the FoS config pair (NR-015) (2026-10-13, science-validator)

This block appends only, under the amend pattern. No signed row changed.

The aero W7 receipt asks one register question. NR-015 records "FoS gate 2.5/2.5". That string names the two config fields: `fos_target = 2.5` and `fos_hard = 2.5` (`scripts/run_v13_5kw_masslift.jl:151-155`).

The campaign scorer gates on the floor only. A window minimum below `fos_hard` rejects the design (`src/objective_v12.jl:149`). The utilisation charge reads `fos_hard / FoS_min` (`:165`). The `fos_target` field takes no read in the campaign scorer. The older power scorer switches its soft target window off when target equals hard (`:50-54`).

Reading rule:

- Where a draft site states the FoS requirement as a plain "2.5", it reads the floor, `fos_hard`. The pair form "2.5/2.5" stays valid as the recorded config.

- No value moves. NR-015 stands as signed.

## Display-form note: the minimum FoS at 1 dp (NR-009) (2026-10-13, science-validator)

This block appends only, under the amend pattern. No signed row changed.

The founder docx return asks for a 1 dp display at one site: the abstract sentence ("1dp resolution fine here"; return note 3, `scratch/au_draft_docx_notes_extract_2026-10-13.md`). This seat signs the reduced form, so the sweeps read one basis.

- The signed value reads `14.971791422208508` (NR-009). The row form reads 14.972. At 1 dp the value rounds to `15.0`.

- The returned copy carried "14.9". That form truncates the value. It is not the 1 dp rounding. The fold takes 15.0.

- The row keeps 14.972. No value moves.

Reading rule:

- A site that prints the minimum factor of safety at 1 dp reads 15.0. Sites that print it at the row precision keep 14.972.

## Derived row: NR-043, winner blade span (2026-10-13, science-validator)

This block appends only, under the amend pattern. No signed row changed.

Founder note 13 asks the section 2.1 figure to carry the blade span
(`scratch/au_draft_docx_notes_extract_2026-10-13.md`, quote "include blade
span"). The value reads in the NR-032 block findings. This block lifts it to
its own row and signs the display form. The next render can then draw the
dimension.

| ID | Claim | Value | Units | Source | Status |
|---|---|---|---|---|---|
| NR-043 | Winner blade span (island 3, main rotor) | 1.499 (quote 1.499) | m | `scratch/sv_probe_winner_areas.log`, the `span (built)` line, sha256 in the manifest. R_main 5.630 minus blade_hub_radius 4.130. The decode convention `src/objective_v10.jl:374-376`. Figures decode log `scratch/fig1_decode_winner.log`. Counter-read: the aero tip-reference receipt (2026-10-11) | signed (science-validator, 2026-10-13) |

Sign-off basis:

- Reproduction. This seat re-ran `scratch/sv_probe_winner_areas.jl` at HEAD
  `2db50f9`. The output equals the committed log, line for line. No commit
  touches `src/` between the probe log landing `25ff00e` and the re-run.

- Arithmetic. The span reads tip radius minus inner edge:
  `5.629560432565964 - 4.130158464357515 = 1.4994019682084492`. The 0.7 / 0.3
  ring anchor closes both radii about the hub ring. It reads r_out = r_hub +
  0.7 span and r_in = r_hub - 0.3 span, at r_hub 4.57997905482005. The decode
  variable reads 0.75 x r_rotor x blade_scale = 1.4994019682084492, on r_rotor
  2.4341173109692225 and blade_scale 0.8213255027884769. Checker:
  `scratch/sv_nr043_span_check.py` and its log. Every quoted form gates.

- Counter-read. The aero seat counter-read the tip pair and this span on
  2026-10-11
  (`docs/reporting/room-responses/aero-validator-2026-10-11-tipref-counterread.md`).

Display form, signed:

- The plate prints the dimension at three decimals: `1.499 m`. That matches
  the drawn radii precision (4.580 m, 0.804 m). The row keeps the full value.

- The dimension reads the built blade span, inner edge to tip. It is not the
  ring radius, and not the tip offset alone.

Reading rule:

- The system-anatomy plate prints `1.499 m` as the blade-span dimension
  (NR-043).

Boundaries that travel with this row:

1. One machine, one built state: the island-3 winner decode, the NR-032
   receipts chain.

2. The span is decode geometry, not a flight measurement.

## Display-form note update: the minimum FoS at 1 dp, the report sites (2026-10-13, science-validator)

This block appends only, under the amend pattern. No signed row changed.

The founder call of 2026-10-13 rules the report display: the factor of safety
prints at 1 dp, and the full precision stays internal (tracker display forms,
`2ebbd22`). The call covers every report site of the value.

The reading rule below replaces the last sentence of the FoS note above, so
the sweeps read one basis.

Reading rule:

- Every report display site of the minimum factor of safety (NR-009) reads
  `15.0` at 1 dp.

- The register row keeps 14.972. The signed value reads `14.971791422208508`.

- The sites that fold: the front summary block, two section 3.3 sites, the
  gates table, and section 5.

- The capture hub ring reading (15.033, NR-021) is a ring reading at the
  final step. It is not the machine factor of safety. It keeps its form at
  the section 3.3 disambiguation line.

## Display-form note: the section 3.3 lift chain (NR-037 on NR-018 and NR-026) (2026-10-13, science-validator)

This block appends only, under the amend pattern. No signed row changed.

The founder call rules coarse display for the report. The section 3.3 lift
chain takes the report forms.

- The sizing mass prints at `20.698` (3 dp, the report mass form). The
  sentence above the chain reads 20.698 kilograms.

- The vertical load prints at `304.6` (1 dp, the force form). NR-010 reads
  324.1 N at 1 dp.

- The chain holds as displayed. The rounded operands give 304.571.

- Both the rounded operands and the full value read 304.6 at 1 dp.

- The 6 dp operand served the 2 dp result form alone. The report takes 1 dp
  for the force.

- The full values stay internal: `20.69846825623688` kg and
  `304.5779603905257` N. NR-037 keeps its value.

Reading rule:

- The section 3.3 chain reads: 1.5 × 20.698 × 9.81 = 304.6 newtons.

Boundaries:

- The tension line keeps NR-010. The elevation 70 degrees and the margin 1.5
  keep NR-026.

## Derived row: NR-044, the PCA projection summary (2026-10-13, science-validator)

This block appends only, under the amend pattern. No signed row changed.

The levers family draws the v13 5 kW screen in gene space (rows 20 and 21, founder ask 2026-10-13). The kit notes carry the recipe and the row want. This block signs the projection summary.

| ID | Claim | Value | Units | Source | Status |
|---|---|---|---|---|---|
| NR-044 | PCA projection summary (v13 5 kW screen, 930 draws): variance shares, top loadings, bin rule | PC1 22.434667 (quote 22.4), PC2 17.263044 (quote 17.3), pair total 39.697710 (quote 39.7) per cent. Loadings at four decimals, the abs(v) >= 0.2 set: PC1 n_lines -0.5385, rotor_count -0.5222, blade_scale_top +0.5180, target_Lr +0.2517, r_bottom +0.2036. PC2 bank_bottom +0.5621, blade_scale_bottom -0.5605, density_profile -0.5018, bank_top -0.2444. The field bins at 18 x 18 cells over the 1 to 99 percentile rectangle | per cent, -, cells | Recipe: z-score the 930 x 10 matrix of x1..x10 (three island telemetry files, data commit dd3cc6a), one SVD, shares from the squared singular values. Reproduction below | signed (science-validator, 2026-10-13) |

Sign-off basis:

- Reproduction. This seat re-ran the projection in Julia (`LinearAlgebra.svd`, a different instrument than the numpy path in the kits) from the three committed telemetry files. The shares read 22.4346665772 and 17.2630436556. The pair total reads 39.6977102328. Every listed loading matches at four decimals. Checker: `scratch/sv_pca_projection_check.jl` and its log.

- Counts. The matrix reads 930 rows, 310 per island. The status mix reads 508 ok, 301 reject, 110 clearance-reject and 11 reject-twist. The kit checks log carries the same.

- Counter-read. The kit probe (`scratch/fig_pca_probe.py`) and the kit checks log carry the same values at the drawn precision. The F-REPRO log reads `scratch/fig_pca_repro.log`.

Display form, signed:

- The plates and the prose print the shares at one decimal: `22.4` and `17.3`. The pair total prints at the same precision: `39.7` (the reading ask, science-writer 2026-10-13). The row keeps six decimals.

- The loadings print at four decimals from this row, as the abs(v) >= 0.2 set per axis.

Reading rule:

- PC1 carries 22.4 per cent, PC2 carries 17.3 per cent, and the pair carries 39.7 per cent.

Boundaries that travel with this row:

1. The projection reads the raw draw columns x1..x10 as logged. The evaluator rounding of x4 and x6 is not applied. The figure maps the draw space.

2. The bin rule is a display fact: the field bins at 18 x 18 cells over the 1 to 99 percentile rectangle of the full screen.

3. The axis names and the direction reads ride the kit text.

## Derived row: NR-045, the island generation counts (2026-10-14, science-validator)

This block appends only, under the amend pattern. No signed row changed.

The landscape plate prints `31 generations each` in its subtitle. No row carried the count. The figures-seat query asked for a row or a drop. This block signs the counts.

| ID | Claim | Value | Units | Source | Status |
|---|---|---|---|---|---|
| NR-045 | Island generation counts (v13 5 kW screen) | 31 generations per island (gen index 0 to 30), 10 rows per generation (idx 0 to 9), 310 rows per island, 930 in total | generations / rows | island_*/telemetry.csv, `gen` and `idx` columns, data commit dd3cc6a | signed (science-validator, 2026-10-14) |

Sign-off basis:

- Census. This seat re-read the three committed telemetry files. Each island carries 310 data rows. The `gen` column reads 0 to 30, so 31 values. Each generation carries exactly 10 rows, idx 0 to 9. The totals add to 930 (NR-001).

- Anchors. The gen-0 (seed batch) best reads 36.109, the NR-006 quote form. The global best 27.364 sits at gen 26, the NR-005 quote form. The convergence files carry both at full precision: 36.10892711736875 and 27.3635412663488.

- The recorded step reads 28.315 to 27.364 from gen 25 to gen 26. The drop reads 0.951 (the NR-036 form). The best holds at 27.364 through gen 30.

- Checker: `scratch/sv_generations_check.py` and its log.

Reading rules:

- Generation 0 is the initial population (the seed batch). Generations 1 to 30 are the evolution steps.

- The convergence files carry 30 read rows, iterations 1 to 30. The telemetry carries 31 generation indices, 0 to 30. The NR-006 precision note reconciles the two forms.

## Source row: NR-046, the objective seam forms, the weights, the thresholds and the reject placement (2026-10-14, science-validator)

This block appends only, under the amend pattern. No signed row changed.

The feedback round 4 asks how the campaign builds the score and how rejected designs sit against it. This block reads the source and signs the forms. The three files read byte-identical at launch `a76c5e9`, at HEAD `7b8c101` and at origin. Their blobs read `da9c5554` (`objective_v12.jl`), `52669d40` (`objective_evaluator.jl`) and `bf5c5e36` (`run_v13_5kw_masslift.jl`). The line numbers below read at HEAD.

| ID | Claim | Value | Units | Source | Status |
|---|---|---|---|---|---|
| NR-046 | The objective seam forms, the weights, the thresholds and the reject placement | `f = mass + 5.0 * max(P_score - 5.0, 0)^2 + 20.0 * (2.5 / FoS_min)^2 + 1.0 * (r / (1 - r))^2` with `r = min(twist_ratio, 1)`, plus the stationarity add-on `10.0 * max(0, swing - 0.20)` with `swing = P_range / P_mean`. `P_score` reads the tail-5 power (P_end). Winner closure: 25.70 + 0.4933 + 0.5577 + 0.6141 = 27.36 (NR-039). Rejects carry no score: the evaluator returns `Inf` and the runner stamps the search cost `1e9` on every non-ok design (422 of 930 rows) | kg-equivalent: 5.0 per kW², 1.0 per twist-ratio², 20.0 per FoS-ratio², 10.0 per swing fraction. Mass reads kg. The `1e9` stamp is a search cost, not an objective unit | Source read at `7b8c101`, the tip at read time. Byte-stable from launch `a76c5e9`. Sites: `src/objective_v12.jl:114-116` (weights), `:145-168` (seam body). `src/objective_evaluator.jl:90-91, 1148, 1161, 1192-1194, 1200-1203`. `scripts/run_v13_5kw_masslift.jl:153-156, 256-257, 266, 272, 281-283`. Census over island_*/telemetry.csv. Checker: `scratch/sv_nr046_objective_seam_check.py` and its log | signed (science-validator, 2026-10-14) |

Sign-off basis:

- Source pins. Thirty line-numbered pins assert across the three files. The weights read 5.0 / 1.0 / 20.0 at `objective_v12.jl:114-116`. The gates and the forms read at `:149-167`. The stationarity constants read at `objective_evaluator.jl:90-91`. The window chain reads at `:1148-1203`. The campaign config and the reject stamp read at `run_v13_5kw_masslift.jl:153-283`.

- Blob identity. The three blobs read identical at launch `a76c5e9`, at HEAD and at origin. The launch sits in the tip ancestry.

- Closure. The forms recompute the recorded terms at full precision. The diff reads 0.0 against `island_3/convergence.csv` gen 26 and `scratch/sv_p0_winner_reeval.txt`. Every term equals its Phase 0 audit string.

- Term sum. The term sum reads 1.665073010111922. The direct gap reads 1.6650730101119215. The seam gap reads 4.440892098500626e-16, the NR-039 record.

- Reject census. All 930 telemetry rows read: 508 ok with finite scores, 422 stamped `1.0e9`. The mix reads 301 reject / 110 clearance_reject / 11 reject_twist (NR-002). No ok row carries the stamp. No non-ok row carries a score.

- Twist ratio basis. The ratio reads `|Δα| / δα*` per segment, worst over the window. The limit reads `δα* = 2 * asin(L_seg / sqrt(2 * (L_seg^2 + 2 * r_seg^2)))` with `r_seg = max(r_i, r_i+1)`. Source `twist_collapse_check` at `objective_evaluator.jl:443-477`. The cap and the margin floor read at `:1201-1202`.

Reading rules:

- One kg of airborne mass adds 1.0 to the score. The charges read kg-equivalent too (display note, `43fb0bc`).

- The over-power charge reads the score power. Under this campaign that reads the tail-5 (end) power (`power_stat = :tail5`, `objective_evaluator.jl:1148`).

- Rejected designs hold no objective score. The search ranks no reject above an ok design. The search cannot trade power or safety against mass.

- The winner reads 27.364 kg-equivalent (NR-005) = 25.698 kg (NR-018) + 1.665 kg-equivalent (NR-039).

Boundaries that travel with this row:

1. One campaign config: floor and ceiling 5.0 kW, `fos_hard` 2.5, tail-5 power, k 2.24, 18.8 m. A config move changes the thresholds and needs a new read.

2. The `1e9` stamp is a runner fact, not a physics fact. It is not an objective unit.

3. The stationarity add-on joins every objective at the evaluator level. It reads zero inside the 20 per cent swing gate. The winner reads 0.54 per cent.

4. The twist term carries two sites with one form: the seam keyword (default 0.0, for tests) and the evaluator add-on (live). The recorded winner charge comes from the live add-on.

5. The seam argument reads `P_mean` by name. Under `power_stat = :tail5` it carries `P_end`. Quote the tail-5 basis with the value.

Counter-read requested from the aero seat.

## Aero counter-read: NR-046 (2026-10-14, aero-validator)

This block appends only, under the lead ruling and the amend pattern.
No signed row changed.

Basis: the block above at `4a86e6f`. The counter-read works from the
committed records. It runs no simulator.

Evidence: `scratch/av_nr046_counterread.py` and its log. The pass reads
89 checks, all green.

- The source pins. The thirty sites re-read at the pinned launch
  commit `a76c5e9`. The three blobs read `da9c5554`, `52669d40` and
  `bf5c5e36` at launch, at HEAD and at origin.

- The closure. The three charges recompute with own arithmetic from the
  raw tokens. They read `0.49333696413175443`, `0.5576509889014662`
  and `0.6140850570787014`, repr-equal to the row.

- The seam. The live chain closes at diff 0.0 against `27.3635412663488`.
  The term sum reads `1.665073010111922` and the direct gap
  `1.6650730101119215`.

- The residual. The seam gap reads `4.440892098500626e-16`. The
  stationarity charge reads zero at a swing of 0.54 per cent.

- The reject census. All 930 telemetry rows read: 508 ok with finite
  scores, 422 stamped `1.0e9`. The mix reads 301 / 110 / 11 (NR-002).

- No crossover reads either way. The least ok score reads 27.364.

- The rank cross-checks. The telemetry twist-ratio column equals the
  record token `0.4393474253185575`. The convergence gen-26 fitness
  equals the record token `27.3635412663488`.

- The seat checker. It re-runs green on this seat: `SV_NR046_DONE`.

Verdict: no discrepancy found. The row stands as signed. The printed
block at draft section 2.4 reads at the signed forms.

## Derived row: NR-047, the k-sweep display rows for section 2.3 (2026-10-14, science-validator)

This block appends only, under the amend pattern. No signed row changed.

The k = 2.24 story folds at section 2.3. The fold prints a small table of the load sweep, one row per load. This row binds the six display rows to the committed sweep file. The omega column is named. The settled speed reads in `omega_final`. The `omega_eq` column reads 0.0 on all ten rows (the cold path). A quote from that column prints zero.

| ID | Claim | Value | Units | Source | Status |
|---|---|---|---|---|---|
| NR-047 | The k-sweep display rows for section 2.3: six loads of the honest-window sweep, one row per k | P_mean at 2 dp: k 0.5 reads reject. Then 5.45, 6.78, 7.56, 8.00, 8.89. omega_final at 2 dp: 19.14, 17.64, 16.59, 15.80, 15.34, 14.42. FoS_min at 1 dp: 51.8, 47.8, 42.8, 40.1, 36.4, 24.3 | kW, rad/s, - | `scripts/results/k_sweep_daisy_5kw.csv`, blob `d17d1377b191dde5b44df7f5534d0cdc4c48d0f3`, landed `adea1a3` (2026-08-22). Column line and ten data rows. The six rows read at `omega_final` | signed (science-validator, 2026-10-14) |

The six display rows, one row per k:

| k | status | P_mean (kW) | omega_final (rad/s) | FoS_min |
|---|---|---|---|---|
| 0.5 | reject | 3.49 | 19.14 | 51.8 |
| 1.0 | ok | 5.45 | 17.64 | 47.8 |
| 1.5 | ok | 6.78 | 16.59 | 42.8 |
| 1.94 | ok | 7.56 | 15.80 | 40.1 |
| 2.24 | ok | 8.00 | 15.34 | 36.4 |
| 3.0 | ok | 8.89 | 14.42 | 24.3 |

Sign-off basis:

- Recompute. All six triples cross-read the committed file at full precision. The quote forms round from the stored digits. Three examples: k 1.0 reads P_mean 5.450868423585806, omega_final 17.635572770055294, FoS_min 47.800187200992305. k 2.24 reads 7.997584762516935, 15.343704281699525, 36.41539771790948. k 0.5 reads 3.485236347784519 against the 5.0 kW bar, and the row reads reject.

- Blob identity. The sweep file reads `d17d1377` at the landing commit `adea1a3`, at HEAD and at origin.

- The column naming. The column line carries `omega_final`. The sweep script header names it: "omega_final = ground-ring omega at window end" (`scripts/sweep_k_mppt_5kw.jl:112`). Quote the speed from `omega_final` alone.

- The reject row. k 0.5 reads 3.4852 against the 5.0 kW bar. The other nine rows read ok.

- The plateau rows. k 4.0 to 9.0 ride the NR-041 band and the k >= 4 bracket. No new read.

- Tip forms. The runner comment records two pairings (`scripts/run_v13_5kw_masslift.jl:161-168`): k 2.24 at omega 15.3, tip about 73 m/s, FoS 36. And k 1.0 at omega 17.6, tip about 85 m/s, near the 100 m/s ceiling. The ceiling is the hard gate `TIP_SPEED_CEILING_MPS = 100.0` at `src/objective_evaluator.jl:103`. It applies to every ring rim and rotor tip (`:427` to `:437`).

- The retirements. Two anchors retire, per the same comment. 3.55, the mass-scale value (`p_base.k_mppt`), unanchored. And 5.39, the 3-blade anchor chosen on the broken machine. The 5.39 claim reads "~9 kW from the seed". The CSV k 5.39 row reads P_end 8.97 kW at 2 dp.

- The bases inside the comment. "8.0 kW" reads P_end, and the comment says so. "5.45 kW" reads P_mean. The table prints P_mean at 2 dp and names P_end where it means it.

Reading rules:

- Quote forms: P_mean at 2 dp, omega_final at 2 dp, FoS_min at 1 dp.

- The tip line prints as "about 73 m/s" and "about 85 m/s", each with its omega pairing at the comment's precision (15.3, 17.6). No exact per-row tip prints from this row. A full tip column takes a fresh derivation.

- The reject row prints reject and its power. Its FoS prints as context only.

- The k = 1.94 row reads the sweep header's theory anchor, not a Daisy anchor.

Boundaries that travel with this row:

1. Era. As NR-041: the sweep ran on the corrected 18.8 m machine on 2026-08-22, under the span-cubed blade-mass law. The values are era readings and not a current-tip re-read.

2. Tips. The record carries the two approximate pairings only. The 100 m/s ceiling is the gate the light end approaches.

3. The six rows are the fold's display set. The plateau set (4.0 to 9.0) stays with NR-041.

Counter-read requested from the aero seat.

Evidence: `scratch/sv_nr047_k_sweep_rows_check.py` and its log.

## Derived row: NR-048, the sizing-side pair for the k = 2.24 story (2026-10-14, science-validator)

This block appends only, under the amend pattern. No signed row changed.

The section 2.3 fold prints a sizing-side pair beside its two-side safety text. The pair reads in the structural record, not the sweep file. This row binds its tokens to the record files.

| ID | Claim | Value | Units | Source | Status |
|---|---|---|---|---|---|
| NR-048 | The sizing-side pair for the k = 2.24 story: the load-step sizing case and the k-easing refusal | Sizing load case = a bounded generator load step (nominal `k_mppt × 2`), measured `F_helix ≈ 1278 N/vertex` on the hub segment. The lull is benign under MPPT. k easing refused as the high-wind substitute: the rotor spins up to twist 87.9° against the 78.8° collapse limit | N/vertex, degrees | `DECISIONS.md` [2026-09-06] entry; `docs/plans/2026-09-06-closed-form-beam-sizing.md` section 7.1 and the scenario list; evidence script `scratch/scenario_sweep.jl` | signed (science-validator, 2026-10-14) |

Sign-off basis:

- Token read. The tokens re-read verbatim at the two record files. The DECISIONS entry reads: "Sizing load case = a bounded generator load step (nominal `k_mppt × 2`), measured `F_helix ≈ 1278 N/vertex` on the hub segment". And: "Easing `k_mppt` is the wrong substitute (rotor spins up to twist 87.9° > 78.8°)". The plan section 7.1 restates the sizing pair. The plan scenario list carries the k-ease line: "25 m/s spins the rotor up to twist 87.9° (> 78.8° collapse)".

- Basis of record. The measurement is the first-cut scenario sweep of 2026-09-06. The script is committed (`scratch/scenario_sweep.jl`). The run's console record is not in the tree. This row signs the record forms. A re-derivation is a new read.

- The entry's own qualifiers. The load-step magnitude detail (an instant step against a soft ramp) pends `RampController`. The tokens do not move with that detail.

Reading rules:

- Print the tokens at the record forms: "× 2" or "twice the nominal load", "1278 N/vertex" with its about marker, "87.9°" and "78.8°".

- Do not multiply out and print 4.48 as a new value. "Twice nominal" carries it.

- The lull claim carries no number. It reads "benign".

- The pair prints in the sizing paragraph only. The k table and the tip text read NR-047.

Boundaries that travel with this row:

1. First-cut sweep. The sweep header lists the feather and lifter-drop cases as TODO. The high-wind structural case stays un-modelled until a feather factor lands.

2. Era. The 78.8° limit is the era machine's hub-segment collapse limit. A machine move re-reads it.

3. The wider scenario set (the gust row and the load-step x3 row) is not signed by this row. A fold that reaches for it takes a new read.

Counter-read requested from the aero seat.

Evidence: `scratch/sv_nr047_k_sweep_rows_check.py` and its log.

## Aero counter-read: NR-047, NR-048 (2026-10-14, aero-validator)

This block appends only, under the lead ruling and the amend pattern.
No signed row changed.

Basis: the NR-047 and NR-048 blocks above at `07e2eb9`. The counter-read
works from the committed records. It runs no simulator.

Evidence: `scratch/av_nr047_nr048_counterread.py` and its log. The pass
reads 81 checks, all green. The seat checker re-runs green:
`SV_NR047_DONE`, 46 checks.

- The sweep-file pin. The file reads blob `d17d1377` at the landing
  commit `adea1a3`, at HEAD and at origin.

- The six triples. Each triple recomputes at full precision from the raw
  CSV and rounds to the printed forms under the reading rules. Two spot
  reads: k 1.0 reads 5.450868423585806 / 17.635572770055294 /
  47.800187200992305. k 2.24 reads 7.997584762516935 /
  15.343704281699525 / 36.41539771790948.

- The reject row. k 0.5 reads 3.4852 kW against the 5.0 kW bar and
  carries reject. The other nine rows read ok.

- The companion forms. The tip pair reads as the runner comment records.
  The pairs read omega 15.3 with tip about 73 m/s, and omega 17.6 with
  tip about 85 m/s. The 100 m/s ceiling reads at
  `src/objective_evaluator.jl:103`. The two retirements read as stated.

- The sizing pair. The tokens re-read at the two record files. The fold
  prints them at the record forms.

- The fold in the draft. The table, the two side paragraphs and the
  sizing pair read at the signed forms (v0.39, `12a5753`).

Verdict: no discrepancy found. Both rows stand as signed. The printed
block at draft section 2.3 reads at the signed forms.

## Aero wording amends: NR-025 (2026-10-14, aero-validator)

This block appends only, under the lead ruling and the amend pattern.
No signed row changed.

The row phrase "rope breaks enabled across both" reads as permission.
The phrase describes gate placement. The run applies the rope-break
check across both phases. A break always disqualifies. The winner run
reads no break (NR-012, NR-013). The section 4.1 pair rewords to the
detector forms at the same pass (`ed3d202`).

- NR-025 wording. The protocol phrase reads "the rope-break check
  armed across both". Future quotes use the detector form.

The row keeps its signed values. No number and no ruling moves.

## Display-form note: the gate-margin column figures (NR-009 on NR-015) (2026-10-14, science-validator)

This block appends only, under the amend pattern. No signed row changed.

The AU9 fold brings the SW2d margin column into the section 3.3 gate table.
The gate table is an enumerated site of the minimum factor of safety.
The report reads `15.0` at 1 dp there.
The full precision stays internal (tracker display forms, `2ebbd22`).
The display note update above holds the same rule.

The FoS row of the column reads from the printed operands, `15.0` over `2.5`.
The row holds as displayed (the lift chain precedent above).
The SV5 supply keeps `14.972 vs 2.5` as the computation basis.
The basis notation does not print in the column.

- The margin reads `+12.5`.
- The per cent reads `+500.0 per cent`.
- The ratio reads `6.00 times`.

The internal forms stay in the SV5 basis and its receipt.
They read margin `+12.472`, `+498.9 per cent` and `5.99 times`, from
`14.971791422208508` over 2.5. They do not print.

Reading rules:

- The gate-margin column's FoS row prints `15.0` on `2.5`, with margin
  `+12.5`, per cent `+500.0` and ratio `6.00 times`.
- The FoS outcome cell keeps `pass, 15.0 minimum`.
- No other figure in the column moves under this note.

Checker: `scratch/sv_gate_margin_display_check.py` and its log.

## Derived row: NR-049, the shaft transition cone angle, one fixed value (2026-10-14, science-validator)

This block appends only, under the amend pattern. No signed row changed.

Founder comments 2 and 17 ask whether the rotor-ring to first-TRPT angle is
one fixed value. It is. This block signs the fact, the basis and the display
form.

The campaign holds one cone half-angle, `cone_slope_deg = 22.0`. The runner
cfg carries the literal (`scripts/run_v13_5kw_masslift.jl:172`). The decode
reads the value through one kwarg (`src/objective_v10.jl:207`). The
transition cone length computes as `(r_hub - r_bottom) /
tan(deg2rad(cone_slope_deg))` at `src/objective_v10.jl:259`. The value is a
configuration constant. It is not a genome gene. No sweep script varies it.

| ID | Claim | Value | Units | Source | Status |
|---|---|---|---|---|---|
| NR-049 | The shaft transition cone angle, one fixed half-angle across the campaign | `cone_slope_deg` 22.0 | degrees | `scripts/run_v13_5kw_masslift.jl:172`, `src/objective_v10.jl:207` and `:259`, `src/objective_evaluator.jl:148`. Census: 41 `cone_slope_deg` sites across `src/`, `scripts/`, `test/` and the figure scripts, each a literal 22 or a cfg plumb. Probe `scratch/sv_fb5_source_reads_probe.jl` | signed (science-validator, 2026-10-14) |

Sign-off basis:

- The census. Checker `scratch/sv_fb5_source_reads_check.py` walks every
  `.jl` file outside `scratch/`. Every `cone_slope_deg` line reads 22 or
  plumbs the cfg value. The checker finds no variation site. The seed file
  carries no cone gene, and the canonical layout carries none.
- The decode geometry. The probe reads the winner's cone. `taper_start_z`
  reads `9.453339242013` m. The cone length reads `9.346660757987` m. The
  hub ring sits in the harvest section at `s = 18.826179`. The cone runs
  from the transmission cylinder to the harvest section.

Display form, signed:

- The report site reads `22 degrees` with its own name, the shaft transition
  cone. The qualifier keeps it apart from the other named angles. See the
  boundaries below. The number does not carry the phrase `Tulloch/Jensen
  reference` as its basis (boundary 3).

Boundaries that travel with this row:

1. Two 22-degree facts stay apart. One is the second bank slot at its search
   box top (`bank_bot`, NR-011). One is this cone angle.
2. Three named angles share the machine: the bank slot 22 degrees
   (`bank_bot`), the shaft transition cone half-angle 22 degrees (this row),
   and the bridle cone half-angle 31 degrees from the shaft axis
   (`docs/agents/physics-topology.md` section 3.1).
3. The reading record. `docs/validation/trpt-reference/03-repo-findings.md`
   F5 resolves the source reading: the printed 22 degrees in the Tulloch
   reference is the apex angle, and its per-side slope reads 11.0 degrees.
   The live tree applies 22 as the per-side slope. The cone runs steeper
   than the source machine. The aligning code change stays open (work
   package WP2d, awaiting a ruling). The report prints the fixed-value fact
   alone.

   Boundary 3 amendment (2026-10-20, science-validator).
   The closing sentence above describes the state at signing.
   It stays in place as that record.
   The report no longer prints the fixed-value fact alone.
   The landing commit is `a2b2e84` at draft blob `b7f0b6cc`.

   That gloss prints the reference 22 as an apex angle.
   It prints this cone as steeper.
   It prints the aligning change as open and awaiting a ruling.
   It prints the same 22 as the full opening in the reference.
   It prints one side of it here.

   The lift keeps the purpose of this boundary.
   The reference is not the basis of the value.
   The report may print the two readings.
   It may print which way they differ.
   It may print the open status of the change.

   It may not print the source per-side slope as a number.
   It may not print a steepness ratio.
   It may not cite the reference as the basis of this value.
   A boundary lifts only under a dated amendment such as this one.
   The original line stays.

   Boundary 3 state note (2026-10-20, science-validator). The gloss
   described above left the draft at `016e24d`, draft v0.75 at blob
   `efe185f`.

   Section 2.1 now prints the fixed half-angle, one constant sentence and
   the NR-049 cite. The present tense above describes the state at
   `a2b2e84`. The permissions and prohibitions above still govern any
   later gloss on this value.

   Boundary 3 state note (2026-10-21, science-validator).
   The gloss is live again.
   The founder ruled Option B on 2026-10-21.
   Section 2.1 reinstated the gloss at `43356a5`, draft v0.76, blob `7014d94b`.

   The restored block prints both readings.
   It prints the reference 22 as the full apex angle, one side against the other.
   It prints this cone as the half-angle from the shaft axis.
   It prints which way they differ, this cone steeper.
   It prints the aligning change as open, awaiting a ruling.

   The block prints no source per-side slope and no steepness ratio.
   It does not name the reference as the basis of the value.
   The permissions and prohibitions above govern it.
   The note above at `016e24d` records the withdrawn pass.
   The original closing line stays.

4. The unexplored space. Founder comments 2 and 16 log the cone angle as a
   campaign lead. The angle was never a search gene. A later campaign can
   vary it.

## Derived row: NR-050, the blade-scale base (2026-10-14, science-validator)

This block appends only, under the amend pattern. No signed row changed.

Founder comment 1 asks what number or size the blade scale multiplies. It
multiplies the blade span and chord the decoder sets from the rotor radius
the power sizing needs. This block signs the base and the two factors.

The chain reads from the decode at `src/objective_v10.jl:355-377`:

- The sized radius. `r_rotor_i = BEM.rotor_radius_for_power(P_i, v_i,
  design.n_lines; f=f_i)`. The power share reads `P_i = power_split *
  power_W` for the top rotor. The factor `f_i` reads the bank and elevation
  projection.
- The sizing law. `P = f · Cp · ½ρ · πr² · v³` at `src/bem.jl:162`. The
  radius solves at the rotor's local wind speed, with the co-axial blocking
  factor where it applies.
- The base blade. The base span reads `0.75 * r_rotor_i`. The base chord
  reads `0.113 * r_rotor_i`. Blade scale multiplies both. The mass law
  follows the span cubed, at `0.420` kg per blade at a span of 1.0 m
  (`M_BLADE_REF_KG`, `src/parameters.jl:18`).

| ID | Claim | Value | Units | Source | Status |
|---|---|---|---|---|---|
| NR-050 | The blade-scale base: the sized rotor radius, the base span at 0.75 of it, the base chord at 0.113 of it | Winner decode: `r_rotor` `2.434`, base span `1.826`, span `1.499` (NR-043), chord `0.2259` | m | `src/objective_v10.jl:355-377`, `src/bem.jl:156-179`, probe `scratch/sv_fb5_source_reads_probe.jl` and its log | signed (science-validator, 2026-10-14) |

Sign-off basis:

- The decode chain. The probe runs the evaluated decode on the island-3
  winner. It passes `v_rated = 11.0`, the cfg value the evaluator threads
  (`src/objective_evaluator.jl:721`). It reproduces the NR-043 pair to the
  last digit. Both factor checks read true.
- The arithmetic. The scale `0.8213255027884769` takes the base span
  `1.8255879832269168` to `1.4994019682084492` and the base chord
  `0.27505525613952214` to `0.22590989654340632`. Checker
  `scratch/sv_fb5_source_reads_check.py`, every quoted form gates.
- The mass follow-on. The span cubed law gives `1.4158052557245482` kg per
  blade and `4.247415767173645` kg for the three-blade assembly.

Display form, signed:

- The section 2.1 clause names the base calculation. It prints the two
  factors as `0.75` and `0.113`. A worked example can print `1.826 m` and
  `0.226 m`. The span keeps its signed form, `1.499 m` (NR-043).

Boundaries that travel with this row:

1. The decode convention. The evaluated decode passes `v_rated` at the cfg
   value, 11.0. The standalone clearance decode in the runner omits it, so
   it reads `p.v_wind_ref`, `11.009694...`. The radii differ by 0.13 per
   cent. The signed rows follow the evaluator convention.
2. The base is a decoder convention, not a measured part. The blade mass
   law stays the published span cubed law.

## Derived row: NR-051, the corner-grid picks (2026-10-14, science-validator)

This block appends only, under the amend pattern. No signed row changed.

Founder comment 14 (id 13) asks four machine renders. Each render shows a
typical machine for one corner of the PC1-PC2 field. The corner grid mints
at row 23 of section 3.4. This block signs the four picks, the rule and
the display forms.

The picks replicate the certified projection (NR-044). Every anchor
re-verifies before a pick prints. This seat re-ran the projection in Julia,
a different instrument than the numpy path of the kit.

| ID | Claim | Value | Units | Source | Status |
|---|---|---|---|---|---|
| NR-051 | The corner-grid picks (v13 5 kW screen): four machines, one per PC1-PC2 window corner, at the least feasible distance | The picks stand in the blocks below | kg-equivalent, PC units | `scratch/fig_cg_picks.py` and its log. The island telemetry files (data commit `dd3cc6a`, run `a76c5e9`). Projection per NR-044. Checker `scratch/sv_r6_count_nr051_check.jl` and its log | signed (science-validator, 2026-10-14) |

The picks, one per corner of the [1,99] percentile window:

| Corner | Design | PC1, PC2 | Objective (kg-equivalent) |
|---|---|---|---|
| low PC1 / low PC2 | `i1-g13-i1` | -1.454423, -1.238178 | 60.646 |
| low PC1 / high PC2 | `i1-g7-i7` | -2.088227, 0.152353 | 58.864 |

| Corner | Design | PC1, PC2 | Objective (kg-equivalent) |
|---|---|---|---|
| high PC1 / low PC2 | `i2-g21-i4` | 1.132051, -1.488592 | 33.704 |
| high PC1 / high PC2 | `i3-g26-i8` | 1.679755, 3.050611 | 33.812 |

Sign-off basis:

- Reproduction. This seat re-ran the projection in Julia from the three
  committed telemetry files. The shares read 22.4346665772 and
  17.2630436556. The pair total reads 39.6977102328. Every NR-044 anchor
  gates: the shares, the seed point, the winner point and both fits.
- The rule. For each corner, the pick is the feasible design of least
  distance in PC1-PC2 space. The checker re-derives all four picks from
  the raw files.
- The composition. The two low-PC1 picks are many-line, two-rotor
  machines: 7 and 8 lines, rotor count 2. The two high-PC1 picks are
  one-rotor machines: 3 lines each. The decoder rounds the rotor-count
  gene to an integer count (`src/objective_v10.jl:235`).

Display form, signed:

- The plate prints the objective at 3 dp: `60.646`, `58.864`, `33.704`
  and `33.812`. The strip sets the precedent at 3 dp.
- The identity prints as the island-gen-idx tag, for example `i1-g13-i1`.
- No value prints before this row. The family-mode build opens on this
  sign.

Boundaries that travel with this row:

1. The projection reads the raw draw columns x1..x10, per NR-044
   boundary 1.
2. The picks are typical machines, not optima. All four objectives sit
   above the winner value (NR-005).
3. The cross-check note. The mint records a diagonal-extreme cross-check
   at three picks of four. The independent re-read agrees on three
   corners over the whole feasible set and differs at the high-PC1 /
   low-PC2 corner. The row does not rest on that check.

## NR-013 extension: post-fix warm runs, the three winners (2026-10-15, science-validator)

This block appends only, under the amend pattern. No signed row changed.

The rope-break gate placement fix lands (`2bf76a3`, receipt `317d9cd`).
Break detection arms at the relax boundary (10 s). The measurement window
runs fully armed. This block records the post-fix warm state and binds it
to the fresh extract.

| NR-013 ext2 | Post-fix warm runs, the three winners | Island 1: P_mean 5.719 kW, P_end 3.381 kW, FoS_min 0.154, ω_eq 7.727 rad/s, twist 0.544. Island 2: 5.803, 7.563, 0.439, 8.064, 0.541. Island 3: 5.115, 5.070, 0.593, 14.231, 0.965. All three read status reject, line_broken false, no latch through 50 s | kW, rad/s | `scratch/av_rb_warm_extract/island_1_warm_10ms.csv`, blob `770d937743948763e56715e5baade154fe179941`, `island_2_warm_10ms.csv`, blob `05fb874b0aa0c756570935e1e50039305ebaac39`, `island_3_warm_10ms.csv`, blob `3b39f063c286a58d865bc3c7234cf625ee31244d`, and the log `scratch/av_rb_warm_extract.log` | signed (science-validator, 2026-10-15) |

Sign-off basis:

- The census. The three traces hold 4,999, 4,992 and 5,000 rows.
  Each run reaches about 50 s. The latch column reads zero at every row.
  Before the fix all three read broken=true (NR-013).

- The placement. The arm time reads `breaks_arm_s = cfg.relax_s` = 10.0 s.
  The control case still trips at step 98, t = 2.841 ms, 1.00081.
  The fixed path clears the full run. The placement check reads 5 checks,
  0 fail (`scratch/av_rb_placement_check.log`).

- The window means. The trace reconstructs the recorded P_mean within the
  ringing reconstruction bound. The observed residuals read at or below
  0.023 kW. P_end is a 5-sample statistic. Its observed residuals read at
  or below 0.203 kW. The exact forms stand as evaluator outputs
  (1 s grid, `src/objective_evaluator.jl:912, 1018`).

- The settle rate. The recorded ω_eq reproduces at the trace start on all
  three islands. The first-row values read 7.7258, 8.0632 and 14.2283
  against 7.727, 8.064 and 14.231.

- FoS_min and twist read from the committed extract log lines. The trace
  does not carry them.

- The closure. The 2026-10-12 note "That placement is not in the code"
  retires. The placement sits in the code. The condition curve reproduces
  as a real code run (`317d9cd`).

Reading rules:

- Quote the warm rows as honest-gate rejections (the FoS gate), never as
  rope-break rejections.

- The 1.00081 trip reading stays the control case.

- The condition-run label reads "rope-break gate off during relax"
  (landed `f5c2d59`). No label claims a pass.

Boundaries that travel with this row:

1. The blobs above hold the trace bytes. A re-run writes new bytes and
   needs a new block.

2. The recorded P_mean and P_end stand as evaluator statistics.
   A trace-only recomputation reads the reconstruction bounds above.

## NR-025 quote form, post-fix (2026-10-15, science-validator)

This block appends only, under the amend pattern. No signed row changed.

The placement fix lands (`2bf76a3`). Break detection arms at the relax
boundary (10 s). The measurement window runs fully armed. The 2026-10-14
quote form ("the rope-break check armed across both") describes the
as-run campaign. Future quotes of the fixed evaluator read "the rope-break check armed at the window".
The row keeps its signed text, byte-identical to the base.

## NR-031 and NR-032 source-cell amend (2026-10-15, science-validator)

This block appends only, under the amend pattern. No signed row changed.

The two source cells read "the measured n = 3 surface". The basis is a
computation, not a measurement. The Cp values come from the AeroDyn
v5.0.0 quasi-steady BEM table (NACA4412, 3 blades, R = 4.0 m, 0 degree
elevation) at `src/aerodynamics.jl:93` (the `BEM_CP` table). The function
`cp_at_tsr` (`:263`) interpolates it. The blade-count ratio surface is a
separate, measured surface. At n = 3 it returns the baseline unchanged
(`src/bem.jl:16-25, 102, 109-111`). The values stand byte-identical.
Anchor `a82cafd` stays the signing anchor.

Reading rules:

- Future quotes of the Cp basis read "the AeroDyn v5.0.0 BEM table".

- The "measured" wording stays tied to the blade-count ratio surface only.

## Derived rows: the torsion criteria and the realisability floor, NR-052 and NR-053 (2026-10-15, science-validator)

This block appends only, under the amend pattern. No signed row changed.

The writing queue keys the torsion sentence (Harris review item 1.3) and
the floor sentence (item 2.3) on these two rows.

| ID | Claim | Value | Units | Source | Status |
|---|---|---|---|---|---|
| NR-052 | The torsion criteria as implemented, and the 2.5 boundary | Criterion 1: the geometric crossing check is the campaign's twist gate (form in NR-053). Criterion 2: the torsional-stability FoS hard constraint reads 1.5, on the design-verification path. Winner: least segment torque margin 2.03 at S1 (NR-040), 1.35 times the 1.5 floor. Worst crossing ratio 0.4393, margin 2.28 | deg, - | Constant `src/trpt_optimization.jl:39` (`OPT_TORSION_FOS_REQUIRED = 1.5`), per segment `:872-882`, feasibility and message `:1100-1123`. Crossing detector `src/objective_evaluator.jl:454, 913-920`, hard reject `:1024`. Policy boundary per `software-validator-2026-10-11-item13-torsion-gate.md`. Winner cell: `island_3/telemetry.csv`, gen 26, idx 9 | signed (science-validator, 2026-10-15) |
| NR-053 | The realisability floor and its 1.05 margin | sin(Δα) <= 1/1.05 = 0.9524 (quote 0.9524). The continuum floor angle reads 72.25 deg (quote 72.25). The discrete crossing limit reads δα* = 2*asin(L_seg / sqrt(2*(L_seg^2 + 2*r_seg^2))), r_seg = max(r_i, r_{i+1}). Winner cross-reads: S1 twist 33.95 deg, margin 2.13 to the floor and 2.91 to δ_crit (NR-022) | deg, - | Constant `src/initialization.jl:1691` (`TRPT_REALISABILITY_TENSION_MARGIN = 1.05`), basis `:1663-1691`. Crossing form `src/objective_evaluator.jl:444-462` and `src/initialization.jl:1414-1456`. Ruling DECISIONS [2026-09-20] | signed (science-validator, 2026-10-15) |

Sign-off basis:

- The constants at the tree tip. `trpt_optimization.jl:39` carries
  `OPT_TORSION_FOS_REQUIRED = 1.5`. `initialization.jl:1691` carries
  `TRPT_REALISABILITY_TENSION_MARGIN = 1.05`.

- The arithmetic. 1 / 1.05 = 0.9523809523809523. The arc sine gives
  72.24720983805331 deg. 2.0287970973051634 / 1.5 = 1.3525313982034424
  (quote 1.35). 72.24720983805331 / 33.94561934829036 = 2.1283220405195515
  (quote 2.13). 1 / 0.4393474253185575 = 2.2761030163655342 (quote 2.28).
  98.85908296054023 / 33.94561934829036 = 2.912278074711846 (quote 2.91).
  Checker `scratch/sv_criteria_check.py` and its log.

- The winner cell. The worst crossing ratio 0.4393474253185575 reads once
  in the campaign telemetry: island 3, gen 26, idx 9, status ok,
  twist_crossed false. That is the winner row.

- The 1.05 basis. It is a design constraint, not a fit. The docstring
  census reads measured seed shortfalls up to sin(dalpha) = 1.0366. The
  margin clears every measured shortfall. It lifts the campaign seed's
  binding segment from sin 0.983 to at or below 0.952
  (`src/initialization.jl:1663-1691`).

- The 2.5 boundary. The 2.5 gate reads the structural FoS metric
  (`fos_hard = 2.5`, `scripts/run_v13_5kw_masslift.jl:155`; hard gate
  `src/objective_v12.jl:35`). As run, no code and no row enforces 2.5 on
  torsion. Extending the gate to torsion is open at the founder
  (recorded at the software seat, 2026-10-11).

Reading rules:

- The torsion sentence reads: the collapse factor of safety >= 1.5, the
  twist within the crossing limit, and the 2.5 gate does not cover torsion
  today.

- The floor quotes as 72.25 deg. The enforced gate is the crossing check.
  The floor is the design constraint behind the preload.

- The receipt records the floor as the binding limit of the twist margins
  (software seat, 2026-10-11).

## Derived row: NR-054, the convergence series (2026-10-15, science-validator)

This block appends only, under the amend pattern. No signed row changed.

The convergence figure (Harris review, item 3.5.4) needs the island 1 and
2 running-best series. The aero seat extracted them. This seat recomputed
them from the campaign telemetry.

| ID | Claim | Value | Units | Source | Status |
|---|---|---|---|---|---|
| NR-054 | Island running-best series, generations 0 to 30 | Islands 1 and 2 read 31 values each. Island 3 carries the full curve. Finals: 30.578 (island 1, gen 30), 30.637 (island 2, gen 30), 27.364 (island 3, gen 26). All three start at the common seed 36.109. The finals read +11.7 and +12.0 per cent against island 3 | kg-equivalent | `scratch/av_conv_series.csv` (93 rows, blob `9666b1ad`), script `scratch/av_conv_series.py` (blob `b8c52694`), log `scratch/av_conv_series.log` (blob `98103246`), committed at `9dd453d`. Rule: best-so-far at generation G = least recorded ok fitness with gen <= G, ties take the earliest. Telemetry hashes travel in the file header | signed (science-validator, 2026-10-15) |

Sign-off basis:

- Reproduction. This seat recomputed all 93 rows from the three telemetry
  files. The picked row, its source generation and its index equal the
  extract at every generation. Checker `scratch/sv_conv_series_check.py`.

- The parity set. The telemetry sha256 values match the file header. The
  ok counts read 152, 162 and 194. They sum to 508 (NR-002). The island 3
  milestones reproduce NR-036 at seven of seven generations. The finals
  read the NR-003, NR-004 and NR-005 forms. The stock-probe log carries
  the same 30.578 and 30.637 values.

Reading rules:

- Quote the series as the search objective (kg-equivalent). Never quote it
  as mass (NR-036 boundary 1).

- The figure prints from these bytes. A re-extract writes new bytes and
  needs a new block.

## Derived row: NR-055, the reject split at the status mix (2026-10-15, science-validator)

This block appends only, under the amend pattern. No signed row changed.

The founder ruled "Print" on the 301-reject breakdown (room, 2026-10-15).
Panel one of the progress figure takes the three subgroups. This seat
re-derived the split from the three campaign telemetry files.

| ID | Claim | Value | Units | Source | Status |
|---|---|---|---|---|---|
| NR-055 | The reject class of the status mix, split three ways for print | The plain `reject` class reads 301. Subgroup A, ran with power below the 5 kW floor: 96. Subgroup B, ran at or above 5 kW with FoS below 2.5: 4. Subgroup C, fields zeroed and the cause not logged: 201 | designs | Read of the three campaign telemetry files, `scripts/results/v13_5kw_masslift_len18.8_rotorcount_bankderate2/island_{1,2,3}/telemetry.csv`. Subgroup rule and counts: `docs/reporting/figures/figure-generation-notes.md:135-147`. Checker `scratch/sv_301_split_check.py` and its log | signed (science-validator, 2026-10-15) |

Sign-off basis:

- The counts. This seat re-read all 930 rows. Subgroup A covers 96 rows
  with P_mean below 5.0 kW (range 1.90 to 4.98). 34 of the 96 also read
  FoS below 2.5, so the split reads the power floor first. Subgroup B
  covers four rows: island 1 gen 6 idx 7 (P 5.47, FoS 2.27), island 3
  gen 5 idx 8 (5.15, 1.61), island 3 gen 14 idx 8 (5.72, 1.25), island 3
  gen 22 idx 2 (5.68, 0.42). Subgroup C covers 201 rows with P_mean 0,
  FoS Inf and T_lift 0. No reject falls outside the three subgroups.

- The status mix. ok 508, reject 301, clearance_reject 110, reject_twist
  11. The per-island rows read 152/162/194, 108/111/82, 47/35/28 and
  3/2/6. The three telemetry sha256 values match the NR-054 header.

- The cross-read. The Phase 0 audit carries the same 100/201 split on the
  FoS census: 100 finite readings (0.02 to 15.30) against 201 Inf
  (`docs/validation/2026-10-08-phase0-bankderate2-audit.md`, section 6).

Reading rules:

- Print the three subgroups in words. Label subgroup C "cause not
  logged". Print no status codes and no Track names.

- The reason-code work for the 201 stays a separate item (section 7.1 of
  the improvement plan). It does not ride this ruling.

## Derived rows: the item-2.1 environment reads, NR-056 to NR-058 (2026-10-15, science-validator)

This block appends only, under the amend pattern. No signed row changed.

The v0.54 scope note (author seat) left three section 3.3 environment
items outside the signed set. The aero seat read them and routed them for
sign. This seat re-read each item at the tree tip and through the shipped
library.

| ID | Claim | Value | Units | Source | Status |
|---|---|---|---|---|---|
| NR-056 | The shear law and its exponent | Hellmann power law, exponent 1/7 (0.1429). One authority: the measured Daisy pair, 10.0 m/s at 4.8 m. Reads: 11.01 m/s at 9.412 m (the table pair reads 11.01 at 9.41), 11.01 m/s at the 9.400 m design hub, 10.92 m/s at the settled hub 8.914 m | -, m/s, m | `src/wind_profile.jl:50,54` (SITE_DAISY, SITE_ANCHOR), `:110-112` (site_shear), `:130-137` (wind_at_altitude). Guard `test/test_wind_authority.jl`. Landing record `docs/validation/2026-10-03-d1-wind-landing-verification.md` | signed (science-validator, 2026-10-15) |
| NR-057 | The shaft-elevation angle and the hub altitude | 30.0 degrees (pi/6), the model convention. Angles do not scale. The design hub reads 18.8 * sin 30 deg = 9.4000 m. The rung reference reads 9.4117 m (gap 0.0117 m, immaterial). The flown settled read: mean elevation 28.64 deg at mean z 8.914 m | deg, m | `src/parameters.jl:294,369,606`. Campaign runner `scripts/run_v13_5kw_masslift.jl:73` (ELEV = pi/6). Register boundary note 5 (`docs/reporting/numbers-register.md:618-622`) | signed (science-validator, 2026-10-15) |
| NR-058 | The steady-wind basis of the reported trace | The evaluator wind closure reads altitude only, so the reported trace runs steady wind. The steady_wind constructor returns a constant. Ramp, gust and turbulence tools exist and none is engaged. The NR-014 window swing (0.029 kW on 5.309 kW, 0.5 per cent) is a steady-wind response, not a stability property. The register reads 0.54 per cent on the same quotient | -, kW | `src/objective_evaluator.jl:792-795`. `src/wind_profile.jl:160-164`. Harris review `docs/reporting/feedback/2026-10-10-harris-review.md:184`. Register `:826` | signed (science-validator, 2026-10-15) |

Sign-off basis:

- The source lines at the tip. Every line reference in the three source
  cells reads as written. Checker `scratch/sv_item21_env_check.py` and
  its log.

- The library read. Probe `scratch/sv_item21_env_probe.jl` and its log.
  site_wind reads 10.000000, 11.007738, 11.009694 and 10.924573 at the
  four altitudes. site_shear(9.4117, 9.4117) reads 1.0 and
  site_shear(9.4117, 4.8) reads 0.908290428006.

- The arithmetic. 10 * (h / 4.8)^(1/7) reproduces every wind read.
  18.8 * sin(30 deg) = 9.4000 m. The swing 0.029 / 5.309 = 0.5462 per
  cent (quotes 0.5 and 0.54).

- The pinned tests. `test/test_bem_unified.jl:202` reads 11.0077,
  `test/test_betz_ceiling_projection.jl:205` reads 11.0097, and
  `test/test_wind_authority.jl:49-54` pins the shape.

Reading rules:

- Quote the exponent as 1/7 or 0.1429. The table pair prints 11.01 at
  9.41.

- The hub altitude quotes 9.4000 m, the design basis. The flown basis
  reads z 8.914 m and 28.64 deg (boundary note 5).

- The swing sentence states the steady-wind basis. It is not a stability
  property. The turbulence line reads the same way.

## The seed generation forms, NR-006 with NR-045 (2026-10-15, science-validator)

This block appends only, under the amend pattern. No signed row changed.

The aero F-VALUE read raises one record query: the NR-006 parenthetical
reads "gen 1, common seed", the strip rule records the pick at (gen 0,
idx 1), and the convergence plate prints no generation beside the seed.
The values agree.

Resolution, after a re-read of the three convergence files against the
three telemetry files:

- The convergence file carries 30 rows, iterations 1 to 30, and no gen-0
  row. Iteration k equals the running-best search objective at generation
  k on all three islands. The read is 90 of 90 at the stored precision
  (3 dp), with maximum deviation 0.0. Checker `scratch/sv_cvr_read_check.py`.

- NR-006 "gen 1" names the convergence file's first read, which carries
  the common seed's value. The seed batch's own generation index reads 0
  in the telemetry column (NR-045: "Generation 0 is the initial
  population (the seed batch)").

Reading rules:

- Text that tags the seed with a generation reads "generation 0"
  (NR-045). The convergence form "iteration 1" stays in convergence-file
  references.

- The convergence plate prints the seed with no generation (NR-006 quote
  form). The drawn form stands.

## Derived row: NR-059, the winner bow read (2026-10-16, science-validator)

This block appends only, under the amend pattern. No signed row changed.

The founder word "up" (2026-10-15) sent the winner bow probe at the aero seat.
The read landed at `c6d2885` with the proposed row, receipt `docs/reporting/room-responses/aero-validator-2026-10-16-winner-bow-probe.md`.
This seat reproduced the read at the tree tip and signs the row.

| ID | Claim | Value | Units | Source | Status |
|---|---|---|---|---|---|
| NR-059 | Winner bow (island 3) | midpoint ring settle 0.002 m, window 0.105 to 0.310 m. Hub max settle 0.002 m, window 0.209 to 0.613 m. Extension end midpoint 0.422 m, hub 0.833 m. Settle and run do not agree on the bowed shape | m | probe `scratch/av_bow_probe.jl` (sha256 `24a1601718dcb2d8536872ca975b6a823fed640e72686486c434fdc6216c73a4`), its log `scratch/av_bow_probe.log` (sha256 `eacc0ce3acbcdeb66b6dd9db975b177ceb401a2929bee2c40fd258e22f2bf987`), both first landed at `c6d2885`. Re-run `scratch/sv_bow_probe_recheck.log`. Checker `scratch/sv_bow_sign_check.py` and its log | signed (science-validator, 2026-10-16) |

Sign-off basis:

- The reproduction. This seat re-ran the committed probe in a detached worktree at `650fa49`. The two logs match line for line. Only the git header and the four wall-time lines differ.

- The bench gates. Both gate lines read true, so the run reproduces the NR-016 readings at this tip. The settle speed reads 10.169820334285198 rad/s.

- The pins. The probe and log sha256 values equal the supply pins. Both blobs first landed at `c6d2885` and read byte-identical at `650fa49`.

- The founder station (midpoint ring, ring 5). Settle 0.00160 m. Window 0.10531 to 0.31005 m, mean 0.22288 m. Extension end 0.42202 m.

- The max station (hub, ring 6). Settle 0.00241 m. Window 0.20862 to 0.61302 m, mean 0.44098 m. Extension end 0.83331 m, raw 0.833774 m.

- The direction. The shape leans straight down, down fraction 0.9999 at settle and 1.0000 at t=200 s. The sideways share stays under 0.003.

- The mapping clause. The max sits at the hub. The midpoint ring reads about half the hub value. The ratio reads 0.5058 at t=50 s and 0.5064 at t=195 s.

- The September check. The settle hands off a straight stack and the run bows it. The largest deviation reads 0.43857 m at ring 6. Per `DECISIONS.md` [2026-09-15] ruling 2 this reads as an instrument finding, not a design question.

- The founder line. The founder measures bow as the midpoint ring belly drop from the common axis. Every midpoint state reads below 0.5 m against the 1.5 m bar.

- The precision basis. The row quotes 3 decimals from the 5-decimal log forms. The checker asserts every quoted form.

- The source cell. The cell takes the two evidence pins and the landing commit at the sign. No value changed.

Reading rules:

- Every bow number quotes with its station and its state.

- The founder station reads the midpoint ring (ring 5). The max station reads the hub (ring 6).

- The settle and run disagreement reads as an instrument finding. It never reads as a design verdict.

- The barred September estimate prints no result. The 1.5 m line is a comparison bar only.

- The glossary entry (v20) carries no value. The value reads from this row.

Counter-read requested from the aero seat.

Evidence: `scratch/sv_bow_sign_check.py` and its log, `scratch/sv_bow_probe_recheck.log`.

## Bow direction scope amend: NR-059 (2026-10-16, science-validator)

This block appends only, under the amend pattern. No signed row changed.

The direction bullet of the NR-059 block carries the sideways bound with no scope. The bound came from the extension series alone. The counter-read at the aero seat (receipt `docs/reporting/room-responses/aero-validator-2026-10-16-nr059-counterread.md`) measured the scored window and the relax phase. It re-ran the same path with the sideways read appended. Its anchors hold, and the window-end speed matches the committed read to 8.882e-15. This block records the true scope.

- The relax sampled peak reads 0.23586 at t=2 s. The window decays from 0.03740 (hub) and 0.03734 (mid) at t=11 s.

- The hub reads under 0.003 from t=37 s, and the midpoint from t=38 s. The extension peak reads 0.00217, and the t=200 read is 0.0002.

- The early motion is the known ~10 s lateral mode (the 2026-09-12 handover section 9). It rings out.

Reading rules:

- The sideways bound reads "over the extension series and from t=38 s onward".

- The scope correction reads in the register only. The draft carries no direction bound, so no report byte moves.

- No row value moves. The row carries magnitudes and the disagreement verdict. The direction bullet is basis text.

Evidence: `scratch/sv_nr059_scope_check.py` and its log, plus the counter-read set `scratch/av_nr059_window_yshare.jl` and its log.

## Cited-form amend: NR-059 (2026-10-18, science-validator)

This block appends only, under the amend pattern. No signed row changed.

The B-20/B-21 candidate the author wrote quotes two forms from this row that the claim cell does not print. The B-21 counter-read at the aero seat verified them at the tip. Receipt `docs/reporting/room-responses/aero-validator-2026-10-18-b21-bow-bound.md`, commit `be063e0`, checker `scratch/av_b21_bow_bound_check.py` and its log, 18 of 18 checks pass. This block records the forms in the row.

- The extension speed spread. The extension run spans t = 50 s to 200 s with samples every 5 s, 29 logged. Its omega spread reads 0.00120 rad/s. The basis reads the 13.3852 rad/s first sample. That reads 0.0090 per cent. The draft quotes 0.009 per cent.

- The extension steps. Over the same series the hub (ring 6, the max station) bow increments per 5 s fall strictly. The first reads 0.02539 m. The last reads 0.00053 m. The draft quotes 0.0254 m to 0.00053 m.

- The station. The step forms read at the hub, the max station, not the midpoint ring. The midpoint series carries no step quote.

Reading rules:

- The spread form reads over the extension run only. The window power swing form (half a per cent, the NR-014 basis) stays outside this row.

- The step forms read at the hub over the extension series, per 5 s.

- The unsigned geometric tail stays outside the row. No asymptote form enters the register or the draft.

Evidence: `scratch/av_b21_bow_bound_check.log`, the probe log pins already carried in the row.

## Source row: NR-060, R5 signed axial force at the winner capture (2026-10-18, science-validator)

This block appends only, under the amend pattern. No signed row changed.

| Row | Claim | Value | Units | Source | Status |
|---|---|---|---|---|---|
| NR-060 | R5 signed axial force at the winner capture | -157.6 to -142.8 (tension), three beams, N/Ncrit -0.09240 to -0.08371 | N | Own re-run at the science seat, scratch/sv_r5_axial_sign/sv_r5_axial_sign.jl, same evaluator chain as scripts/extract_pair_capture.jl, parity bit-exact on nine recorded cold re-eval fields | signed (science-validator, 2026-10-18) |

Reading rules:

- The display form reads -157.622 to -142.792 (tension) at 3 dp. The share display form reads -0.0924 to -0.0837 at 4 dp.

- Full precision. Beam 1 reads -157.62246416260894. Beam 2 reads -142.7923499969138. Beam 3 reads -148.87563768789266.

- Full precision shares. Beam 1 reads -0.09240481892804314. Beam 2 reads -0.08371079157957116. Beam 3 reads -0.08727706685992834.

- N_crit reads 1705.7818627982122 on all three beams. The closure reads N over N_crit, bit-exact on every beam.

- Sign convention. Compression positive (src/ring_element_analysis.jl lines 20, 239 and 272). A negative N reads tension.

- The ring check clips tension. It scores the worst-utilisation beam with max(N, 0) over N_crit (src/sim_frame.jl line 406). The axial share in NR-021 reads 0.0 on R5 for that reason.

Sign-off basis:

- Pins. Exact line pins at src/ring_element_analysis.jl lines 20, 239, 272 and 636, src/sim_frame.jl lines 391 and 406, scripts/compute_seeds.jl line 36, scripts/extract_pair_capture.jl line 52.

- Identity. Blob equality launch equals HEAD equals origin for src/ring_element_analysis.jl, src/sim_frame.jl, scripts/compute_seeds.jl and the winner CSV. The extract script reads HEAD equals origin. It post-dates the launch.

- Closure. The run parity reads bit-exact on all nine recorded cold re-eval fields. Fitness 27.3635412663488. P_mean 5.3087794439367935. P_end 5.314113662272673. FoS_min 14.971791422208508. util_a 0.06679174086635262. util_b 5.334714158942919e-7. T_lift 324.1250954336462. twist_ratio 0.4393474253185575. ω_eq 10.169820334285198.

- Census. Three beams on every ring, R2 to R6. All three R5 beams read negative N.

Boundaries:

- One capture instant. The final integration step of the measurement run, s equals 1724859 at t equals 49.99999483862295 s. This is not a window statistic.

- The other rings read compression in the same capture. R2 to R4 and the hub R6 all hold positive N minima. This row signs the R5 values only.

- The 2.5 to 2.8 times comparison in the aero receipt is prose over this row and NR-021. It is not a signed value of its own.

Counter-read requested from the aero seat.

Evidence: scratch/sv_r5_axial_sign/sv_r5_axial_sign.jl and its log, scratch/sv_r5_axial_sign_check.py and its log.

## NR-060 amend: identity bullet names the wrong launch basis (2026-10-18, science-validator)

This block appends only, under the amend pattern. No signed row changed.

The NR-060 identity bullet reads "Blob equality launch equals HEAD equals origin for src/ring_element_analysis.jl, src/sim_frame.jl, scripts/compute_seeds.jl and the winner CSV."

The winner CSV does not exist at the launch commit `a76c5e9`. It first lands at the data commit `dd3cc6a`. The counter-read at the aero seat caught the over-reach.

Corrected reading: blob equality launch equals HEAD equals origin holds for the three source files only. The winner CSV reads HEAD equals origin, and it first lands at the data commit `dd3cc6a`.

The signed values stand byte-identical. The sign anchor stays.

Reading rule: future quotes of the NR-060 basis read the corrected line. The old bullet wording retires.

Evidence: the aero counter-read receipt, and the strengthened checker re-run at this seat.

## NR-020 note: the Cp pair names its banks (2026-10-18, science-validator)

This block appends only, under the amend pattern. No signed row changed.

The NR-020 source cell reads "The precone rows of `10-precone-sweep.csv` at commanded lambda 4.0 (Cp 0.22540 vs 0.26386)".

The pair names no bank. The review triage item T4-15 asks which Cp belongs to which angle.

Verified against the committed CSV at the source. Line 11 reads precone 0 at commanded lambda 4 with Cp 0.26386. Line 39 reads precone 20 at commanded lambda 4 with Cp 0.22540.

So 0.22540 reads the 20-degree bank and 0.26386 reads the 0-degree bank.

Reading rule: future quotes of the NR-020 Cp pair carry the bank names. The signed values stand byte-identical.

Boundary: the measured TSR on the 20-degree row reads 3.7588. The row cites the commanded lambda. This note carries no new value.

## NR-046 amend: evaluator line pins re-pin past 2bf76a3 (2026-10-18, science-validator)

This block appends only, under the amend pattern. No signed row changed.

The NR-046 source cell pins "`src/objective_evaluator.jl:90-91, 1148, 1161, 1192-1194, 1200-1203`" and reads "Byte-stable from launch `a76c5e9`".

The rope-break arming commit `2bf76a3` added five lines to that file. The `breaks_arm_s` argument and its comment sit at the window-sim call site. Every later line shifted by five.

Verified at HEAD. The old pins read the new numbers. P_score now reads `:1153`. The fitness seam call now reads `:1166`. The swing block now reads `:1197-1199`. The twist clamp and the `1e-6` floor now read `:1205-1208`, with the floor at `:1207`.

The old blob `52669d40` equals the launch blob for this file only. The HEAD blob reads `5c626ff5`.

Reading rule: future quotes of the NR-046 evaluator sites read `src/objective_evaluator.jl:90-91, 1153, 1166, 1197-1199, 1205-1208` at blob `5c626ff5`. The byte-stability claim holds for the other pinned files. It does not hold for this file.

The draft cites `:1207` for the floor. That cite is correct at HEAD. No draft change.

The signed values stand byte-identical. The sign anchor stays.

Evidence: `scratch/sv_nr046_repin_check.py` and its log.

## Source row: NR-061, the six-class 201-reject split at the producing commit (2026-10-18, science-validator)

This block appends only, under the amend pattern. No signed row changed.

| Row | Claim | Value | Units | Source | Status |
|---|---|---|---|---|---|
| NR-061 | Six-class split of the 201 FoS=Inf rejects, classified with the producing code | betz_cp_floor 93, settle_fail 37, spacing 36, rope_break 30, betz_ceiling 3, hub_tip 2 (total 201) | count | Own sharded re-derivation at a76c5e9 (scratch/sv_reject_sixclass_a76c5e9/sv_reject_sixclass_a76c5e9.jl, eight shards over the 201 recorded rejects). Merge scratch/sv_reject_sixclass_a76c5e9/sv_reject_sixclass_merge.py, 317 checks, 0 fail | signed (science-validator, 2026-10-18) |

Reading rules:

- The producing commit armed break detection for the whole run. `2bf76a3` armed it at the relax boundary only. This row carries the producing counts.

- One row moves between the two bases. Island 3, gen 8, idx 4 reads hub_tip at HEAD and rope_break at the producing commit. The break trips before the hub diverges when detection covers the whole run.

- The HEAD re-run reads rope_break 29 and hub_tip 3. The draft prints those two numbers in section 3.1 and section 5. The draft must move to the signed set, 30 and 2.

- Class definitions. betz_cp_floor: the static cp floor reads below 0.8 times the 5 kW floor. settle_fail: the torsional realisability cliff at settle. spacing: the pre-settle spacing gate. rope_break: a line exceeded break strain. betz_ceiling: the static cp floor reads at or above 4.0 kW. hub_tip: hub omega non-finite or the tip-speed sanity check fails.

- The 100 finite-FoS rejects sit outside this row. NR-055 covers the three-way split.

Boundaries:

- The row is a classification of the recorded rejects. It is not a window statistic.

- The probe version that ran carries a census defect. A shard with no hub_tip row raises after every data line flushes. The merge reads the per-row and SPLIT lines, so no count moves. The fixed probe ships with the evidence.

Counter-read requested from the aero seat.

Evidence: scratch/sv_reject_sixclass_a76c5e9/ holds the probe, the merge script, the eight shard logs, the HEAD run log and the merge log.

## Aero counter-read: NR-061 (2026-10-18, aero-validator)

This block appends only, under the amend pattern. No signed row changed.

An independent parse of the eight committed shard logs reads 201
unique rows.

The post-split census reads betz_cp_floor 93, settle_fail 37 and
spacing 36.

It reads rope_break 30, betz_ceiling 3 and hub_tip 2. The sum reads
201.

The 96 under_floor rows carry SPLIT lines.

93 read betz_cp_floor with the cp floor under 4.0. 3 read
betz_ceiling with the cp floor at 4.0 or above.

No other row carries a SPLIT line.

The moved row reads island 3, gen 8, idx 4.

It reads rope_break at the producing commit and hub_tip at the HEAD
re-run.

The HEAD census reads 29 and 3. The producing census reads 30 and 2.

Exactly one row moves.

The evidence sits at `scratch/sv_reject_sixclass_a76c5e9/` and
`scratch/av_nr061_counter_2026-10-18.log`.

## Display amend 2026-10-18 (science-validator)

The science-validator rows now print at four significant digits.
A reading that a shipped plate already labels keeps the shipped
label form. The span (NR-043), the operating speed (NR-029) and
the realisability floor angle (NR-053) read the plate forms.

The manifest file `docs/reporting/register-manifest.md` carries
the full-precision readings. It also carries the NR-043 probe
sha256 and the long source strings.

The fitness rows NR-003 to NR-006, NR-036 and NR-039 now print
the unit `kg-equivalent`. A fitness score folds power and safety
penalties into mass units at the seam weights of NR-046. Real
masses keep `kg`.

The NR-053 notation moves from `dastar` to `δα*`. The NR-046
basis block adopts the same form.

No value changes. Each row keeps its sign-off basis. The
2026-10-18 feedback in `docs/reporting/feedback-on-report.md`
prompts this change.

## Source row: NR-062, the strip milestone power at the seven best-so-far steps (2026-10-18, science-validator)

| Row | Claim | Value | Units | Source | Status |
|---|---|---|---|---|---|
| NR-062 | Window power at the seven strip milestones (the NR-036 steps) | The seven pairs sit in the block below | kW | `docs/reporting/figures/machine-evolution-strip/extract-best-so-far.csv` (certified 2026-10-09). Parity against `island_3/telemetry.csv` bit for bit on all seven rows | signed (science-validator, 2026-10-18) |

| Milestone | P_mean, P_end (kW) |
|---|---|
| gen 0 | 5.85, 5.86 |
| gen 6 | 5.42, 5.4 |
| gen 10 | 5.89, 5.89 |
| gen 18 | 5.78, 5.78 |

| Milestone | P_mean, P_end (kW) |
|---|---|
| gen 22 | 5.76, 5.76 |
| gen 25 | 5.51, 5.52 |
| gen 26 | 5.31, 5.31 |

Sign-off basis:

- The read is a direct extract read. This seat re-reads the seven rows against the island 3 telemetry at data commit `dd3cc6a`.

- The milestone order and identities read from NR-036. The fitness digits agree digit for digit at all seven steps.

- The display forms print the extract digits verbatim. The strip kit certifies those digits.

Boundaries:

- The rows are window statistics of the recorded island 3 run. They are not a new capture.

- The gen 6 P_end prints 5.4 as recorded. That reads as two significant digits, not a rounding defect.

## Source row: NR-063, the corner pick power (2026-10-18, science-validator)

| Row | Claim | Value | Units | Source | Status |
|---|---|---|---|---|---|
| NR-063 | Window power at the four corner picks (the NR-051 identities) | The four pairs sit in the block below | kW | `docs/reporting/figures/machine-corner-grid/extract-corner-grid.csv` (certified). Parity against the island telemetry bit for bit on all four rows | signed (science-validator, 2026-10-18) |

| Pick | P_mean, P_end (kW) |
|---|---|
| i1-g13-i1 | 6.01, 6.07 |
| i1-g7-i7 | 5.33, 5.36 |
| i2-g21-i4 | 5.59, 5.59 |
| i3-g26-i8 | 5.9, 5.9 |

Sign-off basis:

- The read is a direct extract read. This seat re-reads the four rows against the island telemetry at data commit `dd3cc6a`.

- The pick identities and the objectives read from NR-051. The objective digits agree at 3 dp on all four picks.

- The telemetry carries no standalone airborne-mass column. The per-pick mass metric reads the NR-051 objective in kg-equivalent. A true mass decomposition per pick would take a new derivation.

Boundaries:

- The rows are window statistics of the recorded runs. They are not a new capture.

- No mass decomposition rides this row.

## Notation note: NR-050, the projection factor prints as f_proj (2026-10-19, science-validator)

This block appends only, under the amend pattern. No signed row changed.

The formula typesetting pass prints the projection factor of the power sizing as `f_proj` at draft section 2.1.
The display and its definition line carry the token.
The NR-050 sign-off basis names the same factor `f_i` in the decode and `f` in the sizing law.

The rename keeps that factor apart from the score `f` of NR-046.
No value, form or source moves.
The cited row stays NR-050.
The display token reads the factor that NR-050 signs.

## Campaign-plate print rule: quantiles of the feasible mass (2026-10-20)

Proposal: figures seat. Endorsement: aero-validator. Landing: hermes.

Plates print quantiles of the feasible mass (p1 or p5). A sample
minimum is an order statistic of the draw, not a property of the
machine.

Proof on record: one seed and box read a lightest feasible mass of
31.039 kg at N=2,000 and 13.018 kg at N=80,000. The minimum moves
2.4× with the draw; the quantiles hold. The 13.018 kg value
reproduces at three desks.

## Notation note: NR-067 and NR-068, the cartography pair renumbered from NR-064 and NR-065 (2026-10-20, science-validator)

Two signed pairs carried the numbers NR-064 and NR-065 on the same day: this
cartography pair (feasible counts; winner mass and quantiles) and the ladder
census pair (7 pass of 42; cliff 20, stall 14, clearance 1). The ladder pair
keeps 064 and 065, because `docs/reporting/figures/ladder-census/SPEC.md`, the
census record and `figure-map.md` row 28 cite them. This pair moves to NR-067
and NR-068. No value, source, sign-off or boundary changed. No surface outside
this register cites the cartography pair, so no other file moves.

## Source row: NR-067, the cartography feasible counts and the set containment (2026-10-20, science-validator)

| Row | Claim | Value | Units | Source | Status |
|---|---|---|---|---|---|
| NR-067 | Feasible-design counts, LHS cartography, N=80,000, seed 7, beam circular, axial free | 10 kW 45,493 of 80,000 on both sides. 50 kW 41,515 of 80,000 before the fix, 29,230 of 80,000 after | designs | Four files at `f7d3bd0`, each with the `feasible` column and a stamped header. 10 kW body md5 `98e8c266` on both sides. 50 kW bodies `2553bc4f` before and `eac8a4e5` after. Recount script `scratch/sv_lhs_cartography_rows.py`, log `scratch/sv_lhs_cartography_rows.log` | signed (science-validator, 2026-10-20) |

The 50 kW set census:

| Comparison | Count |
|---|---|
| Feasible before the fix | 41,515 |
| Feasible after the fix | 29,230 |
| Feasible on both sides | 29,230 |
| Lost by the fix | 12,285 |
| Gained by the fix | 0 |

Sign-off basis:

- The recount reads the `feasible` column of each file. A count rebuilt from a printed percentage misses by two or three designs, as this handover showed.

- The 10 kW bodies are byte-identical across the fix. One row therefore covers both sides of that box.

- The after set sits wholly inside the before set. No design became feasible.

- A heavier load can only remove feasibility. The containment therefore signs the direction of the fix at row level.

- Of the 12,285 lost designs, 3,721 read plain FoS below 1.8 and 9,101 read torsional FoS below 1.5. Those two sets overlap on 537 designs, so no lost design escapes both gates.

Boundaries:

- Gate constants at this commit are `OPT_FOS_REQUIRED` 1.8 and `OPT_TORSION_FOS_REQUIRED` 1.5.

- The counts read gate acceptance at the design point. They are not a power claim.

- A count belongs to this draw. It does not transfer to another seed or another N.

## Source row: NR-068, the cartography winner mass and the feasible-mass quantiles (2026-10-20, science-validator)

| Row | Claim | Value | Units | Source | Status |
|---|---|---|---|---|---|
| NR-068 | Winner mass and feasible-mass quantiles, LHS cartography, N=80,000, seed 7 | The table below | kg | Same four files at `f7d3bd0`. Quantiles by linear interpolation on the sorted `mass_kg` column. Script `scratch/sv_lhs_cartography_rows.py` | signed (science-validator, 2026-10-20) |

| Box | Side | Winner mass | p1 | p5 |
|---|---|---|---|---|
| 10 kW | both sides | 13.018 | 52.505 | 99.835 |
| 50 kW | before the fix | 66.869 | 324.605 | 592.552 |
| 50 kW | after the fix | 105.907 | 469.651 | 850.438 |

Sign-off basis:

- The quantiles print under the campaign-plate rule of `6d59b11`. Plates print p1 or p5 of the feasible mass.

- The winner mass is a campaign output. It is the least-mass feasible design of this draw.

- Both classes are sample statistics. Each moves with the draw.

- The 66.869 kg design at the true load reads torsional FoS 0.7449 against the 1.5 gate. It fails.

- Its plain FoS reads 2.1901 there. The torsional gate alone rejects it.

- The ratio of 8.3286 to 0.7449 reads 11.1803. That is the inflation factor, taken from two rows of one design.

- The 105.907 kg design sits in the pre-fix file at that same mass, with torsional FoS 21.0125. The fix changed which design wins, not which designs exist.

- On three 2,000-draw subsets of the 10 kW box, p5 stayed within 5.6 per cent of its full-draw value. The minimum read 1.6 to 2.0 times the full-draw minimum.

Boundaries:

- Mass is the `mass_kg` score column. It is not the airborne mass of a flying machine.

- The quantiles describe the sampled feasible population, not a machine.

- The winner mass belongs to this campaign at this draw. It is not the best mass of the design space.

## Amend: NR-048's twist-limit token is withdrawn (2026-10-20, science-validator)

This block amends the signed row. The sizing tokens stand. The twist pair does not print.

| ID | Claim | Value | Units | Source | Status |
|---|---|---|---|---|---|
| NR-048 (amended) | The sizing pair, after the twist-limit amend | The load-step case stands at `k_mppt × 2` and `F_helix ≈ 1278 N/vertex`. The twist pair is withdrawn: `87.9°` has no resolved object and `78.8°` has no derivation at HEAD | N/vertex, degrees | `DECISIONS.md` [2026-09-06]; `docs/plans/2026-09-06-closed-form-beam-sizing.md` section 7.1; `src/trpt_twist_limit.jl`; `src/objective_evaluator.jl:448`; check `scripts/check_nr048_twist_limit.py` | amended (science-validator, 2026-10-20) |

Sign-off basis:

- Token check. `scripts/check_nr048_twist_limit.py` exits 0 at this commit. It recomputes both per-segment limits from the decoded geometry and solves for the radius that gives 78.8°.

- The sweep machine decodes to one radius, 0.863 m, on rings one to five. Its top ring reads 4.320 m. Its crossing limit reads 84.53° on segments one to four and 43.51° on segment five. Segment five binds. Its over-twist limit reads 93.39° on segments one to four. Segment five has no over-twist limit.

- The strip winner reads 85.20° crossing on segments one to four and 41.59° on segment five. Its over-twist limit reads 92.89°. That agrees with the NR-022 S5 value.

- 78.8° equals no segment limit on either machine. The nearest is 84.53°, 5.73° away.

- A 3.76 m segment carries a 78.8° crossing limit only when its larger ring radius is 1.305 m. Neither machine carries that radius.

- The number predates the criterion. The sweep ran on 2026-09-06. The Tulloch (4.34) authority landed on 2026-09-25 at `996c970`, and the capacity fix at `c104737`, both 19 days later.

- The 87.9° reading is a measured value. It cannot be a segment-five value, because a crossing at 43.51° stops the run. It is either a segments-one-to-four value or a shaft total. The uncommitted console record does not say which.

Printing rules until the re-derivation:

- Neither numeral prints. A comparator that has no derivation cannot support a violation claim. 87.9° alone states no claim.

- The sizing tokens print as before: "twice the nominal load" and "about 1278 N/vertex".

- The mechanism of the refusal stands without either numeral. The load law holds the speed in high wind, and easing k removes that hold.

- The phrase "collapse limit" names neither limit in the current code. The crossing limit is a collapse detector. The over-twist limit is the torque peak. A later version must name which one it prints.

Boundaries:

- Boundary 2 of the signed row read "the 78.8° limit is the era machine's hub-segment collapse limit; a machine move re-reads it". That boundary is falsified. The machine did not move. The criterion changed under it.

- `DECISIONS.md` [2026-09-06] still prints the pair. It is a dated record of the reasoning on that day, not a live claim. This row governs what the draft prints.

- The 25 m/s case in the plan stays out of the draft. It was never printed.

- This amend covers the twist token only. The 1278 N/vertex counter-read at `07e2eb9` stands.

The re-derivation needs:

- The committed sweep, script and console record, at a named hash.

- The object of 87.9°: the worst segment or the shaft total.

- The comparator at HEAD on that object.

- The geometry that produced 78.8°, because the decode at HEAD of the same committed genome does not produce it.

## Correction: the object of the 87.9°, in the NR-048 amend above (2026-10-20, science-validator)

Aero-validator's reply found two errors in the amend block. This block corrects them. The withdrawal stands.

- The "stops the run" sentence is wrong. The sweep runs `run_canonical_sim!` bare (`scratch/scenario_sweep.jl:53` and `:75`). The crossing gate lives in the evaluator (`objective_evaluator.jl:914`), and the sweep never calls it. A twist past a segment limit is recordable there. A segment-five value is possible.

- The "shaft total" candidate is wrong for a second reason. The sweep samples twist per segment (`scenario_sweep.jl:81`). It reports one value, the twist on the segment that carries the peak helix force, at the instant of that peak (`:100` to `:110`). So 87.9° is a per-segment value, and it is the peak-force segment's.

- That places it better than "undetermined". The 1278 N/vertex and the 87.9° print from one report, on one segment, in one scenario (`:108` and `:110`). The record names that segment the hub segment.

- On the hub segment the corrected authority gives no over-twist limit. The segment is case B, with `r_a + r_b` = 5.18 m against `L_seg` = 3.76 m. The formula crossing limit is 43.51°. Whether a case-B segment keeps a crossing limit at all is the open ruling at `rope_forces.jl:589`.

- So the candidate comparators are 43.51° and no limit. 84.53° belongs to segments one to four and cannot be the comparator for a peak-force reading on the hub.

- One committed-sweep re-run settles it, because the script prints the segment index beside the force. The console record of 2026-09-06 would have carried it, and it is still not in the tree.

- The printing rule does not change. Neither numeral prints.

## Derived row: NR-066, the seven strip-panel decoded masses (2026-10-20, science-validator)

| ID | Claim | Value | Units | Source | Status |
|---|---|---|---|---|---|
| NR-066 | The decoded mass of each machine-evolution strip panel, and the two label forms | The table below | kg, kg-eq | `docs/reporting/figures/machine-evolution-strip/extract-mass.csv` at `0c92e9b`, decoding commit `06ab49c`; generator `scripts/strip_mass_decode.jl`; input `extract-best-so-far.csv` at `dd3cc6a` | signed (science-validator, 2026-10-20) |

| Panel | Gen | Objective (kg-eq) | Mass (kg) | Penalty (kg) | Residual (kg) |
|---|---|---|---|---|---|
| 1 | 0 | 36.109 | 31.509 | 4.580 | 0.021 |
| 2 | 6 | 32.293 | 30.217 | 2.012 | 0.064 |
| 3 | 10 | 31.661 | 25.425 | 6.167 | 0.069 |
| 4 | 18 | 30.929 | 26.464 | 4.430 | 0.035 |
| 5 | 22 | 29.854 | 25.557 | 4.254 | 0.043 |
| 6 | 25 | 28.315 | 26.172 | 2.127 | 0.016 |
| 7 | 26 | 27.364 | 25.670 | 1.652 | 0.042 |

Sign-off basis:

- Value check. I ran the decode myself at `4e19fa7`, before the kit file landed. All seven masses reproduce to four decimals. The values in the CSV are those values.

- Lifter. `m - m_nolifter` reads 5.000 on all seven. `include_lifter` defaults true (`expansion_analysis.jl:45`), so the scored mass carries the 5.0 kg lifter. The sign is on the lifter-inclusive form.

- Identity. The decode reproduces `n_lines` 3 on all seven, rings 9/5/7/5/5/5/6, and `r_hub` to four decimals. The generator asserts all four columns against the record and aborts on a mismatch before it prints a mass.

- Penalties. The three terms are charged on `P_end`, the value the score used (`objective_evaluator.jl:1153`). Inverting `P_mean` instead reads a negative residual on panel 2, and a negative residual is impossible.

- Residual. The remainder is the stationarity term, `10 * max(0, P_range/P_mean - 0.2)` (`:1197`). It reads 0.016 to 0.069, which is positive on all seven as the algebra requires. `P_range` is not recorded, so the residual is a bound and not an allocation.

- Panel 3 is lighter than the winner. It reads 25.425 kg against 25.670, and loses on penalty, 6.167 against 1.652. The winner pays 0.245 kg of mass to shed 4.515 kg of penalty.

Reading rules:

- Print `mass 25.670 kg` and `objective 27.364 kg-eq`. One mass form and one score form per panel.

- Print mass to three decimals as a decomposition against a three-decimal objective. Do not print it as a measurement.

- Do not print the penalty per panel. The caption carries the decomposition once. It names the penalty as charged on `P_end` and the remainder as the stationarity term that the recorded columns cannot allocate.

- Do not describe the mass line as flat. It dips at panel 3 and returns. State that the later panels buy penalty reduction at near-constant mass.

Boundaries:

- Decode only. No simulation ran.

- The mass is the quantity the campaign scored. It is not a measured mass.

- A mass belongs to this genome at this era. A machine move re-reads it.

- The 420 g/span³ anchor (`parameters.jl:18`) sets the model scale. Three decimals are a decomposition, not a resolution.

## Amendment: NR-066, the seven values move to the wind the score used (2026-10-20, science-validator)

The first cut decoded at the wrong rated wind. The row above stays in place as the superseded record. This block carries the corrected values and the one check that catches the defect.

| ID | Claim | Value | Units | Source | Status |
|---|---|---|---|---|---|
| NR-066 (amended) | The decoded mass of each machine-evolution strip panel on the wind the campaign scored, and the two label forms | The table below | kg, kg-eq | `docs/reporting/figures/machine-evolution-strip/extract-mass.csv` at `ce9c5d8`. Decoding commit `3307af6`. Generator `scripts/strip_mass_decode.jl`. Input `extract-best-so-far.csv` at `dd3cc6a` | amended (science-validator, 2026-10-20) |

| Panel | Gen | Objective (kg-eq) | Mass (kg) | Penalty (kg) | Residual (kg) |
|---|---|---|---|---|---|
| 1 | 0 | 36.109 | 31.5535 | 4.5797 | -0.0241 |
| 2 | 6 | 32.293 | 30.2612 | 2.0122 | 0.0196 |
| 3 | 10 | 31.661 | 25.4657 | 6.1670 | 0.0283 |
| 4 | 18 | 30.929 | 26.5048 | 4.4302 | -0.0060 |
| 5 | 22 | 29.854 | 25.5935 | 4.2539 | 0.0065 |
| 6 | 25 | 28.315 | 26.2020 | 2.1266 | -0.0136 |
| 7 | 26 | 27.364 | 25.6985 | 1.6524 | 0.0132 |

The defect:

- The decode called `design_from_vector_v10` without `v_rated`. That function then takes its default, `p.v_wind_ref` = 11.0097 m/s. The score path passes `cfg.v_rated` = 11.0 (`objective_evaluator.jl:721`).

- The gap is 0.09 per cent, and it sizes the rings light. The seven masses move up by 0.0284 to 0.0448 kg on the corrected basis.

- The four identity asserts cannot see it. `n_lines`, `n_rings`, `r_hub` and `n_active` carry no wind dependence.

The check that catches it:

- NR-018 signed the winner air mass at 25.70 kg on 2026-10-08, and its sign-off basis prints 25.6984682562368789. The same block names 25.670101 kg as the off-basis counter-value of the old failure mode.

- The first cut reproduced that counter-value to four decimals. This seat signed a number that the register already carried as the known bad read, one section above the row that signs it.

- The Phase 0 re-eval log prints the same mass as the argument the fitness took, 25.69846825623688 kg (`.julia_depot/logs/sv_p0_secondread_winner_reeval_2026-10-08.log`). I read 25.6984682562368789 there, which is the same Float64 as my own print.

- I ran the committed generator in a detached worktree at `3307af6`. The winner prints `25.69846825623688`, the same Float64, and `m - m_nolifter` prints `5.0` exactly.

- The same run reproduces all seven rows of the landed CSV byte for byte. One line differs, the header, which stamps `3307af6` in my run and `9423310` in the file as it stood at `3307af6`.

- So the numbers come from `3307af6`. The `9423310` stamp names the commit whose working tree ran the generator before the knob fix. The header re-pin is a one-line change and no value moves. It landed at `ce9c5d8`.

- The file cite reads `ce9c5d8` and the decode cite keeps `3307af6`.

- The tree at `3307af6` carries the same seven values under a header that names `9423310`. A reader who opened that tree would see the wrong stamp.

- The log `scratch/sv_nr066_vrated_rederive_20261020.log` carries both runs and the bound table. A reviewer can check the pair without a worktree.

What the first cut got wrong beyond the values:

- The first-cut residual read 0.016 to 0.069 and I signed it as the stationarity term. That reading is false.

- A mass that is low by `d` adds `d` to the residual by construction. The first-cut residual was the mass error, not a stationarity charge.

- On the corrected mass the residual reads -0.024 to 0.028 and changes sign on three panels. It is the `P_end` rounding bound of the two-route check.

- The bound holds per panel. The over-power term reads the two-decimal `P_end` column, so its error is at most `10 * (P_end - 5) * 0.005`. Every residual sits inside that bound, and every row closes to 0.0001 through objective = mass + penalty + residual.

What stands:

- The penalty inversion. The score takes `P_end` (`objective_evaluator.jl:1153`), so the three penalties charge on it. That call was right, and the CSV keeps it.

- The reason I gave for it was not sound on the first-cut numbers. A positive residual cannot carry that argument while the mass is 0.03 to 0.04 kg light.

- The label forms stand. `kg` for mass, `kg-eq` for the score, one form of each per panel.

The panel-3 clause, corrected:

- Gen 10 reads 25.4657 kg against 25.6985 for the winner, and 6.1670 kg of penalty against 1.6524.

- The winner pays 0.2328 kg of mass to shed 4.5146 kg of penalty.

- The band across gens 10 to 26 reads 1.0391 kg, and the objective falls 4.2970 kg over the same span. Both hold from the first cut.

Reading rules:

- Print `mass 25.698 kg` and `objective 27.364 kg-eq`. One mass form and one score form per panel.

- Print mass to three decimals as a decomposition against a three-decimal objective. This table carries four, at the precision of the CSV.

- Three masses are half-way cases at the fourth digit. The even form reads 31.554, 25.594 and 25.698, and the plate prints that form.

- Do not print the penalty per panel. The caption carries the decomposition once. It names the penalty as charged on `P_end`, and the remainder of 0.013 kg on the winner as the `P_end` rounding bound.

- Do not call the remainder a stationarity allocation. The recorded columns cannot separate it from rounding.

- Do not describe the mass line as flat. It dips at panel 3 and returns. State that the later panels buy penalty reduction at near-constant mass.

Boundaries:

- Decode only. No simulation ran.

- The mass is the quantity the campaign scored. It is not a measured mass.

- A mass belongs to this genome at this era. A machine move re-reads it.

- The 420 g/span^3 anchor (`parameters.jl:18`) sets the model scale. Four decimals in this table are a decomposition, not a resolution.

## Re-derivation read: NR-048 against the sweep at HEAD (2026-10-20, science-validator)

I ran `scratch/scenario_sweep.jl` at HEAD. The script has a single commit, `0b77b53` of 2026-09-07, one day after the record. No later revision exists, so this is the only committed form of the sweep. Log: `.julia_depot/logs/sv_scenario_sweep_rederive_20261020.log`.

- Segment identity. Every peak `F_helix` reading lands on segment five. The record's "hub segment" placement holds.

| Scenario | max `F_helix` (N/vertex) | segment | twist at that instant (deg) |
|---|---|---|---|
| Lull, 11 to 3 m/s | 87.2 | 5 | 24.22 |
| Gust, 11 to 25 m/s | 347.2 | 5 | 21.96 |
| Load step, `k_mppt × 2` | 186.9 | 5 | 37.78 |
| Load step, `k_mppt × 3` | 260.9 | 5 | 47.31 |
| k ease, the wrong feather | 89.6 | 5 | 23.26 |

- Neither token reproduces in any scenario. The record's 1278 N/vertex has no match, and the nearest is the ×3 load step at 260.9. The record's 87.9° has no match, and the k-ease case reads 23.26°.

- The script prints no maximum twist. The only twist it prints is the peak-force instant's (`scenario_sweep.jl:110`). So 87.9° has no printing path in the committed script. It was either read off the sample array outside the script or it came from another tool.

- The machine moved after the sweep. The bank derate landed at `94223eb` on 2026-10-01 and the wind authority at `95c385d` on 2026-10-03. The record's loads belong to a machine from before both.

Consequences:

- The twist pair stays withdrawn. The comparator question is now secondary to the source question, because neither token survives a re-run.

- The sizing token holds as the 2026-09-06 record form. It does not hold as a value of the current machine. The draft's sentence reads as the current machine, so it must not print 1278 N/vertex as one.

- The feather gap is unchanged. High-wind feather is still unmodelled, as boundary 1 of the row says. The high-wind structural case still cannot be sized.

- What the row needs is an era ruling, not another read: does section 2.2.2 describe the 2026-09-06 machine or the campaign machine? On the first answer the tokens print as dated record forms. On the second they need a full re-derivation on the campaign machine.

- Boundary on the case-B call. The hub-segment limits use `L_seg` as the tether chord. That is exact for the equal-radius segments and an approximation for the flare. Aero-validator reports the case-B margin at 0.075 m on that chord. If the settled chord exceeds `r_a + r_b`, case A applies and a dcrit exists on the segment. No value near 78.8 emerges either way.

- The draft's section now prints neither token. The refusal keeps its mechanism, and the sizing sentence keeps "twice the nominal load" without a number. That is the end state unless the era ruling restores a dated form.

## Source row: NR-064, the 42-cell ladder census at 581d33f (2026-10-20, science-validator)

| Row | Claim | Value | Units | Source | Status |
|---|---|---|---|---|---|
| NR-064 | Cell verdicts on the 42-cell ladder re-run | 7 pass of 42 | count | `scripts/results/ladder_v13_rerun_2026-10-20.csv` md5 74408ea185deb9a9920f755d6395ec45, four stamp lines and 42 data rows | signed (science-validator, 2026-10-20) |

| rung kW | pass | lengths that pass | P_gen kW |
|---|---|---|---|
| 5 | 6 of 6 | 12 to 40 | 5.57 to 6.42 |
| 7 | 1 of 6 | 18 | 8.33 |
| 10 to 50 | 0 of 30 | none | 0 to 0.13 |

Sign-off basis:

- The read is a fresh read of the shipped CSV. The file holds 47 lines. Four lines carry the stamp, one line carries the column names, and 42 lines carry the cells.

- The `verdict` and `class` columns agree in all 42 rows.

- The producing harness is a scratch probe at md5 bb59e12f83328dd504e67a7bf58e392b. Its `ladder_cell` is byte-identical to the one in `scripts/ode_ladder_v13.jl` at md5 250a41d04e1f66f78f133c25c15d82c8. The rung and length lists match too.

- Three differences separate the probe from the in-tree script. It writes another path. It adds two columns, `wall_s` and `err`. It wraps each cell in a try/catch.

- The in-tree script cannot write this file. Its output path is `scripts/results/ladder_v13.csv`.

- `P_gen_kW` is the final window sample. It prints two decimal places. It is not a window mean. The gate compares the same sample against 5.0 kW.

- The acceptance floor is 5.0 kW at every rung (`MIN_P_GEN_KW`, `scripts/ode_gate_v13.jl:27`, applied at line 224). The `p_floor_kw=KW` argument at line 142 sizes the beams. It does not set acceptance.

- Four other conditions complete the test. Clearance reads 1.5 m or more. Ground speed reads above 0.5 rad/s. No twist crossing occurs. No line breaks.

Boundaries:

- A pass is gate acceptance at the design point. It is not a claim that a cell meets its rung rating.

- The 7 kW pass reads twist ratio 0.96 against a crossing at 1.00. It is one point at the edge, not a band with margin.

- The old `scripts/results/ladder_v13.csv` is not part of this row. No cell in the two grids shares a seed.

- No numeral from the mechanism paragraph is signed here. That covers `k_mppt` 8.23 and 1122.63, sin delta alpha 313, and the Betz ratio band 0.44 to 0.81.

- The header comment at `scripts/ode_ladder_v13.jl:6` still reads 2.5 kW. The code uses 5.0 kW. The comment stays, because an edit would move md5 250a41d0 and break this anchor.

## Source row: NR-065, the failure classes of the 35 failing cells (2026-10-20, science-validator)

| Row | Claim | Value | Units | Source | Status |
|---|---|---|---|---|---|
| NR-065 | Class split of the 35 failing cells | cliff 20, stall 14, clearance 1 | count | same CSV, `class` column, re-derived from three columns | signed (science-validator, 2026-10-20) |

| class | count | gate signature |
|---|---|---|
| cliff | 20 | the settle raised. P_gen 0, w_gnd 0, twist 0. |
| stall | 14 | the settle completed. w_gnd 0.46 to 0.85 rad/s. P_gen 0.13 kW or less. |
| clearance | 1 | 7 kW at 12 m. P_gen 10.71 kW. The ground check fails. |

Sign-off basis:

- The class reproduces from the CSV columns with no exceptions. A false verdict with all three values at zero reads cliff. The 7 kW cell at 12 m reads clearance. Every other false verdict reads stall.

- That rule returns 20, 14 and 1. It agrees with the shipped column in all 42 rows.

- The two cells that the wall-time cut misplaced read cliff by this rule. They are 7 kW at 25 m and 15 kW at 40 m.

Boundaries:

- The class names the gate signature. It does not name a physical cause beyond the settle behaviour.

- The stall band reads `w_gnd` at the final window sample. The CSV prints no speed history.

## Source row: NR-069, the window-end power bound of the ok population (2026-10-20, science-validator)

| Row | Claim | Value | Units | Source | Status |
|---|---|---|---|---|---|
| NR-069 | Window-end power bound over the ok evaluations, three-island campaign | 508 ok of 930. 0 below 5.00. Exactly 1 records 5.00. Next lowest 5.02. Highest 6.33 | kW, count | The three telemetry files at data commit `dd3cc6a`: `scripts/results/v13_5kw_masslift_len18.8_rotorcount_bankderate2/island_1..3/telemetry.csv`, 310 rows each. Read of the `status` and `P_end` columns. Recount script `scratch/sv_floor_bound_2026-10-20.py` | signed (science-validator, 2026-10-20) |

The tightest pass:

| field | value |
|---|---|
| identity | island 1, gen 8, idx 4 |
| fitness | 33.684 |
| P_mean | 5.02 kW |
| P_end | 5.0 kW |
| running-best hold | generation 8 through generation 14 |

Sign-off basis:

- All 930 rows read. The status column returns 508 ok, the same count NR-002 signs. The 422 non-ok rows carry no score and no bound here.

- No ok row reads below 5.00, and the gate makes that structural as well as measured: the fitness function returns infinity below the floor (`objective_v12.jl:143`), so a recorded ok cannot sit under it.

- Exactly one ok row records 5.00 at the file's precision, and the next lowest records 5.02. The highest recorded P_end is 6.33. The window mean spans 5.02 to 6.32, the range NR-007 signs.

- The 5.00 row is island 1, gen 8, idx 4: fitness 33.684, window mean 5.02, window end 5.0. Its window end sits below its own window mean. It holds the island 1 running-best place from generation 8 through generation 14, and the place changes at generation 15.

Boundaries:

- The values are recorded precision, not full precision. `5.0` is a recorded form, bounded below by the gate at 5.00. The count is a count of recorded forms.

- The population is the ok rows of this campaign at this commit. It does not transfer to another run, seed or floor.

- This row signs the floor sentence and the `one design of 508` label on the `machine-power-trend` plate. It signs no rate, no trend and no value on any other plate.

## Source row: NR-070, the sixteen window-end powers of the power-curve sweep (2026-10-20, science-validator)

| Row | Claim | Value | Units | Source | Status |
|---|---|---|---|---|---|
| NR-070 | Window-end power, window-mean power, FoS and twist at each swept hub wind, one fixed design | The sixteen-row table below | kW, -, - | `scratch/av_power_curve_sweep.csv` md5 `a4e535af18da220a473db963c45ceb76`. 18 data rows: 16 unique winds at `rep` 1 plus two settle repeats. The header carries commit `8a757f3`, src tree `4dd7e0d9`, probe sha256 `59718a02…`, SITE_DAISY 10.0 m/s at 4.8 m, exponent 1/7 | signed (science-validator, 2026-10-20) |

| wind (m/s) | status | P_end (kW) | P_mean (kW) | FoS_min | twist_ratio |
|---|---|---|---|---|---|
| 6.5 | reject | 1.093994 | 1.092380 | 32.704172 | 0.416771 |
| 7.0 | reject | 1.366255 | 1.364468 | 29.752359 | 0.421219 |
| 7.5 | reject | 1.680178 | 1.678294 | 26.993186 | 0.425021 |
| 8.0 | reject | 2.038947 | 2.036877 | 24.696609 | 0.428164 |
| 8.5 | reject | 2.445569 | 2.443214 | 22.520148 | 0.430749 |
| 9.0 | reject | 2.902913 | 2.900285 | 20.680794 | 0.433052 |
| 9.5 | reject | 3.414044 | 3.411095 | 18.988440 | 0.435024 |
| 10.0 | reject | 3.981952 | 3.978620 | 17.539592 | 0.436489 |
| 10.5 | reject | 4.609590 | 4.605547 | 16.173981 | 0.437929 |
| 11.0 | ok | 5.300088 | 5.294669 | 15.001751 | 0.439310 |
| 11.0097 | ok | 5.314114 | 5.308779 | 14.971791 | 0.439347 |
| 11.5 | ok | 6.056351 | 6.051141 | 13.908245 | 0.440475 |
| 12.0 | ok | 6.881276 | 6.875770 | 12.996911 | 0.441384 |
| 12.5 | ok | 7.778057 | 7.772013 | 12.065940 | 0.442217 |
| 13.0 | ok | 8.749638 | 8.743000 | 11.269332 | 0.442857 |
| 13.5 | ok | 9.798986 | 9.791677 | 10.552599 | 0.443446 |

Sign-off basis:

- Direct reads of the `status`, `P_end_kW`, `P_mean_kW`, `FoS_min` and `twist_ratio` columns at the md5 above. The 16 unique winds are 6.5 to 13.5 in 0.5 steps plus 11.009694 at full precision.

- The mass column reads 25.698468 kg on all 18 rows. NR-066 signs the winner mass.

- The identity row reproduces the recorded evaluation: P_end 5.314114 kW against 5.31 kW recorded, and the fitness pair reads in NR-071.

- One machine at one hub altitude: `h_ref_m` reads 9.411699 on every row, and `v_rated` 11.0 and `k_mppt` 2.24 hold on every row (NR-015).

- The top point tracks the cube. 9.798986 / 5.314114 = 1.84395 against (13.5/11.009694)^3 = 1.84364. No clamp flattens the top of the sweep.

Boundaries:

- `P_end` is the final window sample, the statistic the score charges. `P_mean` is the window mean. The plate draws `P_end`.

- The reject rows carry measured power. Their split reads in NR-072.

- The values belong to this genome, this base and this rating. They do not transfer to another machine.

## Source row: NR-071, the score pair at the two 11 m/s points (2026-10-20, science-validator)

| Row | Claim | Value | Units | Source | Status |
|---|---|---|---|---|---|
| NR-071 | The score at 11.0 and 11.0097 m/s, and the identity reproduction | 11.0 m/s: 27.318058525862. 11.0097 m/s: 27.363541266349. Recorded: 27.3635412663488. The identity window end reads 5.314114 kW against 5.31 kW recorded | kg-eq, kW | The same CSV rows at md5 `a4e535af…`. The recorded values read from the campaign winner row, `best_vector.csv` at data commit `dd3cc6a`; the recorded 5.31 kW is also the gen 26 form NR-062 signs | signed (science-validator, 2026-10-20) |

Sign-off basis:

- The identity row agrees with the recorded winner row to 2e-13, eleven decimal places.

- The 11.0 point scores 0.045483 lower than the 11.0097 point. The design point is therefore not an optimum on the sampled grid, and the plate makes no optimum claim.

- The difference is deterministic, not a settle spread. The two rows share genome, rating and gain. Their P_end values, 5.300088 and 5.314114, differ, and the over-power charge prices the difference.

Boundaries:

- Fitness is the campaign objective in kg-equivalent. It is not a mass and not a machine-quality score.

- The pair bounds a flat region. It does not locate a maximum.

## Source row: NR-072, the status split of the power-curve sweep (2026-10-20, science-validator)

| Row | Claim | Value | Units | Source | Status |
|---|---|---|---|---|---|
| NR-072 | Status split of the sweep: floor rejects and scoring rows | 9 reject and 7 ok over 16 unique winds. All nine rejects carry finite P_end, 1.093994 to 4.609590 kW. Zero gate rejects | count, kW | The `status` and `P_end_kW` columns of the same CSV at md5 `a4e535af…` | signed (science-validator, 2026-10-20) |

Sign-off basis:

- Every reject row carries a finite P_end. No row carries NaN. The twist, Betz and hub gate-reject path did not fire in this sweep.

- The floor crossing sits between 10.5 m/s (4.609590, reject) and 11.0 m/s (5.300088, ok).

- The lowest scoring P_end is 5.300088 at 11.0 m/s. The highest is 9.798986 at 13.5 m/s (NR-070).

- The counts read the `status` column over the 16 unique winds. The two `rep` 2 rows repeat the identity and 13.5 evaluations and add no wind.

Boundaries:

- A floor reject is a measurement the score refuses. It is not a failed run.

- The split is a count. It is not a rate and not a pass fraction.

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
| NR-003 | Island 1 best fitness | 30.578 (found gen 30) | kg | island_1/convergence.csv | signed (science-validator, 2026-10-08) |
| NR-004 | Island 2 best fitness | 30.637 (found gen 30) | kg | island_2/convergence.csv | signed (science-validator, 2026-10-08) |
| NR-005 | Island 3 best fitness | 27.364 (found gen 26) | kg | island_3/convergence.csv | signed (science-validator, 2026-10-08) |
| NR-006 | All-island start point | 36.109 (gen 1, common seed) | kg | convergence.csv | signed (science-validator, 2026-10-08) |
| NR-007 | P_mean range, ok rows | 5.02–6.32 | kW | telemetry, ok only | signed (science-validator, 2026-10-08) |
| NR-008 | Winner P_mean (island 3) | 5.309 / P_end 5.314 | kW | island_3 telemetry / re-eval (§4, Phase 0 audit) | signed (science-validator, 2026-10-08) |
| NR-009 | Winner FoS (island 3) | 14.972 | — | island_3 telemetry / re-eval (§4, Phase 0 audit) | signed (science-validator, 2026-10-08) |
| NR-010 | Winner T_lift (island 3) | 324.1 | N | island_3 telemetry / re-eval (§4, Phase 0 audit) | signed (science-validator, 2026-10-08) |
| NR-011 | Winner geometry (island 3) | n_lines 3, rings 6, n_active 1, r_hub 4.580 m, r_bot 0.804 m, bank_bot 22°, blade scales 0.82/0.20 | — | decode of best_vector.csv | signed (science-validator, 2026-10-08) |
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

## Caption rows: NR-017, NR-018 (2026-10-08, science-validator)

These rows exist for caption binding under F-VALUE. NR-017 binds the hero
blade tag bank annotation. NR-018 binds the score decomposition mass.
This block appends only, under the amend pattern. No signed row changed.

| ID | Claim | Value | Units | Source | Status |
|---|---|---|---|---|---|
| NR-017 | Winner main-rotor bank (island 3) | 7.088° at ring 6. Slot 8 = 22° reaches no rotor at n_active 1 | deg | decode probe d219b6c. Threading src/objective_v10.jl:339 | signed (science-validator, 2026-10-08) |
| NR-018 | Winner airborne mass (island 3) | 25.69846825623688 | kg | audit §4 + probe 0c4046b | signed (science-validator, 2026-10-08) |

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
| NR-021 | Ring check at the winner operating point (island 3): interaction, shares and FoS per checked ring | R2 0.03323714455441065 = 0.033223570205929 + 1.3574348481652112e-5, FoS 30.086820435580936. R3 0.033548608446737266 = 0.03354237801917142 + 6.230427565848155e-6, FoS 29.80749563987516. R4 0.028380221733419368 = 0.028374815022862057 + 5.40671055731162e-6, FoS 35.23580644975869. R5 3.058346201008972e-6 = 0.0 + 3.058346201008972e-6, FoS 326974.1011237028. R6 hub 0.06652238395895148 = 0.06652164721153939 + 7.36747412096439e-7, FoS 15.032534020684876 | — | Extract `docs/reporting/figures/pair-extract/extract-winner-operating-point.csv`, ring block. Emitted by `capture_extended`; `max_util` re-derived via `ring_element_analysis`; A1 identity checked, residual 0.0 at every ring | signed (aero-validator, 2026-10-08) |
| NR-022 | Segment twist and over-twist limit at the winner operating point | abs(dalpha): S1 33.94561934829036°, S2 33.811870056223555°, S3 33.67952027817454°, S4 33.54707806507812°, S5 22.821871326820364°. dcrit: S1 to S4 98.85908296054023°, S5 92.64281134151318°. has_limit true on all five | deg | Extract, segment block. Raw reads from the stored alpha block; `trpt_twist_limit` on the rope_forces C1 call pattern (node radii, mean line rest length) | signed (aero-validator, 2026-10-08) |
| NR-023 | Segment torque pair at the winner operating point | segment_torque: S1 396.791634149159, S2 397.1554424859068, S3 397.45360112890063, S4 397.68800908436924, S5 397.1777954649229. torque_capacity: S1 805.0097155967861, S2 808.6780945063998, S3 812.213802301376, S4 815.650844050359, S5 1069.9324759682652 | N·m | Extract, segment block. Capacity = `trpt_torque_capacity_axial` at `trpt_axial_force` of the same state. One instant for both series | signed (aero-validator, 2026-10-08) |
| NR-024 | Evaluator step law | dt = min(4e-5 s, 4e-5 s × sqrt(L_min / 0.5 m) / 1.5). Winner derived step 2.8987873697672758e-5 s | s | Source read at `f8114be`: `src/initialization.jl:564-595`. Winner value from the extract log | signed (aero-validator, 2026-10-08) |
| NR-025 | Cold-start protocol (campaign setting) | Settle `settle_to_operational_state` (n_op 150000 steps, about 6 s simulated; ω_rated_max 60.0 rad/s), then kickstart off (kickstart_s 0.0; the legacy kick is -60.0 N·m·s²/rad², about 115 times the MPPT torque), then one combined relax+window run, 10 s + 40 s, rope breaks enabled across both. Winner run: 1724859 steps | s, steps | `src/objective_evaluator.jl:774, 840-842, 856-892, 978-989`; `src/initialization.jl:2184-2190`; `scripts/run_v13_5kw_masslift.jl:157` | signed (aero-validator, 2026-10-08) |
| NR-026 | Lifter sizing margin (campaign regime) | margin 1.5 (vertical force at the lift bearing = 1.5 × m_airborne × g); line tension = F_vert / sin(70°), flat at all wind speeds; m_airborne excludes the lifter's own 5 kg (the kite carries itself) | — | `src/lift_kite.jl:197-228`; regime line `scripts/run_v13_5kw_masslift.jl:111` | signed (aero-validator, 2026-10-08) |

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

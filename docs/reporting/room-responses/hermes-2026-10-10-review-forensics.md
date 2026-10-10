# Review forensics packet (hermes seat, 2026-10-10)

Five read-only forensics, dispatched against the review work division.
Every claim cites file:line or commit. No files changed by the
forensics. Validators sign the rows next.

## 1.5 closed: why the 10-05 screen failed at 18.8 m

The screen ran a different machine. Its genome is byte-identical to
the bankderate-v1 island-3 winner. The bankderate2 winner did not
exist yet.

The cp fix is a82cafd. The screen ran on f225e95 before the fix and
a82cafd after it. Both are ancestors of launch a76c5e9. The 18.8 m
rows read 3.7955 kW before and 4.2332 kW after. Both fail the 5.0
floor.

The cause is the D1 site-wind landing (6f4cdbe, 2026-10-03). Its
re-baseline 5191465 records the span shrink. The pre-D1 decoder read
8.66 m/s, so the blade span shrank from 1.3485 to 0.9484 for every
stored genome. The same genome measured 5.10 kW on 2026-10-01 and
3.80 kW on 2026-10-05.

Launch-only physics was absent from both screen trees: 793137a,
b488262, b835ebc and 95c385d. The bankderate2 winner (r_hub 4.580 m,
bank gene 22 degrees, blades 0.82 and 0.20) found the pass at 5.31
kW.

Caveat: the exact split of the 5.10 to 3.80 kW drop is inferred. The
span shrink is the only documented large mechanism, and its magnitude
fits.

Provenance hole: the screen runner scripts/run_length_variants.jl is
untracked. Queue a commit for it.

## 1.2 resolved: the 1.5 lift factor multiplies mass minus the lifter

The 5 kg lifter sits in the scored mass but not in the lift sizing
(include_lifter=false). The hand check closes.

1.5 x (25.698 - 5) x 9.81 = 304.5 N vertical. Divide by sin 70
degrees and the lift tension is 324.1 N, which is NR-010 exactly.

The reviewer's 1.21 ratio used the full 25.698 kg mass. The draft
must state the mass the factor multiplies. See expansion_analysis.jl
line 74 and numbers-register.md lines 359 to 360.

## 1.6 closed: the objective equation

F = m_airborne + 5.0 x max(P_end - 5.0, 0)^2 + 20.0 x (2.5 / FoS)^2
+ 1.0 x (tr / (1 - tr))^2. The stationarity term reads 0.0 for the
winner.

Winner terms: 25.69846825623688 plus 0.49334 over-power plus 0.55765
utilisation plus 0.61409 twist. The sum is 27.3635412663488, which
closes at zero.

Mass sub-terms: tether 0.5729 kg, rings 15.4200 kg, blades 4.2474 kg
(0.420 x span^3), expansion rotors 0.0 kg, knuckles 0.4582 kg,
lifter 5.0 kg. See objective_v12.jl lines 114 to 165,
objective_evaluator.jl lines 1148 to 1203, expansion_analysis.jl
lines 44 to 78.

## 1.7 damper values at dd3cc6a

- lin_damp = 0.05. Rope nodes only. retain = exp(-rate x dt) with
  rate = -ln(0.05) / 4e-5. Time constant about 13 microseconds. Ring
  nodes are not damped. See objective_evaluator.jl line 698,
  simulation.jl lines 194 to 195, initialization.jl lines 738 to 799.
- Physical line drag: TETHER_DRAG_CD = 1.0. The Tveide factor of
  about 1.09 was deliberately not landed. See aerodynamics.jl line
  335 and DECISIONS 2026-09-11.
- Physical rope damping: zeta = 0.05, c = 2 x zeta x sqrt(EA x m / L).
  See parameters.jl lines 177 and 226, initialization.jl lines 259 to
  271, rope_forces.jl line 128.
- bearing_tr_damp = 0.99994 and ang_damp = 1.0 are legacy. They act
  only in simulate(). They were never active in a campaign
  evaluation.
- Step size: dt = stable_dt_for_system, ceiling 4e-5 s. About 1.25
  million steps per 50 s evaluation. The 5 kW taper can halve dt.
- DECISIONS 2026-09-15 ruling 3: lin_damp survives only as a declared,
  pinned numerical stabiliser.

## 2.2 the gene table

Canonical 10-D genome. Campaign box from tight_bounds in
compute_seeds.jl. Decode clamps from objective_v10.jl and
ring_spacing.jl. Winner decode: 4.580, 0.804, 2.721, 3, -0.8, 1,
7.088, 22.0, 0.821, 0.200.

| Slot | Gene | Units | Box | Clamp | Live condition |
|---|---|---|---|---|---|
| 1 | r_hub | m | 0.7 to 7.776 | - | Always live. |
| 2 | r_bottom | m | 0.1 to 1.5 x seed | 0.1 to 8.0, then min(r_bot, r_hub) | Dead above r_hub. Silently capped. |
| 3 | target_Lr | - | 1.0 to 2.94 | 0.1 to 5.0 | Always live. |
| 4 | n_lines | count | 3 to 9 | 3 to 16 | Always live. |
| 5 | density_profile | - | -0.8 to 0.8 | -0.8 to 0.8 | Dead when a section has one interior ring or none. |
| 6 | rotor_count | count | 1 to 3 | 1 to 3 | Rotors whose ring index falls outside the ring list are dropped. |
| 7 | bank_top | deg | 0 to 22 | 0 to 25 | Live when at least one rotor exists. |
| 8 | bank_bottom | deg | 0 to 22 | 0 to 25 | Dead when rotor_count = 1. Winner gene 22.0. Rotor bank is 7.088. |
| 9 | blade_scale_top | - | 0.2 to 1.0 | 0.1 to 2.0 | Live when at least one rotor exists. |
| 10 | blade_scale_bottom | - | 0.2 to 1.0 | 0.1 to 2.0 | Dead when rotor_count = 1. Winner gene 0.2. |

Legacy 14-D beam genes are dead (R7, 2026-09-10). They are
synthesized on the canonical path.

Doc fix queued: objective_v10.jl line 24 says blade scale 0.005 to
2.0. The actual clamp is 0.1 to 2.0 and the box floor is 0.2.

## 2.7 the DE settings

- NP = 10 per island. Gen 0 is one seed plus 9 draws. Gens 1 to 30
  are 300 trials. Total 310.
- F = 0.5 + 0.3 x rand(). CR = 0.7 + 0.2 x rand(). Redrawn per
  vector.
- Strategy rand/1/bin. Selection is synchronous. The trial replaces
  the parent when the trial cost is not larger.
- Stopping: fixed 30 generations. No early stop.
- Islands: 3, independent, seeds 42 to 44. No migration.
- Reproduce: julia --project=. scripts/run_v13_5kw_masslift.jl
  --length 18.8 --tag bankderate2

## Next

- software-validator: confirm the 1.7 rows against dd3cc6a.
- science-validator: sign the 1.5, 1.6, 2.2 and 2.7 rows and the 1.2
  mass statement.
- author: draft edits for 1.2 and 1.8.
- aero-worker: run the 1.1 window-mean omega probe.

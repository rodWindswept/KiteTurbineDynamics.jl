# Harris review, read-only pass by aero-worker

Date 2026-10-10. Input: the lead triage at
`docs/reporting/room-responses/hermes-2026-10-10-harris-triage.md`.
Scope: read-only checks only. No simulator runs. No register writes.
All rows stay validator-gated.

## Verdict

The reviewer arithmetic reproduces. I resolved three items in full.
I narrowed five more. The rest stay with the validators.

## 1.2 Lift margin. Resolved.

`src/lift_kite.jl:197`. `sized_lifter_for` sets `F_vert = 1.5 x m_airborne x g`.
`m_airborne` is `expansion_airborne_mass` with `include_lifter=false`.
`src/expansion_analysis.jl:44`.

The lifter mass (5.0 kg) enters only when `include_lifter=true`.
NR-018 (25.698 kg) includes it. The sizing mass is 20.698 kg.

Check: 1.5 x 20.698 x 9.81 = 304.6 N. Divide by sin(70 deg). Result: 324.1 N.
NR-010 = 324.125 N. Exact match.

The lifter carries its own weight. That is Rod's 2026-08-21 ruling.
It sits as a code comment in `src/lift_kite.jl`.

Margin over the full airborne mass: 304.6 / (25.698 x 9.807) = 1.208.

Report fix: name the mass. The 1.5 multiplies 20.698 kg.
It does not multiply 25.698 kg. Quote both margins.
State the point (lift bearing, not sky anchor).

## 1.6 Objective gap. Resolved.

`fitness_fn = appropriate_mass_fitness`. `scripts/run_v13_5kw_masslift.jl:262`.
Fitness = mass + 3 penalties. `src/objective_v12.jl:145`.

Itemised: over-power `5.0 x (P_mean - 5.0)^2` = 0.477 kg.
Twist `1.0 x (0.4393 / 0.5607)^2` = 0.614 kg.
Utilisation `20 x (2.5 / 14.972)^2` = 0.558 kg.

Sum: 1.649 kg. Actual gap: 27.3635 - 25.6985 = 1.665 kg.
Residual: 0.017 kg. The evaluator trace must pin it.
Request to science-validator.

## 1.1 Speed conflict. Verified. Row pending.

`omega_eq` = 10.170 rad/s. That is the settle speed.
`scratch/sv_p0_winner_reeval.txt:12`.
Final-step segment torque S1 = 396.8 N·m.
`docs/reporting/figures/pair-extract/extract-winner-operating-point.csv`.

`sqrt(396.8 / 2.24)` = 13.31 rad/s (127 rpm). Torque times speed = 5.28 kW.
This matches P_mean 5.309 kW. The reviewer reproduces.

The pair-extract capture holds 52 samples over the window.
The window-mean ω row comes from that trace. Request to validators.
One trace read or one small probe.

## 1.3 Margins. Table verified. Two items open.

| Failure mode | Demand | Limit | Margin |
|---|---|---|---|
| Ring beam-column R6 | util 0.0665 | 1.0 | 15.0 |
| Segment torque S1 | 396.8 N·m | 805.0 N·m | 2.03 |
| Twist vs floor S1 | 33.9 deg | 72.25 deg | 2.13 |
| Twist vs crossing S1 | 33.9 deg | 78.83 deg | 2.32 |
| Twist vs δcrit S1 | 33.9 deg | 98.86 deg | 2.91 |

The binding twist limit is the 72.25 deg floor. It equals asin(1/1.05).
The 1.05 rationale lives in the realisability code.
Request to science-validator.

The torque capacity uses the Tulloch authority basis. The extract header says so.
Whether torsion sits under the 2.5 gate is open. Request to software-validator.
Check the gate module.

## 1.4 Ring factors of safety. Data verified. Floor check open.

R2 30.09. R3 29.81. R4 35.24. R5 326,974. R6 15.03. Extract CSV.

R5: util_axial = 0.0. util_bending = 3.06e-6. Effectively unloaded.
Its station sits in the cylindrical section. The lines run near-axially there.

Per-ring tube dims against the OD and wall floors: request to software-worker.
`scratch/probe_ring_fos_breakdown.jl` exists.

## 1.7 Dampers. Values pinned. Call site open.

`lin_damp` = 0.05. Default at `src/simulation.jl:71`. Applied each step at line 194.
`ang_damp` = 1.0 (no kill). `bearing_tr_damp` = 0.99994.
`src/initialization.jl:808`.

dt = 2.8988e-5 s. Total 1,724,859 steps over 50.0 s. Pair-extract log.

Physical damping: Tveide drag with C_D = 1.0. Cite it apart from the stabilisers.

Call-site confirm: `src/objective_evaluator.jl`. Open for the software seat.

## 1.8 Ambiguities. Three resolved.

Two blade scales: x9 = 0.8213 (top, active). x10 = 0.2000 (bottom, dead).
The decode gives n_active = 1. `scratch/sv_p0_winner_reeval.txt`.

Bank: x7 = 7.088 deg is the bank gene. The 22.0 deg is the fixed cone slope.
It is `cone_slope_deg` in ObjectiveConfig. It is not a bank gene.
The draft conflates the two.

Back line: 3 mm Dyneema. EA pinned in `params_5kw_188` after `mass_scale`.
`src/parameters.jl` BackLineSpec note. Modelled with payout 0.0.

## 2.1 Operating point. Assembled from code.

Site: Tulloch Daisy. 10.0 m/s at 4.8 m. Hellmann 1/7. `src/wind_profile.jl:50`.

h_ref = 9.41 m. v_wind_ref = site_wind(9.41 m) = 11.01 m/s. V_RATED = 11.0.
ρ = 1.225. Shaft elevation 30 deg. Lift line 70 deg.

Winner radii: r_ring 4.580 m. r_bot 0.804 m. Annulus swept area 63.9 m².

λ at settle = 4.23. λ at the implied operating speed = 5.54.

Cp base = 0.16. That is the Daisy measured band 0.15 to 0.18.
The campaign runs the measured blade-count Cp surface.
The operating Cp(λ) still needs a row from the sweep CSV. Open pointer.

Betz check: (16/27) x 0.5 x ρ x A x v³ x cos³(30 deg) = 20.1 kW.
The winner makes 5.31 kW. Well inside.

The wind is steady. The 0.5 percent swing is not a stability property.
Agree with the reviewer.

## 2.4 Load law. Provenance pinned. One comment is wrong.

k = 2.24. Single source: `compute_seeds.jl`. Honest sweep 2026-08-22 on the fixed machine.
CSV: `scripts/results/k_sweep_daisy_5kw.csv`.

Closed form: k scales as P^2.5. `src/parameters.jl:637`.
0.175 x (5/1.5)^2.5 = 3.55. Ratio 2.24 / 3.55 = 0.63. Matches the reviewer.

The runner comment writes `0.175·(5/1.5)^2.5 = 2.24`. That arithmetic is wrong.
The scaling gives 3.55. Fix the comment. Flag for the lead or the software seat.

Units: k is N·m·s²/rad². The ControlSpec comment already says so.

## 2.7 Search settings. Part pinned. One pointer open.

10 designs x 3 islands x 30 generations = 930 evaluations. PROVENANCE.md.
RNG seed = 42 + island - 1.

Genome dimension = 10. NP = 10 against the usual 5-10 x D guidance.
Agree with the reviewer.

F, CR and strategy: the campaign DE config still needs a location.
Request to software-worker.

## Requests to the room

1. Window-mean ω row. Validators. One trace read or one small probe.
2. Pin the 0.017 kg fitness residual. science-validator.
3. Torque-capacity gate status. software-validator.
4. Per-ring OD and wall floor check. software-worker.
5. Realisability floor 1.05 rationale. science-validator.
6. Fix the k comment arithmetic slip. lead or software.
7. Gene table with bounds and live conditions. software-worker.
8. Daisy rows. science-validator. Long-standing.
9. Exact torque and twist expressions from src for 2.3. science-validator.
   Compare with τ = n T r1 r2 sin(Δα) / L.

No register rows added. No simulator runs performed. Read-only pass.

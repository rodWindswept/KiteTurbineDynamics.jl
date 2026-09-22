# Item 4 campaign summary: 5 kW mass-aware lift redo

**Date:** 2026-09-22. **Instance:** Hermes desktop. **Status:** first pass complete.

## Campaign setup

- Era: HEAD `1c9f9cb`. That commit landed the lifter boundary condition.
- Runner: `scripts/run_v13_5kw_masslift.jl` with tag `physlift` and length 18.8 m.
- Design: 3 islands, 10 genomes per island, 30 generations.
- Stage-1 screen: evaluator window 40 s, FoS target 2.5.
- Results: `scripts/results/v13_5kw_masslift_len18.8_rotorcount_physlift/`.
- Stage-2 re-gate: full 120 s protocol at two settings. The settings are the zero-artificial-damping envelope (ld 0.00) and the canonical value (ld 0.05). Runner: `scratch/probe_wobble_gate_run_island3.jl`. The 6th argument selects the island directory.

## Island 2: best fitness 22.26 kg (campaign best)

- Genome: `[3.5510, 0.7185, 1.8310, 3.0, 0.2887, 1.0, 4.4110, 22.0, 0.7110, 0.8758]`
- Machine: 3 lines, 12 rings, single rotor, r_hub 3.55 m.
- Evaluator: P 5.37 kW, FoS 9.56, clearance 6.46 m, T_lift 211 N.
- Convergence: seed 57.22. Gen 18: 25.50. Gen 20: 23.71. Gen 26: 22.45. Gen 30: 22.26. The line was still improving at gen 30.
- Re-gate: PASS at both settings.
- Envelope numbers: hub p2p 0.0082 m. FoS trough 6.54. P 5.762 kW. omega 13.750 rad/s.
- Slack: only the 3 bridle cone lines flag. The dips are 0.08 s long at 35 % duty. All other lines are clean.
- Canonical numbers: hub p2p 0.035 m. FoS trough 6.98.
- Logs: `.julia_depot/logs/wg_isl2_ld0.00_dtf1.log` and `wg_isl2_ld0.05_dtf1.log`.

## Island 3: best fitness 22.32 kg

- Genome: `[3.5457, 0.8627, 1.6924, 3.0, 0.3509, 1.0, 17.3884, 4.7264, 0.6905, 0.8618]`
- Machine: 3 lines, 11 rings, single rotor, r_hub 3.55 m.
- Evaluator: P 5.29 kW, FoS 15.1, clearance 6.42 m, T_lift 243 N.
- Convergence: seed 53.75. Gen 7: 25.38. Gen 16: 24.02. Gen 21: 22.84. Gen 29: 22.32. The line was flat over the last generations.
- Re-gate: PASS at both settings.
- Envelope numbers: hub p2p 0.0075 m. FoS trough 12.27. P 5.655 kW. omega 13.665 rad/s.
- Slack: only the 3 bridle cone lines flag. The dips are 0.10 s long at 50 % duty.
- Canonical numbers: hub p2p 0.052 m. FoS trough 11.74.
- Logs: `wg_isl3_ld0.00_dtf1` and `wg_isl3_ld0.05_dtf1`.

## Island 1: best fitness 33.68 kg (fails the re-gate)

- Genome: `[2.6096, 0.7413, 1.6390, 3.0, 0.1230, 2.8893, 9.9032, 0.6200, 0.8797, 0.6441]`
- Machine: 3 lines, 10 rings, 3 rotors, r_hub 2.61 m.
- Evaluator: P 5.07 kW, FoS 12.34, clearance 3.37 m, T_lift 416 N.
- Convergence: seed 62.14. Gen 11: 42.07. Gen 13: 40.28. Gen 18: 33.68. Flat to gen 30.
- Re-gate: FAIL.
- Envelope numbers: FoS trough 1.59 against the 2.5 gate. Hub p2p 1.23 m. Bridle cone slack up to 14.9 s contiguous. Cyan cycles 0 to 1003 N. Back line cycles 5 to 1801 N. Power cycles 3.8 to 9.2 kW. Omega cycles 11.9 to 16.0 rad/s.
- Canonical numbers: damping masks the instability. FoS trough 7.82. Hub p2p 0.054 m. The cone still runs at 84 % duty.
- Logs: `wg_isl1_ld0.00_dtf1` and `wg_isl1_ld0.05_dtf1`.

## Verdicts

- 2 of 3 candidates qualify. Both are one family: 3 lines, one rotor, r_hub near 3.55 m, 11 to 12 rings, near 22.3 kg.
- The multi-rotor direction is heavier and unstable in the envelope.
- Stage-1 accepted island 1. Stage-2 rejected it. The honest re-gate does its job.

## Forensics: why is island 1 unstable? (first pass)

- Island 1 enters the window already violent. The first 10 s bin already shows a large hub excursion. There is no growth phase.
- The settled state is itself rough. The handoff residual reads 46.7 m/s2 for island 1. Islands 2 and 3 read 16.7 and 17.6 m/s2.
- The stable machines hold one organised mode. Hub, omega and cyan oscillate together at about 4.85 s. The couplings are r = 0.85 to 0.91.
- Island 1 loses that mode. The couplings fall to r = 0.05 to 0.07. Omega and cyan show no periodic structure at all.
- The bridle cone is the suspect. Only 1 % of the window has cone tension above 5 N. The mean cone load is 0.03 N. Island 3 shows 58 % above 5 N and a mean of 46 N.
- The cone deficit is intrinsic. At ld 0.05 the excursions are small and the machine regains coherence. The cone still drops below 5 N for 73 % of the window. Island 3 sits at 42 %.
- Reading: island 1's lift cone carries almost no load at its operating point. The load shifts to the cyan and back lines. Those cycle over their full range (0 to 1003 N and 5 to 1801 N). At zero damping the result is chaos.
- Next: compare the settled cone geometry and tensions across the three machines. The probe is in preparation.
- Artefacts: fine logs and CSVs `wg_isl{1,3}_ld0.{00,05}_fine` in `.julia_depot/logs/`. Analyser: `scratch/analyze_item4_fine.py`.

## Open questions

- The bridle preload cut and the settled cone geometry need a cross-machine check. Probe in preparation.
- The honest window is not yet active in the stage-1 evaluator. Stage-1 still runs a 40 s window.

# Room response: Phase 1 re-analysis of dd3cc6a (2026-11-01, science-worker)

**Status** LANDED. **Base** `6f12520` on `bank-derate-cos2p65`. **Seat** science-worker, the phases 0 to 2 lane.

Five Phase 1 re-analysis deliverables land here. All five recompute from raw campaign data and logs without simulation.

## 1. The 0.837 m bow bound

The geometric tail of the extension run confirms the asymptote. The mean ratio of the last ten steps gives 0.8367 m.

The largest ratio gives 0.8370 m. Both values round to 0.837 m. The margin to the 1.5 m floor reads 0.663 m.

The midpoint ring gives 0.4220 m with a margin of 1.078 m. This bound verifies the uncommitted number from FB-6.

Evidence: `scratch/aw_bow_asym_2026-11-01.py`, log `scratch/aw_bow_asym_2026-11-01.log`, and `scratch/av_b21_bow_bound_check.log`.

## 2. The omega-basis row

At the archive gain k = 2.24 and window-mean speed omega = 13.3803 rad/s:

- k times omega squared reads 401.03 N m.

- k times omega cubed reads 5365.89 W (5.366 kW).

- The ratio of delivered torque to k times omega squared reads 0.9894.

- The deficit gap reads 1.064 per cent.

The 1.064 per cent gap explains the difference between P_mean and k times omega cubed.

Evidence: `scratch/sw_p1_omegabasis_2026-11-01.py` and log `scratch/sw_p1_omegabasis_2026-11-01.log` (9 checks, 0 fail).

## 3. Extract-torque closure

The campaign winner carries P_mean = 5308.78 W in full precision.

Dividing by omega = 13.38026 rad/s returns torque = 396.7621 N m.

This matches NR-030 exactly. The two-decimal display forms read 5.31 kW and 396.76 N m.

Evidence: `scratch/sw_p1_torqueclosure_2026-11-01.py` and log `scratch/sw_p1_torqueclosure_2026-11-01.log` (7 checks, 0 fail).

## 4. Masked PCA and lever table

The campaign ok set holds 508 designs. 506 designs carry one active rotor.

They carry two dead genes: x8 (bank_bottom) and x10 (blade_scale_bottom).

- Unmasked PCA (10 genes): PC1 = 32.12 per cent, PC2 = 14.20 per cent.

- Masked PCA (8 active genes): PC1 = 26.92 per cent, PC2 = 16.54 per cent.

- Correlation rho(P_mean, x1) = -0.7903.

- Correlation rho(fitness, x1) = -0.0138.

The lever table lists the Spearman correlation with fitness across active designs:

- x1 r_hub: rho = +0.0736 (n = 508)

- x2 r_bottom: rho = -0.2764 (n = 508)

- x3 target_Lr: rho = -0.5832 (n = 508)

- x4 n_lines: rho = -0.0287 (n = 508)

- x5 density_profile: rho = +0.0662 (n = 508)

- x6 rotor_count: rho = +0.0317 (n = 508)

- x7 bank_top: rho = +0.1252 (n = 508)

- x8 bank_bottom: rho = -1.0000 (n = 2)

- x9 blade_scale_top: rho = +0.5042 (n = 508)

- x10 blade_scale_bottom: rho = +1.0000 (n = 2)

Evidence: `scratch/sw_p1_maskedpca_2026-11-01.py` (15 checks, 0 fail) and `scratch/sw_p1_levertable_2026-11-01.py` (12 checks, 0 fail).

## 5. Convergence exhibit

Island 3 traces 31 generations from seed to winner.

The seed at generation 0 reads 36.109 kg-equivalent.

The best-so-far fitness improves monotonically.

It reaches the winner score 27.364 kg-equivalent at generation 26.

It holds 27.364 kg-equivalent through generation 30.

Evidence: `scratch/sw_p1_convergence_2026-11-01.py` and log `scratch/sw_p1_convergence_2026-11-01.log` (9 checks, 0 fail).

## Handoffs

- @figures-images-diagrams: the convergence exhibit and lever tables stand ready for plate builds.

- @science-validator: rows NR-083 to NR-085 cover these verified findings.

- @hermes: the queue can mark Phase 1 of the lane complete.

science-worker, 2026-11-01.

# The k_mppt retune of the S2 fold: 6.7951 kW and the 625 N·m clamp

Author: aero-validator (2026-10-06). Measurement tree: `a82cafd` (2026-10-05). Re-run tree: `613f3de` (2026-10-06).
Probe: `scratch/av_kretune_cpfix.jl`. CSVs: `scripts/results/av_kretune_cpfix/`. Logs: `.julia_depot/logs/av_kretune_cpfix_613f3de.log` and `.julia_depot/logs/sv_kretune_repro_a82cafd.log`.

**Clamp release (2026-10-07, science-validator).** D4 landed: fix `b488262`, docs `7c9f4b9`. The unified `generator_torque_cap` reads 1541.1 N·m at 5 kW. It supersedes the 625 N·m clamp that this record measures against (DECISIONS [2026-10-07]). The B2 load no longer binds. The released cap clears the recorded product k_eff × ω_gnd² = 624.96 N·m and the uncapped demand ≈ 695 N·m. The 6.7951 kW row stands as the historical pre-gate read, with no new capture.

The floor screen blocks the released-clamp re-read at this tip. The block is a certified non-regression, not a D4 effect. The S2 fold seed reads 3.6757 kW against the 4.0 bar at `objective_evaluator.jl:1106`. The B1 control rejects, and no B row produces a number. The cause is the floor landing `793137a`.

Part A reproduces to the digit, and the flight values reproduce (ω_hub 13.4302, λ 6.6124). Logs: `.julia_depot/logs/av_kretune_cpfix_7c9f4b9.log` and `.julia_depot/logs/sv_cert_floor_match_bank_d24d4ce.log`. A live row needs a room call. The n=9 companion clears the bar at 4.1319. A documented single-probe exception is the other path. The ≈ 6.87–6.89 kW release estimate stays an estimate until then.

## Verdict

- The S2 fold is not aero-capped at 5.37 kW. At a retuned k_mppt it measures **6.7951 kW**, cold, stationary, and unbroken.
- The cap is the 625 N·m `tau_max_safe` clamp. The load sits on the clamp, so the point is torque-limited, not aero-limited.
- Reaching a 5.5 kW seed in the single-rotor class takes a k ruling, not a bounds change. The campaign pins k = 2.24 by test, so this point sits outside the campaign instrument until that ruling lands.
- The retune does not rescue the old-winner radius class. Every probed row stays under 5 kW.
- The number is era-conditional. Cross-ref: `2026-10-06-s2fold-floor-sensitivity.md` (c739348).

## Why the retune gains

The honest k (2.24, `K_MPPT_5KW_HONEST`) parks the fold past its own Cp peak. It flies at λ = 6.6124 with cp = 0.24047. The committed table peaks near λ = 5.2 at cp = 0.3087. The ODE carries no solidity term. So cp_at_tsr(λ) is the only aero lever against ω. A retune holds the rotor nearer the peak.

## Measured, fold class (cold, floor 5.0 live)

| case | k set | P_end kW | P_mean kW | FoS min | twist | λ flown | cp flown | state |
|---|---|---|---|---|---|---|---|---|
| B1 control | 2.24 | 5.3691 | 5.3622 | 5.407 | 0.3603 | 6.6124 | 0.24047 | ok, stationary |
| B2 retuned | 5.877725 | 6.7951 | 6.7902 | 2.775 | 0.6818 | 5.3472 | 0.30436 | ok, stationary |

B1 matches the committed cp-span record to the digit. B2 gains +1.426 kW, or +26.6 per cent.

The cap, measured. The effective k for B2 reads 5.2864. The product k_eff × ω_gnd² reads 624.96 N·m. `tau_max_safe` = 2500 × (p_rated / 10 kW)² = 625 N·m, at `src/ring_forces.jl:149`. Margins thin as the torque rises. FoS drops 5.407 to 2.775 against a gate of 2.5. Twist rises 0.360 to 0.682 against a crossing bound of 1.0. Both still pass.

## Measured, radius class (context)

| case | r_hub m | k set | P_end kW | verdict |
|---|---|---|---|---|
| A1 control | 3.8347 | 2.24 | 4.2512 | FAIL |
| A2 pull to λ 4.1 | 3.8347 | 4.3552 | 4.0043 | FAIL, 5.8 per cent loss |
| A3 hold λ 5.19 | 4.32 | 3.3432 | 4.7271 | FAIL |
| A4 hold λ 5.19, out of bound | 4.50 | 3.8295 | 4.8980 | FAIL |

A2 shows the direction. Pulling the radius class toward λ = 4.1 moves away from the peak and loses 5.8 per cent. The retune gain is fold-specific.

## Scope

- Adoption wants an aero review and an acceptance lens. The point sits on the torque-protection clamp.
- The two pending rulings can move the evaluator. This number holds under its tree only. A matched-charge floor would drop this candidate from the screening set with its class.
- Tip status: re-run at `613f3de`. Data rows match the a82cafd run bit for bit. Headers differ by tree and date only.

## Reproduction

`scripts/ktd-julia scratch/av_kretune_cpfix.jl` runs both parts in about 6.2 minutes.
Independent reproduction: science-validator ran the same script at `a82cafd`, twelve minutes after the first run. Printed digits match (log `sv_kretune_repro_a82cafd.log`).

## Evidence

- `scripts/results/av_kretune_cpfix/s2_kretune.csv`, sha256 `c5f8d4a9e5a4ac2f0116f7fcf5b24a34036151430c3b3ec65f71f01b1423c1f8` (a82cafd run). Tip re-run copy: `s2_kretune_613f3de.csv`, sha256 `ea1bec64d7f96dfe7d44c9cf06eb24a036d8342f73ff488c84a3cfc4ed2d5529`.
- `scripts/results/av_kretune_cpfix/radius_kretune.csv`, sha256 `5b98ff1278b46a31544fab42ea09d2bfa759eafb6a20c4ae3f225146ba27a58d` (a82cafd run). Tip re-run copy: `radius_kretune_613f3de.csv`, sha256 `616dd0ce4619b3edd09c378f0871fdae8ff9b988cd8af79d9dc678d080ed29bd`.
- Console log of the tip re-run: `.julia_depot/logs/av_kretune_cpfix_613f3de.log` (exit 0, elapsed 369.7 s). Independent reproduction log: `.julia_depot/logs/sv_kretune_repro_a82cafd.log`.

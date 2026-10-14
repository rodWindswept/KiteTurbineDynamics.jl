# Room response: NR-046 signs the objective seam forms, the weights, the thresholds and the reject placement (2026-10-14, science-validator)

**Status** The feedback round 4 source read closes to the register side. One new signed row (NR-046) carries the three soft penalty forms, with their weights, thresholds and units. It also carries the stationarity add-on and the reject placement. The winner closure recomputes with diff 0.0. The reject census reads clean over all 930 rows.

**Seat** science-validator. **Read at** HEAD `7b8c101`, the tip at read time. Register edited below the NR-045 block (1.00 to 0.99 per100w, additions only, STE rc=0).

## The read

The read walks three source files. The three files read byte-identical at launch `a76c5e9`, at HEAD and at origin (`da9c5554`, `52669d40`, `bf5c5e36`). No source byte separates the launched campaign from the read.

1. `src/objective_v12.jl`: the seam body at lines 145 to 168 and the weights at 114 to 116.

2. `src/objective_evaluator.jl`: the window chain at 1148, 1161, 1192 to 1194 and 1200 to 1203. The stationarity constants sit at 90 to 91. The twist detector sits at 443 to 477.

3. `scripts/run_v13_5kw_masslift.jl`: the campaign config at 153 to 156 and the seam pin at 266. The clearance gate reads at 256 to 257. The status map reads at 272. The reject stamp reads at 281 to 283.

## The forms (as signed)

| term | form | weight | threshold | input |
|---|---|---|---|---|
| over-power | `5.0 * max(P_score - 5.0, 0)^2` | 5.0 kg-equivalent per kW² | ceiling 5.0 kW | P_score, the tail-5 power (P_end) |
| utilisation | `20.0 * (2.5 / FoS_min)^2` | 20.0 kg-equivalent | floor 2.5 (`fos_hard`) | the window minimum FoS |
| twist | `1.0 * (r / (1 - r))^2`, `r = min(twist_ratio, 1)` | 1.0 kg-equivalent | the crossing limit (ratio 1) | the window worst twist ratio |
| stationarity | `10.0 * max(0, swing - 0.20)` | 10.0 kg-equivalent | a 20 per cent swing | `P_range / P_mean` |

Every charge is continuous. None is step-like. Two hard gates sit beside them: an FoS below 2.5 or a score power below 5.0 returns `Inf`. That is a reject signal and not a score.

## The closure

The forms recompute the recorded winner terms at full precision: over-power `0.49333696413175443`, utilisation `0.5576509889014662`, twist `0.6140850570787014`. The chain closes at diff 0.0 against the recorded fitness `27.3635412663488`. The term sum reads `1.665073010111922`. The direct gap reads `1.6650730101119215`. The seam sits on the NR-039 record.

## The reject placement

The evaluator carries `Inf` for a rejected design, plus the measured window statistics where the window ran. The runner stamps the search cost `1e9` on every non-ok design. The census over all 930 telemetry rows reads: 508 ok with finite scores, 422 stamped. The stamp splits 301 reject, 110 clearance_reject and 11 reject_twist (NR-002).

No ok row carries the stamp. No non-ok row carries a score. The search ranks no reject above an ok design, and it cannot trade power or safety against mass.

## Evidence

- Checker: `scratch/sv_nr046_objective_seam_check.py`. Log: `scratch/sv_nr046_objective_seam_check.log`. 53 checks, 0 fail: 30 source pins, 4 identity checks, 15 closure and cross-read checks, 4 census checks.

- Register: `docs/reporting/numbers-register.md`, the NR-046 block below NR-045.

- STE: rc=0. The register reads 1.00 to 0.99 per100w, additions only. This receipt reads 0.00 per100w.

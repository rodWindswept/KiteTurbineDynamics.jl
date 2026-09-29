# Handover — 2026-09-29: Daisy anchor reconciliation, the two-exponents wind defect, and the pending anchor ruling

**From:** aero-worker. Measured-data session, 2026-09-29, desktop with NAS access to `/mnt/RodsData`.
**To:** the next working-group session.
**State:** Findings only. No code changed. The four rulings and the 0.85 blocking figure are already
committed (see §5). This doc records the measured-data findings and the pending Daisy-anchor ruling that
still needs Rod's sign-off.

---

## 0. What this is

The design-room session closed the four rulings and landed the 0.85 blocking figure. The rulings are:
rings are rotors; spokes carry a tension duty; blocking is 15 per cent of power; wind shear is the
stronger effect. Its last exchanges produced four new items that lived only in the room transcript. This
handover records them so the next session starts primed.

## 1. Daisy anchor — measured data (findings, not rulings)

Read the session folders in `/mnt/RodsData/kites/Test Data`. Four instrumented Daisy sessions exist.
Swept area is 11.2 m², an annulus not a planform. `DECISIONS.md:2394` matches it to π(2.22² − 1.22²) =
10.8 m².

| Session | Wind (m/s) | Peak power | Peak cadence |
|---|---|---|---|
| 2019-06-05 (AWEC period) | 3.0–8.0, mean 5.5 | 415 W | 173 rpm |
| 2019-06-06 | ~4–8 | 911 W | 150 rpm |
| 2020-01-18 | no wind file | 1025 W | 157 rpm |
| 2020-05-16 | 2.0–10.5, mean 5.45 | 953 W | 157 rpm |

Three findings follow.

1. **624 W / 146 rpm is instrumented, not publication-only.** It appears in three sessions (within
   ±20 W / ±4 rpm): 2019-06-06 (23 rows), 2020-01-18 (7 rows), 2020-05-16 (19 rows). `DECISIONS.md:2393`
   labels it "(Dec 2019 blog)". That is incomplete. The pair is in the logs.
2. **The wind at 624 W / 146 rpm is ~7 m/s.** On 2020-05-16 (the only session with matched wind) the
   rows sit at 5–9 m/s, median 6.7, mean 7.1. This confirms the ~8 m/s curve estimate and the model's
   implied Cp ≈ 0.18 at that point.
3. **Only "> 1.5 kW @ 10 m/s" is publication-only.** The AWEC-period folder (2019-06-05) never exceeded
   415 W. No logged session reaches 1.5 kW. The record's two anchor rows imply Cp 0.091 (624 W @ 10 m/s)
   against Cp 0.219 (1.5 kW @ 10 m/s). That is a 2.4× gap. It resolves only when each row carries its own
   wind.

## 2. The bin-matched Cp rule

Instantaneous SRM power is decorrelated from the ground anemometer below the minute scale. At the 624 W
rows the instantaneous Cp is 0.13–0.79 (median 0.30), including values past Betz. Instantaneous Cp is
unquotable.

The rule: no Cp may be quoted unless power and wind come from the same time bin. No anchor may be quoted
without its wind. The only defensible measured Cp is the 1-minute bin value. That is 0.167 raw on ½ρAv³
(337 W at 6.65 m/s on 2020-05-16), or ~0.18 on the sheet's "AWES-style" denominator.

## 3. The two-exponents wind defect (science-validator)

The repo shears one machine twice, in different halves of one evaluation.

- Sizing path: `src/objective_v10.jl:92-101` sets `shear_exp = 0.14` and `h_ref = 50.0`.
  `objective_v10.jl:391` is its only caller.
- Dynamics path: `src/objective_evaluator.jl:587` shears at `1/7` against `p.h_ref`.

The ring sees two winds in one evaluation. The recorded pair 8.7051/7.9959 m/s is the decode number.

The crossover where the 0.85 blocking re-inverts the profile is reproducible only as a pair:
`α_cross = α₀ · ln(1/0.947268) / ln(spread)`. With `spread = 8.7051/7.9959` the coefficient is ≈ 0.637.
So 0.14 gives ≈ 0.089 and 1/7 gives ≈ 0.091. Record the exponent next to any quoted crossover. The
number is not reproducible without it. Science-validator computed this by hand; one line from a box that
can run it settles it.

## 4. The pending Daisy-anchor ruling (for Rod — NOT decided)

The science-validator proposed: promote a bin-matched session row as the source for both the mass scale
and `k_mppt`. Demote "> 1.5 kW @ 10 m/s" and "624 W / 146 rpm" to checks against it.

Aero-worker's refinement: make the demotion asymmetric. "> 1.5 kW @ 10 m/s" is publication-only. Demote
it to a consistency check. But "624 W / 146 rpm" is instrumented. Keep it, re-quoted as an instantaneous
point at ~7 m/s. Flag it as a spike if used for `k_mppt`, not as a bin-matched anchor.

This ruling is Rod's to make. It is not written to DECISIONS.md.

## 5. Session state

Committed on master: `02b766b` + `a3e053e` (the four rulings), `5153d6b` + `4bc51ec` (0.85 blocking
figure and the stale-doc sweep), `fac4c29` / `0cdc05b` (AeroDyn v5.0.0 provenance). The working tree
still carries the in-flight banked-top-rotor work in `src/` (software-worker).
`docs/plans/2026-09-29-work-division.md` records the open workstreams and owners.

Note for the lead: that plan's "Decisions for Rod" table still shows decision 3 (wake de-rate) and
decision 4 (Daisy anchor) as open. Decision 3 is resolved at 0.85 this session. Decision 4 has a pending
proposal in §4 above. Refresh the table before the next dispatch.

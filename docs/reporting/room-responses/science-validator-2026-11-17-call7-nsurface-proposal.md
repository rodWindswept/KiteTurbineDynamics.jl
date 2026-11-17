# Room response: the Call 7 n-surface proposal and its acceptance tests (2026-11-17, science-validator)

**Status** PROPOSED. It waits on the aero counter-read, then on the
software-validator implementation behind both signs. No code lands here.

**Seat** science-validator. **Read at** `2a0514f5`, the tip at read time.
**Queue item** 2, the Call 7 proposal.

## 1. What the ruling asks for

The founder ruled Option A on 2026-10-30. Teach the ODE the n-surface.

The ODE flies `cp_at_tsr(λ)` at four disc-power sites. The sizing path
already reads the measured blade-count surface through `cp_bem`.

The proposal is not "call `cp_bem` in the ODE". That would import two
defects. Section 3 prices them.

## 2. The definition

One read. One table. No new data.

```
cp_ode(n, λ) = cp_at_tsr(λ) · Rf(n, λ)    while cp_at_tsr(λ) > 0
             = cp_at_tsr(λ)               where cp_at_tsr(λ) ≤ 0
```

`Rf` is `_RATIO_CP` against `_RATIO_TSR`. Rows are exact in `n`. The read
is linear in λ between the eight knots and held at both ends.

Three properties do the work.

- At `n = 3`, `Rf ≡ 1`, so the read is the anchor bit for bit.
- The ratio corrects the positive branch of the anchor only. The negative
  branch is the blade's own flat-plate brake. No blade-count ratio may
  touch it.
- No lower clamp. A negative Cp is a brake, not a zero.

## 3. Two defects in `cp_bem`, priced

**(a) The sign inverts past the anchor zero.** The table holds its end
value at λ > 8.3905. For `n ≥ 4` that value is negative. The anchor is
also negative past λ 9.61. The product of two negatives is positive
power.

At λ 10.5 the anchor reads −0.3018. `cp_bem(9, 10.5)` reads +0.5926,
the Betz clamp. `cp_bem(4, 10.5)` reads +0.0726. A rotor at λ 10.5 would
be fed by the read that describes it.

**(b) The clamp deletes the measured brake.** `cp_bem(6, 7.0)` reads 0.
The measured surface reads −0.0267 there, and `n = 6` crosses zero at
6.839. Every negative reading is flattened: nine of the 536 measured
rows read zero or below (three at `n = 5`, six at `n = 9`), and the
interpolated band between them is wider still.

Neither defect fires on the sizing path, which asks only for a positive
radius. Both fire on the ODE path, whose λ band runs to 12
(`src/sim_frame.jl:471` clamps at 12).

This is why the proposal adds a second named read instead of reusing the
sizing one. The two reads answer different questions.

## 4. Where it lands

Four sites, one function.

| Site | What it reads today |
|---|---|
| `src/ring_forces.jl:233` | the ODE disc power and torque |
| `src/sim_frame.jl:157` | the frame torque balance |
| `src/sim_frame.jl:472` | the per-rotor power panel |
| `src/initialization.jl:1033` | the settle scan |

The settle scan must match the ODE disc branch. If it does not, the two
find different equilibria, which is what `test_settle_drag_alignment`
guards.

The expansion rotors at `src/initialization.jl:1053` stay on
`cp_at_tsr`. They are three-blade propellers and carry no line-count
surface.

CT does not move. Thrust reads `ct_at_tsr` at `src/ring_forces.jl:218`
and keeps reading it. RF-21 and NR-086 own that axis. One physics axis
per change.

## 5. What the surface reads

| n | peak Cp | peak λ | zero λ | Cp at 4.1 | Cp at 6.8415 |
|---|---|---|---|---|---|
| 3 | 0.308697 | 5.2000 | 9.6107 | 0.295535 | +0.225785 |
| 4 | 0.323635 | 4.2000 | 8.0991 | 0.319805 | +0.162351 |
| 5 | 0.318044 | 4.0145 | 7.4356 | 0.317877 | +0.089445 |
| 6 | 0.317304 | 3.4355 | 6.8392 | 0.303235 | −0.000392 |
| 7 | 0.317034 | 3.2000 | 6.4602 | 0.282961 | −0.103644 |
| 8 | 0.316255 | 2.9782 | 6.1546 | 0.260451 | −0.218589 |
| 9 | 0.319333 | 2.8131 | 5.7484 | 0.237335 | −0.340723 |

The zero for `n = 3` is the anchor's own crossing, not a ratio crossing.
The peak for `n = 3` is the AeroDyn table's peak. It sits above the regen
family's 4.825 and is not a discrepancy.

## 6. The consequence at the archive's operating point

NR-032 prints λ_tip 6.842 and Cp 0.2258. `cp_at_tsr(6.8415)` reads
0.225785, so the printed pair is a read of the anchor at the flown λ.

At that λ the surface reads:

- `n = 3`: 0.2258, unchanged. The anchor.
- `n = 4`: 0.1624, down 28 per cent.
- `n = 5`: 0.0894, down 60 per cent.
- `n = 6`: −0.0004. The crossing is at 6.8392, which is 0.0023 below the
  flown λ. An `n = 6` machine sits past its zero at the archive's point.
- `n = 7, 8, 9`: −0.10, −0.22, −0.34. Each brakes.

So an `n = 6` machine at 6.8415 has no equilibrium there. It brakes and
settles at a lower λ. That is the mechanism behind "the design λ moves
to 3 to 4".

## 7. The design window per n

The band where the surface reads at least 95 per cent of its own peak:

| n | 95 per cent band | width |
|---|---|---|
| 3 | 4.07 to 5.59 | 1.52 |
| 4 | 3.83 to 4.69 | 0.86 |
| 5 | 3.19 to 4.46 | 1.27 |
| 6 | 2.97 to 4.14 | 1.17 |
| 7 | 2.80 to 3.80 | 1.00 |
| 8 | 2.60 to 3.54 | 0.95 |
| 9 | 2.47 to 3.14 | 0.67 |

The routing's "3 to 4 for n 6 to 9" holds at `n = 6` and at the low end
of `n = 7`. At `n = 9` the whole band sits below 3.15. The precise form
is 2.5 to 4.1 across `n = 6..9`, falling with n.

## 8. The exposure, counted on the signed 508

NR-001 signs 508 ok designs. Their line counts:

| n | designs | share |
|---|---|---|
| 3 | 319 | 62.8 % |
| 4 | 144 | 28.3 % |
| 5 | 34 | 6.7 % |
| 6 | 3 | 0.6 % |
| 7 | 6 | 1.2 % |
| 8 | 1 | 0.2 % |
| 9 | 1 | 0.2 % |

- 11 of 508 are `n ≥ 6`. That is 2.2 per cent.
- 189 of 508 are `n ≥ 4`. That is 37.2 per cent, and every one of them
  moves in power if the campaign re-runs.

**RF-22's "251 of 404 ok rows are n 6-9" is exact for the bankderate
campaign, not for the signed one.** The bankderate run holds 404 ok rows
and 251 of them are `n ≥ 6` (62.1 per cent). The signed campaign is
bankderate2. It holds 508 ok rows and 11 of them are `n ≥ 6`
(2.2 per cent).

So "the first option voids the 6.84 operating point for half the
archive" describes the superseded run. It does not describe the
report's archive. The direction of the ruling does not change: a read
that feeds a braking rotor is wrong at 2.2 per cent as at 50. The cost
does change.

## 9. Fit against the fine-lambda table

`fine_lambda_bladecount.csv`, 536 rows, matched λ, rows where both the
surface and the measurement read positive:

| n | rows | bias | MAE | max abs |
|---|---|---|---|---|
| 3 | 82 | −0.0066 | 0.0069 | 0.0131 |
| 4 | 89 | −0.0053 | 0.0059 | 0.0299 |
| 5 | 84 | −0.0042 | 0.0050 | 0.0194 |
| 6 | 68 | −0.0009 | 0.0029 | 0.0082 |
| 7 | 68 | −0.0008 | 0.0044 | 0.0134 |
| 8 | 67 | −0.0016 | 0.0076 | 0.0246 |
| 9 | 59 | +0.0011 | 0.0083 | 0.0335 |

The peak λ tracks the measured peak within 0.08 for `n = 4` and
`n = 6..9`. `n = 5` reads +0.24 high (4.01 against 3.78).

## 10. Acceptance tests

`test/test_call7_nsurface.jl`. It is not wired into `test/runtests.jl`.
It wires in beside `test_bem_unified.jl` when the code lands.

The run reads 1,746 checks. 1,745 pass on the reference definition. One
is red: `isdefined(BEM, :cp_ode)`. That red is the implementation gate.

| Test | What it pins |
|---|---|
| A1 | `n = 3` identity is exact across λ 0 to 12 |
| A2 | the ratio reproduces at all eight knots |
| A3 | peak Cp and peak λ per n, and the ordering never re-sorts |
| A4 | the zero crossing per n, by bisection |
| A5 | the flown point: 0.225785 at `n = 3`, and `n = 6` just past its zero |
| A6 | no positive power past the anchor's zero, at any n |
| A7 | the measured brake survives, and the clamp deletes it |
| A8 | bounds: no Betz clamp fires, and the peak is 0.323635 |
| A9 | the design-point ratios at 4.1 keep their signed values |
| A10 | CT stays on the anchor, and the source guard holds |
| A11 | `cp_ode` exists, and the clamped sizing read never reaches the ODE |

A11 also holds a source guard: `cp_bem` must not appear in
`ring_forces.jl`, `sim_frame.jl` or `initialization.jl`. That is the
defect guard, not a style rule.

## 11. The register and the draft

No draft numeral moves. No register row opens. No campaign CSV re-stamps.

NR-031 and NR-032 stay as they print. Both are reads of a measured
`n = 3` surface at the flown λ. Neither is a read of the ODE.

The change is prospective. It moves the ODE. A campaign re-run is its
own ruling, and it would re-stamp the dataset.

## 12. Open for the aero counter-read

1. The `n = 5` peak, +0.24 high against the measured 3.776. Say whether
   the counter-read accepts the table's knot spacing as the cause.
2. The table's top two knots (7.3417 and 8.3905) for `n ≥ 5` have no
   counterpart in the fine-lambda CSV, which stops at 6.19 for those
   rows. The counter-read must take those two columns from the 96-point
   family record, `docs/validation/2026-10-04-bladecount-n-fit.md`.
3. The −1.04 Cp at `n = 9`, λ 8.39 is a measured ratio, not an
   extrapolation. Confirm it against the family record before the
   implementer relies on the brake magnitude.

## Handoffs

- @aero-validator: the counter-read keys on sections 5, 9 and 12.
- @software-validator: implement `BEM.cp_ode` and the four sites behind
  both signs. A11 is the gate.
- @author: no draft byte moves. NR-031 and NR-032 stand.
- @hermes: the queue can record item 2 as proposed, awaiting the
  counter-read.

science-validator, 2026-11-17.

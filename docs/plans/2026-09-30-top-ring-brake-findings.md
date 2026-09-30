# The banked top-ring model brakes the rotor, measured 2026-09-30

**Scope:** measurement and record only. This note changes no machine code.

## 1. The measurement

The acceptance gate `test/test_gate_v13.jl` test A1 gates the campaign winner
`scripts/results/v13_5kw_masslift_len18.8_rotorcount/best_vector.csv`. The gate
builds the winner with its own recipe (`scripts/ode_gate_v13.jl:87-120`). The
probe measured four configurations.

| No. | Configuration | P_gen_final | w_gnd_final |
|---|---|---|---|
| 1 | HEAD `1b4d9be` | **5.46 kW** | 13.46 rad/s |
| 2 | HEAD plus the uncommitted banked work, hub guard deleted | **3.43 kW** | 11.53 rad/s |
| 3 | Configuration 2 plus the disk gate closed | **0.80 kW** | 7.1 rad/s |
| 4 | Yaw-analogy expectation, `cos^3(19.95) = 0.8306` | **4.54 kW** | no run |

Row 1 reproduces the 2026-09-14 record of 5.65 kW and 13.61 rad/s. Row 3 is the
value that fails A1. Every row has a clearance of 5.73 m. Every row has a
healthy twist ratio of 0.50 or less. No row shows a collapse.

Row 3 costs seven times the power of row 1. The cube of the speed ratio gives
the same factor, because `(7.1 / 13.46)^3 = 0.147`. The machine loses speed
only. Nothing else breaks.

## 2. Why the winner is affected

The winner is a legacy 14-D vector. Its bank genes are not zero.

```
x[10] = 1.3831  -> clamped to 1        one rotor
x[11] = 19.9469 -> bank_top, 19.95 deg
x[12] =  6.6904 -> bank_bottom, 6.69 deg
```

The decoded rotor sits on ring 6 of 6. Ring 6 is the top ring. The chain has
three links.

1. `is_banked_rotor` reads 19.95 deg, so the top-ring exclusion no longer skips
   the rotor (`src/builders_util.jl:128`).
2. An expansion rotor claims ring 6. The built system reports
   `ring_idx=6, bank=19.9469, n_blades=3, tip=0.9458 m, mass=3.1082 kg`.
3. `has_top_expansion(sys)` returns true. The new gate at
   `src/ring_forces.jl:204` then skips the disk model. The machine has one
   rotor, and that rotor loses its drive.

## 3. HEAD forbids this change at three sites

The committed code already records the same finding, with its date.

- `src/builders_util.jl:61-62`: "The top rotor (ring_idx == n_rings) is the
  MAIN/hub rotor and is excluded (no expansion entry, it is modelled by the
  cp/ct rotor)."
- `src/builders_util.jl:88-91`: "high solidity killed the 5 kW seed:
  w -> -0.6 rad/s freewheeling ... Expansion rotors are ADDITIONAL rotors on
  intermediate rings only." The guard reads
  `rotor.ring_idx == n_rings && continue`.
- `src/ring_forces.jl:255-261`: HUB GUARD, dated 2026-08-22. "the ring hosting
  the MAIN rotor must never also get the expansion model, the same annulus
  would be double-modelled (the expansion alpha/induction model brakes at high
  solidity; killed the 5 kW seed)". The guard reads
  `er.ring_idx == hub_ri && continue`.

The uncommitted banked work deletes the third guard and relaxes the second. It
then reproduces the brake that both guards were written to prevent.

Row 2 of the table shows the effect of the deleted guard alone, with the disk
model still active. The power falls from 5.46 kW to 3.43 kW. Row 3 shows the
effect of the relaxed exclusion as well. So the work carries two defects.

## 4. The expectation disagrees with row 3

Tulloch equation (4.1) gives the power of a misaligned rotor as
`P = 0.5 * rho * Vw^3 * A * Cp * cos^3(beta)`. The reference row sits in
`docs/validation/trpt-reference/09-aerodyn-geometry-knobs.md:108`.

A bank of 19.95 deg is a misalignment of 19.95 deg. The factor is
`cos^3(19.95) = 0.8306`. Row 4 applies that factor to row 1 and gives 4.54 kW.

Row 3 reads 0.80 kW. That figure is 5.7 times below the expectation. A bank of
20 deg must cost a few tens of per cent of the power. It cannot cost 86 per cent.

The expansion model does not measure the machine at this ring. It brakes it.

## 5. The conflict to rule on

DECISIONS.md [2026-09-24] retires the top-ring exclusion for banked blades. The
2026-08-22 measurements forbid the same change. The run of 2026-09-30
reproduces the 2026-08-22 result.

The ruling is not wrong in its intent. The expansion model is not fit to own the
hub ring yet. A banked rotor of 19.95 deg is not a small coned blade row. The
expansion model brakes at high solidity, and the hub rotor is the widest annulus
in the machine.

The open question is which model is right for a banked top rotor. No model is
validated today. The disk model ignores the bank. The expansion model brakes.
The AeroDyn precone sweep is the tool that can answer the question. See
`docs/validation/trpt-reference/09-aerodyn-geometry-knobs.md`.

## 6. Two existing tests were weakened

The uncommitted work also lowered the coverage of two existing tests.

- `test/test_builders_v10.jl`: the hub fixture changes from `bank = 25.0` to
  `bank = 0.0`, so its exclusion assertion still passes.
- `test/test_wind_blocking.jl`: `@test ps[1].wind_factor ≈ BF` becomes
  `@test ps[1].wind_factor == 0.90`. A computed law becomes a literal. The
  fixture banks change from 25/20/15 to 0/20/15, with new manual factors of
  0.85/0.90/1.00.

## 7. Recommendation

Revert the six `src/` files to HEAD. Revert the two weakened tests. Remove
`test/test_banked_top_rotor.jl` from `test/runtests.jl`. Keep the documentation
that records the banked geometry and the AeroDyn knobs. Record the ruling as
blocked on a validated banked-rotor model.

Do not re-baseline the A1 assertion. Row 3 is a brake, not a machine.

## 8. Evidence

Commands, all on `rodbot-ThinkPad-P1-Gen-3`:

- `git worktree add --detach ~/Documents/GitHub/ktd-bisect HEAD` makes a clean
  checkout of HEAD next to the main repo, so the `CoaxialAutogyroStacking` path
  dependency resolves.
- `scripts/ktd-julia .scratch/probe_winner_power.jl` gives rows 1 and 2. The
  probe copies the A1 recipe from `test/test_gate_v13.jl:34-45`.
- `scripts/ktd-julia .scratch/probe_top_ring.jl` gives the rotor and expansion
  rotor fields of section 2. The probe is structural only, with no ODE solve.
- Row 3 is the A1 output line of the acceptance run on the working tree.
- Row 2 needs two steps. Apply `git diff HEAD -- src/` to the worktree. Then
  force the gate expression at `src/ring_forces.jl:204` to true.

Files:

- `scripts/results/v13_5kw_masslift_len18.8_rotorcount/best_vector.csv`, the winner.
- `src/builders_util.jl:61-62`, `:88-91`, `:128`, the exclusion and its record.
- `src/ring_forces.jl:204` in the working tree, `:255-261` at HEAD, the gate and the guard.
- `src/expansion_rotor.jl:136-151`, `top_ring_expansion`, the ownership authority.
- `docs/validation/trpt-reference/09-aerodyn-geometry-knobs.md:108`, Tulloch (4.1).

# Proposal: the tether drag coefficient becomes a per-case setting

**Date:** 2026-09-26
**Status:** Proposed. Awaiting Rod. No code changed.
**Ruling behind it:** Ruling 3 of 2026-09-26. Rod: "Yes, fair play, let's go with that",
with the values 1.2 for scaled work and 2.7 for Daisy-class work, and the loss reported at
both.
**Place in the order:** after Ruling 4, before Ruling 1.

## Terms

| Term | Meaning |
|---|---|
| drag coefficient | A non-dimensional number in the drag force. Written CD in the source. |
| tether | A main TRPT line. It runs near axial and the rotation sweeps it sideways. |
| ring beam | The tube of an intermediate ring. The rotation slides it lengthwise. |
| physics era | A stamp on campaign output. It marks which physics produced the numbers. |
| lumped value | A coefficient that absorbs losses which the model does not represent. |

## 1. What the ruling asks for

The ruling has two parts.

1. The tether drag coefficient becomes a per-case setting. The scaled campaigns use 1.2.
   The Daisy-class prototypes use 2.7. The loss is reported at both.
2. Rod offers Tallak Tveide, Storm Dunker and Janis Wacker as AWES line drag references.

## 2. What the source says, and why it changes the meaning

The reference library holds the scope of the printed drag model, in section 8 of
`docs/validation/trpt-reference/01-tulloch-relations.md`.

- The source uses 1.2 in every simulation. It swept the coefficient from 0.5 to 5.
- The best fit to the Daisy experiment is 2.7. The source calls that "over double the value
  of 1.2 used in all other simulations".
- The same page states that the models underestimate the drag of the whole Daisy system,
  and that the rings and the bridle lines are absent from the model.

So the pair is not two candidate line coefficients. The 1.2 is a physical line value for a
cylinder in cross-flow, which is the correct form for a tether. The 2.7 is a lumped value
which absorbs the ring drag and the bridle drag that the model omits.

The setting must therefore carry its meaning, not just its number. A case that states
"2.7" tells a reader nothing. A case that states "Daisy-class lumped calibration" tells the
reader that the number hides two absent components.

## 3. The sites that read the coefficient

`TETHER_DRAG_CD` is read at five places.

| Site | Use |
|---|---|
| `src/rope_forces.jl:428` | the ODE tether drag force, which now carries its moment |
| `src/initialization.jl:971` | `settle_parasitic_drag_power`, the settle's loss term |
| `src/objective_v6.jl:333` | `P_seg_raw`, the objective's line drag power |
| `src/ring_element_analysis.jl:369` | the ring element analysis |
| `src/ring_element_analysis.jl:414` | the same analysis, second call |

`TUBE_DRAG_CD` is read in `src/dynamics.jl:142` and in `src/ring_element_analysis.jl:565`.
The objective also models a ring beam drag in its P_beam component. See finding F12.

## 4. The mechanism

Use a module-level `Ref`, the pattern the repo already uses for `RING_ATTACHMENT` and for
the `EXPANSION_PHYSICS` toggles. A `Ref` avoids a field on `SystemParams`, which is built
positionally by six presets.

- `TETHER_DRAG_CD` stays as the default constant. The `Ref` starts at that default.
- A named setter takes a symbol: `:physical_line` sets 1.2, `:daisy_lumped` sets 2.7.
- A reader returns the value and the name together, so a report can state both.
- Campaign scripts set the value at start-up and stamp it into the CSV provenance.

A global switch is not thread-safe. The acceptance suite runs each file in its own process,
so that is not a problem today. Record the limit in the docstring.

## 5. Tests, written first

T1. The ODE drag torque scales with the coefficient. Set the value to 2.0 and confirm the
moment doubles. Reuse the measurement method of
`test/test_trpt_drag_torque_balance.jl`, which is already proven.

T2. The default equals the constant. This catches a silent drift of the default.

T3. The screen loss scales with the coefficient. Check `settle_parasitic_drag_power` at two
values.

T4. The named options set the two values, and the reader returns the matching name.

## 6. The default, and the order of work

**Recommendation: keep the default at 1.0 until F11 and F12 are settled.**

The drag terms are wrong in two opposite directions today. F11 makes the tether drag about
a quarter low at the ring ends. F12 may make the ring beam drag far too high in the
objective. To tune the coefficient now would fit it to two known errors at once. That is the
same mistake as calibrating before the torque route was fixed.

So the sequence is:

1. Set the mechanism and the two named values. Keep the default at 1.0.
2. Settle F11, which raises the tether drag towards the printed anchor.
3. Settle F12, which decides the ring beam term.
4. Move the default to 1.2 in one act, and record a new physics era.

## 7. Reporting the loss at both values

Add one helper that returns the tether drag loss at a stated coefficient. The campaigns call
it twice and write two columns, under names that carry the meaning:

- `drag_loss_cd12_physical`
- `drag_loss_cd27_daisy_lumped`

The provenance stamp already carries the git hash and the geometry fingerprint. Add the
coefficient name, not only the number.

## 8. Risks

- A campaign run at a new coefficient is not comparable with an older run. The physics era
  stamp exists for this, and the proposal uses it.
- The global `Ref` is not thread-safe. State the limit in the docstring.
- The F12 check may change the objective. Do that before any campaign depends on the new
  default.

## 9. What must not change

- The tether drag form. A tether is a cylinder in cross-flow, so CD near 1.2 is right.
- The ring beam projection in the ODE. `src/dynamics.jl:136-138` is correct.
- The printed anchors. They stay as the oracle in the reference library.

# Void taxonomy, 2026-10-20

This page classifies the failures of past campaigns. Each class gets a name, a
signature, and a remedy. The page also gives the archive template.

The page signs no count and no per-cell claim. The numbers register owns every
count.

## Anchor

- HEAD: 581d33ff963adebb62647b77529bf4022748b03c
- Source A: `DECISIONS.md`, 98 dated entries.
- Source B: `docs/validation/physics-validation-ledger.md`, retired claims E1
  to E7.
- Source C: `scripts/results/archive_void_*/`, three folders.
- Source D: `scripts/results/ladder_v13_rerun_2026-10-20.csv`, md5 74408ea1.

## Five mechanisms

The classes divide by where the number came from. A number can come from a
builder, a model edge, a reader, a harness, or a solver that cannot reach the
design point. Each origin has a different remedy.

### V0, build mismatch

The machine that ran was not the machine in the file.

Signature: the decoder geometry and the ODE geometry differ.

Instances, all from 2026-08-24 and 2026-08-26:

- The builders x6, x7 and x9 were dead.
- The settle scan used rotor offsets, not absolute radii.
- The linear-taper builder made negative ring radii.
- The rotor-to-system ring index read one short.

Remedy: one equivalence test between the decoder and the builder.
`test_builders_v10.jl` holds it.

### V1, surrogate escape

The search found the corner where a cheap model is invalid. The aero result
stays honest. The price does not.

Signature: the winner sits at two or more active bounds, and the model that
prices it was never checked at that corner.

Instances:

- 2026-08-22, the blade-mass law priced span to the cube while the decoder set
  the span from `λ` and `r_rotor`. Claims E7 and DECISIONS
  [2026-08-22] record it. The winners sustained power, and only the mass was
  wrong.
- 2026-08-28 and 2026-09-02, the same corner priced a 4.4 kg machine that
  weighs 10.94 kg on the corrected law. The corner survived the audit. The
  number did not.

Remedy: the corner test. Read the active bounds of every winner. Audit the
pricing model at that corner before the number prints.

### V2, selection error

The gate read the wrong element.

Signature: the reported value is finite and plausible, and a sibling element
is worse.

Instances:

- 2026-08-26, `FoS_min` read one element off and hid the buckled lowest ring.
  The reported value was 67.54 and the re-gate read 0.556.

Remedy: the gate reports the worst element with its index, never the first
element and never the top element.

### V3, default fill

A required argument was left out, and a default supplied a number.

Signature: the run log prints a value that the design did not choose.

Instance: 2026-10-20, `evaluate_design` ran without `P_rated`. Both boxes took
the 10,000 W default, so the 50 kW box was scored at 10 kW torque against 50 kW
capacity. `ec69c4e` fixes it. The 10 kW box stands byte-identical across the
fix, and that pair is the attribution control.

Remedy: required keyword arguments. A run header prints every load the result
used.

### V4, model limit

The model could not settle the design point.

Signature: the settle returns zero on every state (cliff), or it settles at a
parked speed with no power (stall).

Instance: 2026-10-20, the ladder census. Twenty cliff cells, fourteen stall
cells, one clearance cell, seven pass cells.

Remedy: no verdict word. The class prints as UNPROVEN by this gate. The fix is
a precondition, not a new design.

## The lexicon trap

One word can carry two mechanisms across eras. Classification by word then
fails, and classification by signature holds.

- "Stall" on 2026-08-24 meant a NaN-poisoned settle that returned the 60 rad/s
  fallback. "Stall" on 2026-10-20 means a settled machine that parks at 0.46 to
  0.85 rad/s. The two words describe a defect and a behaviour.
- "λ³" named the blade-mass law until 2026-08-25. The name then changed to
  "span³", because `λ` is TSR and the law prices the span.

Rule: every class name carries its numeric signature in the archive record.

## Archive template

Every removed campaign gets one `STATUS.md` in its folder. Five fields:

1. State: live, void, or superseded.
2. Class: V0 to V4 from this page.
3. The tell: the check that catches it now, named by file or test.
4. The anchor: launch HEAD, physics era, and artifact md5.
5. Superseded by: the path that replaced it.

The three `archive_void_*` folders already carry the substance in `VOID.md`
and `PROVENANCE.md`. The template adds field 2, and it adds field 5 to the
older pair.

## Inventory

`scripts/results/` holds 79 folders. Nine carry a file that states void,
superseded, or a verdict. Sixty-six carry nothing, so a reader cannot tell a
live campaign from a dead one by inspection. Four more carry provenance only.

The template is a mechanical job. It needs no simulation and no physics
decision.

## What this page does not do

It does not sign a count. It does not re-open a retired claim. It does not
replace `DECISIONS.md`, and it does not replace the register.

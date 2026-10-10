# Room response: item 1.2 counter check (2026-10-10, aero-validator)

Scope: the counter request in
`science-validator-2026-10-10-item12-lift-margin.md`.
That seat asked this seat to verify two arithmetic lines and the cited code.

**Result: verified. The identity closes bit-exact. This seat signs the
item 1.2 response.**

## The two lines, re-derived

- 1.5 x 20.69846825623688 x 9.81 = 304.5779603905257 N.

- 304.5779603905257 / sin(70 deg) = 324.1250954336462 N. That is NR-010
  exactly, difference 0.0.

- Full-mass ratio: 304.5779603905257 / (25.69846825623688 x 9.81) = 1.20815.

## The code

- `src/lift_kite.jl:197`: `sized_lifter_for` carries margin 1.5 and
  elevation 70 degrees.

- `src/lift_kite.jl:208`: g = 9.81.

- `src/lift_kite.jl:209-212`: the Rod ruling of 2026-08-21. The sizing
  mass excludes the 5 kg lifter.

- `src/expansion_analysis.jl:44`: `include_lifter` defaults to true. The
  docstring at lines 41 to 42 records the exclusion from tension sizing.

## Notes for the draft pass

- Write 304.58 N. A paraphrase that reads 304.5 N uses g = 9.807 and
  does not close the identity.
- The requirement question stays open for Rod: where the 1.5 check sits
  (sky hook or lift bearing). The implemented rule sits at the lift
  bearing.

Aero-validator, 2026-10-10.

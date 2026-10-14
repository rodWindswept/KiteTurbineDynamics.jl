# Room response: the Harris-3.5 render deltas (2026-10-14, figures seat)

**Status** LANDED. The two mechanism-pair plates take the Harris 3.5
deltas and the 1.3 binding-limit ruling, on the existing capture. No
drawn value moves. No new data runs.

**Seat** figures-images-diagrams. **Read at** the script commit
`671ab96`. The artifacts land with this receipt.

## The ring plate (`ring-utilisation`, v5)

- The axis is logarithmic, six decades from 10⁻⁶ to the unit value. The
  fail boundary stays at the right edge, so the empty field to its left
  is the margin. Every bar reads at its own scale.
- One utilisation bar per ring. The axial/bending stack retired, per
  the founder generation notes (the F7 row). The bending share reports
  in the caption: below 0.05 per cent of each loaded ring's utilisation,
  with R5 bending alone.
- The corrected interaction form N/N_crit + √(M_ip²+M_oop²)/M_el
  replaces the blind √(M²) in the legend. The SPEC pins the M_ip/M_oop
  component form, so the reviewer's y/z letters resolve to the kit
  convention. A flag follows in case the literal letters are wanted.
- Caption text updates ride the kit: the bar sentence, the bending
  sentence, the R5 sentences.

## The twist plate (`twist-limit`, v4)

- The two changelog lines (the 2026-08-13 overshoot and the read-cap
  line) leave the plate notes for the failure ledger. This executes the
  2026-10-12 review carry.
- The δcrit labels re-space clear of the tick column, right of each
  tick. No label touches another label or a tick.
- The title, subtitle and panel-A label measure against the binding
  limit, the realisability floor (the 1.3 ruling).

## Checks

- Script commit `671ab96`. The three-way render check (delivered, A, B)
  reads byte-identical across all ten outputs. F-LABEL passes on every
  run.
- `scratch/fig_35_check.py` and its log: 65 checks, 0 fail. It asserts
  the new forms, the retired forms, the stamps, the manifest pins and
  the drawn values.
- The map rows 6 and 7 take the landing, and delta v29 records it.
- STE rc=0 on every touched file (ring captions 1.30 and twist captions
  1.49 per 100 words).
- Output md5s and sha256s sit in `scratch/fig_35_runs.md5` and the two
  manifests.

## Flags carried (no action requested)

- The draft prose still measures the twist against δcrit at its 3.3 and
  3.4 sentences. The plate now measures against the binding limit. The
  prose alignment is the author's fold.
- The R5 readout keeps its true value (FoS 326,974). A short form like
  "> 10⁵, no compression" needs a display ruling before it can print.
- The wider rework (sizing-case markers, the three-limit draw with δα*,
  the margin panel) needs the extract extension and decisions 1 and 3.
  The generation notes sit untracked at
  `docs/reporting/figures/SUggested generation methods.md` for triage.
- The floor value (72.25°) still needs its register row. It pends with
  the ledger pass.

## Handoff

- @aero-validator: the F-VALUE counter-read on both plates is the last
  gate for rows 6 and 7. The check script is a starting point.
- @author: the caption text sits in the kits for the fold.
- @science-validator: the floor row pends, and the captions keep their
  cites.
- Placement confirmed: the plates seat at their point of reference in
  the main body, not in a grouped section (the plain-English share ask).

---

figures-images-diagrams, 2026-10-14.

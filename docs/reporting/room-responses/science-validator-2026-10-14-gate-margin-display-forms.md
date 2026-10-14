# Room response: the gate-margin column display forms (2026-10-14, science-validator)

**Status** A display-form note lands for the SW2d margin column's FoS row.
The note goes in before the AU9 fold. **Seat** science-validator.
**Read at** HEAD `0cbb9b8`.

The AU9 fold brings the SW2d margin column into the section 3.3 gate table.
One row of that column needs report forms first. This seat signs the note
and the forms.

## 1. The catch

The supply sits in the SV5 margin block
(`docs/reporting/room-responses/science-validator-2026-10-13-sv5-nr042-signed-and-margin-block.md`).
Its FoS figures read from the full value: `14.972` on `2.5`, margin
`+12.472`, `+498.9 per cent`, `5.99 times`.

Two rules block those forms at the fold.

- The gate table is an enumerated site of the minimum factor of safety.
  The report reads `15.0` at 1 dp there, and the full precision stays
  internal (tracker display forms, `2ebbd22`).
- The display guards read `14.97` and `14.972` zero at report sites.
  A literal `14.972` in the column would trip them.

## 2. The note

The register block "Display-form note: the gate-margin column figures
(NR-009 on NR-015)" pins the FoS row.

- The operands read `15.0` over `2.5`.
- The margin reads `+12.5`. The per cent reads `+500.0`. The ratio reads
  `6.00 times`.
- The internal forms stay in the SV5 basis and here. They do not print.
- No other figure in the column moves under the note.

The forms hold as displayed. The printed operands give the printed margins.

## 3. Evidence

- `scratch/sv_gate_margin_display_check.py` and its log. The check reads
  the committed register. It recomputes both form sets. All checks green.

## 4. Handoffs

- @author: fold the FoS row at the pinned forms. The outcome cell keeps
  `pass, 15.0 minimum`. The basis notation `14.972 vs 2.5` does not print.
- @science-writer: the sweep basis for the folded column reads at the note.
- @aero-validator: the counter-read basis for the FoS row reads at the note.
- @hermes: the queue can record the note.

---

science-validator, 2026-10-14.

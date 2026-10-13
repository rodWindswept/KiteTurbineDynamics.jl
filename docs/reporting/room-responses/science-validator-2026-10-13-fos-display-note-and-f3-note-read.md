# Room response: the FoS 1 dp display note and the F3 note read (2026-10-13, science-validator)

**Status** The register signs the FoS reduced display form. The F3 eval-timeline note read at `20da96c` holds from this seat. **Seat** science-validator. **Read at** HEAD `6fd7dc6`. Committed bytes only.

## 1. The FoS at 1 dp (NR-009), signed

The founder docx return carries a 1 dp display call at one site: the abstract sentence. The return note reads "1dp resolution fine here" (note 3, `scratch/au_draft_docx_notes_extract_2026-10-13.md`, source sha256 `e6b743d2...`).

The register block signs the forms:

- Signed value `14.971791422208508`. Row form 14.972. At 1 dp the value rounds to 15.0.

- The returned copy carried 14.9. That form is a truncation. The fold takes 15.0.

- The row keeps 14.972. No value moves.

## 2. The F3 note read at `20da96c`

The update from the fig seat holds. Read from this seat, committed bytes only:

- The row joins correctly. NR-042 carries the clearance floor 1.5 m and the "≥ 1.5 m, read once" string. The row also carries the winner 5.468 m at decode and the margin +3.968 m. It matches the signed register row cell for cell, cited to SV5 `8c278a5`.

- "No unrowed numeral remains on the plate" verifies. The census over the drawn SVG text (`scratch/sv_f3_census_check.py` and its log) maps every drawn readout to a signed row. The speed pair 10.17 and 13.38 (NR-016, NR-029). The power readings 5.309, 5.314 and the 5 kW floor (NR-008, NR-027, NR-039). The strain readings 1.448, 2.841 and 5.798 (NR-013 ext). The 10 s gate placement (NR-015). The 1.5 string now takes NR-042. What remains reads as scale: axis ticks, the "first 12 ms" inset extent and the 100 Hz rate caption.

- "No plate byte moves" verifies. The figures tree diff over `ed5fb29..20da96c` reads two markdown files only. The five outputs, the manifest and the ledger do not move, so the v19 F-REPRO, F-LABEL and F-VALUE pins stand.

- One boundary, informational. The drawn footer carries the row list through NR-039. NR-042 joins the footer list at the next plate build. Nothing needs to move now.

## 3. Evidence

- `scratch/sv_f3_census_check.py` and `scratch/sv_f3_census_check.log`.

- Register block: "Display-form note: the minimum FoS at 1 dp (NR-009)".

---

science-validator, 2026-10-13.

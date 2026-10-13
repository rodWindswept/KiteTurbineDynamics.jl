# Room response: NR-043 signed — the winner blade span (2026-10-13, science-validator)

**Status** This seat signs NR-043 into the register. The blade-span ask (founder note 13) now has its register form. **Seat** science-validator. **Read at** HEAD `2db50f9`. Committed bytes plus a fresh probe re-run.

## 1. NR-043: the blade span, signed

Founder note 13 asks the section 2.1 figure to carry the blade span. The quote reads "include blade span" (`scratch/au_draft_docx_notes_extract_2026-10-13.md`). The figures seat recorded the source: the span reads in the NR-032 block findings. This block lifts it to its own row.

- Span: `1.4994019682084492` m. Tip radius minus inner edge: `5.629560432565964 - 4.130158464357515`. Quote form `1.499`.

- The 0.7 / 0.3 ring anchor closes both radii about the hub ring (`src/objective_v10.jl:374-376`).

- Reproduction: the probe re-run at HEAD equals the committed log, line for line. No commit touches `src/` from the probe log landing `25ff00e` to the re-run. Log: `scratch/sv_nr043_span_rerun_2026-10-13.log`.

- The aero seat counter-read the tip pair and this span on 2026-10-11 (`docs/reporting/room-responses/aero-validator-2026-10-11-tipref-counterread.md`).

Checker: `scratch/sv_nr043_span_check.py` and its log. All 24 checks pass from the committed bytes.

## 2. The display form, for the figures seat

- The plate prints the dimension at three decimals: `1.499 m`. That matches the drawn radii precision (4.580 m and 0.804 m). The row keeps the full value.

- The dimension reads the built blade span, inner edge to tip. It is not the ring radius, and not the tip offset alone.

@fig-img-diagrams: the register form is in. The kit note and the map row can take the dimension at the next render.

## 3. Evidence

- `scratch/sv_nr043_span_check.py` and `scratch/sv_nr043_span_check.log`: 24 checks, all pass.

- `scratch/sv_nr043_span_rerun_2026-10-13.log`: the fresh re-run at `2db50f9`.

- Register block: "Derived row: NR-043, winner blade span".

---

science-validator, 2026-10-13.

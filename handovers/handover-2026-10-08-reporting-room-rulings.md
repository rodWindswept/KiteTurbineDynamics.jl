# Handover: reporting room rulings after register v1

**Date:** 2026-10-08. **From:** @hermes (reporting room lead). **To:** the
reporting room.

**Context:** the boot doc
(`handovers/handover-2026-10-08-reporting-room-boot.md`) stays unchanged.
These rulings answer the open questions the room raised. They apply from
today.

## Rulings

- **Sky anchor.** The report name for the three-way knot is sky anchor.
  The code uses `sky_anchor` throughout. The topology load-path diagram
  uses sky anchor. Sky hook joins the retire list. First use still
  carries the definition.
- **Rapid and ODE.** The report names for the two evaluation paths are
  rapid (the `:warm` static pre-solve) and ODE (the `:cold` settle and
  kickstart). Methods maps these names to the code symbols at first use.
  The framework and Track C use the same names.
- **references.bib.** @science-writer owns `docs/reporting/references.bib`.
  @author seeds it with the 17-row anchor table from the AWE-context
  outline. Each entry needs a resolvable DOI, arXiv, or URL before any
  prose cites it. Citations gate like register rows (framework section
  10).
- **NR-012 wording.** @science-validator lands the wording amend. The
  claim must state that all fields agree at the stored precision, and
  that island 3 agrees at full precision. Values do not change. Amend
  pattern.
- **Aero counter-read.** @aero-validator counter-reads rows NR-007,
  NR-008, NR-009, NR-010, NR-011, NR-014, and NR-016 against the section
  4 re-eval and the Phase 0 audit. Amend pattern (append only).
- **Software pass.** The renderer software pass request sits in
  `handovers/handover-2026-10-08-renderer-software-pass.md`.

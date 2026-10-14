# Room response: the v5 system-anatomy re-cut, the cone ring (2026-10-14, figures seat)

**Status** LANDED. **Seat** figures-images-diagrams. **Read at** `d243b37`.

## The pass

The feedback routing sent comment 3 (id 2) to this seat. The anatomy
plate did not name the cone ring. The later plates carry it, and the
hero legend reads "ring, cone".

The fix: the v5 re-cut adds the label "R5, the cone ring" with the line
"the shaft cone starts here", pointing at the base ring of the widening
cone. The leader carries in-script clearance asserts against all drawn
ink. No new number prints. The plate stays on NR-011, NR-017 and NR-043.

## Surfaces

- The generator at `d243b37`: the label entry, the header note and the
  clearance asserts. The ledger reads 34 strings.
- The kit records: the register note (the v5 re-cut, the v5 hash block,
  Delta v3), the captions note, and the SPEC (thirteen labels, the
  leader clearance in the checks).
- The map takes the row 2 cell and delta v35.
- The draft takes the figure-provenance appendix pins (the script-commit
  cell and the four output-hash cells), the v0.44 title bump and the
  tracker entry. No seat marker and no declared value moves.

## Checks

- Two full runs at `d243b37` stay byte-identical across all five
  outputs. pdflatex reports zero error lines and zero overfull boxes.
- `scratch/fig_sa_v5_check.py` and its log read 31 checks, 0 fail. The
  PDF text layer carries both new strings.
- The vision pass on the delivered render reads clean: the leader lands
  on the cone-base ring, no crossings and no text collision.
- STE rc=0 on all six edited files.

## Handoffs

- @aero-validator: the re-cut re-keys at your desk, as routed. The
  label, the ledger and the re-pinned appendix row read for the
  counter-read.
- @science-writer: the caption text does not move. The kit note and the
  map delta record the label change.
- @hermes: the queue can record the re-cut.
- @user: the anatomy drawing now names the cone ring, ahead of the
  corner grid.

---

figures-images-diagrams, 2026-10-14.

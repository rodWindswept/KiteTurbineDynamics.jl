# Room response: the levers caption seating headers (2026-10-14, figures seat)

**Status** LANDED. The two levers caption files take the seated head. The
author promoted both draft files to the builder name at `5a7a6b4`, bytes
unchanged, so the seats resolve. The head still read as a draft for the
author seat. This pass seats it.

**Seat** figures-images-diagrams. **Read at** `9c6cb68`.

## The change

- `figures/pca-landscape/captions.md` and `figures/pca-atlas/captions.md`
  take the seated head: the status line, the date, the site and the reading
  order, the split note, and a delta line.
- The retired form: "Captions draft", "Status DRAFT", "Review input for the
  author seat", "Ledger strings only".
- The caption text and the provenance lines stand unchanged.

## What this does not move

- No render bytes move. The v3 hash blocks recompute from the committed bytes
  on both kits. Ten pins, all match.
- The build parser reads the same plain and technical sections, byte for
  byte. The next build reads the same captions from the same file name.
- The seats stay resolved, and the provenance lines keep their rows.

## Checks

- `scratch/fig_sh_edit.py` applies the pass from the pre-edit copies
  (`scratch/fig_sh_before_landscape.md`, `scratch/fig_sh_before_atlas.md`).
- `scratch/fig_sh_check.py` and `scratch/fig_sh_check.log`: 37 checks, 0
  fail. The parse identity reads plain md5 `8983e84f` and `8487791e`, tech
  md5 `701f6fed` and `04324208`, on both sides of the pass.
- The file md5s: landscape `24c36939` to `6c4679b7`. The atlas: `67f03e65`
  to `5b3c9a87`.
- STE rc=0 on both files (0.77 and 1.18 per 100 words). The flag counts
  match the pre-edit counts.

## Handoff

- @author: the next build reads the seated headers. The caption text stands.
- The eval-timeline and k-basis kits take the same treatment at their folds.

---

figures-images-diagrams, 2026-10-14.

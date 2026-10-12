# Room response: the figure-caption split (three built kits)

**Seat** figures-images-diagrams. **Date** 2026-10-12. **Status** LANDED.
**Read at** `819b09f`.

Answers the full-feedback delta map item 9: the figure-caption split,
against the v0.15 appendix. Also answers checklist item 16 (shorten the
figure captions, move the provenance to the appendix).

## The split

The three built kits now carry the split:

- `figures/ring-utilisation/captions.md`
- `figures/twist-limit/captions.md`
- `figures/machine-evolution-strip/captions.md`

Each kit carries a plain caption, a technical caption, a provenance line
and a split note. The plain and technical captions carry the scientific
text only. The provenance line carries the audit tokens. It resolves to
the figure-provenance appendix (draft v0.15). The report prints the
scientific captions, and the stamp on each exhibit and the appendix
carry the provenance.

The kits keep the register citations: the provenance line cites every
row. No number prints without its row.

## The tokens that left the captions

| Kit | Leaves the caption | Lands in |
|---|---|---|
| Ring utilisation | the capture pair and the capture instant | the provenance line, the plate stamp, the appendix, NR-025 |
| Twist limit | the capture pair and the capture instant | the provenance line, the plate stamp, the appendix, NR-025 |
| Machine evolution strip | the NR-036 citation, the extract reference and the canvas values | the provenance line, register-status, the manifest |

The capture instant reads s = 1724859 (t = 49.99999483862295 s). It
stays on the stamps and in NR-025.

## The provenance lines

- Ring utilisation: data commit `dd3cc6a` · capture `pair-extract-2026-10-08-winner-ops` · rows NR-021 · script commit `eacf073`.
- Twist limit: data commit `dd3cc6a` · capture `pair-extract-2026-10-08-winner-ops` · rows NR-022, NR-023 · script commit `eacf073`.
- Machine evolution strip: data commit `dd3cc6a` · extract `strip-extract-2026-10-09-best-so-far` · rows NR-005, NR-006, NR-011, NR-036 · script commit `74cfef9`.

Each line matches its appendix row on the extract, the cited rows and
the script commit. The dataset commit `dd3cc6a` holds across all three.
No number changed. No render moved.

## Notes for the room

- Draft §3.5 cites NR-005, NR-006 and NR-011 for the strip. The appendix
  and the kit carry NR-036 too. Fold at the v0.18 pass, or the builder
  reads the kit.

- Figure 1 (system anatomy) keeps its caption draft. The split lands
  with its build, after the Track D term picks.

- The figure items 2 and 3 of the full feedback (caption
  self-containment, the FoS readout) are not in this split. Item 4
  (numbering) lands at assembly.

- Counter-read invited.

figures-images-diagrams, 2026-10-12.

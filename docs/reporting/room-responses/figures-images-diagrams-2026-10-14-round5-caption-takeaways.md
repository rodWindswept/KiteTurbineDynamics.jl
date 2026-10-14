# Room response: the round-5 caption dedupe (2026-10-14, figures seat)

**Status** LANDED. **Seat** figures-images-diagrams. **Read at** `94aa219`.

## The pass

The feedback routing sent comments 12 and 13 (ids 11 and 12) to this
seat. The ring-utilisation and twist-limit plain captions repeated one
claim from the technical tier. The caption audit swept the pattern to
rows 6, 7 and 9.

The fix: each plain tier reads one takeaway sentence. The two tiers no
longer repeat one claim. The shipped sentences:

- Ring utilisation: "Every airborne ring passes its structural check
  with a wide margin."
- Twist limit: "The shaft passes its twist and torque checks along its
  whole length."
- Evolution strip: "The search improves the machine at every recorded
  step, from the common seed to the campaign winner."

The strip claim holds on the extract. The seven selected objectives
fall strictly, 36.109 to 27.364 kg-equivalent.

## Surfaces

- The three caption files (rows 6, 7 and 9): the plain-tier rewrite, the
  intro clause and one takeaway note per kit.
- The two SPEC caption plans take the new takeaway and a delta line
  (ring v7, twist v6).
- The two register notes take a Delta v3 line each.
- The map takes delta v34.
- Text only. The diff is eight markdown files. No render byte moves.
  The draft builder reads the new tiers at its next build.

## One recorded choice

The strip plain tier also retired "A lower number is better". The
one-sentence takeaway cannot carry the reading key. The falling labels
and the word "improves" carry the direction. A one-line restore stays
ready if the room wants the key in the technical tier.

## Checks

- `scratch/fig_cd_edit.py` applies the pass. `scratch/fig_cd_check.py`
  and its log read 37 checks, 0 fail.
- The builder caption parser dry-runs on all three kits. Both tiers
  stay non-empty, and the provenance section does not parse as a tier.
- STE rc=0 on all eight files. The reading falls on every file: the map
  1.95 to 1.94, ring captions 1.30 to 1.11, twist captions 1.49 to
  1.26, strip captions 1.40 to 0.89.

## Handoffs

- @science-writer: the caption deltas for sweep 29 read at this receipt
  and the kit notes.
- @aero-validator: the caption text joins the next copy rebuild for its
  desk read, as routed.
- @hermes: the queue can record the pass. The cone ring and the corner
  grid head next at this seat.
- @user: the three flagged captions now read as single takeaway
  sentences. The copy picks them up at its next rebuild.

---

figures-images-diagrams, 2026-10-14.

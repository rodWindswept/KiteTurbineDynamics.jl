# Room response: the AU3 wording set lands — draft v0.31 (2026-10-13, author)

**Status** LANDED. **Seat** author. **Read at** `08e1d95`.

AU3 folds from the feedback round 2 plan (parts 6.1 and 14), the ungated part. No value moves.

## What lands

- Section 2.1: the polygon sentence takes the active-rotor form. Inactive slots do not create physical blades (6.1, 14.5).

- Section 3.3: the blade-scale sentence reads two slots. Slot 1 reads 0.82 on the active rotor. Slot 2 reads 0.20 and stays inactive (6.1, 14.6). The bank sentence reads two bank-angle slots. Ring 6 decodes the active bank, 7.088 degrees (6.1, 14.7).

- Section 3.3: the era sentence drops the development-history phrase. The report covers the wind-authority era campaign (14.1).

- Section 3.1: the seed lines take the runner-checked policy. Each island starts its population from the same seed genome. The other members draw at random under a fixed seed per island (14.4). The runner check: population[1] = the common seed, and Random.seed!(42 + island - 1), read at scripts/run_v13_5kw_masslift.jl.

- Section 4.3: the wind bullet gains the base-case line (14.8). The gust and direction exclusions held already.

## Held (routed)

- Part 6.2, for the aero read. Forms as drafted:

  FoS form: "The campaign applies a minimum structural FoS gate of 2.5. The same value sets the reference for the objective's structural penalty. A design must pass the floor to be accepted, and the penalty shrinks as the margin grows."

  Line-length form: "The campaign line length is the nominal TRPT line length used in the scored geometry, 18.8 metres (NR-015). It differs from the lift-line geometry in section 3.3."

  Window axis form: "The scored run spans 0 to 50 seconds. The relax takes the first 10 seconds and the measurement window the last 40. The final capture sits at t = 50 seconds."

- Part 14.2: the Daisy sentences wait on their rows.

- Part 14.3: the presumption line waits on AU4.

## Receipts

- STE gate, draft: 4441 to 4538 words, total 5 to 5. No category gains.

- STE gate, tracker: 2019 to 2094 words, total 10 to 10. No category gains.

- Token diff, draft: add the pin 31 and the two slot numerals, 1 and 2; remove the pin 30. No value token moves.

- Token diff, tracker: add 31. Nothing removed.

- Citation gate: rc=0, 32 cited rows, all signed (44 signed rows).

- Check script: `scratch/au_v031_au3_wording.py` and its log.

## Notes

- The review copy rebuilds at the tip: `scratch/report-pdf-build/draft-live.docx`.

author, 2026-10-13.

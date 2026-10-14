## Sweep 26: v0.40, 2026-10-14

**Target** `docs/reporting/drafts/2026-10-08-report-first-draft.md` at
`0e7d396` (v0.40, the decision shape), spanning one mover from
`7d46148` (the Sweep 25 span end). The file carries zero diff to the
branch tip at sweep time.

**Register** `docs/reporting/numbers-register.md` at `a7d09eb`, zero
diff to the tip.
Moved since Sweep 25: the item-8 aero leg, two appended blocks.
The blocks carry the NR-047/NR-048 counter-read verdict and the NR-025 wording amend.
The move is append-only, 54 added lines and none removed.
No signed row changed.

**Results**

- Span note: this pass closes the one draft mover since Sweep 25.
  The span `7d46148..ad56692` carries non-draft landings outside this gate.

- Span landings: the sweep-25 train (`ff159d7` to `bbc214e`), the queue
  `9166686`, the item-8 aero leg (`a7d09eb` to `8d3b61d`), the item-5
  counter-read `d0679d3`, the figures seat page (`e04e072`, `7fc0717`)
  and the v0.40 set (`0e7d396`, `bacf9e2`, `716bd3a`, `ad56692`).

- Queue note: the queue takes the v0.39 span at `9166686`.
  Item 8 and the item-5 counter-read close, and PL13 closes at the
  author seat. Noted, not gated.

- Register companion note: the aero leg takes the room-consultation
  line to the detector form (one line, 1/1), and the `.ste-exempt`
  takes the consultation row under its comment extension.
  Noted, not gated.

- Bracket count: the body carries the two number-gate brackets and the
  six seated markers, per part 11.

- STE gate, draft: words 6229 to 6281, total 6 to 6, `per100w=0.10`,
  and `em_dash=2` throughout, the guidance-only pair inside the frozen
  axis names.
  The hook lines hold at `passive_voice x1` and `long_paragraph x5`.

- STE gate, tracker: words 2490 to 2542, total 10 to 10, `per100w`
  0.40 to 0.39. The category set holds at `long_sentence x1`,
  `semicolon x1`, `contraction x1`, `passive_voice x2` and
  `long_paragraph x5`.

- Offender delta, draft and tracker: no offender line moves, entry for
  entry. Only the header lines change.

- Token diff, draft (`12a5753` to `0e7d396`), 1 arrival form, 1
  occurrence, raw 1/1.
  The arrival is the pin `40`. The removal is the pin `39`.
  No pair reads.

- Value cross-check: no value form moves.
  The pin pair is a version mark, and the shape additions carry no digits.

- Push-note check: the v0.40 receipt declares the same pin pair and
  the tracker `40` add. The recount holds, token for token.

- Arithmetic: no value moves, and the standing sums hold (NR-002, NR-001).

- Shape census: the six shape lines read at their sites in sections
  3.4 to 3.6.
  Sections 4 and 5 hold byte-identical against the base.

- K-story census: the table reads at the NR-047 display forms, and the
  reject row prints its status and power.

- Safety census: the `enabl` and `breaks only` forms read zero across
  the draft. The detector pair and the safety set read at their sites.

- Rename census: the old form reads zero sites across the draft, the
  candidates and the tracker.
  The new form reads at three draft sites and both candidates sites,
  one form.
  The old-form sites survive in the record and verbatim classes (`cadf83d`).

- Retired phrasing: no hit on the banned forms. The standing near-hit
  holds, the section 1 negation, "It is not a rigid driveshaft".
  The lift-chain terms read in their split sense.

- Superseded forms: no hit. `3.816`, `14.972` and the message example
  `14.97` all stay unwritten.

- Head status note: no change. The head line reads "Draft v0.40", and
  the nomenclature and references stubs keep their pending markers.

- Held tokens: `1.94` and `5.18` stay under the section 4.2 note, and
  the k `1.94` row reads NR-047. `3.55` stays flagged in the tracker.
  The section 5 Daisy gate stands.

- Cited commits: the draft names seven (`dd3cc6a`, `a76c5e9`,
  `31ca00d`, `74cfef9`, `9cecee3`, `671ab96`, `e23f226`), plus the era
  label `95c385d`. All resolve in the tip ancestry.

- Freeze re-check: the levers block re-reads byte-identical in the
  draft at `0e7d396`. The draft region, the receipt region and the
  block file carry the same bytes. The block md5 reads
  `7bbd964db09d2b33269ce5cb8c334054`.

- Pins note: the two Harris-3.5 plate pins recompute on the delivered
  bytes. The ring PNG reads `f49aaaa1` and the twist PNG `00cd857a`,
  both matching the appendix cells.

- Review copy: the copy verifies current at v0.40 for the founder
  read. Nothing moved since the build (md5
  `835de8d8dc92e209d23cba39e7c11549`), and the build inputs carry zero
  diff from `0e7d396` to the tip.

- Copy census: the shape lines read in the copy, and the v0.39 marks
  read zero.

- Cascade note: the renumber stays ruled. AU9 and the partner-gated
  tails head the author queue.

**Finding**

No value discrepancy found.
The span folds the decision shape with the pin move alone.
Every token accounts, and the one push matches its declared set.
The register takes the two append-only blocks, and the frozen block re-checks.
The offender delta reads header-only.
The draft passes the gate at the push.

**Next run** at the next draft push.

# Science-writer seat, 2026-10-20: the section 6.1 cut and the section 8 list

Base: the working tree draft reads `5108e6d1`, 1299 lines and 10,674 words.
G6 is applied on disk and not committed.

## Section 6.1: the four locks fit inside the cut

Section 6.1 held 805 body words in 18 paragraphs.
The four do-not-trim strings sit at lines 1117, 1118, 1165 and 1169.
All four sat inside the section, so the ruling was not a choice between the cut and the locks.

The cut keeps the gate, the rim-bridle reaction path and the two tests.
It drops the lifter-stack paragraph, the self-lift trade, the Cp cost, the hub-moment check and the lateral-mode check.
The heading reads "6.1 Cyclic pitch on the ring rotor", under comment 97.
Paragraph 2 is the blessed block, verbatim.

## The science-validator hedge

The first cut dropped "almost" from the shaft sentence and "would" from the rim-bridle sentence.
That printed a hypothetical as fact inside potential extension work.
The fix is the science-validator sentence at 19 words.
It reads: "The shaft carries tension and torque but almost no bending, so the rim bridle would take the tilt reaction."

## Comment 99, comment 98 and comment 95

Comment 99 rides in paragraph 1.
It reads: "Tension above the rotor reduces that steer, though it cannot change the phase relation."
That sentence follows the aero pin. The reversal is kinematic, and stacking shrinks the steer.
Comment 98 has no slot under a two-paragraph cap, so comment 100 drops it.
It returns as one `someawe.org` bibliography entry and one sentence.
Comment 95 adds "Many more remain open." to the section 6 intro.
"None of these" replaces "None of the three".

## The author fix and the v3 path

The author seat found the real fault in version 2.
The cut kept the lock "Until they run, the rotor phase lag stays a free parameter."
It dropped the plural that the lock points at.
The fix names both tests.
It reads: "A BEM sweep from 0 to 10 degrees of tilt and a lateral-mode check are the two tests."
The fault was mine and the fix is right.

The author v3 patch carries the wrong path header.
It reads `a/scratch/sw_sec61_cut_v2.md`, so inside the repo it edits the candidate and not the draft.
`scratch/sw_cut_v3_pathfix.patch` carries the same body at the draft path.
Applied to `bfef2c95`, it lands `d54d6ae4`.
Reverse-applied, it returns `bfef2c95`.

## The chain

| Link | State | Measure |
|---|---|---|
| disk | `5108e6d1` | 1299 / 10,674 |
| G7 | `b9d01717` | 1299 / 10,670 |
| batch 1 | `265f90d5` | 1303 / 10,743 |
| cut v2 | `bfef2c95` | 1222 / 10,112 |
| pathfixed v3 | `d54d6ae4` | 1222 / 10,117 |
| section 8 | `fc44f70a` | 1242 / 10,587 |

Final section 6.1 reads 170 body words in two paragraphs by the register convention.
That is a 79 per cent cut from 805.

## Section 8: the list is built from references.bib

`docs/reporting/references.bib` holds 17 entries.
14 carry a DOI. Two carry an archive or report URL. One carries a slides note.
All five names in comment 14 sit in it with a year, a title and a DOI link.
The list is `scratch/sw_refs_list.md`, 462 words.

The science-validator checked the list against the bib in both directions.
17 entries match 17 keys.
Every DOI and both archive URLs read byte-identical.

Seven entries carry no in-text name in section 1.
They are Read, Jamieson, Aull, Joshi 2023, Joshi 2025, Weber and Hancock.
The author seat places them as clauses on sentences that already make the claim.
Nothing in the list moves when those clauses land.

## Section 8: the gate rule

A reference list cannot pass the gate as written.
Quoted titles add 3 flags and 10 dashes.
Jamieson carries a semicolon and Tulloch carries an em dash.
The Weber author list reads 25 words.
The list is data and not prose.
`scratch/sw_ste_lint_refs.patch` drops numbered entries under a References or Bibliography heading before the scan.
The section prose still counts.

The author seat measured the blast radius on five files.
Only the section 8 candidate moves.
It reads 25 at 0.24 with 10 dashes, and 22 at 0.22 with the rule.
The science-validator then probed for a leak.
A numbered list under a methods heading still flags every passive.
The rule is scoped to the heading.

## Section 8: the unresolved proper name

The science-validator found one proper name in section 8 with no entry.
Ranneberg sat inside the sentence that records its own removal.
The provenance survives in `references-verification.md:75`.
The report does not need to carry it, so the sentence is deleted.

The reading moves, and the reason is stated so no one reads it as instrument drift.
The deleted sentence carried one passive, in the words "was dropped".
It also left the section 8 paragraph at seven sentences.
At six sentences the paragraph is no longer a long paragraph.
The file reads 20 at 0.20 with counters p4, l3, c1, n1 and lp11.
It read 22 at 0.22 with p5 and lp12 before.
The base is unchanged at 22 at 0.22.
Both falls are real prose improvements.
Both show in the diff.

## Apply order

The section 8 patch is pinned to `d54d6ae4`.
It still applies after the seven author clauses, because its context is section 8.
The hash guard then changes with that pass.
Apply section 8 last, or recompute the guard.

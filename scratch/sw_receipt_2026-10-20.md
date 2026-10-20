# Science-writer seat, 2026-10-20: the section 6.1 cut keeps every lock

Base: the working tree draft reads md5 `5108e6d1`, 1299 lines and 10,674 words.
G6 is applied on disk and not committed.

## Finding 1: the four locks fit inside the cut

Section 6.1 runs from line 1084 to line 1179.
It holds 807 words in 19 paragraphs.
The four do-not-trim strings sit at lines 1117, 1118, 1165 and 1169.
All four sit inside section 6.1.
So the ruling is not a choice between the cut and the locks.

Candidate: `scratch/sw_sec61_cut.md`, md5 `f5bf426085e2c779c79042744124a838`, 1217 lines and 10,020 words.
Section 6.1 reads 153 words in two body paragraphs, an 81 per cent cut.
STE reads 22 at 0.22.
Counters: long_sentence 3, contraction 1, passive 5, nominalization 1, long_paragraph 12, em dash 0.
The counters match the base.
The rate moves from 0.21 to 0.22 because the word count falls and the flag count does not.
Every lock string returns one hit.
`the tether-to-blade rule` returns one hit.

Paragraph 2 is the blessed block, verbatim.
Paragraph 1 keeps the gate, the rim-bridle reaction path and the test.
The cut drops the lift-kite stack, the self-lift trade, the Cp cost of the axial component, the hub-moment check and the lateral-mode check.
The heading reads "6.1 Cyclic pitch on the ring rotor", under comment 97.

## Finding 2: section 8 can be built from references.bib

`docs/reporting/references.bib` holds 17 entries.
14 carry a DOI.
Two carry an archive or report URL.
One carries a slides note.
All five names in comment 14 sit in it with a year, a title and a DOI link.
The list is `scratch/sw_refs_list.md`, 462 words.

The draft names 10 of the 17 in section 1.
Seven carry no in-text reference: Read, Jamieson, Aull, Joshi 2023, Joshi 2025, Weber and Hancock.
Either the prose cites them or the list drops them.

A reference list cannot pass the STE gate as written.
Titles carry one semicolon and one em dash.
Author initials split as sentences.
The Weber entry holds 12 authors and reads 25 words.
A pasted list adds 4 flags and 10 em dashes to the file total.
Section 8 needs a linter exemption, or a build step that renders the list from the bib.

## Finding 3: the 168 target clause prints false

The founder answered in the room: the lean points at a point on the TRPT section line, not at the next ring.
`toward the ring below` prints false against that answer.
Delete the clause and the sentence is true.
It reads "The machine plates show the blade leaning downward."

Candidate: `scratch/sw_168_drop_target.md`, md5 `b9d01717e7fd5e4f0f9ba0baaaf5f42e`, 1299 lines and 10,670 words.
STE reads 22 at 0.21.
`toward the ring below` returns 0 hits.

## Version 2: the hedge is restored and comment 99 rides along

Base: `265f90d5`, the G7 patch plus the author batch 1 applied, 1303 lines and 10,743 words.
The science-validator found one fault in the first cut.
The compression dropped "almost" from the shaft sentence and "would" from the rim-bridle sentence.
That prints a hypothetical as fact in a section headed potential extension work.
The fix is the science-validator sentence, verbatim, at 19 words.

The cut also deleted the anchors for comments 98 and 99.
Comment 99 now rides in paragraph 1: "Tension above the rotor reduces that steer, though it cannot change the phase relation."
That sentence follows the aero pin: the phase reversal is kinematic, and stacking reduces the response size.
Comment 98 has no slot under a two-paragraph cap.
It is recorded as dropped by comment 100.

One structural move, stated for the record.
Comment 99 makes paragraph 1 seven sentences.
Lock three therefore opens paragraph 2, before the blessed block, so both paragraphs hold six sentences and no long-paragraph flag enters.
The alternative is lock three at the end of paragraph 1 and STE 23.
All five lock strings return one hit each.

Section 6 intro, comment 95, two lines outside the cut: "Many more remain open." joins the "three of them" sentence, and "None of these" replaces "None of the three".

Candidate: `scratch/sw_sec61_cut_v2.md`, md5 `bfef2c95506daec34cb62c1436bd433a`, 1222 lines and 10,112 words.
Patch: `scratch/sw_sec61_cut_v2.patch`, one hunk, applies clean to `265f90d5` and lands the same md5.
Section 6.1 reads 171 body words in two paragraphs, from 805, a 79 per cent cut.
STE reads 22 at 0.22.
Counters: long_sentence 3, contraction 1, passive 5, nominalization 1, long_paragraph 12, em dash 0.
The counters match the base.
The patch also applies to the G6 disk copy and lands `fecf29bd`, because batch 1 does not touch this region.
The base is `265f90d5`, and any other base fails the hash test.

## Version 3: the lock points at two tests, and the patch path is corrected

The author seat found a real fault in version 2.
The cut kept the lock "Until they run, the rotor phase lag stays a free parameter." and dropped the plural it points at.
The only test sentence left read "A BEM sweep from 0 to 10 degrees of tilt is the test", which is singular.
The fix names both tests and keeps the lock at the head of paragraph 2.
It reads "A BEM sweep from 0 to 10 degrees of tilt and a lateral-mode check are the two tests."
The fault was mine and the fix is right.
Final state `d54d6ae4`, 1222 lines and 10,117 words, STE 22 at 0.22.

The v3 patch carries the wrong path header.
It reads `a/scratch/sw_sec61_cut_v2.md`, so inside the repo it edits the candidate and not the draft.
The re-pathed hunk is `scratch/sw_cut_v3_pathfix.patch`, one line, same body.
Applied to `bfef2c95`, it lands `d54d6ae4` on the draft path.
The chain in the room works only with this header.

## Section 8: the reference list is built, and the gate needs one rule

Candidate `scratch/sw_sec8_candidate.md`, md5 `f58d6778a4a8b8dc4742597b5a658169`, 1242 lines and 10,592 words.
It adds 17 entries under section 8, one per source, with authors, year, title, venue and a DOI or archive link.
14 entries carry a DOI, two carry an archive or report URL, and the Hancock entry carries the slides note.
The lead sentence reads "Each entry carries a DOI link, an archive link, or a slides note."

A reference list cannot pass the gate as written.
The entries add 3 flags and 10 dashes, because titles are quoted material.
Jamieson carries a semicolon, Tulloch carries an em dash, and the Weber author list reads 25 words.
The list is data and not prose, so the linter should skip the entry list and still count the section prose.
`scratch/sw_ste_lint_refs.patch` adds that rule: numbered entries under a References or Bibliography heading are dropped before the scan.

Measured with the rule: the base reads 22 at 0.22 and the section 8 candidate reads 22 at 0.22.
Measured without the rule: the candidate reads 25 at 0.24 with 10 dashes.
The rule applies clean to `ste-lint.py` and changes no existing file's reading.

Seven entries carry no in-text reference in section 1: Read, Jamieson, Aull, Joshi 2023, Joshi 2025, Weber and Hancock.
The list holds all 17 because the bibliography is the report source set.
Comment 98 returns here if Rod wants it: one bib entry for someawe.org, then one sentence.

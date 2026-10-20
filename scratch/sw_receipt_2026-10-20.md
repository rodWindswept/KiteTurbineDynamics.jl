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

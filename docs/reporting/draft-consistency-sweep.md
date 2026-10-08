# Draft consistency sweep: the running record

**Slug** `draft-consistency-sweep`. **Status** LIVE. **Seat** science-writer.

**Scope** the report draft against the numbers register. A read-only pass.
The sweep changes no register row and no draft line. This record is its only
artifact.

**Method.** Each sweep runs four checks:

- The STE gate by hand. Command: `python3 ste-lint.py --fail-above 2.0 <file>`.

- A grep for retired solver phrasing. Patterns: `adaptive`, `DifferentialEquations`.

- A value cross-check. Every printed value against its signed row or side block, at the quoted precision.

- A number-token diff. The current draft against the previous one. The pattern: `(?<![\w-])\d+(?:\.\d+)?(?![\w-])`. It ignores identifiers and dates.

## Sweep 1: v0.2, 2026-10-08

**Target** `docs/reporting/drafts/2026-10-08-report-first-draft.md` at `25b9e91`.

**Register** `docs/reporting/numbers-register.md` at the same commit.

**Results**

- STE gate: words 2627, total 0, `per100w=0.00`, exit 0. The reading in the author note reproduces.

- Retired phrasing: no hit.

- Value cross-check: every printed value matches its row at the quoted precision.

- The checked set covers NR-001 to NR-018, the rotor-bank note, and the caption rows NR-017 and NR-018.

- Token diff against v0.1 (the attachment staged with the room message): zero value tokens dropped or altered.

- Five tokens arrived: 1.94, 5.18, 21.2, 25.0, 3.55. All five sit inside brackets. Four wait on register rows. The 3.55 arrival carries the non-operating flag.

- Two standalone "2" tokens left. Both were comment text that the fold replaced with the full answers.

**Finding**

One stale token, and no more. The header reads "cited by row ID (NR-001 to NR-018)". The register now carries signed NR-019 and NR-020.

The proposed replacement line, for the author seat:

> Status DRAFT. Numbers come only from signed register rows, cited by row ID.

The range form stales at each sign-off. The register stays the authority.

**Next run** at the next draft push.

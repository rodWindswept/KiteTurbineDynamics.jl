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

## Sweep 2: v0.3, 2026-10-09

**Target** `docs/reporting/drafts/2026-10-08-report-first-draft.md` at `0b0d7f1`
(the v0.3 pass; zero diff to the branch tip `35dec11`).

**Register** `docs/reporting/numbers-register.md` at `a443e26` (zero diff to the
tip). Includes the amended blocks: the rotor-bank note, the caption rows NR-017
and NR-018, the bank-derate rows NR-019 and NR-020, and the mechanism-pair and
ODE rows NR-021 to NR-026.

**Results**

- STE gate: words 2641, total 0, `per100w=0.00`, `em_dash=0`, exit 0.

- Retired phrasing: no hit.

- Value cross-check: every printed value matches its row or side block at the
  quoted precision. The checked set covers NR-001 to NR-018, the rotor-bank
  note, and the caption rows NR-017 and NR-018. Both v0.3 edits verify clean:
  the k bracket close and the NR-016 read. Rows NR-019 to NR-026 print no
  values in this draft, so nothing from them enters the value check yet.

- Number-token diff against v0.2 (at `25b9e91`): one arrival, all removals
  accounted.

  - Arrived: `3` (the v0.3 pass note).

  - Left: one duplicate `3.55` (the open k bracket collapsed to a single
    flagged mention); the `§2.3` and `§3.3` cross-references in the
    open-requests list (three bullets rewritten as status lines).

  - Held, inside their brackets: `1.94` and `5.18` (§4.2 ledger), `21.2` and
    `25.0` (§2.3 length screen), `3.55` (flagged non-operating).

**Finding**

The sweep-1 finding is closed: the v0.3 pass retired the status range; the
header now reads "cited by row ID". No value discrepancy found.

One carry-note for the author seat: the §2.3 bracket reads "Step-ceiling and
protocol figures". The draft uses "figure" for a diagram elsewhere (§8). If
the intent is the step-law and protocol values, "values" may read cleaner.

**Next run** at the next draft push.

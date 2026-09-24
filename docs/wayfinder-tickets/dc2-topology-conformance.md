# dc2 — Conformance of the record to the code

> Part of [Decisions Conformance Audit](../wayfinder-decisions-conformance.md) · `wayfinder:research` · **blocked by dc1, dc3**

## Question

For every ruling in `docs/agents/physics-topology.md`, where does the code implement it,
where does a test check it, and does it hold?

One table row per ruling:

| ruling | topology doc section | source that implements it | test that checks it | verdict |
|---|---|---|---|---|

Verdict vocabulary, one word per row:

- **agrees** — the source implements the ruling and a test checks it.
- **conflicts** — the source contradicts the ruling.
- **untested** — the source implements the ruling and nothing checks it. **This is the
  repeated-mistake surface.**
- **unimplemented** — the ruling has no source at all.

## Scope

Report the record as it stands. Do not fix anything. Do not accept a docstring as
evidence of behaviour: read the code that runs.

Section by section:

- §1 fixed versus floating (ground ring, backline anchor, the free-floating column).
- §2 the lift chain, four links, four names, plus §2.1 damping and crosswind symmetry.
- §3 the load path, §3.1 bridle geometry, §3.1.1 one ring plane, §3.2 the back line.
- §4 rotor models, plus §4.1 annulus sizing and the `1/N²` claim.
- §5 the eight pre-flight checks, each as a question about the code.
- §6 silent truncations: verify each of the five rows against the current source.
- §7 measurement traps: verify each against the current source.

## Method

1. Read the document as it stands after dc1.
2. For each ruling, `search_files` for the named symbol or constant. Read the call
   sites, not the definitions alone.
3. For each claim of a check, open the test and read the assertion. A test that asserts
   a tautology, or pins a no-op, is not a check. The `backline_payout` fault is the
   worked example: the docstring promised a trim, and the test asserted that the trim
   changed nothing.
4. Record the path and line for every cell. A cell without a line reference is not
   evidence.

## Prior art

- `docs/validation/physics-validation-ledger.md` — claim-to-status mapping, section A
  through D. Do not duplicate it; link to it, and correct it where the audit disagrees.
- `docs/agents/instrument-trust-log.md` — the fault ledger. Rows marked OPEN are
  candidates for an **untested** verdict.
- `docs/audit-2026-08-20-standards-debt.md` §2 — fifteen physics findings, some since
  fixed. Re-check them, and mark which are closed.

## Output

`docs/reports/2026-09-24-record-conformance.md`, read-only, with the table above and a
short list of the **untested** rows ranked by what they protect.

## Sizing

Two to three sessions, one section group each.

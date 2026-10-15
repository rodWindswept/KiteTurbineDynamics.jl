# Room response: the MCP tooling pilot (2026-10-15, hermes)

**Status** LANDED, pilot complete. The adoption call sits with the
founder. **Seat** hermes (main session, laptop). **Read at** `d0ed902`
(branch `bank-derate-cos2p65`).

**Source** the go-ahead from Rod in the main session, 2026-10-15.

## What ran

Two free research servers now run on the laptop. The pilot put them
through the reference record, `docs/reporting/references.bib`
(18 entries).

- Scholar Sidekick runs over its hosted endpoint on the anonymous free
  tier. It carries 7 tools: citation verify, bibliography audit,
  retraction check, open-access check, resolve, format, export.

- The arXiv server runs locally (`arxiv-mcp-server` 0.8.2, 19 tools). It
  covers search, download, full text, LaTeX sections, citation graph,
  BibTeX export and topic watches. Paper storage sits at
  `~/.hermes/cache/arxiv-papers`, outside the repo.

- Both passed `hermes mcp test`, and the tools call cleanly from a live
  session. Both sit in the laptop main profile.

## Controls, run first

- The fabricated control (a real DOI with an invented title) read
  `mismatch` at high confidence.

- The known-good control (Loyd 1980) read `ambiguous` at high confidence,
  on its documented title variant. The bulk pass reads the same entry at
  low confidence.

- The retraction control (Wakefield 1998) read retracted, with the
  notices attached. A second control (Loyd 1980) read no retraction.

- Open-access checks: Tulloch and Joshi read `gold` with publisher links.
  Loyd read `closed`.

## The bulk audit against the 8 Oct pass

One call audited the whole file in about 3.5 seconds.

- Of the 15 entries the 8 Oct pass checked, the tool resolved 14.

- Twelve read `matched`. One carries the known Pereira year note at
  medium confidence.

- Two read `mismatch` at low confidence. Both causes carry notes. The
  Loyd title variant is already noted in the seed. The Flather note
  reflects the scan year on the archive record.

- Weber read `not_found`. The 8 Oct pass read the PDF and the OSTI
  companion record. That read still holds.

- The 3 entries with no public source read `not_found`, as expected.

- The record carries no retraction flags, and no entry reads as a
  fabrication.

- Note for the next pass: the audit needs `format=bibtex`. Auto-detect
  fails on the commented seed file.

## The arXiv lane

- Search, full text, LaTeX section reads and BibTeX export all work. The
  demo fetched one paper in full (58,077 characters) and listed 15 LaTeX
  sections.

- Coverage note: the reference record is journal-side, so the preprint
  corpus overlaps it thinly. This lane serves discovery and reading, not
  the reference check.

## No record edits

The pilot made no edits to `references.bib` or
`references-verification.md`. It ran as a tool trial, not as a
verification pass. The certifying standard stays Crossref plus the
manual read.

## Flags

- @science-writer: raw artifacts sit in `scratch/mcp-pilot-2026-10-15/`.
  If the founder adopts, the next verification pass can run through these
  tools. The tool that finds a paper never certifies it. The endpoint
  runs as a third-party hosted service. Send citation data, not
  unpublished text.

- For @author and @science-writer: the new writing-craft points sit in
  the laptop main profile skills (`awes-reporting`, section "Writing
  craft"). The `ste-writing` word list gains `novel` and `unprecedented`.
  The seats can fold the same lines into their skill copies.

- @hermes: seat-profile wiring follows the adoption call.

**Evidence** `scratch/mcp-pilot-2026-10-15/` (probe, verdicts, controls,
readback). The readback carries the wiring commands, endpoints and version
pins. This pass lands this receipt.

Recorded by @hermes (main session, laptop).

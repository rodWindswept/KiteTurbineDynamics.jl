# Room response: sent-build check and review-status snapshot (2026-10-11, science-validator)

Rod requested this pass on 2026-10-11. Scope: the current report PDF,
built and sent 2026-10-11 09:52 BST, checked against the Claude review
of 2026-10-10.

## Sent build, verified

The builder is `scripts/build_draft_pdf.py` (lead seat). The draft input
is `e0abbce`, v0.9. It has not changed since 2026-10-09 22:21.

The citation gate passed on a re-run here: exit 0. Every one of the 26
cited rows is signed. The register holds 28 signed rows in total. NR-027
and NR-028 stay uncited by this draft. That is informational. The rewrite
cites them.

The artifact is `draft-live.pdf`, sha256
`c8cceecaa5ab1f5efbd7c85c791f4a809f135be516c3dd5d7f5b7dc509ab835b`.
It is byte-identical to `draft-e0abbce-20261011-085202.pdf`.

The PDF runs 12 pages at A4. Page 1 reads clean. The ring-utilisation
plate and the twist-limit plate render as vector on pages 7 and 8. Their
captions and source lines sit in place. The lead seat delivered the file
to the channel at 09:52:21, prose caveat stated.

## Review status against the draft

Closed in the record since the review:

- 1.2 lift margin: resolved. The counter signs bit-exact (`264a008`). The
  draft pass writes 304.58 N.
- 1.4 ring floor: check landed (`264a008`). Verdict: no ring at the OD
  floor. R2 to R5 sit at the wall floor.
- 1.5 length screen: pair closed (packet `9f29df1`, this seat `b07a7b3`).
  NR-027 and NR-028 filed.
- 1.6 objective gap, 1.7 damping values, 2.2 gene table, 2.7 DE settings:
  answered in the lead packet.
- 1.8: the three ambiguities resolved. The draft edits remain.

In flight:

- 1.1: the window-mean omega row waits on one trace read or small probe.
- 1.3: gate status and the 1.05 rationale remain open.
- 2.1: register rows and one profile pointer remain open.
- Sign-off gates on the packet items stay open. This seat holds several.

Pending the rewrite round:

- The prose is v0.9, exactly as reviewed. The text fixes stay out of this
  PDF. These cover 1.2 wording, the 1.8 edits, 2.3 to 2.6, 2.8, 2.9 to
  2.12, 3.1 and 3.5. This matches the lead caveat.
- The register-notes tail line "signs once committed" is stale now.
  NR-027 and NR-028 are committed. Refresh it in the rewrite.

science-validator, 2026-10-11.

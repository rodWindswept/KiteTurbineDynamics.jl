# Room response: sweep 38, the v0.92 to v0.93 span (2026-11-18, science-writer)

**Status** LANDED. **Seat** science-writer.
**Read at** `f005788c`. The record sits in `docs/reporting/draft-consistency-sweep.md`.
**Span** `690efb5a..f005788c`. The read ran on 2026-11-18.

## The span

The span carries one draft mover, `76b2fb48`, and one register mover, the NR-086 cherry-pick.
The draft moves from v0.92 to v0.93, and the register reads 86 base rows.
The fold prints the Glauert block, the Tveide credit, entry 19 and the nine appendix cells.
B16 retires with its anchor, so the reader sheet reads 46 sites.

## STE

| State | Words | Total | Per 100 words |
|---|---|---|---|
| v0.92 | 12,909 | 30 | 0.23 |
| v0.93 | 12,989 | 32 | 0.25 |

The offender delta reads contraction 1 to 2 and long paragraphs 15 to 16.
Long sentences hold at 8, passive at 5 and nominalization at 1.
Em dashes read 0 at both ends.
The new contraction is `Tveide's`.
The new long paragraph is the appendix intro.
It reads 6 sentences at v0.92 and 8 at v0.93, because the credit joins it.

## The token and form diff

The tokens that arrive read `0.5192`, `0.3434`, `12.4` and `27`.
The `27` is the second half of `16/27`, and the token census cannot see the fraction.
The forms that arrive read `16/27`, `a = 1/3`, `a = 0.3434`, `12.4 per cent` and `1/3`.
No token and no form leaves.
This is the first fold where the form census carries two arrivals the token diff cannot see.

## The finding

The credit prints `Tveide's note states`.
The possessive costs one STE violation, so the fold reads 32 where 31 was available.
And `note` names the joint short note that the ruling says does not exist yet.
The credit sits one line under a sentence that names Tulloch.
`Tveide states` clears both, and this seat measured that form at 0.00.
The fix costs one word and one rebuild.

## Checks that pass

- Cited rows: 60 distinct, every one present and signed against 86 rows.
- Appendix cells: 10 of 10 match their manifests, at `4444c516` and `87e6b10`.
- Render pins: 9 of 9.

- Plate census: 0 row ids, 0 era tags, 0 commit-like tokens.
- Send-ready: 3 of 3 arrows, exit 0.

The cells read 10 of 10 only after the gate fix in
`science-writer-2026-11-18-appendix-pin-gate-parse.md`.
Before it, the gate parsed one row and reported a green table.

## The built copy

The reader PDF reads 1,899,462 bytes and md5 `f002c5fcb471929441fa6182d879f266`.
Its text layer carries `0.5192`, `16/27` and the credit.
It also carries `Tveide's note states`, so the finding above is in the release file and not only in the draft.

## What this pass moves

It moves no draft byte and no register row.
It lands the record section and this receipt.

science-writer, 2026-11-18

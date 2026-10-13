# Room response: the Track D queue reads v12 — two founder-docx note entries (2026-10-13, science-writer)

**Status** LANDED. **Seat** science-writer. **Read at** `d2d641f`.

## What lands

- **The glossary queue reads v12.** The two items from the founder docx
  return take their queue places, as @author routed them. Track D
  ratifies or rewrites each entry.

- **Bank derate** (machine group). The row takes the mechanism clause from
  the note: banked blades cone out of the ring plane, so the rotor sweeps
  less streamtube frontal area. The form and action stand. The ground adds
  the note pin (`c2e2aee`).

- **Segment torque margin** (structural-limit group). A new row: the ratio
  of torque capacity to the segment torque carried, at the same state.
  The least value governs. Ground: register NR-040 (NR-023 strings),
  `src/sim_frame.jl`, `src/trpt_twist_limit.jl`.

## Receipts

- Commits: `04d2179` (glossary v12), `d2d641f` (the evidence set). Push
  follows this response.

- STE, glossary: words 4133 to 4242, total 11 to 12, per100w 0.28. rc=0.
  The one addition is the v12 delta paragraph. No value slot moves.

- Evidence in `scratch/`: `sw_gloss12_lint_before.txt`,
  `sw_gloss12_lint_after.txt`, `sw_gloss12_diff.txt`,
  `sw_gloss12_sentprobe_final.txt`.

## Flags

- SW3b (part 11.3, the era map) comes next, ahead of the era treatment at
  the fold. A first name check: bank derate and the fold carry rows.
  cp fix, folded class and wind-authority do not. The era map pass routes
  them.

- Sweep 15 runs at the next draft push.

science-writer, 2026-10-13

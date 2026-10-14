#!/usr/bin/python3
# -*- coding: utf-8 -*-
"""The appendix re-pin and the levers rows: the edit pass (figures seat).

Applies the ten computed fix lines from the aero counter-read
(docs/reporting/room-responses/aero-validator-2026-10-14-harris35-fvalue-counterread.md):
eight plate output-hash substitutions and both plate script-commit cells.
Adds the levers rows 20 and 21 with their output hashes (the query
resolution), fixes the count sentence, bumps the draft head to v0.35,
takes the tracker entry and refreshes this seat's handover.

Every substitution asserts its exact occurrence count. Re-running fails
loudly on the first assert (the edit is a one-shot).

Run: /usr/bin/python3 scratch/fig_repin_edit.py
"""

from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
DRAFT = REPO / "docs/reporting/drafts/2026-10-08-report-first-draft.md"
TRACKER = REPO / "docs/reporting/draft-tracker.md"
HANDOVER = REPO / "handovers/handover-2026-10-14-reporting-room-figures-images-diagrams.md"


def sub(text, old, new, n=1):
    c = text.count(old)
    assert c == n, "expected %d of %r, found %d" % (n, old[:72], c)
    return text.replace(old, new)


# ---------------------------------------------------------------- draft ---
d = DRAFT.read_text()

# 1. The head bump.
d = sub(
    d,
    "Internal engineering report. Draft v0.34. Date 2026-10-14.",
    "Internal engineering report. Draft v0.35. Date 2026-10-14.",
)

# 2. The count sentence.
d = sub(
    d,
    "One row per built exhibit. All four read dataset commit `dd3cc6a`.",
    "One row per built exhibit. All six read dataset commit `dd3cc6a`.",
)

# 3-4. The two script-commit cells (eacf073 -> 671ab96).
d = sub(
    d,
    "| Ring utilisation plate | `pair-extract-2026-10-08-winner-ops` | NR-021 | `eacf073` | `post-95c385d_wind-authority` |",
    "| Ring utilisation plate | `pair-extract-2026-10-08-winner-ops` | NR-021 | `671ab96` | `post-95c385d_wind-authority` |",
)
d = sub(
    d,
    "| Twist limit plate | `pair-extract-2026-10-08-winner-ops` | NR-022, NR-023 | `eacf073` | `post-95c385d_wind-authority` |",
    "| Twist limit plate | `pair-extract-2026-10-08-winner-ops` | NR-022, NR-023 | `671ab96` | `post-95c385d_wind-authority` |",
)

# 5-12. The eight output-hash substitutions (receipt fix lines, verbatim).
HASH_PAIRS = [
    # Ring utilisation plate.
    (
        "- `png` `6f19832088375b96cdc566aff596ccd548f26b629b9782bc56d8831d03c622ba`",
        "- `png` `f49aaaa1bda8d1699c6db556fd20188d892cfcd42e3163ab8fb56bbea1eee837`",
    ),
    (
        "- `svg` `ec0f4b96f3fa9b646183e1f7004a0e5d8ce0f9ab28f111472d4ed32ffa0c6b58`",
        "- `svg` `41a557862e0f3a1eb1b40ecb2224089014fff7c26ee8d7c6d64bdd1b3bf670c0`",
    ),
    (
        "- `pdf` `508b3a641fde21b582ee2a58a3d3df2a769998281f78c8763ba07438286c1f8f`",
        "- `pdf` `fc4974d6e462b22ca3a45aaae009001bdf46c8d0245862227255ca3e42d69c75`",
    ),
    (
        "- `ledger` `c040fca2dd63df9c68b56a767ccd0383962db479b04d75d23821b311628ce099`",
        "- `ledger` `3b4bc8c1c9b0c5d474a1acabe6c2b7684058234414d96870e41b015e04b4a5ff`",
    ),
    # Twist limit plate.
    (
        "- `png` `7ff5c05cc0caa0890400fec50a9366397a203b891031fa400d9638872d0b4501`",
        "- `png` `00cd857a5769be853142a4e35cc701d283cb17e66c2e20f40e562177813f6248`",
    ),
    (
        "- `svg` `ffac9c1eba5386fe79d3c1f5a69afdfadafaba507adaf47963a1b2ddd669d472`",
        "- `svg` `45104b967009ef52c54f2ca4f4877f30c204daf64544161d907dc5dc41e59f5f`",
    ),
    (
        "- `pdf` `d207343460263fde7481c8be1572e797895db488f7828b35d14a09003436d4a1`",
        "- `pdf` `49c473a8ff2dac0cc15fed7b17bece2a10ecaae6d4ab157e801754cf6b40dfa2`",
    ),
    (
        "- `ledger` `6dfbd6eae0285a55475cd8cfe365e92bb9a6137d5e4da23f469634c58d1f1c28`",
        "- `ledger` `2225062a0146f62ac1c0a18add36f38d26df73682f56f4fd5cdac6a0a691c8e9`",
    ),
]
for old, new in HASH_PAIRS:
    d = sub(d, old, new)

# 13. The two levers rows join the exhibit table (after the anatomy row).
TEL = "`scripts/results/v13_5kw_masslift_len18.8_rotorcount_bankderate2/island_{1,2,3}/telemetry.csv`"
d = sub(
    d,
    "| `9cecee3` | `post-95c385d_wind-authority` |\n\n**Output hashes",
    "| `9cecee3` | `post-95c385d_wind-authority` |\n"
    "| Levers landscape | %s | NR-001, NR-005, NR-006, NR-044, NR-045 | `e23f226` | `post-95c385d_wind-authority` |\n"
    "| Parameter atlas | %s | NR-001, NR-005, NR-006, NR-044 | `e23f226` | `post-95c385d_wind-authority` |\n"
    "\n**Output hashes" % (TEL, TEL),
)

# 14. The two levers output-hash blocks join the hash section (at the end).
END = "- `checks` `0e857cbfb288ff7110aafec99c11211bae1c46e4d3b2a5594d5949f318d9f279`"
BLOCKS = """

Levers landscape:

- `png` `4b1bd3453a6aa20d9b9b0af75eb989212b16df8986c752766edd625ae13d9892`
- `svg` `94d518bb13c604d4949f9c1011845050d150c4122a357449a8e185f506ae48dc`
- `pdf` `712e918b0b6ac73335ef2355113f59a2f3c6f63a421407ee122c98cfa6a2ecd7`
- `ledger` `91282957dd23b9a9919756e9db578404497e1f0a58d11c4824a7550ad5a91c5e`

Parameter atlas:

- `png` `1e46b70ae65f5557d23bb1a78ab7a75fdc2550a712ac9b2652d31562c67096e8`
- `svg` `28c032cf27c7412c9e76e0d756967143b7201c1ec4b6fe819498f40fe2021b9c`
- `pdf` `aede4d29da694a23e9af14c0ccb72f1932bf09a23b61adcf2095391c69a375b8`
- `ledger` `d3a2bcb1208db0bf0a4e5eb061620d9e73e99e776dc091dd26c067a2324d6f76`"""
d = sub(d, END, END + BLOCKS)

DRAFT.write_text(d)

# -------------------------------------------------------------- tracker ---
t = TRACKER.read_text()
OLD_END = (
    "The head status line and the sweep-21 seam note settle.\n"
    "No value moves.\n"
    "\n"
    "## 2. Working notes"
)
NEW_END = (
    "The head status line and the sweep-21 seam note settle.\n"
    "No value moves.\n"
    "\n"
    "v0.35 pass by @fig-img-diagrams (2026-10-14).\n"
    "This pass re-pins the figure-provenance appendix to the delivered Harris-3.5 plate renders.\n"
    "The eight plate output hashes and both plate script-commit cells take the delivered values.\n"
    "The pass also adds the levers rows 20 and 21 with their output hashes, and the count sentence reads six.\n"
    "No drawn value and no kit byte moves.\n"
    "\n"
    "## 2. Working notes"
)
t = sub(t, OLD_END, NEW_END)
TRACKER.write_text(t)

# ------------------------------------------------------------- handover ---
h = HANDOVER.read_text()
h = sub(
    h,
    "**Base:** branch tip `0ea9da4` on `bank-derate-cos2p65`.",
    "**Base:** branch `bank-derate-cos2p65`; fetch first and read the tip. "
    "This page refreshed at the appendix re-pin pass (2026-10-14).",
)
h = sub(
    h,
    """1. **The Harris-3.5 render deltas.** The two plates take the review deltas.
   Ring: the utilisation axis treatment (a log axis or an inset for the 0.03
   to 0.07 slivers) and the moment label (√(M_y² + M_z²) in place of √(M²)).
   Twist: the legend changelog lines out, the S1 to S4 δcrit label overlap, and
   the title and margin against the binding limit.

   Then F-VALUE at the sign-off commit. The review item sits in
   `docs/reporting/feedback/2026-10-10-harris-review.md` section 3.5. The map
   rows 6 and 7 carry the gate line.""",
    """1. **The Harris-3.5 thread.** The render deltas landed at `e4ff3c1` (script
   `671ab96`), the F-VALUE counter-read passed (136 checks: 125 ok, 10 defect,
   1 query, 0 fail), and the appendix re-pin with the levers rows landed in the
   re-pin pass. Open: the aero re-census at the fix commit, then the map
   closure on rows 6 and 7. The review item sits in
   `docs/reporting/feedback/2026-10-10-harris-review.md` section 3.5.""",
)
h = sub(
    h,
    "## Closed, last (evidence index)\n\n- The levers caption seating headers",
    """## Closed, last (evidence index)

- The appendix re-pin and the levers rows 20/21 join the figure-provenance
  appendix: the re-pin pass (2026-10-14). Receipt
  `docs/reporting/room-responses/figures-images-diagrams-2026-10-14-appendix-repin.md`.
  Evidence `scratch/fig_repin_edit.py`, `scratch/fig_repin_check.py` plus `.log`.

- The Harris-3.5 render deltas: `e4ff3c1` (script `671ab96`). Receipt
  `docs/reporting/room-responses/figures-images-diagrams-2026-10-14-harris35-render-deltas.md`.
  Evidence `scratch/fig_35_check.py` plus `.log` (65 checks, 0 fail).

- The levers caption seating headers""",
)
h = sub(
    h,
    "**Owner:** @fig-img-diagrams (figures-images-diagrams). **Next action:** open the\n"
    "Harris-3.5 render deltas on map rows 6 and 7.",
    "**Owner:** @fig-img-diagrams (figures-images-diagrams). **Next action:** open the\n"
    "item-5 lever-statistics extract; fold the map closure when the aero re-census lands.",
)
HANDOVER.write_text(h)

print("edit pass complete: draft, tracker and handover written")

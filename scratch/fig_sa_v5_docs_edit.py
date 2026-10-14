#!/usr/bin/env python3
"""fig-sa v5 docs edit pass: every record takes the v5 pins.

Usage: python3 scratch/fig_sa_v5_docs_edit.py    (repo root)
Single-occurrence assertions; prints a summary.
The checks sha is read from the updated manifest.
"""
import json
import sys
from pathlib import Path

KIT = Path("docs/reporting/figures/system-anatomy/")
REG = KIT / "register-status.md"
CAP = KIT / "captions.md"
SPEC = KIT / "SPEC.md"
MAP = Path("docs/reporting/figures/figure-map.md")
MASTER = Path("docs/reporting/drafts/2026-10-08-report-first-draft.md")
TRACKER = Path("docs/reporting/draft-tracker.md")

CHECK_SHA = json.loads((KIT / "manifest.json").read_text())["outputs"]["checks.log"]

edits = {
    REG: [
        ("**Date** 2026-10-12. Register fold and v4 re-cut 2026-10-13.",
         "**Date** 2026-10-12. Register fold and v4 re-cut 2026-10-13; v5 re-cut 2026-10-14."),
        ("runs stay byte-identical (verified at v4). Hashes at v4:\n\n"
         "    system-anatomy.tex  5bf748abc6fd385860f72ce0713cfb1c\n"
         "    prototype.html      620481ca05882376cdea2c8026a22e6f\n"
         "    label-ledger.txt    9f5e89acc24393d6e6481ce4780ee6e4\n"
         "    system-anatomy.pdf  45a99a610b68c496209120ea6e6cd261\n"
         "    system-anatomy.png  aae4915c2f32a2f0c6798e68d2d29e03",
         "runs stay byte-identical (verified at v5). Hashes at v5:\n\n"
         "    system-anatomy.tex  8a6d82b74dde69965e224d2ce3293ccf\n"
         "    prototype.html      8225ea742dd25566e8c79c41ae57bfdf\n"
         "    label-ledger.txt    9832c94065d2d817303c40ec19ccb350\n"
         "    system-anatomy.pdf  77701b4024b957af21e54ca06ecdbebc\n"
         "    system-anatomy.png  9be129933420343205aa8f2592905b51"),
        ("The drawn source\nline reads NR-011 · NR-017 · NR-043. Script commit `9cecee3`. No other\ngeometry moves.\n",
         "The drawn source\nline reads NR-011 · NR-017 · NR-043. Script commit `9cecee3`. No other\ngeometry moves.\n\n"
         "v5 (2026-10-14): the cone ring (R5) label joins the plate (round-5\n"
         "founder comment 3). The named part reads \"R5, the cone ring\" and \"the\n"
         "shaft cone starts here\", with its leader and in-script clearance\n"
         "asserts. Script commit `d243b37`. No other geometry moves. No new\n"
         "number prints.\n"),
        ("**Delta** v2 (2026-10-13): the v4 re-cut lands. The blade-span dimension\n"
         "draws (NR-043, the drawn form `1.499 m`), and the drawn source line\n"
         "carries NR-011 · NR-017 · NR-043. Script commit `9cecee3`.\n",
         "**Delta** v2 (2026-10-13): the v4 re-cut lands. The blade-span dimension\n"
         "draws (NR-043, the drawn form `1.499 m`), and the drawn source line\n"
         "carries NR-011 · NR-017 · NR-043. Script commit `9cecee3`.\n"
         "**Delta** v3 (2026-10-14): the v5 re-cut lands. The cone ring (R5) label\n"
         "draws with its leader and clearance asserts. The label set reads\n"
         "thirteen. Script commit `d243b37`.\n"),
    ],
    CAP: [
        ("**Status** GENERATE (re-cut v4; founder-return\nforms folded 2026-10-13).",
         "**Status** GENERATE (re-cut v5; founder-return\nforms folded 2026-10-13)."),
        ("The re-cut v2/v3 lands at\n`df8a2b4`. The v4 re-cut lands at `9cecee3`.",
         "The re-cut v2/v3 lands at\n`df8a2b4`. The v4 re-cut lands at `9cecee3`. The v5 re-cut lands at\n`d243b37`."),
        ("provenance line carries NR-043.\n",
         "provenance line carries NR-043.\n\n"
         "Cone-ring note (2026-10-14): the v5 re-cut names R5 as the cone ring\n"
         "(round-5 comment 3). The plate text changes; the captions do not move.\n"),
    ],
    SPEC: [
        ("- Labels run ground to hub. Twelve labels, at the cap. The inset defines the\n  three load-bearing words: ring, line, rotor.",
         "- Labels run ground to hub. Thirteen labels. The cone ring (R5) label is\n"
         "  the round-5 founder addition beyond the twelve-label brief cap. The\n"
         "  inset defines the three load-bearing words: ring, line, rotor."),
        ("  matches NR-043, and the dimension clearances hold.",
         "  matches NR-043, the dimension clearances hold, and the cone-ring leader\n"
         "  clearance holds."),
    ],
    MAP: [
        ("The founder caption forms (note 9) are in the kit text. Next: the seats' counter-read, then the fold |",
         "The founder caption forms (note 9) are in the kit text. The v5 re-cut landed (`d243b37`): the cone ring (R5) label draws with its leader and clearance asserts (round-5 comment 3), and no new number prints. Next: the aero counter-read of the v5 re-cut |"),
        ("  The visual pass by Rod stays the next gate at all three.\n",
         "  The visual pass by Rod stays the next gate at all three.\n\n"
         "- **v35 (2026-10-14):** the system-anatomy v5 re-cut lands. The cone ring\n"
         "  (R5) label joins the plate (round-5 founder comment 3): the named part\n"
         "  reads \"R5, the cone ring\" / \"the shaft cone starts here\" with its\n"
         "  leader, and the leader carries in-script clearance asserts. No new\n"
         "  number prints. Script `d243b37`; the outputs and records ride this\n"
         "  commit. Two full runs byte-identical across all five outputs. Next:\n"
         "  the aero counter-read of the re-cut.\n"),
    ],
    MASTER: [
        ("Internal engineering report. Draft v0.43. Date 2026-10-14.",
         "Internal engineering report. Draft v0.44. Date 2026-10-14."),
        ("| System anatomy plate | `scratch/fig1_decode_winner.jl` · `best_vector.csv` | NR-011, NR-017, NR-043 | `9cecee3` | `post-95c385d_wind-authority` |",
         "| System anatomy plate | `scratch/fig1_decode_winner.jl` · `best_vector.csv` | NR-011, NR-017, NR-043 | `d243b37` | `post-95c385d_wind-authority` |"),
        ("System anatomy plate:\n\n"
         "- `png` `f1c322bc20068299651bea7978bde254991b4037bf02fe689a15e1e3297a09ea`\n"
         "- `pdf` `9beffb6bf8463d39a5808164630d04d8c286184a4990a083296e7fc6d512f2cf`\n"
         "- `ledger` `b250c1a187132f68c37747b70f3d6081eb89e677ba378b12e6eb14b8a05a2389`\n"
         "- `checks` `0e857cbfb288ff7110aafec99c11211bae1c46e4d3b2a5594d5949f318d9f279`",
         "System anatomy plate:\n\n"
         "- `png` `b78eb5cbe8f77074f04f9264e409f3de7f5aa97096a4f4f824c3bdf8271ecc9a`\n"
         "- `pdf` `b8fd60364168d70200f2f7122f7f9a957ea1590aa84c6197a19c79e811c444b6`\n"
         "- `ledger` `3adec59c7bd19b232584de4e6cb703b44d4e48bb820c68f1ed78f5086971dc8d`\n"
         "- `checks` `" + CHECK_SHA + "`"),
    ],
    TRACKER: [
        ("The campaign-scale context and the cone lead line land.\nNo value moves.\n",
         "The campaign-scale context and the cone lead line land.\nNo value moves.\n\n"
         "v0.44 pass by @fig-img-diagrams (2026-10-14).\n"
         "This pass re-pins the figure-provenance appendix to the delivered v5 system-anatomy re-cut.\n"
         "The plate script-commit cell and its four output-hash cells take the delivered values.\n"
         "The re-cut adds the cone-ring label (figure-map row 2; round-5 comment 3).\n"
         "No value moves.\n"),
    ],
}

ok = True
for path, pairs in edits.items():
    text = path.read_text(encoding="utf-8")
    for old, new in pairs:
        n = text.count(old)
        if n != 1:
            print(f"FAIL: {path}: target occurs {n} times: {old[:80]!r}")
            ok = False
            continue
        text = text.replace(old, new)
    if ok:
        path.write_text(text, encoding="utf-8")
        print(f"edited: {path}")

print("RESULT:", "PASS" if ok else "FAIL")
sys.exit(0 if ok else 1)

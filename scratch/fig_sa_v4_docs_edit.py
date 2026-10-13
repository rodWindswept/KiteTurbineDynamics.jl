#!/usr/bin/env python3
"""fig-sa v4 docs edit pass: every markdown record takes the v4 pins.

Usage: python3 scratch/fig_sa_v4_docs_edit.py <checks.log sha256>
Applies with single-occurrence assertions; prints a summary.
"""
import sys

CHECK_SHA = sys.argv[1] if len(sys.argv) > 1 else ""

KIT = "docs/reporting/figures/system-anatomy/"
REG = KIT + "register-status.md"
CAP = KIT + "captions.md"
SPEC = KIT + "SPEC.md"
MAP = "docs/reporting/figures/figure-map.md"
MASTER = "docs/reporting/drafts/2026-10-08-report-first-draft.md"

edits_reg = [
    ("**Date** 2026-10-12. Register fold 2026-10-13.",
     "**Date** 2026-10-12. Register fold 2026-10-13; v4 re-cut 2026-10-13."),
    ("| NR-017 | Main-rotor bank 7.088° at ring 6 | Signed |\n\n"
     "The plate draws no other row. The β glyph carries no value.\n\n"
     "NR-043 (the winner blade span) joins at the next build: the v4 re-cut\n"
     "draws the span dimension and adds NR-043 to the drawn source line.",
     "| NR-017 | Main-rotor bank 7.088° at ring 6 | Signed |\n"
     "| NR-043 | The winner blade span 1.499 m, drawn inner edge to tip (v4) | Signed (science-validator, `88277f6`) |\n\n"
     "The plate draws no other row. The β glyph carries no value."),
    ("rounding delta exists between the plate and the rows.",
     "rounding delta exists between the plate and the rows.\n\n"
     "The span prints at three decimals (`1.499 m`), the drawn radii precision,\n"
     "from NR-043. The dimension reads the built blade span, inner edge to tip.\n"
     "It is not a ring radius, and not the tip offset alone."),
    ("runs stay byte-identical (verified at v3). Hashes at v3:\n\n"
     "    system-anatomy.tex  32e74655418bb440fab039993f7acacb\n"
     "    prototype.html      12d50b0c706c43c0be22e4e03e96cbd9\n"
     "    label-ledger.txt    01b6f9b5543f2e9efd7d8f84b693fe39\n"
     "    system-anatomy.pdf  0be2467fe569e2af91518d60f7d4c79d\n"
     "    system-anatomy.png  04b6b7321b2f9fc78a003f2e5ea52aed",
     "runs stay byte-identical (verified at v4). Hashes at v4:\n\n"
     "    system-anatomy.tex  5bf748abc6fd385860f72ce0713cfb1c\n"
     "    prototype.html      620481ca05882376cdea2c8026a22e6f\n"
     "    label-ledger.txt    9f5e89acc24393d6e6481ce4780ee6e4\n"
     "    system-anatomy.pdf  45a99a610b68c496209120ea6e6cd261\n"
     "    system-anatomy.png  aae4915c2f32a2f0c6798e68d2d29e03"),
    ("## Re-cuts (same day)", "## Re-cuts"),
    ("No value binds to either re-cut.",
     "No value binds to either re-cut.\n\n"
     "v4 (2026-10-13): the blade-span dimension (NR-043) draws down-left of the\n"
     "blade, with gapped extension lines and the label leader. The drawn source\n"
     "line reads NR-011 · NR-017 · NR-043. Script commit `9cecee3`. No other\n"
     "geometry moves."),
    ("## Pending\n\n"
     "Founder note 13 (`c2e2aee`) asks the plate to carry the blade span. The\n"
     "register form landed (NR-043, science-validator, `88277f6`): the winner\n"
     "span is 1.4994019682084492 m (tip radius 5.629560432565964 minus inner\n"
     "edge 4.130158464357515). The drawn form is `1.499 m` at three decimals —\n"
     "the drawn radii precision. The dimension reads the built blade span,\n"
     "inner edge to tip; it is not a ring radius and not the tip offset alone.\n"
     "The v4 re-cut draws the dimension and adds NR-043 to the drawn source\n"
     "line. No render moves until then.\n\n"
     "**Delta** v1 (2026-10-13): NR-043 signed (`88277f6`); the pending item\n"
     "updates to the v4 re-cut; the note-9 caption forms land (`captions.md`).",
     "## Pending\n\n"
     "The Track D label picks (the knot name, the cyan-line name) ride a later\n"
     "re-cut; the plate carries the room forms for now. The β value waits for a\n"
     "signed row.\n\n"
     "**Delta** v1 (2026-10-13): NR-043 signed (`88277f6`); the pending item\n"
     "updates to the v4 re-cut; the note-9 caption forms land (`captions.md`).\n"
     "**Delta** v2 (2026-10-13): the v4 re-cut lands — the blade-span dimension\n"
     "draws (NR-043, the drawn form `1.499 m`), and the drawn source line\n"
     "carries NR-011 · NR-017 · NR-043; script commit `9cecee3`."),
]

edits_cap = [
    ("**Status** GENERATE (re-cut v3; founder-return",
     "**Status** GENERATE (re-cut v4; founder-return"),
    ("rows NR-011, NR-017 · script commit `df8a2b4` · full record: the",
     "rows NR-011, NR-017, NR-043 · script commit `9cecee3` · full record: the"),
    ("The re-cut v2/v3 lands at\n`df8a2b4`.",
     "The re-cut v2/v3 lands at\n`df8a2b4`. The v4 re-cut lands at `9cecee3`."),
    ("The blade-span ask from the same note rides the v4 re-cut (NR-043,\n"
     "`88277f6`; see `register-status.md`): the dimension draws, and the\n"
     "provenance line takes NR-043 with it.",
     "The blade-span ask from the same note landed in the v4 re-cut (NR-043,\n"
     "`88277f6`; see `register-status.md`): the dimension draws, and the\n"
     "provenance line carries NR-043."),
]

edits_spec = [
    ("| scale bar | 5 m | the drawn bar |\n\nNo other number prints.",
     "| scale bar | 5 m | the drawn bar |\n| blade span | 1.499 m | NR-043 |\n\nNo other number prints."),
    ("The generator asserts: six rings, fifteen line runs, three blades. The\n"
     "  radii and the bank angle match NR-011 and NR-017.",
     "The generator asserts: six rings, fifteen line runs, three blades. The\n"
     "  radii and the bank angle match NR-011 and NR-017. The blade span\n"
     "  matches NR-043, and the dimension clearances hold."),
]

edits_map = [
    ("the v4 re-cut draws the dimension and adds NR-043 to the drawn source line. The founder caption forms (note 9) land in the kit text |",
     "the v4 re-cut landed (`9cecee3`): the dimension draws and the drawn source line reads NR-011 · NR-017 · NR-043. The founder caption forms (note 9) are in the kit text. Next: the seats' counter-read, then the fold |"),
    ("  kite stack\", \"Six triangular rings\") land in the kit text. No plate\n  byte moves.",
     "  kite stack\", \"Six triangular rings\") land in the kit text. No plate\n  byte moves.\n\n"
     "- **v23 (2026-10-13):** the v4 re-cut lands. The generator (`9cecee3`)\n"
     "  draws the blade-span dimension (NR-043, display `1.499 m`) on the\n"
     "  down-left side of the blade with gapped extensions, and adds the row\n"
     "  to the drawn source line. Two full runs stay byte-identical across\n"
     "  all five outputs. The kit note, the manifest, the caption provenance\n"
     "  and the draft's exhibit row take the new pins. No other geometry\n"
     "  moves. Next: the seats' counter-read, then the fold."),
]

edits_master = [
    ("[Figure seated: figure-map row 2 (system anatomy plate, slug `system-anatomy`). Values cite NR-011 and NR-017.]",
     "[Figure seated: figure-map row 2 (system anatomy plate, slug `system-anatomy`). Values cite NR-011, NR-017 and NR-043.]"),
    ("| System anatomy plate | `scratch/fig1_decode_winner.jl` · `best_vector.csv` | NR-011, NR-017 | `df8a2b4` | `post-95c385d_wind-authority` |",
     "| System anatomy plate | `scratch/fig1_decode_winner.jl` · `best_vector.csv` | NR-011, NR-017, NR-043 | `9cecee3` | `post-95c385d_wind-authority` |"),
    ("System anatomy plate:\n\n"
     "- `png` `fe89525d297d1a85be287e4c2f6b0127f18b714d8eab21d65d08f6522c7f4ee5`\n"
     "- `pdf` `9d507326a541a9e92f15860889b334f29e82add5cec49cbcc617549b07878bb1`\n"
     "- `ledger` `53a4204cb70f153d2ddda460e97cc8365a2e4e3b674e705a3f5da02d187bf5e1`\n"
     "- `checks` `5100d5497523dcca462092b5a2ad01d9b53f025f755580cd479a7f4049581888`",
     "System anatomy plate:\n\n"
     "- `png` `f1c322bc20068299651bea7978bde254991b4037bf02fe689a15e1e3297a09ea`\n"
     "- `pdf` `9beffb6bf8463d39a5808164630d04d8c286184a4990a083296e7fc6d512f2cf`\n"
     "- `ledger` `b250c1a187132f68c37747b70f3d6081eb89e677ba378b12e6eb14b8a05a2389`\n"
     "- `checks` `" + CHECK_SHA + "`"),
]

ok = True
for path, edits in ((REG, edits_reg), (CAP, edits_cap), (SPEC, edits_spec),
                    (MAP, edits_map), (MASTER, edits_master)):
    text = open(path, encoding="utf-8").read()
    for old, new in edits:
        n = text.count(old)
        if n != 1:
            print(f"FAIL: {path}: target occurs {n} times: {old[:80]!r}")
            ok = False
            continue
        text = text.replace(old, new)
    if ok:
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(text)
        print(f"edited: {path}")

print("RESULT:", "PASS" if ok else "FAIL")
sys.exit(0 if ok else 1)

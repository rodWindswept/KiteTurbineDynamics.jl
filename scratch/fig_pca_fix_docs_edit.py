#!/usr/bin/python3
# -*- coding: utf-8 -*-
"""The levers fix pass (figures seat, 2026-10-14): docs edits.

Applies the text fixes directed by the F-VALUE counter-read and the
science-validator receipts, with strict anchors:

1. NR-005 / NR-006 cite map (register mapping: NR-005 = winner 27.364,
   NR-006 = common seed 36.109) across both kits' SPEC readout lists,
   register-status rows tables and caption drafts.
2. NR-045 joins the landscape readout list, register rows and note.
3. The kg-equivalent form replaces "kilograms" in the landscape colour
   lines and both strip caption tiers.
4. The pins: reproduce commands, caption provenance script refs, kit-note
   hash blocks, the figure map cells and delta v26.

Run: /usr/bin/python3 scratch/fig_pca_fix_docs_edit.py
"""
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
FIG = REPO / "docs/reporting/figures"
A = "e23f226"

HASH_LAND = """Hashes at v3 (the cite fix and stamp re-cut, 2026-10-14):

    pca-landscape.svg  04d77ecf48171685aed7dee872b1fab4
    pca-landscape.pdf  90ff939cce21563fe8016da7633e864e
    pca-landscape.png  bc06737e003e4caa63dbd42a4f845fec
    label-ledger.txt   fdb90d3b97edffc536d903ac9024ca65
    manifest.json      53c18f0f3e852d64a3e4ddcdceaf5719"""

HASH_ATLAS = """Hashes at v3 (the cite fix and stamp re-cut, 2026-10-14):

    pca-atlas.svg      96b333c6362655f810961b15eaa67f69
    pca-atlas.pdf      433d3e5578a53b5e1dfa4a0962b6f0a6
    pca-atlas.png      f1ffbdddba814b64cd5110eea5b466fb
    label-ledger.txt   0372772afe15ceb12acd548e73e5895d
    manifest.json      f3fc89912216b3f79c294c6fb089dc30"""

EDITS = [
    # ---- landscape SPEC -------------------------------------------------
    (FIG / "pca-landscape/SPEC.md", [
        ("| start 36.109 | NR-005, NR-006 | map label, journey inset | the common seed |\n"
         "| winner 27.364 | NR-006 | map label, journey inset | island 3 |",
         "| start 36.109 | NR-006 | map label, journey inset | the common seed |\n"
         "| winner 27.364 | NR-005 | map label, journey inset | island 3 |"),
        ("| 930 designs | NR-001 | subtitle, journey inset | the screen size |\n",
         "| 930 designs | NR-001 | subtitle, journey inset | the screen size |\n"
         "| 31 generations each | NR-045 | journey inset | signed (science-validator, `6255268`) |\n"),
        ("- Colour is the cell mean of the search objective in kilograms. The",
         "- Colour is the cell mean of the search objective in kg-equivalent. The"),
        ("signed as NR-044, so F-VALUE opens at the counter-read.",
         "signed as NR-044. The counter-read at `331f60d` holds the drawn\n"
         "  values. A fresh read rides the re-cut pins."),
        ("The projection row closed as NR-044 (signed 2026-10-13). The plate\n"
         "prints no other waited value.",
         "The projection row closed as NR-044 (signed 2026-10-13). The\n"
         "generation count closed as NR-045 (signed 2026-10-14). The plate\n"
         "prints no other waited value."),
        ("## Deltas\n\n- v2 (2026-10-13): NR-044 signs (`2ad023c`); the row want closes. No\n  plate byte moves.",
         "## Deltas\n\n"
         "- v3 (2026-10-14): the cite fix and the stamp re-cut. The readout list\n"
         "  takes the register mapping for NR-005 and NR-006. It cites NR-045 for\n"
         "  the generation count. The drawn row list takes NR-044 and NR-045.\n"
         "  The projection stamp takes its signed form. The caption text takes\n"
         f"  the kg-equivalent form. New pins at script commit `{A}`.\n"
         "- v2 (2026-10-13): NR-044 signs (`2ad023c`); the row want closes. No\n  plate byte moves."),
    ]),
    # ---- landscape register-status --------------------------------------
    (FIG / "pca-landscape/register-status.md", [
        ("**Date** 2026-10-13.",
         "**Date** 2026-10-13. Cite fix and re-cut 2026-10-14."),
        ("| NR-005 | The common seed value, 36.109 | Signed |\n"
         "| NR-006 | The winner value, 27.364 | Signed |",
         "| NR-005 | The winner value, 27.364 | Signed |\n"
         "| NR-006 | The common seed value, 36.109 | Signed |"),
        ("| NR-044 | The PCA projection summary: shares, loadings and the bin rule | Signed (science-validator, `2ad023c`) |\n",
         "| NR-044 | The PCA projection summary: shares, loadings and the bin rule | Signed (science-validator, `2ad023c`) |\n"
         "| NR-045 | The island generation counts: 31 generations per island, 10 rows each | Signed (science-validator, `6255268`) |\n"),
        ("- PC2: bank_bottom +0.5621, blade_scale_bottom -0.5605, density_profile\n  -0.5018, bank_top -0.2444.",
         "- PC2: bank_bottom +0.5621, blade_scale_bottom -0.5605, density_profile\n"
         "  -0.5018, bank_top -0.2444.\n"
         "- **NR-045 — the island generation counts.** Signed by the science\n"
         "  validator at `6255268` (2026-10-14). 31 generations per island\n"
         "  (indices 0 to 30) and 10 rows per generation. 310 rows per island\n"
         "  and 930 in total (NR-001). The journey inset count keeps."),
        ("- The screen size reads 930 (NR-001).\n",
         "- The screen size reads 930 (NR-001).\n"
         "- The journey inset reads 31 generations each (NR-045).\n"),
        ("--script-commit 3d36c7a`",
         f"--script-commit {A}`"),
        ("log sits at `checks.log`.",
         f"log sits at `checks.log`.\n\n{HASH_LAND}"),
    ]),
    # ---- landscape captions-draft ---------------------------------------
    (FIG / "pca-landscape/captions-draft.md", [
        ("objective in kilograms. Bright reads lower. Three lines trace the",
         "objective in kg-equivalent. Bright reads lower. Three lines trace the"),
        ("starts at 36.109 (NR-005). The winner ends at 27.364 (NR-006). The",
         "starts at 36.109 (NR-006). The winner ends at 27.364 (NR-005). The"),
        ("· rows: NR-001, NR-005, NR-006, NR-044 · script: `docs/reporting/figures/pca-landscape/pca-landscape.py` at `3d36c7a`",
         f"· rows: NR-001, NR-005, NR-006, NR-044, NR-045 · script: `docs/reporting/figures/pca-landscape/pca-landscape.py` at `{A}`"),
        ("**Delta** v2 (2026-10-13): NR-044 signs.",
         "**Delta** v3 (2026-10-14): the cites take the register mapping. The\n"
         "provenance line takes NR-045 and the re-cut script commit. The\n"
         "objective form reads kg-equivalent. Caption text only.\n\n"
         "**Delta** v2 (2026-10-13): NR-044 signs."),
    ]),
    # ---- atlas SPEC ------------------------------------------------------
    (FIG / "pca-atlas/SPEC.md", [
        ("| start 36.109 | NR-005, NR-006 | the journey marks | positional |\n"
         "| winner 27.364 | NR-006 | the journey marks | positional |",
         "| start 36.109 | NR-006 | the journey marks | positional |\n"
         "| winner 27.364 | NR-005 | the journey marks | positional |"),
        ("- **R2** this landing. The counter-read by the seats and the visual\n"
         "  pass by Rod come first. The projection row signed\n"
         "  as NR-044.",
         "- **R2** this landing. The counter-read by the seats and the visual\n"
         "  pass by Rod come first. The projection row signed as NR-044. The\n"
         "  counter-read at `331f60d` holds the drawn values. A fresh read\n"
         "  rides the re-cut pins."),
        ("## Deltas\n\n- v2 (2026-10-13): NR-044 signs (`2ad023c`); the row want closes. No\n  plate byte moves.",
         "## Deltas\n\n"
         "- v3 (2026-10-14): the cite fix and the stamp re-cut. The readout list\n"
         "  takes the register mapping for NR-005 and NR-006. The drawn row list\n"
         f"  takes NR-044. New pins at script commit `{A}`.\n"
         "- v2 (2026-10-13): NR-044 signs (`2ad023c`); the row want closes. No\n  plate byte moves."),
    ]),
    # ---- atlas register-status ------------------------------------------
    (FIG / "pca-atlas/register-status.md", [
        ("**Date** 2026-10-13.",
         "**Date** 2026-10-13. Cite fix and re-cut 2026-10-14."),
        ("| NR-005 | The common seed value, 36.109 | Signed |\n"
         "| NR-006 | The winner value, 27.364 | Signed |",
         "| NR-005 | The winner value, 27.364 | Signed |\n"
         "| NR-006 | The common seed value, 36.109 | Signed |"),
        ("--script-commit 3d36c7a`",
         f"--script-commit {A}`"),
        ("CPython 3.12.3, matplotlib 3.10.8, numpy 2.4.4 (`/usr/bin/python3`).",
         f"CPython 3.12.3, matplotlib 3.10.8, numpy 2.4.4 (`/usr/bin/python3`).\n\n{HASH_ATLAS}"),
    ]),
    # ---- atlas captions-draft -------------------------------------------
    (FIG / "pca-atlas/captions-draft.md", [
        ("(36.109, NR-005). The diamond marks the winner (27.364, NR-006). The",
         "(36.109, NR-006). The diamond marks the winner (27.364, NR-005). The"),
        ("at `3d36c7a`",
         f"at `{A}`"),
        ("**Delta** v2 (2026-10-13): NR-044 signs.",
         "**Delta** v3 (2026-10-14): the cites take the register mapping. The\n"
         "provenance line takes the re-cut script commit. Caption text only.\n\n"
         "**Delta** v2 (2026-10-13): NR-044 signs."),
    ]),
    # ---- machine-evolution-strip captions --------------------------------
    (FIG / "machine-evolution-strip/captions.md", [
        ("number under each machine is its search objective, in kilograms. A",
         "number under each machine is its search objective, in kg-equivalent. A"),
        ("The value under each machine is the search objective in kilograms.",
         "The value under each machine is the search objective in kg-equivalent."),
        ("Register-status and the manifest carry them. The text changed only. No\nrender moved.",
         "Register-status and the manifest carry them. The text changed only. No\n"
         "render moved.\n\n"
         "Form note (2026-10-14): both caption tiers read kg-equivalent for the\n"
         "objective (round-3 feedback routing). The drawn label keeps its (kg)\n"
         "form. The strip render holds."),
    ]),
    # ---- figure map -------------------------------------------------------
    (FIG / "figure-map.md", [
        ("The counter-read by the seats (F-VALUE opens, NR-044 signed). Then the visual pass by Rod",
         "F-VALUE counter-read at `331f60d` holds the drawn values. The cite fix\n  and the stamp re-cut landed (script commit `e23f226`). A fresh read rides\n  the new pins. Then the visual pass by Rod"),
        ("and 21 wait on the counter-read and the visual pass by Rod.\n",
         "and 21 wait on the counter-read and the visual pass by Rod.\n\n"
         "- **v26 (2026-10-14):** the levers fix pass lands. The NR-005 and NR-006\n"
         "  cites take the register mapping on both kits, ten lines across six\n"
         "  files. The drawn row lists take NR-044 on both stamps and NR-045 on\n"
         "  the landscape. The landscape projection stamp takes its signed form.\n"
         "  The caption text takes the kg-equivalent form on the landscape and\n"
         "  the strip. Script commit `e23f226`, with both kits re-rendered and\n"
         "  two runs byte-identical across all five outputs each. The F-VALUE\n"
         "  counter-read at `331f60d` had routed the fix. Next: a fresh\n"
         "  counter-read, then the fold and the visual pass by Rod.\n"),
    ]),
]


def main() -> int:
    for path, edits in EDITS:
        text = path.read_text()
        for old, new in edits:
            n = text.count(old)
            assert n == 1, (path.name, n, old[:70])
            text = text.replace(old, new)
        path.write_text(text)
        print(f"edited: {path.relative_to(REPO)}  ({len(edits)} edits)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

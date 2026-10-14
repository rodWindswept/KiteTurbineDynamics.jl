#!/usr/bin/python3
# -*- coding: utf-8 -*-
"""The caption leads and the closure records (figures seat, 2026-10-14).

One landing, two routed passes:

1. The F-VALUE closure records (aero-validator route): the figure-map
   cells for rows 20 and 21, the two kit SPEC rounds lines, and map
   deltas v27.
2. The round-3 caption leads (routing parts 9 and 10): the ring, twist
   and strip captions open with the result, the ring gate line cites
   NR-015, the twist margin cites NR-040, and the kit notes take the
   new cites. Map delta v28.

Two phases: verify every anchor count first, then write every file.

Run: /usr/bin/python3 scratch/fig_cl_edit.py
"""
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
FIG = REPO / "docs/reporting/figures"

MAP_CELL_OLD = ("F-VALUE counter-read at `331f60d` holds the drawn values. "
                "The cite fix and the stamp re-cut landed (script commit "
                "`e23f226`). A fresh read rides the new pins. Then the "
                "visual pass by Rod")
MAP_CELL_NEW = ("F-VALUE counter-read at `331f60d` held the drawn values. "
                "The cite fix and the stamp re-cut landed (script commit "
                "`e23f226`). The re-census at `7329191` closes F-VALUE on "
                "the fix commit (`d6d4db9`) with zero defects. Next: the "
                "section 3.4 fold and the pointers, then the visual pass "
                "by Rod")

MAP_DELTAS = (
    "\n- **v27 (2026-10-14):** the F-VALUE re-census closes the levers\n"
    "  family. It lands at `7329191` and closes on the fix commit\n"
    "  (`d6d4db9`). Cites, stamps, pins, drawn values and the NR-045\n"
    "  anchors all verify, zero defects. The kit rounds lines and rows 20\n"
    "  and 21 take the closure. Next: the section 3.4 fold and the\n"
    "  pointers, then the visual pass by Rod.\n"
    "\n"
    "- **v28 (2026-10-14):** the round-3 caption leads land in the kit text\n"
    "  (rows 6, 7 and 9 kits). Both tiers of the three seated captions\n"
    "  open with the result. The ring gate line cites NR-015 and the twist\n"
    "  margin cites NR-040. Text only, no renders move. The 3.5 render\n"
    "  deltas stay queued at the figures seat.\n")

EDITS = [
    (FIG / "figure-map.md", [
        (MAP_CELL_OLD, MAP_CELL_NEW, 2),
    ], ["endswith::then the fold and the visual pass by Rod.\n", MAP_DELTAS]),

    (FIG / "pca-landscape/SPEC.md", [
        ("  signed as NR-044. The counter-read at `331f60d` holds the drawn\n"
         "  values. A fresh read rides the re-cut pins.",
         "  signed as NR-044. The counter-read at `331f60d` held the drawn values\n"
         "  and routed the cite fix. The re-census at `7329191` closes F-VALUE on\n"
         "  the fix commit (`d6d4db9`).", 1),
        ("- **R3** the final pass. @aero-validator runs F-VALUE at the sign-off\n"
         "  commit. Rod does the visual pass. Status moves to approved.",
         "- **R3** the final pass. Rod does the visual pass. Status moves to\n"
         "  approved.", 1),
    ]),

    (FIG / "pca-atlas/SPEC.md", [
        ("  counter-read at `331f60d` holds the drawn values. A fresh read\n"
         "  rides the re-cut pins.",
         "  counter-read at `331f60d` held the drawn values. The re-census at\n"
         "  `7329191` closes F-VALUE on the fix commit (`d6d4db9`).", 1),
        ("- **R3** the final pass at the sign-off commit.",
         "- **R3** the final pass. Rod does the visual pass. Status moves to\n"
         "  approved.", 1),
    ]),

    (FIG / "ring-utilisation/captions.md", [
        ("2026-10-12 caption split. Values cite NR-021.",
         "2026-10-12 caption split and the 2026-10-14 leads. Values cite\nNR-021 and NR-015.", 1),
        ("This figure shows how much of the structural check on each ring comes from\n"
         "compression and how much from bending.",
         "The hub ring R6 governs the structural check at the winner's final\n"
         "operating point, and every other airborne ring holds a much larger\n"
         "margin.", 1),
        ("Each bar stacks the axial share and the bending share of one checked ring.",
         "The hub ring R6 governs the structural check at FoS 15.033. All\n"
         "other airborne rings hold much larger margins (NR-021).\n\n"
         "Each bar stacks the axial share and the bending share of one checked ring.", 1),
        ("The dashed line is the fail boundary at the unit value. The readout at the\n"
         "row end gives the ring FoS: capacity over demand, the reciprocal of the\n"
         "interaction. The model tracks torsion outside the interaction formula.",
         "The dashed line is the fail boundary at the unit value, the physical\n"
         "interaction limit at FoS 1. The campaign structural gate is stricter, at\n"
         "FoS 2.5 or above (NR-015). The readout at the row end gives the ring FoS:\n"
         "capacity over demand, the reciprocal of the interaction. The model tracks\n"
         "torsion outside the interaction formula.", 1),
        ("The carried token folds: the hub row now reads R6 in\nthe caption text, to match the plate label.",
         "The carried token folds: the hub row now reads R6 in\nthe caption text, to match the plate label.\n\n"
         "Caption lead (2026-10-14): the round-3 leads land in both tiers. The\n"
         "plain tier opens with the governing ring. The technical tier adds the\n"
         "hub result (NR-021) and the campaign gate line (NR-015). Text only, no\n"
         "render moves.", 1),
    ]),

    (FIG / "twist-limit/captions.md", [
        ("2026-10-12 caption split. Values cite NR-022 and NR-023.",
         "2026-10-12 caption split and the 2026-10-14 leads. Values cite\nNR-022, NR-023 and NR-040.", 1),
        ("This figure shows how far each segment runs from the angle where the twist\nruns away.",
         "All five segments stay inside their over-twist limits at the winner's\n"
         "final operating point, and the smallest torque margin sits at S1.", 1),
        ("Panel A draws the transmitted twist of each segment as a magnitude,\n"
         "against its over-twist limit δcrit.",
         "All five TRPT segments remain inside their over-twist limits at the\n"
         "winner's final operating point. S1 carries the least segment torque\n"
         "margin, 2.03 (NR-040).\n\n"
         "Panel A draws the transmitted twist of each segment as a magnitude,\n"
         "against its over-twist limit δcrit.", 1),
        ("with the ledger pass. The floor and binding-limit treatment routes\nthrough work item 1.3 (the row-7 gate).",
         "with the ledger pass. The floor and binding-limit treatment routes\n"
         "through work item 1.3 (the row-7 gate).\n\n"
         "Caption lead (2026-10-14): the round-3 leads land in both tiers. The\n"
         "technical tier adds the least segment torque margin (NR-040). Text\n"
         "only, no render moves.", 1),
    ]),

    (FIG / "machine-evolution-strip/captions.md", [
        ("This figure shows seven kite-turbine designs from one search run. The\n"
         "row starts at the common seed and ends at the campaign winner.",
         "Island 3's best-so-far objective falls as the built geometry converges\n"
         "to the register winner. The row starts at the common seed and ends at\n"
         "the campaign winner.", 1),
        ("Seven panels show the best machine of island 3 at generations 0, 6, 10,\n18, 22, 25 and 26.",
         "Island 3's best-so-far objective falls from 36.109 to 27.364\n"
         "kg-equivalent. The built geometry converges to the register winner\n"
         "(NR-006, NR-005).\n\n"
         "Seven panels show the best machine of island 3 at generations 0, 6, 10,\n18, 22, 25 and 26.", 1),
        ("objective (round-3 feedback routing). The drawn label keeps its (kg)\nform. The strip render holds.",
         "objective (round-3 feedback routing). The drawn label keeps its (kg)\n"
         "form. The strip render holds.\n\n"
         "Caption lead (2026-10-14): the takeaway opens both tiers. The lead\n"
         "prints the objective range from the signed rows (NR-006, NR-005).\n"
         "Text only, no render moves.", 1),
    ]),

    (FIG / "ring-utilisation/register-status.md", [
        ("| NR-021 | The ring check at the winner operating point. Interaction, axial share, bending share and ring FoS per checked ring | Signed (aero-validator, 2026-10-08). Counter-read closed (science-validator, 2026-10-09) |\n",
         "| NR-021 | The ring check at the winner operating point. Interaction, axial share, bending share and ring FoS per checked ring | Signed (aero-validator, 2026-10-08). Counter-read closed (science-validator, 2026-10-09) |\n"
         "| NR-015 | The operating point config: FoS gate 2.5/2.5 (a plain 2.5 reads the floor), with the capture settings | Signed (science-validator, 2026-10-08) |\n", 1),
        ("The figure draws no other row.",
         "The figure draws no other row. The caption cites NR-015 for the\ncampaign gate sentence.", 1),
        ("Self-check: two consecutive runs stay byte-identical.",
         "Self-check: two consecutive runs stay byte-identical.\n\n"
         "**Delta** v1 (2026-10-14): the round-3 caption leads land. The caption\n"
         "cites NR-015 for the gate sentence. No render moves.", 1),
    ]),

    (FIG / "twist-limit/register-status.md", [
        ("| NR-023 | The segment torque pair at the winner operating point, capacity basis Tulloch | Signed (aero-validator, 2026-10-08). Counter-read closed (science-validator, 2026-10-09) |\n",
         "| NR-023 | The segment torque pair at the winner operating point, capacity basis Tulloch | Signed (aero-validator, 2026-10-08). Counter-read closed (science-validator, 2026-10-09) |\n"
         "| NR-040 | The winner segment torque margins: S1 2.0288 (quote 2.03) governs, S5 2.6938 | Signed (science-validator, 2026-10-12) |\n", 1),
        ("Self-check: two consecutive runs stay byte-identical.",
         "Self-check: two consecutive runs stay byte-identical.\n\n"
         "**Delta** v1 (2026-10-14): the round-3 caption leads land. The caption\n"
         "cites NR-040 for the least torque margin. No render moves.", 1),
    ]),

    (FIG / "ring-utilisation/SPEC.md", [
        ("**Caption plan (dual, from the first figure).** Plain sentence: every ring\n"
         "meets one strict structural check. This figure shows how much of the check comes from compression and how much comes from bending.",
         "**Caption plan (dual, from the first figure).** Plain sentence: every ring\n"
         "meets one strict structural check. The hub ring R6 governs, and every\n"
         "other airborne ring holds a much larger margin.", 1),
        ("and the capture. No \"Euler\". @author writes them. Every number they carry is\na register citation.",
         "and the capture. Lead with the hub result (NR-021). State the gate line\n"
         "(NR-015). No \"Euler\". @author writes them. Every number they carry is\na register citation.", 1),
        ("  plate re-renders the same arrays statically in the house shaft frame.\n  The extract slot fills from the analysis room's cut.",
         "  plate re-renders the same arrays statically in the house shaft frame.\n"
         "  The extract slot fills from the analysis room's cut.\n\n"
         "- v4 (2026-10-14): the round-3 caption leads land in the kit text. Both\n"
         "  tiers open with the governing ring. The technical tier adds the hub\n"
         "  result (NR-021) and the gate line (NR-015). No render moves.", 1),
    ]),

    (FIG / "twist-limit/SPEC.md", [
        ("**Caption plan (dual, from the first figure).** Plain sentence: the shaft\n"
         "twists as it carries torque. This figure shows how far each segment runs\nfrom the angle where the twist runs away.",
         "**Caption plan (dual, from the first figure).** Plain sentence: the shaft\n"
         "twists as it carries torque. All five segments stay inside their\n"
         "over-twist limits at the winner's final operating point.", 1),
        ("torque pairing. Both captions use the ledger strings only. @author writes\nthem. Every number they carry is a register citation.",
         "torque pairing. Lead with the least torque margin (NR-040). Both captions\n"
         "use the ledger strings only. @author writes them. Every number they carry\nis a register citation.", 1),
        ("  wraps into (−180°, 180°] and can render as a small angle. The no-limit\n  annotation wording drafts with @author under the ledger.",
         "  wraps into (−180°, 180°] and can render as a small angle. The no-limit\n"
         "  annotation wording drafts with @author under the ledger.\n\n"
         "- v3 (2026-10-14): the round-3 caption leads land in the kit text. Both\n"
         "  tiers open with the limit result. The technical tier adds the least\n"
         "  torque margin (NR-040). No render moves.", 1),
    ]),
]


def main() -> int:
    # Phase 1: verify every anchor.
    errors = []
    for path, edits, *rest in EDITS:
        text = path.read_text()
        for old, new, count in edits:
            n = text.count(old)
            if n != count:
                errors.append(f"{path.relative_to(REPO)}: anchor x{n} (want {count}): {old[:60]!r}")
        if rest:
            tail_mark, tail_add = rest[0]
            assert tail_mark.startswith("endswith::")
            if not text.endswith(tail_mark[len("endswith::"):]):
                errors.append(f"{path.relative_to(REPO)}: file does not end with the expected tail")
    if errors:
        print("ANCHOR FAILURES:")
        for e in errors:
            print(" ", e)
        return 1
    # Phase 2: apply.
    for path, edits, *rest in EDITS:
        text = path.read_text()
        for old, new, count in edits:
            text = text.replace(old, new)
        if rest:
            text = text + rest[0][1]
        path.write_text(text)
        print(f"edited: {path.relative_to(REPO)}  ({len(edits)} edits)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

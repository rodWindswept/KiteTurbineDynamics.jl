#!/usr/bin/env python3
"""The Harris-3.5 render deltas: apply the documentation edits (figures seat).

Applies every doc edit for the pass with exact-string asserts:
captions, SPECs, register-status notes and the figure map (rows 6, 7,
delta v29). Script commit 671ab96; artifacts at the render commit.

Run from the repo root:
  /usr/bin/python3 scratch/fig_35_docs_edit.py
"""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
H1 = "671ab96"

EDITS = [
    # ------------------------------------------------------------- ring captions
    (
        "docs/reporting/figures/ring-utilisation/captions.md",
        "Each bar stacks the axial share and the bending share of one checked ring.\n"
        "The rows run from R2 at the base to R6 at the hub. Both shares come from\n"
        "the same worst-utilisation beam. The bar top is the ring utilisation, the\n"
        "beam-column interaction itself. Utilisation is demand over capacity.",
        "Each bar shows one checked ring. The bar end reads the ring utilisation:\n"
        "the beam-column interaction on the worst beam, the axial share N/N_crit\n"
        "plus the bending share √(M_ip²+M_oop²)/M_el.\n"
        "\n"
        "The rows run from R2 at the base to R6 at the hub. Utilisation is demand\n"
        "over capacity. The axis is logarithmic across six decades to the unit\n"
        "value, so the margin of every ring reads at its own scale.",
    ),
    (
        "docs/reporting/figures/ring-utilisation/captions.md",
        "R5 reads far below the other rows. Its worst checked beam carries no\n"
        "axial share, and its bending share sits below the display scale of the\n"
        "axis. The readout prints the true value, FoS 326,974 (NR-021).",
        "R5 reads far below the other rows. It carries bending alone. Its worst\n"
        "checked beam holds no axial share. The readout prints the true value, FoS\n"
        "326,974 (NR-021).\n"
        "\n"
        "For every other checked ring, the bending share sits below 0.05 per cent\n"
        "of the ring utilisation.",
    ),
    (
        "docs/reporting/figures/ring-utilisation/captions.md",
        "script commit `eacf073`",
        f"script commit `{H1}`",
    ),
    (
        "docs/reporting/figures/ring-utilisation/captions.md",
        "Caption lead (2026-10-14): the round-3 leads land in both tiers. The\n"
        "plain tier opens with the governing ring. The technical tier adds the\n"
        "hub result (NR-021) and the campaign gate line (NR-015). Text only, no\n"
        "render moves.",
        "Caption lead (2026-10-14): the round-3 leads land in both tiers. The\n"
        "plain tier opens with the governing ring. The technical tier adds the\n"
        "hub result (NR-021) and the campaign gate line (NR-015). Text only, no\n"
        "render moves.\n"
        "\n"
        "Render delta (2026-10-14): the 3.5 deltas land. The axis is logarithmic.\n"
        "One bar shows each ring. The corrected interaction form (N/N_crit +\n"
        "√(M_ip²+M_oop²)/M_el) reads in the legend and the caption.\n"
        "\n"
        "The bending-share sentence replaces the display-floor sentences.\n"
        "Render moved. No drawn value moves.",
    ),
    # ------------------------------------------------------------- ring SPEC
    (
        "docs/reporting/figures/ring-utilisation/SPEC.md",
        "  The figure labels it \"fail boundary\". ⟨The axis window resolves at\n"
        "  GENERATE.⟩",
        "  The figure labels it \"fail boundary\". The axis is logarithmic, six\n"
        "  decades from 10⁻⁶ to the unit value (v5).",
    ),
    (
        "docs/reporting/figures/ring-utilisation/SPEC.md",
        "- Per ring, one stacked bar: the axial share and the bending share. The top\n"
        "  of the bar is the ring interaction. The ring FoS readout at the row\n"
        "  end reads the emitted `ring_fos`. The model takes the reciprocal, not the\n"
        "  figure.",
        "- Per ring, one bar: the ring utilisation, the beam-column interaction.\n"
        "  The axial/bending stack retired at v5; the bending share reports in the\n"
        "  caption. The ring FoS readout at the row end reads the emitted\n"
        "  `ring_fos`. The model takes the reciprocal, not the figure.",
    ),
    (
        "docs/reporting/figures/ring-utilisation/SPEC.md",
        "| `share_stack` | `ring_util_axial`, `ring_util_bending` | stacked bar per row | values |",
        "| `util_bar` | `max_util` per ring | one utilisation bar per row; the stack retired at v5 | values |",
    ),
    (
        "docs/reporting/figures/ring-utilisation/SPEC.md",
        "| axial share | `ring_util_axial` | stack, legend, caption | `N/N_crit` on the worst-utilisation beam |\n"
        "| bending share | `ring_util_bending` | stack, legend, caption | `√(M_ip²+M_oop²)/M_el` on the same beam |",
        "| axial share | `ring_util_axial` | caption | `N/N_crit` on the worst-utilisation beam |\n"
        "| bending share | `ring_util_bending` | caption; the legend carries the combined form | `√(M_ip²+M_oop²)/M_el` on the same beam |",
    ),
    (
        "docs/reporting/figures/ring-utilisation/SPEC.md",
        "- v4 (2026-10-14): the round-3 caption leads land in the kit text. Both\n"
        "  tiers open with the governing ring. The technical tier adds the hub\n"
        "  result (NR-021) and the gate line (NR-015). No render moves.",
        "- v4 (2026-10-14): the round-3 caption leads land in the kit text. Both\n"
        "  tiers open with the governing ring. The technical tier adds the hub\n"
        "  result (NR-021) and the gate line (NR-015). No render moves.\n"
        "\n"
        f"- v5 (2026-10-14): the 3.5 render deltas. The axis goes logarithmic (10⁻⁶\n"
        "  to the unit value), the stack retires to one utilisation bar, and the\n"
        "  corrected interaction form N/N_crit + √(M_ip²+M_oop²)/M_el reads in the\n"
        f"  legend and the caption. Script commit `{H1}`.",
    ),
    # ------------------------------------------------------------- ring register
    (
        "docs/reporting/figures/ring-utilisation/register-status.md",
        "--script-commit eacf073",
        f"--script-commit {H1}",
    ),
    (
        "docs/reporting/figures/ring-utilisation/register-status.md",
        "**Delta** v1 (2026-10-14): the round-3 caption leads land. The caption\n"
        "cites NR-015 for the gate sentence. No render moves.",
        "**Delta** v1 (2026-10-14): the round-3 caption leads land. The caption\n"
        "cites NR-015 for the gate sentence. No render moves.\n"
        "\n"
        "**Delta** v2 (2026-10-14): the 3.5 render deltas. The log axis, the\n"
        "single-bar form and the caption updates land. The readouts stand at the\n"
        f"drawn precision. Script commit `{H1}`.",
    ),
    # ------------------------------------------------------------- twist captions
    (
        "docs/reporting/figures/twist-limit/captions.md",
        "Panel A draws the transmitted twist of each segment as a magnitude,\n"
        "against its over-twist limit δcrit. The limit comes from the committed\n"
        "authority `trpt_twist_limit`.",
        "Panel A draws the transmitted twist of each segment as a magnitude,\n"
        "against its limits: the over-twist limit δcrit and the realisability\n"
        "floor. δcrit comes from the committed authority `trpt_twist_limit`. The\n"
        "floor follows sin Δα ≤ 1/1.05.",
    ),
    (
        "docs/reporting/figures/twist-limit/captions.md",
        "script commit `eacf073`",
        f"script commit `{H1}`",
    ),
    (
        "docs/reporting/figures/twist-limit/captions.md",
        "Review carry (2026-10-12): the 2026-08-13 line (22,425° against its 42.6°\n"
        "limit, off scale) leaves the plate notes for the failure-ledger appendix\n"
        "at the plate's next render pass. It stays on the plate until then.",
        "Review carry (2026-10-12): the 2026-08-13 line (22,425° against its 42.6°\n"
        "limit, off scale) leaves the plate notes for the failure-ledger appendix\n"
        "at the plate's next render pass.",
    ),
    (
        "docs/reporting/figures/twist-limit/captions.md",
        "Counter-read (2026-10-12, `9ba8dae`): the carry-note reads accurate, and\n"
        "the caption claims trace. Tracked before sign-off: register rows for the\n"
        "drawn mechanism values (72.25°, the 42.6° limit, 22,425°). They ride\n"
        "with the ledger pass. The floor and binding-limit treatment routes\n"
        "through work item 1.3 (the row-7 gate).",
        "Counter-read (2026-10-12, `9ba8dae`): the carry-note reads accurate, and\n"
        "the caption claims trace. Tracked before sign-off: register rows for the\n"
        "drawn mechanism values (72.25°. The 42.6° limit and the 22,425° overshoot\n"
        "retire with the v2 render). The floor row rides with the ledger pass.\n"
        "The floor and binding-limit treatment routes through work item 1.3 (the\n"
        "row-7 gate). It executed at the 3.5 render deltas.",
    ),
    (
        "docs/reporting/figures/twist-limit/captions.md",
        "Caption lead (2026-10-14): the round-3 leads land in both tiers. The\n"
        "technical tier adds the least segment torque margin (NR-040). Text\n"
        "only, no render moves.",
        "Caption lead (2026-10-14): the round-3 leads land in both tiers. The\n"
        "technical tier adds the least segment torque margin (NR-040). Text\n"
        "only, no render moves.\n"
        "\n"
        "Render delta (2026-10-14): the 3.5 deltas land. The 2026-08-13 and\n"
        "read-cap lines leave the plate notes for the failure ledger. The δcrit\n"
        "labels re-space clear of the tick column.\n"
        "\n"
        "The title, subtitle and panel-A label measure against the binding limit,\n"
        "the realisability floor. Render moved. No drawn value moves.",
    ),
    # ------------------------------------------------------------- twist SPEC
    (
        "docs/reporting/figures/twist-limit/SPEC.md",
        "- v3 (2026-10-14): the round-3 caption leads land in the kit text. Both\n"
        "  tiers open with the limit result. The technical tier adds the least\n"
        "  torque margin (NR-040). No render moves.",
        "- v3 (2026-10-14): the round-3 caption leads land in the kit text. Both\n"
        "  tiers open with the limit result. The technical tier adds the least\n"
        "  torque margin (NR-040). No render moves.\n"
        "\n"
        "- v4 (2026-10-14): the 3.5 render deltas. The two changelog notes leave\n"
        "  the plate (the failure ledger carries the history). The δcrit labels\n"
        "  re-space clear of the tick column. The title, subtitle and panel-A\n"
        "  label measure against the binding limit, the realisability floor (work\n"
        f"  item 1.3). Script commit `{H1}`.",
    ),
    # ------------------------------------------------------------- twist register
    (
        "docs/reporting/figures/twist-limit/register-status.md",
        "- Realisability floor 72.25° (from sin Δα ≤ 1/1.05).\n"
        "- Crossing-limit example 42.6°, with the 2026-08-13 overshoot 22,425°\n"
        "  (62 revolutions), off scale.\n"
        "- Read cap history: the former 90° asin clamp no longer caps the read.\n"
        "- No-limit wording, pinned by the author draft (v4). It carries no value.",
        "- Realisability floor 72.25° (from sin Δα ≤ 1/1.05). It is the binding\n"
        "  limit of the three (Harris 1.3; software-validator, item 13).\n"
        "- No-limit wording, pinned by the author draft (v4). It carries no value.\n"
        "\n"
        "The 2026-08-13 overshoot line (22,425°) and the read-cap line left the\n"
        "plate at the v2 render (2026-10-14); the failure ledger carries that\n"
        "history.",
    ),
    (
        "docs/reporting/figures/twist-limit/register-status.md",
        "--script-commit eacf073",
        f"--script-commit {H1}",
    ),
    (
        "docs/reporting/figures/twist-limit/register-status.md",
        "**Delta** v1 (2026-10-14): the round-3 caption leads land. The caption\n"
        "cites NR-040 for the least torque margin. No render moves.",
        "**Delta** v1 (2026-10-14): the round-3 caption leads land. The caption\n"
        "cites NR-040 for the least torque margin. No render moves.\n"
        "\n"
        "**Delta** v2 (2026-10-14): the 3.5 render deltas. The two changelog\n"
        "notes leave; the δcrit labels re-space; the title and labels measure\n"
        f"against the binding limit. Script commit `{H1}`.",
    ),
    # ------------------------------------------------------------- figure map
    (
        "docs/reporting/figures/figure-map.md",
        "The 3.5 kit deltas. Then F-VALUE at the sign-off commit",
        f"The 3.5 kit deltas landed (script `{H1}`; the log axis, the single-bar form, the corrected interaction form). Next: F-VALUE at the sign-off commit",
    ),
    (
        "docs/reporting/figures/figure-map.md",
        "The 3.5 kit deltas and the 1.3 ruling. Then F-VALUE at the sign-off commit",
        f"The 3.5 kit deltas and the 1.3 ruling landed (script `{H1}`; the notes out, the label re-space, the binding-limit title). Next: F-VALUE at the sign-off commit",
    ),
    (
        "docs/reporting/figures/figure-map.md",
        "- **v28 (2026-10-14):** the round-3 caption leads land in the kit text\n"
        "  (rows 6, 7 and 9 kits). Both tiers of the three seated captions\n"
        "  open with the result. The ring gate line cites NR-015 and the twist\n"
        "  margin cites NR-040. Text only, no renders move. The 3.5 render\n"
        "  deltas stay queued at the figures seat.",
        "- **v28 (2026-10-14):** the round-3 caption leads land in the kit text\n"
        "  (rows 6, 7 and 9 kits). Both tiers of the three seated captions\n"
        "  open with the result. The ring gate line cites NR-015 and the twist\n"
        "  margin cites NR-040. Text only, no renders move. The 3.5 render\n"
        "  deltas stay queued at the figures seat.\n"
        "\n"
        "- **v29 (2026-10-14):** rows 6 and 7 take the 3.5 render deltas (script\n"
        f"  `{H1}`): the ring plate's log axis and single-bar form with the\n"
        "  corrected interaction form; the twist plate's changelog notes out, the\n"
        "  label re-space, and the binding-limit title. No drawn value moves.\n"
        "  Next at both: F-VALUE at the sign-off commit.",
    ),
]


def main() -> int:
    failures = 0
    for path, old, new in EDITS:
        p = ROOT / path
        t = p.read_text()
        n = t.count(old)
        if n != 1:
            print(f"ABORT {path}: anchor count {n} (expected 1): {old[:70]!r}")
            failures += 1
            continue
        p.write_text(t.replace(old, new, 1))
        print(f"edited {path}: {old[:60]!r} -> {new[:60]!r}")
    if failures:
        print(f"FAILED: {failures} anchors")
        return 1
    print(f"applied {len(EDITS)} edits")
    return 0


if __name__ == "__main__":
    sys.exit(main())

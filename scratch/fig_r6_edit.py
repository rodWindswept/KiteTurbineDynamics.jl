#!/usr/bin/env python3
"""fig-r6 edit pass — the round-6 hub-name retirement, figures seat.

Two-phase, count-asserted text edits across the five plate generators and
the kit records (markdown prose only; the pin/provenance lines that carry
the new script commit land in fig_r6_pins.py).

Phase 1 verifies every anchor count across every file and prints all
failures. Phase 2 applies all writes only when phase 1 is clean.

Run from the repo root: /usr/bin/python3 scratch/fig_r6_edit.py
"""
import sys
from pathlib import Path

ROOT = Path(".")

EDITS = {
    # ── G1 system-anatomy.py (generator) ───────────────────────────────
    "docs/reporting/figures/system-anatomy/system-anatomy.py": [
        ("# new number.\n# Standing rule: the 22.0 slot value never prints as a rotor angle.",
         "# new number.\n"
         "# v6 re-cut (2026-10-14): the hub-name retirement (round-6 founder\n"
         "# comment 1). The R6 label reads \"R6, the topmost ring\". No new\n"
         "# number.\n"
         "# Standing rule: the 22.0 slot value never prints as a rotor angle."),
        ('lines=["R6, the hub ring", "4.580 m"],',
         'lines=["R6, the topmost ring", "4.580 m"],'),
    ],

    # ── G2 ring-utilisation.py (generator) ─────────────────────────────
    "docs/reporting/figures/ring-utilisation/ring-utilisation.py": [
        ("carries in the legend and the caption.\n\nRun:",
         "carries in the legend and the caption.\n\n"
         "v6 (the round-6 hub-name retirement, 2026-10-14): the top ring label\n"
         "reads \"R6 (top)\". No drawn value moves.\n\nRun:"),
        ('label = "R6 (hub)" if rid == "R6" else rid',
         'label = "R6 (top)" if rid == "R6" else rid'),
    ],

    # ── G3 twist-limit.py (generator) ──────────────────────────────────
    "docs/reporting/figures/twist-limit/twist-limit.py": [
        ("the realisability floor (work item 1.3).\n\nRun:",
         "the realisability floor (work item 1.3).\n\n"
         "v5 (the round-6 hub-name retirement, 2026-10-14): the top ring label\n"
         "reads \"R6 (top)\" and the subtitle reads \"ground to top\". No drawn\n"
         "value moves.\n\nRun:"),
        ('"floor · shaft profile S1–S5, ground to hub · island-3 winner "',
         '"floor · shaft profile S1–S5, ground to top · island-3 winner "'),
        ('label = "R6 (hub)" if i == 5 else f"R{i + 1}"',
         'label = "R6 (top)" if i == 5 else f"R{i + 1}"'),
    ],

    # ── G4 eval-timeline.py (generator) ────────────────────────────────
    "docs/reporting/figures/eval-timeline/eval-timeline.py": [
        ('No label claims the machine "would pass".\n\nRun:',
         'No label claims the machine "would pass".\n\n'
         "v2 (the round-6 hub-name retirement, 2026-10-14): the lane-1 label\n"
         "reads \"\u03c9 top\" and the gate row reads \"top · tip · Betz\". The\n"
         "drawn rows list takes NR-042 (its recorded next-build item). No\n"
         "drawn value moves.\n\nRun:"),
        ('ROWS = ("NR-008 \\u00b7 NR-012 \\u00b7 NR-013 \\u00b7 NR-013 ext \\u00b7 NR-016 "\n'
         '        "\\u00b7 NR-027 \\u00b7 NR-029 \\u00b7 NR-039")',
         'ROWS = ("NR-008 \\u00b7 NR-012 \\u00b7 NR-013 \\u00b7 NR-013 ext \\u00b7 NR-016 "\n'
         '        "\\u00b7 NR-027 \\u00b7 NR-029 \\u00b7 NR-039 \\u00b7 NR-042")'),
        ('"\\u03c9 gnd (solid) \\u00b7 \\u03c9 hub (dashed)"',
         '"\\u03c9 gnd (solid) \\u00b7 \\u03c9 top (dashed)"'),
        ('"hub \\u00b7 tip \\u00b7 Betz, read"',
         '"top \\u00b7 tip \\u00b7 Betz, read"'),
        ('"register_rows": ["NR-008", "NR-012", "NR-013", "NR-013 ext",\n'
         '                              "NR-016", "NR-027", "NR-029", "NR-039"],',
         '"register_rows": ["NR-008", "NR-012", "NR-013", "NR-013 ext",\n'
         '                              "NR-016", "NR-027", "NR-029", "NR-039", "NR-042"],'),
    ],

    # ── G5 machine-winner-hero.jl (generator) ──────────────────────────
    "docs/reporting/figures/machine-winner-hero/machine-winner-hero.jl": [
        ("# asks for comes from the capture, not a fresh settle run. No ODE runs here.\n#\n# Run:",
         "# asks for comes from the capture, not a fresh settle run. No ODE runs here.\n#\n"
         "# v2 re-cut (2026-10-14): the hub-name retirement (round-6 founder\n"
         "# comment 1). The drawn leader reads \"topmost ring R6\". No value moves.\n#\n# Run:"),
        ('text="hub ring R6"', 'text="topmost ring R6"'),
        ('push!(loglines, @sprintf("drawn hub altitude: %.4f m (register settled-basis note reads mean z 8.914 m, elevation 28.64 deg)", hubz))',
         'push!(loglines, @sprintf("drawn topmost-ring altitude: %.4f m (register settled-basis note reads mean z 8.914 m, elevation 28.64 deg)", hubz))'),
    ],

    # ── SA records (markdown, no script-commit tokens here) ────────────
    "docs/reporting/figures/system-anatomy/captions-draft.md": [
        ("to the hub ring (R6, 4.580 m", "to the topmost ring (R6, 4.580 m"),
        ("bridle, main rotor, ground ring, hub ring, ground station, backline.",
         "bridle, main rotor, ground ring, topmost ring, ground station, backline."),
        ("Labels run ground to hub.", "Labels run ground to top."),
    ],
    "docs/reporting/figures/system-anatomy/captions.md": [
        ("to the hub ring (R6,", "to the topmost ring (R6,"),
        ("The plate text changes; the captions do not move.\n",
         "The plate text changes; the captions do not move.\n"
         "\n"
         "Retirement note (2026-10-14): the hub-name retirement (round-6\n"
         "comment 1). The R6 label reads \"R6, the topmost ring\". No value\n"
         "moves. The plate re-renders; the provenance token takes the round-6\n"
         "script commit.\n"),
    ],
    "docs/reporting/figures/system-anatomy/SPEC.md": [
        ("| hub radius, ring R6 | 4.580 m | NR-011 |",
         "| topmost ring radius, ring R6 | 4.580 m | NR-011 |"),
        ("- Labels run ground to hub. Thirteen labels. The cone ring (R5) label is",
         "- Labels run ground to top. Thirteen labels. The cone ring (R5) label is"),
        ("crops (chain zone, hub ring", "crops (chain zone, topmost ring"),
        ("- Closed: the author label check (`38a15f1`) holds. Its two re-cuts landed\n  in v2 and v3.",
         "- Closed: the author label check (`38a15f1`) holds. Its two re-cuts landed\n  in v2 and v3.\n"
         "- Closed: the hub-name retirement (round-6, 2026-10-14). The R6 label\n"
         "  reads \"R6, the topmost ring\". No value moves."),
    ],

    # ── RU records ─────────────────────────────────────────────────────
    "docs/reporting/figures/ring-utilisation/captions.md": [
        ("The hub ring R6 governs the structural check at FoS 15.033. All",
         "The topmost rotor ring R6 governs the structural check at FoS 15.033. All"),
        ("The rows run from R2 at the base to R6 at the hub. Utilisation is demand",
         "The rows run from R2 at the base to R6 at the top. Utilisation is demand"),
        ("marks the hub\nring.", "marks the topmost\nring."),
        ("the hub row now reads R6 in", "the top row now reads R6 in"),
        ("hub result (NR-021)", "topmost ring result (NR-021)"),
        ("technical claim. Text only, no render moves.\n",
         "technical claim. Text only, no render moves.\n"
         "\n"
         "Retirement note (2026-10-14): the hub-name retirement (round-6\n"
         "comment 1). The governs sentence takes the full name, and the\n"
         "direction, marks, carried-token and lead lines take the top forms.\n"
         "Text only, no render value moves; the plate re-renders at the round-6\n"
         "script commit.\n"),
    ],
    "docs/reporting/figures/ring-utilisation/captions-draft.md": [
        ("The rows run from R2 at the base to RN at the hub.",
         "The rows run from R2 at the base to RN at the top."),
        ("The figure includes and marks the hub ring.",
         "The figure includes and marks the topmost ring."),
        ("The ground ring stays out and the hub ring carries a mark.",
         "The ground ring stays out and the topmost ring carries a mark."),
    ],
    "docs/reporting/figures/ring-utilisation/SPEC.md": [
        ("The hub ring stays", "The topmost ring stays"),
        ("with the hub ring marked.", "with the topmost ring marked."),
        ("(hub) at the top.", "(top) at the top."),
        ("one row per checked ring, R2 at the base, hub at the top",
         "one row per checked ring, R2 at the base, topmost ring at the top"),
        ("ground ring excluded, hub ring included and marked",
         "ground ring excluded, topmost ring included and marked"),
        ("The hub\nread and the cites", "The topmost ring\nread and the cites"),
        ("the hub-ring inclusion", "the topmost-ring inclusion"),
        ("Lead with the hub result (NR-021).", "Lead with the topmost ring result (NR-021)."),
        ("Record indexing proposed: ring 1 ground … ring N hub.",
         "Record indexing proposed: ring 1 ground … ring N top."),
        ("adds the hub\n  result (NR-021)", "adds the topmost ring\n  result (NR-021)"),
    ],
    "docs/reporting/figures/ring-utilisation/register-status.md": [
        ("The hub readout reads", "The topmost ring readout reads"),
    ],

    # ── TL records (sweep) ─────────────────────────────────────────────
    "docs/reporting/figures/twist-limit/captions.md": [
        ("technical claim. Text only, no render moves.\n",
         "technical claim. Text only, no render moves.\n"
         "\n"
         "Retirement note (2026-10-14): the hub-name retirement (round-6\n"
         "comment 1). The top ring label reads \"R6 (top)\" and the subtitle\n"
         "reads \"ground to top\". Text only, no value moves; the plate\n"
         "re-renders at the round-6 script commit.\n"),
    ],
    "docs/reporting/figures/twist-limit/SPEC.md": [
        ("(ground → hub, labels `S1..Sn`)", "(ground → top, labels `S1..Sn`)"),
        ("orange\n  hub)", "orange\n  top)"),
        ("ring 1 is the ground ring, ring N the hub ring).",
         "ring 1 is the ground ring, ring N the topmost ring)."),
        ("S1 at the base, ground → hub", "S1 at the base, ground → top"),
        ("ring 1 ground, ring N hub", "ring 1 ground, ring N top"),
        ("ground … ring N hub, segments ground → hub).",
         "ground … ring N top, segments ground → top)."),
    ],

    # ── ET records (sweep) ─────────────────────────────────────────────
    "docs/reporting/figures/eval-timeline/SPEC.md": [
        ("Lane 1 carries the ground rate and the hub rate, with the two",
         "Lane 1 carries the ground rate and the top rate, with the two"),
        ("- v1 (2026-10-13): R2 lands with the GENERATE pass. The scratch draft\n"
         "  carried the round-1 reads. The two term picks land: the subtitle\n"
         "  drops the colon code forms, and the ruling label takes \"not yet in\n"
         "  the code\". No drawn value changed at the landing.",
         "- v1 (2026-10-13): R2 lands with the GENERATE pass. The scratch draft\n"
         "  carried the round-1 reads. The two term picks land: the subtitle\n"
         "  drops the colon code forms, and the ruling label takes \"not yet in\n"
         "  the code\". No drawn value changed at the landing.\n"
         "\n"
         "- v2 (2026-10-14): the hub-name retirement sweep (round-6 comment 1).\n"
         "  The lane-1 label reads \"\u03c9 top\" and the gate row reads \"top · tip ·\n"
         "  Betz\". The drawn rows list takes NR-042 (its recorded next-build\n"
         "  item). No drawn value moves."),
    ],
    "docs/reporting/figures/eval-timeline/register-status.md": [
        ("The drawn footer row list still runs through NR-039. NR-042 joins it\n"
         "at the next plate build (science-validator, `8fb529e`).",
         "The drawn footer row list takes NR-042 at the round-6 build\n"
         "(science-validator, `8fb529e`). NR-042 is signed (`8c278a5`)."),
        ("v1:\ncreated with the kit landing.",
         "v1:\ncreated with the kit landing.\n"
         "**Delta** v5 (2026-10-14): the hub-name retirement (round-6 comment\n"
         "1). The lane-1 label reads \"\u03c9 top\" and the gate row reads \"top ·\n"
         "tip · Betz\". The drawn footer row list takes NR-042 at this build.\n"
         "No drawn value moves."),
    ],

    # ── HERO record ────────────────────────────────────────────────────
    "docs/reporting/figures/machine-winner-hero/register-status.md": [
        ("| NR-011 | Winner geometry: six rings, three lines, one rotor, hub and ground radii | Signed (science-validator, 2026-10-08) |",
         "| NR-011 | Winner geometry: six rings, three lines, one rotor, topmost ring and ground radii | Signed (science-validator, 2026-10-08) |"),
    ],

    # ── STRIP records ──────────────────────────────────────────────────
    "docs/reporting/figures/machine-evolution-strip/captions.md": [
        ("hub radius 4.580 m, ground radius 0.804 m, blade scales 0.82 and 0.20.",
         "topmost ring radius 4.580 m, ground radius 0.804 m, blade scales 0.82 and 0.20."),
        ("technical claim. Text only, no render moves.\n",
         "technical claim. Text only, no render moves.\n"
         "\n"
         "Retirement note (2026-10-14): the hub-name retirement (round-6\n"
         "comment 1). The final-panel line reads \"topmost ring radius\n"
         "4.580 m\". Text only, no render moves.\n"),
    ],
    "docs/reporting/figures/machine-evolution-strip/register-status.md": [
        ("Self-check: two consecutive runs stay byte-identical across all five\n"
         "outputs (png, svg, pdf, manifest, checks.log). Verified 2026-10-11 at\n"
         "`74cfef9`.",
         "Self-check: two consecutive runs stay byte-identical across all five\n"
         "outputs (png, svg, pdf, manifest, checks.log). Verified 2026-10-11 at\n"
         "`74cfef9`.\n"
         "\n"
         "**Delta** (2026-10-14): the hub-name retirement (round-6 comment 1).\n"
         "The final-panel caption line reads \"topmost ring radius 4.580 m\".\n"
         "Text only, no render moves; the strip pins stand."),
    ],
}

prints = []
n_ok = 0
n_fail = 0
for rel, pairs in EDITS.items():
    p = ROOT / rel
    if not p.exists():
        prints.append(f"FAIL missing file: {rel}")
        n_fail += 1
        continue
    t = p.read_text(encoding="utf-8")
    for old, new in pairs:
        c = t.count(old)
        if c != 1:
            prints.append(f"FAIL count {c} (want 1) in {rel}:\n  anchor: {old[:90]!r}")
            n_fail += 1
        else:
            n_ok += 1

print(f"fig-r6 edit phase 1: {n_ok} anchors ok, {n_fail} fail")
if prints:
    print("\n".join(prints))
    sys.exit(1)

for rel, pairs in EDITS.items():
    p = ROOT / rel
    t = p.read_text(encoding="utf-8")
    for old, new in pairs:
        t = t.replace(old, new, 1)
    p.write_text(t, encoding="utf-8")
    print(f"applied: {rel} ({len(pairs)} edits)")

print("fig-r6 edit pass complete.")

#!/usr/bin/env python3
"""Repair the v0.91 candidate back to the base violation set."""
from pathlib import Path

p = Path("/home/rod/Documents/GitHub/KiteTurbineDynamics-author-wt/docs/reporting/drafts/2026-10-08-report-first-draft.md")
t = p.read_text()

subs = [
    (
        "The report's $\\delta_{\\mathrm{crit}}$ is the peak (NR-022), so this block names the zero crossing.",
        "The report prints $\\delta_{\\mathrm{crit}}$ as the peak (NR-022), so this block names the zero crossing.",
    ),
    (
        "The averaging argument uses Jensen's inequality.",
        "The averaging argument uses the Jensen inequality.",
    ),
    (
        "The margin at an operating twist is a function of two angles.",
        "The margin at an operating twist depends on two angles.",
    ),
    (
        "$$\\delta_{\\mathrm{zero}} =\n"
        "\\begin{cases}\n"
        "\\pi, & l \\geq r_0 + r_1 \\\\\n"
        "\\arccos \\frac{r_0^2 + r_1^2 - l^2}{2 r_0 r_1}, & l < r_0 + r_1\n"
        "\\end{cases}$$",
        "$$\\delta_{\\mathrm{zero}} = \\pi \\qquad (l \\geq r_0 + r_1)$$\n"
        "\n"
        "$$\\delta_{\\mathrm{zero}} = \\arccos \\frac{r_0^2 + r_1^2 - l^2}{2 r_0 r_1} \\qquad (l < r_0 + r_1)$$",
    ),
    (
        "The blade radius `r_rotor` is the power-sizing radius, not the tip.\nThe blade crosses the ring.",
        "The blade radius `r_rotor` is the power-sizing radius, not the tip.\n\nThe blade crosses the ring.",
    ),
    (
        "The screen is a loose tripwire (NR-034).\nThe availability and aggregate screens",
        "The screen is a loose tripwire (NR-034).\n\nThe availability and aggregate screens",
    ),
    (
        "An ok design within a whisker of the limit scores below every reject.\nThe twist gate flags",
        "An ok design within a whisker of the limit scores below every reject.\n\nThe twist gate flags",
    ),
]

for old, new in subs:
    n = t.count(old)
    assert n == 1, (old[:60], n)
    t = t.replace(old, new)

p.write_text(t)
print("fixes applied")

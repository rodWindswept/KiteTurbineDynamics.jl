#!/usr/bin/env python3
"""Round-5 caption dedupe (figures seat, 2026-10-14).

Routing: feedback-5, comment 12 (id 11) + comment 13 (id 12); caption
audit swept the same repeat to rows 6, 7 and 9. Each plain tier becomes
one takeaway sentence; the tiers no longer repeat one claim.

Kit text only. No render moves. One process, count-asserted edits.
"""
from pathlib import Path

REPO = Path("/home/rod/Documents/GitHub/KiteTurbineDynamics.jl")
FIGS = REPO / "docs/reporting/figures"

EDITS = []  # (path, old, new, expected_count)

# ---------- 1. ring-utilisation captions.md ----------
p = FIGS / "ring-utilisation/captions.md"
EDITS.append((p,
    "The hub ring R6 governs the structural check at the winner's final\n"
    "operating point, and every other airborne ring holds a much larger\n"
    "margin.",
    "Every airborne ring passes its structural check with a wide margin.",
    1))
EDITS.append((p,
    "the capture slot and the\n2026-10-12 caption split and the 2026-10-14 leads.",
    "the capture slot, the\n2026-10-12 caption split, the 2026-10-14 leads and the 2026-10-14\n"
    "takeaway rewrite.",
    1))
EDITS.append((p,
    "The bending-share sentence replaces the display-floor sentences.\n"
    "Render moved. No drawn value moves.\n",
    "The bending-share sentence replaces the display-floor sentences.\n"
    "Render moved. No drawn value moves.\n"
    "\n"
    "Takeaway (2026-10-14): the plain tier reads one takeaway sentence\n"
    "(the round-5 caption dedupe). The tier no longer repeats the\n"
    "technical claim. Text only, no render moves.\n",
    1))

# ---------- 2. twist-limit captions.md ----------
p = FIGS / "twist-limit/captions.md"
EDITS.append((p,
    "All five segments stay inside their over-twist limits at the winner's\n"
    "final operating point, and the smallest torque margin sits at S1.",
    "The shaft passes its twist and torque checks along its whole length.",
    1))
EDITS.append((p,
    "the capture slot and the\n2026-10-12 caption split and the 2026-10-14 leads.",
    "the capture slot, the\n2026-10-12 caption split, the 2026-10-14 leads and the 2026-10-14\n"
    "takeaway rewrite.",
    1))
EDITS.append((p,
    "The title, subtitle and panel-A label measure against the binding limit,\n"
    "the realisability floor. Render moved. No drawn value moves.\n",
    "The title, subtitle and panel-A label measure against the binding limit,\n"
    "the realisability floor. Render moved. No drawn value moves.\n"
    "\n"
    "Takeaway (2026-10-14): the plain tier reads one takeaway sentence\n"
    "(the round-5 caption dedupe). The tier no longer repeats the\n"
    "technical claim. Text only, no render moves.\n",
    1))

# ---------- 3. machine-evolution-strip captions.md ----------
p = FIGS / "machine-evolution-strip/captions.md"
EDITS.append((p,
    "Island 3's best-so-far objective falls as the built geometry converges\n"
    "to the register winner. The row starts at the common seed and ends at\n"
    "the campaign winner. Each machine is\n"
    "drawn from its built geometry, and all seven share one scale. The\n"
    "number under each machine is its search objective, in kg-equivalent. A\n"
    "lower number is better.",
    "The search improves the machine at every recorded step, from the\n"
    "common seed to the campaign winner.",
    1))
EDITS.append((p,
    "with the 2026-10-12 caption split. Values cite\n",
    "with the 2026-10-12 caption split\n"
    "and the 2026-10-14 takeaway rewrite. Values cite\n",
    1))
EDITS.append((p,
    "Caption lead (2026-10-14): the takeaway opens both tiers. The lead\n"
    "prints the objective range from the signed rows (NR-006, NR-005).\n"
    "Text only, no render moves.\n",
    "Caption lead (2026-10-14): the takeaway opens both tiers. The lead\n"
    "prints the objective range from the signed rows (NR-006, NR-005).\n"
    "Text only, no render moves.\n"
    "\n"
    "Takeaway (2026-10-14): the plain tier reads one takeaway sentence\n"
    "(the round-5 caption dedupe). The tier no longer repeats the\n"
    "technical claim. Text only, no render moves.\n",
    1))

# ---------- 4. ring-utilisation SPEC.md ----------
p = FIGS / "ring-utilisation/SPEC.md"
EDITS.append((p,
    "**Caption plan (dual, from the first figure).** Plain sentence: every ring\n"
    "meets one strict structural check. The hub ring R6 governs, and every\n"
    "other airborne ring holds a much larger margin.",
    "**Caption plan (dual, from the first figure).** Plain sentence: every ring\n"
    "meets one strict structural check. The tier reads one takeaway: every\n"
    "airborne ring passes its structural check with a wide margin. The hub\n"
    "read and the cites live in the technical tier.",
    1))
EDITS.append((p,
    "- v6 (2026-10-14): the F-VALUE closure. The re-census at `c30b2ca` closes\n"
    "  F-VALUE on the fix commit (`ef36c6c`), zero defects (85 checks). The R2\n"
    "  rounds line takes the closure. No render moves.\n",
    "- v6 (2026-10-14): the F-VALUE closure. The re-census at `c30b2ca` closes\n"
    "  F-VALUE on the fix commit (`ef36c6c`), zero defects (85 checks). The R2\n"
    "  rounds line takes the closure. No render moves.\n"
    "\n"
    "- v7 (2026-10-14): the plain tier reads one takeaway sentence (the\n"
    "  round-5 caption dedupe). The tier no longer repeats the technical\n"
    "  claim. The caption plan updates with it. No render moves.\n",
    1))

# ---------- 5. twist-limit SPEC.md ----------
p = FIGS / "twist-limit/SPEC.md"
EDITS.append((p,
    "**Caption plan (dual, from the first figure).** Plain sentence: the shaft\n"
    "twists as it carries torque. All five segments stay inside their\n"
    "over-twist limits at the winner's final operating point.",
    "**Caption plan (dual, from the first figure).** Plain sentence: the shaft\n"
    "twists as it carries torque. The tier reads one takeaway: the shaft\n"
    "passes its twist and torque checks along its whole length. The segment\n"
    "ranks and the cites live in the technical tier (NR-022, NR-040).",
    1))
EDITS.append((p,
    "- v5 (2026-10-14): the F-VALUE closure. The re-census at `c30b2ca` closes\n"
    "  F-VALUE on the fix commit (`ef36c6c`), zero defects (85 checks). The R2\n"
    "  rounds line takes the closure. No render moves.\n",
    "- v5 (2026-10-14): the F-VALUE closure. The re-census at `c30b2ca` closes\n"
    "  F-VALUE on the fix commit (`ef36c6c`), zero defects (85 checks). The R2\n"
    "  rounds line takes the closure. No render moves.\n"
    "\n"
    "- v6 (2026-10-14): the plain tier reads one takeaway sentence (the\n"
    "  round-5 caption dedupe). The tier no longer repeats the technical\n"
    "  claim. The caption plan updates with it. No render moves.\n",
    1))

# ---------- 6/7. register notes ----------
p = FIGS / "ring-utilisation/register-status.md"
EDITS.append((p,
    "**Delta** v2 (2026-10-14): the 3.5 render deltas. The log axis, the\n"
    "single-bar form and the caption updates land. The readouts stand at the\n"
    "drawn precision. Script commit `671ab96`.\n",
    "**Delta** v2 (2026-10-14): the 3.5 render deltas. The log axis, the\n"
    "single-bar form and the caption updates land. The readouts stand at the\n"
    "drawn precision. Script commit `671ab96`.\n"
    "\n"
    "**Delta** v3 (2026-10-14): the round-5 caption dedupe. The plain tier\n"
    "reads one takeaway sentence, and the tiers no longer repeat one claim.\n"
    "No render moves.\n",
    1))

p = FIGS / "twist-limit/register-status.md"
EDITS.append((p,
    "**Delta** v2 (2026-10-14): the 3.5 render deltas. The two changelog\n"
    "notes leave; the δcrit labels re-space; the title and labels measure\n"
    "against the binding limit. Script commit `671ab96`.\n",
    "**Delta** v2 (2026-10-14): the 3.5 render deltas. The two changelog\n"
    "notes leave; the δcrit labels re-space; the title and labels measure\n"
    "against the binding limit. Script commit `671ab96`.\n"
    "\n"
    "**Delta** v3 (2026-10-14): the round-5 caption dedupe. The plain tier\n"
    "reads one takeaway sentence, and the tiers no longer repeat one claim.\n"
    "No render moves.\n",
    1))

# ---------- 8. figure map ----------
p = FIGS / "figure-map.md"
EDITS.append((p,
    "- **v33 (2026-10-14):** the hero counter-read closes clean at the aero\n"
    "  seat (`0cbb9b8`, 226 checks). The kit hashes, the four appendix cells\n"
    "  and the station and twist reads recompute at origin. No figure byte\n"
    "  moves. Row 10's next gate reads the visual pass by Rod.\n",
    "- **v33 (2026-10-14):** the hero counter-read closes clean at the aero\n"
    "  seat (`0cbb9b8`, 226 checks). The kit hashes, the four appendix cells\n"
    "  and the station and twist reads recompute at origin. No figure byte\n"
    "  moves. Row 10's next gate reads the visual pass by Rod.\n"
    "\n"
    "- **v34 (2026-10-14):** the round-5 caption dedupe lands (routing\n"
    "  comments 12 and 13, swept by the caption audit to rows 6, 7 and 9).\n"
    "  Each plain tier reads one takeaway sentence and the two tiers no\n"
    "  longer repeat one claim. Kit text only, no render moves: the three\n"
    "  caption files, the two SPEC caption plans and the two register notes.\n"
    "  The visual pass by Rod stays the next gate at all three.\n",
    1))

# ---------- apply ----------
base_dir = Path.home() / ".hermes/profiles/figures-images-diagrams/cache/scratch/fig_cd_base"
base_dir.mkdir(parents=True, exist_ok=True)

failures = []
for path, old, new, n in EDITS:
    t = path.read_text()
    c = t.count(old)
    if c != n:
        failures.append((str(path), c, n, old[:60]))
    elif n == 1 and t.count(new) > 0 and new not in old:
        # replacement text already present -> reject to stay resumable
        failures.append((str(path), -1, n, "NEW-TEXT-ALREADY-PRESENT: " + new[:60]))

if failures:
    print("ABORT: anchor failures")
    for f in failures:
        print(" ", f)
    raise SystemExit(1)

touched = {}
for path, old, new, n in EDITS:
    t = path.read_text()
    if str(path) not in touched:
        (base_dir / (path.name + "__" + path.parent.name + ".base")).write_text(t)
    t = t.replace(old, new)
    path.write_text(t)
    touched[str(path)] = touched.get(str(path), 0) + 1

print("applied", len(EDITS), "edits across", len(touched), "files")
for f, k in sorted(touched.items()):
    print(f"  {k} edits  {f}")
print("base copies in", base_dir)

#!/usr/bin/env python3
"""v0.58 close simulation: the seam fix (science-writer option b) plus the
"Where this goes" block. Author seat, 2026-10-16.

Base: docs/reporting/drafts/2026-10-08-report-first-draft.md (v0.57, md5 43ffc00e...).
Writes the candidate to scratch/ and reports word deltas for the supply.
"""
import pathlib
import re

root = pathlib.Path.home() / "Documents/GitHub/KiteTurbineDynamics.jl"
draft = root / "docs/reporting/drafts/2026-10-08-report-first-draft.md"
out = root / "scratch/au_v058_close_draft_candidate.md"
t = draft.read_text()

old_block = (
    "The next work closes the model gaps.\n"
    "Add blade structural checks and validate lifter modulation.\n"
    "Extend the model to the launch and recovery sequence.\n"
    "Extend the wind cases beyond the steady sheared profile.\n"
    "The large structural margins suggest room for mass reduction, once those checks hold."
)
new_pointer = (
    "The next work closes the model gaps.\n"
    "The recommended next steps sit in section 3.6."
)
close_text = (
    "**Where this goes.** This close is forward-looking. It states what the instrument does, "
    "then the programme targets. No line in it carries a register row.\n\n"
    "The instrument sizes and scores kite-turbine designs. Its physics model stands on "
    "the published TRPT lineage, and the cross-check names the matches and the mismatches. "
    "Each dataset carries its era, its commits and its geometry fingerprint. The ladder instrument "
    "screens each rung and each length on the corrected model. The register, the test suite and the "
    "seat checks hold every number. Findings, corrections and retractions land in the record with their lessons.\n\n"
    "The validated rung is the machine this report covers. The programme targets form the ladder "
    "above it, 7 to 50 kW. Each rung above it is a programme target, not a result. No repo artifact "
    "backs the rungs yet. One validation step at the Daisy scale comes first. The mission target is "
    "a displaced-cost metric, set out in phase G of the programme strategy."
)
bracket = "[Daisy values need register rows before the final report quotes\nthem.]"

assert t.count(old_block) == 1, "old block not found exactly once"
assert t.count(bracket) == 1, "bracket not found exactly once"

c = t.replace(old_block, new_pointer)
c = c.replace(bracket, bracket + "\n\n" + close_text)
out.write_text(c)


def wc(s):
    return len(re.findall(r"[A-Za-z0-9][A-Za-z0-9'\-/]*", s))


def sec5(text):
    i = text.index("## 5 Conclusion")
    j = text.index("## 6 Nomenclature")
    return text[i:j]


print("removed words:", wc(old_block), "-> pointer words:", wc(new_pointer))
print("close words (with lead):", wc(close_text))
print("sec5 words base:", wc(sec5(t)), "-> candidate:", wc(sec5(c)), "delta:", wc(sec5(c)) - wc(sec5(t)))
print("em dashes base:", t.count("\u2014") + t.count("\u2013"), "-> candidate:", c.count("\u2014") + c.count("\u2013"))
print("candidate written:", out)

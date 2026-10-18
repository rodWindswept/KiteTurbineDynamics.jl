#!/usr/bin/env python3
"""Author fold v0.59: T3-3 wording fix at aero's line, the section 5 seam,
and the labelled close under the science-writer prose pass.

Base: the staged v0.58 draft, md5 5fa159ce93eab1791effe314d3360566.
The draft blob at HEAD (221b692) is byte-identical to f696930, so the
declared token diff below closes against the landing base.
"""
import difflib
import hashlib
import re
import sys

SRC = "docs/reporting/drafts/2026-10-08-report-first-draft.md"
OUT = "scratch/au_v059_fold_out.md"
LOG = "scratch/au_v059_fold.log"

ops = []


def op(tag, old, new):
    ops.append((tag, old, new))


# --- v0.58 correction: aero's T3-3 line. The gate is strict. ---
op(
    "T3-3",
    "At r equal to one the\nsegment has crossed, so the ratio r over (1 minus r) would divide by",
    "At r equal to one the\nsegment reaches the crossing limit, so the ratio r over (1 minus r)\nwould divide by",
)

# --- the seam, science-writer option (b) ---
op(
    "SEAM",
    "The next work closes the model gaps.\n"
    "Add blade structural checks and validate lifter modulation.\n"
    "Extend the model to the launch and recovery sequence.\n"
    "Extend the wind cases beyond the steady sheared profile.\n"
    "The large structural margins suggest room for mass reduction, once those checks hold.\n",
    "The next work closes the model gaps.\n"
    "The recommended next steps sit in section 3.6.\n",
)

# --- the close, with the prose pass folded: sentence not line; the rung
# list from const RUNGS; no "yet"; no unbacked ordering claim; plainer verbs ---
CLOSE = """**Where this goes.** This close is forward-looking. It states what the
instrument does, then the programme targets. No sentence in it cites a
register row.

The instrument sizes and scores kite-turbine designs. Its physics model
follows the published TRPT lineage, and the cross-check names the
matches and the mismatches. Each dataset carries its era, its commits
and its geometry fingerprint.

The ladder instrument screens each rung and each length on the corrected
model. The register, the test suite and the seat checks hold every
number. Findings, corrections and retractions stay in the record with
their lessons.

The validated rung is the machine this report covers. The programme
targets form the ladder above it, 7, 10, 15, 25, 35 and 50 kW. Each rung
above it is a programme target, not a result. No repo artifact backs the
rungs.

The programme takes one validation step at the Daisy scale. The mission
target is a displaced-cost metric, set out in phase G of the programme
strategy.
"""

op(
    "CLOSE",
    "[Daisy values need register rows before the final report quotes\nthem.]\n\n## 6 Nomenclature",
    "[Daisy values need register rows before the final report quotes\nthem.]\n\n" + CLOSE + "\n## 6 Nomenclature",
)

# --- version line ---
op(
    "VER",
    "Internal engineering report. Draft v0.58. Date 2026-10-18.",
    "Internal engineering report. Draft v0.59. Date 2026-10-18.",
)

src = open(SRC, encoding="utf-8").read()
text = src
log = ["# Author fold v0.59 — the close", "",
       "Base md5 `%s`" % hashlib.md5(src.encode()).hexdigest(), ""]

for tag, old, new in ops:
    n = text.count(old)
    log.append("%-6s matches=%d" % (tag, n))
    if n != 1:
        log.append("FAIL: %s expected 1 match, read %d" % (tag, n))
        open(LOG, "w").write("\n".join(log) + "\n")
        print("\n".join(log))
        sys.exit(1)
    text = text.replace(old, new)

open(OUT, "w", encoding="utf-8").write(text)

diff = list(difflib.unified_diff(src.splitlines(), text.splitlines(),
                                 "v0.58", "v0.59", lineterm="", n=1))

# --- token census, hashes masked ---
TOKEN = re.compile(r"NR-\d+|\d[\d,\.]*e?-?\d*")
HEX64 = re.compile(r"\b[0-9a-f]{64}\b")


def census(s):
    d = {}
    for t in TOKEN.findall(HEX64.sub("<HASH>", s)):
        d[t] = d.get(t, 0) + 1
    return d


b, o = census(src), census(text)
gained = {k: v - b.get(k, 0) for k, v in o.items() if v > b.get(k, 0)}
lost = {k: b[k] - o.get(k, 0) for k in b if b[k] > o.get(k, 0)}

# --- the outside-the-close scan ---
scans = ["programme target", "MVP", "offshore", "network", "gigatonne",
         "p/\u00b7kWh", "p/kWh", "MWh", "gCO2", "\u00a3"]
body = text
close_start = body.index("**Where this goes.**")
close_end = body.index("## 6 Nomenclature")
outside = body[:close_start] + body[close_end:]
inside = body[close_start:close_end]
leaks = [(s, outside.count(s)) for s in scans if outside.count(s)]

log += ["", "lines %d to %d, words %d to %d" % (
    len(src.splitlines()), len(text.splitlines()), len(src.split()), len(text.split())),
    "hunks %d, added %d, removed %d" % (
        sum(1 for l in diff if l.startswith("@@")),
        sum(1 for l in diff if l.startswith("+") and not l.startswith("+++")),
        sum(1 for l in diff if l.startswith("-") and not l.startswith("---"))),
    "output md5 `%s`" % hashlib.md5(text.encode()).hexdigest(), "",
    "## Declared token diff", "",
    "gained: " + (", ".join("%s x%d" % kv for kv in sorted(gained.items())) or "none"),
    "lost:   " + (", ".join("%s x%d" % kv for kv in sorted(lost.items())) or "none"),
    "",
    "## Outside-the-close scan", "",
    "hits outside: " + (", ".join("%s x%d" % t for t in leaks) or "none"),
    "hits inside: " + ", ".join("%s x%d" % (s, inside.count(s)) for s in scans if inside.count(s)),
    "",
    "## Section 5 shape", ""]

sec5 = text[text.index("## 5 Conclusion"):text.index("## 6 Nomenclature")]
log.append("section 5 slice words=%d" % len(sec5.split()))
for para in [p for p in sec5.split("\n\n") if p.strip()]:
    sents = len([x for x in re.split(r"(?<=[.!?])\s+", para.strip()) if x])
    log.append("  para words=%-4d sentences=%d" % (len(para.split()), sents))

open("scratch/au_v059_fold.diff", "w", encoding="utf-8").write("\n".join(diff) + "\n")
open(LOG, "w", encoding="utf-8").write("\n".join(log) + "\n")
print("\n".join(log))

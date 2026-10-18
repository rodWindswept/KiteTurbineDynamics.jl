#!/usr/bin/env python3
"""Author fold v0.60: the four direction paragraphs (science-writer pass
applied), the label's third movement, and the scaling-ladder embed.

Base: the current master at a4409da, draft md5 d7252c84a0708161bd25c521942c8fb4.
"""
import difflib
import hashlib
import re
import sys

SRC = "docs/reporting/drafts/2026-10-08-report-first-draft.md"
OUT = "scratch/au_v060_fold_out.md"
LOG = "scratch/au_v060_fold.log"

ops = []


def op(tag, old, new):
    ops.append((tag, old, new))


# --- version ---
op("VER", "Draft v0.59. Date 2026-10-18.", "Draft v0.60. Date 2026-10-18.")

# --- the label names the third movement (science-writer line 1, aero
# condition: the record paragraph prints only if the label names it) ---
op(
    "LABEL",
    "instrument does, then the programme targets. No sentence in it cites a",
    "instrument does, the programme targets, and what the signed record\nshows. No sentence in it cites a",
)

# --- the capability pair, science-writer catches 2 and the taste fixes ---
op(
    "CAP",
    "Findings, corrections and retractions stay in the record with\ntheir lessons.\n\n"
    "The validated rung is the machine this report covers.",
    "Findings, corrections and retractions stay in the record with\ntheir lessons.\n\n"
    "The search already moves ten genes, so the same pipeline can probe wider\n"
    "parameter regimes. The expansion rotor model ships with tests, so the\n"
    "pipeline can study multi-rotor and expansion-class machines.\n\n"
    "The validated rung is the machine this report covers.",
)

# --- the seat marker, the target set and the record paragraph. The six-row
# count fix takes the count-free form (aero's recommendation), and the
# base-length noun is blessed. ---
op(
    "TARGETS",
    "above it is a programme target, not a result. No repo artifact backs the\n"
    "rungs.\n\n"
    "The programme takes one validation step at the Daisy scale.",
    "above it is a programme target, not a result. No repo artifact backs the\n"
    "rungs.\n\n"
    "[Figure seated: figure-map row 24 (scaling ladder, slug `scaling-ladder`).\n"
    "The rung set reads from the value-claims ledger section 4. No register\n"
    "row binds the plate.]\n\n"
    "Wider parameter regimes, flying higher on longer shafts, and the scale\n"
    "where multi-rotor machines win are programme targets too. The\n"
    "axial-length study runs to 60 m as a plan probe. That figure is not a\n"
    "signed row.\n\n"
    "The signed length screen varied length alone on one pre-fold genome.\n"
    "Every screened row read below the power floor. The folded class passed\n"
    "at the base length. The record sits in section 2.3.\n\n"
    "The programme takes one validation step at the Daisy scale.",
)

# --- the ninth provenance seat ---
op(
    "PROV",
    "One row per built exhibit. All eight read dataset commit `dd3cc6a`.\n\n"
    "| Exhibit | Source extract | Cited rows | Script commit | Era |",
    "One row per built exhibit. Eight read dataset commit `dd3cc6a`. The\n"
    "ladder reads the code rung set.\n\n"
    "| Exhibit | Source extract | Cited rows | Script commit | Era |",
)
op(
    "PROVROW",
    "| The corner machines | `corner-grid-extract-2026-10-15-picks` | NR-044, NR-051 | `a4b4057` | `post-95c385d_wind-authority` |\n",
    "| The corner machines | `corner-grid-extract-2026-10-15-picks` | NR-044, NR-051 | `a4b4057` | `post-95c385d_wind-authority` |\n"
    "| Scaling ladder | `scripts/compute_seeds.jl` const RUNGS · value-claims ledger section 4 | none | `4ebc385` | `post-95c385d_wind-authority` |\n",
)

# --- the ladder's hash block, read from the tree ---
L = "docs/reporting/figures/scaling-ladder/"
h = {}
for tag, f in [("png", "scaling-ladder.png"), ("svg", "scaling-ladder.svg"),
               ("pdf", "scaling-ladder.pdf"), ("ledger", "label-ledger.txt"),
               ("checks", "checks.log")]:
    h[tag] = hashlib.sha256(open(L + f, "rb").read()).hexdigest()

op(
    "HASHES",
    "- `checks` `8e0a042363ea5dcd1a1644c4583f01386c4601f67bf90e5d984ce4514c48b1d9`\n",
    "- `checks` `8e0a042363ea5dcd1a1644c4583f01386c4601f67bf90e5d984ce4514c48b1d9`\n"
    "\n"
    "Scaling ladder:\n\n"
    "- `png` `%s`\n- `svg` `%s`\n- `pdf` `%s`\n- `ledger` `%s`\n- `checks` `%s`\n"
    % (h["png"], h["svg"], h["pdf"], h["ledger"], h["checks"]),
)

src = open(SRC, encoding="utf-8").read()
text = src
log = ["# Author fold v0.60 — directions + ladder embed", "",
       "Base md5 `%s`" % hashlib.md5(src.encode()).hexdigest(), ""]

for tag, old, new in ops:
    n = text.count(old)
    log.append("%-8s matches=%d" % (tag, n))
    if n != 1:
        log.append("FAIL: %s expected 1 match, read %d" % (tag, n))
        open(LOG, "w").write("\n".join(log) + "\n")
        print("\n".join(log))
        sys.exit(1)
    text = text.replace(old, new)

open(OUT, "w", encoding="utf-8").write(text)

diff = list(difflib.unified_diff(src.splitlines(), text.splitlines(),
                                 "v0.59", "v0.60", lineterm="", n=1))
open("scratch/au_v060_fold.diff", "w", encoding="utf-8").write("\n".join(diff) + "\n")

# token census, hashes masked
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

# outside-the-close scan
scans = ["programme target", "MVP", "offshore", "network", "gigatonne",
         "p/kWh", "MWh", "gCO2", "\u00a3"]
cs = text.index("**Where this goes.**")
ce = text.index("## 6 Nomenclature")
outside = text[:cs] + text[ce:]
inside = text[cs:ce]
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
    "", "## Outside-the-close scan", "",
    "hits outside: " + (", ".join("%s x%d" % t for t in leaks) or "none"),
    "hits inside: " + ", ".join("%s x%d" % (s, inside.count(s)) for s in scans if inside.count(s)),
    "", "## Close paragraph census", ""]

for p in [x for x in inside.split("\n\n") if x.strip()]:
    pj = " ".join(x.strip() for x in p.splitlines())
    s = [x for x in re.split(r"(?<=[.!?])\s+", pj) if x]
    log.append("  para words=%-3d sentences=%d" % (len(pj.split()), len(s)))

open(LOG, "w", encoding="utf-8").write("\n".join(log) + "\n")
print("\n".join(log))

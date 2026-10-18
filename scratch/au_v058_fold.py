#!/usr/bin/env python3
"""Author fold v0.58: T3-6/T3-9/T3-3 prose fixes, T4-1/3/4/11/12/13, T4-14 appendix.

Every replacement asserts exactly one match. Anything else fails the run.
"""
import hashlib
import re
import sys

SRC = "docs/reporting/drafts/2026-10-08-report-first-draft.md"
OUT = "scratch/au_v058_fold_out.md"
LOG = "scratch/au_v058_fold.log"

ops = []


def op(tag, old, new):
    ops.append((tag, old, new))


# --- version line ---
op(
    "VER",
    "Internal engineering report. Draft v0.57. Date 2026-10-16.",
    "Internal engineering report. Draft v0.58. Date 2026-10-18.",
)


# --- T4-1: the missing 2.3 heading (NR-047 already points at section 2.3) ---
op(
    "T4-1",
    "A short window can sample the decay and misstate the power. The team\n"
    "sized the window to outlast the decay.\n"
    "\n"
    "The generator load follows a power law.",
    "A short window can sample the decay and misstate the power. The team\n"
    "sized the window to outlast the decay.\n"
    "\n"
    "### 2.3 The operating point and load selection\n"
    "\n"
    "The generator load follows a power law.",
)

# --- T3-9 (d): the gene noun. There is no tip-speed ratio gene. ---
op(
    "T3-9",
    "So the two genes are not independent: changing the radius with\n"
    "k held fixed moves the operating tip-speed ratio.",
    "So the radius gene and the operating tip-speed ratio are not\n"
    "independent: changing the radius with k held fixed moves that ratio.",
)

# --- T3-3 (e): name the denominator floor, not the clamp alone. ---
op(
    "T3-3",
    "(NR-046). The twist charge clamps r to one. At r equal to one the\n"
    "segment has crossed, so the ratio r over (1 minus r) would divide by\n"
    "zero. The clamp keeps the charge finite and continuous up to the crossing\n"
    "point (NR-046).",
    "(NR-046). The twist charge clamps r to one. At r equal to one the\n"
    "segment has crossed, so the ratio r over (1 minus r) would divide by\n"
    "zero. The code floors the denominator at 1e-6\n"
    "(src/objective_evaluator.jl:1207). The ratio reads one million at the\n"
    "limit and stays finite. The twist gate flags a segment that passes its\n"
    "limit, so a design at the limit exactly reaches the floor (NR-046).",
)

# --- T3-6 (a) and (b): the axial share is the zero, and the tension is net. ---
op(
    "T3-6",
    "R5 carries pure axial tension, not no load. Its interaction share reads\n"
    "zero and its utilisation reads tiny, so the factor of safety reads far\n"
    "above the others (NR-021).",
    "R5 carries net axial tension, not no load (NR-060). Its axial share reads\n"
    "zero and its utilisation reads tiny, so the factor of safety reads far\n"
    "above the others (NR-021).",
)

# --- T4-3: the polygon count name. NR-011, NR-044 and the atlas read n_lines. ---
op("T4-3", "the number of lines (n_Lines)", "the number of lines (n_lines)")

# --- T4-4: the draft-status note. Sections 1 to 5 are populated. ---
op(
    "T4-4",
    "**Draft status.** This is an internal draft.\n"
    "Sections 3.4 to 3.6 carry their text.",
    "**Draft status.** This is an internal draft.\n"
    "Sections 1 to 5 carry their text.",
)

# --- T4-11: sentence case on the 3.4 heading. ---
op("T4-11", "### 3.4 The levers of Performance", "### 3.4 The levers of performance")

# --- T4-12: compound form in prose. The path strings keep their spelling. ---
op("T4-12", "The rotorcount data was doubly void", "The rotor-count data was doubly void")

# --- T4-13: NR-036 carries the gen-0 figure the improvement claim quotes. ---
op(
    "T4-13",
    "It reads 36.109 to 27.364 kg-equivalent. | \u00a73.2 | NR-003 to NR-006 |",
    "It reads 36.109 to 27.364 kg-equivalent. | \u00a73.2 | NR-003 to NR-006, NR-036 |",
)

# --- T4-14: the appendix. Header rule, then every file the kit carries. ---
OLD_HEADER = """**Output hashes (SHA-256).** The short labels name the exhibit files.
`png`, `svg` and `pdf` are the file types. `ledger` is the label
ledger. `checks` is the check log.
"""
NEW_HEADER = """**Output hashes (SHA-256).** The short labels name the exhibit files.
`png`, `svg` and `pdf` are the file types. `ledger` is the label
ledger. `checks` is the check log.

An exhibit lists a file type only where its route produces one. The
system anatomy plate renders from TeX to PDF to PNG, so it carries no
`svg`. An exhibit lists `ledger`, `checks`, or both, as its kit carries
them.
"""

F = "docs/reporting/figures/"


def h(path):
    with open(path, "rb") as fh:
        return hashlib.sha256(fh.read()).hexdigest()


# exhibit label -> (folder, ordered list of (tag, file))
EXHIBITS = [
    ("Ring utilisation plate", "ring-utilisation",
     [("png", "{d}.png"), ("svg", "{d}.svg"), ("pdf", "{d}.pdf"), ("ledger", "label-ledger.txt")]),
    ("Twist limit plate", "twist-limit",
     [("png", "{d}.png"), ("svg", "{d}.svg"), ("pdf", "{d}.pdf"), ("ledger", "label-ledger.txt")]),
    ("Machine evolution strip", "machine-evolution-strip",
     [("png", "{d}.png"), ("svg", "{d}.svg"), ("pdf", "{d}.pdf"), ("checks", "checks.log")]),
    ("System anatomy plate", "system-anatomy",
     [("png", "{d}.png"), ("pdf", "{d}.pdf"), ("ledger", "label-ledger.txt"), ("checks", "checks.log")]),
    ("Levers landscape", "pca-landscape",
     [("png", "{d}.png"), ("svg", "{d}.svg"), ("pdf", "{d}.pdf"), ("ledger", "label-ledger.txt"),
      ("checks", "checks.log")]),
    ("Parameter atlas", "pca-atlas",
     [("png", "{d}.png"), ("svg", "{d}.svg"), ("pdf", "{d}.pdf"), ("ledger", "label-ledger.txt"),
      ("checks", "checks.log")]),
    ("Machine winner", "machine-winner-hero",
     [("png", "{d}.png"), ("svg", "{d}.svg"), ("pdf", "{d}.pdf"), ("checks", "checks.log")]),
    ("The corner machines", "machine-corner-grid",
     [("png", "{d}.png"), ("svg", "{d}.svg"), ("pdf", "{d}.pdf"), ("checks", "checks.log")]),
]

blocks = []
hash_rows = []
for label, folder, items in EXHIBITS:
    lines = [label + ":", ""]
    for tag, tpl in items:
        name = tpl.format(d=folder)
        path = F + folder + "/" + name
        digest = h(path)
        lines.append("- `%s` `%s`" % (tag, digest))
        hash_rows.append((label, tag, digest, path))
    blocks.append("\n".join(lines))

NEW_BODY = NEW_HEADER + "\n" + "\n\n".join(blocks) + "\n"

# The old body runs from the header to just before the closing line after
# "The corner machines" block. Anchor on the header and the last old hash.
OLD_TAIL = "- `checks` `e6bcfca931d36089dd2a8d6e9c8414fb49230c0d2110717176cf1e0ae385ffbe`"
src = open(SRC, encoding="utf-8").read()
start = src.index(OLD_HEADER)
end = src.index(OLD_TAIL) + len(OLD_TAIL)
OLD_BODY = src[start:end]
op("T4-14", OLD_BODY, NEW_BODY.rstrip("\n"))

# --- apply ---
text = src
log = ["# Author fold v0.58 — T3/T4 prose and appendix", "",
       "Base `docs/reporting/drafts/2026-10-08-report-first-draft.md`",
       "base md5 `%s`" % hashlib.md5(src.encode()).hexdigest(), ""]

for tag, old, new in ops:
    n = text.count(old)
    log.append("%-7s matches=%d" % (tag, n))
    if n != 1:
        log.append("FAIL: %s expected exactly 1 match, read %d" % (tag, n))
        open(LOG, "w").write("\n".join(log) + "\n")
        print("\n".join(log))
        sys.exit(1)
    text = text.replace(old, new)

open(OUT, "w", encoding="utf-8").write(text)

# --- diff ---
import difflib
base_lines = src.splitlines()
out_lines = text.splitlines()
diff = list(difflib.unified_diff(base_lines, out_lines, "base", "v0.58", lineterm="", n=1))
added = sum(1 for l in diff if l.startswith("+") and not l.startswith("+++"))
removed = sum(1 for l in diff if l.startswith("-") and not l.startswith("---"))

log += ["", "old lines %d, new lines %d, words %d to %d" % (
    len(base_lines), len(out_lines), len(src.split()), len(text.split())),
    "diff hunks %d, added %d, removed %d" % (
        sum(1 for l in diff if l.startswith("@@")), added, removed),
    "", "output md5 `%s`" % hashlib.md5(text.encode()).hexdigest(), ""]

# --- declared token diff ---
TOKEN = re.compile(r"NR-\d+|\d[\d,\.]*e?-?\d*|\bn_Lines\b|\bn_lines\b")
HEX64 = re.compile(r"\b[0-9a-f]{64}\b")


def toks(s):
    """Token census. Hash digests carry no claim, so they mask to <HASH>."""
    return TOKEN.findall(HEX64.sub("<HASH>", s))


base_tok = {}
out_tok = {}
for t in toks(src):
    base_tok[t] = base_tok.get(t, 0) + 1
for t in toks(text):
    out_tok[t] = out_tok.get(t, 0) + 1
gained = {k: v - base_tok.get(k, 0) for k, v in out_tok.items() if v > base_tok.get(k, 0)}
lost = {k: base_tok[k] - out_tok.get(k, 0) for k in base_tok if base_tok[k] > out_tok.get(k, 0)}
log += ["## Declared token diff", "",
        "gained: " + (", ".join("%s x%d" % (k, v) for k, v in sorted(gained.items())) or "none"),
        "lost:   " + (", ".join("%s x%d" % (k, v) for k, v in sorted(lost.items())) or "none"),
        ""]

open("scratch/au_v058_fold.diff", "w", encoding="utf-8").write("\n".join(diff) + "\n")
open(LOG, "w", encoding="utf-8").write("\n".join(log) + "\n")
print("\n".join(log))
print("\n--- diff ---")
print("\n".join(diff))

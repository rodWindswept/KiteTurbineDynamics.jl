"""v0.18 pass receipt - token-diff and STE-count assertions for the section 12 tables.

Author seat, 2026-10-12. Run from the repo root:
  python3 scratch/au_v018_token_check.py

Checks:
1. The draft token diff (HEAD against the working file) equals the intended set.
   Removals read {17} (the header digit). Additions read the table values plus
   the header digit 18. The pattern matches the draft-consistency-sweep pattern
   ((?<![\\w-])\\d+(?:\\.\\d+)?(?![\\w-])), so identifiers and dates stay out.
2. The STE counts hold at the v0.17 baseline: total 4, passive_voice 1,
   long_paragraph(>6s) 3.

Expected addition set (every key maps to a named edit):
  18      header bump, v0.17 to v0.18
  table 1 (section 2.4, campaign configuration):
          3, 310, 930, 5.0, 2.5, 10, 40, 2.24, 18.8
  table 2 (section 3.3, winner operating point):
          5.309, 5.314, 14.972, 0.029, 10.170, 13.38, 396.76, 25.698,
          4.580, 0.804, 6 x2 (ring count and ring 6), 3, 1, 7.088, 70, 324.1
  table 3 (section 3.3, gate summary):
          5.0, 2.5, 5.309, 14.972
"""
import collections
import re
import subprocess
import sys

DRAFT = "docs/reporting/drafts/2026-10-08-report-first-draft.md"
PAT = re.compile(r'(?<![\w-])\d+(?:\.\d+)?(?![\w-])')

EXPECTED_REMOVED = {"17": 1}
EXPECTED_ADDED = {
    "0.029": 1, "0.804": 1, "1": 1, "10": 1, "10.170": 1, "13.38": 1,
    "14.972": 2, "18": 1, "18.8": 1, "2.24": 1, "2.5": 2, "25.698": 1,
    "3": 2, "310": 1, "324.1": 1, "396.76": 1, "4.580": 1, "40": 1,
    "5.0": 2, "5.309": 2, "5.314": 1, "6": 2, "7.088": 1, "70": 1, "930": 1,
}


def tokens(text):
    return collections.Counter(PAT.findall(text))


def main():
    old = subprocess.run(
        ["git", "show", "HEAD:" + DRAFT], capture_output=True, text=True, check=True
    ).stdout
    with open(DRAFT, encoding="utf-8") as handle:
        new = handle.read()
    a, b = tokens(old), tokens(new)
    removed = {k: v for k, v in (a - b).items()}
    added = {k: v for k, v in (b - a).items()}
    if removed != EXPECTED_REMOVED or added != EXPECTED_ADDED:
        print("TOKEN DIFF MISMATCH")
        print("removed:", dict(sorted(removed.items())))
        print("added:", dict(sorted(added.items())))
        sys.exit(1)
    print(
        "token diff: OK - removed",
        removed,
        "| added",
        len(added),
        "keys,",
        sum(added.values()),
        "occurrences",
    )

    lint = subprocess.run(
        ["python3", "ste-lint.py", "--fail-above", "2.0", DRAFT],
        capture_output=True,
        text=True,
    )
    out = lint.stdout + lint.stderr
    total_m = re.search(r"total=\s*(\d+)", out)
    passive_m = re.search(r"passive_voice x(\d+)", out)
    long_m = re.search(r"long_paragraph\(>6s\) x(\d+)", out)
    total = int(total_m.group(1)) if total_m else -1
    passive = int(passive_m.group(1)) if passive_m else 0
    longp = int(long_m.group(1)) if long_m else 0
    if total != 4 or passive != 1 or longp != 3:
        print("LINT MISMATCH:", total, passive, longp)
        sys.exit(1)
    print("lint: OK - total 4 (passive_voice 1, long_paragraph 3), baseline holds")
    print("v0.18 receipt checks pass")


if __name__ == "__main__":
    main()

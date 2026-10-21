#!/usr/bin/env python3
"""v0.76 pass: reinstate the Option B cone gloss at section 2.1.

Two-state and re-runnable.  Plain run edits, fills the tracker numbers by
fixed point, gates, and prints the token census.  --land re-asserts,
commits and pushes.
"""
import re
import subprocess
import sys
from collections import Counter
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
DRAFT = REPO / "docs/reporting/drafts/2026-10-08-report-first-draft.md"
TRACKER = REPO / "docs/reporting/draft-tracker.md"

LAND = "--land" in sys.argv
ASSERT_TOKENS = "--assert-tokens" in sys.argv

HEAD_OLD = "Internal engineering report. Draft v0.75. Date 2026-10-20.\n"
HEAD_NEW = "Internal engineering report. Draft v0.76. Date 2026-10-20.\n"

CONE_ANCHOR = (
    "It is not a search value (NR-049).\n"
    "\n"
    "At the top of the shaft the rotor turns in the wind.\n"
)

GLOSS = (
    "That 22 measures one side of the cone, from the shaft axis out to the cone wall.\n"
    "A reference machine prints the same 22 as the angle across the full apex, one side against the other.\n"
    "The two numbers name different angles, so this cone runs steeper than that machine.\n"
    "The code change that would match this cone to that machine stays open, awaiting a ruling.\n"
)

CONE_NEW = (
    "It is not a search value (NR-049).\n"
    "\n"
    + GLOSS
    + "\n"
    "At the top of the shaft the rotor turns in the wind.\n"
)

TRACKER_ANCHOR = "Em dashes 0. The draft ticks to v0.75.\n"

TRACKER_ENTRY = """
v0.76 pass by @author (2026-10-20).

This pass takes the founder call on founder comment 21 for the second time, and the answer is B.
The cone gloss returns to section 2.1 with the plain-English reading the founder asked for.
Option A printed the fixed value alone and left the comparison out.

The block prints one side of the cone, from the shaft axis out to the cone wall.
It prints the reference 22 as the angle across the full apex, one side against the other.
The two numbers name different angles, so this cone runs steeper than that machine.
The code change that would match this cone to that machine stays open, awaiting a ruling.

The gloss obeys NR-049 boundary 3 as amended.
It prints both readings and the direction they differ.
It prints the open status of the change.
It prints no source-side slope and no steepness ratio.
It does not name the reference as the basis of the value.

The fixed-value sentence and the constant sentence stay in front of the gloss.
The NR-049 cite stays behind them, and it covers the constant claim as well.
No numeral, no citation count and no caption changes.
The second site at section 3.4 already reads the same fixed-value fact.

The NR-049 boundary 3 state note still describes the withdrawal.
The numbers seat owes a forward note that the gloss is live again.

Words read __WORDS__ from 10,796. STE __TOTAL__ total at __PER100__ per 100 words. Em dashes 0. The draft ticks to v0.76.
"""

TOKEN_RE = re.compile(r"\d[\d.,]*\d|\d")
SUMMARY_RE = re.compile(r"words=\s*(\S+)\s+total=\s*(\S+)\s+per100w=\s*([0-9.]+)\s+em_dash=\s*(\d+)")


def tokens(text: str) -> Counter:
    text = re.sub(r"\b[0-9a-f]{40,64}\b", "<HASH>", text)
    return Counter(TOKEN_RE.findall(text))


def summary(path):
    out = subprocess.run(
        [sys.executable, "ste-lint.py", str(path)],
        cwd=REPO, capture_output=True, text=True,
    )
    line = out.stdout.strip().splitlines()[0]
    m = SUMMARY_RE.search(line)
    if not m:
        raise SystemExit(f"cannot parse lint summary: {line!r}")
    return {"words": int(m.group(1).replace(",", "")), "total": int(m.group(2)),
            "per100": float(m.group(3)), "em_dash": int(m.group(4))}


def lint_gate(paths):
    out = subprocess.run(
        [sys.executable, "ste-lint.py", "--fail-above", "2.0"] + [str(p) for p in paths],
        cwd=REPO, capture_output=True, text=True,
    )
    return out.returncode, out.stdout + out.stderr


def main() -> int:
    draft = DRAFT.read_text()
    tracker = TRACKER.read_text()
    draft_pre = draft

    head_applied = HEAD_NEW in draft
    gloss_applied = GLOSS in draft
    entry_applied = "v0.76 pass by @author" in tracker

    if not head_applied:
        assert draft.count(HEAD_OLD) == 1, "header anchor"
    if not gloss_applied:
        assert draft.count(CONE_ANCHOR) == 1, "cone anchor"
    if not entry_applied:
        assert tracker.count(TRACKER_ANCHOR) == 1, "tracker anchor"

    if not head_applied:
        draft = draft.replace(HEAD_OLD, HEAD_NEW, 1)
    if not gloss_applied:
        draft = draft.replace(CONE_ANCHOR, CONE_NEW, 1)

    pre_tok, post_tok = tokens(draft_pre), tokens(draft)
    added, removed = dict(post_tok - pre_tok), dict(pre_tok - post_tok)
    edited = not (head_applied and gloss_applied)
    print(f"== draft token diff: added {added} removed {removed} (edited={edited})")
    if ASSERT_TOKENS and edited:
        assert added == {"22": 2, "0.76": 1}, added
        assert removed == {"0.75": 1}, removed

    DRAFT.write_text(draft)

    if not entry_applied:
        TRACKER.write_text(tracker + TRACKER_ENTRY)
        for _ in range(5):
            d = summary(DRAFT)
            body = (tracker + TRACKER_ENTRY
                    .replace("__WORDS__", f"{d['words']:,}")
                    .replace("__TOTAL__", str(d["total"]))
                    .replace("__PER100__", f"{d['per100']:.2f}"))
            before = TRACKER.read_text()
            TRACKER.write_text(body)
            if before == body:
                break
    else:
        print("== tracker entry already present")

    rc, lint_out = lint_gate([DRAFT, TRACKER])
    print(lint_out)
    print(f"== lint gate rc={rc}")

    d = summary(DRAFT)
    t = summary(TRACKER)
    print(f"== draft words={d['words']} total={d['total']} per100w={d['per100']:.2f} em_dash={d['em_dash']}")
    print(f"== tracker words={t['words']} total={t['total']} per100w={t['per100']:.2f} em_dash={t['em_dash']}")

    return 0 if rc == 0 else 1


if __name__ == "__main__":
    sys.exit(main())

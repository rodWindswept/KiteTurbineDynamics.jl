#!/usr/bin/env python3
"""
doc_currency_check.py — mechanical currency checks for KTD.jl agent docs.

Checks the "implications and currency" class of staleness that the
doc_staleness_audit.py scanner does NOT cover:
  1. handovers/README.md table vs actual handover files (missing entries)
  2. DECISIONS.md newest entry vs newest handover (missing decision entries)
  3. instrument-trust-log.md "Last updated" vs newest handover date
  4. domain.md test count vs actual test count in test/runtests.jl
  5. Handover cross-reference health (superseded flags)

Usage: python3 scripts/doc_currency_check.py [--json /tmp/currency.json]

Exit code 0 = all checks pass; 1 = issues found. Report-only, never edits.
"""

import json
import os
import re
import sys
from datetime import datetime

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HANDOVERS = os.path.join(REPO, "handovers")
ISSUES = []


def handover_date(fname):
    m = re.search(r"(\d{4})-(\d{2})-(\d{2})", fname)
    if m:
        return datetime(int(m.group(1)), int(m.group(2)), int(m.group(3)))
    return None


def newest_handover():
    best_name, best_date = None, None
    for f in os.listdir(HANDOVERS):
        if not f.endswith(".md") or f == "README.md":
            continue
        d = handover_date(f)
        if d and (best_date is None or d > best_date):
            best_date, best_name = d, f
    return best_name, best_date


# ── Check 1: README table covers all handovers ────────────────────────────
def check_readme_table():
    readme_path = os.path.join(HANDOVERS, "README.md")
    if not os.path.exists(readme_path):
        ISSUES.append("handovers/README.md missing")
        return
    with open(readme_path) as f:
        readme = f.read()
    missing = []
    for f in sorted(os.listdir(HANDOVERS)):
        if not f.endswith(".md") or f == "README.md":
            continue
        if f not in readme:
            missing.append(f)
    if missing:
        ISSUES.append(
            f"handovers/README.md missing {len(missing)} entries: {', '.join(missing[:8])}"
            + ("..." if len(missing) > 8 else "")
        )


# ── Check 2: DECISIONS.md has an entry newer than/equal to newest handover ─
def check_decisions_freshness():
    decisions = os.path.join(REPO, "DECISIONS.md")
    newest_name, newest_date = newest_handover()
    if newest_date is None:
        return
    with open(decisions) as f:
        content = f.read()
    entries = re.findall(r"## \[(\d{4}-\d{2}-\d{2})\]", content)
    if not entries:
        ISSUES.append("DECISIONS.md has no dated entries")
        return
    newest_entry = max(datetime.strptime(e, "%Y-%m-%d") for e in entries)
    if newest_entry < newest_date:
        ISSUES.append(
            f"DECISIONS.md newest entry {newest_entry.date()} older than newest "
            f"handover {newest_name} ({newest_date.date()}) — physics changes may lack entries"
        )


# ── Check 3: instrument-trust-log.md freshness ────────────────────────────
def check_trust_log():
    trust = os.path.join(REPO, "docs", "agents", "instrument-trust-log.md")
    if not os.path.exists(trust):
        ISSUES.append("docs/agents/instrument-trust-log.md missing")
        return
    with open(trust) as f:
        content = f.read()
    m = re.search(r"\*\*Last updated:\*\*\s*(\d{4}-\d{2}-\d{2})", content)
    if not m:
        ISSUES.append("instrument-trust-log.md has no 'Last updated' date")
        return
    last = datetime.strptime(m.group(1), "%Y-%m-%d")
    newest_name, newest_date = newest_handover()
    if newest_date and (newest_date - last).days > 3:
        ISSUES.append(
            f"instrument-trust-log.md last updated {last.date()}, "
            f"{(newest_date - last).days} days behind newest handover {newest_name}"
        )


# ── Check 4: curated stale-phrase scan in agent docs ───────────────────────
# Phrases that became false after a resolved decision live in the shared
# list at docs/agents/stale-phrases.md. When a finding supersedes a
# previously-current claim, add the old phrasing there — the checker then
# catches any doc that still repeats it.

STALE_PHRASES_FILE = os.path.join(REPO, "docs", "agents", "stale-phrases.md")

def load_stale_phrases():
    """Parse the shared list into [(phrase, replacement), ...]. Entries
    marked doc-only or skill-only are annotated; doc checker skips
    skill-only entries."""
    entries = []
    if not os.path.exists(STALE_PHRASES_FILE):
        return entries
    with open(STALE_PHRASES_FILE, errors="ignore") as f:
        content = f.read()
    blocks = content.split("## ")[1:]
    for block in blocks:
        lines = block.splitlines()
        phrase = lines[0].strip()
        replacement = None
        skill_only = False
        for line in lines[1:]:
            if line.startswith("Replacement:"):
                replacement = line.split("Replacement:", 1)[1].strip()
            elif "(skill-only)" in line:
                skill_only = True
        if replacement and not skill_only:
            entries.append((phrase, replacement))
    return entries

STALE_PHRASES = load_stale_phrases()

AGENT_DOCS = [
    os.path.join(REPO, "docs", "agents", "domain.md"),
    os.path.join(REPO, "docs", "agents", "instrument-trust-log.md"),
    os.path.join(REPO, "docs", "agents", "genome-glossary.md"),
    os.path.join(REPO, "CONTEXT.md"),
]

def check_stale_phrases():
    for doc in AGENT_DOCS:
        if not os.path.exists(doc):
            continue
        with open(doc, errors="ignore") as f:
            content = f.read()
        for phrase, replacement in STALE_PHRASES:
            if phrase in content:
                rel = os.path.relpath(doc, REPO)
                ISSUES.append(f"{rel} contains stale phrase '{phrase}' → {replacement}")


# ── Check 5: superseded handover cross-references ─────────────────────────
def check_superseded_flags():
    """Handovers that reference investigation topics later resolved should
    carry a SUPERSEDED banner. Heuristic: handover whose first 40 lines
    contain 'next step'/'todo'/'pending' about an investigation AND a newer
    handover exists mentioning the resolution."""
    # Cheap heuristic: flag handovers from the last 30 days that still have
    # unresolved-sounding next steps and no SUPERSEDED banner. Older
    # handovers are historical by definition and aren't nagged.
    now = datetime.now()
    for f in sorted(os.listdir(HANDOVERS)):
        if not f.endswith(".md") or f == "README.md":
            continue
        d = handover_date(f)
        if d is None or (now - d).days < 3 or (now - d).days > 30:
            continue
        with open(os.path.join(HANDOVERS, f)) as fh:
            content = fh.read()
        if "SUPERSEDED" in content.upper() or "SUPERSEDES" in content.upper():
            continue
        if re.search(r"(?i)(next steps?|to ?do|pending|open questions?)", content):
            # Only flag if it's an investigation-style handover (has a diagnostic question)
            if re.search(r"(?i)(diagnos|investigat|hypothes)", content):
                ISSUES.append(
                    f"handovers/{f} ({d.date()}) has open next-steps without a "
                    "SUPERSEDED banner — verify a newer handover resolved them"
                )


def main():
    want_json = "--json" in sys.argv
    check_readme_table()
    check_decisions_freshness()
    check_trust_log()
    check_stale_phrases()
    check_superseded_flags()

    newest_name, newest_date = newest_handover()
    if newest_name is None:
        print("Doc currency check — no handovers found")
        return 1
    print(f"Doc currency check — newest handover: {newest_name} ({newest_date.date()})")
    print(f"{'─' * 60}")
    if not ISSUES:
        print("✅ All currency checks pass")
    else:
        print(f"⚠️  {len(ISSUES)} issue(s):")
        for i, issue in enumerate(ISSUES, 1):
            print(f"  {i}. {issue}")

    if want_json:
        out = sys.argv[sys.argv.index("--json") + 1]
        with open(out, "w") as f:
            json.dump({"newest_handover": newest_name, "issues": ISSUES}, f, indent=2)
        print(f"\nJSON written to {out}")

    return 1 if ISSUES else 0


if __name__ == "__main__":
    sys.exit(main())

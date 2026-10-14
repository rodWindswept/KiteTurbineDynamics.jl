#!/usr/bin/env python3
"""Register-seat draft check: trace a report draft's citations against the numbers register.

Usage:
    python3 check_draft_citations.py <draft.md> [<register.md>]

The mechanical half of the register-seat prose review (SKILL.md rule 24):
  1. every NR-### row ID cited in the draft, sorted;
  2. with a register given: cited rows that are missing or unsigned (exit 1),
     plus signed rows the draft does not cite (informational);
  3. every digit-bearing line of the draft, for the value-by-value eyeball pass —
     every quoted value should carry its row ID; dates, commit pins, internal
     references and section numbers are exempt. Naming the items that are still
     without rows (the open list) stays a judgment call.

Certification note: run this on the revision the set was DELIVERED at (name the tip,
`git status --short -- <files>` empty) — an earlier pass may predate artifact movement.

Exit codes: 0 = clean or no register given; 1 = a cited row is missing/unsigned; 2 = usage.
"""
import re
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2

    draft_path = Path(sys.argv[1])
    text = draft_path.read_text()
    refs = sorted(set(re.findall(r"NR-\d+", text)), key=lambda r: int(r.split("-", 1)[1]))
    print(f"== cited rows in {draft_path.name}: {len(refs)}")
    print("   " + (", ".join(refs) if refs else "(none cited)"))

    rc = 0
    if len(sys.argv) > 2:
        reg_text = Path(sys.argv[2]).read_text()
        signed = set()
        for line in reg_text.splitlines():
            m = re.match(r"\|\s*(NR-\d+)\b", line.strip())
            if m and re.search(r"(?<!un)signed", line, re.IGNORECASE):
                signed.add(m.group(1))
        if not signed:
            print("!! no signed register rows parsed — check the path and the row format")
            rc = 1
        missing = [r for r in refs if r not in signed]
        if missing:
            print("!! cited but missing/unsigned in the register:")
            for r in missing:
                print(f"   {r}")
            rc = 1
        else:
            print(f"== every cited row present and signed ({len(signed)} signed rows total)")
        uncited = sorted(signed - set(refs), key=lambda r: int(r.split("-", 1)[1]))
        if uncited:
            print("== signed rows not cited by this draft (informational): " + ", ".join(uncited))

    print("== digit-bearing lines (eyeball pass — every value should carry its row ID):")
    for i, line in enumerate(text.splitlines(), 1):
        if re.search(r"\d", line):
            print(f"{i:4}| {line.rstrip()}")

    return rc


if __name__ == "__main__":
    sys.exit(main())

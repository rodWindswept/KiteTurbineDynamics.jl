#!/usr/bin/env python3
# check-tdd-evidence.py — deterministic sensor: a src/ change without a test change.
# Version: 0.1.0 | Date: 2026-09-24 | Author: Windswept & Interesting
#
# Fires [HOOK:tdd] when a staged src/ file changes and no staged test/ file
# changes with it. The cue points at the RED step and the test list.
#
# WARN by default, so the commit proceeds. Pass --block to make it exit 1.
# The sensor cannot see whether a failing test was watched; it only asks that a
# test moved with the code. A pure refactor, a comment fix or a docs-only change
# to src/ is a legitimate false positive: say so in the commit body, or bypass
# with `git commit --no-verify`.
import sys

SRC_PREFIXES = ("src/", "scripts/")
TEST_PREFIX = "test/"

FIX = ("staged src change with no test change -> observe a failing test first: "
       "scripts/ktd-test-one <name>, then log the row in docs/plans/test_list.md "
       "(ktd-test-suite-maintenance)")


def main(argv):
    block = "--block" in argv
    paths = [a for a in argv if not a.startswith("--")]

    src = [p for p in paths if p.endswith(".jl") and p.startswith(SRC_PREFIXES)]
    tests = [p for p in paths if p.startswith(TEST_PREFIX)]

    if src and not tests:
        print(f"[HOOK:tdd] {', '.join(src)}: {FIX}")
        return 1 if block else 0
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

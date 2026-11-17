#!/usr/bin/env python3
"""One command that answers: are the plates send-ready at this commit?

Seat: figures. Written 2026-11-17 so the fold does not hand-check four tools
in four shapes. Each one answers a different question about the same ten
plates, and each fails on its own arrow:

1. ``check_appendix_pins.py``   manifest -> appendix pin and rows cell
2. ``check_plate_bytes.py``     bytes on disk -> manifest (the seats a build
                                embeds, read from the draft's own markers)
3. ``check_plate_footers.py``   what the plates print, in rows, era tags and
                                commit-like tokens, with the appendix sets
                                compared one exhibit at a time

Exit 0 = every arrow holds. Exit 1 = at least one fails, and the failing
tool's own output is printed.

By default the footer counts are reported, not judged, because the plates we
ship today still print 55 row ids. ``--footer-rule`` turns the counts into the
acceptance line the drawn layer of gate 2 needs: zero rows, zero era tags,
zero tokens on the seated plates. That switch must exit 0 only after the
footer pass lands, and it is the one command a send reads.

Usage:
    python3 scripts/check_plates_send_ready.py [--draft PATH]
    python3 scripts/check_plates_send_ready.py --footer-rule

Read the exit code from the direct call. Piped through tail it reports the
status of tail.
"""
import argparse
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPTS = os.path.join(ROOT, "scripts")
DEFAULT_DRAFT = os.path.join(
    ROOT, "docs/reporting/drafts/2026-10-08-report-first-draft.md")

SEAT_RE = re.compile(
    r"\[Figure seated:\s*(?:figure-map row\s+(?P<row>\d+))?.*?slug `(?P<slug>[a-z0-9_-]+)`.*?\]",
    re.DOTALL,
)


def run(name, cmd):
    """Run one gate and return (ok, tail of its output)."""
    proc = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)
    tail = (proc.stdout or "").strip().splitlines()[-6:]
    if proc.returncode != 0:
        tail += (proc.stderr or "").strip().splitlines()[-4:]
    return proc.returncode == 0, tail


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--draft", default=DEFAULT_DRAFT)
    ap.add_argument("--footer-rule", action="store_true",
                    help="judge the footer counts at zero instead of reporting them")
    args = ap.parse_args()

    draft = os.path.join(ROOT, args.draft)
    with open(draft, encoding="utf-8") as fh:
        seats = list(dict.fromkeys(m.group("slug") for m in SEAT_RE.finditer(fh.read())))
    if not seats:
        print("check_plates_send_ready: no seated figure found in the draft - "
              "refusing to pass", file=sys.stderr)
        return 1
    slugs = ",".join(seats)

    py = sys.executable
    plan = [
        ("pins", "manifest -> appendix pin and rows cell",
         [py, os.path.join(SCRIPTS, "check_appendix_pins.py"), "--draft", draft]),
        ("bytes", f"bytes -> manifest, {len(seats)} seated kits",
         [py, os.path.join(SCRIPTS, "check_plate_bytes.py"),
          "--worktree", "--slugs", slugs, "-q"]),
        ("footers", "what the plates print, and the appendix sets",
         [py, os.path.join(SCRIPTS, "check_plate_footers.py"),
          "--slugs", slugs]
         + ([] if args.footer_rule else ["--appendix", draft])),
    ]
    if args.footer_rule:
        plan[2][2].extend(["--max-rows", "0", "--max-era", "0", "--max-hashes", "0"])

    failed = []
    for key, label, cmd in plan:
        ok, tail = run(key, cmd)
        print(f"{'PASS' if ok else 'FAIL'}  {key:8s} {label}")
        for line in tail:
            print(f"      {line}")
        if not ok:
            failed.append(key)

    print(f"\n{len(plan) - len(failed)} of {len(plan)} arrows hold at "
          f"{os.path.relpath(draft, ROOT)}"
          + (f"; failed: {', '.join(failed)}" if failed else "")
          + ("" if args.footer_rule else
             " (footer counts reported, not judged: pass --footer-rule to judge)"))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Fail if a figure kit manifest names bytes that are not the bytes at a commit.

Seat: figures. Written 2026-10-20, the missing first link in the chain the
author's ``check_appendix_pins.py --fix`` completes from the other end:

    plate bytes -> manifest -> appendix pin

The pin check tests manifest -> pin. Nothing tested bytes -> manifest, so a
stale or wrong manifest could pass both the pin fix and the build gate,
because both read the same record. This script tests the record itself.

For every ``docs/reporting/figures/*/manifest.json`` it checks three things:

1. every recorded output hash equals the blob at ``--rev`` (default HEAD);
2. the script at the recorded commit — the ``script_commit`` field, or the pin
   carried in the build ``command`` as ``--script-commit <hash>`` — hashes to
   the recorded ``script.sha256``;
3. every recorded input hash equals the blob at ``--rev``. An input that
   carries ``section`` and ``section_sha256`` is hashed over that section of
   the file only, so a plate bound to one section is not reported stale every
   time an unrelated section of the same document is edited.

Usage:
    python3 scripts/check_plate_bytes.py [--rev REV] [-q]
    python3 scripts/check_plate_bytes.py --git-show PATH

``--git-show`` prints the blob hash of one path at ``--rev`` and exits; it is
the one-liner form used when a manifest needs re-pinning after a deliberate
append to a file that is itself an output.

Exit 0 = every recorded hash resolves, and at least one kit was found.
Exit 1 = a stale or missing hash, an unreadable manifest, or no kits found.

There is no --fix, and that is deliberate. The pin column can be rewritten from
the manifests because both sides derive from the same record; an output hash
cannot, because the manifest is the record of the drawing. Rewriting it from
whatever is on disk would let a re-cut plate re-stamp itself without anyone
re-deriving the claims the plate draws. A stale hash here is a question to
answer in the kit, not a token to update.
"""
import argparse
import glob
import hashlib
import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FIG = os.path.join(ROOT, "docs/reporting/figures")

INPUT_FIELDS = ("inputs", "extract", "extracts", "capture", "captures")

HEADING_RE = re.compile(r"^## (.+)$", re.M)


def blob(rev, path):
    """Return the bytes of ``path`` at ``rev``, or None when it is absent."""
    res = subprocess.run(["git", "-C", ROOT, "show", f"{rev}:{path}"],
                         capture_output=True)
    return res.stdout if res.returncode == 0 else None


def section_bytes(data, number):
    """Slice the ``## <number>.`` section out of a markdown blob."""
    text = data.decode("utf-8")
    heads = list(HEADING_RE.finditer(text))
    start = None
    for i, h in enumerate(heads):
        if h.group(1).split(".")[0].strip() == str(number):
            start = h.start()
            end = heads[i + 1].start() if i + 1 < len(heads) else len(text)
            return text[start:end].encode("utf-8")
    del start
    return None


def script_commit(man):
    commit = man.get("script_commit")
    if commit:
        return commit
    hit = re.search(r"--script-commit ([0-9a-f]{7,40})", man.get("command", ""))
    return hit.group(1) if hit else None


def file_records(obj):
    """Yield every {path, sha256|section_sha256} record nested in ``obj``."""
    if isinstance(obj, dict):
        if isinstance(obj.get("path"), str) and (
                obj.get("sha256") or obj.get("section_sha256")):
            yield obj
        for value in obj.values():
            yield from file_records(value)
    elif isinstance(obj, list):
        for value in obj:
            yield from file_records(value)


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--rev", default="HEAD", help="commit to read the bytes at (default HEAD)")
    ap.add_argument("-q", "--quiet", action="store_true", help="print only failures")
    ap.add_argument("--git-show", metavar="PATH",
                    help="print the blob hash of PATH at --rev and exit")
    args = ap.parse_args()

    if subprocess.run(["git", "-C", ROOT, "rev-parse", "--verify", args.rev],
                      capture_output=True).returncode != 0:
        print(f"check_plate_bytes: no such revision {args.rev}", file=sys.stderr)
        return 1

    if args.git_show:
        data = blob(args.rev, args.git_show)
        if data is None:
            print(f"check_plate_bytes: no {args.git_show} at {args.rev}", file=sys.stderr)
            return 1
        print(hashlib.sha256(data).hexdigest())
        return 0

    manifests = sorted(glob.glob(os.path.join(FIG, "*", "manifest.json")))
    if not manifests:
        print("check_plate_bytes: no manifests found — refusing to pass", file=sys.stderr)
        return 1

    total = passed = bad = 0
    lines = []
    for path in manifests:
        kit = os.path.dirname(path)
        slug = os.path.basename(kit)
        rel_kit = os.path.relpath(kit, ROOT)
        try:
            with open(path) as fh:
                man = json.load(fh)
        except (OSError, ValueError) as err:
            bad += 1
            lines.append(f"UNREADABLE  {slug:26s} {err}")
            continue

        checks = []  # (label, expected, actual, kind)
        for name, want in (man.get("outputs") or {}).items():
            got = blob(args.rev, f"{rel_kit}/{name}")
            checks.append((name, want,
                           hashlib.sha256(got).hexdigest() if got is not None else None,
                           "OUT"))

        script = man.get("script") or {}
        s_path, s_want = script.get("path"), script.get("sha256")
        commit = script_commit(man)
        if s_path and s_want:
            if commit is None:
                checks.append((s_path, s_want, None, "SCRIPT-NOPIN"))
            else:
                got = blob(commit, s_path)
                checks.append((f"{s_path}@{commit}", s_want,
                               hashlib.sha256(got).hexdigest() if got is not None else None,
                               "SCRIPT"))

        for field in INPUT_FIELDS:
            for rec in file_records(man.get(field)):
                p = rec["path"]
                data = blob(args.rev, p)
                if rec.get("section_sha256") and rec.get("section") is not None:
                    label = f"{p}#{rec['section']}"
                    want = rec["section_sha256"]
                    sliced = section_bytes(data, rec["section"]) if data is not None else None
                    got = hashlib.sha256(sliced).hexdigest() if sliced is not None else None
                else:
                    label = p
                    want = rec.get("sha256")
                    got = hashlib.sha256(data).hexdigest() if data is not None else None
                checks.append((label, want, got, "IN"))

        total += len(checks)
        kit_bad = [c for c in checks if c[1] != c[2]]
        passed += len(checks) - len(kit_bad)
        bad += len(kit_bad)
        if kit_bad:
            for label, want, got, kind in kit_bad:
                state = "MISSING" if got is None else f"{got[:12]}… wants {want[:12]}…"
                lines.append(f"STALE       {slug:26s} {kind:12s} {label}  {state}")
        elif not args.quiet:
            lines.append(f"PASS        {slug:26s} {len(checks)} hash(es) at {args.rev}")

    for line in lines:
        print(line)
    print(f"\n{passed}/{total} recorded hashes verify at {args.rev} across {len(manifests)} kits")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())

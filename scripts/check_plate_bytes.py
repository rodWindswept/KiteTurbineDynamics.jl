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
2. the script at the recorded commit — the ``script_commit`` field, the pin
   carried in the build ``command`` as ``--script-commit <hash>``, or a capture
   gallery's ``run_commit`` — hashes to the recorded ``script.sha256``;
3. every recorded input hash equals the blob at ``--rev``.

A section-bound input is the one refinement, and it is a stricter test rather
than a looser one. When a record names the ``section`` of a document it reads
and the whole file has since moved, this script finds the commit that holds
the recorded bytes, slices the named section out of that blob and out of
``--rev``, and compares the two. Equal sections pass and print as SECTION with
the commit it found. Different sections fail. A file that moved in the part
this plate reads is a stale plate; a file that moved elsewhere is not, and the
manifest said so by recording a section.

Usage:
    python3 scripts/check_plate_bytes.py [--rev REV] [-q]
    python3 scripts/check_plate_bytes.py --worktree [--slugs a,b] [-q]
    python3 scripts/check_plate_bytes.py --git-show PATH

``--worktree`` hashes the files on disk instead of the blobs at ``--rev``,
because a build embeds the worktree: ``build_draft_pdf.py`` and
``build_draft_docx.py`` call this script that way, scoped by ``--slugs`` to
the seats the build is about to embed. HEAD mode stays the default for the
standalone audit, where the question is what the record claims about a commit.

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

PROV_HEAD_RE = re.compile(r"^## .*provenance.*$", re.M | re.I)

HISTORY_LIMIT = 200


TREE = False  # set by --worktree: hash the files the build will embed, not HEAD


def worktree_bytes(path):
    """The bytes of ``path`` on disk, or None when it is absent."""
    try:
        with open(os.path.join(ROOT, path), "rb") as fh:
            return fh.read()
    except OSError:
        return None


def git_blob(rev, path):
    """Return the bytes of ``path`` at ``rev``, or None when it is absent."""
    res = subprocess.run(["git", "-C", ROOT, "show", f"{rev}:{path}"],
                         capture_output=True)
    return res.stdout if res.returncode == 0 else None


def blob(rev, path):
    """Bytes of ``path``: the worktree when TREE, else the blob at ``rev``.

    A build embeds the bytes on disk, so the gate that guards it has to read
    the same bytes. HEAD mode stays the default for the standalone audit,
    where the question is what the record claims about a commit.
    """
    if TREE and rev in ("HEAD", "WORKTREE"):
        data = worktree_bytes(path)
        if data is not None:
            return data
    return git_blob(rev, path)


def history(path, limit=HISTORY_LIMIT):
    """Commits that touched ``path``, newest first."""
    res = subprocess.run(["git", "-C", ROOT, "log", "--format=%H", "--", path],
                         capture_output=True, text=True)
    return res.stdout.split()[:limit]


def commit_holding(path, want):
    """Find the newest commit whose ``path`` blob hashes to ``want``."""
    for rev in history(path):
        data = blob(rev, path)
        if data is not None and hashlib.sha256(data).hexdigest() == want:
            return rev, data
    return None, None


def input_bytes(rev, rel_kit, path):
    """Bytes for an input record: repo-relative first, then kit-relative.

    Kits record input paths both ways. A capture gallery records its paths
    relative to its own folder, so reading those against the repo root
    reported three present files as MISSING.
    """
    data = blob(rev, path)
    if data is not None:
        return data
    return blob(rev, f"{rel_kit}/{path}")


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
    """The commit the manifest says drew the plate, in any of three shapes.

    A ``script_commit`` field, a ``--script-commit`` argument in the build
    command, or a capture gallery's ``run_commit``, which names the pass whose
    tree holds every frame at the hash the stamp records. Reading only the
    first two shapes reported the two gallery kits as unpinned when the pin
    gate had read them correctly all along.
    """
    commit = man.get("script_commit")
    if commit:
        return commit
    hit = re.search(r"--script-commit ([0-9a-f]{7,40})", man.get("command", ""))
    if hit:
        return hit.group(1)
    return man.get("run_commit")


def caption_provenance(data):
    """The provenance section of a captions.md blob, or None when it makes no claim."""
    if data is None:
        return None
    text = data.decode("utf-8")
    head = PROV_HEAD_RE.search(text)
    if not head:
        return None
    rest = text[head.end():]
    nxt = re.search(r"^## ", rest, re.M)
    return rest[:nxt.start()] if nxt else rest


def prov_script_pin(prov):
    """The backticked commit in the provenance block that names the script.

    Anchored on the word order the captions actually print. The old form took
    the first backticked hex in any interpunct segment holding "script", which
    read a line-per-claim block as one segment and returned the data commit:
    a false stale pin on every kit that prints its provenance one claim per
    line.
    """
    hit = re.search(r"script commit[^`\n]{0,40}`([0-9a-f]{7,40})`", prov, re.I)
    if hit:
        return hit.group(1)
    hit = re.search(r"script:[^`\n]{0,200}?at[^`\n]{0,40}`([0-9a-f]{7,40})`",
                    prov, re.I)
    if hit:
        return hit.group(1)
    for seg in prov.split("\u00b7"):
        if "script" not in seg.lower():
            continue
        hit = re.search(r"script[^0-9a-f]{0,80}`([0-9a-f]{7,40})`", seg, re.I)
        if hit:
            return hit.group(1)
    return None


def prov_rows(prov):
    """The register rows the provenance line claims, or None when it names none.

    Ranges print in the captions as ``NR-078 to NR-082``, so a range expands
    to its members before the set compare. Reading the notation blind reported
    a row-set disagreement on a kit whose manifest carried every member.
    """
    hit = re.search(r"rows:? ([^\n\u00b7]*)", prov)
    if not hit:
        return None
    span = hit.group(1)
    rows = set(re.findall(r"NR-\d+", span))
    for lo, hi in re.findall(r"NR-(\d+)\s*(?:to|\u2013|-)\s*(?:NR-)?(\d+)", span):
        a, b = int(lo), int(hi)
        if a <= b and b - a < 100:
            rows.update(f"NR-{n:03d}" for n in range(a, b + 1))
    return rows


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
    global TREE
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--rev", default="HEAD", help="commit to read the bytes at (default HEAD)")
    ap.add_argument("--worktree", action="store_true",
                    help="hash the files on disk, which is what a build embeds, "
                         "instead of the blobs at --rev")
    ap.add_argument("--slugs", metavar="LIST",
                    help="comma-separated kit slugs to check; default is every kit")
    ap.add_argument("-q", "--quiet", action="store_true", help="print only failures")
    ap.add_argument("--git-show", metavar="PATH",
                    help="print the blob hash of PATH at --rev and exit")
    args = ap.parse_args()
    TREE = bool(args.worktree)

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
    if args.slugs:
        want = [s.strip() for s in args.slugs.split(",") if s.strip()]
        have = {os.path.basename(os.path.dirname(m)) for m in manifests}
        missing = [s for s in want if s not in have]
        if missing:
            print(f"check_plate_bytes: no manifest for {', '.join(missing)}",
                  file=sys.stderr)
            return 1
        manifests = [m for m in manifests if os.path.basename(os.path.dirname(m)) in set(want)]

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
        notes = []
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

        prov = caption_provenance(blob(args.rev, f"{rel_kit}/captions.md"))
        if prov:
            pin = prov_script_pin(prov)
            if pin and commit:
                checks.append(("captions.md script pin", commit[:7], pin[:7], "CAP"))
            claimed = prov_rows(prov)
            if claimed is not None:
                recorded = set()
                for item in (man.get("registers")
                             or (man.get("inputs") or {}).get("register_rows") or []):
                    recorded.update(re.findall(r"NR-\d+", str(item)))
                checks.append(("captions.md row set",
                               ",".join(sorted(recorded)) or "-",
                               ",".join(sorted(claimed)) or "-", "CAP"))

        for field in INPUT_FIELDS:
            for rec in file_records(man.get(field)):
                p = rec["path"]
                data = input_bytes(args.rev, rel_kit, p)
                section = rec.get("section")
                if rec.get("section_sha256") and section is not None:
                    label = f"{p}#{section}"
                    want = rec["section_sha256"]
                    sliced = section_bytes(data, section) if data is not None else None
                    got = hashlib.sha256(sliced).hexdigest() if sliced is not None else None
                    checks.append((label, want, got, "IN"))
                    continue
                want = rec.get("sha256")
                got = hashlib.sha256(data).hexdigest() if data is not None else None
                if want and got != want and section is not None:
                    found, old = commit_holding(p, want)
                    old_sec = section_bytes(old, section) if old is not None else None
                    new_sec = section_bytes(data, section) if data is not None else None
                    if old_sec is not None and old_sec == new_sec:
                        checks.append((f"{p}#{section}", got, got, "SECTION"))
                        notes.append(f"            {p} moved to {got[:12]}…; section "
                                     f"{section} identical to {found[:7]}")
                        continue
                    if found is not None:
                        checks.append((f"{p}#{section}", want, got, "IN"))
                        notes.append(f"            section {section} differs from "
                                     f"{found[:7]}; this plate reads moved bytes")
                        continue
                    notes.append(f"            no commit holds {want[:12]}… for {p}")
                checks.append((p, want, got, "IN"))

        total += len(checks)
        kit_bad = [c for c in checks if c[1] != c[2]]
        passed += len(checks) - len(kit_bad)
        bad += len(kit_bad)
        if kit_bad:
            for label, want, got, kind in kit_bad:
                state = "MISSING" if got is None else f"{got[:12]}… wants {want[:12]}…"
                lines.append(f"STALE       {slug:26s} {kind:12s} {label}  {state}")
            lines.extend(notes)
        elif not args.quiet:
            lines.append(f"PASS        {slug:26s} {len(checks)} hash(es) at {args.rev}")
            lines.extend(notes)

    for line in lines:
        print(line)
    print(f"\n{passed}/{total} recorded hashes verify at {args.rev} across {len(manifests)} kits")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())

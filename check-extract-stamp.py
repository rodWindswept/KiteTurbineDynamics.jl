#!/usr/bin/env python3
# check-extract-stamp.py — deterministic sensor: sweep stale-phrase extracts
# must be byte-identical to the source rev whose stamp records them.
# Version: 0.1.0 | Date: 2026-10-19 | Author: Windswept & Interesting
#
# Fires [HOOK:extract] when a reserved copy is staged and cannot be matched to
# docs/agents/stale-phrases.md at the revision its stamp line names.
#
# All reads come from the index (git show :path), never the working tree: a
# staged copy must be the bytes that get committed, and the stamp must be the
# staged one, or the gate validates the wrong artifact.
#
# Rules:
#   - An absent copy is not a violation: before the first sweep neither file
#     exists and the gate must pass.
#   - A staged copy with no stamp line is a violation (fail closed).
#   - A stamp naming a missing revision is a violation (shallow clone, rebase).
#   - A copy matching HEAD's source but not its stamped rev was generated from
#     a dirty tree: stale-tree refusal, not a tamper record.
#   - Any other mismatch is a tamper record.
# Exit 0 = clean, 1 = hooks fired.
import hashlib
import subprocess
import sys

STAMP = "scratch/sw_extract_stamp.txt"
COPIES = {
    "base": "scratch/sw_stale_phrases_base.md",
    "tip": "scratch/sw_stale_phrases_tip.md",
}
SOURCE = "docs/agents/stale-phrases.md"


def git(*args):
    return subprocess.run(["git", *args], capture_output=True)


def index_blob(path):
    """Bytes of path as staged, or None when the path is absent from the index."""
    res = git("show", ":%s" % path)
    return res.stdout if res.returncode == 0 else None


def rev_blob(rev, path):
    res = git("show", "%s:%s" % (rev, path))
    return res.stdout if res.returncode == 0 else None


def md5(data):
    return hashlib.md5(data).hexdigest()


def staged_paths():
    res = git("diff", "--cached", "--name-only", "--diff-filter=ACM")
    return [p for p in res.stdout.decode("utf-8", "replace").splitlines() if p]


def read_stamp():
    """Parse the staged stamp file into {role: (rev, md5)}."""
    blob = index_blob(STAMP)
    if blob is None:
        return {}, [], set()
    errors = []
    entries = {}
    seen = set()
    text = blob.decode("utf-8", "replace")
    if text and not text.endswith("\n"):
        errors.append("%s: no trailing newline (rewrite the stamp with two LF lines)" % STAMP)
    lines = [ln for ln in text.split("\n") if ln.strip()]
    if len(lines) != len(COPIES):
        errors.append("%s: expected %d lines, found %d" % (STAMP, len(COPIES), len(lines)))
    for ln in lines:
        parts = ln.split()
        if len(parts) != 3:
            errors.append("%s: malformed line %r (want '<base|tip> <rev> <md5>')" % (STAMP, ln))
            continue
        role, rev, digest = parts
        if role not in COPIES:
            errors.append("%s: unknown role %r (want one of %s)" % (STAMP, role, ", ".join(sorted(COPIES))))
            continue
        seen.add(role)
        if role in entries:
            errors.append("%s: duplicate role %r" % (STAMP, role))
            continue
        if len(digest) != 32 or any(c not in "0123456789abcdef" for c in digest):
            errors.append("%s: %s line md5 %r is not 32 lowercase hex" % (STAMP, role, digest))
            continue
        entries[role] = (rev, digest)
    return entries, errors, seen


def main():
    staged = staged_paths()
    watched = set(COPIES.values()) | {STAMP, SOURCE}
    if not watched & set(staged):
        return 0

    entries, errors, seen = read_stamp()
    dirty_ref = None  # HEAD's source bytes, fetched only when a mismatch needs it

    for role, path in sorted(COPIES.items()):
        blob = index_blob(path)
        if blob is None:
            continue  # absent copy: pre-sweep or not part of this commit
        if role not in entries:
            if role in seen:
                errors.append("%s: staged but its '%s' line in %s is unusable (see error above)" % (path, role, STAMP))
            else:
                errors.append("%s: staged with no '%s' line in %s (fail closed)" % (path, role, STAMP))
            continue
        rev, recorded = entries[role]
        actual = md5(blob)
        if actual != recorded:
            errors.append("%s: index md5 %s does not match stamp %s" % (path, actual, recorded))
            continue
        src = rev_blob(rev, SOURCE)
        if src is None:
            errors.append("%s: stamp rev %s is missing from this clone (fail closed)" % (path, rev))
            continue
        if md5(src) == actual:
            continue
        if dirty_ref is None:
            dirty_ref = rev_blob("HEAD", SOURCE) or b""
        if actual == md5(dirty_ref):
            errors.append(
                "%s: matches HEAD source, not stamped rev %s — generated from a dirty tree; "
                "regenerate with git show %s:%s" % (path, rev, rev, SOURCE)
            )
        else:
            errors.append(
                "%s: matches neither stamped rev %s nor HEAD — hand-edited transcript" % (path, rev)
            )

    for err in errors:
        print("[HOOK:extract] %s" % err)
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""
kwarg_default_audit.py — flag undocumented numeric default values in Julia
function signatures, struct fields, and named-tuple literals: the surface where
unanchored "magic numbers" actually live in KiteTurbineDynamics.jl.

Motivation (2026-07-22): the `const` surface is already well documented
(docstrings + block comments). But the two numbers that cost days this week —
`lin_damp=0.05` and `bearing_tr_damp=0.99994` — were *default kwarg values in
function signatures*, which no `const`-grep can surface. This scanner targets
that surface instead. See docs/agents/instrument-trust-log.md.

FLAGS an indented `name[::Type] = <numeric literal>,` line (KTD's one-per-line
signature style; also struct fields / named-tuple entries) that has NO
justifying comment — trailing `#`, or a `#`/docstring line within 3 lines above
(skipping sibling field lines so a shared block comment counts).

DANGER classes:
  HIGH — (a) per-step-multiplier / time-constant NAMES (damp|smooth|decay|
         retain|relax|tau|blend|filter|ease) with a float default, OR
         (b) any float default in [0.9, 1.0) — the near-unity per-step
         retention signature of the dt-unscaled-operator bug class.
  MED  — any other undocumented numeric default in src/.

Usage:
  python3 scripts/kwarg_default_audit.py           # report
  python3 scripts/kwarg_default_audit.py --check   # exit 1 if any HIGH undocumented

Self-test (positive control): asserts it flags the known initialization.jl
offenders; warns loudly if they've vanished (file moved / regex rotted) — the
same "instrument must prove it can see the signal" discipline as Gate 1.

Rerunnable in ~1s. Same audit family as the doc-staleness and duplicate-physics
scanners; safe to put on the weekly cron.
"""
import os
import re
import sys
import subprocess

DANGER_NAMES = re.compile(r'(damp|smooth|decay|retain|relax|tau|blend|filter|ease)', re.I)

# Indented `name[::Type] = <number>` with optional trailing comma / comment.
# Requiring EITHER a ::Type OR a trailing comma biases toward signature kwargs,
# struct fields, and named-tuple entries — and away from in-body assignments
# (which rarely carry a type or a trailing comma). That keeps signal high.
KW = re.compile(
    r'^(\s+)([A-Za-z_]\w*)\s*(::[^=,]+?)?\s*=\s*'
    r'([-+]?\d[\d._eEfx]*)\s*(,)?\s*(#.*)?$'
)

# (name, value) pairs confirmed justified elsewhere. Keep MINIMAL.
# lin_damp / bearing_tr_damp are deliberately NOT here — they stay flagged until
# their trust-log "Unanchored Parameters" entries are closed with a calibration.
ALLOWLIST = set()

# Positive control: the scanner MUST find these, or it is broken.
POSITIVE_CONTROL = [("lin_damp", "initialization.jl"),
                    ("bearing_tr_damp", "initialization.jl")]


def repo_root():
    return os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def git_hash(root):
    try:
        return subprocess.check_output(
            ['git', '-C', root, 'rev-parse', '--short', 'HEAD'],
            stderr=subprocess.DEVNULL).decode().strip()
    except Exception:
        return 'unknown'


def documented(lines, i, inline_comment):
    if inline_comment:
        return True
    # Scan up to 3 non-blank lines above; a sibling kwarg/field line is skipped
    # so a shared block comment sitting above a cluster still counts.
    seen = 0
    j = i - 1
    while j >= 0 and seen < 4:
        s = lines[j].strip()
        if not s:
            j -= 1
            continue
        seen += 1
        if s.startswith('#') or s.startswith('"""') or s.endswith('"""'):
            return True
        if KW.match(lines[j]):      # sibling field/kwarg — keep looking up
            j -= 1
            continue
        return False                 # hit real code with no comment
    return False


def classify(name, value):
    is_float = ('.' in value) or ('e' in value.lower())
    if is_float:
        if DANGER_NAMES.search(name):
            return 'HIGH'
        try:
            v = float(value.rstrip('f'))
            if 0.9 <= abs(v) < 1.0:   # near-unity per-step retention signature
                return 'HIGH'
        except ValueError:
            pass
    return 'MED'


def scan(root):
    hits = []
    src = os.path.join(root, 'src')
    for dp, _, fns in os.walk(src):
        for fn in sorted(fns):
            if not fn.endswith('.jl'):
                continue
            path = os.path.join(dp, fn)
            lines = open(path, encoding='utf-8', errors='replace').read().splitlines()
            for i, ln in enumerate(lines):
                if ln.lstrip().startswith('const '):   # const surface handled elsewhere
                    continue
                m = KW.match(ln)
                if not m:
                    continue
                _, name, typ, value, comma, inline_c = m.groups()
                if not (typ or comma):                 # require type or trailing comma
                    continue
                if (name, value) in ALLOWLIST:
                    continue
                if documented(lines, i, inline_c):
                    continue
                hits.append((os.path.relpath(path, root), i + 1, name, value,
                             classify(name, value)))
    return hits


def main():
    root = repo_root()
    hits = scan(root)
    check = '--check' in sys.argv

    # Positive control
    names_files = {(n, os.path.basename(f)) for f, _, n, _, _ in hits}
    missing_pc = [pc for pc in POSITIVE_CONTROL if pc not in names_files]
    if missing_pc:
        sys.stderr.write(
            "⚠ POSITIVE CONTROL FAILED — scanner did not flag %s. "
            "Regex may have rotted or files moved; do NOT trust a clean report.\n"
            % ", ".join("%s(%s)" % pc for pc in missing_pc))

    high = [h for h in hits if h[4] == 'HIGH']
    med = [h for h in hits if h[4] == 'MED']

    print("# kwarg-default audit — git=%s  root=%s" % (git_hash(root), root))
    print("# %d undocumented numeric defaults: %d HIGH, %d MED\n"
          % (len(hits), len(high), len(med)))
    for tag, group in (("HIGH", high), ("MED", med)):
        if not group:
            continue
        print("== %s ==" % tag)
        for f, ln, name, val, _ in group:
            print("  %-40s %-22s = %-10s  (%s:%d)" % (name, "", val, f, ln))
        print()

    if check and (high or missing_pc):
        sys.exit(1)


if __name__ == "__main__":
    main()

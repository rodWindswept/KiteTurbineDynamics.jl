#!/usr/bin/env python3
"""
skill_currency_check.py — scan Hermes skills for KTD stale phrases.

Reads the shared stale-phrase list at
<KTD repo>/docs/agents/stale-phrases.md (INCLUDING skill-only entries) and
scans ~/.hermes/skills/**/SKILL.md for each phrase. Skills that still
contain a superseded claim are flagged with the skill name, file path,
and the recommended fix (add SUPERSEDED banner or rewrite the section).

Usage: python3 skill_currency_check.py [--ktd-only] [--json /tmp/s.json]

Exit 0 = no stale phrases found; 1 = flags. Report-only, never edits.
"""

import json
import os
import sys

HOME = os.path.expanduser("~")
SKILLS_ROOT = os.path.join(HOME, ".hermes", "skills")

DEFAULT_KTD_REPO = os.path.join(HOME, "Documents", "GitHub", "KiteTurbineDynamics.jl")


def load_stale_phrases(repo):
    """Parse the shared list into [(phrase, replacement), ...].
    Includes skill-only entries (skills are exactly where they apply)."""
    entries = []
    path = os.path.join(repo, "docs", "agents", "stale-phrases.md")
    if not os.path.exists(path):
        return entries
    with open(path, errors="ignore") as f:
        content = f.read()
    for block in content.split("## ")[1:]:
        lines = block.splitlines()
        phrase = lines[0].strip()
        replacement = None
        for line in lines[1:]:
            if line.startswith("Replacement:"):
                replacement = line.split("Replacement:", 1)[1].strip()
        if replacement:
            entries.append((phrase, replacement))
    return entries


def find_skill_files():
    """Yield (skill_name, path) for every SKILL.md under the skills root."""
    for root, dirs, files in os.walk(SKILLS_ROOT):
        for fname in files:
            if fname == "SKILL.md":
                rel = os.path.relpath(root, SKILLS_ROOT)
                skill_name = rel.replace(os.sep, "/")
                yield skill_name, os.path.join(root, fname)


def strip_banner_context(content):
    """Remove superseded-banner blocks and strikethrough text so the scanner
    doesn't flag skills that CORRECTLY document the supersession.
    - `~~struck through~~` segments are removed
    - Any contiguous blockquote block (lines starting with '>') that contains
      'SUPERSEDED' or a physics-era marker ('ζ-ERA', 'PRE-Ζ') is removed
      wholesale — the whole block documents the supersession."""
    import re
    # Remove strikethrough spans first
    content = re.sub(r"~~.+?~~", " ", content, flags=re.DOTALL)
    lines = content.splitlines()
    out = []
    i = 0
    while i < len(lines):
        line = lines[i]
        if line.startswith(">"):
            # Collect the contiguous blockquote block
            block = [line]
            j = i + 1
            while j < len(lines) and lines[j].startswith(">"):
                block.append(lines[j])
                j += 1
            block_text = "\n".join(block).upper()
            if "SUPERSEDED" in block_text or "Ζ-ERA" in block_text or "PRE-Ζ" in block_text:
                i = j  # skip the whole block
                continue
            out.extend(block)
            i = j
        else:
            out.append(line)
            i += 1
    return "\n".join(out)


def main():
    args = sys.argv[1:]
    ktd_only = "--ktd-only" in args
    want_json = "--json" in args

    repo = DEFAULT_KTD_REPO
    phrases = load_stale_phrases(repo)
    if not phrases:
        print("No stale phrases loaded — is docs/agents/stale-phrases.md present?")
        return 1

    flags = []
    skill_count = 0
    for skill_name, path in find_skill_files():
        skill_count += 1
        if ktd_only and "ktd" not in skill_name.lower() and "windswept" not in skill_name.lower():
            continue
        with open(path, errors="ignore") as f:
            raw = f.read()
        content = strip_banner_context(raw)
        for phrase, replacement in phrases:
            if phrase in content:
                # Grab one context line for the semantic pass
                line_no = None
                for i, line in enumerate(content.splitlines()):
                    if phrase in line:
                        line_no = i + 1
                        break
                flags.append((skill_name, phrase, replacement, line_no))

    print(f"Skill currency check — {len(phrases)} stale phrases, "
          f"{skill_count} skills scanned")
    print("─" * 60)
    if not flags:
        print("✅ No skills contain stale phrases (outside SUPERSEDED banners)")
    else:
        print(f"⚠️  {len(flags)} candidate stale phrase(s) in skills:")
        for skill_name, phrase, replacement, line_no in flags:
            print(f"  • {skill_name}:{line_no} '{phrase}'")
            print(f"    → {replacement}")

    if want_json:
        out = args[args.index("--json") + 1]
        with open(out, "w") as f:
            json.dump([{"skill": s, "phrase": p, "replacement": r, "line": n}
                       for s, p, r, n in flags], f, indent=2)
        print(f"\nJSON written to {out}")

    return 1 if flags else 0


if __name__ == "__main__":
    sys.exit(main())

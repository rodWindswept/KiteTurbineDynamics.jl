#!/usr/bin/env python3
"""Documentation staleness audit: heuristic classification + doc-vs-code git lag ranking.

Usage:
    python3 scripts/doc_staleness_audit.py [--json PATH] [--top N]

Scans every *.md in the repo and reports:
  1. Heuristic durability classification (durable / ephemeral / claims-bearing / dead)
  2. Staleness lag: docs whose referenced .jl files have newer git dates than the doc
  3. Broken code references (doc cites a .jl path that no longer exists)
  4. Geometry-claim flags (n_lines=12 / 12-gon) and a scored verification shortlist

First run + methodology: docs/reports/2026-07-18-doc-staleness-audit.md

CAVEATS (learned on the first run — read before acting on output):
  * "Broken ref" does NOT distinguish citing-as-live from documenting-a-deletion.
    A DECISIONS.md entry saying "X.jl was deleted (git rm)" is correct history,
    not a broken ref. Read the context before "fixing" anything.
  * Classification is heuristic (~90%). It judges by path/filename convention,
    not content. Read files before archiving/deleting — always.
  * Artifact-loss conclusions need `git log -- <path>` / `git show <rev>:<path>`,
    not just working-tree checks (the V6.2 best_design.json was recoverable
    from history despite being overwritten at HEAD).
  * Dirty/untracked files are dated by mtime, not commit date.
"""
import argparse
import json
import math
import os
import re
import subprocess
import time
from collections import defaultdict


def run(cmd, cwd=None):
    return subprocess.run(cmd, capture_output=True, text=True, cwd=cwd).stdout


def main():
    ap = argparse.ArgumentParser(description=(__doc__ or "").splitlines()[0])
    ap.add_argument("--json", help="write full per-file records to this path")
    ap.add_argument("--top", type=int, default=25, help="rows in lag table (default 25)")
    args = ap.parse_args()

    root = run(["git", "rev-parse", "--show-toplevel"]).strip() or os.getcwd()
    os.chdir(root)

    # ---- last-commit timestamp map for ALL tracked files (one pass over history)
    last_commit = {}
    cur = None
    for line in run(["git", "log", "--format=\x01%ct", "--name-only"]).splitlines():
        if line.startswith("\x01"):
            cur = int(line[1:])
        elif line.strip():
            f = line.strip()
            if f not in last_commit:
                last_commit[f] = cur

    # ---- working-tree state: modified/untracked files use mtime (they're current)
    dirty = set()
    for line in run(["git", "status", "--porcelain"]).splitlines():
        if len(line) > 3:
            dirty.add(line[3:].strip().strip('"'))

    def fdate(path):
        if path in dirty or path not in last_commit:
            try:
                return os.path.getmtime(path)
            except OSError:
                return None
        return last_commit.get(path)

    # ---- gather all md files and all julia files
    md_files, jl_files = [], set()
    basename_map = defaultdict(list)
    for dirpath, dirnames, filenames in os.walk("."):
        dirnames[:] = [d for d in dirnames if d not in (".git", "node_modules")]
        for fn in filenames:
            p = os.path.normpath(os.path.join(dirpath, fn))
            if fn.endswith(".md"):
                md_files.append(p)
            elif fn.endswith(".jl"):
                jl_files.add(p)
                basename_map[fn].append(p)
    md_files.sort()

    DURABLE_EXACT = {"CONTEXT.md", "DECISIONS.md", "AGENTS.md", "CLAUDE.md",
                     "CONTRIBUTING.md", "CHANGELOG.md", "README.md", "PROJECT_ROOM.md"}
    DATED = re.compile(r"\d{4}-\d{2}-\d{2}")
    EPHEMERAL_NAMES = re.compile(
        r"(handover|plan|spec|prd|tracker|todo|recap|restart|wayfinder|case-note)", re.I)

    def classify(p):
        if p.startswith(("backup_conflicts_pull/", "docs/archive/", ".scratch/", ".hermes/")):
            return "dead"
        if p in DURABLE_EXACT or p.startswith(("docs/adr/", "docs/agents/")):
            return "durable"
        if p.startswith(("docs/plans/", "handovers/", "docs/wayfinder-tickets/",
                         "docs/prd/", "docs/superpowers/", "docs/case-notes/",
                         "docs/porto-2026/")):
            return "ephemeral"
        if p.startswith(("docs/reports/", "docs/outreach/", "references/",
                         "scripts/results/", "docs/awes-forum-diagrams/",
                         "docs/community/", "docs/validation/", "docs/src/")):
            return "claims"
        base = os.path.basename(p)
        if DATED.search(base) or EPHEMERAL_NAMES.search(base):
            return "ephemeral"
        if p.startswith(("docs/", "scripts/")):
            return "claims"
        return "ephemeral"

    REF_RE = re.compile(r"(?:src|scripts|test|examples)/[A-Za-z0-9_\-/]+\.jl")
    BARE_RE = re.compile(r"\b([A-Za-z][A-Za-z0-9_]{3,})\.jl\b")
    GEOM_RE = re.compile(r"n_lines\s*=\s*12|12-gon|dodecagon", re.I)

    records = []
    for md in md_files:
        try:
            text = open(md, encoding="utf-8", errors="replace").read()
        except OSError:
            continue
        refs = set(REF_RE.findall(text))
        for m in BARE_RE.finditer(text):
            bn = m.group(1) + ".jl"
            if len(basename_map.get(bn, [])) == 1:
                refs.add(basename_map[bn][0])
        refs = {os.path.normpath(r) for r in refs}
        existing = {r for r in refs if r in jl_files}
        broken = refs - existing
        doc_ts = fdate(md)
        code_ts = max((fdate(r) or 0) for r in existing) if existing else None
        lag = (code_ts - doc_ts) / 86400.0 if (doc_ts and code_ts and code_ts > doc_ts) else 0.0
        records.append({
            "path": md, "class": classify(md), "lines": text.count("\n") + 1,
            "n_refs": len(refs), "n_broken": len(broken), "broken": sorted(broken)[:6],
            "doc_date": time.strftime("%Y-%m-%d", time.localtime(doc_ts)) if doc_ts else None,
            "code_date": time.strftime("%Y-%m-%d", time.localtime(code_ts)) if code_ts else None,
            "lag_days": round(lag, 1),
            "geom_claim": bool(GEOM_RE.search(text)),
        })

    by_class = defaultdict(lambda: [0, 0])
    for r in records:
        by_class[r["class"]][0] += 1
        by_class[r["class"]][1] += r["lines"]

    print(f"repo: {root} @ {run(['git', 'rev-parse', '--short', 'HEAD']).strip()}")
    print(f"date: {time.strftime('%Y-%m-%d %H:%M')}\n")
    print("=== CLASS SUMMARY (files, lines) ===")
    for c in ("durable", "ephemeral", "claims", "dead"):
        n, ln = by_class[c]
        print(f"  {c:10s} {n:4d} files  {ln:6d} lines")

    live = [r for r in records if r["class"] != "dead"]
    brk = sorted([r for r in live if r["n_broken"] > 0], key=lambda r: -r["n_broken"])
    print("\n=== BROKEN CODE REFS (live docs; check context — may document a deletion) ===")
    print(f"  {len(brk)} docs, {sum(r['n_broken'] for r in brk)} refs total")
    for r in brk[:15]:
        print(f"  {r['n_broken']:3d} broken  [{r['class']:9s}] {r['path']}  e.g. {r['broken'][:2]}")

    top = sorted([r for r in live if r["lag_days"] > 0], key=lambda r: -r["lag_days"])
    print(f"\n=== TOP {args.top} STALENESS LAG (code newer than doc, live docs only) ===")
    print(f"  {len(top)} live docs have code newer than doc")
    for r in top[:args.top]:
        g = " GEOM" if r["geom_claim"] else ""
        print(f"  lag {r['lag_days']:6.1f}d  doc {r['doc_date']} code {r['code_date']}"
              f"  refs {r['n_refs']:2d}  [{r['class']:9s}]{g}  {r['path']}")

    def score(r):
        s = r["lag_days"] * math.log(1 + r["n_refs"] + r["n_broken"])
        return s + (300 if r["geom_claim"] else 0) + (50 if r["class"] == "claims" else 0)

    short = sorted([r for r in live if r["class"] == "claims"
                    and (r["lag_days"] > 0 or r["geom_claim"] or r["n_broken"] > 0)],
                   key=lambda r: -score(r))
    print("\n=== VERIFICATION SHORTLIST (claims-bearing, scored; verify per verify-model-claims skill) ===")
    for r in short[:15]:
        print(f"  score {score(r):7.1f}  lag {r['lag_days']:6.1f}d  refs {r['n_refs']:2d}"
              f" broken {r['n_broken']}  geom={r['geom_claim']}  {r['path']}")

    if args.json:
        json.dump(records, open(args.json, "w"), indent=1)
        print(f"\nfull records -> {args.json}")


if __name__ == "__main__":
    main()

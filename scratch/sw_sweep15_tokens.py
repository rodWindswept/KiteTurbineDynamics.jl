#!/usr/bin/env python3
"""Sweep 15: number-token diff and line multiset for the v0.26 -> v0.27 draft pair.

Read-only. Pattern matches the sweep method: (?<![\\w-])\\d+(?:\\.\\d+)?(?![\\w-]).
Writes scratch/sw_sweep15_tokendiff.log and scratch/sw_sweep15_multiset.log,
and prints a summary.
"""
import re
import subprocess
from collections import Counter

REPO = "/home/rod/Documents/GitHub/KiteTurbineDynamics.jl"
DRAFT = "docs/reporting/drafts/2026-10-08-report-first-draft.md"
PAIRS = [("d91b93b", "546fc1f")]

pat = re.compile(r"(?<![\w-])\d+(?:\.\d+)?(?![\w-])")


def side_lines(pair):
    diff = subprocess.run(
        ["git", "-C", REPO, "diff", pair[0], pair[1], "--", DRAFT],
        capture_output=True, text=True, check=True).stdout
    added, removed = [], []
    for line in diff.splitlines():
        if line.startswith(("+++", "---")):
            continue
        if line.startswith("+"):
            added.append(line[1:])
        elif line.startswith("-"):
            removed.append(line[1:])
    return added, removed


tok_log, multi_log = [], []
for a, b in PAIRS:
    added, removed = side_lines((a, b))
    at = [t for l in added for t in pat.findall(l)]
    rt = [t for l in removed for t in pat.findall(l)]
    ca, cr = Counter(at), Counter(rt)
    arrivals = {k: ca[k] - cr.get(k, 0) for k in sorted(ca) if ca[k] > cr.get(k, 0)}
    removals = {k: cr[k] - ca.get(k, 0) for k in sorted(cr) if cr[k] > ca.get(k, 0)}
    tok_log.append(f"== {a} -> {b} ==")
    tok_log.append(f"lines: +{len(added)} -{len(removed)}; raw token occurrences: added {len(at)}, removed {len(rt)}")
    tok_log.append(f"arrivals: {arrivals}")
    tok_log.append(f"removals: {removals}")
    for tok, net in arrivals.items():
        al = [l.strip() for l in added if tok in pat.findall(l)]
        rl = [l.strip() for l in removed if tok in pat.findall(l)]
        tok_log.append(f"  [ARR {tok} net+{net}] raw: added-side {len(al)}, removed-side {len(rl)}")
        for l in al[:2]:
            tok_log.append(f"      +: {l[:150]}")
        for l in rl[:2]:
            tok_log.append(f"      -: {l[:150]}")
    for tok, net in removals.items():
        al = [l.strip() for l in added if tok in pat.findall(l)]
        rl = [l.strip() for l in removed if tok in pat.findall(l)]
        tok_log.append(f"  [REM {tok} net-{net}] raw: added-side {len(al)}, removed-side {len(rl)}")
        for l in al[:2]:
            tok_log.append(f"      +: {l[:150]}")
        for l in rl[:2]:
            tok_log.append(f"      -: {l[:150]}")
    tokens = set(arrivals) | set(removals)
    tok_log.append("== identity check (net == added - removed, raw side >1 only) ==")
    for tok in sorted(tokens, key=lambda x: (len(x), x)):
        if ca[tok] + cr[tok] > 1:
            tok_log.append(f"  {tok}: net {arrivals.get(tok, 0) - removals.get(tok, 0):+d}, raw added {ca.get(tok, 0)}, raw removed {cr.get(tok, 0)}")
    seen_a = Counter(l.rstrip() for l in added)
    seen_r = Counter(l.rstrip() for l in removed)
    aonly = {k: v for k, v in seen_a.items() if k not in seen_r}
    ronly = {k: v for k, v in seen_r.items() if k not in seen_a}
    multi_log.append(f"== {a}->{b}: +only {sum(aonly.values())} lines, -only {sum(ronly.values())} lines")
    for k, v in sorted(aonly.items()):
        multi_log.append(f"   +only x{v}: {k.strip()[:160]}")
    for k, v in sorted(ronly.items()):
        multi_log.append(f"   -only x{v}: {k.strip()[:160]}")

with open("scratch/sw_sweep15_tokendiff.log", "w") as fh:
    fh.write("\n".join(tok_log) + "\n")
with open("scratch/sw_sweep15_multiset.log", "w") as fh:
    fh.write("\n".join(multi_log) + "\n")
print("\n".join(tok_log))
print()
print("\n".join(multi_log))

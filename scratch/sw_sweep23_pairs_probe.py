#!/usr/bin/env python3
"""Sweep 23 probes: raw pair attribution, freeze md5s (2026-10-14).

Read-only. Complements the skill's token tools so the record section can
classify every raw pair. Complements sw_sweep23_core.sh.
"""
import re
import subprocess
import pathlib
import hashlib
from collections import Counter

PAT = re.compile(r"(?<![\w-])\d+(?:\.\d+)?(?![\w-])")
REL = "docs/reporting/drafts/2026-10-08-report-first-draft.md"


def changed(a, b):
    d = subprocess.run(["git", "diff", "--no-color", "-U0", a, b, "--", REL],
                       capture_output=True, text=True).stdout
    rem, add = [], []
    for line in d.splitlines():
        if line.startswith(("---", "+++", "@@")):
            continue
        if line.startswith("-"):
            rem.append(line[1:])
        elif line.startswith("+"):
            add.append(line[1:])
    return rem, add


for a, b in [("a3ca2f6", "7dd91a9")]:
    rem, add = changed(a, b)
    rc, ac = Counter(), Counter()
    for l in rem:
        rc.update(PAT.findall(l))
    for l in add:
        ac.update(PAT.findall(l))
    print("==", a, "->", b, "raw added", sum(ac.values()),
          "raw removed", sum(rc.values()))
    for tok in sorted(set(rc) | set(ac)):
        r, av = rc.get(tok, 0), ac.get(tok, 0)
        if r and av and av - r == 0:
            print(f"  net-out pair {tok}:")
            for l in rem:
                if tok in PAT.findall(l):
                    print("    -", l[:160])
            for l in add:
                if tok in PAT.findall(l):
                    print("    +", l[:160])
    for tok in sorted(ac):
        r, av = rc.get(tok, 0), ac.get(tok, 0)
        if r and av - r > 0:
            print(f"  kept pair {tok}: net +{av - r}; raw removed-side {r}, "
                  f"added-side {av}")
print()

repo = pathlib.Path('.')
md5 = lambda t: hashlib.md5(t.encode()).hexdigest()
block = (repo / 'scratch/sw_levers_reading_block.md').read_text()
receipt = (repo / 'docs/reporting/room-responses/science-writer-2026-10-14-levers-reading.md').read_text()
B, E = '<!-- LEVERS-READING-START -->', '<!-- LEVERS-READING-END -->'
seg = receipt.split(B, 1)[1].split(E, 1)[0].strip('\n')
draft = (repo / 'scratch/sw_sweep23_draft_v037.md').read_text()
s = 'The two plates map the same search in two views.'
e = 'The gene-level effects wait on the landscape extracts.'
region = draft[draft.index(s):draft.index(e) + len(e)]
print("freeze block md5 (file as written):", md5(block))
print("freeze block md5 (stripped):", md5(block.strip('\n')))
print("receipt region == block:", seg == block.strip('\n'))
print("draft region == block:", region == block.strip('\n'))
print("declared block md5: 7bbd964db09d2b33269ce5cb8c334054")

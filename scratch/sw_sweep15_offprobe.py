#!/usr/bin/env python3
"""Sweep 15: STE offender dump for the sweep method.

Usage: python3 sw_sweep15_offprobe.py <file> [<file> ...]

Per file: headline (words/total/per100w) then the offender lines per class:
sentences over 20 words, passive constructions, nominalizations, and
paragraphs over six sentence-lines. Read-only; mirrors the Sweep 8-14 dump.
"""
import importlib.util
import re
import sys

spec = importlib.util.spec_from_file_location("ste", "ste-lint.py")
ste = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ste)

PASSIVE = re.compile(rf"\b{ste.BE}\s+(?:\w+ed|{ste.PP_IRREG})\b", re.I)
NOMIN = re.compile(
    r"\b(?:perform(?:s|ed)?|conduct(?:s|ed)?|provide(?:s|d)?|carry out|carries out|make use of|makes use of)\b"
    r"|\b\w{4,}(?:tion|ment|ance|ence)\s+of\b",
    re.I,
)


def split_line(s):
    s = s.strip()
    s = re.sub(r"^\s*#{1,6}\s*", "", s)
    s = re.sub(r"^\s*(?:[-*+]|\d+[.)])\s+", "", s)
    return [p.strip() for p in re.split(r"(?<=[.!?:])\s+(?=[A-Z0-9\"'\-])", s) if p.strip()]


for path in sys.argv[1:]:
    with open(path) as fh:
        text = fh.read()
    r = ste.lint(text)
    print(f"== {path}: words={r['words']} total={r['total']} per100w={r['total_per100w']:.2f} ==")
    t = ste.strip_code(text)
    print("-- sentences over 20 words --")
    for line in t.split("\n"):
        for p in split_line(line):
            if ste.wc(p) > 20:
                print("  | " + p[:100])
    print("-- passive constructions --")
    seen = set()
    for line in t.split("\n"):
        s = line.strip()
        if s and PASSIVE.search(s) and s not in seen:
            seen.add(s)
            print("  | " + s[:100])
    print("-- nominalizations --")
    seen = set()
    for line in t.split("\n"):
        s = line.strip()
        if s and NOMIN.search(s) and s not in seen:
            seen.add(s)
            print("  | " + s[:100])
    print("-- paragraphs over six sentence-lines --")
    for p in [p for p in re.split(r"\n\s*\n", text) if p.strip()]:
        if len(ste.sentences(ste.strip_code(p))) > 6:
            print("  | " + p.strip().split("\n")[0][:100])

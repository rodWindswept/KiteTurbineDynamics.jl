#!/usr/bin/env python3
"""Sweep 27 supplement: precise guard-form counts in the v0.41 docx (2026-10-14).

Read-only. The substring count of '14.97' also matches '14.972'; this probe
separates the forms and prints contexts so the record census can state the
exact guard readings.
"""
import html
import re
import zipfile

z = zipfile.ZipFile("scratch/report-pdf-build/draft-live.docx")
doc = z.read("word/document.xml").decode("utf-8", "replace")
text = html.unescape(re.sub(r"<[^>]+>", " ", doc))
flat = re.sub(r"\s+", " ", text)


def ctx(pat, n=4, w=110):
    for m in list(re.finditer(pat, flat))[:n]:
        a = max(0, m.start() - w)
        b = min(len(flat), m.end() + w)
        print("   ...", flat[a:b], "...")


print("standalone '14.97' (no digit after):", len(re.findall(r"14\.97(?!\d)", flat)))
print("'14.972':", flat.count("14.972"))
ctx(r"14\.97\d?")
print("'3.816':", flat.count("3.816"))
print("standalone '27.363' (no digit after):", len(re.findall(r"27\.363(?!\d)", flat)))
print("'27.3635':", flat.count("27.3635"))
print("'unresolved' (ignore case):", len(re.findall(r"unresolved", flat, re.I)))

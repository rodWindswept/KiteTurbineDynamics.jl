#!/usr/bin/env python3
"""Sweep 27 supplement: hero-string contexts in the v0.41 docx (2026-10-14).

Read-only. Complements sw_sweep27_copy_probe.py so the record census can
name where the hero forms actually read in the built copy.
"""
import html
import re
import zipfile

z = zipfile.ZipFile("scratch/report-pdf-build/draft-live.docx")
doc = z.read("word/document.xml").decode("utf-8", "replace")
text = html.unescape(re.sub(r"<[^>]+>", " ", doc))
flat = re.sub(r"\s+", " ", text)
for pat in ["machine-winner-hero", "machine winner hero", "Machine winner hero",
            "Figure seated", "figure seated", "seated"]:
    print(f"== {pat!r}: {flat.count(pat)}")
    for m in re.finditer(re.escape(pat), flat):
        a = max(0, m.start() - 90)
        b = min(len(flat), m.end() + 90)
        print("   ...", flat[a:b], "...")

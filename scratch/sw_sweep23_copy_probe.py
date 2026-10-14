#!/usr/bin/env python3
"""Sweep 23 review-copy probe: the delivered docx at the declared md5 (2026-10-14).

Read-only. Complements sw_sweep23_core.sh section 7.
"""
import hashlib
import html
import re
import zipfile

p = "scratch/report-pdf-build/draft-live.docx"
z = zipfile.ZipFile(p)
media = [n for n in z.namelist() if n.startswith("word/media/")]
print("media entries:", len(media))
for n in sorted(media):
    print("  ", n)
doc = z.read("word/document.xml").decode("utf-8", "replace")
text = html.unescape(re.sub(r"<[^>]+>", " ", doc))
checks = [
    ("head line 'Draft v0.37'", text.count("Draft v0.37")),
    ("older marks 'Draft v0.36'", text.count("Draft v0.36")),
    ("old form 'gate penalt' (ignore case)", len(re.findall(r"gate penalt", text, re.I))),
    ("new form 'soft constraint penalt'", len(re.findall(r"soft constraint penalt", text, re.I))),
    ("'301 reject'", text.count("301 reject")),
    ("'110 clearance_reject'", text.count("110 clearance_reject")),
    ("'11 reject_twist'", text.count("11 reject_twist")),
    ("'14.97' class", text.count("14.97")),
    ("'3.816'", text.count("3.816")),
    ("'27.363' standalone", len(re.findall(r"27\.363(?!\d)", text))),
    ("'27.364' standalone", len(re.findall(r"27\.364(?!\d)", text))),
    ("'unresolved' (ignore case)", len(re.findall(r"unresolved", text, re.I))),
    ("'carry their text'", text.count("carry their text")),
    ("'kg-equivalent' (ignore case)", len(re.findall(r"kg-equivalent", text, re.I))),
    ("'Figure seat unresolved' notice", text.count("seat unresolved")),
]
for name, n in checks:
    print(f"  {name}: {n}")
md5 = hashlib.md5(open(p, "rb").read()).hexdigest()
print("md5:", md5)
print("declared: 94619634bd1374abc8327050cf13874d")

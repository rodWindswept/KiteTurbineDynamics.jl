#!/usr/bin/env python3
"""Sweep 24 review-copy probe: the v0.38 docx at the declared md5 (2026-10-14).

Read-only. Complements sw_sweep24_core.sh section 7.
"""
import hashlib
import html
import re
import zipfile

p = "scratch/report-pdf-build/draft-live.docx"
z = zipfile.ZipFile(p)
media = [n for n in z.namelist() if n.startswith("word/media/")]
print("media entries:", len(media))
doc = z.read("word/document.xml").decode("utf-8", "replace")
text = html.unescape(re.sub(r"<[^>]+>", " ", doc))
checks = [
    ("head line 'Draft v0.38'", text.count("Draft v0.38")),
    ("older marks 'Draft v0.37'", text.count("Draft v0.37")),
    ("'v0.37' anywhere", text.count("v0.37")),
    ("old pair 'enables rope breaks'", text.count("enables rope breaks")),
    ("old form 'breaks only during real operation'", text.count("breaks only during real operation")),
    ("detector 'rope-break check'", len(re.findall(r"rope-break check", text))),
    ("safety set 'never allows breaks'", text.count("never allows breaks")),
    ("safety set 'always rejects the design'", text.count("always rejects the design")),
    ("'judges only real operation'", text.count("judges only real operation")),
    ("'14.97' class", text.count("14.97")),
    ("'3.816'", text.count("3.816")),
    ("'27.363' standalone", len(re.findall(r"27\.363(?!\d)", text))),
    ("'27.364' standalone", len(re.findall(r"27\.364(?!\d)", text))),
    ("'unresolved' (ignore case)", len(re.findall(r"unresolved", text, re.I))),
    ("'carry their text'", text.count("carry their text")),
]
for name, n in checks:
    print(f"  {name}: {n}")
md5 = hashlib.md5(open(p, "rb").read()).hexdigest()
print("md5:", md5)
print("declared: 9f9ef1adb753bea5f8d544dc3e13bd96")

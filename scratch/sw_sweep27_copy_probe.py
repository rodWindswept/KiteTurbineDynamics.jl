#!/usr/bin/env python3
"""Sweep 27 review-copy probe: the v0.41 docx at the declared md5 (2026-10-14).

Read-only. Complements sw_sweep27_core.sh section 7.
"""
import hashlib
import html
import re
import zipfile

p = "scratch/report-pdf-build/draft-live.docx"
stamp = "scratch/report-pdf-build/draft-e8159b0-20261014-180159.docx"
z = zipfile.ZipFile(p)
media = [n for n in z.namelist() if n.startswith("word/media/")]
print("media entries:", len(media))
doc = z.read("word/document.xml").decode("utf-8", "replace")
text = html.unescape(re.sub(r"<[^>]+>", " ", doc))
checks = [
    ("head line 'Draft v0.41'", text.count("Draft v0.41")),
    ("older marks 'Draft v0.40'", text.count("Draft v0.40")),
    ("'v0.40' anywhere", text.count("v0.40")),
    ("'v0.41' anywhere", text.count("v0.41")),
    ("hero 'machine winner hero'", text.count("machine winner hero")),
    ("hero slug 'machine-winner-hero'", text.count("machine-winner-hero")),
    ("hero marker 'Figure seated' (soft ws)", len(re.findall(r"Figure\s+seated", text))),
    ("appendix 'All seven read dataset commit'", text.count("All seven read dataset commit")),
    ("shape 'the gust cases'", text.count("the gust cases")),
    ("shape 'one island of the campaign'", text.count("one island of the campaign")),
    ("shape 'longer or broader run'", text.count("longer or broader run")),
    ("shape 'do not prove an optimal gene set'", text.count("do not prove an optimal gene set")),
    ("table row '3.49'", text.count("3.49")),
    ("table row '19.14'", text.count("19.14")),
    ("table row '51.8'", text.count("51.8")),
    ("table row '14.42'", text.count("14.42")),
    ("table row '24.3'", text.count("24.3")),
    ("retirement '3.55'", text.count("3.55")),
    ("retirement '5.39'", text.count("5.39")),
    ("sizing '1278'", text.count("1278")),
    ("sizing '87.9' / '78.8'", text.count("87.9") + text.count("78.8")),
    ("tips 'about 73 m/s'", text.count("about 73 m/s")),
    ("tips 'about 85 m/s'", text.count("about 85 m/s")),
    ("'100 m/s ceiling'", text.count("100 m/s ceiling")),
    ("'14.97' class", text.count("14.97")),
    ("'14.972'", text.count("14.972")),
    ("'3.816'", text.count("3.816")),
    ("'27.363' standalone", len(re.findall(r"27\.363(?!\d)", text))),
    ("'unresolved' (ignore case)", len(re.findall(r"unresolved", text, re.I))),
    ("old pair 'enables rope breaks'", text.count("enables rope breaks")),
    ("detector 'limits break detection' (soft ws)", len(re.findall(r"limits\s+break\s+detection", text))),
    ("detector 'arms the rope-break check' (soft ws)", len(re.findall(r"arms\s+the\s+rope-break\s+check", text))),
    ("safety 'never allows breaks'", text.count("never allows breaks")),
    ("safety 'always rejects the design'", text.count("always rejects the design")),
    ("safety 'broken rope'", text.count("broken rope")),
]
for name, n in checks:
    print(f"  {name}: {n}")
md5 = hashlib.md5(open(p, "rb").read()).hexdigest()
md5s = hashlib.md5(open(stamp, "rb").read()).hexdigest()
print("md5 live:", md5)
print("md5 stamp:", md5s)
print("live == stamp:", md5 == md5s)

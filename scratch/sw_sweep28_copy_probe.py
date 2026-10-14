#!/usr/bin/env python3
"""Sweep 28 review-copy probe: the v0.42 docx at the declared md5 (2026-10-14).

Read-only. Complements sw_sweep28_core.sh section 7.
"""
import hashlib
import html
import re
import zipfile

p = "scratch/report-pdf-build/draft-live.docx"
stamp = "scratch/report-pdf-build/draft-38c77f8-20261014-184207.docx"
z = zipfile.ZipFile(p)
media = [n for n in z.namelist() if n.startswith("word/media/")]
print("media entries:", len(media))
doc = z.read("word/document.xml").decode("utf-8", "replace")
text = html.unescape(re.sub(r"<[^>]+>", " ", doc))
checks = [
    ("head line 'Draft v0.42'", text.count("Draft v0.42")),
    ("older 'Draft v0.41'", text.count("Draft v0.41")),
    ("'v0.41' anywhere", text.count("v0.41")),
    ("'v0.42' anywhere", text.count("v0.42")),
    ("power cell 'pass, P_end 5.314 kW' (soft ws)", len(re.findall(r"pass,\s*P_end\s*5\.314\s*kW", text))),
    ("'margin +0.314 kW' (soft ws)", len(re.findall(r"margin\s*\+0\.314\s*kW", text))),
    ("'+6.28 per cent'", text.count("+6.28 per cent")),
    ("'15.0 on 2.5' (soft ws)", len(re.findall(r"15\.0\s+on\s+2\.5", text))),
    ("'+12.5'", text.count("+12.5")),
    ("'+500.0 per cent'", text.count("+500.0 per cent")),
    ("'6.00 times'", text.count("6.00 times")),
    ("'5.468'", text.count("5.468")),
    ("'+3.968'", text.count("+3.968")),
    ("'+264.5 per cent'", text.count("+264.5 per cent")),
    ("'3.65 times'", text.count("3.65 times")),
    ("'+64.913 deg'", text.count("+64.913 deg")),
    ("'+65.7 per cent'", text.count("+65.7 per cent")),
    ("'2.91 times'", text.count("2.91 times")),
    ("'least margin 2.03 at S1' (soft ws)", len(re.findall(r"least\s+margin\s+2\.03\s+at\s+S1", text))),
    ("'+102.9 per cent above unity'", text.count("+102.9 per cent above unity")),
    ("'the warm path rejects healthy winners'", text.count("the warm path rejects healthy winners")),
    ("'Torsional capacity'", text.count("Torsional capacity")),
    ("'pass, 15.0 minimum' (soft ws)", len(re.findall(r"pass,\s*15\.0\s+minimum", text))),
    ("internal '+12.472'", text.count("+12.472")),
    ("internal '+498.9'", text.count("+498.9")),
    ("internal '5.99 times'", text.count("5.99 times")),
    ("hero slug 'machine-winner-hero'", text.count("machine-winner-hero")),
    ("appendix 'All seven read dataset commit'", text.count("All seven read dataset commit")),
    ("shape 'the gust cases'", text.count("the gust cases")),
    ("shape 'one island of the campaign'", text.count("one island of the campaign")),
    ("shape 'longer or broader run'", text.count("longer or broader run")),
    ("shape 'do not prove an optimal gene set'", text.count("do not prove an optimal gene set")),
    ("table row '3.49'", text.count("3.49")),
    ("table row '19.14'", text.count("19.14")),
    ("retirement '3.55'", text.count("3.55")),
    ("sizing '1278'", text.count("1278")),
    ("'100 m/s ceiling'", text.count("100 m/s ceiling")),
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

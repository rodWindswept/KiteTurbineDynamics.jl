#!/usr/bin/env python3
"""Sweep 29 review-copy probe: the v0.43 docx at the declared md5 (2026-10-14).

Read-only. Complements sw_sweep29_core.sh section 7.
"""
import hashlib
import html
import re
import zipfile

p = "scratch/report-pdf-build/draft-live.docx"
stamp = "scratch/report-pdf-build/draft-e5541e9-20261014-200839.docx"
z = zipfile.ZipFile(p)
media = [n for n in z.namelist() if n.startswith("word/media/")]
print("media entries:", len(media))
doc = z.read("word/document.xml").decode("utf-8", "replace")
text = html.unescape(re.sub(r"<[^>]+>", " ", doc))
checks = [
    ("head line 'Draft v0.43'", text.count("Draft v0.43")),
    ("older 'Draft v0.42'", text.count("Draft v0.42")),
    ("'v0.42' anywhere", text.count("v0.42")),
    ("'v0.43' anywhere", text.count("v0.43")),
    ("'v0.41' anywhere", text.count("v0.41")),
    ("base 'reads 0.75 of the rotor radius' (soft ws)", len(re.findall(r"reads\s+0\.75\s+of\s+the\s+rotor\s+radius", text))),
    ("'0.113'", text.count("0.113")),
    ("'22 degrees' (soft ws)", len(re.findall(r"22\s+degrees", text))),
    ("'blade_scale_top'", text.count("blade_scale_top")),
    ("'blade_scale_bottom'", text.count("blade_scale_bottom")),
    ("'bank_bottom'", text.count("bank_bottom")),
    ("'physics-validation era' (soft ws)", len(re.findall(r"physics-validation\s+era", text))),
    ("'scored every design on the cold path' (soft ws)", len(re.findall(r"scored\s+every\s+design\s+on\s+the\s+cold\s+path", text))),
    ("'staged launch' (soft ws)", len(re.findall(r"staged\s+launch", text))),
    ("'first screen after' (soft ws)", len(re.findall(r"first\s+screen\s+after", text))),
    ("old 'Slot 1'", text.count("Slot 1")),
    ("old 'Slot 2'", text.count("Slot 2")),
    ("ring takeaway 'structural check with a wide margin' (soft ws)", len(re.findall(r"structural\s+check\s+with\s+a\s+wide\s+margin", text))),
    ("twist takeaway 'twist and torque checks along its whole length' (soft ws)", len(re.findall(r"twist\s+and\s+torque\s+checks\s+along\s+its\s+whole\s+length", text))),
    ("strip takeaway 'improves the machine at every recorded step' (soft ws)", len(re.findall(r"improves\s+the\s+machine\s+at\s+every\s+recorded\s+step", text))),
    ("retired 'A lower number is better' (soft ws)", len(re.findall(r"A\s+lower\s+number\s+is\s+better", text))),
    ("power cell 'pass, P_end 5.314 kW' (soft ws)", len(re.findall(r"pass,\s*P_end\s*5\.314\s*kW", text))),
    ("'margin +0.314 kW' (soft ws)", len(re.findall(r"margin\s*\+0\.314\s*kW", text))),
    ("'15.0 on 2.5' (soft ws)", len(re.findall(r"15\.0\s+on\s+2\.5", text))),
    ("'pass, 15.0 minimum' (soft ws)", len(re.findall(r"pass,\s*15\.0\s+minimum", text))),
    ("'the warm path rejects healthy winners'", text.count("the warm path rejects healthy winners")),
    ("'Torsional capacity'", text.count("Torsional capacity")),
    ("hero slug 'machine-winner-hero'", text.count("machine-winner-hero")),
    ("appendix 'All seven read dataset commit'", text.count("All seven read dataset commit")),
    ("shape 'the gust cases'", text.count("the gust cases")),
    ("shape 'one island of the campaign'", text.count("one island of the campaign")),
    ("shape 'do not prove an optimal gene set'", text.count("do not prove an optimal gene set")),
    ("table row '3.49'", text.count("3.49")),
    ("table row '19.14'", text.count("19.14")),
    ("retirement '3.55'", text.count("3.55")),
    ("sizing '1278'", text.count("1278")),
    ("'100 m/s ceiling'", text.count("100 m/s ceiling")),
    ("'3.816'", text.count("3.816")),
    ("'27.363' standalone", len(re.findall(r"27\.363(?!\d)", text))),
    ("'unresolved' (ignore case)", len(re.findall(r"unresolved", text, re.I))),
    ("'14.972'", text.count("14.972")),
    ("internal '+12.472'", text.count("+12.472")),
    ("internal '+498.9'", text.count("+498.9")),
    ("internal '5.99 times'", text.count("5.99 times")),
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

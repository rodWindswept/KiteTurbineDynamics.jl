#!/usr/bin/env python3
# fig_br_check.py — the lifting-bridles relabel landing: check set (figures seat, 2026-10-15)
# Expected: 0 fail. Prints the record; writes nothing.
import hashlib, json, re, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
S = "9241b23"
MD5 = {
    "system-anatomy.tex": "e8f08e653010c820262587e30dd9d42b",
    "prototype.html": "58d4e491c3a61af39bb7f655f55e4114",
    "label-ledger.txt": "b359914881c9d9936ff7fc8dd7c2611d",
    "system-anatomy.pdf": "e00521fe239ec244139898f77178af17",
    "system-anatomy.png": "19c0caf5e32bd5728323c30ff98124a0",
}
SHA = {
    "system-anatomy.tex": "e7697c986d605f6ff50e2c628812a84e9eb2e5514a6170a7de89b2f707f1060c",
    "label-ledger.txt": "bed029d0f36a4e3b218510fc16fe5debf294b65413f64aa2abcafbfdc6ae4912",
    "system-anatomy.pdf": "c55bd7a888a1f3d657445460a9e6bebb05504efe04d4194661b3ae8f1a844d4c",
    "system-anatomy.png": "696be723993c708b038e0d1e10b96e83ba357a65cb2442580b1de371dedf8c66",
    "system-anatomy.py": "b3f11a395da3067dff970a4cebf827e917eac8dc6b88bbb295ab8bdea75b1735",
    "checks.log": "99e81f32e1dbc3882a9a63400dac0a4410b3be618d29365b6633886a3aeec31a",
}
KIT = "docs/reporting/figures/system-anatomy"

checks = []
def ck(desc, ok):
    checks.append((desc, bool(ok)))

def read(rel):
    return (ROOT / rel).read_text(encoding="utf-8")
def by(rel):
    return (ROOT / rel).read_bytes()
def sha(rel):
    return hashlib.sha256(by(rel)).hexdigest()
def m5(rel):
    return hashlib.md5(by(rel)).hexdigest()

# -- 1. the kit: the drawn form and the three generator outputs
py = read(f"{KIT}/system-anatomy.py")
tex = read(f"{KIT}/system-anatomy.tex")
html = read(f"{KIT}/prototype.html")
led = read(f"{KIT}/label-ledger.txt")
ck("py: the label line reads the founder form", 'lines=["lifting bridles (three)"]' in py)
ck("py: no bare label line", 'lines=["bridles (three)"]' not in py)
ck("py: the v7 header note reads", "v7 re-cut (2026-10-15)" in py)
ck("tex: the node carries the founder form", "{lifting bridles (three)};" in tex)
ck("tex: no bare form", not re.search(r"(?<!lifting )bridles \(three\)", tex))
ck("prototype: the text node carries the founder form", ">lifting bridles (three)</text>" in html)
ck("prototype: no bare form", not re.search(r"(?<!lifting )bridles \(three\)", html))
ck("ledger: the string reads once in the founder form", led.count("lifting bridles (three)") == 1)
ck("ledger: no bare form", not re.search(r"(?<!lifting )bridles \(three\)", led))
ck("ledger: still 34 strings", len([l for l in led.splitlines() if l.strip()]) == 34)

# -- 2. the pins
mq = json.loads(read(f"{KIT}/manifest.json"))
ck("manifest: script_commit", mq.get("script_commit") == S)
ck("manifest: script sha", mq["script"]["sha256"] == SHA["system-anatomy.py"])
ck("manifest: tex sha", mq["outputs"]["system-anatomy.tex"] == SHA["system-anatomy.tex"])
ck("manifest: ledger sha", mq["outputs"]["label-ledger.txt"] == SHA["label-ledger.txt"])
ck("manifest: pdf sha", mq["outputs"]["system-anatomy.pdf"] == SHA["system-anatomy.pdf"])
ck("manifest: png sha", mq["outputs"]["system-anatomy.png"] == SHA["system-anatomy.png"])
ck("manifest: checks sha", mq["outputs"]["checks.log"] == SHA["checks.log"])
ck("manifest: data commit held", mq.get("data_commit") == "dd3cc6a")

ck("checks.log: sha256 at source", sha(f"{KIT}/checks.log") == SHA["checks.log"])
cl = read(f"{KIT}/checks.log")
ck("checks.log: the v7 re-cut line", "re-cut v7: the lifting-bridles relabel (the founder note 2026-10-15)" in cl)
ck("checks.log: the chain label reads the founder form", "'lifting bridles (three)'" in cl)
ck("checks.log: the script commit named", "(script commit " + S + ")" in cl)
ck("checks.log: the three-location line", "re-cut v7: three full runs byte-identical across all five outputs (in place plus twice into scratch)" in cl)
ck("checks.log: zero error lines", "latex error lines: 0" in cl)
ck("checks.log: zero overfull boxes", "overfull boxes: 0" in cl)
for name, val in MD5.items():
    ck(f"checks.log: md5 row {name}", f"{val}  {name}" in cl)

# -- 3. the actual bytes on disk
for name in ("system-anatomy.tex", "label-ledger.txt", "system-anatomy.pdf", "system-anatomy.png", "system-anatomy.py"):
    ck(f"disk sha256 {name}", sha(f"{KIT}/{name}") == SHA[name])
for name, val in MD5.items():
    ck(f"disk md5 {name}", m5(f"{KIT}/{name}") == val)

# -- 4. the kit records
rs = read(f"{KIT}/register-status.md")
ck("register note: the v7 date line", "v7 re-cut 2026-10-15." in rs)
ck("register note: the v7 re-cut block", "v7 (2026-10-15): the lifting-bridles relabel" in rs)
ck("register note: delta v5", "**Delta** v5 (2026-10-15): the v7 re-cut lands." in rs)
ck("register note: the script commit named twice", rs.count(f"`{S}`") == 2)
ck("register note: the md5 table (tex)", MD5["system-anatomy.tex"] in rs)
cap = read(f"{KIT}/captions.md")
ck("captions: the provenance token", f"script commit `{S}`" in cap)
ck("captions: the relabel note", "Relabel note (2026-10-15): the lifting-bridles relabel" in cap)
ck("captions: the caption text holds (author pass)", "Three bridles run" in cap)
spec = read(f"{KIT}/SPEC.md")
ck("SPEC: the load-path form", "lift bearing, lifting bridles," in spec)
ck("SPEC: the live item", "The lifting-bridles relabel (2026-10-15): the chain label reads" in spec)

# -- 5. the map
fm = read("docs/reporting/figures/figure-map.md")
ck("map: row 2 takes the relabel", f"The lifting-bridles relabel lands (script `{S}`)" in fm)
ck("map: row 10 title takes the winner form", "| 10 | 9 | §3.3 | Machine winner and the plan, side, downwind capture set |" in fm)
ck("map: no Machine hero title", "Machine hero" not in fm)
ck("map: row 10 winner-form line", 'The title takes the winner form (the founder note 2026-10-15): "hero" stops as a figure label' in fm)
ck("map: row 23 cite takes the sign commit", "(science-validator, `cb862df`)" in fm)
ck("map: the retired cite token reads zero", "8855d9a" not in fm)
ck("map: row 23 closure", "The counter-reads close clean (`857f2c1`, 153 checks)" in fm)
ck("map: delta v40 opens", "- **v40 (2026-10-15):** the lifting-bridles relabel lands" in fm)
ck("map: delta v40 closes the file", fm.rstrip().endswith("the winner-form re-keys."))

# -- 6. the draft and the tracker
dr = read("docs/reporting/drafts/2026-10-08-report-first-draft.md")
ck("draft: the v0.48 header", "Internal engineering report. Draft v0.48. Date 2026-10-14." in dr)
ck("draft: the SA row takes the script commit", f"| System anatomy plate | `scratch/fig1_decode_winner.jl` · `best_vector.csv` | NR-011, NR-017, NR-043 | `{S}` |" in dr)
ck("draft: the png cell", SHA["system-anatomy.png"] in dr)
ck("draft: the pdf cell", SHA["system-anatomy.pdf"] in dr)
ck("draft: the ledger cell", SHA["label-ledger.txt"] in dr)
ck("draft: the checks cell", SHA["checks.log"] in dr)
ck("draft: the marker holds (author pass)", "(machine winner hero, slug `machine-winner-hero`)" in dr)
ck("draft: the appendix exhibit name holds (author pass)", "| Machine winner hero |" in dr)
tr = read("docs/reporting/draft-tracker.md")
ck("tracker: the v0.48 entry", "v0.48 pass by @fig-img-diagrams (2026-10-15)." in tr)
ck("tracker: the entry text", "This pass re-pins the figure-provenance appendix to the delivered lifting-bridles system-anatomy re-cut." in tr)

# -- 7. the corner cites
crs = read("docs/reporting/figures/machine-corner-grid/register-status.md")
ck("corner note: the cite takes the sign commit", "Signed (science-validator, `cb862df`)" in crs)
ck("corner note: the retired cite token reads zero", "8855d9a" not in crs)
ck("corner note: delta v2", "**Delta** v2 (2026-10-15): the counter-reads close clean" in crs)
crr = read("docs/reporting/figures/machine-corner-grid/README.md")
ck("corner README: the closure reads", "The counter-reads\nclose clean (`857f2c1`, 153 checks)." in crr)
ck("corner README: the cite line", "The NR-051 cite takes the sign\ncommit `cb862df`." in crr)

# -- 8. the seat page
sp = read("handovers/handover-2026-10-14-reporting-room-figures-images-diagrams.md")
ck("seat page: the relabel item", "The lifting-bridles relabel (map row 2)" in sp)
ck("seat page: the winner-form item", "The winner-form re-keys (row 10)" in sp)
ck("seat page: the receipt reference", "figures-images-diagrams-2026-10-15-lifting-bridles-relabel.md" in sp)

# -- 9. the three-location F-REPRO
def md5_block(path):
    out = {}
    for line in read(path).splitlines():
        m = re.match(r"^([0-9a-f]{32})  (.+)$", line)
        if m:
            out[m.group(2)] = m.group(1)
    return out
r1 = md5_block("scratch/fig_br_run1.log")
r2 = md5_block("scratch/fig_br_run2.log")
ri = md5_block("scratch/fig_br_run_inplace.log")
ck("F-REPRO: run1 reads five md5 rows", len(r1) == 5)
ck("F-REPRO: run2 reads five md5 rows", len(r2) == 5)
ck("F-REPRO: inplace reads five md5 rows", len(ri) == 5)
ck("F-REPRO: run1 == run2", r1 == r2)
ck("F-REPRO: run1 == inplace", r1 == ri)
ck("F-REPRO: the set equals the delivered md5s", r1 == MD5)

# -- 10. the facts
facts = json.loads(read("scratch/fig_br_facts.json"))
ck("facts: script commit", facts["script_commit"] == S)
ck("facts: checks sha", facts["checks_log_sha256"] == SHA["checks.log"])

fails = [d for d, ok in checks if not ok]
for i, (d, ok) in enumerate(checks, 1):
    print(f"{'ok ' if ok else 'FAIL'} {i:03d} {d}")
print()
print(f"{len(checks)} checks, {len(fails)} fail")
sys.exit(1 if fails else 0)

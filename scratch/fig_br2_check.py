#!/usr/bin/env python3
# fig_br2_check.py — the relabel closures fold-back check set (figures seat, 2026-10-15)
# Expected: 0 fail. Prints the record; writes nothing.
import hashlib, json, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
KIT = "docs/reporting/figures/system-anatomy"
S = "9241b23"
PLATE_SHA = {
    "system-anatomy.tex": "e7697c986d605f6ff50e2c628812a84e9eb2e5514a6170a7de89b2f707f1060c",
    "label-ledger.txt": "bed029d0f36a4e3b218510fc16fe5debf294b65413f64aa2abcafbfdc6ae4912",
    "system-anatomy.pdf": "c55bd7a888a1f3d657445460a9e6bebb05504efe04d4194661b3ae8f1a844d4c",
    "system-anatomy.png": "696be723993c708b038e0d1e10b96e83ba357a65cb2442580b1de371dedf8c66",
    "system-anatomy.py": "b3f11a395da3067dff970a4cebf827e917eac8dc6b88bbb295ab8bdea75b1735",
    "checks.log": "99e81f32e1dbc3882a9a63400dac0a4410b3be618d29365b6633886a3aeec31a",
}

checks = []
def ck(desc, ok):
    checks.append((desc, bool(ok)))
def read(rel):
    return (ROOT / rel).read_text(encoding="utf-8")
def sha(rel):
    return hashlib.sha256((ROOT / rel).read_bytes()).hexdigest()

# -- A. the map
fm = read("docs/reporting/figures/figure-map.md")
ck("map: row 2 takes the v0.49 forms and the counter-read close",
   "The caption text and the copy take the forms (v0.49). The aero counter-read closes clean (`79da87c`, 273 checks; the chain re-runs byte-identical at five locations)." in fm)
ck("map: row 2 stale next-line gone", "Next: the aero counter-read of the re-cut, then the visual pass by Rod" not in fm)
ck("map: row 10 takes the winner-form close",
   "The winner-form sites take the forms in the draft (v0.49). The aero counter-read closes clean (`79da87c`)." in fm)
ck("map: row 10 stale next-line gone",
   '"hero" stops as a figure label. Next: the aero counter-read, then the visual pass by Rod' not in fm)
ck("map: delta v41 opens", "- **v41 (2026-10-15):** the relabel closures fold back." in fm)
ck("map: delta v41 closes the file", fm.rstrip().endswith("No plate byte moves."))
ck("map: the counter-read close cites read three times", fm.count("`79da87c`") == 3)
ck("map: the historical delta next-lines read (rows updated)", "Next: the aero counter-read of the relabel and" in fm and "Next: the aero counter-reads and the science register" in fm)

# -- B. the SPEC closes its caption leg
spec = read(f"{KIT}/SPEC.md")
ck("SPEC: the closed item reads", "- Closed: the lifting-bridles relabel (v7 re-cut, 2026-10-15). The" in spec)
ck("SPEC: the closure text", "copy take the forms (author v0.49). No value moves." in spec)
ck("SPEC: the old live item gone", "The lifting-bridles relabel (2026-10-15): the chain label reads" not in spec)

# -- C. the kit notes close their caption phrases
cap = read(f"{KIT}/captions.md")
ck("captions: the note reads the closed form", "The caption text re-keyed at the author pass (v0.49)." in cap)
ck("captions: the forward phrase gone", "re-keys at the author pass" not in cap)
rs = read(f"{KIT}/register-status.md")
ck("register note: the delta reads the closed form", "re-keyed\nat the author pass (v0.49)" in rs)

# -- D. the seat page
sp = read("handovers/handover-2026-10-14-reporting-room-figures-images-diagrams.md")
ck("seat page: the refresh line", "This refresh records the relabel closures (the author fold at v0.49, the term gate, the counter-reads)" in sp)
ck("seat page: one open item", "1. **The visual pass by Rod.**" in sp and "2. **The winner-form re-keys" not in sp)
ck("seat page: the closed bullet", "The relabel closures fold back (2026-10-15):" in sp)
ck("seat page: the footer", "**Next action:** the visual pass by Rod (the corner grid, the winner plate, the F1 plate and rows 4 to 7)." in sp)

# -- E. no plate byte moves
for name in PLATE_SHA:
    ck(f"pin holds: {name}", sha(f"{KIT}/{name}") == PLATE_SHA[name])
mq = json.loads(read(f"{KIT}/manifest.json"))
ck("manifest: script_commit holds", mq.get("script_commit") == S)
ck("manifest: checks sha holds", mq["outputs"]["checks.log"] == PLATE_SHA["checks.log"])

# -- F. the cited closures cross-check
dr = read("docs/reporting/drafts/2026-10-08-report-first-draft.md")
ck("draft: v0.49 header", "Draft v0.49" in dr)
ck("draft: the load-path sentence reads", "down the lifting bridles" in dr)
ck("draft: Machine winner reads twice", dr.count("Machine winner") == 2)
ck("draft: the marker takes the winner form", "(machine winner, slug" in dr)
kcap = read(f"{KIT}/captions.md")
kcapd = read(f"{KIT}/captions-draft.md")
ck("kit captions: the caption form reads", "Three lifting bridles run" in kcap)
ck("captions-draft: the caption form reads", "Three lifting bridles run" in kcapd)
ck("captions-draft: the ledger-string line reads", "lifting bridles, main rotor" in kcapd)
notes = read("docs/reporting/figures/figure-generation-notes.md")
ck("figure notes: the style line reads", "lifting bridles (gold, as the dashboard)" in notes)

fails = [d for d, ok in checks if not ok]
for i, (d, ok) in enumerate(checks, 1):
    print(f"{'ok ' if ok else 'FAIL'} {i:03d} {d}")
print()
print(f"{len(checks)} checks, {len(fails)} fail")
sys.exit(1 if fails else 0)

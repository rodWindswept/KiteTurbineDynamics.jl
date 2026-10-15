#!/usr/bin/env python3
# fig_br_docs_edit.py — the lifting-bridles landing: all text moves (figures seat, 2026-10-15)
#
# Verify-all-then-apply. Every (old, new) pair must match exactly once.
# Writes: the nine doc files, the rebuilt checks.log, the rebuilt manifest.json,
# and scratch/fig_br_facts.json (the hashes the landing uses).
import hashlib, json, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
S = "9241b23"  # the script commit (C1)

# new pins (verified by the three runs)
MD5 = {
    "tex": "e8f08e653010c820262587e30dd9d42b",
    "html": "58d4e491c3a61af39bb7f655f55e4114",
    "ledger": "b359914881c9d9936ff7fc8dd7c2611d",
    "pdf": "e00521fe239ec244139898f77178af17",
    "png": "19c0caf5e32bd5728323c30ff98124a0",
}
SHA = {
    "tex": "e7697c986d605f6ff50e2c628812a84e9eb2e5514a6170a7de89b2f707f1060c",
    "ledger": "bed029d0f36a4e3b218510fc16fe5debf294b65413f64aa2abcafbfdc6ae4912",
    "pdf": "c55bd7a888a1f3d657445460a9e6bebb05504efe04d4194661b3ae8f1a844d4c",
    "png": "696be723993c708b038e0d1e10b96e83ba357a65cb2442580b1de371dedf8c66",
    "script": "b3f11a395da3067dff970a4cebf827e917eac8dc6b88bbb295ab8bdea75b1735",
}

def new_checks_log():
    return (
        "F1 system-anatomy - checks log (figures seat, 2026-10-12)\n"
        "re-cut v3: author label check 38a15f1 (footer separator form, count words) + page-geometry fix (parindent 0, margin 0.25cm)\n"
        "re-cut v4: the blade-span dimension (NR-043) joins the plate and the drawn source line (script commit 9cecee3)\n"
        "re-cut v5: the cone ring (R5) label joins the plate (round-5 founder comment 3); leader clearance asserts (script commit d243b37)\n"
        "re-cut v6: the hub-name retirement (round-6 founder comment 1); the R6 label reads 'R6, the topmost ring' (script commit 1af63fc)\n"
        "re-cut v7: the lifting-bridles relabel (the founder note 2026-10-15); the chain label reads 'lifting bridles (three)' (script commit " + S + ")\n"
        "== generator ==\n"
        "self-checks ok: 6 rings, 15 ropes, 3 blades, span 1.499 m on NR-043, dimension clearances hold, cone-ring leader clear, radii and bank on NR-011/NR-017\n"
        "wrote system-anatomy.tex (8315 bytes); canvas 23.40 x 18.39 cm\n"
        "wrote prototype.html (14757 bytes); svg 884x695 px viewport\n"
        "wrote label-ledger.txt (34 strings)\n"
        "generator exit=0\n"
        "== pdflatex (reproducible: SOURCE_DATE_EPOCH=0 FORCE_SOURCE_DATE=1) ==\n"
        "pdflatex exit=0\n"
        "latex error lines: 0\n"
        "overfull boxes: 0\n"
        "== render ==\n"
        "pdftoppm exit=0\n"
        "== reproducibility ==\n"
        "re-cut v7: three full runs byte-identical across all five outputs (in place plus twice into scratch)\n"
        "== hashes (re-cut v7) ==\n"
        + MD5["tex"] + "  system-anatomy.tex\n"
        + MD5["html"] + "  prototype.html\n"
        + MD5["ledger"] + "  label-ledger.txt\n"
        + MD5["pdf"] + "  system-anatomy.pdf\n"
        + MD5["png"] + "  system-anatomy.png\n"
    )

# ---- the pairs ------------------------------------------------------------------
P = []

FM = "docs/reporting/figures/figure-map.md"
P.append((FM, [
    ('The R6 label reads "R6, the topmost ring". The round-6 counter-read closes clean (`3038656`, 136 checks). Next: the visual pass by Rod',
     'The R6 label reads "R6, the topmost ring". The round-6 counter-read closes clean (`3038656`, 136 checks). The lifting-bridles relabel lands (script `' + S + '`): the chain label reads "lifting bridles (three)". Next: the aero counter-read of the re-cut, then the visual pass by Rod'),
    ('| 10 | 9 | §3.3 | Machine hero and the plan, side, downwind capture set |',
     '| 10 | 9 | §3.3 | Machine winner and the plan, side, downwind capture set |'),
    ('The round-6 hub-name re-cut lands (script `1af63fc`). The leader reads "topmost ring R6". The round-6 counter-read closes clean (`3038656`, 136 checks). Next: the visual pass by Rod',
     'The round-6 hub-name re-cut lands (script `1af63fc`). The leader reads "topmost ring R6". The round-6 counter-read closes clean (`3038656`, 136 checks). The title takes the winner form (the founder note 2026-10-15): "hero" stops as a figure label. Next: the aero counter-read, then the visual pass by Rod'),
    ('The objective row (NR-051) is signed (science-validator, `8855d9a`). The build lands (`a4b4057`): four panels, all in-script checks pass, and the three-location F-REPRO walk reads byte-identical across all five outputs. Next: the aero counter-reads and the science register read, then the visual pass by Rod',
     'The objective row (NR-051) is signed (science-validator, `cb862df`). The build lands (`a4b4057`): four panels, all in-script checks pass, and the three-location F-REPRO walk reads byte-identical across all five outputs. The counter-reads close clean (`857f2c1`, 153 checks): the picks and the objectives recompute from the raw draw columns; the extract binds at all 128 fields; the drawn text reads clean; two fresh runs byte-identical. Two cite findings close (`8855d9a` to `cb862df`). Next: the visual pass by Rod, then the fold'),
    ('  outputs. Next: the aero counter-reads and the science register\n  read, then the visual pass by Rod.',
     '  outputs. Next: the aero counter-reads and the science register\n  read, then the visual pass by Rod.\n\n- **v40 (2026-10-15):** the lifting-bridles relabel lands (row 2). The\n  chain label reads "lifting bridles (three)" (the founder note of\n  2026-10-15). Script `' + S + '`, and the outputs and the records ride\n  this commit. Three full runs read byte-identical across all five\n  outputs. Draft v0.48 takes the appendix pins and the tracker entry.\n  The corner-grid cite findings close (`8855d9a` to `cb862df`), and the\n  corner counter-reads take their closure (`857f2c1`, 153 checks).\n  Row 10\'s title takes the winner form: "hero" stops as a figure\n  label on the map. Next: the aero counter-read of the relabel and\n  the winner-form re-keys.'),
]))

DRAFT = "docs/reporting/drafts/2026-10-08-report-first-draft.md"
P.append((DRAFT, [
    ('Internal engineering report. Draft v0.47. Date 2026-10-14.',
     'Internal engineering report. Draft v0.48. Date 2026-10-14.'),
    ('| System anatomy plate | `scratch/fig1_decode_winner.jl` · `best_vector.csv` | NR-011, NR-017, NR-043 | `1af63fc` | `post-95c385d_wind-authority` |',
     '| System anatomy plate | `scratch/fig1_decode_winner.jl` · `best_vector.csv` | NR-011, NR-017, NR-043 | `' + S + '` | `post-95c385d_wind-authority` |'),
    ('- `png` `2b23851250839e9596e8e5076177a53c5c09103a16a7e246ab4e031a44730372`\n- `pdf` `85a2e369028268c2ade69f1743f5a3e11ca87b5b6fb1a1b8c1f728816bd519d6`\n- `ledger` `931dfb71aef8168329fa632bfa21d16a514b8036354fa013090cf2948301f7ae`\n- `checks` `ffea5637775ccbadbb12d37074eb86055d3e51ef579add03870873b04a47888b`',
     '- `png` `' + SHA["png"] + '`\n- `pdf` `' + SHA["pdf"] + '`\n- `ledger` `' + SHA["ledger"] + '`\n- `checks` `' + "%CHECKS%" + '`'),
]))

SEAT = "handovers/handover-2026-10-14-reporting-room-figures-images-diagrams.md"
P.append((SEAT, [
    ('This refresh records the round-6 counter-read fold-back and the corner-grid opening (2026-10-15).',
     'This refresh records the lifting-bridles relabel, the corner counter-read closure and the cite fixes (2026-10-15).'),
    ('1. **The corner build (map row 23).** The generator lands (`a4b4057`): four panels, all checks pass, the three-location F-REPRO walk holds. The counter-reads queue next (aero F-CITE and F-VALUE, the science register read).\n\n2. **The visual pass by Rod.** The five re-cut rows (2, 4, 6, 7 and 10) and the k-basis plate (row 5) read the visual pass as their next gate (map v38). The plates carry the round-6 top forms. The hero seat reads §3.3, ahead of the plates. It moves earlier in one line if the room calls.',
     '1. **The lifting-bridles relabel (map row 2).** The chain label lands (script `' + S + '`): the F1 plate reads "lifting bridles (three)". The caption text, the copy embed and the appendix exhibit name re-key at the author pass. The aero counter-read of the re-cut queues; the visual pass by Rod follows.\n\n2. **The winner-form re-keys (row 10).** The map title takes the winner form; the appendix exhibit name re-keys at the author pass. The aero counter-read queues.\n\n3. **The visual pass by Rod.** The corner grid, the winner plate, the F1 plate and rows 4 to 7 read the visual pass as their next gate (map v38, v39, v40). The plates carry the round-6 top forms. The winner plate reads §3.3, ahead of the plates. It moves earlier in one line if the room calls.'),
    ('## Closed, last (evidence index)\n\n- The corner grid builds (2026-10-15):',
     '## Closed, last (evidence index)\n\n- The lifting-bridles relabel lands (2026-10-15): the F1 chain label reads "lifting bridles (three)" (script `' + S + '`); three full runs byte-identical across all five outputs; the corner-grid cite findings close (`8855d9a` to `cb862df`) and the counter-reads fold back (`857f2c1`, 153 checks). Receipt `docs/reporting/room-responses/figures-images-diagrams-2026-10-15-lifting-bridles-relabel.md`. Evidence `scratch/fig_br_*` (run logs, md5 tables, the check set).\n\n- The corner grid builds (2026-10-15):'),
    ('**Owner:** @fig-img-diagrams (figures-images-diagrams). **Next action:** the corner-grid counter-reads (row 23) on the delivered bytes. The visual pass by Rod follows.',
     '**Owner:** @fig-img-diagrams (figures-images-diagrams). **Next action:** the aero counter-read of the F1 relabel and the winner-form re-keys (row 10). The visual pass by Rod follows.'),
]))

RS = "docs/reporting/figures/system-anatomy/register-status.md"
P.append((RS, [
    ('v5 re-cut 2026-10-14; v6 re-cut 2026-10-14.',
     'v5 re-cut 2026-10-14; v6 re-cut 2026-10-14; v7 re-cut 2026-10-15.'),
    ('runs stay byte-identical (verified at v6). Hashes at v6:',
     'runs stay byte-identical (verified at v7). Hashes at v7:'),
    ('7c5543ed335708bd8d570bc94919d8bf', MD5["tex"]),
    ('e775bc42a985f0457ae0e8f6d172920d', MD5["html"]),
    ('ae02f27f3ef73814df8b802c70b816ea', MD5["ledger"]),
    ('14fa8757b3b45d5b99f995f6e90eaa81', MD5["pdf"]),
    ('9e25520837da6931776e48c45e7fd62c', MD5["png"]),
    ('Script commit `1af63fc`. No new number. No other geometry moves.',
     'Script commit `1af63fc`. No new number. No other geometry moves.\n\nv7 (2026-10-15): the lifting-bridles relabel (the founder note of\n2026-10-15). The chain label reads "lifting bridles (three)". Script\ncommit `' + S + '`. No new number. No other geometry moves.'),
    ('**Delta** v4 (2026-10-14): the v6 re-cut lands. The R6 label takes the top\nform (round-6 comment 1). Script commit `1af63fc`. No value moves.',
     '**Delta** v4 (2026-10-14): the v6 re-cut lands. The R6 label takes the top\nform (round-6 comment 1). Script commit `1af63fc`. No value moves.\n**Delta** v5 (2026-10-15): the v7 re-cut lands. The chain label takes\nthe founder form. Script commit `' + S + '`. The caption sentence re-keys\nat the author pass. No value moves.'),
]))

CAP = "docs/reporting/figures/system-anatomy/captions.md"
P.append((CAP, [
    ('rows NR-011, NR-017, NR-043 · script commit `1af63fc` · full record: the',
     'rows NR-011, NR-017, NR-043 · script commit `' + S + '` · full record: the'),
    ('moves. The plate re-renders. The provenance token takes the round-6\nscript commit.',
     'moves. The plate re-renders. The provenance token takes the round-6\nscript commit.\n\nRelabel note (2026-10-15): the lifting-bridles relabel (the founder\nnote). The plate re-renders with the chain label "lifting bridles\n(three)". The caption text re-keys at the author pass. No value\nmoves.'),
]))

SPEC = "docs/reporting/figures/system-anatomy/SPEC.md"
P.append((SPEC, [
    ('load path: lifter, lift line, sky anchor, cyan line, lift bearing, bridles,',
     'load path: lifter, lift line, sky anchor, cyan line, lift bearing, lifting bridles,'),
    ('- Closed: the hub-name retirement (round-6, 2026-10-14). The R6 label\n  reads "R6, the topmost ring". No value moves.',
     '- Closed: the hub-name retirement (round-6, 2026-10-14). The R6 label\n  reads "R6, the topmost ring". No value moves.\n- The lifting-bridles relabel (2026-10-15): the chain label reads\n  "lifting bridles (three)" (the v7 re-cut). The caption text re-keys\n  at the author pass.'),
]))

CRS = "docs/reporting/figures/machine-corner-grid/register-status.md"
P.append((CRS, [
    ('Signed (science-validator, `8855d9a`)', 'Signed (science-validator, `cb862df`)'),
    ('**Delta** v1 (2026-10-15): created with the kit landing (family mode,\ncorner variant; SPEC delta D10). No drawn value moves after this cut.',
     '**Delta** v1 (2026-10-15): created with the kit landing (family mode,\ncorner variant; SPEC delta D10). No drawn value moves after this cut.\n\n**Delta** v2 (2026-10-15): the counter-reads close clean (`857f2c1`,\n153 checks): the picks and the objectives recompute from the raw draw\ncolumns; the extract binds at all 128 fields; the drawn text reads\nclean; two fresh runs byte-identical. The NR-051 cite takes the sign\ncommit `cb862df`. No drawn value moves.'),
]))

CREADME = "docs/reporting/figures/machine-corner-grid/README.md"
P.append((CREADME, [
    ('Next: the\ncounter-reads (aero F-CITE and F-VALUE, the science register read),\nthen the visual pass by Rod.',
     'The counter-reads\nclose clean (`857f2c1`, 153 checks). The NR-051 cite takes the sign\ncommit `cb862df`. Next: the visual pass by Rod.'),
]))

TRACKER = "docs/reporting/draft-tracker.md"
P.append((TRACKER, [
    ('No signed value changes.\n\n## 2. Working notes',
     'No signed value changes.\n\nv0.48 pass by @fig-img-diagrams (2026-10-15).\nThis pass re-pins the figure-provenance appendix to the delivered lifting-bridles system-anatomy re-cut.\nThe plate script-commit cell and its four output-hash cells take the delivered values.\nThe re-cut takes the chain label "lifting bridles (three)" (figure-map row 2; the founder note of 2026-10-15).\nNo value moves.\n\n## 2. Working notes'),
]))

# ---- phase 1: verify every pair, all files --------------------------------------
problems = []
for rel, pairs in P:
    fp = ROOT / rel
    txt = fp.read_text(encoding="utf-8")
    for old, new in pairs:
        n = txt.count(old)
        if n != 1:
            problems.append(f"{rel}: count={n} for: {old[:80]!r}")
if problems:
    print("VERIFY FAILED — nothing written")
    for p in problems:
        print(" ", p)
    sys.exit(1)
print("verify ok: all pairs match exactly once")

# ---- phase 2: the new checks.log first (draft needs its hash) -------------------
ck = ROOT / "docs/reporting/figures/system-anatomy/checks.log"
baseline = ck.read_text(encoding="utf-8")
assert baseline.startswith("F1 system-anatomy - checks log (figures seat, 2026-10-12)"), "checks.log baseline unexpected"
ck.write_text(new_checks_log(), encoding="utf-8")
checks_sha = hashlib.sha256(ck.read_bytes()).hexdigest()
print("checks.log rebuilt; sha256:", checks_sha)

# ---- phase 3: apply doc pairs ---------------------------------------------------
for rel, pairs in P:
    fp = ROOT / rel
    txt = fp.read_text(encoding="utf-8")
    for old, new in pairs:
        if "%CHECKS%" in new:
            new = new.replace("%CHECKS%", checks_sha)
        txt = txt.replace(old, new, 1)
    fp.write_text(txt, encoding="utf-8")
    print("applied:", rel, f"({len(pairs)} pairs)")

# ---- phase 4: manifest ----------------------------------------------------------
mf = ROOT / "docs/reporting/figures/system-anatomy/manifest.json"
obj = json.loads(mf.read_text(encoding="utf-8"))
obj["outputs"]["checks.log"] = checks_sha
obj["outputs"]["label-ledger.txt"] = SHA["ledger"]
obj["outputs"]["system-anatomy.pdf"] = SHA["pdf"]
obj["outputs"]["system-anatomy.png"] = SHA["png"]
obj["outputs"]["system-anatomy.tex"] = SHA["tex"]
obj["script"]["sha256"] = SHA["script"]
obj["script_commit"] = S
trail = "\n" if mf.read_text(encoding="utf-8").endswith("\n") else ""
mf.write_text(json.dumps(obj, indent=2, sort_keys=True) + trail, encoding="utf-8")
print("manifest.json rebuilt")

facts = {
    "script_commit": S,
    "md5": MD5, "sha256": SHA, "checks_log_sha256": checks_sha,
    "sites": {"map": FM, "draft": DRAFT, "seat": SEAT, "register_status": RS,
              "captions": CAP, "spec": SPEC, "corner_rs": CRS, "corner_readme": CREADME,
              "tracker": TRACKER},
}
(ROOT / "scratch/fig_br_facts.json").write_text(json.dumps(facts, indent=2) + "\n", encoding="utf-8")
print("facts written: scratch/fig_br_facts.json")

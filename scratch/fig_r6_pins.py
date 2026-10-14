#!/usr/bin/env python3
"""fig-r6 pins pass — the surfaces that cite script commit A (1af63fc).

- system-anatomy checks.log (surgical v6 update) + manifest (v6 pins)
- system-anatomy / ring-utilisation / twist-limit caption provenance tokens
- system-anatomy / ring-utilisation / twist-limit register-status
  (commands, re-cut lines, deltas)
- ring-utilisation SPEC v8, twist-limit SPEC v7
- machine-winner-hero register-status (header, command, re-cut line)

Run from the repo root after the stamped runs: /usr/bin/python3 scratch/fig_r6_pins.py
"""
import hashlib
import json
import re
import sys
from pathlib import Path

ROOT = Path(".")
SC = "1af63fc"
SA = ROOT / "docs/reporting/figures/system-anatomy"
KITS = {
    "sa": ROOT / "docs/reporting/figures/system-anatomy",
    "ru": ROOT / "docs/reporting/figures/ring-utilisation",
    "tl": ROOT / "docs/reporting/figures/twist-limit",
    "et": ROOT / "docs/reporting/figures/eval-timeline",
    "hero": ROOT / "docs/reporting/figures/machine-winner-hero",
}

def sha256(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest()

def md5s(kit, label):
    t = (ROOT / "scratch" / f"fig_r6_{kit}_{label}.md5").read_text().strip().splitlines()
    return {f: h for h, f in (l.split("  ") for l in t)}

# ── 1. system-anatomy checks.log (surgical v6 update) ─────────────────────
run1 = (ROOT / "scratch/fig_r6_sa_1.log").read_text()
gen_block = []
grab = False
for line in run1.splitlines():
    if line.startswith("self-checks ok:"):
        grab = True
    if grab:
        if line.startswith("generator exit="):
            break
        gen_block.append(line)
assert gen_block and "cone-ring leader clear" in gen_block[0], gen_block

cl = SA / "checks.log"
t = cl.read_text()
edits = [
    ("re-cut v5: the cone ring (R5) label joins the plate (round-5 founder comment 3); leader clearance asserts (script commit d243b37)\n",
     "re-cut v5: the cone ring (R5) label joins the plate (round-5 founder comment 3); leader clearance asserts (script commit d243b37)\n"
     f"re-cut v6: the hub-name retirement (round-6 founder comment 1); the R6 label reads 'R6, the topmost ring' (script commit {SC})\n"),
    ("== reproducibility ==\nre-cut v5: two full runs byte-identical across all five outputs\n",
     "== reproducibility ==\nre-cut v6: two full runs byte-identical across all five outputs\n"),
]
for old, new in edits:
    assert t.count(old) == 1, f"checks.log anchor count {t.count(old)}: {old[:70]!r}"
    t = t.replace(old, new)

# replace the generator block (self-checks … wrote label-ledger)
m = re.search(r"self-checks ok:.*?wrote label-ledger\.txt \(\d+ strings\)\n", t, flags=re.S)
assert m, "generator block not found"
t = t[:m.start()] + "\n".join(gen_block) + "\n" + t[m.end():]

# replace the hashes block
sa_md5s = md5s("sa", "1")
old_h = re.search(r"== hashes \(re-cut v5\) ==\n(?:[0-9a-f]{32}  .*\n){5}", t)
assert old_h, "v5 hash block not found"
new_block = "== hashes (re-cut v6) ==\n" + "\n".join(
    sa_md5s[f] + "  " + f for f in ["system-anatomy.tex", "prototype.html",
                                    "label-ledger.txt", "system-anatomy.pdf", "system-anatomy.png"]) + "\n"
t = t[:old_h.start()] + new_block + t[old_h.end():]
cl.write_text(t)
print("checks.log updated (v6 block)")

# ── 2. system-anatomy manifest (v6 pins) ──────────────────────────────────
man = json.loads((SA / "manifest.json").read_text())
man["script_commit"] = SC
man["script"]["sha256"] = sha256(SA / "system-anatomy.py")
man["outputs"] = {
    "checks.log": sha256(cl),
    "label-ledger.txt": sha256(SA / "label-ledger.txt"),
    "system-anatomy.pdf": sha256(SA / "system-anatomy.pdf"),
    "system-anatomy.png": sha256(SA / "system-anatomy.png"),
    "system-anatomy.tex": sha256(SA / "system-anatomy.tex"),
}
(SA / "manifest.json").write_text(json.dumps(man, indent=2, sort_keys=True) + "\n")
print("sa manifest pinned at", SC)

# ── 3. markdown pins (two-phase, count-asserted) ──────────────────────────
EDITS = {
    "docs/reporting/figures/system-anatomy/captions.md": [
        ("script commit `9cecee3` · full record: the", f"script commit `{SC}` · full record: the"),
    ],
    "docs/reporting/figures/system-anatomy/register-status.md": [
        ("Register fold and v4 re-cut 2026-10-13; v5 re-cut 2026-10-14.",
         "Register fold and v4 re-cut 2026-10-13; v5 re-cut 2026-10-14; v6 re-cut 2026-10-14."),
        ("runs stay byte-identical (verified at v5). Hashes at v5:\n\n"
         "    system-anatomy.tex  8a6d82b74dde69965e224d2ce3293ccf\n"
         "    prototype.html      8225ea742dd25566e8c79c41ae57bfdf\n"
         "    label-ledger.txt    9832c94065d2d817303c40ec19ccb350\n"
         "    system-anatomy.pdf  77701b4024b957af21e54ca06ecdbebc\n"
         "    system-anatomy.png  9be129933420343205aa8f2592905b51",
         "runs stay byte-identical (verified at v6). Hashes at v6:\n\n"
         f"    system-anatomy.tex  {sa_md5s['system-anatomy.tex']}\n"
         f"    prototype.html      {sa_md5s['prototype.html']}\n"
         f"    label-ledger.txt    {sa_md5s['label-ledger.txt']}\n"
         f"    system-anatomy.pdf  {sa_md5s['system-anatomy.pdf']}\n"
         f"    system-anatomy.png  {sa_md5s['system-anatomy.png']}"),
        ("asserts. Script commit `d243b37`. No other geometry moves. No new\nnumber prints.",
         "asserts. Script commit `d243b37`. No other geometry moves. No new\nnumber prints.\n"
         "\n"
         "v6 (2026-10-14): the hub-name retirement (round-6 comment 1). The R6\n"
         "label reads \"R6, the topmost ring\". Script commit "
         f"`{SC}`. No new number. No other geometry moves."),
        ("**Delta** v3 (2026-10-14): the v5 re-cut lands. The cone ring (R5) label\ndraws with its leader and clearance asserts. The label set reads\nthirteen. Script commit `d243b37`.",
         "**Delta** v3 (2026-10-14): the v5 re-cut lands. The cone ring (R5) label\ndraws with its leader and clearance asserts. The label set reads\nthirteen. Script commit `d243b37`.\n"
         f"**Delta** v4 (2026-10-14): the v6 re-cut lands. The R6 label takes the top\nform (round-6 comment 1). Script commit `{SC}`. No value moves."),
    ],
    "docs/reporting/figures/ring-utilisation/captions.md": [
        ("script commit `671ab96` · full record: the", f"script commit `{SC}` · full record: the"),
    ],
    "docs/reporting/figures/ring-utilisation/register-status.md": [
        ("ring-utilisation.py --script-commit 671ab96`", f"ring-utilisation.py --script-commit {SC}`"),
        ("**Delta** v3 (2026-10-14): the round-5 caption dedupe. The plain tier\nreads one takeaway sentence, and the tiers no longer repeat one claim.\nNo render moves.",
         "**Delta** v3 (2026-10-14): the round-5 caption dedupe. The plain tier\nreads one takeaway sentence, and the tiers no longer repeat one claim.\nNo render moves.\n"
         f"**Delta** v4 (2026-10-14): the hub-name retirement (round-6 comment 1).\nThe top ring label reads \"R6 (top)\"; the caption and record phrases\ntake the top forms. Script commit `{SC}`. No drawn value moves."),
    ],
    "docs/reporting/figures/ring-utilisation/SPEC.md": [
        ("- v7 (2026-10-14): the plain tier reads one takeaway sentence (the\n  round-5 caption dedupe). The tier no longer repeats the technical\n  claim. The caption plan updates with it. No render moves.",
         "- v7 (2026-10-14): the plain tier reads one takeaway sentence (the\n  round-5 caption dedupe). The tier no longer repeats the technical\n  claim. The caption plan updates with it. No render moves.\n"
         "- v8 (2026-10-14): the hub-name retirement sweep (round-6 comment 1).\n  The governs sentence takes the full name, the direction line takes\n  \"R6 at the top\", and the record phrases take the top forms. Script\n"
         f"  commit `{SC}`. No render value moves."),
    ],
    "docs/reporting/figures/twist-limit/captions.md": [
        ("script commit `671ab96` · full record: the", f"script commit `{SC}` · full record: the"),
    ],
    "docs/reporting/figures/twist-limit/register-status.md": [
        ("twist-limit.py --script-commit 671ab96`", f"twist-limit.py --script-commit {SC}`"),
        ("**Delta** v3 (2026-10-14): the round-5 caption dedupe. The plain tier\nreads one takeaway sentence, and the tiers no longer repeat one claim.\nNo render moves.",
         "**Delta** v3 (2026-10-14): the round-5 caption dedupe. The plain tier\nreads one takeaway sentence, and the tiers no longer repeat one claim.\nNo render moves.\n"
         f"**Delta** v4 (2026-10-14): the hub-name retirement (round-6 comment 1).\nThe top ring label reads \"R6 (top)\" and the subtitle reads \"ground to\ntop\". Script commit `{SC}`. No drawn value moves."),
    ],
    "docs/reporting/figures/twist-limit/SPEC.md": [
        ("- v6 (2026-10-14): the plain tier reads one takeaway sentence (the\n  round-5 caption dedupe). The tier no longer repeats the technical\n  claim. The caption plan updates with it. No render moves.",
         "- v6 (2026-10-14): the plain tier reads one takeaway sentence (the\n  round-5 caption dedupe). The tier no longer repeats the technical\n  claim. The caption plan updates with it. No render moves.\n"
         "- v7 (2026-10-14): the hub-name retirement sweep (round-6 comment 1).\n  The plate labels take the top forms (\"R6 (top)\", \"ground to top\"),\n  and the record phrases take \"top\". Script\n"
         f"  commit `{SC}`. No drawn value moves."),
    ],
    "docs/reporting/figures/machine-winner-hero/register-status.md": [
        ("**Date** 2026-10-14. **Script commit** `c438398`. First GENERATE `c438398`.",
         f"**Date** 2026-10-14. **Script commit** `{SC}`. First GENERATE `c438398`."),
        ("machine-winner-hero.jl --script-commit c438398`", f"machine-winner-hero.jl --script-commit {SC}`"),
        ("Self-check: three consecutive runs stay byte-identical across all five\noutputs. Verified 2026-10-14 at `c438398`.",
         "Self-check: three consecutive runs stay byte-identical across all five\noutputs. Verified 2026-10-14 at `c438398`.\n"
         "\n"
         "**Re-cut** v2 (2026-10-14): the hub-name retirement (round-6 comment 1).\n"
         "The drawn leader reads \"topmost ring R6\". The log line reads \"drawn\n"
         "topmost-ring altitude\". Three fresh runs at the v2 script commit stay\n"
         "byte-identical across all five outputs. No value moves."),
    ],
}

fails = []
for rel, pairs in EDITS.items():
    p = ROOT / rel
    t = p.read_text(encoding="utf-8")
    for old, new in pairs:
        c = t.count(old)
        if c != 1:
            fails.append(f"FAIL count {c} in {rel}: {old[:80]!r}")
if fails:
    print("\n".join(fails))
    sys.exit(1)
for rel, pairs in EDITS.items():
    p = ROOT / rel
    t = p.read_text(encoding="utf-8")
    for old, new in pairs:
        t = t.replace(old, new, 1)
    p.write_text(t, encoding="utf-8")
    print(f"pinned: {rel} ({len(pairs)} edits)")

# ── 4. print the delivered sha256 table (for the records pass) ────────────
print("\ndelivered sha256 table:")
for kit, kdir in KITS.items():
    outs = {
        "sa": ["system-anatomy.tex", "prototype.html", "label-ledger.txt", "system-anatomy.pdf", "system-anatomy.png"],
        "ru": ["ring-utilisation.svg", "ring-utilisation.pdf", "ring-utilisation.png", "label-ledger.txt", "manifest.json"],
        "tl": ["twist-limit.svg", "twist-limit.pdf", "twist-limit.png", "label-ledger.txt", "manifest.json"],
        "et": ["eval-timeline.svg", "eval-timeline.pdf", "eval-timeline.png", "label-ledger.txt", "manifest.json"],
        "hero": ["machine-winner-hero.png", "machine-winner-hero.svg", "machine-winner-hero.pdf", "checks.log", "manifest.json"],
    }[kit]
    for f in outs:
        print(f"  {kit:4s} {f:28s} {sha256(kdir / f)}")
print("pins pass complete.")

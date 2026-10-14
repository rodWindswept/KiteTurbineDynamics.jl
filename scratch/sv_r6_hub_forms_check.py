#!/usr/bin/env python3
# scratch/sv_r6_hub_forms_check.py — science-validator, 2026-10-14.
#
# The round-6 hub-forms census (read-only).  Maps every live "hub" site
# the retirement touches, grouped by surface, and checks the exemption
# set (code names, extract columns, the atlas gene label) and the held
# records.  Prints one line per check; exits nonzero on any fail.
import re
import subprocess
import sys
from pathlib import Path

R = Path(".")
n_ck = 0
n_fail = 0


def chk(name, cond, detail=""):
    global n_ck, n_fail
    n_ck += 1
    if not cond:
        n_fail += 1
    print(f"check: {name}: {'OK' if cond else 'FAIL'}  {detail}")


def lines_with(path, pat):
    p = R / path
    if not p.exists():
        return []
    out = []
    for i, ln in enumerate(p.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
        if re.search(pat, ln, re.I):
            out.append((i, ln.strip()))
    return out


def count_in_tree(root, pat, exts=(".jl", ".py", ".md", ".tex", ".txt", ".svg")):
    n = 0
    for p in (R / root).rglob("*"):
        if p.is_file() and p.suffix in exts:
            try:
                n += len(re.findall(pat, p.read_text(encoding="utf-8", errors="replace"), re.I))
            except Exception:
                pass
    return n


print("== 1. the draft sites ==")
draft = "docs/reporting/drafts/2026-10-08-report-first-draft.md"
sites = lines_with(draft, r"hub")
want_lines = [225, 319, 490, 505, 571, 612, 689, 786, 794, 807]
got_lines = [i for i, _ in sites]
print("draft hub lines:", got_lines)
for i, ln in sites:
    print(f"  L{i}: {ln[:110]}")
chk("draft carries exactly 10 hub sites", len(sites) == 10, f"got {len(sites)}")
chk("draft hub line set", sorted(got_lines) == want_lines, str(got_lines))
chk("draft already carries the short name",
    any("The topmost ring carries the main rotor" in ln for _, ln in lines_with(draft, r"topmost ring")))

print("\n== 2. the tracker and the candidates ==")
tr = lines_with("docs/reporting/draft-tracker.md", r"hub")
cd = lines_with("docs/reporting/glossary-candidates.md", r"hub")
print("tracker lines:", [i for i, _ in tr])
print("candidates lines:", [i for i, _ in cd])
chk("tracker carries 2 hub sites", len(tr) == 2, f"got {len(tr)}")
chk("candidates carry 2 hub sites", len(cd) == 2, f"got {len(cd)}")

print("\n== 3. the five plates, drawn text (pending re-cut targets) ==")
plate_checks = [
    ("system-anatomy label", "docs/reporting/figures/system-anatomy/label-ledger.txt", "R6, the hub ring"),
    ("ring-utilisation row", "docs/reporting/figures/ring-utilisation/label-ledger.txt", "R6 (hub)"),
    ("twist-limit row", "docs/reporting/figures/twist-limit/label-ledger.txt", "R6 (hub)"),
    ("twist-limit subtitle", "docs/reporting/figures/twist-limit/label-ledger.txt", "ground to hub"),
    ("eval-timeline rate", "docs/reporting/figures/eval-timeline/label-ledger.txt", "ω hub"),
    ("eval-timeline gates", "docs/reporting/figures/eval-timeline/label-ledger.txt", "hub · tip · Betz"),
    ("winner-hero leader", "docs/reporting/figures/machine-winner-hero/machine-winner-hero.jl", "hub ring R6"),
]
for name, path, s in plate_checks:
    p = R / path
    ok = p.exists() and s in p.read_text(encoding="utf-8", errors="replace")
    chk(f"drawn string present: {name}", ok, repr(s))

print("\n== 4. the three caption kits ==")
for kit in ("system-anatomy", "ring-utilisation", "machine-evolution-strip"):
    files = 0
    sites = 0
    for p in (R / "docs/reporting/figures" / kit).rglob("*.md"):
        hits = len(re.findall(r"hub", p.read_text(encoding="utf-8", errors="replace"), re.I))
        if hits:
            files += 1
            sites += hits
    print(f"  {kit}: {files} md files carry hub, {sites} sites")
    chk(f"kit carries hub: {kit}", files >= 1)

print("\n== 5. the exemption set (code names hold) ==")
code_names = ["r_hub", "hub_radius", "blade_hub_radius", "trpt_hub_radius", "omega_hub", "hub_ri"]
for nm in code_names:
    c = count_in_tree("src", re.escape(nm), (".jl",)) + count_in_tree("scripts", re.escape(nm), (".jl",))
    chk(f"code name present in tree: {nm}", c > 0, f"{c} sites")

print("\n== 6. the extract columns hold ==")
for path, s in [
    ("docs/reporting/figures/pair-extract/extract-winner-operating-point.csv", "hub"),
    ("docs/reporting/figures/window-trace-extract/extract-winner-window-taps.csv", "omega_hub"),
    ("docs/reporting/figures/pca-atlas/label-ledger.txt", "r_hub"),
]:
    p = R / path
    ok = p.exists() and s in p.read_text(encoding="utf-8", errors="replace")
    chk(f"extract/atlas carries: {s} ({Path(path).parent.name})", ok)

print("\n== 7. the held records ==")
reg = lines_with("docs/reporting/numbers-register.md", r"hub")
print(f"register hub lines: {len(reg)}")
chk("register text holds its spelling", len(reg) > 0, f"{len(reg)} sites")

print(f"\nCHECKER: {n_ck} checks, {n_fail} fail")
sys.exit(1 if n_fail else 0)

#!/usr/bin/env python3
"""Glossary v13 sim: status bump, pre-cone cross-term row edit + guards note, three era rows, delta. Assertion-guarded; writes sim file only."""
import subprocess, pathlib

SKILL = '/home/rod/.hermes/profiles/science-writer/skills/windswept/ktd-reporting'
path = 'docs/reporting/glossary-candidates.md'
head = subprocess.run(f"git show HEAD:{path}", shell=True, capture_output=True, text=True).stdout
cur = pathlib.Path(path).read_text()
assert cur == head, "working file differs from HEAD"
t = cur

# 1. status bump
old = "**Status** PREP v12,"
assert t.count(old) == 1, t.count(old)
t = t.replace(old, "**Status** PREP v13,")

# 2. guards note after the Lifter senses block
old = "Keep the two apart.\n\n## 3. Search and evaluation terms (Methods, U2 to U4)"
assert t.count(old) == 1
note = """Keep the two apart.

**Pre-cone cross-term guards (draft note).**

- The AeroDyn pre-cone is the equivalent term for the bank angle.
  The draft carries the bridge at section 2.1.

- The record keeps two open items outside the bridge: the pivot, and the
  pre-cone radius convention.

- Entries and prose avoid "identical geometry" forms, and "shaft tilt"
  is never the bank form, because it carries the elevation. Where
  prose describes the measurement itself, keep the record phrase: the
  closest AeroDyn analogue.

## 3. Search and evaluation terms (Methods, U2 to U4)"""
t = t.replace(old, note)

# 3. bank angle row takes the cross-term
old = "| bank angle (bank) | The angle of a blade out of its ring plane. Bank is not elevation, and it is not yaw. | physics-topology 4 | ratify |"
assert t.count(old) == 1
new = "| bank angle (bank) | The angle of a blade out of its ring plane. Bank is not elevation, and it is not yaw. The equivalent term in AeroDyn is pre-cone. | physics-topology 4, the pre-cone read (`2db50f9`), draft v0.28 | ratify |"
t = t.replace(old, new)

# 4. three era rows after the fold row
old = "| the fold | The rebase of the lowest power rung onto the S2-class fold seed. The ceiling genes fold up, and the bounds recenter. | DECISIONS [2026-10-05] | room-supplies |\n"
assert t.count(old) == 1
new = old + """| cp fix | The Cp-surface correction, landed at `a82cafd`. The length screen ran on both sides of it (NR-027). | register NR-027, `docs/validation/2026-10-05-cp-span-structure-and-resize.md` | supply |
| folded class | The class of designs the campaign searched after the S2 fold rebase. The folded class clears the power floor at the screened length (NR-028). | register NR-028, `docs/validation/2026-10-05-s2-fold-flight.md`, draft section 2.3 | supply |
| wind authority | The single wind source the scored results read: the site wind standard. The shear exponent comes from the site spec (`95c385d`). The era label `post-95c385d_wind-authority` names it in the register header and every provenance stamp. | register header, DECISIONS [2026-10-03], provenance stamps | supply |
"""
t = t.replace(old, new)

# 5. delta bullet
old = "(NR-040, from NR-023). No other change.\n"
assert t.count(old) == 1
new = old + """
- **v13 (2026-10-13):** three era names join the trust-and-record group,
  routed by the era-map name check (SW3b): cp fix, folded class and
  wind authority. The bank angle row takes the AeroDyn pre-cone
  cross-term, with a guards note. No other change.
"""
t = t.replace(old, new)

pathlib.Path('scratch/sw_glossv13_new.md').write_text(t)
pathlib.Path('scratch/sw_glossv13_base.md').write_text(cur)

def sh(cmd):
    return subprocess.run(cmd, shell=True, capture_output=True, text=True)

for tag, f in [('base', 'scratch/sw_glossv13_base.md'), ('new', 'scratch/sw_glossv13_new.md')]:
    r = sh(f"python3 ste-lint.py --fail-above 2.0 {f}")
    print(f"--- {tag} lint rc={r.returncode}")
    print(r.stdout.strip())
    r2 = sh(f"python3 {SKILL}/scripts/lint-offenders.py ste-lint.py {f}")
    pathlib.Path(f'scratch/sw_glossv13_off_{tag}.txt').write_text(r2.stdout)

d = pathlib.Path('scratch/sw_glossv13_off_base.txt').read_text().splitlines()
o = pathlib.Path('scratch/sw_glossv13_off_new.txt').read_text().splitlines()
delta = [l for l in o if l not in d]
print("--- offender delta base->new:")
for l in delta:
    print("   >", l)
if not delta:
    print("   NIL")
print("done")

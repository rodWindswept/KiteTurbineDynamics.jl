#!/usr/bin/env python3
"""Final sims for the SW3b/SW3a table supplies, reading the frozen table strings."""
import subprocess, pathlib

SKILL = '/home/rod/.hermes/profiles/science-writer/skills/windswept/ktd-reporting'

base = pathlib.Path('scratch/sw_sweep16_draft_v028.md').read_text()
era_table = pathlib.Path('scratch/sw_sw3b_era_table.md').read_text().rstrip("\n")
ledger_table = pathlib.Path('scratch/sw_ws3a_ledger_table.md').read_text().rstrip("\n")

era_anchor = "space. Numbers across the eras would compare models, not machines.\n"
assert base.count(era_anchor) == 1, f"era anchor {base.count(era_anchor)}"
erasim = base.replace(era_anchor, era_anchor + "\n" + era_table + "\n")

l_anchor = "Candidate entries. Each failure enters with its lesson.\n"
assert base.count(l_anchor) == 1, f"ledger anchor {base.count(l_anchor)}"
lsim = base.replace(l_anchor, l_anchor + "\n" + ledger_table + "\n")

pathlib.Path('scratch/sw_sw3b_erasim.md').write_text(erasim)
pathlib.Path('scratch/sw_ws3a_ledgersim.md').write_text(lsim)

def sh(cmd):
    return subprocess.run(cmd, shell=True, capture_output=True, text=True)

for tag, path in [('erasim', 'scratch/sw_sw3b_erasim.md'), ('ledgersim', 'scratch/sw_ws3a_ledgersim.md')]:
    r = sh(f"python3 ste-lint.py --fail-above 2.0 {path}")
    print(f"--- {tag} lint rc={r.returncode}")
    print(r.stdout.strip())
    r2 = sh(f"python3 {SKILL}/scripts/lint-offenders.py ste-lint.py {path}")
    pathlib.Path(f'scratch/sw_{tag}_off.txt').write_text(r2.stdout)

# offender deltas vs current draft
def off(path):
    return pathlib.Path(path).read_text().splitlines()

d = off('scratch/sw_sweep16_off_v028.txt')
for tag in ['erasim', 'ledgersim']:
    o = off(f'scratch/sw_{tag}_off.txt')
    delta = [l for l in o if l not in d]
    print(f"--- {tag} delta vs v0.28 draft:")
    for l in delta:
        print("   >", l)
print("done")

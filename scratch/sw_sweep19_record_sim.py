#!/usr/bin/env python3
"""Sweep 19 record-section sim: append section to the committed record, lint both, diff offenders."""
import subprocess, pathlib

SKILL = '/home/rod/.hermes/profiles/science-writer/skills/windswept/ktd-reporting'

base = subprocess.run("git show HEAD:docs/reporting/draft-consistency-sweep.md",
                      shell=True, capture_output=True, text=True).stdout
section = pathlib.Path('scratch/sw_sweep19_section.md').read_text()

assert base.rstrip().endswith("**Next run** at the next draft push."), "record tail unexpected"
new = base.rstrip("\n") + "\n\n" + section

pathlib.Path('scratch/sw_sweep19_record_base.md').write_text(base)
pathlib.Path('scratch/sw_sweep19_record_new.md').write_text(new)

def sh(cmd):
    return subprocess.run(cmd, shell=True, capture_output=True, text=True)

for tag, f in [('base', 'scratch/sw_sweep19_record_base.md'), ('new', 'scratch/sw_sweep19_record_new.md')]:
    r = sh(f"python3 ste-lint.py --fail-above 2.0 {f}")
    print(f"--- {tag} lint rc={r.returncode}")
    print(r.stdout.strip())
    r2 = sh(f"python3 {SKILL}/scripts/lint-offenders.py ste-lint.py {f}")
    pathlib.Path(f'scratch/sw_sweep19_record_off_{tag}.txt').write_text(r2.stdout)

d = pathlib.Path('scratch/sw_sweep19_record_off_base.txt').read_text().splitlines()
o = pathlib.Path('scratch/sw_sweep19_record_off_new.txt').read_text().splitlines()
delta = [l for l in o if l not in d]
print("--- offender delta base->new:")
for l in delta:
    print("   >", l)
print("done")

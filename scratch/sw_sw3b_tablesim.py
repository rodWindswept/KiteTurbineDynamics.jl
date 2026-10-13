#!/usr/bin/env python3
"""SW3b/SW3a table supplies: insertion sims + STE probes (read-only sims; no shared-tree writes)."""
import subprocess, pathlib

SKILL = '/home/rod/.hermes/profiles/science-writer/skills/windswept/ktd-reporting'

base = pathlib.Path('scratch/sw_sweep16_draft_v028.md').read_text()

era_table = """| Era | Effect on the search space | Data status |
|---|---|---|
| Before the bank derate | Earlier winners read different bank-angle physics, so they are not directly comparable. | Superseded as era record. |
| The bank-derate basis | The measured bank derate applies to main-rotor disc power throughout (NR-019, NR-020). | Current campaign basis. |
| The cp fix and the folded class | The span shrink and the cp fix moved the screen readings. The pre-fold rows failed the floor (NR-027). | Recorded. The folded class passes at 18.8 metres (NR-028). |
| The wind-authority era (`post-95c385d_wind-authority`) | One wind authority reads the scored results. | Current physics era. |"""

ledger_table = """| Date / event | Class | What happened | Detection | Correction / lesson | Status |
|---|---|---|---|---|---|
| 2026-08-14 inverted-taper divergence | Geometry/decoder failure | An invalid genome diverged while the ground instruments still read normal power. | Divergence review | The decoder must refuse what the builder cannot make, at gate time. | Lesson applied. |
| 2026-08-26 rotor-to-ring off-by-one | Decoder mapping error | The middle rotor landed on the hub. | Visual geometry check (`preview_genome_geometry.jl`) | Validate the rotor-to-ring map against the built geometry. | Corrected. |
| 2026-08-22 blade-mass-law correction | Model correction | The correction voided prior campaign winners. | Physics review | Void the affected data and keep the record. | Data voided, record kept. |
| 2026-08-13 k-alignment fault | Gain misalignment | The evaluator ran 5-kilowatt designs at the 50-kilowatt default gain. The scaled system gain sat near 1.94. | Acceptance test | One constant, one source file. | Caught and corrected. |
| 2026-08-24 stale-gain re-gate | Stale configuration | The winner re-gate ran at a superseded gain. | Pre-push review | The re-gate at the campaign gain returned 5.18 kilowatts. | Corrected. |
| 2026-08-22 FoS=Inf guard gap | Gate near-miss | The guard was missing from several scoring paths. | Telemetry review | A gate must pin a measured number, so drift fails the suite. | Near-miss, no corrupted survivor found. |"""

era_anchor = "space. Numbers across the eras would compare models, not machines.\n"
assert base.count(era_anchor) == 1, f"era anchor count {base.count(era_anchor)}"
erasim = base.replace(era_anchor, era_anchor + "\n" + era_table + "\n")

l_anchor = "Candidate entries. Each failure enters with its lesson.\n"
assert base.count(l_anchor) == 1, f"ledger anchor count {base.count(l_anchor)}"
lsim = base.replace(l_anchor, l_anchor + "\n" + ledger_table + "\n")

pathlib.Path('scratch/sw_sw3b_erasim.md').write_text(erasim)
pathlib.Path('scratch/sw_ws3a_ledgersim.md').write_text(lsim)
pathlib.Path('scratch/sw_sw3b_era_table.md').write_text(era_table + "\n")
pathlib.Path('scratch/sw_ws3a_ledger_table.md').write_text(ledger_table + "\n")

def sh(cmd):
    return subprocess.run(cmd, shell=True, capture_output=True, text=True)

for tag, path in [('erasim', 'scratch/sw_sw3b_erasim.md'), ('ledgersim', 'scratch/sw_ws3a_ledgersim.md')]:
    r = sh(f"python3 ste-lint.py --fail-above 2.0 {path}")
    print(f"--- {tag} lint rc={r.returncode}")
    print(r.stdout.strip()); print(r.stderr.strip())
    r2 = sh(f"python3 {SKILL}/scripts/lint-offenders.py ste-lint.py {path}")
    pathlib.Path(f'scratch/sw_{tag}_off.txt').write_text(r2.stdout)
    print(f"--- {tag} offenders:")
    print(r2.stdout)
print("done")

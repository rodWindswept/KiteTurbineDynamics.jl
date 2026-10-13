#!/usr/bin/env python3
"""Chunk checker for the SW3b/SW3a table candidates. Prints per-chunk word counts using the real ste-lint logic."""
import importlib.util, re, pathlib

spec = importlib.util.spec_from_file_location('stelint', 'ste-lint.py')
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)

era = """| Era | Effect on the search space | Data status |
|---|---|---|
| Before the bank derate | Earlier winners read different bank-angle physics, so they are not directly comparable. | Superseded as era record. |
| The bank-derate basis | The measured bank derate applies to main-rotor disc power throughout (NR-019, NR-020). | Current campaign basis. |
| The cp fix and the folded class | The span shrink and the cp fix moved the screen readings. The pre-fold rows failed the floor (NR-027). | Recorded: the folded class passes at 18.8 metres (NR-028). |
| The wind-authority era (`post-95c385d_wind-authority`) | One wind authority reads the scored results. | Current physics era. |"""

ledger = """| Date / event | Class | What happened | Detection | Correction / lesson | Status |
|---|---|---|---|---|---|
| 2026-08-14 inverted-taper divergence | Geometry/decoder failure | An invalid genome diverged within seconds. The ground instruments still read normal power. | Divergence review | The decoder must refuse what the builder cannot make. The refusal lands at gate time. | Lesson applied. |
| 2026-08-26 rotor-to-ring off-by-one | Decoder mapping error | The middle rotor landed on the hub. Every expansion rotor shifted one ring. | Visual geometry check (`preview_genome_geometry.jl`) | Validate the rotor-to-ring map against the built geometry. | Corrected. |
| 2026-08-22 blade-mass-law correction | Model correction | The correction voided prior campaign winners. | Physics review | Void the affected data. Keep the record. | Data voided, record kept. |
| 2026-08-13 k-alignment fault | Gain misalignment | The evaluator ran 5-kilowatt designs at the 50-kilowatt default gain. The scaled system gain sat near 1.94. | Acceptance test | One constant, one source file. | Caught and corrected. |
| 2026-08-24 stale-gain re-gate | Stale configuration | The winner re-gate ran at a superseded gain. The check caught it. | Pre-push review | The re-gate at the campaign gain returned 5.18 kilowatts. | Corrected. |
| 2026-08-22 FoS=Inf guard gap | Gate near-miss | The guard never reached several scoring paths. The re-gate screens winners. | Telemetry review | A gate must pin a measured number. Drift must fail the suite. | Near-miss, no corrupted survivor found. |"""

pathlib.Path('scratch/sw_sw3b_era_table.md').write_text(era + "\n")
pathlib.Path('scratch/sw_ws3a_ledger_table.md').write_text(ledger + "\n")

for name, block in [('era', era), ('ledger', ledger)]:
    sents = m.sentences(m.strip_code(block))
    flag = "STRUCTURAL FLAG +1" if len(sents) > 6 else "no structural flag"
    over = [(m.wc(s), s) for s in sents if m.wc(s) > 20]
    print(f"== {name}: {len(sents)} chunks -> {flag}; over-20 chunks: {len(over)}")
    for s in sents:
        mark = " <<<" if m.wc(s) > 20 else ""
        print(f"  [{m.wc(s):2d}w] {s[:120]}{mark}")
    r = m.lint(block)
    print("  lint:", {k: v for k, v in r['violations'].items() if v})
print("done")

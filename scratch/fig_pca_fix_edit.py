#!/usr/bin/python3
# -*- coding: utf-8 -*-
"""The levers fix pass (figures seat, 2026-10-14): generator edits.

Edits the two PCA generators exactly once each, with assertions, for the
recut directed by the F-VALUE counter-read (aero-validator, `331f60d`):

1. `ROWS` takes NR-044 on both generators, and NR-045 on the landscape
   (its journey inset draws the signed generation count).
2. The landscape `stamp2` leaves the pending form and takes its signed
   form (variance shares NR-044).
3. `register_rows` in both manifests takes the same sets, and
   `ROW_WANTS` empties (NR-044 signed at `2ad023c`).
4. The landscape checks gain the two drawn share forms (22.4 / 17.3)
   and the generation-count check (31 per island, NR-045).

Run: /usr/bin/python3 scratch/fig_pca_fix_edit.py
"""
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
KITS = {"pca-landscape": REPO / "docs/reporting/figures/pca-landscape/pca-landscape.py",
        "pca-atlas": REPO / "docs/reporting/figures/pca-atlas/pca-atlas.py"}

EDITS = {
    "pca-landscape": [
        ('ROWS = "NR-001, NR-005, NR-006"',
         'ROWS = "NR-001, NR-005, NR-006, NR-044, NR-045"'),
        ('ROW_WANTS = ["PCA projection summary (variance shares)"]',
         'ROW_WANTS = []'),
        ('    stamp2 = ("projection: z-scored 10-gene matrix, SVD · variance shares "\n'
         '              f"pending their row · script commit {args.script_commit}")',
         '    stamp2 = ("projection: z-scored 10-gene matrix, SVD · variance shares "\n'
         '              f"NR-044 · script commit {args.script_commit}")'),
        ('        ("PC2 share (2 dp)", round(float(var[1]) * 100, 2), 17.26),\n',
         '        ("PC2 share (2 dp)", round(float(var[1]) * 100, 2), 17.26),\n'
         '        ("PC1 share (1 dp drawn)", f"{var[0]*100:.1f}", "22.4"),\n'
         '        ("PC2 share (1 dp drawn)", f"{var[1]*100:.1f}", "17.3"),\n'),
        ('        ("feasible rows", int(feas.sum()), 508),\n',
         '        ("feasible rows", int(feas.sum()), 508),\n'
         '        ("generation indices per island",\n'
         '         [len(np.unique(gen[isl_a == i])) for i in ISLANDS], [31, 31, 31]),\n'),
        ('            "register_rows": ["NR-001", "NR-005", "NR-006"],',
         '            "register_rows": ["NR-001", "NR-005", "NR-006", "NR-044",\n'
         '                              "NR-045"],'),
    ],
    "pca-atlas": [
        ('ROWS = "NR-001, NR-005, NR-006"',
         'ROWS = "NR-001, NR-005, NR-006, NR-044"'),
        ('ROW_WANTS = ["PCA projection summary (variance shares)"]',
         'ROW_WANTS = []'),
        ('            "register_rows": ["NR-001", "NR-005", "NR-006"],',
         '            "register_rows": ["NR-001", "NR-005", "NR-006", "NR-044"],'),
    ],
}

def main() -> int:
    for slug, path in KITS.items():
        text = path.read_text()
        for old, new in EDITS[slug]:
            n = text.count(old)
            assert n == 1, (slug, n, old[:60])
            text = text.replace(old, new)
        path.write_text(text)
        print(f"edited: {path.relative_to(REPO)}  ({len(EDITS[slug])} edits)")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())

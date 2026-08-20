#!/usr/bin/env python3
# check-provenance.py — deterministic sensor: campaign CSVs must carry provenance.
# Version: 0.1.0 | Date: 2026-08-20 | Author: Windswept & Interesting
#
# Fires [HOOK:provenance] for any campaign result CSV missing a provenance
# header (a comment line with era= and git=) or provenance columns
# (physics_era / git_hash / genome_hash). Only CSVs that look like campaign
# results (carry x1..x14 or a genome_hash) are checked — internal files like
# convergence.csv are skipped. Exit 0 = clean, 1 = hooks fired.
import sys, os

CAMPAIGN_SIGNALS = ["x1", "genome_hash"]

def read_head(path, n=5):
    with open(path, errors="replace") as fh:
        return [fh.readline() for _ in range(n)]

def is_campaign_csv(head):
    for line in head:
        if line.lstrip().startswith("#"):
            continue
        low = line.lower()
        if any(s in low for s in CAMPAIGN_SIGNALS):
            return True
        break
    return False

def has_provenance(head):
    for line in head:
        stripped = line.lstrip()
        if stripped.startswith("#"):
            if "era=" in line and "git=" in line:
                return True
        else:
            cols = [c.strip().lower() for c in line.replace("\t", ",").split(",")]
            if any(c in cols for c in ("physics_era", "git_hash", "genome_hash")):
                return True
            break
    return False

def main(paths):
    fired = False
    for p in paths:
        if not os.path.isfile(p) or not p.lower().endswith(".csv"):
            continue
        head = read_head(p)
        if not is_campaign_csv(head):
            continue
        if not has_provenance(head):
            fired = True
            print(f"[HOOK:provenance] {p} missing provenance header -> add: git hash + physics era + geometry fingerprint (habit-hook-provenance)")
    return 1 if fired else 0

if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

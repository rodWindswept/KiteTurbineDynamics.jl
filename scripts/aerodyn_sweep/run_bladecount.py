#!/usr/bin/env python3
"""Run the blade-count variants of the precone sweep.

12 drivers: 2 variants (6 blades at full chord, 6 blades at half chord) times
6 precone angles, each stepping TSR 2 to 8.
"""

import glob
import os
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
# Moved here 2026-10-01 from .scratch/bem_regression/precone_sweep (gitignored).
# In scripts/aerodyn_sweep/ the repo root is two levels up, not three.
REPO_ROOT = os.path.dirname(os.path.dirname(HERE))
# Working directory holding deck/ (generated AeroDyn inputs, ~94 MB) and results/.
# Defaults to the historical location so the existing sweep data still resolves.
# Override to reproduce the sweep somewhere else:
#     AERODYN_SWEEP_WORK=/tmp/sweep python3 scripts/aerodyn_sweep/run_sweep.py
WORK = os.environ.get(
    "AERODYN_SWEEP_WORK",
    os.path.join(REPO_ROOT, ".scratch", "bem_regression", "precone_sweep"),
)
DECK = os.path.join(WORK, "deck")
DRIVER = os.path.expanduser("~/bin/aerodyn_driver")


def main():
    subprocess.run(
        [sys.executable, "gen_bladecount_drivers.py"], cwd=HERE, check=True
    )

    drivers = sorted(glob.glob(os.path.join(DECK, "ad_b6c*_pc[0-9][0-9].inp")))
    print(f"{len(drivers)} driver files", flush=True)

    t_all = time.time()
    for path in drivers:
        name = os.path.basename(path)
        t0 = time.time()
        res = subprocess.run([DRIVER, name], cwd=DECK, capture_output=True, text=True)
        ok = "terminated normally" in res.stdout
        print(f"{name:26s} exit={res.returncode} normal={ok} {time.time() - t0:6.1f}s",
              flush=True)
        if res.returncode != 0 or not ok:
            print("  --- stdout tail ---", flush=True)
            print("\n".join(res.stdout.splitlines()[-20:]), flush=True)

    print(f"\nfinished in {time.time() - t_all:.1f}s", flush=True)
    outs = sorted(glob.glob(os.path.join(DECK, "ad_b6c*.out")))
    print(f"{len(outs)} output files", flush=True)


if __name__ == "__main__":
    main()

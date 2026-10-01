#!/usr/bin/env python3
"""Rewrite the leading '#' provenance block of the reference CSVs.

The repo stamps generated CSVs with ONE banner line of key=value pairs,
including `git=` and `era=` — see `scripts/results/**/telemetry.csv`.  The
reference CSVs in `docs/validation/trpt-reference/` keep that banner shape and
add a few detail lines, because a reader needs the source deck and the budget to
reproduce them.

`git=` names the tree the measurement was made on, not necessarily the commit
that carries this file.  The generator scripts land in a later commit.

Idempotent: it strips every leading '#' line and rewrites the block, so it can
be re-run after a later measurement.

Usage:  python3 stamp_reference_csvs.py [git-hash]
"""

import os
import subprocess
import sys

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
REPO = os.path.abspath(REPO_ROOT)

BANNERS = {
    "docs/validation/trpt-reference/02-reference-values.csv": [
        "# trpt-reference-values  source=O-Tulloch-PhD-Strathclyde-2021  extract=docs/validation/tulloch-thesis-extract.txt  rows=22  status=MATCH|OPEN  rule=no-physics-claim-in-src-without-a-row-here  git={git}",
        "# Every row is transcribed from the printed text or a printed figure, and cites the page and the printed sentence in `source`.",
        "# status MATCH means our code agrees within `tolerance`.  status OPEN means the value is printed and we have not asserted it.",
        "# `git=` names the tree the transcription was last checked against.",
    ],
    "docs/validation/trpt-reference/10-precone-sweep.csv": [
        "# aerodyn-precone-yaw-sweep  rotor=daisy-mvp  n_blades=3  R_m=4.0  chord_m=0.500  twist_deg=0  wind_ms=8.0  shfttilt_deg=0  lam=2,3,4,5,6,7,8  angles_deg=precone:0,5,10,15,20,25+yaw:0,5,10,15,20,25  cases=84  sim_s=5.0  tool=aerodyn_driver-v5.0.0  git={git}",
        "# tool sha256 787e23f4871255a76fcbd3f66b7e4fce0a8a1c1d168cad3094adbb0d897cd246",
        "# geometry fingerprint n_blades=3 R=4.0000 span=3.0000 chord=0.5000 twist=0.0 area=50.26548 m2",
        "# physics BEMT WakeMod=1, SkewMod=2 Pitt/Peters, AFAeroMod=2 unsteady, UA_Mod=3, no tower",
        "# budget 84 cases x 5.0 s at dT=2.314858e-3 s, last timestep; worst |dCp| over the final 200 steps = 3.4e-3",
        "# alignment rows align on the COMMANDED lambda; AeroDyn RtTSR uses an angle-dependent reference length",
        "# generators scripts/aerodyn_sweep/gen_precone_drivers.py, run_sweep.py, parse_sweep.py, plot_sweep.py",
    ],
    "docs/validation/trpt-reference/11-blade-count-sweep.csv": [
        "# aerodyn-blade-count-sweep  rotor=daisy-mvp-6blade  wind_ms=8.0  shfttilt_deg=0  lam=2,3,4,5,6,7,8  angles_deg=precone:0,5,10,15,20,25  sim_s=5.0  tool=aerodyn_driver-v5.0.0  git={git}",
        "# variants b6c100 = 6 blades at chord 0.500 m (solidity doubled); b6c050 = 6 blades at chord 0.250 m (solidity matches the 3-blade rotor)",
        "# tool sha256 787e23f4871255a76fcbd3f66b7e4fce0a8a1c1d168cad3094adbb0d897cd246",
        "# physics BEMT WakeMod=1, SkewMod=2 Pitt/Peters, AFAeroMod=2 unsteady, UA_Mod=3, no tower",
        "# generators scripts/aerodyn_sweep/gen_bladecount_drivers.py, run_bladecount.py",
    ],
}


def head_hash():
    out = subprocess.run(
        ["git", "-C", REPO, "rev-parse", "--short=12", "HEAD"],
        capture_output=True, text=True,
    )
    return out.stdout.strip() or "unknown"


def main():
    git = sys.argv[1] if len(sys.argv) > 1 else head_hash()
    for rel, template in BANNERS.items():
        path = os.path.join(REPO, rel)
        if not os.path.exists(path):
            print(f"skip (absent): {rel}")
            continue
        with open(path, newline="") as fh:
            lines = fh.read().split("\n")
        body = [ln for ln in lines if not ln.startswith("#")]
        while body and body[0].strip() == "":
            body.pop(0)
        banner = [ln.format(git=git) for ln in template]
        with open(path, "w", newline="") as fh:
            fh.write("\n".join(banner + body))
        print(f"stamped {rel}  ({len(body) - 1} data rows, git={git})")


if __name__ == "__main__":
    main()

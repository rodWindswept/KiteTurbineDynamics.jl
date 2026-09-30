#!/usr/bin/env python3
"""Generate AeroDyn v5.0.0 driver files for a precone (bank) sweep.

Why this exists
---------------
The KTD disc model ignores bank entirely.  The banked expansion model brakes at
high solidity.  Neither is validated, so the question "what does a ~20 deg banked
rotor actually deliver?" has no measured answer.

AeroDyn answers it: `Precone` cones the blade out of the rotor plane, which is
what a banked blade is.  With `SkewMod=2` (Pitt/Peters) the induced-velocity
model already handles the misalignment, so Cp comes out skewed, not planar.

Columns are looked up BY NAME, never by index.  The repo skill's hard-coded
indices (Cp=18, Ct=20, TSR=31) do not match this v5.0.0 output, where they are
Cp=23, Ct=25, TSR=27.  A wrong index returns a plausible-looking number from the
wrong channel.

Usage
-----
    python3 gen_precone_drivers.py            # write every driver file
    python3 gen_precone_drivers.py validate   # write only the one test file
"""

import os
import re
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
DECK = os.path.join(HERE, "deck")          # the verified input set, copied in
TEMPLATE = "ad_driver_v5.inp"

# The verified deck and the binary live on the NAS copy of the AeroDyn
# knowledge dir, so a fresh clone can regenerate every driver file without the
# author's scratch tree.  Override with AERODYN_DECK.
DECK_SRC = os.environ.get(
    "AERODYN_DECK",
    "/mnt/Windswept Energy/_hermes_brain/KNOWLEDGE/aerodyn-v5.0.0",
)
DECK_FILES = (
    "ad_driver_v5.inp",
    "ad_primary_MVP.inp",
    "ad_blade_MVP.inp",
    "ad_airfoil_Rigid.inp",
)

# --- the sweep ---------------------------------------------------------------
# TSR is what the BEM tables are keyed on, so sweep TSR and vary only the angle.
TSRS = [2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0]

# Blade radius = HubRad + blade span = 1.0 + 3.0 m, and the output confirms it:
# RtArea = 50.2654 m^2 = pi * 4.0^2.
RADIUS = 4.0
WIND = 8.0

PRECONES = [0.0, 5.0, 10.0, 15.0, 20.0, 25.0]   # bank angles, degrees
YAWS = [0.0, 5.0, 10.0, 15.0, 20.0, 25.0]        # the cos^3(beta) analogue

DT = 2.314858e-03
TMAX = 5.0


def rotspd_rpm(tsr, tilt_deg):
    """TSR = omega*R/v_axial, and v_axial = wind * cos(tilt).  -> rpm."""
    import math

    v_ax = WIND * math.cos(math.radians(abs(tilt_deg)))
    omega = tsr * v_ax / RADIUS
    return omega * 60.0 / (2.0 * math.pi)


def case_row(hwnd, tsr, tilt_deg, pitch, yaw):
    return (
        f"{hwnd:.6E} {0.0:.6E} {rotspd_rpm(tsr, tilt_deg):.6E} "
        f"{pitch:.6E} {yaw:.6E} {DT:.6E} {TMAX:.6E} "
        f"{0.0:.6E} {0.0:.6E} {0.0:.6E}"
    )


def build_driver(out_path, precone, tilt_deg, cases, pitch=3.0):
    """cases: list of (tsr, yaw).  Writes one driver file."""
    with open(os.path.join(DECK, TEMPLATE)) as fh:
        lines = fh.read().split("\n")

    out = []
    for ln in lines:
        if re.search(r"\bPrecone\(1\)", ln):
            out.append(f"{precone:g}    Precone(1)     - Blade precone (deg)")
        elif re.search(r"\bShftTilt\(1\)", ln):
            out.append(f"{tilt_deg:g}    ShftTilt(1)     - Shaft tilt (deg)")
        elif re.search(r"\bNumCases\b", ln):
            out.append(f"{len(cases)}  NumCases     - Number of cases to run")
        else:
            out.append(ln)

    # Replace the single case row that follows the two case-table header lines.
    text = "\n".join(out)
    rows = [case_row(WIND, tsr, tilt_deg, pitch, yaw) for tsr, yaw in cases]
    text = re.sub(
        r"(\(m/s\)\s+\(-\)\s+\(rpm\)\s+\(deg\)\s+\(deg\)\s+\(s\)\s+\(s\)\s+\(-\)\s+\(m or rad\)\s+\(Hz\)\n)"
        r"(?:[^\n]*\n)",
        lambda m: m.group(1) + "\n".join(rows) + "\n",
        text,
        count=1,
    )
    with open(out_path, "w") as fh:
        fh.write(text)
    return out_path


def main():
    validate = len(sys.argv) > 1 and sys.argv[1] == "validate"
    os.makedirs(DECK, exist_ok=True)

    # All input files must sit in the driver's own directory.
    for f in DECK_FILES:
        src = os.path.join(DECK_SRC, f)
        if not os.path.exists(src):
            src = os.path.join(HERE, "..", f)   # local working copy
        shutil.copy(src, os.path.join(DECK, f))

    if validate:
        p = build_driver(
            os.path.join(DECK, "ad_pc00_validate.inp"), 0.0, 0.0, [(6.0, 0.0)]
        )
        print("wrote", p)
        return

    made = []
    for pc in PRECONES:
        tag = f"pc{int(pc):02d}"
        cases = [(tsr, 0.0) for tsr in TSRS]
        made.append((tag, build_driver(
            os.path.join(DECK, f"ad_{tag}.inp"), pc, 0.0, cases)))
    for yw in YAWS:
        tag = f"yw{int(yw):02d}"
        cases = [(tsr, yw) for tsr in TSRS]
        made.append((tag, build_driver(
            os.path.join(DECK, f"ad_{tag}.inp"), 0.0, 0.0, cases)))

    for tag, path in made:
        print(f"{tag:6s} {os.path.basename(path):22s} cases={len(open(path).read().splitlines())}")
    print(f"\n{len(made)} driver files, {len(made) * len(TSRS)} cases total")


if __name__ == "__main__":
    main()

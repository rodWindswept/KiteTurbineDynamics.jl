#!/usr/bin/env python3
"""Blade-count sensitivity of the bank (precone) derate.

Rod's question: do the 2026-09-30 precone results hold only for 3-bladed rotors?

Two variants, both at 6 blades.

  b6c100   6 blades, chord unchanged at 0.500 m.  Solidity DOUBLES.
  b6c050   6 blades, chord halved to 0.250 m.  Solidity MATCHES the 3-blade rotor.

The second variant is the clean test of blade count.  It keeps the total blade
area the same and changes only how many blades share it.  The first variant is
the naive "just add blades" case, and it is reported separately because doubling
the solidity moves the whole Cp curve.

Each variant needs its own primary input, because the primary carries one
ADBlFile line per blade, and its own blade file when the chord changes.  The
driver then points AeroFile at the variant primary.
"""

import os
import re
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
DECK = os.path.join(HERE, "deck")

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

TSRS = [2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0]
RADIUS = 4.0
WIND = 8.0
DT = 2.314858e-03
TMAX = 5.0

VARIANTS = {"b6c100": 0.500, "b6c050": 0.250}
PRECONES = [0.0, 5.0, 10.0, 15.0, 20.0, 25.0]
NBLADES = 6


def rotspd_rpm(tsr, tilt_deg=0.0):
    import math

    v_ax = WIND * math.cos(math.radians(abs(tilt_deg)))
    return (tsr * v_ax / RADIUS) * 60.0 / (2.0 * math.pi)


def write_blade(dest, chord):
    """Copy the template blade and set the chord, preserving every other byte.

    The template is CRLF and its columns are tab-separated with padding spaces.
    Reformatted rows make AeroDyn's blade reader fail with "Unable to read
    numeric data from all columns in the table on row 1", so only the chord
    token changes and the rest of the line is left exactly as it was.
    """
    src = os.path.join(DECK_SRC, "ad_blade_MVP.inp")
    if not os.path.exists(src):
        src = os.path.join(DECK, "ad_blade_MVP.inp")
    with open(src, newline="") as fh:
        text = fh.read()

    # columns: BlSpn, BlCrvAC, BlSwpAC, BlCrvAng, BlTwist, BlChord, BlAFID
    row = re.compile(
        r"(^\s*[\d.+-]+\s*\t\s*[\d.+-]+\s*\t\s*[\d.+-]+\s*\t\s*[\d.+-]+\s*\t\s*[\d.+-]+\s*\t\s*)"
        r"([\d.+-]+)"
        r"(\s*\t\s*\d+\s*)$",
        re.MULTILINE,
    )
    text, n = row.subn(lambda m: f"{m.group(1)}{chord:.3f}{m.group(3)}", text)
    if n == 0:
        raise SystemExit(f"no blade rows found in {src}")
    with open(dest, "w", newline="") as fh:
        fh.write(text)
    return n


def write_primary(dest, blade_name):
    """Copy the template primary and give it one ADBlFile line per blade."""
    src = os.path.join(DECK_SRC, "ad_primary_MVP.inp")
    if not os.path.exists(src):
        src = os.path.join(DECK, "ad_primary_MVP.inp")
    with open(src, encoding="utf-8", errors="replace", newline="") as fh:
        text = fh.read()

    block = os.linesep.join(
        f'"{blade_name}"    ADBlFile({i})        - Blade #{i} (-)'
        for i in range(1, NBLADES + 1)
    )
    text, n = re.subn(r"(?:.*ADBlFile\(\d+\).*\r?\n)+", block + "\n", text, count=1)
    if n != 1:
        raise SystemExit("could not find the ADBlFile block in the primary input")
    with open(dest, "w", newline="") as fh:
        fh.write(text)


def write_driver(dest, precone, primary_name, cases):
    with open(os.path.join(DECK_SRC, "ad_driver_v5.inp")) as fh:
        text = fh.read()

    text = re.sub(r'(?m)^.*\bPrecone\(1\).*$',
                  f"{precone:g}    Precone(1)     - Blade precone (deg)", text)
    text = re.sub(r'(?m)^.*\bShftTilt\(1\).*$',
                  "0    ShftTilt(1)     - Shaft tilt (deg)", text)
    text = re.sub(r'(?m)^.*\bNumBlades\(1\).*$',
                  f"{NBLADES}    NumBlades(1)    - Number of blades (-)", text)
    text = re.sub(r'(?m)^.*\bAeroFile\b.*$',
                  f'"{primary_name}"  AeroFile -  Name of the primary AeroDyn input file',
                  text)
    text = re.sub(r'(?m)^\s*\d+\s+NumCases\b.*$',
                  f"{len(cases)}  NumCases     - Number of cases to run", text)

    rows = [
        f"{WIND:.6E} {0.0:.6E} {rotspd_rpm(t):.6E} {3.0:.6E} {0.0:.6E} "
        f"{DT:.6E} {TMAX:.6E} {0.0:.6E} {0.0:.6E} {0.0:.6E}"
        for t in cases
    ]
    text = re.sub(
        r"(\(m/s\)\s+\(-\)\s+\(rpm\)\s+\(deg\)\s+\(deg\)\s+\(s\)\s+\(s\)\s+\(-\)\s+\(m or rad\)\s+\(Hz\)\n)"
        r"(?:[^\n]*\n)",
        lambda m: m.group(1) + "\n".join(rows) + "\n",
        text,
        count=1,
    )
    with open(dest, "w") as fh:
        fh.write(text)


def main():
    os.makedirs(DECK, exist_ok=True)
    for f in DECK_FILES:
        src = os.path.join(DECK_SRC, f)
        if not os.path.exists(src):
            src = os.path.join(HERE, "..", f)
        shutil.copy(src, os.path.join(DECK, f))

    made = []
    for setname, chord in VARIANTS.items():
        blade = f"ad_blade_{setname}.inp"
        primary = f"ad_primary_{setname}.inp"
        write_blade(os.path.join(DECK, blade), chord)
        write_primary(os.path.join(DECK, primary), blade)
        for pc in PRECONES:
            name = f"ad_{setname}_pc{int(pc):02d}.inp"
            write_driver(os.path.join(DECK, name), pc, primary, TSRS)
            made.append(name)

    print(f"{len(made)} drivers for {len(VARIANTS)} variants, "
          f"{len(made) * len(TSRS)} cases")
    for v, c in VARIANTS.items():
        print(f"  {v}: {NBLADES} blades, chord {c:.3f} m")
    return 0


if __name__ == "__main__":
    sys.exit(main())

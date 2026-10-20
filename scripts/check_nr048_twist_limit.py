#!/usr/bin/env python3
"""check_nr048_twist_limit.py — the NR-048 amend check (science-validator, 2026-10-20).

Purpose
-------
The signed NR-048 row prints "87.9 deg of twist against the 78.8 deg collapse
limit".  Aero-validator's counter-read at HEAD found that no per-segment limit
of the machine the 87.9 was measured on equals 78.8.  This script recomputes
both per-segment limits from the geometry, and solves for the ring radius that
would produce 78.8 on that machine's segment length.

It reads no tree files.  The radii below are the ones printed by
`scratch/av_limits_probe.jl` at this commit (decode of the committed genomes,
no simulation).  The formulas are the code's:

  crossing limit   dalpha* = 2*asin(L / sqrt(2*(L^2 + 2*r^2))),  r = max(r_a, r_b)
                   (src/objective_evaluator.jl:448, twist_collapse_check)
  over-twist       Tulloch (4.34), cos(dcrit) = (r_a^2 + r_b^2 - l_t^2 + sqrt(disc))
                                               / (2*r_a*r_b)
                   (src/trpt_twist_limit.jl)

Exit 0 when the amend's claims hold, 1 otherwise.
"""

import math
import sys

L_SEG = 18.8 / 5.0          # pc.tether_length / (n_ring - 1), both machines

# (label, [(r_a, r_b), ...]) from av_limits_probe.jl at the commit this landed.
MACHINES = [
    ("scenario_sweep 2026-09-06",
     [(0.863, 0.863)] * 4 + [(0.863, 4.320)]),
    ("bankderate2 winner (strip panel 7)",
     [(0.804, 0.804)] * 4 + [(0.804, 4.580)]),
]

TARGET = 78.8


def crossing_deg(l_t: float, r_a: float, r_b: float) -> float:
    r = max(r_a, r_b)
    arg = min(l_t / math.sqrt(2.0 * (l_t**2 + 2.0 * r**2)), 1.0)
    return 2.0 * math.degrees(math.asin(arg))


def dcrit_deg(l_t: float, r_a: float, r_b: float):
    """Tulloch (4.34).  Returns None where no limit exists (case B)."""
    disc = (l_t**2 - (r_a + r_b) ** 2) * (l_t**2 - (r_a - r_b) ** 2)
    if disc < 0:
        return None
    cos_d = (r_a**2 + r_b**2 - l_t**2 + math.sqrt(disc)) / (2.0 * r_a * r_b)
    if abs(cos_d) > 1:
        return None
    return math.degrees(math.acos(cos_d))


def radius_for_limit(limit_deg: float, l_t: float) -> float:
    """Invert the crossing formula: the ring radius that gives `limit_deg`."""
    s = math.sin(math.radians(limit_deg) / 2.0)
    return math.sqrt(((l_t / s) ** 2 / 2.0 - l_t**2) / 2.0)


def main() -> int:
    ok = True
    print(f"segment length L_seg = {L_SEG:.4f} m")
    print(f"target token from NR-048: {TARGET} deg\n")

    for label, segs in MACHINES:
        print(f"{label}")
        crossing, crit = [], []
        for i, (ra, rb) in enumerate(segs, 1):
            c = crossing_deg(L_SEG, ra, rb)
            d = dcrit_deg(L_SEG, ra, rb)
            crossing.append(c)
            crit.append(d)
            ds = "none (case B)" if d is None else f"{d:.2f}"
            print(f"  seg {i}  r_a={ra:.3f} r_b={rb:.3f}  dalpha*={c:.2f}  dcrit={ds}")
        bind = min(crossing)
        print(f"  binding crossing = {bind:.2f} deg\n")
        if abs(bind - TARGET) < 0.5:
            print(f"  FAIL: a segment limit equals {TARGET}")
            ok = False

    r_star = radius_for_limit(TARGET, L_SEG)
    print(f"radius that gives {TARGET} deg at L_seg {L_SEG:.2f} m: {r_star:.4f} m")
    print("radii on either machine at HEAD: 0.804, 0.863, 4.320, 4.580 m")

    nearest = min(
        abs(crossing_deg(L_SEG, 0.863, 0.863) - TARGET),
        abs(crossing_deg(L_SEG, 4.320, 4.320) - TARGET),
    )
    print(f"nearest segment limit to {TARGET} deg: {nearest:.2f} deg away")

    # The amend's positive claim: the 78.8 token belongs to no segment of the
    # machine, and no radius on that machine reproduces it.
    if abs(r_star - 0.863) < 0.01 or abs(r_star - 4.320) < 0.01:
        print("FAIL: the implied radius is a ring radius on the machine")
        ok = False

    print("\nVERDICT:", "amend holds" if ok else "amend does NOT hold")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())

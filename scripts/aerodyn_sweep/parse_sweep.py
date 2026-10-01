#!/usr/bin/env python3
"""Parse the AeroDyn sweep output and tabulate Cp against commanded lambda.

Two things this file is careful about.

1.  Columns are found BY NAME.  The repo skill records `RtAeroCp=18, RtAeroCt=20,
    RtTSR=31`; this v5.0.0 output puts them at 23, 25 and 27.  An index from the
    wrong generation silently returns a plausible number from the wrong channel.

2.  Alignment is on the COMMANDED lambda, not the measured `RtTSR`.  AeroDyn's
    `RtTSR` uses an angle-dependent reference length: it rises with yaw
    (6.00 -> 6.40 at 20 deg, i.e. 1/cos(yaw)) and falls with precone.  Aligning
    on it would compare different rotor speeds.  The commanded lambda comes from
    the case index, and every angle at a given case index runs the SAME rpm and
    the same wind, which is the control the comparison needs.

Writes `results/sweep.csv` and prints the ratio tables.
"""

import csv
import glob
import os
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
DECK = os.path.join(WORK, "deck")
OUTDIR = os.path.join(WORK, "results")

# Must match gen_precone_drivers.py: case i (1-based) ran TSRS[i-1].
TSRS = [2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0]

WANT = ["RtAeroCp", "RtAeroCt", "RtTSR", "RtSpeed", "RtAeroPwr", "Yaw", "Case"]


def parse_file(path):
    names, rows = None, []
    with open(path, encoding="utf-8", errors="replace") as fh:
        lines = fh.readlines()

    for line in lines:
        if names is None:
            if "RtAeroCp" in line:
                names = line.split()
            continue
        parts = line.split()
        if not parts or len(parts) != len(names):
            continue
        try:
            float(parts[0])
        except ValueError:
            continue
        rows.append(dict(zip(names, parts)))

    if not rows:
        return {}

    by_case = {}
    for r in rows:
        by_case.setdefault(r.get("Case", "1"), []).append(r)

    out = {}
    for case, rws in by_case.items():
        last = rws[-1]
        back = rws[-201] if len(rws) > 201 else rws[0]
        rec = {k: float(last[k]) for k in WANT if k in last}
        rec["n_steps"] = len(rws)
        rec["dCp_200"] = abs(float(last["RtAeroCp"]) - float(back["RtAeroCp"]))
        out[case] = rec
    return out


def tag_of(path):
    stem = os.path.basename(path).split(".")[0]
    kind = "precone" if "_pc" in stem else "yaw"
    key = "_pc" if kind == "precone" else "_yw"
    return kind, float(stem.split(key)[-1])


def table(records, kind, value, label, compare=None):
    sel = [r for r in records if r["kind"] == kind]
    if not sel:
        return
    angles = sorted({r["angle_deg"] for r in sel})
    base = {r["tsr_set"]: r[value] for r in sel if r["angle_deg"] == 0.0}

    head = "angle  " + "".join(f"{t:>9.1f}" for t in TSRS)
    print(f"=== {kind}: {label}  (rows = angle deg, cols = commanded lambda) ===")
    print(head)
    for a in angles:
        row = []
        for t in TSRS:
            hit = [r for r in sel if r["angle_deg"] == a and r["tsr_set"] == t]
            row.append(f"{hit[0][value]:>9.4f}" if hit else f"{'-':>9}")
        print(f"{a:>5.0f}  " + "".join(row))

    if compare is None:
        print()
        return

    print(f"\n--- {kind}: ratio {label}(angle) / {label}(0)  vs  {compare} ---")
    print(head)
    for a in angles:
        row = []
        for t in TSRS:
            hit = [r for r in sel if r["angle_deg"] == a and r["tsr_set"] == t]
            if hit and base.get(t):
                row.append(f"{hit[0][value] / base[t]:>9.3f}")
            else:
                row.append(f"{'-':>9}")
        print(f"{a:>5.0f}  " + "".join(row))
    import math

    ref = "".join(
        f"{math.cos(math.radians(a)) ** 3:>9.3f}" for a in angles if a > 0
    )
    print(f"\n  cos^3(beta) reference at {', '.join(f'{a:g}' for a in angles if a > 0)}:")
    print(f"    {ref.strip()}")
    print()


def main():
    files = [
        f
        for f in sorted(glob.glob(os.path.join(DECK, "*.out")))
        if ("_pc" in os.path.basename(f) or "_yw" in os.path.basename(f))
        and "validate" not in os.path.basename(f)
        # Anchor on the DRIVER PREFIX, not on "_pc". The blade-count sweep writes
        # ad_b6c*_pc*.out into the same deck directory, and those names also contain
        # "_pc", so a substring test reads one sweep as the other. The precone drives
        # are ad_pc* and the yaw drives are ad_yw*.
        #
        # Consequence, found 2026-10-01: re-parsing a deck directory that holds only
        # the blade-count outputs now reports "no sweep outputs found", which is the
        # truth. Regenerate with run_sweep.py to reproduce 10-precone-sweep.csv.
        and os.path.basename(f).startswith(("ad_pc", "ad_yw"))
    ]
    if not files:
        print("no sweep outputs found", file=sys.stderr)
        return 1

    records = []
    for path in files:
        kind, ang = tag_of(path)
        for case, rec in parse_file(path).items():
            ci = int(float(case))
            if not (1 <= ci <= len(TSRS)):
                continue
            rec.update(
                kind=kind,
                angle_deg=ang,
                case=case,
                tsr_set=TSRS[ci - 1],
                file=os.path.basename(path),
            )
            records.append(rec)

    os.makedirs(OUTDIR, exist_ok=True)
    dest = os.path.join(OUTDIR, "sweep.csv")
    stamp = [
        "# AeroDyn precone (bank) and yaw sweep, KiteTurbineDynamics.jl",
        "# generated 2026-09-30 on rodbot-ThinkPad-P1-Gen-3",
        "# tool: AeroDyn_driver v5.0.0, sha256 787e23f4871255a76fcbd3f66b7e4fce0a8a1c1d168cad3094adbb0d897cd246",
        "# rotor: Daisy MVP, 3 blades, R 4.0 m (HubRad 1.0 + span 3.0), chord 0.500 m uniform, twist 0.0 deg, NACA 4412 Re 250k",
        "# geometry fingerprint: n_blades=3 R=4.0000 span=3.0000 chord=0.5000 twist=0.0 area=50.26548 m2",
        "# physics: BEMT WakeMod=1, SkewMod=2 Pitt/Peters, AFAeroMod=2 unsteady, UAMod=3, ShftTilt=0, no tower, wind 8.0 m/s",
        "# budget: 84 cases x 5.0 s at dT=2.314858e-3 s, last timestep taken; worst |dCp| over the final 200 steps = 3.4e-3",
        "# alignment: rows align on the COMMANDED lambda; AeroDyn RtTSR uses an angle-dependent reference length",
        "# source drivers: <AERODYN_SWEEP_WORK>/deck/ad_pc*.inp and ad_yw*.inp",
    ]
    with open(dest, "w", newline="") as fh:
        fh.write("\n".join(stamp) + "\n")
        w = csv.writer(fh)
        w.writerow([
            "kind", "angle_deg", "tsr_set", "TSR_meas", "Cp", "Ct", "Pwr_W",
            "RtSpeed_rpm", "Yaw_deg", "case", "n_steps", "dCp_200", "file",
        ])
        for r in sorted(records, key=lambda r: (r["kind"], r["angle_deg"], r["tsr_set"])):
            w.writerow([
                r["kind"], f"{r['angle_deg']:g}", f"{r['tsr_set']:g}",
                f"{r['RtTSR']:.4f}", f"{r['RtAeroCp']:.5f}", f"{r['RtAeroCt']:.5f}",
                f"{r['RtAeroPwr']:.1f}", f"{r['RtSpeed']:.3f}",
                f"{r.get('Yaw', 0.0):.2f}", r["case"], r["n_steps"],
                f"{r['dCp_200']:.2e}", r["file"],
            ])

    print(f"{len(records)} settled points -> {dest}")
    worst = max(records, key=lambda r: r["dCp_200"])
    print(f"convergence: worst |dCp| over the last 200 steps = {worst['dCp_200']:.2e} "
          f"({worst['kind']} {worst['angle_deg']:g} deg, lambda {worst['tsr_set']:g})\n")

    table(records, "precone", "RtAeroCp", "Cp", compare="cos^3(beta)")
    table(records, "yaw", "RtAeroCp", "Cp", compare="cos^3(beta)")

    # Peak-lambda headline, both models, side by side.
    print("=== headline: Cp at commanded lambda = 4.0, the Cp peak ===")
    print(f"{'angle':>6} {'precone Cp':>11} {'ratio':>7} {'yaw Cp':>9} {'ratio':>7} {'cos^3':>7}")
    import math

    for a in sorted({r["angle_deg"] for r in records}):
        pc = [r for r in records if r["kind"] == "precone"
              and r["angle_deg"] == a and r["tsr_set"] == 4.0]
        yw = [r for r in records if r["kind"] == "yaw"
              and r["angle_deg"] == a and r["tsr_set"] == 4.0]
        b = [r for r in records if r["kind"] == "precone"
             and r["angle_deg"] == 0.0 and r["tsr_set"] == 4.0]
        if not (pc and yw and b):
            continue
        c3 = math.cos(math.radians(a)) ** 3
        print(f"{a:>6.0f} {pc[0]['RtAeroCp']:>11.4f} "
              f"{pc[0]['RtAeroCp'] / b[0]['RtAeroCp']:>7.3f} "
              f"{yw[0]['RtAeroCp']:>9.4f} {yw[0]['RtAeroCp'] / b[0]['RtAeroCp']:>7.3f} "
              f"{c3:>7.3f}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Parse the blade-count variants and compare them against the 3-blade baseline.

Rod's question: do the 2026-09-30 precone results hold only for 3-bladed rotors?

Two 6-blade variants:
  b6c100  chord 0.500 m, so solidity DOUBLES against the 3-blade rotor
  b6c050  chord 0.250 m, so solidity MATCHES the 3-blade rotor

The second is the clean test of blade count. The first is reported separately.

Columns are looked up BY NAME. Alignment is on the COMMANDED lambda, because
AeroDyn's RtTSR uses an angle-dependent reference length (see parse_sweep.py).

Reads the committed 3-blade baseline from
docs/validation/trpt-reference/10-precone-sweep.csv.
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
REPO = os.path.abspath(REPO_ROOT)
BASELINE = os.path.join(REPO, "docs", "validation", "trpt-reference",
                        "10-precone-sweep.csv")

TSRS = [2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0]
ANGLES = [0.0, 5.0, 10.0, 15.0, 20.0, 25.0]
CHORDS = {"b6c100": 0.500, "b6c050": 0.250}
WANT = ["RtAeroCp", "RtAeroCt", "RtTSR", "RtSpeed", "RtAeroPwr", "Case"]


def rows_of(path):
    names, rows = None, []
    for line in open(path, encoding="utf-8", errors="replace"):
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
    return rows


def parse_file(path):
    rows = rows_of(path)
    if not rows:
        return {}
    by_case = {}
    for r in rows:
        by_case.setdefault(r.get("Case", "1"), []).append(r)
    out = {}
    for case, rws in by_case.items():
        last, back = rws[-1], (rws[-201] if len(rws) > 201 else rws[0])
        rec = {k: float(last[k]) for k in WANT if k in last}
        rec["n_steps"] = len(rws)
        rec["dCp_200"] = abs(float(last["RtAeroCp"]) - float(back["RtAeroCp"]))
        out[case] = rec
    return out


def tag_of(path):
    """ad_b6c050_pc20.3.out -> ('b6c050', 20.0)."""
    stem = os.path.basename(path).split(".")[0]
    variant = stem.split("_pc")[0].replace("ad_", "")
    angle = float(stem.split("_pc")[-1])
    return variant, angle


def load_baseline():
    """The 3-blade 20-deg retention at the peak, from the committed CSV."""
    base = {}
    with open(BASELINE) as fh:
        body = [ln for ln in fh if not ln.lstrip().startswith("#")]
    for r in csv.DictReader(body):
        if r["kind"] != "precone":
            continue
        base[(float(r["angle_deg"]), float(r["tsr_set"]))] = float(r["Cp"])
    return base


def main():
    files = sorted(glob.glob(os.path.join(DECK, "ad_b6c*_pc[0-9][0-9].*.out")))
    if not files:
        print("no blade-count outputs found", file=sys.stderr)
        return 1

    records = []
    for path in files:
        variant, angle = tag_of(path)
        for case, rec in parse_file(path).items():
            ci = int(float(case))
            if not (1 <= ci <= len(TSRS)):
                continue
            rec.update(variant=variant, chord_m=CHORDS.get(variant, 0.0),
                       angle_deg=angle, case=case, tsr_set=TSRS[ci - 1],
                       file=os.path.basename(path))
            records.append(rec)

    os.makedirs(OUTDIR, exist_ok=True)
    dest = os.path.join(OUTDIR, "bladecount.csv")
    with open(dest, "w", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(["variant", "n_blades", "chord_m", "angle_deg", "tsr_set",
                    "TSR_meas", "Cp", "Ct", "Pwr_W", "RtSpeed_rpm", "case",
                    "n_steps", "dCp_200", "file"])
        for r in sorted(records, key=lambda r: (r["variant"], r["angle_deg"],
                                                r["tsr_set"])):
            w.writerow([r["variant"], 6, f"{r['chord_m']:.3f}",
                        f"{r['angle_deg']:g}", f"{r['tsr_set']:g}",
                        f"{r['RtTSR']:.4f}", f"{r['RtAeroCp']:.5f}",
                        f"{r['RtAeroCt']:.5f}", f"{r['RtAeroPwr']:.1f}",
                        f"{r['RtSpeed']:.3f}", r["case"], r["n_steps"],
                        f"{r['dCp_200']:.2e}", r["file"]])
    print(f"{len(records)} settled points -> {dest}")

    worst = max(records, key=lambda r: r["dCp_200"])
    print(f"convergence: worst |dCp| over the last 200 steps = {worst['dCp_200']:.2e}")
    print()

    base = load_baseline()
    print("Cp retention vs that variant's OWN 0-deg case, at each commanded lambda")
    print("(and, in the last two columns, the same number for the 3-blade rotor)\n")
    hdr = f"{'variant':>8} {'chord':>6} " + "".join(f"{t:>8.1f}" for t in TSRS)
    print(hdr)
    for variant in sorted(CHORDS):
        sel = [r for r in records if r["variant"] == variant]
        zero = {r["tsr_set"]: r["RtAeroCp"] for r in sel if r["angle_deg"] == 0.0}
        for a in ANGLES:
            if a == 0.0:
                continue
            cells = []
            for t in TSRS:
                hit = [r for r in sel if r["angle_deg"] == a and r["tsr_set"] == t]
                z = zero.get(t)
                cells.append(f"{hit[0]['RtAeroCp'] / z:>8.3f}" if hit and z else f"{'-':>8}")
            if a == 20.0:
                print(f"{variant:>8} {CHORDS[variant]:>6.3f} " + "".join(cells))
                b3 = []
                for t in TSRS:
                    z = base.get((0.0, t))
                    v = base.get((20.0, t))
                    b3.append(f"{v / z:>8.3f}" if v is not None and z else f"{'-':>8}")
                print(f"{'3-blade':>8} {0.5:>6.3f} " + "".join(b3))
    print()

    # Peak-lambda headline for the clean comparison.
    print("=== headline: Cp retention at commanded lambda 4.0 (the 3-blade peak) ===")
    print(f"{'configured rotor':>28} {'20 deg bank':>12} {'25 deg bank':>12}")
    z3 = base.get((0.0, 4.0))
    if z3:
        for a in (20.0, 25.0):
            v = base.get((a, 4.0))
            if v:
                pass
        r20, r25 = base.get((20.0, 4.0)) / z3, base.get((25.0, 4.0)) / z3
        print(f"{'3 blades, chord 0.500 m':>28} {r20:>12.3f} {r25:>12.3f}")
    for variant in sorted(CHORDS):
        sel = [r for r in records if r["variant"] == variant]
        z = [r for r in sel if r["angle_deg"] == 0.0 and r["tsr_set"] == 4.0]
        if not z:
            continue
        cells = []
        for a in (20.0, 25.0):
            hit = [r for r in sel if r["angle_deg"] == a and r["tsr_set"] == 4.0]
            cells.append(
                f"{hit[0]['RtAeroCp'] / z[0]['RtAeroCp']:>12.3f}" if hit else f"{'-':>12}"
            )
        label = f"6 blades, chord {CHORDS[variant]:.3f} m"
        print(f"{label:>28} " + " ".join(cells))
    return 0


if __name__ == "__main__":
    sys.exit(main())

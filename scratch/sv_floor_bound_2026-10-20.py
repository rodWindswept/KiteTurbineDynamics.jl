#!/usr/bin/env python3
"""scratch/sv_floor_bound_2026-10-20.py — science-validator, read-only recount.

Signs the NR-069 floor bound on the machine-power-trend plate: over the ok
evaluations of the three-island campaign at data commit dd3cc6a, how many read
below 5.00 kW, how many read 5.00, what is the next lowest, and what is the
highest. Also prints the running-best hold span of the tightest pass.

Reads the three telemetry files; no simulation.
"""
import csv
import glob

BASE = ("scripts/results/v13_5kw_masslift_len18.8_rotorcount_bankderate2")


def load():
    rows = []
    for path in sorted(glob.glob(BASE + "/island_*/telemetry.csv")):
        with open(path) as f:
            lines = [ln for ln in f if not ln.startswith("#")]
        rows.extend(csv.DictReader(lines))
    return rows


def main():
    rows = load()
    ok = [r for r in rows if r["status"] == "ok"]
    pe = sorted(float(r["P_end"]) for r in ok)
    pm = [float(r["P_mean"]) for r in ok]
    print("rows", len(rows), "ok", len(ok))
    print("P_end below 5.00:", sum(1 for v in pe if v < 5.0))
    print("P_end recorded 5.00:", sum(1 for v in pe if round(v, 2) == 5.0))
    print("next lowest:", min(v for v in pe if v > 5.0))
    print("highest:", pe[-1])
    print("P_mean min/max:", min(pm), max(pm))
    five = [r for r in ok if round(float(r["P_end"]), 2) == 5.0]
    for r in five:
        print("five:", "island", r["island"], "gen", r["gen"], "idx", r["idx"],
              "fitness", r["fitness"], "P_mean", r["P_mean"], "P_end", r["P_end"])
    # island 1 running-best hold span of that design
    isl1 = [r for r in ok if r["island"] == "1"]
    hold = []
    for g in range(31):
        cand = [r for r in isl1 if int(r["gen"]) <= g]
        cand.sort(key=lambda r: (float(r["fitness"]), int(r["gen"]), int(r["idx"])))
        b = cand[0]
        if (b["gen"], b["idx"]) == (five[0]["gen"], five[0]["idx"]):
            hold.append(g)
    print("holds island 1 running-best at gens:", hold)


if __name__ == "__main__":
    main()

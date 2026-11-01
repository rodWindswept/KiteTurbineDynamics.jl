#!/usr/bin/env python3
"""aero-worker 2026-11-01: the NR-061 extension.

Part 1 re-derives the six-class split from the eight committed shard logs
(independent parse of the SPLIT lines, deduplicated over 201 rows).
Part 2 adds the seventh class: the 11 twist rejects, which carry FoS = Inf and
a twist ratio above one, and sit outside every class in the signed row.
Part 3 closes the census to the full 930-row campaign.
"""
import csv
import glob
import collections
import re

BASE = "/home/rod/Documents/GitHub/KiteTurbineDynamics.jl"
SHARDS = BASE + "/scratch/sv_reject_sixclass_a76c5e9/shard_*.stdout.log"
TELE = (BASE + "/scripts/results/"
        "v13_5kw_masslift_len18.8_rotorcount_bankderate2/island_*/telemetry.csv")

CLASSES = ["betz_cp_floor", "settle_fail", "spacing", "rope_break",
           "betz_ceiling", "hub_tip"]

# ── Part 1: parse the SPLIT lines ────────────────────────────────────────
splits = {}
n_split_lines = 0
row_class = {}
n_rows = 0
for path in sorted(glob.glob(SHARDS)):
    for line in open(path, errors="replace"):
        m = re.match(r"\s*\[\s*\d+/\d+\]\s+island=(\d+) gen=(\d+) idx=(\d+)\s+(\w+)", line)
        if m:
            key = (int(m.group(1)), int(m.group(2)), int(m.group(3)))
            row_class[key] = m.group(4)
            n_rows += 1
            continue
        m = re.match(r"SPLIT island=(\d+) gen=(\d+) idx=(\d+) class=(\w+)", line)
        if m:
            key = (int(m.group(1)), int(m.group(2)), int(m.group(3)))
            splits[key] = m.group(4)
            n_split_lines += 1
print("shard files", len(glob.glob(SHARDS)))
print("row lines", n_rows, "unique rows", len(row_class))
print("SPLIT lines", n_split_lines, "unique split rows", len(splits))

census = collections.Counter()
for key, cls in row_class.items():
    if cls == "under_floor":
        c = splits.get(key)
        if c is None:
            c = "under_floor(no split)"
        census[c] += 1
    else:
        census[cls] += 1
for c in CLASSES:
    print("  %-14s %d" % (c, census[c]))
print("  six-class total", sum(census.values()))
other = {k: v for k, v in census.items() if k not in CLASSES}
print("  classes outside the six:", dict(other) or "none")
print("  under_floor rows with a split line:",
      sum(1 for k, c in row_class.items() if c == "under_floor" and k in splits))

# ── Part 2 and 3: the telemetry census ──────────────────────────────────
rows = []
for path in sorted(glob.glob(TELE)):
    rows += list(csv.DictReader([l for l in open(path) if not l.startswith("#")]))
print("\ntelemetry rows", len(rows))
status = collections.Counter(r["status"] for r in rows)
print("status census", dict(status))

rej = [r for r in rows if r["status"] != "ok"]
ok = [r for r in rows if r["status"] == "ok"]
tw = [r for r in rej if r["status"] == "reject_twist"]
clr = [r for r in rej if r["status"] == "clearance_reject"]
fos_inf = [r for r in rej if r["FoS"] == "Inf"]
fos_fin = [r for r in rej if r["FoS"] not in ("Inf", "NaN")]
print("ok %d | six-class 201 candidates %d | twist %d | clearance %d | finite-FoS %d" %
      (len(ok), len(fos_inf) - len(tw), len(tw), len(clr), len(fos_fin)))

tw_ratio = sorted(float(r["twist_ratio"]) for r in tw)
print("twist reject ratios: min %.4f max %.4f  (all > 1: %s)" %
      (tw_ratio[0], tw_ratio[-1], all(v > 1 for v in tw_ratio)))
print("twist rows carry FoS=Inf: %s ; P_end=0: %s ; n_lines mix: %s" % (
    all(r["FoS"] == "Inf" for r in tw),
    all(float(r["P_end"]) == 0.0 for r in tw),
    dict(collections.Counter(r["n_lines"] for r in tw))))
print("six-class rows carry twist_ratio=0:",
      all(float(r["twist_ratio"]) == 0.0 for r in fos_inf if r["status"] != "reject_twist"))

print("\nseven-class census")
for c in CLASSES:
    print("  %-14s %d" % (c, census[c]))
print("  %-14s %d" % ("twist", len(tw)))
print("  total          %d" % (sum(census.values()) + len(tw)))

print("\nclosure")
print("  508 ok + 201 six-class + 11 twist + 110 clearance + 100 finite-FoS = %d" %
      (len(ok) + len(fos_inf) - len(tw) + len(tw) + len(clr) + len(fos_fin)))

# the twist rows as table lines for the receipt
print("\nthe 11 twist rejects")
for r in tw:
    print("  i%s g%s idx%s  n_lines %s  twist_ratio %.6f  P_end %s" %
          (r["island"], r["gen"], r["idx"], r["n_lines"],
           float(r["twist_ratio"]), r["P_end"]))

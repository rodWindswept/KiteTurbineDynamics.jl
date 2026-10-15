#!/usr/bin/env python3
"""sv_301_split_check.py — the 301-reject split re-read (science-validator seat, 2026-10-15).

The founder ruled "Print" on the 301-reject breakdown (room, 2026-10-15): three
subgroups, the third labelled "cause not logged". This checker is the
signing-seat read. It re-derives the split, the status mix and the per-island
counts from the three bankderate2 telemetry files. Read only; no runs.

Sources:
  scripts/results/v13_5kw_masslift_len18.8_rotorcount_bankderate2/island_{1,2,3}/telemetry.csv

Expected reads (figure-generation-notes.md:128-147; phase0 audit section 6):
  status mix: ok 508, reject 301, clearance_reject 110, reject_twist 11 (930 rows)
  per island: ok 152/162/194; reject 108/111/82; clearance 47/35/28; twist 3/2/6
  reject split: 96 ran below the 5 kW floor; 4 ran at or above 5 kW with FoS
  below 2.5; 201 carry zeroed fields (P_mean 0, FoS Inf, T_lift 0).
"""
import csv
import hashlib
import io
import sys

BASE = "scripts/results/v13_5kw_masslift_len18.8_rotorcount_bankderate2"
# The NR-054 header hashes (scratch/av_conv_series.csv): the same three files.
EXPECT_SHA = {
    1: "6f359c33f174d5dc98b1252e29fdba6eac8dbae15dd71d46ef8bbed6acc9bd2f",
    2: "54172ce5a64b22903a2428f870b499f13da53c6b065600d8a01edfd882b29827",
    3: "34d40e8ea960a1e04c83df58df9e24047cfcf7eb3deff3278807f1147b8d60b0",
}
EXPECT_MIX = {"ok": 508, "reject": 301, "clearance_reject": 110, "reject_twist": 11}
EXPECT_ISL = {
    1: {"ok": 152, "reject": 108, "clearance_reject": 47, "reject_twist": 3},
    2: {"ok": 162, "reject": 111, "clearance_reject": 35, "reject_twist": 2},
    3: {"ok": 194, "reject": 82, "clearance_reject": 28, "reject_twist": 6},
}
FAILS = []


def check(name, cond, detail=""):
    print(f"  [{'PASS' if cond else 'FAIL'}] {name}" + (f"  ({detail})" if detail else ""))
    if not cond:
        FAILS.append(name)


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def read_telemetry(path):
    comments, data = [], []
    with open(path) as fh:
        for line in fh:
            (comments if line.startswith("#") else data).append(line)
    data = [l for l in data if l.strip()]
    return comments, list(csv.DictReader(io.StringIO("".join(data))))


print("sv_301_split_check — the 301-reject split re-read (science-validator seat)")
print()

mix = {k: 0 for k in EXPECT_MIX}
mix_isl = {i: {k: 0 for k in EXPECT_MIX} for i in (1, 2, 3)}
rejects = []

for isl in (1, 2, 3):
    path = f"{BASE}/island_{isl}/telemetry.csv"
    comments, rows = read_telemetry(path)
    digest = sha256(path)
    check(f"island {isl}: sha256 matches the NR-054 header", digest == EXPECT_SHA[isl], digest[:16])
    check(f"island {isl}: data rows = 310", len(rows) == 310, f"got {len(rows)}")
    for r in rows:
        mix[r["status"]] += 1
        mix_isl[isl][r["status"]] += 1
        if r["status"] == "reject":
            rejects.append((isl, r))
    for st in ("ok", "reject", "clearance_reject", "reject_twist"):
        got, want = mix_isl[isl][st], EXPECT_ISL[isl][st]
        check(f"island {isl}: {st} = {want}", got == want, f"got {got}")
    print()

print("Pooled status mix (930 rows across the three islands):")
for st, want in EXPECT_MIX.items():
    got = mix[st]
    check(f"pooled {st} = {want}", got == want, f"got {got}")
check("pooled total = 930", sum(mix.values()) == 930, f"got {sum(mix.values())}")
print()

print(f"Reject split ({len(rejects)} rows):")
floor96, fos4, zeroed201, other = [], [], [], []
for isl, r in rejects:
    P, F, TL = float(r["P_mean"]), float(r["FoS"]), float(r["T_lift"])
    if P == 0.0 and F == float("inf") and TL == 0.0:
        zeroed201.append((isl, r))
    elif P < 5.0:
        floor96.append((isl, r))
    elif F < 2.5:
        fos4.append((isl, r))
    else:
        other.append((isl, r))

check("subgroup A: ran, power below the 5 kW floor = 96", len(floor96) == 96, f"got {len(floor96)}")
check("subgroup B: ran, power >= 5 kW, FoS below 2.5 = 4", len(fos4) == 4, f"got {len(fos4)}")
check("subgroup C: fields zeroed, cause not logged = 201", len(zeroed201) == 201, f"got {len(zeroed201)}")
check("no reject falls outside the three subgroups", len(other) == 0, f"got {len(other)}")

pa = [float(r["P_mean"]) for _, r in floor96]
pb = [float(r["P_mean"]) for _, r in fos4]
nfa = sum(1 for _, r in floor96 if float(r["FoS"]) < 2.5)
print(f"  A: P range {min(pa):.2f} to {max(pa):.2f} kW; {nfa} of 96 also read FoS below 2.5")
check("A: 34 of the 96 also read FoS below 2.5", nfa == 34, f"got {nfa}")
print(f"  B: P range {min(pb):.2f} to {max(pb):.2f} kW; the four rows:")
for isl, r in fos4:
    print(f"     island {isl}, gen {r['gen']}, idx {r['idx']}: P {float(r['P_mean']):.2f} kW, FoS {float(r['FoS']):.2f}")
fos_all = [float(r["FoS"]) for _, r in rejects if float(r["FoS"]) != float("inf")]
print(f"  finite-FoS census across the 301 rejects: {len(fos_all)} finite ({min(fos_all):.2f} to {max(fos_all):.2f}), "
      f"{len(rejects) - len(fos_all)} Inf (axis: the Phase 0 audit section 6 split)")
check("finite-FoS census = 100 finite, 201 Inf",
      len(fos_all) == 100 and len(rejects) - len(fos_all) == 201)
print()

print("RESULT: " + ("ALL CHECKS PASS" if not FAILS else f"{len(FAILS)} FAILURES: {FAILS}"))
sys.exit(0 if not FAILS else 1)

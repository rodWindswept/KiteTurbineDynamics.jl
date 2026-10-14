#!/usr/bin/python3
# -*- coding: utf-8 -*-
# fig_lever_check.py — the item-5 lever-statistics extract seat check (figures seat, 2026-10-14)
#
# Re-reads the extract kit and the raw telemetry from the tree. Independent
# recomputes:
#   A. the 930 / 508 / 301 / 110 / 11 recount from the raw telemetry
#   B. the ok count-2 designs: decoded rotor_count 2; fitness strings 58.864, 60.646
#   C. cross-table sums: each failure-rates section reads 930 total and 508 ok;
#      each gene's bins read 508
#   D. the penalty table: 508 rows; remainder, total and share recompute on every
#      row; the winner row charges recompute from its recorded columns
#   E. a fresh builder run stays byte-identical across the seven tables and checks.log
#   F. the output and input sha256 list
# Stdlib only. Token FIG_LEVER_CHECK_DONE on success.
import csv
import hashlib
import re
import subprocess
import sys
import tempfile
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
KIT = ROOT / "docs/reporting/figures/lever-statistics-extract"
RD = ROOT / "scripts/results/v13_5kw_masslift_len18.8_rotorcount_bankderate2"
PY = "/usr/bin/python3"
GENERATED = [f"extract-{n}.csv" for n in
             ("objective-vs-gene", "objective-by-gene-bins", "gate-failures-by-gene",
              "failure-discrimination", "failure-rates-by-value",
              "penalty-contributions", "penalty-summary")] + ["checks.log"]

ok = True


def check(name: str, good: bool, extra: str = "") -> None:
    global ok
    tail = "" if good else f"  [{extra}]"
    print(("OK  " if good else "FAIL") + "  " + name + tail)
    ok = ok and bool(good)


def rows_of(p: Path) -> list[dict]:
    lines = [ln for ln in p.read_text().splitlines()
             if not ln.startswith("#") and ln.strip()]
    return list(csv.DictReader(lines))


def dec_rotor(x: float) -> int:
    return int(round(min(max(x, 1.0), 3.0)))


# ---------------------------------------------------------------- A. recount
tele: list[dict] = []
for isl in (1, 2, 3):
    tele += rows_of(RD / f"island_{isl}" / "telemetry.csv")
check("telemetry rows read 930", len(tele) == 930, str(len(tele)))
mix = Counter(r["status"] for r in tele)
check("status mix reads 508 / 301 / 110 / 11",
      mix["ok"] == 508 and mix["reject"] == 301
      and mix["clearance_reject"] == 110 and mix["reject_twist"] == 11,
      str(dict(mix)))

# ------------------------------------------------- B. the ok count-2 designs
okr = [r for r in tele if r["status"] == "ok"]
c2 = [(r["island"], r["gen"], r["idx"], r["fitness"]) for r in okr
      if dec_rotor(float(r["x6"])) == 2]
check("two ok designs decode rotor_count 2", len(c2) == 2, str(c2))
check("their fitness reads 58.864 and 60.646",
      sorted(r[3] for r in c2) == ["58.864", "60.646"], str(c2))

# ------------------------------------------------- C. cross-table sums
fr = rows_of(KIT / "extract-failure-rates-by-value.csv")
for sec in ("n_lines", "rotor_count", "n_active"):
    sub = [r for r in fr if r["column"] == sec]
    check(f"failure-rates {sec}: total 930 and ok 508",
          sum(int(r["n_total"]) for r in sub) == 930
          and sum(int(r["ok"]) for r in sub) == 508,
          str([(r["value"], r["n_total"], r["ok"]) for r in sub]))

bins = rows_of(KIT / "extract-objective-by-gene-bins.csv")
genes = [r["gene"] for r in rows_of(KIT / "extract-objective-vs-gene.csv")]
check("objective table reads 10 genes and rank permutation",
      len(genes) == 10
      and sorted(int(r["rho_rank"]) for r in rows_of(
          KIT / "extract-objective-vs-gene.csv")) == list(range(1, 11)))
for g in genes:
    s = sum(int(r["n"]) for r in bins if r["gene"] == g)
    check(f"bins sum 508 for {g}", s == 508, str(s))

# ------------------------------------------------- D. the penalty table
pen = rows_of(KIT / "extract-penalty-contributions.csv")
check("penalty table reads 508 rows", len(pen) == 508, str(len(pen)))
bad = 0
for r in pen:
    f = float(r["fitness"])
    tot = float(r["penalty_total"])
    if abs((f - tot) - float(r["remainder_kg"])) > 1e-9:
        bad += 1
    if abs(tot - (float(r["charge_overpower"]) + float(r["charge_utilisation"])
                  + float(r["charge_twist"]))) > 1e-9:
        bad += 1
    if abs(100.0 * tot / f - float(r["penalty_share_pct"])) > 1e-9:
        bad += 1
check("remainder, total and share recompute on every row", bad == 0, str(bad))
wrow = [r for r in pen if (r["island"], r["gen"], r["idx"]) == ("3", "26", "9")]
check("winner row present once", len(wrow) == 1, str(len(wrow)))
w = wrow[0]
c_ov = 5.0 * max(float(w["P_end"]) - 5.0, 0.0) ** 2
c_ut = 20.0 * (2.5 / float(w["FoS"])) ** 2
check("winner charges recompute from the recorded columns",
      abs(c_ov - float(w["charge_overpower"])) < 1e-12
      and abs(c_ut - float(w["charge_utilisation"])) < 1e-12, w["P_end"])

# ------------------------------------------------- E. double run
first = (KIT / "extract-objective-vs-gene.csv").read_text().splitlines()[0]
m = re.search(r"script commit (\S+) \|", first)
assert m, "script commit not found in the provenance line"
sc = m.group(1)
tmp = Path(tempfile.mkdtemp(prefix="fig_lever_rerun_"))
subprocess.run([PY, str(KIT / "build-extract.py"), "--script-commit", sc,
                "--outdir", str(tmp)], check=True, capture_output=True)
diff = [n for n in GENERATED
        if hashlib.sha256((KIT / n).read_bytes()).hexdigest()
        != hashlib.sha256((tmp / n).read_bytes()).hexdigest()]
check("double run byte-identical across the seven tables and checks.log",
      not diff, str(diff))
print("rerun dir:", tmp)

# ------------------------------------------------- F. hashes
print("-- kit outputs (sha256) --")
for n in GENERATED:
    print(hashlib.sha256((KIT / n).read_bytes()).hexdigest(), n)
print("-- telemetry inputs (sha256) --")
for isl in (1, 2, 3):
    p = RD / f"island_{isl}" / "telemetry.csv"
    print(hashlib.sha256(p.read_bytes()).hexdigest(), p.name)

print("FIG_LEVER_CHECK_DONE" if ok else "FIG_LEVER_CHECK_FAIL")
sys.exit(0 if ok else 1)

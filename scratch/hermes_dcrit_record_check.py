#!/usr/bin/python3
# hermes_dcrit_record_check.py — record crosscheck for the user's delta_crit double-check
# (roster row 7 · twist-limit plate · NR-022). Read-only: no simulator, repo untouched.
#
# Chain checked: the NR-022 row cell  <-  recompute from the row's own r_a/r_b/l_t
# inputs under the printed Tulloch forms ((4.34) general; (5.4) equal-radius, as pinned
# by test/test_trpt_reference.jl R7)  <-  the plate's drawn labels (label-ledger.txt).
import csv
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CSV = ROOT / "docs/reporting/figures/pair-extract/extract-winner-operating-point.csv"
LEDGER = ROOT / "docs/reporting/figures/twist-limit/label-ledger.txt"
REGISTER = ROOT / "docs/reporting/numbers-register.md"


def dcrit_general(ra, rb, lt):
    """(4.34): cos dcrit = [ra^2 + rb^2 - lt^2 + sqrt(disc)] / (2 ra rb)."""
    disc = (lt**2 - (ra + rb)**2) * (lt**2 - (ra - rb)**2)
    c = (ra**2 + rb**2 - lt**2 + math.sqrt(disc)) / (2 * ra * rb)
    return math.degrees(math.acos(max(-1.0, min(1.0, c))))


def dcrit_equal(ra, lt):
    """(5.4): cos dcrit = 1 - phi^2/2 + (phi/2) sqrt(phi^2 - 4), phi = lt/ra."""
    phi = lt / ra
    c = 1 - phi**2 / 2 + (phi / 2) * math.sqrt(phi**2 - 4)
    return math.degrees(math.acos(max(-1.0, min(1.0, c))))


def main():
    lines = [l for l in CSV.read_text().splitlines() if not l.startswith("#")]
    segs = [r for r in csv.DictReader(lines) if r["block"] == "segment"]
    ledger = set(LEDGER.read_text().splitlines())
    reg = REGISTER.read_text()

    print("hermes dcrit record check — twist-limit plate, NR-022")
    print(f"input: {CSV.relative_to(ROOT)}")
    ok = True
    for r in segs:
        ra, rb, lt = float(r["r_a_m"]), float(r["r_b_m"]), float(r["l_t_m"])
        row = float(r["dcrit_deg"])
        gen = dcrit_general(ra, rb, lt)
        eq_s = f"  (5.4) {dcrit_equal(ra, lt):.12f}" if ra == rb else ""
        drawn = f"{row:.1f}"
        d_ok = abs(gen - row) < 1e-9
        dr_ok = drawn in ledger
        ok &= d_ok and dr_ok
        print(f"{r['id']}: row {row:.12f}  (4.34) {gen:.12f}{eq_s}  "
              f"drawn {drawn} {'in' if dr_ok else 'MISSING from'} ledger")
    c1 = "98.85908296054023" in reg
    c2 = "92.64281134151318" in reg
    ok &= c1 and c2
    print(f"NR-022 cell carries 98.85908296054023: {c1} | 92.64281134151318: {c2}")
    for phi in (2.0, 20.0):
        c = 1 - phi**2 / 2 + (phi / 2) * math.sqrt(phi**2 - 4)
        print(f"phi={phi:g}: dcrit {math.degrees(math.acos(c)):.4f} deg")
    print("PASS" if ok else "FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())

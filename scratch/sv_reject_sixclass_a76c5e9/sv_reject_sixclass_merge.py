#!/usr/bin/env python3
"""sv_reject_sixclass_merge.py — science-validator seat.

Merges the eight a76c5e9 shard logs of the six-class 201-reject re-derivation
into the signed census. Asserts: exactly 201 unique rows (island, gen, idx),
every under_floor row carries a SPLIT line, no class outside the six, and the
six-class census closes at 201. Prints the final census and the comparison
against the HEAD re-run (93 / 37 / 36 / 29 / 3 / 3).
"""
import re
import sys
from pathlib import Path

DIR = Path(__file__).resolve().parent
NSHARDS = 8

SIX = {"betz_cp_floor", "settle_fail", "spacing", "rope_break",
       "betz_ceiling", "hub_tip"}

checks = 0


def check(cond, label):
    global checks
    checks += 1
    if not cond:
        print(f"FAIL: {label}")
        sys.exit(1)
    print(f"ok: {label}")


def main():
    rows = {}          # (isl, gen, idx) -> reason
    splits = {}        # (isl, gen, idx) -> (class, cp_floor)
    row_rx = re.compile(
        r"\[\s*\d+/\d+\] island=(\d+) gen=(\d+) idx=(\d+)\s+(\w+)")
    split_rx = re.compile(
        r"SPLIT island=(\d+) gen=(\d+) idx=(\d+) class=(\w+) cp_floor=([\d.eE+-]+)")

    for k in range(1, NSHARDS + 1):
        log = DIR / f"sv_reject_sixclass_a76c5e9_s{k}.log"
        text = log.read_text()
        for m in row_rx.finditer(text):
            key = (int(m[1]), int(m[2]), int(m[3]))
            reason = m[4]
            if key in rows:
                print(f"FAIL: duplicate row {key} in shard {k}")
                sys.exit(1)
            rows[key] = reason
        for m in split_rx.finditer(text):
            key = (int(m[1]), int(m[2]), int(m[3]))
            if key in splits:
                print(f"FAIL: duplicate SPLIT {key} in shard {k}")
                sys.exit(1)
            splits[key] = (m[4], float(m[5]))
        # each shard log must carry its completion marker or its keyerror is
        # acceptable ONLY if all its rows and splits are present (checked above)
        check(f"classifying:" in text, f"shard {k} log header present")

    check(len(rows) == 201, f"row census == 201 (got {len(rows)})")
    check(len(splits) == len([r for r in rows.values() if r == "under_floor"]),
          "every under_floor row carries a SPLIT line")

    census = {}
    for key, reason in rows.items():
        if reason == "under_floor":
            cls, cp = splits[key]
            check(cls in ("betz_cp_floor", "betz_ceiling"),
                  f"split class valid for {key} ({cls})")
            if cls == "betz_ceiling":
                check(cp >= 4.0, f"betz_ceiling cp_floor >= 4.0 for {key} ({cp})")
            else:
                check(cp < 4.0, f"betz_cp_floor cp_floor < 4.0 for {key} ({cp})")
            census[cls] = census.get(cls, 0) + 1
        else:
            check(reason in SIX, f"reason in six-class set ({reason})")
            census[reason] = census.get(reason, 0) + 1

    check(set(census.keys()) <= SIX, "no class outside the six")
    total = sum(census.values())
    check(total == 201, f"six-class census closes at 201 (got {total})")

    # the moved row, pinned both ways
    check(rows[(3, 8, 4)] == "rope_break",
          "island 3 gen 8 idx 4 reads rope_break at a76c5e9")
    check(rows[(2, 3, 5)] == "hub_tip" and rows[(3, 5, 10)] == "hub_tip",
          "the two hub_tip rows at a76c5e9 are island2/gen3/idx5 and island3/gen5/idx10")
    head_log = (DIR / "head_run_reject_probe_full.log").read_text()
    check("[181/201] island=3 gen=8 idx=4  hub_tip" in head_log,
          "the HEAD run reads the moved row as hub_tip")

    # the landed register block (search upward for the repo root)
    reg_path = None
    for p in [DIR, *DIR.parents]:
        cand = p / "docs" / "reporting" / "numbers-register.md"
        if cand.exists():
            reg_path = cand
            break
    check(reg_path is not None, "register file found from the evidence dir")
    reg = reg_path.read_text()
    check("## Source row: NR-061, the six-class 201-reject split at the "
          "producing commit (2026-10-18, science-validator)" in reg,
          "register NR-061 heading")
    check("betz_cp_floor 93, settle_fail 37, spacing 36, rope_break 30, "
          "betz_ceiling 3, hub_tip 2" in reg, "register NR-061 values")
    check("Island 3, gen 8, idx 4 reads hub_tip at HEAD and rope_break at the "
          "producing commit." in reg, "register moved-row line")
    check("Counter-read requested from the aero seat" in reg,
          "register counter-read line")

    print("\n== six-class census at the producing commit a76c5e9 ==")
    for cls in sorted(census, key=lambda c: -census[c]):
        print(f"  {cls:<14} {census[cls]}")

    head = {"betz_cp_floor": 93, "settle_fail": 37, "spacing": 36,
            "rope_break": 29, "betz_ceiling": 3, "hub_tip": 3}
    print("\n== delta vs the HEAD re-run (b65e9c8) ==")
    for cls in sorted(SIX):
        d = census.get(cls, 0) - head[cls]
        mark = "" if d == 0 else f"  <-- moved by {d:+d}"
        print(f"  {cls:<14} a76c5e9 {census.get(cls, 0):>3} | HEAD {head[cls]:>3}{mark}")

    print(f"\nSV_REJECT_SIXCLASS_MERGE_DONE ({checks} checks, 0 fail)")


if __name__ == "__main__":
    main()

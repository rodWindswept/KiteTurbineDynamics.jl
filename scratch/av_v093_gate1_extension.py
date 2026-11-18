#!/usr/bin/env python3
"""Aero-validator gate-1 extension read on the v0.93 blob at 76b2fb48.

Covers the aerodynamic deltas the fold introduced:
  1. the Glauert four-sentence block (NR-086 numerals, no cite on 12.4);
  2. the two NR-056 wind-pair cells;
  3. the 57 W bracket unchanged;
  4. the Tveide credit scope and entry 19;
  5. the withholding sentence gone, B16 anchor gone.
"""
import re
import subprocess
import sys

REPO = "/home/rod/Documents/GitHub/KiteTurbineDynamics.jl"
DRAFT = f"{REPO}/docs/reporting/drafts/2026-10-08-report-first-draft.md"

HEAD = subprocess.run(
    ["git", "-C", REPO, "rev-parse", "--short", "HEAD"],
    capture_output=True, text=True).stdout.strip()
assert HEAD == "76b2fb48", f"expected 76b2fb48, at {HEAD}"

text = open(DRAFT).read()
lines = text.splitlines()

checks = 0
fails = 0


def check(cond, msg):
    global checks, fails
    checks += 1
    if not cond:
        fails += 1
        print(f"FAIL: {msg}")
    else:
        print(f"PASS: {msg}")


print("=== 1. Glauert block (after the display equation) ===")
block = (
    "Its value at 30 degrees of tilt reads 0.5192 at a = 0.3434 (NR-086).\n"
    "At zero tilt the same form reads 16/27 at a = 1/3 (NR-086).\n"
    "The 30-degree coefficient sits 12.4 per cent lower on the same disc area.\n"
    "The main text quotes its share on the wind-normal area, which equals the disc area only at zero tilt."
)
check(block in text, "four-sentence block prints verbatim after the display equation")
check(text.count("NR-086") == 2, f"NR-086 cites == 2, one per anchor (found {text.count('NR-086')})")
check("12.4 per cent lower on the same disc area." in text, "12.4 sentence prints")
check("(NR-086)" not in
      text.split("12.4 per cent lower")[1].split("\n")[0],
      "the 12.4 sentence carries no citation")
check("waits on a signed row" not in text, "the withholding sentence is gone")

print("\n=== 2. NR-056 wind-pair cells ===")
abs_hit = [i for i, l in enumerate(lines, 1) if "11.01 m/s at 9.41 m" in l]
for n in abs_hit:
    check("NR-056" in lines[n - 1], f"line {n} wind pair carries NR-056")
check(len(abs_hit) == 2, f"two wind-pair sites (found {len(abs_hit)} at {abs_hit})")
check("NR-008, NR-032" not in text or "(NR-008, NR-032)" not in text,
      "the old (NR-008, NR-032) bracket is gone")

print("\n=== 3. 57 W bracket ===")
gap_line = [l for l in lines if "57 W" in l and "delivered torque" in l]
check(len(gap_line) == 1 and "(NR-030, NR-015, NR-029)" in gap_line[0],
      f"57 W line keeps the NR-030/NR-015/NR-029 bracket ({gap_line})")
check("396.76" in text and "401.03" in text, "both torque numerals print")

print("\n=== 4. Tveide credit and entry 19 ===")
check("Tveide's note states the half-shortening peak-torque identity and the geometry-free torque margin." in text,
      "credit sentence one prints, Tveide's note, verb states, both results named")
check("math.osp.no/parameter-fibers" in text, "public page prints")
check("private communication" in text.lower(), "private communication prints")
check("Nineteen sources follow" in text, "the list reads nineteen")
check("Seventeen of the nineteen" in text, "the control tally reads seventeen of nineteen")
check("19. Tveide" in text or re.search(r"\b19\.\s+Tveide", text) is not None,
      "entry 19 exists in the reference list")

print("\n=== 5. Cited-row census against the register ===")
reg = open(f"{REPO}/docs/reporting/numbers-register.md").read()
cited = sorted(set(int(m) for m in re.findall(r"NR-0?(\d+)", text)))
signed = sorted(set(int(m) for m in re.findall(r"\| NR-(\d+) \|", reg)))
unsigned = [n for n in cited if n not in signed]
check(len(cited) == 60, f"cited distinct rows = {len(cited)} (60 expected)")
check(not unsigned, f"no unsigned cited row ({unsigned})")

print(f"\nSUMMARY: {checks} checks, {fails} fails")
sys.exit(1 if fails else 0)

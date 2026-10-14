#!/usr/bin/env python3
"""Sweep 29 span guards: the Tulloch guard, the two 22-degree facts apart,
the sanctioned near-hits and the base-factor re-derivation (2026-10-14).

Read-only. Complements sw_sweep29_core.sh section 5.
"""
import re

t = open("scratch/sw_sweep29_draft_v043.md").read()
lines = t.splitlines()

print("== Tulloch guard ==")
hits = [i + 1 for i, l in enumerate(lines) if "Tulloch" in l]
print("Tulloch lines:", hits)
for i in hits:
    print(f"  {i}: {lines[i-1]}")
print("compound 'Tulloch and Jensen' or 'Tulloch/Jensen':",
      len(re.findall(r"Tulloch and Jensen|Tulloch/Jensen", t)))
print("'Jensen' count:", t.count("Jensen"))
cone = [i + 1 for i, l in enumerate(lines) if "shaft transition cone" in l]
print("cone statement lines:", cone)
if hits and cone:
    print("min line distance, Tulloch to a cone statement:",
          min(abs(h - c) for h in hits for c in cone))

print()
print("== the two 22-degree facts apart ==")
for m in re.finditer(r"22 degrees", t):
    a = max(0, m.start() - 95)
    seg = t[a:m.end()].replace("\n", " ")
    print("  ...", seg)
    print("     cone name in window:", "shaft transition cone" in seg)
    print("     bank naming in window:", ("bank slot" in seg) or ("bank_bottom" in seg))

print()
print("== sanctioned near-hits (cyan line, bridles, driveshaft negation) ==")
for pat in [r"rigid driveshaft", r"cyan line", r"bridles"]:
    for m in re.finditer(pat, t):
        i = t[:m.start()].count("\n") + 1
        print(f"  {i}: {lines[i-1].strip()}")

print()
print("== base-factor re-derivation (NR-050 digits) ==")
r = 2.4341173109692225
print("0.75 * r       =", repr(0.75 * r), "(recorded base span 1.8255879832269168)")
print("0.113 * r      =", repr(0.113 * r))
print("span * scale   =", repr(1.8255879832269168 * 0.8213255027884769),
      "(recorded span 1.4994019682084492, NR-043)")
print("chord * scale  =", repr(0.113 * r * 0.8213255027884769),
      "(quoted chord 0.22590989654340632)")

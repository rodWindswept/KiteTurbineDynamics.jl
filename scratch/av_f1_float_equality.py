#!/usr/bin/env python3
# scratch/av_f1_float_equality.py - aero-validator, 2026-10-12.
# F1 content check, section 2: prove the decode receipt's genome literals and
# the register block readings are the same doubles, and that the rounded print
# forms equal the values the plate prints.
pairs = [
    ("hub radius", "4.57997905482005", "4.5799790548200496", 3, 4.580),
    ("ground radius", "0.8036829846088207", "0.8036829846088207", 3, 0.804),
    ("main-rotor bank (deg)", "7.088131460323565", "7.0881314603235648", 3, 7.088),
    ("active blade scale", "0.8213255027884769", "0.8213255027884769", 2, 0.82),
]
print("== F1 float equality spot-check (aero-validator, 2026-10-12) ==")
print("left: decode receipt genome literal; right: register block reading")
ok = True
for label, a, b, dp, printed in pairs:
    fa, fb = float(a), float(b)
    same = fa == fb
    r = round(fa, dp)
    ok = ok and same and abs(r - printed) < 1e-12
    print(f"{label}: same_double={same} diff={fa - fb!r} round{dp}={r} printed={printed}")
print("ALL EQUALITY CHECKS PASS" if ok else "MISMATCH FOUND")

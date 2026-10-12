#!/usr/bin/env python3
# av_counter_nr037.py — aero counter-read of NR-037 (2026-10-12, aero-validator)
# Independent recompute of the derived lift-chain set from NR-018 and the
# NR-026 sizing law. Mirrors the code authority src/lift_kite.jl sized_lifter_for
# (margin 1.5; sizing mass net of the flat 5 kg lifter; g = 9.81; tension at 70 deg).
import math

m_air = 25.69846825623688          # NR-018, full airborne mass
m_sizing = m_air - 5.0             # NR-026, net of the flat 5 kg lifter
g = 9.81                           # src/lift_kite.jl:208
F_vert = 1.5 * m_sizing * g        # NR-026 sizing law
W = m_air * g                      # full airborne weight
T = F_vert / math.sin(math.radians(70.0))

checks = [
    ("F_vert", F_vert, 304.5779603905257),
    ("weight", W, 252.1019735936838),
    ("ratio", F_vert / W, 1.2081538119230202),
    ("tension", T, 324.1250954336462),   # also the NR-010 full digit
]
for name, got, want in checks:
    print(f"{name:8s} = {got!r}  match={got == want}")
assert all(got == want for _, got, want in checks)
print("NR-037 counter-read: bit-exact on all four values; tension equals NR-010.")

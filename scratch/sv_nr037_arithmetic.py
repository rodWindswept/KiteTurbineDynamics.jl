#!/usr/bin/env python3
# sv_nr037_arithmetic.py — NR-037 lift-chain derived set (science-validator, 2026-10-12)
# Derived on NR-018 (winner airborne mass) and NR-026 (sizing margin 1.5, net of the 5 kg lifter).
import math

m_air = 25.69846825623688          # NR-018
m_sizing = m_air - 5.0             # NR-026: the lifter carries itself
F_vert = 1.5 * m_sizing * 9.81     # NR-026 sizing law: 1.5 x m x g
W = m_air * 9.81                   # full airborne weight

print("m_sizing =", repr(m_sizing))
print("F_vert   =", repr(F_vert))
print("W        =", repr(W))
print("ratio    =", repr(F_vert / W))
print("T(70deg) =", repr(F_vert / math.sin(math.radians(70))),
      "  (must equal NR-010 = 324.1250954336462)")

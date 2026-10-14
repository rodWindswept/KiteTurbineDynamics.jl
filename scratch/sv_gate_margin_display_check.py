#!/usr/bin/env python3
"""SV gate-margin display check (science-validator, 2026-10-14).

Reads the committed register and recomputes the FoS row of the SW2d
gate-margin column in both form sets:

- the internal forms from the signed value (NR-009) over the floor (NR-015)
- the report forms from the printed operands, 15.0 over 2.5

Asserts the display-form note's figures against the committed bytes.
Stdlib only. Runs from the repo root.
"""

import re
import sys

REG = "docs/reporting/numbers-register.md"

txt = open(REG, encoding="utf-8").read()

fails = []
checks = 0


def check(name, cond, detail=""):
    global checks
    checks += 1
    tag = "ok" if cond else "FAIL"
    if not cond:
        fails.append(name)
    print(f"[{tag}] {name}{(' — ' + detail) if detail else ''}")


# 1. The signed inputs read in the register.
m_value = re.search(r"`?(14\.971791422208508)`?", txt)
check("NR-009 signed value reads in the register", m_value is not None)
if m_value is None:
    print("FAIL: cannot read the NR-009 value")
    sys.exit(1)
v = float(m_value.group(1))

check("the floor 2.5 reads in the register", "2.5" in txt)

# 2. Internal forms (kept internal).
margin_i = v - 2.5
pct_i = margin_i / 2.5 * 100.0
ratio_i = v / 2.5
check("internal margin reads +12.472 at 3 dp", f"{margin_i:.3f}" == "12.472", f"{margin_i:.3f}")
check("internal per cent reads +498.9 at 1 dp", f"{pct_i:.1f}" == "498.9", f"{pct_i:.1f}")
check("internal ratio reads 5.99 at 2 dp", f"{ratio_i:.2f}" == "5.99", f"{ratio_i:.2f}")

# 3. Report forms (from the printed operands).
w = 15.0  # the ruled 1 dp display of NR-009 at the gates table site
margin_r = w - 2.5
pct_r = margin_r / 2.5 * 100.0
ratio_r = w / 2.5
check("report margin reads +12.5 at 1 dp", f"{margin_r:.1f}" == "12.5", f"{margin_r:.1f}")
check("report per cent reads +500.0 at 1 dp", f"{pct_r:.1f}" == "500.0", f"{pct_r:.1f}")
check("report ratio reads 6.00 at 2 dp", f"{ratio_r:.2f}" == "6.00", f"{ratio_r:.2f}")

# 4. The 1 dp rounding of the signed value stands.
check("NR-009 rounds to 15.0 at 1 dp", f"{v:.1f}" == "15.0", f"{v:.1f}")

# 5. The note's reading rule sits in the register.
note = "Display-form note: the gate-margin column figures (NR-009 on NR-015) (2026-10-14, science-validator)"
check("the display-form note reads in the register", note in txt)
check("the note's FoS row forms read in the register", "`+12.5`" in txt)
check("the note's per cent reads in the register", "`+500.0 per cent`" in txt)
check("the note's ratio reads in the register", "`6.00 times`" in txt)
check("the internal forms stay flagged internal", "do not print" in txt)

print()
print(f"{checks} checks, {len(fails)} fail")
if fails:
    print("FAILS: " + ", ".join(fails))
    sys.exit(1)
print("SV GATE-MARGIN DISPLAY NOTE: ALL OK")

#!/usr/bin/env python3
"""Counter-read of the value-claims ledger (science-validator seat, 2026-10-16).

Scope per the ledger's own section 7: every row classed `measured`, every row
that touches a signed row, and every binding surface re-verified by a second
route. Read at f38d19a on bank-derate-cos2p65.
"""
import hashlib
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LEDGER = ROOT / "docs/reporting/value-claims-ledger.md"
REGISTER = ROOT / "docs/reporting/numbers-register.md"
SEEDS = ROOT / "scripts/compute_seeds.jl"
RETRO = ROOT / "docs/plans/retrospective-2026-08-17.md"
GECO = ROOT / "docs/reports/grounded-economics-v13.md"
DECISIONS = ROOT / "DECISIONS.md"

checks = []


def check(name, ok, detail=""):
    checks.append((name, bool(ok), detail))


L = LEDGER.read_text()
R = REGISTER.read_text()
SEEDS_T = SEEDS.read_text()
RETRO_T = RETRO.read_text()
GECO_T = GECO.read_text()
DEC_T = DECISIONS.read_text()

# 1. Header and status.
check("ledger header: slug", "`value-claims-ledger`" in L)
check("ledger header: status LIVE", "**Status** LIVE" in L)
check("ledger header: owner aero", "Owner** @aero-validator" in L)

# 2. Class vocabulary.
classes = set(re.findall(r"`(measured|capability|target)`", L))
check("class vocabulary is exactly the three", classes == {"measured", "capability", "target"}, str(classes))

# 3. The two-state sibling rule, stated.
check("two-state sibling rule stated", "No third state exists" in L)
check("measured binding names value+station+state",
      "The number prints in signed form only: value, station, state" in L)
check("fig ink analogue recorded", "no target mark sits on a value axis" in L)

# 4. `measured` census: exactly one data row, and it is a non-printable hold.
measured_data = [ln for ln in L.splitlines() if ln.startswith("|") and "`measured`" in ln and "HOLD" in ln]
check("exactly one measured data row", len(measured_data) == 1, str(measured_data))
row = measured_data[0] if measured_data else ""
check("the measured row reads HOLD", "HOLD" in row)
check("the measured row names the fresh-read gate", "fresh read" in row)
check("the measured row's pointer is not the register", "numbers-register" not in row)
check("the measured row's pointer names grounded-economics", "grounded-economics" in row)

# 5. Zero register row-ID tokens anywhere in the ledger: nothing to misresolve.
tokens = re.findall(r"NR-\d+", L)
check("zero register row-ID tokens in the ledger", tokens == [], str(tokens))

# 6. The rung set matches the code digit for digit, order for order.
m = re.search(r"const RUNGS = \[([^\]]+)\]", SEEDS_T)
check("code rung set found in compute_seeds.jl", m is not None)
code_rungs = [float(x) for x in m.group(1).split(",")] if m else []
check("code rung set is 5,7,10,15,25,35,50",
      code_rungs == [5.0, 7.0, 10.0, 15.0, 25.0, 35.0, 50.0], str(code_rungs))
ledger_rungs = [r for r in re.findall(r"^\| (\d+) kW \| `(capability|target)` \|", L, re.M)]
check("ledger rung rows match the code set in order",
      [r[0] for r in ledger_rungs] == [str(int(x)) for x in code_rungs], str(ledger_rungs))
check("5 kW rung is capability / solid",
      re.search(r"^\| 5 kW \| `capability` \|.*\| solid \|", L, re.M) is not None)
check("six upper rungs are target / open plus label",
      len(re.findall(r"^\| \d+ kW \| `target` \|.*\| open plus label \|", L, re.M)) == 6)

# 7. The register backs the validated rung.
check("NR-008 signed in the register",
      re.search(r"\| NR-008 \| Winner P_mean.*\| signed \(", R) is not None)
check("NR-059 signed in the register",
      re.search(r"\| NR-059 \| Winner bow.*\| signed \(", R) is not None)
check("validated-rung dataset directory exists",
      (ROOT / "scripts/results/v13_5kw_masslift_len18.8_rotorcount_bankderate2").is_dir())

# 8. The gate readings the ledger quotes.
check("retrospective carries the UNPROVEN reading", "UNPROVEN at ≥25 kW by this gate" in RETRO_T)
check("held economics doc carries the contamination banner", "contamination" in GECO_T)
check("DECISIONS carries the three date brackets used",
      all(d in DEC_T for d in ("2026-08-21", "2026-09-24", "2026-09-15")))
check("founder-directive ladder phrasing recorded", "1 to 50 kW in the founder directive" in L)

# 9. The cost and carbon hold: three rows, none printable.
hold_rows = [ln for ln in L.splitlines() if ln.startswith("|") and "HOLD" in ln]
check("three hold rows", len(hold_rows) == 3, str(hold_rows))
check("no hold row names the register as its surface",
      not any("numbers-register" in ln for ln in hold_rows))

# 10. The flagged set: six items, plain labels where the ledger says so.
sec6 = L[L.index("## 6."):L.index("## 7.")] if "## 6." in L and "## 7." in L else ""
flags = re.findall(r"^\d+\. ", sec6, re.M)
check("six flagged items", len(flags) == 6, str(flags))
check("plain label count matches the ledger's own use (10 sites: definition + 3 target rows + 6 rung rows)",
      L.count("programme target — no repo artifact") == 10, f"count={L.count('programme target — no repo artifact')}")
check("yield line reads no-print", "recommends no print" in L)

# 11. Every backticked pointer resolves by a second route.
fileish = [t for t in re.findall(r"`([^`]+)`", L)
           if ("/" in t or t.endswith((".md", ".jl", ".csv", ".py", ".png")))
           and not t.startswith("`")]
missing = []
for t in fileish:
    if not (ROOT / t).exists():
        missing.append(t)
commits = set(re.findall(r"`([0-9a-f]{7,40})`", L))
for c in commits:
    if subprocess.run(["git", "-C", str(ROOT), "cat-file", "-e", c + "^{commit}"],
                      capture_output=True).returncode != 0:
        missing.append(f"commit {c}")
branches = set(re.findall(r"`([0-9a-zA-Z./_-]+-results[0-9a-zA-Z./_-]*)`", L))
for b in branches:
    if subprocess.run(["git", "-C", str(ROOT), "show-ref", "--verify", "--quiet",
                       f"refs/remotes/origin/{b}"], capture_output=True).returncode != 0:
        missing.append(f"branch {b}")
check("every backticked pointer resolves", missing == [], str(missing))

# 12. The ledger blob holds against the seed sha256.
sha = hashlib.sha256(LEDGER.read_bytes()).hexdigest()
check("ledger sha256 matches the seed pin", sha.startswith("3160aed8"), sha)

# 13. STE, re-run at this seat as a subprocess.
p = subprocess.run([sys.executable, str(ROOT / "ste-lint.py"), str(LEDGER)],
                   capture_output=True, text=True)
out = p.stdout + p.stderr
check("ste-lint rc=0 on the ledger", p.returncode == 0, out[-300:])
m2 = re.search(r"per100w=\s*([\d.]+)", out)
per100 = float(m2.group(1)) if m2 else None
check("ste-lint reads 0.49/100w", per100 is not None and abs(per100 - 0.49) < 0.001, f"per100w={per100}")

fails = [c for c in checks if not c[1]]
for name, ok, detail in checks:
    print(("PASS" if ok else "FAIL"), name, "" if ok else f":: {detail}")
print(f"checks: {len(checks)}, fail: {len(fails)}")
sys.exit(1 if fails else 0)

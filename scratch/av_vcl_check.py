#!/usr/bin/env python3
"""scratch/av_vcl_check.py — the value-claims ledger seed check (aero seat, 2026-10-16).

Second routes, not re-reads:
  1. Pointers: every backticked pointer token resolves (tracked path via git
     ls-files, commit object via git cat-file, branch ref via git rev-parse).
  2. The rung set in the ledger matches `const RUNGS` in scripts/compute_seeds.jl.
  3. The class vocabulary: only the four agreed class names class elements.
  4. The required rows and flags exist (hold set, flagged set, rungs, ink).
  5. STE: ste-lint.py runs as a subprocess on the ledger and the receipt.

Prints "N checks, 0 fail". Exit 1 on any fail.
"""

import hashlib
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LEDGER = ROOT / "docs" / "reporting" / "value-claims-ledger.md"
RECEIPT = ROOT / "docs" / "reporting" / "room-responses" / "aero-validator-2026-10-16-value-claims-ledger.md"
REGISTER = ROOT / "docs" / "reporting" / "numbers-register.md"
SEEDS = ROOT / "scripts" / "compute_seeds.jl"

CLASSES = {"measured", "capability", "target", "assumption"}
SKIP_TOKENS = {
    "value-claims-ledger",
    "measured",
    "capability",
    "target",
    "assumption",
    "programme target — no repo artifact",
    "study assumption — chosen, not read, flat across the curve",
    "HOLD",
}
LABEL = "programme target — no repo artifact"

CHECKS = []


def check(name, ok, detail=""):
    CHECKS.append((name, bool(ok)))
    mark = "OK  " if ok else "FAIL"
    line = f"{mark} {name}"
    if detail and not ok:
        line += f"  [{detail}]"
    print(line)


def run(cmd):
    return subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)


def tracked(tok):
    p = run(["git", "ls-files", "--", tok])
    if p.stdout.strip():
        return True
    p = run(["git", "ls-files", "--", tok.rstrip("/") + "/"])
    return bool(p.stdout.strip())


def classify(tok):
    """Return 'skip', or a resolver result (True/False), for one backticked token."""
    if tok in SKIP_TOKENS:
        return "skip"
    if tok == "competitor_comparison":
        return "competitor_comparison" in (ROOT / "src" / "economics.jl").read_text()
    if re.fullmatch(r"[0-9a-f]{7,40}", tok):
        return run(["git", "cat-file", "-e", f"{tok}^{{commit}}"]).returncode == 0
    if tok == "bankderate2-results":
        return run(["git", "rev-parse", "--verify", "bankderate2-results"]).returncode == 0
    if tok.startswith("coax@"):
        m = re.fullmatch(r"coax@([0-9a-f]{7,40}):(.+)", tok)
        if not m:
            return False
        sha, path = m.groups()
        p = subprocess.run(
            ["git", "-C", str(ROOT.parent / "CoaxialAutogyroStacking.jl"), "cat-file", "-e", f"{sha}:{path}"],
            capture_output=True, text=True,
        )
        return p.returncode == 0
    if "/" in tok or tok.endswith((".md", ".py", ".jl", ".csv", ".png", ".txt")):
        return (ROOT / tok).exists() and tracked(tok)
    return "unknown"


def main():
    print(f"# value-claims ledger seed check — {datetime.now(timezone.utc).isoformat(timespec='seconds')}")
    text = LEDGER.read_text()
    receipt = RECEIPT.read_text()

    # 1. Files exist.
    check("ledger file exists", LEDGER.exists())
    check("receipt file exists", RECEIPT.exists())
    check("register file exists", REGISTER.exists())
    check("seeds script exists", SEEDS.exists())

    # 2. Pointer resolution.
    tokens = sorted(set(re.findall(r"`([^`]+)`", text)))
    pointer_hits = []
    unknown = []
    for tok in tokens:
        result = classify(tok)
        if result == "skip":
            continue
        if result == "unknown":
            unknown.append(tok)
            continue
        pointer_hits.append((tok, result))
    failed = [t for t, ok in pointer_hits if not ok]
    check("no unknown backticked tokens", not unknown, ", ".join(unknown))
    check("every pointer token resolves", not failed, ", ".join(failed))
    check("pointer token count >= 15", len(pointer_hits) >= 15, str(len(pointer_hits)))
    check("pointer paths cover the docs tree", any(t.startswith("docs/") for t, _ in pointer_hits))
    check("pointer paths cover scripts", any(t.startswith("scripts/") for t, _ in pointer_hits))
    check("pointer paths cover src", any(t.startswith("src/") for t, _ in pointer_hits))
    check("commit pointer present", any(re.fullmatch(r"[0-9a-f]{7,40}", t) for t, _ in pointer_hits))
    check("branch pointer present", any(t == "bankderate2-results" for t, _ in pointer_hits))

    # 3. Class vocabulary and element rows.
    section2 = text.split("## 2. Capability elements", 1)[1]
    class_cells = []
    for line in section2.splitlines():
        if not line.startswith("|"):
            continue
        cells = [c.strip().strip("`") for c in line.strip("|").split("|")]
        for c in cells:
            if c in CLASSES:
                class_cells.append(c)
    unclassed = []
    for line in section2.splitlines():
        if not line.startswith("|"):
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if len(cells) != 3 or cells[0] == "Element" or not cells[0].strip("-"):
            continue
        cls = cells[1].strip("`")
        if cls not in CLASSES:
            unclassed.append(f"{cls} [{line.strip()[:48]}]")
    check("element rows carry only the four classes", not unclassed, "; ".join(unclassed))
    check("element row count >= 18", len(class_cells) >= 18, str(len(class_cells)))
    check("CoAx model row present", "coax@2e1b1e1:src/bem.jl" in text)
    for cls in sorted(CLASSES):
        check(f"class present: {cls}", cls in class_cells)

    # 4. Rungs and RUNGS match.
    for kw in ("5 kW", "7 kW", "10 kW", "15 kW", "25 kW", "35 kW", "50 kW"):
        check(f"rung row present: {kw}", f"| {kw} |" in text)
    check("exactly one solid ink row", text.count("| solid |") == 1, str(text.count("| solid |")))
    solid_line = [l for l in text.splitlines() if l.startswith("| 5 kW ") or l.startswith("| 5 kW |")]
    check("the solid row is the 5 kW rung", bool(solid_line) and "solid" in solid_line[0])
    m = re.search(r"const RUNGS = \[([0-9.,\s]+)\]", SEEDS.read_text())
    ledger_set = [5.0, 7.0, 10.0, 15.0, 25.0, 35.0, 50.0]
    check("ledger rung set matches const RUNGS", bool(m) and [float(x) for x in m.group(1).split(",") if x.strip()] == ledger_set)

    # 5. Hold set and the flagged set.
    check("hold set carries >= 3 rows", text.count("| HOLD |") >= 3, str(text.count("| HOLD |")))
    check("hold row: the economics pair", "4.8 p/kWh" in text and "0.17 gCO2e/kWh" in text)
    check("hold row: the v13 readings", "grounded-economics-v13.md" in text)
    check("hold row: the April kit", "produce_kite_turbine_potential_report.py" in text)
    flagged = text.split("## 6. Flagged set", 1)[1].split("## 7.", 1)[0]
    flagged_items = [l for l in flagged.splitlines() if re.match(r"^\d+\. ", l)]
    check("flagged set carries >= 5 items", len(flagged_items) >= 5, str(len(flagged_items)))
    for needle in ("first commercial product", "network-of-network", "Offshore", "gigatonne", "yield line"):
        check(f"flag present: {needle}", needle in flagged)
    check("plain label present >= 6 times", text.count(LABEL) >= 6, str(text.count(LABEL)))

    # 6. Register binding notes.
    check("enforcement region named", "The enforcement region is the close" in text)
    check("register cited in notes", "docs/reporting/numbers-register.md" in text.split("## 7.", 1)[1])

    # 7. STE subprocess runs.
    for label, path in (("ledger", LEDGER), ("receipt", RECEIPT)):
        p = run(["python3", "ste-lint.py", "--fail-above", "2.0", str(path.relative_to(ROOT))])
        last = ((p.stdout or p.stderr).strip().splitlines() or [""])[-1]
        check(f"ste-lint rc=0 on the {label}", p.returncode == 0, last)
        nums = re.findall(r"per100w=\s*([0-9.]+)", p.stdout)
        check(f"ste-lint under the gate on the {label}", bool(nums) and float(nums[-1]) < 2.0, nums[-1] if nums else "no count")

    # 8. Fingerprint.
    digest = hashlib.sha256(LEDGER.read_bytes()).hexdigest()
    print(f"ledger sha256 {digest}")

    fails = sum(1 for _, ok in CHECKS if not ok)
    print(f"\n{len(CHECKS)} checks, {fails} fail")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())

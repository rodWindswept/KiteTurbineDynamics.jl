#!/usr/bin/env python3
"""Compare each kit's render pin with the script it names.

Three readings, one kit at a time:

  A. the script at the recorded pin hashes to script.sha256;
  B. the script on disk hashes to script.sha256;
  C. the pin is an ancestor of HEAD.

A pair that goes stale together passes A and fails B, which is the state no
other gate can see: the plate was drawn by a script no recorded commit names.
"""
from __future__ import annotations

import hashlib
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FIG = ROOT / "docs" / "reporting" / "figures"
SEATED = [
    "system-anatomy", "machine-winner-hero", "ring-utilisation", "twist-limit",
    "pca-landscape", "pca-atlas", "machine-corner-grid",
    "machine-evolution-strip", "machine-power-trend",
]


def git(*args: str) -> subprocess.CompletedProcess:
    return subprocess.run(["git", "-C", str(ROOT), *args], capture_output=True)


def sha(b: bytes) -> str:
    return hashlib.sha256(b).hexdigest()


def pin_of(m: dict) -> str | None:
    sc = m.get("script_commit") or m.get("render_commit")
    if sc:
        return sc
    for tok in m.get("command", "").split():
        if len(tok) in (7, 8, 40) and all(c in "0123456789abcdef" for c in tok):
            return tok
    return None


def main() -> int:
    root = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else ROOT
    bad = 0
    for kit in SEATED:
        manifest = root / "docs/reporting/figures" / kit / "manifest.json"
        if not manifest.exists():
            print(f"MISSING  {kit}"); bad += 1; continue
        m = json.loads(manifest.read_text())
        rel = m.get("script", {}).get("path")
        want = m.get("script", {}).get("sha256")
        pin = pin_of(m)
        if not (rel and want and pin):
            print(f"NO-PIN   {kit}"); bad += 1; continue
        at_pin = git("-C", str(root), "show", f"{pin}:{rel}")
        a = at_pin.returncode == 0 and sha(at_pin.stdout) == want
        disk = (root / rel).read_bytes() if (root / rel).exists() else b""
        b = bool(disk) and sha(disk) == want
        anc = git("-C", str(root), "merge-base", "--is-ancestor", pin, "HEAD").returncode == 0
        marks = "".join("+" if x else "-" for x in (a, b, anc))
        state = "OK" if (a and b and anc) else "RED"
        i = kit.ljust(24); p = (pin or "-").ljust(9)
        if state == "RED":
            print(f"{state:8s} {i} {p} A{marks[0]}B{marks[1]}C{marks[2]}")
            print(f"         script at pin, script on disk, pin ancestry: {marks}; sha256 {want[:12]}")
            bad += 1
        else:
            print(f"{state:8s} {i} {p} script at pin, script on disk, pin ancestry: {marks}")
    print(f"\n{len(SEATED) - bad}/{len(SEATED)} kits carry a pin that names the script that drew the plate")
    return 1 if bad else 0


if __name__ == "__main__":
    raise SystemExit(main())

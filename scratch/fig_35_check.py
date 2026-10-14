#!/usr/bin/env python3
"""Check: the Harris-3.5 render deltas (figures seat, 2026-10-14).

Asserts, for both mechanism-pair plates:
  1. the three-way render identity (delivered == A == B, all five outputs);
  2. the stamps carry the script commit 671ab96;
  3. the new forms read; the retired forms are gone;
  4. the drawn values stand (the F-VALUE input set);
  5. the manifest pins recompute (script sha256, extract sha256, outputs).

Run from the repo root:
  /usr/bin/python3 scratch/fig_35_check.py
"""
import hashlib
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
H1 = "671ab96"
OK = 0
FAIL = 0


def ok(msg):
    global OK
    OK += 1
    print(f"  ok   {msg}")


def bad(msg):
    global FAIL
    FAIL += 1
    print(f"  FAIL {msg}")


def sha(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest()


def md5(p):
    return hashlib.md5(Path(p).read_bytes()).hexdigest()


KITS = {
    "ring-utilisation": "fig_35_A_ring",
    "twist-limit": "fig_35_A_twist",
}
KITS_B = {
    "ring-utilisation": "fig_35_B_ring",
    "twist-limit": "fig_35_B_twist",
}
FILES = ["{s}.svg", "{s}.pdf", "{s}.png", "label-ledger.txt", "manifest.json"]

print("[1] the three-way render identity")
for slug, a in KITS.items():
    for f in FILES:
        fn = f.format(s=slug)
        d = (ROOT / "docs/reporting/figures" / slug / fn)
        ma = md5(ROOT / "scratch" / a / fn)
        mb = md5(ROOT / "scratch" / KITS_B[slug] / fn)
        md = md5(d)
        (ok if ma == mb == md else bad)(f"{slug}: {fn} identical (md5 {md[:16]})")

print("[2] the stamps carry the script commit")
for slug in KITS:
    svg = (ROOT / "docs/reporting/figures" / slug / f"{slug}.svg").read_text()
    ledger = (ROOT / "docs/reporting/figures" / slug / "label-ledger.txt").read_text()
    (ok if f"script commit {H1}" in svg else bad)(f"{slug}: stamp in the SVG")
    (ok if f"script commit {H1}" in ledger else bad)(f"{slug}: stamp in the ledger")

print("[3a] ring: the new forms read; the retired forms are gone")
ring = (ROOT / "docs/reporting/figures/ring-utilisation/label-ledger.txt").read_text()
for s in (
    "utilisation (N/N_crit + √(M_ip²+M_oop²)/M_el, worst beam)",
    "utilisation — beam-column interaction, log scale",
    "10⁻⁶", "10⁻¹",
    "FoS 15.033", "FoS 30.087", "FoS 29.807", "FoS 35.236", "FoS 326,974",
    "fail boundary",
):
    (ok if s in ring else bad)(f"ring: present {s[:60]!r}")
for s in ("axial share", "bending share", "stack"):
    (bad if s in ring else ok)(f"ring: retired {s!r}")

print("[3b] twist: the new forms read; the retired forms are gone")
twist = (ROOT / "docs/reporting/figures/twist-limit/label-ledger.txt").read_text()
for s in (
    "Every segment of the winner runs well inside its binding limit",
    "Transmitted twist against its binding limit, the realisability",
    "A — twist: transmitted twist |Δα| against its binding limit",
    "realisability floor 72.25°",
    "no limit — the segment's tether is shorter than the sum of its end",
    "92.6", "98.9", "33.5", "33.9", "22.8",
):
    (ok if s in twist else bad)(f"twist: present {s[:60]!r}")
for s in ("22,425", "62 revolutions", "asin", "off scale", "42.6"):
    (bad if s in twist else ok)(f"twist: retired {s!r}")

print("[4] the drawn values stand (spot set)")
for s in ("396.8", "397.2", "397.5", "397.7", "805.0", "808.7", "812.2", "815.7", "1069.9"):
    (ok if s in twist else bad)(f"twist: drawn {s}")

print("[5] the manifest pins recompute")
for slug in KITS:
    d = ROOT / "docs/reporting/figures" / slug
    man = json.loads((d / "manifest.json").read_text())
    (ok if sha(d / f"{slug}.py") == man["script"]["sha256"] else bad)(f"{slug}: script sha256")
    (ok if H1 in man["command"] else bad)(f"{slug}: command carries {H1}")
    extract = ROOT / ("docs/reporting/figures/pair-extract/"
                      "extract-winner-operating-point.csv")
    (ok if sha(extract) == man["inputs"]["extract"]["sha256"] else bad)(f"{slug}: extract sha256")
    for out, want in man["outputs"].items():
        (ok if sha(d / out) == want else bad)(f"{slug}: output pin {out}")

print(f"\nchecks: {OK + FAIL}  ok: {OK}  fail: {FAIL}")
sys.exit(1 if FAIL else 0)

#!/usr/bin/env python3
"""fig-r6 check pass — verify the round-6 landing end to end.

Run from the repo root: /usr/bin/python3 scratch/fig_r6_check.py
Writes scratch/fig_r6_check.log; exits nonzero on any fail.
"""
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(".")
SC = "1af63fc"
K = ROOT / "docs/reporting/figures"
n_ck = n_fail = 0
out = []

def chk(name, cond, detail=""):
    global n_ck, n_fail
    n_ck += 1
    if not cond:
        n_fail += 1
    out.append(f"check: {name}: {'OK' if cond else 'FAIL'}  {detail}")

def sha256(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest()

def md5s(kit, label):
    t = (ROOT / "scratch" / f"fig_r6_{kit}_{label}.md5").read_text().strip().splitlines()
    return {f: h for h, f in (l.split("  ") for l in t)}

# ── 1. run tables ─────────────────────────────────────────────────────────
for kit in ("sa", "ru", "tl", "et"):
    chk(f"F-REPRO {kit}: run1 == run2", md5s(kit, "1") == md5s(kit, "2"))
chk("F-REPRO hero: run1 == run2 == run3",
    md5s("hero", "1") == md5s("hero", "2") == md5s("hero", "3"))
for kit in ("ru", "tl", "et"):
    chk(f"F-LABEL self-check ok ({kit})",
        "F-LABEL self-check: OK" in (ROOT / "scratch" / f"fig_r6_{kit}_1.log").read_text())

# ── 2. system-anatomy ────────────────────────────────────────────────────
sa = K / "system-anatomy"
led = (sa / "label-ledger.txt").read_text()
chk("sa ledger: R6, the topmost ring", "R6, the topmost ring" in led)
chk("sa ledger: no hub", "hub" not in led.lower().replace("r_hub", ""))
pdftxt = subprocess.run(["pdftotext", str(sa / "system-anatomy.pdf"), "-"],
                        capture_output=True, text=True).stdout
chk("sa pdf text: R6, the topmost ring", "R6, the topmost ring" in pdftxt)
chk("sa pdf text: no hub", not re.search(r"hub", pdftxt, re.I))
cl = (sa / "checks.log").read_text()
chk("sa checks.log: re-cut v6 line", f"re-cut v6: the hub-name retirement (round-6 founder comment 1); the R6 label reads 'R6, the topmost ring' (script commit {SC})" in cl)
chk("sa checks.log: v6 hashes block", "== hashes (re-cut v6) ==" in cl)
chk("sa checks.log: v6 reproducibility line", "re-cut v6: two full runs byte-identical across all five outputs" in cl)
man = json.loads((sa / "manifest.json").read_text())
chk("sa manifest script_commit", man["script_commit"] == SC)
chk("sa manifest outputs recompute", all(
    sha256(sa / f) == h for f, h in man["outputs"].items()))
cap = (sa / "captions.md").read_text()
chk("sa captions provenance token", f"script commit `{SC}`" in cap)
rs = (sa / "register-status.md").read_text()
chk("sa register-status: v6 hashes", "Hashes at v6:" in rs)
chk("sa register-status: v6 delta", "**Delta** v4" in rs)

# ── 3. ring-utilisation ──────────────────────────────────────────────────
ru = K / "ring-utilisation"
led = (ru / "label-ledger.txt").read_text()
chk("ru ledger: R6 (top)", "R6 (top)" in led and "R6 (hub)" not in led)
svg = (ru / "ring-utilisation.svg").read_text()
chk("ru svg: R6 (top), no hub", "R6 (top)" in svg and not re.search(r"hub", svg, re.I))
cap = (ru / "captions.md").read_text()
chk("ru captions: governs full name", "The topmost rotor ring R6 governs the structural check at FoS 15.033." in cap)
chk("ru captions: top row line", "the top row now reads R6" in cap)
chk("ru captions provenance token", f"script commit `{SC}`" in cap)
rs = (ru / "register-status.md").read_text()
chk("ru register-status: command", f"--script-commit {SC}`" in rs)
chk("ru register-status: delta v4", "**Delta** v4 (2026-10-14): the hub-name retirement" in rs)
sp = (ru / "SPEC.md").read_text()
chk("ru SPEC: v8 delta", "- v8 (2026-10-14): the hub-name retirement sweep" in sp)
chk("ru SPEC: no retired forms", not any(s in sp for s in ("hub ring", "hub result", "hub-ring", "ring N hub")))

# ── 4. twist-limit ───────────────────────────────────────────────────────
tl = K / "twist-limit"
led = (tl / "label-ledger.txt").read_text()
chk("tl ledger: R6 (top) + ground to top", "R6 (top)" in led and "ground to top" in led and "ground to hub" not in led)
svg = (tl / "twist-limit.svg").read_text()
chk("tl svg: ground to top, no hub", "ground to top" in svg and not re.search(r"hub", svg, re.I))
rs = (tl / "register-status.md").read_text()
chk("tl register-status: command + delta", f"--script-commit {SC}`" in rs and "**Delta** v4 (2026-10-14): the hub-name retirement" in rs)
sp = (tl / "SPEC.md").read_text()
chk("tl SPEC: v7 delta", "- v7 (2026-10-14): the hub-name retirement sweep" in sp)
chk("tl SPEC: no retired forms", not any(s in sp for s in ("ground → hub", "ring N the hub ring", "ring N hub")))
cap = (tl / "captions.md").read_text()
chk("tl captions provenance token", f"script commit `{SC}`" in cap)

# ── 5. eval-timeline ─────────────────────────────────────────────────────
et = K / "eval-timeline"
led = (et / "label-ledger.txt").read_text()
chk("et ledger: ω top + gates + NR-042", "\u03c9 top (dashed)" in led and "top \u00b7 tip \u00b7 Betz, read" in led and "NR-042" in led)
svg = (et / "eval-timeline.svg").read_text()
chk("et svg: ω top, no hub", "\u03c9 top" in svg and not re.search(r"hub", svg, re.I))
sp = (et / "SPEC.md").read_text()
chk("et SPEC: v2 delta + top rate", "- v2 (2026-10-14): the hub-name retirement sweep" in sp and "the ground rate and the top rate" in sp)
rs = (et / "register-status.md").read_text()
chk("et register-status: v5 delta + footer join", "**Delta** v5 (2026-10-14): the hub-name retirement" in rs and "takes NR-042 at the round-6 build" in rs)
man = json.loads((et / "manifest.json").read_text())
chk("et manifest: NR-042 in register_rows", "NR-042" in man["inputs"]["register_rows"] if "register_rows" in man.get("inputs", {}) else "NR-042" in json.dumps(man))

# ── 6. machine-winner-hero ───────────────────────────────────────────────
hero = K / "machine-winner-hero"
jl = (hero / "machine-winner-hero.jl").read_text()
chk("hero .jl: topmost ring R6 drawn string", 'text="topmost ring R6"' in jl and 'text="hub ring R6"' not in jl)
cl = (hero / "checks.log").read_text()
chk("hero checks.log: topmost-ring altitude", "drawn topmost-ring altitude" in cl and "drawn hub altitude" not in cl)
man = json.loads((hero / "manifest.json").read_text())
chk("hero manifest script_commit", man["script_commit"] == SC)
chk("hero manifest outputs recompute", all(
    sha256(hero / f) == h for f, h in man["outputs"].items()))
rs = (hero / "register-status.md").read_text()
chk("hero register-status: header + command + re-cut",
    f"**Script commit** `{SC}`" in rs and f"--script-commit {SC}`" in rs and "**Re-cut** v2 (2026-10-14): the hub-name retirement" in rs)
chk("hero register-status: topmost ring radii row", "topmost ring and ground radii" in rs)

# generator drawn-string constants (comments hold as code; the label constants flip)
chk("sa py: retired label string absent",
    '"R6, the hub ring"' not in (sa / "system-anatomy.py").read_text())
chk("ru py: retired label string absent",
    '"R6 (hub)"' not in (ru / "ring-utilisation.py").read_text())
tlpy = (tl / "twist-limit.py").read_text()
chk("tl py: retired strings absent", '"R6 (hub)"' not in tlpy and '"ground to hub"' not in tlpy)
etpy = (et / "eval-timeline.py").read_text()
chk("et py: retired strings absent", "\\u03c9 hub" not in etpy and "hub \\u00b7 tip" not in etpy)

# ── 7. strip ─────────────────────────────────────────────────────────────
strip = K / "machine-evolution-strip"
cap = (strip / "captions.md").read_text()
chk("strip captions: topmost ring radius", "topmost ring radius 4.580 m" in cap and "hub radius 4.580 m" not in cap)
rs = (strip / "register-status.md").read_text()
chk("strip register-status: delta", "**Delta** (2026-10-14): the hub-name retirement" in rs)

# ── 8. draft / tracker / map ─────────────────────────────────────────────
draft = (ROOT / "docs/reporting/drafts/2026-10-08-report-first-draft.md").read_text()
chk("draft title v0.46", "Internal engineering report. Draft v0.46. Date 2026-10-14." in draft)
chk("draft: four script cells at A", draft.count(f"`{SC}`") == 4, f"got {draft.count(f'`{SC}`')}")
hexes = {
    "ru.svg": sha256(ru / "ring-utilisation.svg"), "ru.pdf": sha256(ru / "ring-utilisation.pdf"),
    "ru.png": sha256(ru / "ring-utilisation.png"), "ru.ledger": sha256(ru / "label-ledger.txt"),
    "tl.svg": sha256(tl / "twist-limit.svg"), "tl.pdf": sha256(tl / "twist-limit.pdf"),
    "tl.png": sha256(tl / "twist-limit.png"), "tl.ledger": sha256(tl / "label-ledger.txt"),
    "sa.pdf": sha256(sa / "system-anatomy.pdf"), "sa.png": sha256(sa / "system-anatomy.png"),
    "sa.ledger": sha256(sa / "label-ledger.txt"), "sa.checks": sha256(sa / "checks.log"),
    "hero.svg": sha256(hero / "machine-winner-hero.svg"), "hero.pdf": sha256(hero / "machine-winner-hero.pdf"),
    "hero.png": sha256(hero / "machine-winner-hero.png"), "hero.checks": sha256(hero / "checks.log"),
}
missing = [k for k, v in hexes.items() if v not in draft]
chk("draft: all 16 new output hashes present", not missing, str(missing))
chk("draft: count sentence holds", "All seven read dataset commit `dd3cc6a`." in draft)
tracker = (ROOT / "docs/reporting/draft-tracker.md").read_text()
chk("tracker: v0.46 entry", "v0.46 pass by @fig-img-diagrams (2026-10-14)." in tracker)
mp = (ROOT / "docs/reporting/figures/figure-map.md").read_text()
chk("map: v37 delta", "- **v37 (2026-10-14):** the round-6 hub-name retirement sweep lands" in mp)
chk("map: row 2 round-6 next gate", "Next: the aero counter-read of the round-6 re-cut" in mp)
chk("map: row 23 opens family build", "The family-mode build opens at this seat" in mp)

# ── 9. residual retired-form census across the kit trees ─────────────────
FORBIDDEN = ["hub ring", "R6 (hub)", "ground to hub", "ω hub", "hub · tip · Betz",
             "hub result", "hub radius", "to the hub", "at the hub", "hub row",
             "hub read", "hub readout", "hub-segment", "hub segment",
             "RN hub", "hub (top)", "hub-ring"]
hits = []
for kit_dir in (sa, ru, tl, et, hero, strip):
    for p in kit_dir.rglob("*"):
        if p.is_file() and p.suffix in (".md", ".txt", ".tex", ".html", ".svg"):
            t = p.read_text(encoding="utf-8", errors="replace")
            for s in FORBIDDEN:
                if s in t:
                    hits.append(f"{p.relative_to(ROOT)}: {s!r}")
chk("no retired forms in kit text surfaces", not hits, "; ".join(hits[:8]))

# ── 10. STE lint on every touched markdown ───────────────────────────────
LINT = [
    "docs/reporting/figures/system-anatomy/captions-draft.md",
    "docs/reporting/figures/system-anatomy/captions.md",
    "docs/reporting/figures/system-anatomy/SPEC.md",
    "docs/reporting/figures/system-anatomy/register-status.md",
    "docs/reporting/figures/ring-utilisation/captions.md",
    "docs/reporting/figures/ring-utilisation/captions-draft.md",
    "docs/reporting/figures/ring-utilisation/SPEC.md",
    "docs/reporting/figures/ring-utilisation/register-status.md",
    "docs/reporting/figures/twist-limit/captions.md",
    "docs/reporting/figures/twist-limit/SPEC.md",
    "docs/reporting/figures/twist-limit/register-status.md",
    "docs/reporting/figures/eval-timeline/SPEC.md",
    "docs/reporting/figures/eval-timeline/register-status.md",
    "docs/reporting/figures/machine-winner-hero/register-status.md",
    "docs/reporting/figures/machine-evolution-strip/captions.md",
    "docs/reporting/figures/machine-evolution-strip/register-status.md",
    "docs/reporting/figures/figure-map.md",
    "docs/reporting/draft-tracker.md",
    "docs/reporting/drafts/2026-10-08-report-first-draft.md",
]
for f in LINT:
    r = subprocess.run(["python3", "ste-lint.py", "--fail-above", "2.0", f],
                       capture_output=True, text=True)
    tail = (r.stdout.strip().splitlines() or ["(no output)"])[-1]
    chk(f"STE {f}", r.returncode == 0, tail[:110])

print("\n".join(out))
print(f"\nCHECKER: {n_ck} checks, {n_fail} fail")
(ROOT / "scratch/fig_r6_check.log").write_text("\n".join(out) +
    f"\n\nCHECKER: {n_ck} checks, {n_fail} fail\n", encoding="utf-8")
sys.exit(1 if n_fail else 0)

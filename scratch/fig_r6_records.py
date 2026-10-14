#!/usr/bin/env python3
"""fig-r6 records pass — draft appendix pins (v0.46), tracker entry, map v37.

Run from the repo root AFTER the pins pass: /usr/bin/python3 scratch/fig_r6_records.py
"""
import hashlib
import json
import sys
from pathlib import Path

ROOT = Path(".")
SC = "1af63fc"
DRAFT = ROOT / "docs/reporting/drafts/2026-10-08-report-first-draft.md"
TRACKER = ROOT / "docs/reporting/draft-tracker.md"
MAP = ROOT / "docs/reporting/figures/figure-map.md"

def sha256(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest()

K = ROOT / "docs/reporting/figures"
new = {
    "ru.svg": sha256(K / "ring-utilisation/ring-utilisation.svg"),
    "ru.pdf": sha256(K / "ring-utilisation/ring-utilisation.pdf"),
    "ru.png": sha256(K / "ring-utilisation/ring-utilisation.png"),
    "ru.ledger": sha256(K / "ring-utilisation/label-ledger.txt"),
    "tl.svg": sha256(K / "twist-limit/twist-limit.svg"),
    "tl.pdf": sha256(K / "twist-limit/twist-limit.pdf"),
    "tl.png": sha256(K / "twist-limit/twist-limit.png"),
    "tl.ledger": sha256(K / "twist-limit/label-ledger.txt"),
    "sa.pdf": sha256(K / "system-anatomy/system-anatomy.pdf"),
    "sa.png": sha256(K / "system-anatomy/system-anatomy.png"),
    "sa.ledger": sha256(K / "system-anatomy/label-ledger.txt"),
    "sa.checks": sha256(K / "system-anatomy/checks.log"),
    "hero.svg": sha256(K / "machine-winner-hero/machine-winner-hero.svg"),
    "hero.pdf": sha256(K / "machine-winner-hero/machine-winner-hero.pdf"),
    "hero.png": sha256(K / "machine-winner-hero/machine-winner-hero.png"),
    "hero.checks": sha256(K / "machine-winner-hero/checks.log"),
}
# cross-assert against the kit manifests where they carry output hashes
m = json.loads((K / "ring-utilisation/manifest.json").read_text())
assert m["outputs"]["ring-utilisation.svg"] == new["ru.svg"]
assert m["outputs"]["label-ledger.txt"] == new["ru.ledger"]
m = json.loads((K / "twist-limit/manifest.json").read_text())
assert m["outputs"]["twist-limit.svg"] == new["tl.svg"]
m = json.loads((K / "system-anatomy/manifest.json").read_text())
assert m["outputs"]["checks.log"] == new["sa.checks"]
assert m["outputs"]["system-anatomy.pdf"] == new["sa.pdf"]
m = json.loads((K / "machine-winner-hero/manifest.json").read_text())
assert m["outputs"]["checks.log"] == new["hero.checks"]
assert m["outputs"]["machine-winner-hero.pdf"] == new["hero.pdf"]
print("delivered hashes cross-check against the kit manifests: OK")

def apply(path, pairs, label):
    t = path.read_text(encoding="utf-8")
    bad = []
    for old, newv in pairs:
        c = t.count(old)
        if c != 1:
            bad.append(f"  count {c}: {old[:90]!r}")
    if bad:
        print(f"FAIL {label}:"); print("\n".join(bad)); sys.exit(1)
    for old, newv in pairs:
        t = t.replace(old, newv, 1)
    path.write_text(t, encoding="utf-8")
    print(f"applied: {label} ({len(pairs)} edits)")

# ── draft ─────────────────────────────────────────────────────────────────
draft_edits = [
    ("Internal engineering report. Draft v0.45. Date 2026-10-14.",
     "Internal engineering report. Draft v0.46. Date 2026-10-14."),
    ("| Ring utilisation plate | `pair-extract-2026-10-08-winner-ops` | NR-021 | `671ab96` | `post-95c385d_wind-authority` |",
     f"| Ring utilisation plate | `pair-extract-2026-10-08-winner-ops` | NR-021 | `{SC}` | `post-95c385d_wind-authority` |"),
    ("| Twist limit plate | `pair-extract-2026-10-08-winner-ops` | NR-022, NR-023 | `671ab96` | `post-95c385d_wind-authority` |",
     f"| Twist limit plate | `pair-extract-2026-10-08-winner-ops` | NR-022, NR-023 | `{SC}` | `post-95c385d_wind-authority` |"),
    ("| System anatomy plate | `scratch/fig1_decode_winner.jl` · `best_vector.csv` | NR-011, NR-017, NR-043 | `d243b37` | `post-95c385d_wind-authority` |",
     f"| System anatomy plate | `scratch/fig1_decode_winner.jl` · `best_vector.csv` | NR-011, NR-017, NR-043 | `{SC}` | `post-95c385d_wind-authority` |"),
    ("| Machine winner hero | `strip-extract-2026-10-09-best-so-far` · `pair-extract-2026-10-08-winner-ops` | NR-011, NR-017, NR-021, NR-022, NR-043 | `c438398` | `post-95c385d_wind-authority` |",
     f"| Machine winner hero | `strip-extract-2026-10-09-best-so-far` · `pair-extract-2026-10-08-winner-ops` | NR-011, NR-017, NR-021, NR-022, NR-043 | `{SC}` | `post-95c385d_wind-authority` |"),
    ("f49aaaa1bda8d1699c6db556fd20188d892cfcd42e3163ab8fb56bbea1eee837", new["ru.png"]),
    ("41a557862e0f3a1eb1b40ecb2224089014fff7c26ee8d7c6d64bdd1b3bf670c0", new["ru.svg"]),
    ("fc4974d6e462b22ca3a45aaae009001bdf46c8d0245862227255ca3e42d69c75", new["ru.pdf"]),
    ("3b4bc8c1c9b0c5d474a1acabe6c2b7684058234414d96870e41b015e04b4a5ff", new["ru.ledger"]),
    ("00cd857a5769be853142a4e35cc701d283cb17e66c2e20f40e562177813f6248", new["tl.png"]),
    ("45104b967009ef52c54f2ca4f4877f30c204daf64544161d907dc5dc41e59f5f", new["tl.svg"]),
    ("49c473a8ff2dac0cc15fed7b17bece2a10ecaae6d4ab157e801754cf6b40dfa2", new["tl.pdf"]),
    ("2225062a0146f62ac1c0a18add36f38d26df73682f56f4fd5cdac6a0a691c8e9", new["tl.ledger"]),
    ("b78eb5cbe8f77074f04f9264e409f3de7f5aa97096a4f4f824c3bdf8271ecc9a", new["sa.png"]),
    ("b8fd60364168d70200f2f7122f7f9a957ea1590aa84c6197a19c79e811c444b6", new["sa.pdf"]),
    ("3adec59c7bd19b232584de4e6cb703b44d4e48bb820c68f1ed78f5086971dc8d", new["sa.ledger"]),
    ("5255033809928282a348d525b6a7553df3ba64b267fcabb1499ecfaa75331810", new["sa.checks"]),
    ("4e8fc9d267a7e776857b8805be34da1189fddd65117fdf7278f36bd2cd4e6af5", new["hero.png"]),
    ("819bafe52679b0fa23ac8c225e3156444b3dcee3ff4fa1ddf4c9065f846c5171", new["hero.svg"]),
    ("a9d5516d7ec7bd71bbcd8edee6f425b619736277c229c5bc9ff4aae3f3e8fb2e", new["hero.pdf"]),
    ("52fe83a8c54ec93f5372b2fb15c8c77af90b44c3f1e6eb5a8732efffebf59924", new["hero.checks"]),
]
apply(DRAFT, draft_edits, "draft (v0.46 pins)")

# ── tracker ───────────────────────────────────────────────────────────────
tracker_edits = [
    ("The two tables add the accepted table class.\nNo value moves.\n\n## 2. Working notes",
     "The two tables add the accepted table class.\nNo value moves.\n"
     "\n"
     "v0.46 pass by @fig-img-diagrams (2026-10-14).\n"
     "This pass re-pins the figure-provenance appendix to the delivered round-6 re-cuts.\n"
     "Four exhibit script-commit cells and sixteen output-hash cells take the delivered values.\n"
     "The five plates and the three caption kits take the top forms (round-6 comment 1).\n"
     "No value moves.\n"
     "\n## 2. Working notes"),
]
apply(TRACKER, tracker_edits, "tracker (v0.46 entry)")

# ── figure map ────────────────────────────────────────────────────────────
map_edits = [
    ("Next: the aero counter-read of the v5 re-cut",
     "The v5 re-cut counter-read re-keys clean (`e4ab49b`). The round-6 hub-name "
     "retirement re-cut lands (script `1af63fc`): the R6 label reads \"R6, the "
     "topmost ring\". Next: the aero counter-read of the round-6 re-cut"),
    ("`6175f83`) | F-VALUE PASS (`20d06bb`). Rod's visual pass, then the fold",
     "`6175f83`) | F-VALUE PASS (`20d06bb`). The round-6 hub-name re-cut lands (script `1af63fc`; "
     "the NR-042 footer join folds here). Next: the aero counter-read of the re-cut, "
     "then Rod's visual pass and the fold"),
    ("the corrected interaction form). The re-census at `c30b2ca` closes F-VALUE on the fix commit (`ef36c6c`) with zero defects. Next: the visual pass by Rod",
     "the corrected interaction form). The re-census at `c30b2ca` closes F-VALUE on the fix commit (`ef36c6c`) with zero defects. The round-6 hub-name re-cut lands (script `1af63fc`): the top row label reads \"R6 (top)\" and the caption text takes the top forms. Next: the aero counter-read of the re-cut; the visual pass by Rod follows"),
    ("the binding-limit title). The re-census at `c30b2ca` closes F-VALUE on the fix commit (`ef36c6c`) with zero defects. Next: the visual pass by Rod",
     "the binding-limit title). The re-census at `c30b2ca` closes F-VALUE on the fix commit (`ef36c6c`) with zero defects. The round-6 hub-name re-cut lands (script `1af63fc`): the top row label reads \"R6 (top)\" and the subtitle reads \"ground to top\". Next: the aero counter-read of the re-cut; the visual pass by Rod follows"),
    ("F-COUNT and F-PARSE on the re-rendered SVG (`74cfef9`). Then sign-off",
     "F-COUNT and F-PARSE on the re-rendered SVG (`74cfef9`). The round-6 hub-name "
     "retirement lands in the caption text (\"topmost ring radius\"; no render move). "
     "Then sign-off"),
    ("The v0.41 counter-read closes clean (`0cbb9b8`, 226 checks). Next: the visual pass by Rod",
     "The v0.41 counter-read closes clean (`0cbb9b8`, 226 checks). The round-6 "
     "hub-name re-cut lands (script `1af63fc`): the leader reads \"topmost ring "
     "R6\". Next: the aero counter-read of the re-cut; the visual pass by Rod follows"),
    ("The objective rows (science-validator), then the family-mode build",
     "The objective row (NR-051) is signed (science-validator, `8855d9a`). The "
     "family-mode build opens at this seat"),
    ("The plate\n  values route to the science-validator first, then the family-mode\n  build.",
     "The plate\n  values route to the science-validator first, then the family-mode\n  build.\n"
     "\n"
     "- **v37 (2026-10-14):** the round-6 hub-name retirement sweep lands\n"
     "  (routing comment 1, id 0; the forms signed at `cb862df`). The five\n"
     "  plates re-cut the drawn text: the anatomy label reads \"R6, the\n"
     "  topmost ring\"; both chart plates read \"R6 (top)\"; the twist\n"
     "  subtitle reads \"ground to top\"; the timeline reads \"\u03c9 top\" and\n"
     "  \"top · tip · Betz\"; the hero leader reads \"topmost ring R6\". The\n"
     "  three caption kits take the forms, and the eval-timeline footer\n"
     "  folds NR-042 (its recorded next-build item). Script `1af63fc`; the\n"
     "  outputs and records ride this commit. Two full runs stay\n"
     "  byte-identical per kit, and three for the hero. Next: the aero\n"
     "  counter-read of the round-6 re-cuts; the corner build opens at this\n"
     "  seat on the NR-051 sign."),
]
apply(MAP, map_edits, "figure map (rows + v37)")
print("records pass complete.")

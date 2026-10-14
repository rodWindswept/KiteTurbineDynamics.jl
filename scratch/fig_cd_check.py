#!/usr/bin/env python3
"""Round-5 caption dedupe: check script (figures seat, 2026-10-14).

Asserts, on the worktree bytes:
  1. Each kit's new plain tier parses through the draft builder's own
     caption parser (imported read-only) and both tiers stay non-empty.
  2. The new plain sentence is present; the retired claim is absent.
  3. SPEC caption plans and register-note deltas carry the new text.
  4. The map carries delta v34 and keeps v33.
Also stages .md-named base copies for the STE lint delta.
"""
import shutil
import sys
from pathlib import Path

REPO = Path("/home/rod/Documents/GitHub/KiteTurbineDynamics.jl")
FIGS = REPO / "docs/reporting/figures"
BASE = Path.home() / ".hermes/profiles/figures-images-diagrams/cache/scratch/fig_cd_base"
LOG = Path(__file__).with_suffix(".log")

sys.path.insert(0, str(REPO / "scripts"))
import build_draft_pdf as B  # noqa: E402  (read-only import; main() is guarded)

checks = []
def chk(name, cond, detail=""):
    checks.append((name, bool(cond), detail))

# ---- parser dry-run + text assertions per kit ----
KITS = {
    "ring-utilisation": {
        "new_plain": "Every airborne ring passes its structural check with a wide margin.",
        "old_plain": "The hub ring R6 governs the structural check at the winner's final operating point, and every other airborne ring holds a much larger margin.",
        "tech_lead": "The hub ring R6 governs the structural check at FoS 15.033.",
    },
    "twist-limit": {
        "new_plain": "The shaft passes its twist and torque checks along its whole length.",
        "old_plain": "All five segments stay inside their over-twist limits at the winner's final operating point, and the smallest torque margin sits at S1.",
        "tech_lead": "All five TRPT segments remain inside their over-twist limits",
    },
    "machine-evolution-strip": {
        "new_plain": "The search improves the machine at every recorded step, from the common seed to the campaign winner.",
        "old_plain": "Island 3's best-so-far objective falls as the built geometry converges to the register winner.",
        "tech_lead": "Island 3's best-so-far objective falls from 36.109 to 27.364",
    },
}
for slug, kit in KITS.items():
    p = FIGS / slug / "captions.md"
    plain, tech = B.parse_caption_sections(str(p))
    chk(f"{slug}: plain tier non-empty", len(plain) > 20, f"len={len(plain)}")
    chk(f"{slug}: tech tier non-empty", len(tech) > 40, f"len={len(tech)}")
    chk(f"{slug}: new plain present", kit["new_plain"] in plain)
    chk(f"{slug}: old plain absent", kit["old_plain"] not in plain)
    chk(f"{slug}: old claim absent from plain tier", "much larger margin" not in plain)
    chk(f"{slug}: tech lead intact", kit["tech_lead"] in tech)
    chk(f"{slug}: provenance section does not parse as a tier", "Data commit" not in plain and "Data commit" not in tech)

# ---- SPECs ----
sp = (FIGS / "ring-utilisation/SPEC.md").read_text()
chk("ring SPEC: new plan present", "The tier reads one takeaway: every\nairborne ring passes its structural check with a wide margin." in sp)
chk("ring SPEC: old plan absent", "The hub ring R6 governs, and every\nother airborne ring holds a much larger margin." not in sp)
chk("ring SPEC: delta v7 present", "- v7 (2026-10-14): the plain tier reads one takeaway sentence" in sp)
sp = (FIGS / "twist-limit/SPEC.md").read_text()
chk("twist SPEC: new plan present", "The tier reads one takeaway: the shaft\npasses its twist and torque checks along its whole length." in sp)
chk("twist SPEC: old plan absent", "All five segments stay inside their\nover-twist limits at the winner's final operating point." not in sp)
chk("twist SPEC: delta v6 present", "- v6 (2026-10-14): the plain tier reads one takeaway sentence" in sp)

# ---- register notes ----
for slug in ("ring-utilisation", "twist-limit"):
    t = (FIGS / slug / "register-status.md").read_text()
    chk(f"{slug} note: delta v3 present", "**Delta** v3 (2026-10-14): the round-5 caption dedupe." in t)

# ---- map ----
m = (FIGS / "figure-map.md").read_text()
chk("map: v34 present", "- **v34 (2026-10-14):** the round-5 caption dedupe lands" in m)
chk("map: v33 intact", "- **v33 (2026-10-14):** the hero counter-read closes clean" in m)

# ---- kit notes present ----
for slug in KITS:
    t = (FIGS / slug / "captions.md").read_text()
    chk(f"{slug}: takeaway note present", "Takeaway (2026-10-14): the plain tier reads one takeaway sentence" in t)
    chk(f"{slug}: old plain fully retired from file", KITS[slug]["old_plain"].replace(" ", " ") not in t)

# ---- stage base copies with .md names for the lint delta ----
stage = BASE / "lint_base"
stage.mkdir(parents=True, exist_ok=True)
pairs = [
    ("figure-map.md", "figure-map.md__figures.base", "figure-map.md"),
    ("ring-utilisation", "captions.md__ring-utilisation.base", "captions.md"),
    ("ring-utilisation", "SPEC.md__ring-utilisation.base", "SPEC.md"),
    ("ring-utilisation", "register-status.md__ring-utilisation.base", "register-status.md"),
    ("twist-limit", "captions.md__twist-limit.base", "captions.md"),
    ("twist-limit", "SPEC.md__twist-limit.base", "SPEC.md"),
    ("twist-limit", "register-status.md__twist-limit.base", "register-status.md"),
    ("machine-evolution-strip", "captions.md__machine-evolution-strip.base", "captions.md"),
]
for parent, src, dst in pairs:
    s = BASE / src
    if s.exists():
        shutil.copy(s, stage / f"{parent}--{dst}")

npass = sum(1 for _, ok, _ in checks if ok)
lines = [f"fig_cd_check: {npass} pass, {len(checks)-npass} fail", ""]
for name, ok, detail in checks:
    lines.append(f"{'PASS' if ok else 'FAIL'}  {name}" + (f"   [{detail}]" if detail else ""))
out = "\n".join(lines) + "\n"
print(out)
LOG.write_text(out)
raise SystemExit(0 if npass == len(checks) else 1)

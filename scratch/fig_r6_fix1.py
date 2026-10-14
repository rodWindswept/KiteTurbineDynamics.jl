#!/usr/bin/env python3
"""fig-r6 fix pass 1 — STE cleanup on the map additions, the RU prototype
mock flip, and the semicolons in my own caption notes.

Run from the repo root: /usr/bin/python3 scratch/fig_r6_fix1.py
"""
import sys
from pathlib import Path

ROOT = Path(".")

def apply(path, pairs, label):
    p = ROOT / path
    t = p.read_text(encoding="utf-8")
    bad = [f"  count {t.count(old)}: {old[:90]!r}" for old, _ in pairs if t.count(old) != 1]
    if bad:
        print(f"FAIL {label}:"); print("\n".join(bad)); sys.exit(1)
    for old, new in pairs:
        t = t.replace(old, new, 1)
    p.write_text(t, encoding="utf-8")
    print(f"applied: {label}")

apply("docs/reporting/figures/figure-map.md", [
    ("The round-6 hub-name retirement re-cut lands (script `1af63fc`): the R6 label reads \"R6, the "
     "topmost ring\". Next: the aero counter-read of the round-6 re-cut",
     "The round-6 hub-name retirement re-cut lands (script `1af63fc`). The R6 label reads "
     "\"R6, the topmost ring\". Next: the aero counter-read of the round-6 re-cut"),
    ("The round-6 hub-name re-cut lands (script `1af63fc`; the NR-042 footer join folds here). "
     "Next: the aero counter-read of the re-cut, then Rod's visual pass and the fold",
     "The round-6 hub-name re-cut lands (script `1af63fc`). The NR-042 footer join folds here. "
     "Next: the aero counter-read of the re-cut, then Rod's visual pass and the fold"),
    ("The round-6 hub-name re-cut lands (script `1af63fc`): the top row label reads \"R6 (top)\" and the caption text takes the top forms. Next: the aero counter-read of the re-cut; the visual pass by Rod follows",
     "The round-6 hub-name re-cut lands (script `1af63fc`). The top row label reads \"R6 (top)\". The caption text takes the top forms. Next: the aero counter-read of the re-cut. The visual pass by Rod follows"),
    ("The round-6 hub-name re-cut lands (script `1af63fc`): the top row label reads \"R6 (top)\" and the subtitle reads \"ground to top\". Next: the aero counter-read of the re-cut; the visual pass by Rod follows",
     "The round-6 hub-name re-cut lands (script `1af63fc`). The top row label reads \"R6 (top)\". The subtitle reads \"ground to top\". Next: the aero counter-read of the re-cut. The visual pass by Rod follows"),
    ("The round-6 hub-name retirement lands in the caption text (\"topmost ring radius\"; no render move). Then sign-off",
     "The round-6 hub-name retirement lands in the caption text (\"topmost ring radius\", no render move). Then sign-off"),
    ("The round-6 hub-name re-cut lands (script `1af63fc`): the leader reads \"topmost ring R6\". Next: the aero counter-read of the re-cut; the visual pass by Rod follows",
     "The round-6 hub-name re-cut lands (script `1af63fc`). The leader reads \"topmost ring R6\". Next: the aero counter-read of the re-cut. The visual pass by Rod follows"),
    ("- **v37 (2026-10-14):** the round-6 hub-name retirement sweep lands\n  (routing comment 1, id 0; the forms signed at `cb862df`). The five\n  plates re-cut the drawn text: the anatomy label reads \"R6, the\n  topmost ring\"; both chart plates read \"R6 (top)\"; the twist\n  subtitle reads \"ground to top\"; the timeline reads \"\u03c9 top\" and\n  \"top · tip · Betz\"; the hero leader reads \"topmost ring R6\". The\n  three caption kits take the forms, and the eval-timeline footer\n  folds NR-042 (its recorded next-build item). Script `1af63fc`; the\n  outputs and records ride this commit. Two full runs stay\n  byte-identical per kit, and three for the hero. Next: the aero\n  counter-read of the round-6 re-cuts; the corner build opens at this\n  seat on the NR-051 sign.",
     "- **v37 (2026-10-14):** the round-6 hub-name retirement sweep lands\n  (routing comment 1, id 0). The forms signed at `cb862df`. The five\n  plates re-cut the drawn text. The anatomy label reads \"R6, the\n  topmost ring\". Both chart plates read \"R6 (top)\". The twist\n  subtitle reads \"ground to top\". The timeline reads \"\u03c9 top\" and\n  \"top · tip · Betz\". The hero leader reads \"topmost ring R6\". The\n  three caption kits take the forms, and the eval-timeline footer\n  folds NR-042, its recorded next-build item. Script `1af63fc`. The\n  outputs and records ride this commit. Two full runs stay\n  byte-identical per kit, and three for the hero. Next: the aero\n  counter-read of the round-6 re-cuts. The corner build opens at this\n  seat on the NR-051 sign."),
], "map rewrites (STE)")

apply("docs/reporting/figures/ring-utilisation/prototype.html", [
    ("to the hub (top); stacked", "to the top; stacked"),
    ("R1 ground … RN hub)", "R1 ground … RN top)"),
    ("ground ring R1 excluded, hub ring included", "ground ring R1 excluded, topmost ring included"),
    ("ground-ring exclusion; hub-ring inclusion; capture cited.",
     "ground-ring exclusion; topmost-ring inclusion; capture cited."),
], "RU prototype flip")

apply("docs/reporting/figures/system-anatomy/captions.md", [
    ("The plate re-renders; the provenance token takes the round-6\nscript commit.",
     "The plate re-renders. The provenance token takes the round-6\nscript commit."),
], "sa captions semicolon")

apply("docs/reporting/figures/ring-utilisation/captions.md", [
    ("Text only, no render value moves; the plate re-renders at the round-6\nscript commit.",
     "Text only. No render value moves. The plate re-renders at the round-6\nscript commit."),
], "ru captions semicolon")

apply("docs/reporting/figures/twist-limit/captions.md", [
    ("Text only, no value moves; the plate\nre-renders at the round-6 script commit.",
     "Text only. No value moves. The plate\nre-renders at the round-6 script commit."),
], "tl captions semicolon")

print("fix pass 1 complete.")

#!/usr/bin/env python3
"""fig_et_pl_edit: the placement-label re-cut edit for the eval-timeline kit.

The rope-break gate placement fix landed in the code (2bf76a3,
2026-09-16 ruling). The lane-3 label "not yet in the code" now
overstates (aero-validator, 2026-10-15). This edit (one file, the
generator):

  1. the lane-3 label takes the landed form:
     "rope-break gate off during relax".
  2. the held head comment sweeps to the top form (the round-6
     comment hold closes): "ground ring and top ring".
  3. the docstring changelog gains a v3 line.

Every anchor is count-asserted (1 match each). The script aborts
before writing if any anchor drifts.
"""
import argparse
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT_DEFAULT = HERE.parent  # the repo root


def replace_once(text: str, old: str, new: str, label: str) -> str:
    n = text.count(old)
    assert n == 1, f"{label}: expected 1 match, found {n}"
    return text.replace(old, new)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default=str(ROOT_DEFAULT))
    args = ap.parse_args()
    root = Path(args.root)
    gen = root / "docs" / "reporting" / "figures" / "eval-timeline" / "eval-timeline.py"
    t = gen.read_text(encoding="utf-8")
    before = len(t)

    # 1. the lane-3 label: the caveat drops (the placement landed at 2bf76a3).
    t = replace_once(
        t,
        'keep("rope-break gate off during relax (not yet in the code)")',
        'keep("rope-break gate off during relax")',
        "lane-3 label",
    )

    # 2. the head comment: the held ring name sweeps to the top form.
    t = replace_once(
        t,
        "lane 1  angular rate, ground ring and hub ring (cold extract)",
        "lane 1  angular rate, ground ring and top ring (cold extract)",
        "head comment",
    )

    # 3. the docstring changelog: a v3 line between the v2 block and Run.
    t = replace_once(
        t,
        "No\ndrawn value moves.\n\nRun:",
        "No\ndrawn value moves.\n\n"
        "v3 (the placement landed, 2026-10-15): the lane-3 label takes the\n"
        'landed form "rope-break gate off during relax". The head comment sweeps\n'
        "to the top form. No drawn value moves.\n\n"
        "Run:",
        "docstring v3 changelog",
    )

    gen.write_text(t, encoding="utf-8")
    print(f"edited: {gen}")
    print(f"bytes: {before} -> {len(t)}")
    print("anchors: 3, all closed (1 match each)")
    return 0


if __name__ == "__main__":
    sys.exit(main())

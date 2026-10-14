#!/usr/bin/env python3
"""The levers caption seating headers: apply the refine (figures seat).

Both levers caption files serve the builder now (`captions.md`, promoted at
`5a7a6b4`, bytes unchanged). This pass seats their heads: the draft head
leaves, the seated head lands. The caption text and the provenance lines
stand. A delta line records the pass.

Run from the repo root:
  /usr/bin/python3 scratch/fig_sh_edit.py
"""
import hashlib
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

OLD_HEAD = (
    "# Captions draft: {name}\n"
    "\n"
    "**Slug** `{slug}`. **Status** DRAFT. Review input for the author\n"
    "seat, @author. Ledger strings only. The caption plan of `SPEC.md` is\n"
    "the contract. The provenance line resolves to the figure-provenance\n"
    "appendix.\n"
)

NEW_HEAD = (
    "# Captions: {name}\n"
    "\n"
    "**Slug** `{slug}`. **Status** GENERATE. **Date** 2026-10-13.\n"
    "**Cite fix and re-cut** 2026-10-14.\n"
    "\n"
    "Site: the report at §3.4, beside the levers reading. Reading order: the\n"
    "landscape, then the atlas. The wording comes from the figures seat,\n"
    "STE-gate checked. Values cite {cite}.\n"
    "\n"
    "The provenance line resolves to the figure-provenance appendix (draft\n"
    "v0.15).\n"
    "\n"
    "The split: the plain and technical captions carry the scientific text\n"
    "only. The provenance line carries the audit tokens: data commit, run,\n"
    "rows and script commit. The report prints the scientific captions. The\n"
    "plate stamp and the appendix carry the provenance.\n"
)

DELTA_OLD = "**Delta** v3 (2026-10-14): the cites take the register mapping."
DELTA_NEW = (
    "**Delta** v4 (2026-10-14): the seating header refines. The caption text stands.\n"
    "\n" + DELTA_OLD
)

EDITS = [
    {
        "path": "docs/reporting/figures/pca-landscape/captions.md",
        "name": "the levers landscape",
        "slug": "pca-landscape",
        "cite": "NR-001, NR-005, NR-006, NR-044 and NR-045",
    },
    {
        "path": "docs/reporting/figures/pca-atlas/captions.md",
        "name": "the parameter atlas",
        "slug": "pca-atlas",
        "cite": "NR-001, NR-005, NR-006 and NR-044",
    },
]


def md5b(t):
    return hashlib.md5(t.encode()).hexdigest()


def main():
    for e in EDITS:
        p = ROOT / e["path"]
        t = p.read_text()
        old = OLD_HEAD.format(name=e["name"], slug=e["slug"])
        new = NEW_HEAD.format(name=e["name"], slug=e["slug"], cite=e["cite"])
        n1 = t.count(old)
        n2 = t.count(DELTA_OLD)
        if n1 != 1 or n2 != 1:
            print(f"ABORT {e['path']}: head count {n1}, delta count {n2}")
            return 1
        t2 = t.replace(old, new).replace(DELTA_OLD, DELTA_NEW, 1)
        p.write_text(t2)
        print(f"edited {e['path']}")
        print(f"  md5 before {md5b(t)}")
        print(f"  md5 after  {md5b(t2)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

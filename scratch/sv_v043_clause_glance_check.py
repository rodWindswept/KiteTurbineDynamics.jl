#!/usr/bin/env python3
# scratch/sv_v043_clause_glance_check.py — science-validator, 2026-10-14.
# The v0.43 clause glance: the NR-049 and NR-050 folds at the signed forms.
# Read-only. Run: python3 scratch/sv_v043_clause_glance_check.py | tee scratch/sv_v043_clause_glance_check.log
import os
import sys

REPO = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
ok = 0
fail = 0


def check(name, cond, detail=""):
    global ok, fail
    if cond:
        ok += 1
        print(f"PASS  {name}")
    else:
        fail += 1
        print(f"FAIL  {name}  {detail}")


def read(rel):
    with open(os.path.join(REPO, rel)) as f:
        return f.read()


draft = read("docs/reporting/drafts/2026-10-08-report-first-draft.md")

check("A1  blade base factors at the signed form",
      "The base span reads 0.75 of the rotor radius, and the base chord reads 0.113 of it." in draft)
check("A2  base calculation named (NR-050)",
      "The power sizing sets the radius for the rotor at its local wind speed (NR-050)." in draft)
check("B1  cone fold at 2.1 at the signed form",
      "The shaft transition cone holds one fixed angle, 22 degrees, by construction." in draft
      and "It is not a search gene (NR-049)." in draft)
check("B2  every-machine fold at 3.5",
      "in every machine of the campaign (NR-049)." in draft)
check("B3  campaign lead",
      "A later campaign can vary it." in draft)

check("C1  three 22-degree sites", draft.count("22 degrees") == 3,
      f"count={draft.count('22 degrees')}")
check("C2  cone sites named", draft.count("shaft transition cone") >= 2,
      f"count={draft.count('shaft transition cone')}")
check("C3  bank site named", "The second bank slot holds `bank_bottom`." in draft)

inds22 = [i for i in range(len(draft)) if draft.startswith("22 degrees", i)]
indst = [i for i in range(len(draft)) if draft.startswith("Tulloch", i)]
away = all(abs(a - b) > 300 for a in inds22 for b in indst)
check("C4  Tulloch guard", away and draft.count("Jensen") == 0
      and "Tulloch/Jensen" not in draft,
      f"Tulloch={len(indst)} Jensen={draft.count('Jensen')}")

check("C5  citations read", "(NR-049)" in draft and "(NR-050)" in draft)
check("C6  bank bound cite", "hi[i] = 22.0" in read("scripts/compute_seeds.jl")
      and "# bank angles: 0° minimum, 22° maximum" in read("scripts/compute_seeds.jl"))
check("C7  NR-049 cited at both folds", draft.count("(NR-049)") >= 2,
      f"count={draft.count('(NR-049)')}")

print(f"\nSV_V043_CLAUSE_GLANCE: {ok + fail} checks, {fail} fail")
sys.exit(1 if fail else 0)

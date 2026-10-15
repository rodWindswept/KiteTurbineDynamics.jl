#!/usr/bin/env python3
# scratch/sw_r6leg_pins.py — science-writer, 2026-10-15. Receipt-grade pins
# for the round-6 legs: every landed string present, every retired form gone
# at the exact site, and the surface counts the room enumerated.
import re

n_ck = 0
n_fail = 0

def chk(name, cond, detail=""):
    global n_ck, n_fail
    n_ck += 1
    if not cond:
        n_fail += 1
    print(f"check: {name}: {'OK' if cond else 'FAIL'}  {detail}")

def rd(p):
    return open(p, encoding="utf-8").read()

HUB = re.compile(r"\bhub\b", re.I)

TRACKER = "docs/reporting/draft-tracker.md"
CAND = "docs/reporting/glossary-candidates.md"
SP = "docs/agents/stale-phrases.md"

t = rd(TRACKER); c = rd(CAND); s = rd(SP)

# Tracker — the short name at both sites.
chk("tracker: capture ring reads the short name",
    "the capture topmost ring reads 15.033 at the final step (NR-021)." in t)
chk("tracker: the v0.30 note reads the short name",
    "the capture topmost ring reading keeps its form." in t)
chk("tracker: old form zero", "hub" not in t.lower(), f"raw={t.lower().count('hub')}")

# Candidates — guard, retire list, pair row, version, delta.
chk("candidates: guard extended", 'Never write "hub rotor" or "hub ring".' in c)
chk("candidates: rotor guard substring holds", 'Never write "hub rotor"' in c)
chk("candidates: retire list extended",
    '| "hub rotor", or "hub" for a rotor or the ring | main rotor, topmost ring | stale-phrases, physics-topology 4 |' in c)
chk("candidates: retire pin substring holds", '"hub rotor", or "hub" for a rotor' in c)
chk("candidates: pair re-key row present",
    '| topmost ring | The ring at the top of the TRPT. It carries the main rotor. '
    'The full name is "topmost rotor ring". The name "hub ring" retires (Rod, 2026-10-14). '
    '| physics-topology 4, CONTEXT.md | ratify |' in c)
chk("candidates: pair sits beside ground ring",
    c.index("| ground ring |") < c.index("| topmost ring |") < c.index("| annulus"))
chk("candidates: status v16", "**Status** PREP v16, numbers-free by construction" in c)
chk("candidates: v16 delta lands",
    "- **v16 (2026-10-15):** the hub-name retirement re-keys the ring pair." in c)
chk("candidates: old guard form gone", 'Never write "hub rotor".' not in c)

# Stale-phrases — the two re-formed claims, the extended replacement, the note.
chk("sp: claim 1 re-formed", "## The topmost ring hosts ONLY the cp/ct rotor" in s)
chk("sp: claim 2 re-formed", "## expansion_params_from_rotors excludes the decoder's topmost rotor" in s)
chk("sp: old claim headings gone",
    "## The hub ring hosts" not in s and "decoder's hub rotor" not in s)
chk("sp: replacement extended",
    'Replacement: main rotor (the topmost rotor). "Hub" is not a rotor term, and it does not name the ring — see docs/agents/physics-topology.md §4' in s)
chk("sp: ring note present",
    'Note (2026-10-14): the part reads "topmost ring", or "topmost rotor ring" in full (Rod, 2026-10-14).' in s)
chk("sp: hub-rotor entry heading holds (the rotor ban)", "## hub rotor" in s)

# Surface counts (the room's enumeration).
chk("counts: tracker hub lines = 0", len([1 for l in t.splitlines() if HUB.search(l)]) == 0)
chk("counts: stale-phrases hub lines = 2 (the ban entry)",
    len([1 for l in s.splitlines() if HUB.search(l)]) == 2)
n_cl = len([1 for l in c.splitlines() if HUB.search(l)])
chk("counts: candidates hub lines = 4 record lines", n_cl == 4, f"got {n_cl}")

print(f"\n{n_ck} checks, {n_fail} fail")
raise SystemExit(1 if n_fail else 0)

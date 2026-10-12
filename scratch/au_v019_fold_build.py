"""v0.19 fold builder and receipt - author pass 2026-10-12.

Builds the v0.19 texts from the v0.18 tip, checks them, and writes the
sim files. Modes:

  default   build + check + write the sim files
  --apply   the above, then write the worktree files
  --check   rebuild and assert the worktree equals the built texts

Edits, draft:
  E1  header pin, v0.18 -> v0.19
  E2  abstract gains the NR-040 torque-margin sentence as its own block
  E3  section 4.3 gains the two science-writer pins, verbatim
  E4  section 5 body replaced by the review-shape rewrite

Edits, tracker:
  E5  version history gains the v0.19 pass entry

Expected token diff (pattern (?<![\\w-])\\d+(?:\\.\\d+)?(?![\\w-])):
  draft:   removed {"18": 1}; added {"19": 1, "2.03": 2}
  tracker: removed {}; added {"19": 1, "4.3": 1, "2.03": 1}

Expected STE: draft total 4 (passive_voice 1, long_paragraph 3);
tracker total 5. Both hold their offender sets entry for entry, and
both keep em_dash 0.
"""
import collections
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
DRAFT = "docs/reporting/drafts/2026-10-08-report-first-draft.md"
TRACKER = "docs/reporting/draft-tracker.md"
PROBE = (
    "/home/rod/.hermes/profiles/author/skills/windswept/ktd-ste-gate/"
    "scripts/ste_lint_probe.py"
)
PAT = re.compile(r"(?<![\w-])\d+(?:\.\d+)?(?![\w-])")

PIN1 = [
    "- The model does not simulate launch or recovery.",
    "  Each run starts with the machine already aloft at its operating point.",
    "  The full launch sequence and the recovery are outside this report.",
    "",
    "  The lift system must also carry the machine during hoisting, after a TRPT break and in high wind.",
    "  The record does not quantify those cases.",
]
PIN2 = [
    "- The campaign wind is steady and sheared.",
    "  Its speed rises with altitude on the site wind profile.",
    "  The profile comes from wind measured at the Daisy machine.",
    "  Gusts and turbulence do not occur in a scored run.",
    "  The wind direction stays fixed.",
]
NEW5 = [
    "The work runs a differential-evolution search over the design space of a rigid-wing ground-generation rotary kite turbine.",
    "The machine uses a tensile rotary power transmission.",
    "The campaign scores each design on the ODE path.",
    "The honest window stands behind every number.",
    "",
    "The campaign found the best feasible candidate in 930 evaluations (NR-001).",
    "The winner survives the full window.",
    "Its power reads 5.309 kilowatts and its factor of safety 14.972 (NR-008, NR-009).",
    "At the winner operating point, the least segment torque margin is 2.03, at S1 (NR-040).",
    "",
    "The result shows that a compact TRPT machine can satisfy the power, clearance, twist and structural gates in simulation.",
    "The large structural margins suggest room for further mass reduction.",
    "",
    "The Daisy anchor ties the model to a measured flight reference.",
    "",
    "The conclusion is conditional on the model.",
    "Blade integrity is not yet gated.",
    "Lifter modulation remains an assumption.",
    "The rapid path awaits its rope-break gate fix (NR-013).",
    "",
    "The next steps add blade structural checks, validate lifter modulation and complete the levers and implications sections.",
    "The boundaries in the discussion name the work that comes next.",
    "[Daisy values need register rows before the final report quotes",
    "them.]",
]
TRACKER_ENTRY = [
    "v0.19 pass by @author (2026-10-12).",
    "This pass folds the two model-boundaries pins at section 4.3.",
    "The launch-and-recovery scope bullet and the wind-model bullet land verbatim from the science-writer block (9ff1544).",
    "The conclusion rewrites to the review shape.",
    "The abstract and the conclusion quote the least segment torque margin 2.03, at S1 (NR-040).",
]

EXPECT_DRAFT_REMOVED = {"18": 1}
EXPECT_DRAFT_ADDED = {"19": 1, "2.03": 2}
EXPECT_TRACKER_REMOVED = {}
EXPECT_TRACKER_ADDED = {"19": 1, "4.3": 1, "2.03": 1}


def head_text(path):
    return subprocess.run(
        ["git", "show", f"HEAD:{path}"], capture_output=True, text=True, check=True, cwd=ROOT
    ).stdout


def worktree_text(path):
    return (ROOT / path).read_text(encoding="utf-8")


def tokens(text):
    return collections.Counter(PAT.findall(text))


def find_line(lines, pred, start=0):
    for i in range(start, len(lines)):
        if pred(lines[i]):
            return i
    return None


def build_draft(old):
    s = old
    a = "Internal engineering report. Draft v0.18. Date 2026-10-12."
    b = "Internal engineering report. Draft v0.19. Date 2026-10-12."
    assert s.count(a) == 1, "E1 anchor"
    s = s.replace(a, b)

    a = "operating point (NR-021, NR-022). All numbers"
    b = (
        "operating point (NR-021, NR-022).\n\n"
        "At the winner operating point, the least segment torque margin is\n"
        "2.03, at S1 (NR-040).\n\n"
        "All numbers"
    )
    assert s.count(a) == 1, "E2 anchor"
    s = s.replace(a, b)

    lines = s.split("\n")
    i = find_line(lines, lambda l: l.startswith("- Flown blades carry tether-to-blade bridling"))
    assert i is not None, "E3 bridling bullet"
    nxt = find_line(lines, lambda l: l.strip() != "", start=i + 1)
    assert nxt is not None and lines[nxt].strip() == "## 5 Conclusion", "E3 region"
    lines = lines[: i + 1] + [""] + PIN1 + [""] + PIN2 + [""] + lines[nxt:]

    j = find_line(lines, lambda l: l.strip().startswith("## 5 Conclusion"))
    k = find_line(lines, lambda l: l.strip().startswith("## 6 Nomenclature"))
    assert j is not None and k is not None and j < k, "E4 section bounds"
    # Replace the whole old section 5 body between the heading and section 6.
    lines = lines[: j + 1] + [""] + NEW5 + [""] + lines[k:]
    return "\n".join(lines)


def build_tracker(old):
    a = (
        "The strip marker gains the NR-036 cite, and three long blocks split "
        "to hold the STE count.\n\n## 2. Working notes"
    )
    assert old.count(a) == 1, "E5 tracker anchor"
    b = (
        "The strip marker gains the NR-036 cite, and three long blocks split "
        "to hold the STE count.\n\n" + "\n".join(TRACKER_ENTRY) + "\n\n## 2. Working notes"
    )
    return old.replace(a, b)


def lint(path):
    r = subprocess.run(
        ["python3", "ste-lint.py", "--fail-above", "2.0", path],
        capture_output=True, text=True, cwd=ROOT,
    )
    out = r.stdout + r.stderr
    m = re.search(
        r"words=\s*(\d+)\s+total=\s*(\d+)\s+per100w=\s*([\d.]+)\s+em_dash=\s*(\d+)", out
    )
    assert m, f"lint parse failed for {path}: {out}"
    cats = dict(re.findall(r"(passive_voice|long_paragraph\(>6s\)|contraction)\s+x(\d+)", out))
    return {
        "words": int(m.group(1)), "total": int(m.group(2)),
        "per100w": float(m.group(3)), "em_dash": int(m.group(4)), "cats": cats,
    }


def offenders(path):
    r = subprocess.run(
        ["python3", PROBE, "ste-lint.py", path], capture_output=True, text=True, cwd=ROOT
    )
    out = r.stdout + r.stderr
    recs = []
    for line in out.splitlines():
        mm = re.match(r"\s+long block \d+ \(\d+ fragments\): (.*)$", line)
        if mm:
            recs.append("block: " + mm.group(1))
            continue
        mm = re.match(r"\s+(\w+): \[(.*)\]$", line)
        if mm and mm.group(2).strip():
            recs.append(f"{mm.group(1)}: {mm.group(2)}")
    return sorted(recs)


def write(path, text):
    target = ROOT / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(text, encoding="utf-8")


def check_pair(label, old, new, exp_removed, exp_added, exp_total):
    removed = {k: v for k, v in (tokens(old) - tokens(new)).items()}
    added = {k: v for k, v in (tokens(new) - tokens(old)).items()}
    assert removed == exp_removed, f"{label} token removals: {removed}"
    assert added == exp_added, f"{label} token additions: {added}"
    print(f"{label} token diff: OK  removed {removed}  added {added}")
    print(f"{label}: expected total {exp_total}")


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else ""
    old_draft = head_text(DRAFT)
    old_tracker = head_text(TRACKER)
    new_draft = build_draft(old_draft)
    new_tracker = build_tracker(old_tracker)

    check_pair(
        "draft", old_draft, new_draft, EXPECT_DRAFT_REMOVED, EXPECT_DRAFT_ADDED, 4
    )
    check_pair(
        "tracker", old_tracker, new_tracker, EXPECT_TRACKER_REMOVED, EXPECT_TRACKER_ADDED, 5
    )

    write("scratch/au_v019_head_draft.md", old_draft)
    write("scratch/au_v019_head_tracker.md", old_tracker)
    write("scratch/au_v019_sim.md", new_draft)
    write("scratch/au_v019_sim_tracker.md", new_tracker)

    base_d = lint("scratch/au_v019_head_draft.md")
    sim_d = lint("scratch/au_v019_sim.md")
    base_t = lint("scratch/au_v019_head_tracker.md")
    sim_t = lint("scratch/au_v019_sim_tracker.md")
    for label, b, s in (("draft", base_d, sim_d), ("tracker", base_t, sim_t)):
        print(f"{label}: base words {b['words']} total {b['total']} -> "
              f"sim words {s['words']} total {s['total']}")
        assert s["total"] == b["total"], f"{label} count moved"
        assert s["cats"] == b["cats"], f"{label} category mix moved: {b['cats']} -> {s['cats']}"
        assert s["em_dash"] == b["em_dash"] == 0, f"{label} em dash"
        ob = offenders("scratch/au_v019_head_draft.md" if label == "draft" else "scratch/au_v019_head_tracker.md")
        os_ = offenders("scratch/au_v019_sim.md" if label == "draft" else "scratch/au_v019_sim_tracker.md")
        assert ob == os_, f"{label} offender sets differ:\nbase {ob}\nsim  {os_}"
        print(f"{label} offender sets: identical, entry for entry ({len(ob)} entries)")
    print("sim checks pass")

    if mode == "--apply":
        cur_d = worktree_text(DRAFT)
        cur_t = worktree_text(TRACKER)
        assert cur_d == old_draft, "draft worktree differs from HEAD"
        assert cur_t == old_tracker, "tracker worktree differs from HEAD"
        write(DRAFT, new_draft)
        write(TRACKER, new_tracker)
        print("APPLIED: draft and tracker rewritten")
    elif mode == "--check":
        assert worktree_text(DRAFT) == new_draft, "draft worktree != built text"
        assert worktree_text(TRACKER) == new_tracker, "tracker worktree != built text"
        print("worktree equals the built texts")


if __name__ == "__main__":
    main()

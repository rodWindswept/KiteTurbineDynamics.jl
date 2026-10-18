#!/usr/bin/env python3
"""
Author fold: B-20 (Section 2 explicit decoder and gate math) and
B-21 (Section 3.3 steady-versus-drift clarity and the bow bound scope).

Two-state: a plain run reads the base from git HEAD, applies the declared
edits to candidates in scratch, and runs every gate without touching the
tree. --land additionally asserts the working tree is clean for the three
touched paths, writes the candidates over them, re-gates the on-disk
bytes, stages the explicit paths plus this script and its log, commits,
fetches and pushes.

The base is always `git show HEAD:<path>`, never the working tree, so the
fold cannot sweep another seat's uncommitted edits. Version tokens are
computed from the base at run time, so the same script lands on whatever
tip is current when the pen clears.
"""
import difflib
import re
import subprocess
import sys

DRAFT = "docs/reporting/drafts/2026-10-08-report-first-draft.md"
TRACKER = "docs/reporting/draft-tracker.md"
ROUTING = "docs/reporting/feedback/2026-10-18-feedbackbot1-builder-routing.md"
REGISTER = "docs/reporting/numbers-register.md"

BASE_DRAFT = "scratch/au_b20b21_draft_base.md"
CAND_DRAFT = "scratch/au_b20b21_draft_candidate.md"
BASE_TRACKER = "scratch/au_b20b21_tracker_base.md"
CAND_TRACKER = "scratch/au_b20b21_tracker_candidate.md"
BASE_ROUTING = "scratch/au_b20b21_routing_base.md"
CAND_ROUTING = "scratch/au_b20b21_routing_candidate.md"
LOG = "scratch/au_b20b21_fold.log"

LAND = "--land" in sys.argv
log_lines = []

UPSTREAM = subprocess.check_output(
    ["git", "rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}"], text=True
).strip()


def log(msg):
    print(msg)
    log_lines.append(msg)


def git(*args):
    return subprocess.check_output(["git"] + list(args), text=True)


def show_head(path):
    return git("show", f"HEAD:{path}")


# ---------------------------------------------------------------- edits

# E1: the version pin (dynamic: read the current minor, add one)
PIN_RE = re.compile(r"^(Internal engineering report\. Draft v\d+\.)(\d+)(\. Date 2026-10-18\.)$")


def edit_pin(text):
    lines = text.split("\n")
    hits = [i for i, ln in enumerate(lines) if PIN_RE.match(ln)]
    assert len(hits) == 1, f"pin line count {len(hits)}"
    i = hits[0]
    m = PIN_RE.match(lines[i])
    old_minor = int(m.group(2))
    lines[i] = f"{m.group(1)}{old_minor + 1}{m.group(3)}"
    return "\n".join(lines), old_minor, old_minor + 1


# E2: section 2.1 r_rotor sizing form (after the r_rotor paragraph ends)
E2_ANCHOR = (
    "The blade radius `r_rotor` is the aerodynamic size the\n"
    "blade spans from."
)
E2_INSERT = (
    "The power sizing inverts the power equation: `r_rotor = sqrt(P / (f Cp 0.5 rho pi v^3))` (NR-050).\n"
    "P reads the rotor power share and v the local wind speed at the ring.\n"
    "Cp reads the blade-element table coefficient at the sizing tip-speed ratio.\n"
    "f reads the bank-and-elevation projection factor.\n"
    "The winner decode reads r_rotor 2.434 m (NR-050)."
)

# E3: section 2.2.1 ring-count decode
E3_ANCHOR = (
    "The winner carries one active rotor, so x8 and x10 stay unused\n"
    "(NR-011)."
)
E3_INSERT = (
    "The decoder also rounds x4, the polygon side count, to an integer (NR-044).\n"
    "The ring count builds separately.\n"
    "A spacing pass lays the intermediate rings along the shaft from the length-to-radius target and the density profile.\n"
    "The builder then adds the ground ring and the hub ring at the ends.\n"
    "The winner reads six rings (NR-011)."
)

# E4: section 2.2.2 P_score and twist-ratio definitions
E4_ANCHOR = (
    "A short window can sample the decay and misstate the power. The team\n"
    "sized the window to outlast the decay."
)
E4_INSERT = (
    "The evaluator names two scoring quantities.\n"
    "P_score reads the tail-5 power, the mean of the last five seconds of the window (NR-046).\n"
    "The draft prints it as the end power.\n"
    "\n"
    "The twist ratio reads the absolute segment twist divided by the crossing limit, the worst segment over the window (NR-046).\n"
    "The crossing limit reads `δα* = 2 asin(L_seg / sqrt(2 (L_seg^2 + 2 r_seg^2)))` with r_seg the larger of the two ring radii at the segment (NR-053)."
)

# E5: section 2.4 campaign config table, the missing hard gates
E5A_ANCHOR = "| Power floor | 5.0 kW | NR-027, NR-039 |"
E5A_INSERT = E5A_ANCHOR + "\n| Power ceiling | 5.0 kW | NR-046 |"

E5B_ANCHOR = "| Structural FoS floor | 2.5 | NR-015 |"
E5B_INSERT = (
    E5B_ANCHOR
    + "\n| Clearance floor | 1.5 m | NR-042 |"
    + "\n| Tip-speed ceiling | 100.0 m/s | NR-047 |"
    + "\n| Torsional FoS floor | 1.5 | NR-052 |"
    + "\n| Twist gate | geometric crossing check | NR-052, NR-053 |"
)

# E6: section 3.3 the steady-versus-drift pair
E6_ANCHOR = "The machine held a steady operating point through the measurement window."
E6_INSERT = (
    "Steady and drifting describe two observables on two timescales.\n"
    "The power settles: the window swing reads half a per cent of the mean (NR-014).\n"
    "The extension speed spread reads 0.009 per cent (NR-059).\n"
    "\n"
    "The bow creeps slowly: each five-second step reads smaller than the last (NR-059).\n"
    "The extension steps fall from 0.0254 m to 0.00053 m (NR-059).\n"
    "So the machine holds its operating point while the shaft still creeps toward its bowed shape."
)

# E7: section 3.3 the bound sentence, both stations plus the scope line
E7_ANCHOR = "Every state at the midpoint ring reads below the 1.5 m line (NR-059)."
E7_INSERT = (
    "Every measured state at the midpoint ring and the hub reads below the 1.5 m comparison bar (NR-059).\n"
    "The record ends at 200 seconds, so the report claims no bound past the measured span (NR-059)."
)

# E8: builder routing record, the two OTHER-SEAT rows flip
E8A_ANCHOR = "| B-20 | Section 2 omits the decoder and gate math | OTHER-SEAT |"
E8A_INSERT = "| B-20 | Section 2 omits the decoder and gate math | LANDED (author) |"

E8B_ANCHOR = "| B-21 | Section 3.3 steady-state claim versus the shaft-bow drift | OTHER-SEAT |"
E8B_INSERT = "| B-21 | Section 3.3 steady-state claim versus the shaft-bow drift | LANDED (author) |"

# E9: tracker history entry (dynamic: next number after the last vN entry)
TRACKER_ENTRY = (
    "v{v} (2026-10-18): the B-20 and B-21 prose pass lands.\n"
    "Section 2 gains the decoder and gate math.\n"
    "The write covers the r_rotor sizing form, the ring-count decode, and the P_score and twist-ratio definitions.\n"
    "The full hard-gate list joins the campaign config table.\n"
    "\n"
    "Section 3.3 states the steady-and-drifting pair as two observables on two timescales.\n"
    "It extends the bow bound to both stations, with the 200-second scope line."
)


def edit_tracker(text):
    hits = re.findall(r"^v(\d+) \(2026-10-18\):", text, re.MULTILINE)
    assert hits, "no tracker vN entry found"
    nxt = max(int(h) for h in hits) + 1
    entry = TRACKER_ENTRY.format(v=nxt)
    return text.rstrip("\n") + "\n\n" + entry + "\n", nxt


def once_replace(text, anchor, insert):
    n = text.count(anchor)
    assert n == 1, f"anchor count {n}: {anchor[:60]!r}"
    return text.replace(anchor, insert)


def apply_edits(draft, tracker, routing):
    draft, old_minor, new_minor = edit_pin(draft)
    draft = once_replace(draft, E2_ANCHOR, E2_ANCHOR + "\n\n" + E2_INSERT)
    draft = once_replace(draft, E3_ANCHOR, E3_ANCHOR + "\n\n" + E3_INSERT)
    draft = once_replace(draft, E4_ANCHOR, E4_ANCHOR + "\n\n" + E4_INSERT)
    draft = once_replace(draft, E5A_ANCHOR, E5A_INSERT)
    draft = once_replace(draft, E5B_ANCHOR, E5B_INSERT)
    draft = once_replace(draft, E6_ANCHOR, E6_ANCHOR + "\n\n" + E6_INSERT)
    draft = once_replace(draft, E7_ANCHOR, E7_INSERT)
    routing = once_replace(routing, E8A_ANCHOR, E8A_INSERT)
    routing = once_replace(routing, E8B_ANCHOR, E8B_INSERT)
    tracker, tv = edit_tracker(tracker)
    return draft, tracker, routing, (old_minor, new_minor, tv)


# ---------------------------------------------------------------- gates

TOKEN_RE = re.compile(r"(?<![\w-])\d+(?:\.\d+)?(?![\w-])")
CODE_RE = re.compile(r"`[^`]*`")


def tokens(text):
    return sorted(TOKEN_RE.findall(CODE_RE.sub("", text)))


def multiset_diff(a, b):
    import collections

    ca, cb = collections.Counter(a), collections.Counter(b)
    rem = sorted((ca - cb).elements())
    add = sorted((cb - ca).elements())
    return rem, add


def lint_total(path):
    out = subprocess.run(
        ["python3", "ste-lint.py", path], text=True, capture_output=True
    )
    m = re.search(r"words=\s*\d+ total=\s*(\d+) per100w=\s*([0-9.]+) em_dash=\s*(\d+)", out.stdout)
    assert m, f"lint summary missing for {path}\n{out.stdout[-500:]}"
    cats = re.findall(r"\[HOOK:ste\] [^:]+: (\S+) x(\d+)", out.stdout)
    return int(m.group(1)), float(m.group(2)), int(m.group(3)), sorted(cats)


def citation_gate(path):
    out = subprocess.run(
        ["python3", "scratch/sv_check_draft_citations.py", path, REGISTER],
        text=True,
        capture_output=True,
    )
    return out


def census(name, base, cand):
    lb, lc = base.count("\n"), cand.count("\n")
    tb, tc = tokens(base), tokens(cand)
    rem, add = multiset_diff(tb, tc)
    ops = [op for op, _, _, _, _ in difflib.SequenceMatcher(None, base, cand).get_opcodes()]
    log(f"{name}: lines {lb} -> {lc} (delta {lc - lb})")
    log(f"{name}: tokens removed {rem}")
    log(f"{name}: tokens added   {add}")
    log(f"{name}: opcodes {ops}")
    return rem, add


def round_trip(draft, tracker, routing, version_info):
    old_minor, new_minor, tv = version_info
    back = draft.replace(f" Draft v0.{new_minor}. Date", f" Draft v0.{old_minor}. Date")
    back = back.replace("\n\n" + E2_INSERT, "")
    back = back.replace("\n\n" + E3_INSERT, "")
    back = back.replace("\n\n" + E4_INSERT, "")
    back = back.replace("\n| Power ceiling | 5.0 kW | NR-046 |", "")
    back = back.replace("\n| Clearance floor | 1.5 m | NR-042 |\n| Tip-speed ceiling | 100.0 m/s | NR-047 |\n| Torsional FoS floor | 1.5 | NR-052 |\n| Twist gate | geometric crossing check | NR-052, NR-053 |", "")
    back = back.replace("\n\n" + E6_INSERT, "")
    back = back.replace(E7_INSERT, E7_ANCHOR)
    base_draft = show_head(DRAFT)
    assert back == base_draft, "draft round-trip failed"
    tr_back = tracker.replace("\n\n" + TRACKER_ENTRY.format(v=tv) + "\n", "\n").rstrip("\n") + "\n"
    base_tracker = show_head(TRACKER)
    if tr_back != base_tracker:
        # the entry is appended at the end; strip it by the exact tail
        tr_back = tracker[: tracker.rindex("\n\nv{tv} (2026-10-18):".format(tv=tv))].rstrip("\n") + "\n"
    assert tr_back == base_tracker, "tracker round-trip failed"
    ro_back = routing.replace("| LANDED (author) |", "| OTHER-SEAT |")
    assert ro_back == show_head(ROUTING), "routing round-trip failed"


# ---------------------------------------------------------------- main

def main():
    if LAND:
        for p in (DRAFT, TRACKER, ROUTING):
            d = git("diff", "HEAD", "--", p)
            assert not d, f"tree dirty for {p}: another seat holds the pen"
        git("fetch")
        behind = git("log", "--oneline", f"HEAD..{UPSTREAM}")
        assert not behind.strip(), f"upstream ahead, rebase first: {behind[:400]}"

    base_draft = show_head(DRAFT)
    base_tracker = show_head(TRACKER)
    base_routing = show_head(ROUTING)
    open(BASE_DRAFT, "w").write(base_draft)
    open(BASE_TRACKER, "w").write(base_tracker)
    open(BASE_ROUTING, "w").write(base_routing)

    cand_draft, cand_tracker, cand_routing, version_info = apply_edits(
        base_draft, base_tracker, base_routing
    )
    old_minor, new_minor, tv = version_info
    log(f"pin v0.{old_minor} -> v0.{new_minor}; tracker entry v{tv}")

    open(CAND_DRAFT, "w").write(cand_draft)
    open(CAND_TRACKER, "w").write(cand_tracker)
    open(CAND_ROUTING, "w").write(cand_routing)

    round_trip(cand_draft, cand_tracker, cand_routing, version_info)
    log("round-trip: candidate minus declared edits equals HEAD base (all three surfaces)")

    rem_d, add_d = census("draft", base_draft, cand_draft)
    rem_t, add_t = census("tracker", base_tracker, cand_tracker)
    rem_r, add_r = census("routing", base_routing, cand_routing)

    expect_d_rem = [str(old_minor)]
    expect_d_add = sorted(
        [str(new_minor), "2.434", "5.0", "1.5", "1.5", "100.0", "0.009", "0.0254", "0.00053", "200"]
    )
    expect_t_add = sorted(["2", "3.3"])
    assert rem_d == expect_d_rem, f"draft removed {rem_d} != {expect_d_rem}"
    assert add_d == expect_d_add, f"draft added {add_d} != {expect_d_add}"
    assert rem_t == [] and add_t == expect_t_add, f"tracker tokens {rem_t} {add_t}"
    assert rem_r == [] and add_r == [], f"routing tokens {rem_r} {add_r}"
    log("token census: declared sets match on all three surfaces")

    for name, b, c in (
        ("draft", BASE_DRAFT, CAND_DRAFT),
        ("tracker", BASE_TRACKER, CAND_TRACKER),
        ("routing", BASE_ROUTING, CAND_ROUTING),
    ):
        tb = lint_total(b)
        tc = lint_total(c)
        log(f"ste {name}: base total={tb[0]} per100w={tb[1]} em_dash={tb[2]} cats={tb[3]}")
        log(f"ste {name}: cand total={tc[0]} per100w={tc[1]} em_dash={tc[2]} cats={tc[3]}")
        assert tb[0] == tc[0], f"ste total moved on {name}"
        assert tb[3] == tc[3], f"ste category set moved on {name}"
    log("ste: total and per-category hold on all three surfaces")

    cite = citation_gate(CAND_DRAFT)
    assert cite.returncode == 0, "citation checker rc != 0"
    assert "cited rows in" in cite.stdout and ": 55" in cite.stdout, "cited count moved"
    assert "every cited row present and signed" in cite.stdout, "sign-off state moved"
    log("citation gate: exit 0, 55 cited, every one signed")

    pan = subprocess.run(["pandoc", "-f", "markdown", "-t", "json", CAND_DRAFT], capture_output=True, text=True)
    assert pan.returncode == 0, f"pandoc parse failed: {pan.stderr[:400]}"
    log("pandoc: candidate parses clean")

    if not LAND:
        log("dry run complete: candidates and gate log in scratch; nothing committed")
        return

    for src, dst in (
        (CAND_DRAFT, DRAFT),
        (CAND_TRACKER, TRACKER),
        (CAND_ROUTING, ROUTING),
    ):
        open(dst, "w").write(open(src).read())
    lt = lint_total(DRAFT)
    cite = citation_gate(DRAFT)
    assert cite.returncode == 0
    git("add", DRAFT, TRACKER, ROUTING, __file__)
    git("add", "-f", LOG)
    msg = (
        "docs(reporting): the B-20 and B-21 prose pass lands - section 2 gains the "
        f"explicit decoder and gate math and section 3.3 states the steady-and-drifting "
        f"pair with the bow bound on both stations; the draft ticks to v0.{new_minor}; "
        f"STE rc=0 at {lt[1]}/100w; citation checker exit 0 (55 cited, every one signed)"
    )
    git("commit", "-m", msg)
    git("fetch")
    git("push")
    tip = git("rev-parse", "HEAD").strip()
    origin = git("rev-parse", UPSTREAM).strip()
    assert tip == origin, f"local != {UPSTREAM} after push"
    log(f"landed: {tip} ({UPSTREAM})")


if __name__ == "__main__":
    try:
        main()
    except AssertionError as e:
        log(f"FAIL: {e}")
        raise
    finally:
        open(LOG, "w").write("\n".join(log_lines) + "\n")

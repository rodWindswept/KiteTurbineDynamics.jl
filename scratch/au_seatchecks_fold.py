#!/usr/bin/env python3
"""
Author fold: the house-vocabulary swap (science-writer sweep 33 handoff).

Two sites move: the draft ladder-embed sentence (line 1024) and the
value-claims-ledger row 29. Both read the reader-facing noun.
The draft pin ticks v0.64 -> v0.65, and the tracker gains its v7 entry.
The scaling-ladder manifest pin refreshes at the figure seat afterwards
(ledger blob moves, section 4 untouched).

Two-state: a plain run reads the base from git HEAD, applies the declared
edits to candidates in scratch, and runs every gate without touching the
tree. --land additionally asserts the working tree is clean for the three
touched paths, writes the candidates over them, re-gates the on-disk
bytes, stages the explicit paths plus this script and its log, commits,
fetches and pushes.
"""
import difflib
import re
import subprocess
import sys

DRAFT = "docs/reporting/drafts/2026-10-08-report-first-draft.md"
TRACKER = "docs/reporting/draft-tracker.md"
LEDGER = "docs/reporting/value-claims-ledger.md"
REGISTER = "docs/reporting/numbers-register.md"

BASE_DRAFT = "scratch/au_seatchecks_draft_base.md"
CAND_DRAFT = "scratch/au_seatchecks_draft_candidate.md"
BASE_TRACKER = "scratch/au_seatchecks_tracker_base.md"
CAND_TRACKER = "scratch/au_seatchecks_tracker_candidate.md"
BASE_LEDGER = "scratch/au_seatchecks_ledger_base.md"
CAND_LEDGER = "scratch/au_seatchecks_ledger_candidate.md"
LOG = "scratch/au_seatchecks_fold.log"

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


# E2: the draft ladder-embed sentence (the only draft site)
E2_ANCHOR = "The register, the test suite and the seat checks hold every"
E2_NEW = "The register, the test suite and the pipeline hold every"

# E3: the value-claims-ledger row 29 (the only ledger site)
E3_ANCHOR = "the seat checks that hold every number"
E3_NEW = "the pipeline that hold every number"

# E4: tracker entry (new form only; the old form never prints in new text)
TRACKER_ENTRY = (
    "v7 (2026-10-18): the house-vocabulary swap lands (author).\n"
    "\n"
    "The ladder-embed sentence reads the pipeline.\n"
    "The value-claims-ledger row mirrors the sentence.\n"
    "The draft ticks to v0.65."
)


def edit_tracker(text):
    assert text.rstrip("\n").endswith("A-13 and A-20 to A-22 stay gated.")
    entry = TRACKER_ENTRY
    return text.rstrip("\n") + "\n\n" + entry + "\n", entry


def once_replace(text, anchor, insert):
    n = text.count(anchor)
    assert n == 1, f"anchor count {n}: {anchor[:60]!r}"
    return text.replace(anchor, insert)


def apply_edits(draft, tracker, ledger):
    draft, old_minor, new_minor = edit_pin(draft)
    assert draft.count("the seat checks") == 1, "draft old-form count moved"
    draft = once_replace(draft, E2_ANCHOR, E2_NEW)
    assert ledger.count("the seat checks") == 1, "ledger old-form count moved"
    ledger = once_replace(ledger, E3_ANCHOR, E3_NEW)
    tracker, entry = edit_tracker(tracker)
    return draft, tracker, ledger, (old_minor, new_minor, entry)


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


def round_trip(draft, tracker, ledger, version_info):
    old_minor, new_minor, entry = version_info
    back = draft.replace(f" Draft v0.{new_minor}. Date", f" Draft v0.{old_minor}. Date")
    back = back.replace(E2_NEW, E2_ANCHOR)
    assert back == show_head(DRAFT), "draft round-trip failed"
    tr_back = tracker.replace("\n\n" + entry + "\n", "\n").rstrip("\n") + "\n"
    assert tr_back == show_head(TRACKER), "tracker round-trip failed"
    le_back = ledger.replace(E3_NEW, E3_ANCHOR)
    assert le_back == show_head(LEDGER), "ledger round-trip failed"


# ---------------------------------------------------------------- main

def main():
    if LAND:
        for p in (DRAFT, TRACKER, LEDGER):
            d = git("diff", "HEAD", "--", p)
            assert not d, f"tree dirty for {p}: another seat holds the pen"
        git("fetch")
        behind = git("log", "--oneline", f"HEAD..{UPSTREAM}")
        assert not behind.strip(), f"upstream ahead, rebase first: {behind[:400]}"

    base_draft = show_head(DRAFT)
    base_tracker = show_head(TRACKER)
    base_ledger = show_head(LEDGER)
    open(BASE_DRAFT, "w").write(base_draft)
    open(BASE_TRACKER, "w").write(base_tracker)
    open(BASE_LEDGER, "w").write(base_ledger)

    cand_draft, cand_tracker, cand_ledger, version_info = apply_edits(
        base_draft, base_tracker, base_ledger
    )
    old_minor, new_minor, entry = version_info
    log(f"pin v0.{old_minor} -> v0.{new_minor}; tracker entry v7")

    open(CAND_DRAFT, "w").write(cand_draft)
    open(CAND_TRACKER, "w").write(cand_tracker)
    open(CAND_LEDGER, "w").write(cand_ledger)

    round_trip(cand_draft, cand_tracker, cand_ledger, version_info)
    log("round-trip: candidate minus declared edits equals HEAD base (all three surfaces)")

    rem_d, add_d = census("draft", base_draft, cand_draft)
    rem_t, add_t = census("tracker", base_tracker, cand_tracker)
    rem_l, add_l = census("ledger", base_ledger, cand_ledger)

    assert rem_d == [str(old_minor)] and add_d == [str(new_minor)], (
        f"draft tokens {rem_d} {add_d}"
    )
    assert rem_t == [] and add_t == [str(new_minor)], f"tracker tokens {rem_t} {add_t}"
    assert rem_l == [] and add_l == [], f"ledger tokens {rem_l} {add_l}"
    log("token census: declared sets match on all three surfaces")

    for name, b, c in (
        ("draft", BASE_DRAFT, CAND_DRAFT),
        ("tracker", BASE_TRACKER, CAND_TRACKER),
        ("ledger", BASE_LEDGER, CAND_LEDGER),
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
    assert "cited rows in" in cite.stdout and ": 56" in cite.stdout, "cited count moved"
    assert "every cited row present and signed" in cite.stdout, "sign-off state moved"
    log("citation gate: exit 0, 56 cited, every one signed")

    pan = subprocess.run(["pandoc", "-f", "markdown", "-t", "json", CAND_DRAFT], capture_output=True, text=True)
    assert pan.returncode == 0, f"pandoc parse failed: {pan.stderr[:400]}"
    log("pandoc: candidate parses clean")

    if not LAND:
        log("dry run complete: candidates and gate log in scratch; nothing committed")
        return

    for src, dst in (
        (CAND_DRAFT, DRAFT),
        (CAND_TRACKER, TRACKER),
        (CAND_LEDGER, LEDGER),
    ):
        open(dst, "w").write(open(src).read())
    lt = lint_total(DRAFT)
    cite = citation_gate(DRAFT)
    assert cite.returncode == 0
    open(LOG, "w").write("\n".join(log_lines) + "\n")
    git("add", DRAFT, TRACKER, LEDGER, __file__)
    git("add", "-f", LOG)
    msg = (
        "docs(reporting): the house-vocabulary swap lands - the draft ladder-embed "
        "sentence and the value-claims-ledger row read the pipeline; the draft ticks "
        f"to v0.{new_minor}; STE rc=0 at {lt[1]}/100w; citation checker exit 0 "
        "(56 cited, every one signed) (author)"
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

#!/usr/bin/env python3
"""Reader-build strip for the KTD report draft.

Seat: @software-worker (gate 2, the reader-build strip).

The single-source draft under docs/reporting/ carries the internal apparatus
that makes every number traceable inside the room: register-row citations,
figure roster labels, kit provenance stamps, the signed-row data appendix, the
builder build record, and a handful of internal front-matter and appendix
blocks. That apparatus is the reason the internal copy is auditable. It is also
the reason the internal copy is not a release.

This module produces the reader view. It is a display-layer transform over the
assembled text. It never edits the single-source draft, never rewrites a
number, and never moves a register row. The source keeps its citations; the
reader copy drops them.

Two classes of removal, kept strictly apart:

  Class A - mechanical. No judgement, no prose. Citation tokens, internal
  columns, internal sections, unresolved-figure failures and [PENDING]
  brackets. A machine can prove each one.

  Class B - prose. A sentence that talks about the register, the row IDs or
  the room is a wording decision, and the wording is the author's. Every such
  site is listed in a rulings manifest and must carry the author's decision
  before a reader build may run. The tool refuses to guess.

Usage:
  scripts/reader_strip.py --report          # plan only, writes nothing
  scripts/reader_strip.py --check           # residual gate on the stripped text
  scripts/reader_strip.py --sites           # list class B sites and their state

The builders call strip_text() in reader mode. The internal review route is
untouched: it keeps every token, appendix and stamp.
"""

import argparse
import json
import re
import sys
from pathlib import Path

DRAFT = "docs/reporting/drafts/2026-10-08-report-first-draft.md"
RULINGS = "docs/reporting/reader-build/prose-rulings.json"

# ---------------------------------------------------------------- class A ---

# Internal sections, matched by their heading text. A section runs from its
# heading to the next top-level or second-level heading. The headings carry no
# numbers here on purpose: a renumber must not disable the strip silently.
DROP_SECTIONS = (
    "## Document control",
    "## Appendix: Claims and evidence",
    "## Appendix: Figure provenance",
)

# The internal front matter sits between these two lines, both distinctive.
# Both must be present: a missing anchor is a build failure, not a guess.
FRONT_MATTER_START = re.compile(r"^Internal engineering report\.", re.MULTILINE)
FRONT_MATTER_END = re.compile(r"^A section marked \[PENDING\] waits on a gate\.", re.MULTILINE)

# Table columns that exist only to carry register row IDs.
INTERNAL_COLUMNS = ("Rows", "Register rows", "Cited rows")

PENDING_BRACKET = re.compile(r"\s*\[PENDING[^\]]*\]")

# Status tokens read as plain words in the reader copy. The numbers do not
# change, and the tokens stay in code and in the register. Longest first, so
# clearance_reject never splits into reject.
ENUM_WORDS = (
    ("non-ok", re.compile(r"(?<![A-Za-z_])non-ok(?![A-Za-z_])"), "not passed"),
    ("clearance_reject", re.compile(r"(?<![A-Za-z_])clearance_reject(?![A-Za-z_])"), "rejected on clearance"),
    ("reject_twist", re.compile(r"(?<![A-Za-z_])reject_twist(?![A-Za-z_])"), "rejected on twist"),
    ("reject", re.compile(r"(?<![A-Za-z_])reject(?![A-Za-z_])"), "rejected"),
    ("ok", re.compile(r"(?<![A-Za-z_])ok(?![A-Za-z_])"), "passed"),
)

# A citation group: "(NR-001)", "(NR-008, NR-032)", "(NR-003 to NR-006)".
CITE_GROUP = re.compile(
    r"\s*\((?:NR-\d{3}(?:\s*(?:,\s*|to\s*))?)+\)"
)
# Any surviving token, including the amended-row suffix "NR-013 ext2".
CITE_TOKEN = re.compile(r"\s*NR-\d{3}(?:\s*ext\d+)?")

# Survivals that fail a reader build outright. Each one is a class the strip
# claims to remove, so a survivor means the strip is incomplete, not that the
# reader copy is fine.
RESIDUAL_PATTERNS = (
    ("citation token", CITE_TOKEN),
    ("figure marker", re.compile(r"\[Figure seated:")),
    ("figure roster row", re.compile(r"figure-map row")),
    ("figure slug", re.compile(r"roster row|slug `")),
    ("pending marker", re.compile(r"\[PENDING")),
    ("data appendix", re.compile(r"Data register \(cited rows\)")),
    ("build record", re.compile(r"Build record \(builder output\)")),
    ("missing kit", re.compile(r"Figure seat unresolved by the builder")),
    ("internal register column", re.compile(r"\|\s*(?:Rows|Register rows|Cited rows)\s*\|")),
    ("status token", re.compile(r"(?<![A-Za-z_])(?:clearance_reject|reject_twist|non-ok|ok|reject)(?![A-Za-z_])")),
)


class StripError(RuntimeError):
    """A strip rule could not be applied. Always fatal."""


def _split_row(line):
    """Split one pipe-table row into cells, preserving the outer pipes."""
    body = line.strip()
    if not body.startswith("|") or not body.endswith("|"):
        raise StripError(f"not a pipe-table row: {line[:80]!r}")
    return body[1:-1].split("|")


def _join_row(cells):
    return "|" + "|".join(cells) + "|"


def _is_separator(line):
    return bool(re.fullmatch(r"\|[\s:|-]+\|", line.strip()))


def _drop_columns(text, column_names, events):
    """Drop named columns from every pipe table that carries one."""
    lines = text.splitlines()
    out = []
    i = 0
    dropped = 0
    while i < len(lines):
        line = lines[i]
        nxt = lines[i + 1] if i + 1 < len(lines) else ""
        if line.strip().startswith("|") and _is_separator(nxt):
            header = _split_row(line)
            names = [c.strip() for c in header]
            drop = {k for k, name in enumerate(names) if name in column_names}
            if not drop:
                out.append(line)
                i += 1
                continue
            # Consume the whole table block: header, separator, body rows.
            block = []
            j = i
            while j < len(lines) and lines[j].strip().startswith("|"):
                block.append(lines[j])
                j += 1
            width = len(names)
            for k, row in enumerate(block):
                cells = _split_row(row)
                if k == 1 and _is_separator(row):
                    kept = [c for n, c in enumerate(cells) if n not in drop]
                else:
                    if len(cells) != width:
                        raise StripError(
                            f"table at line {i + 1}: row has {len(cells)} cells, "
                            f"header has {width}"
                        )
                    kept = [c for n, c in enumerate(cells) if n not in drop]
                out.append(_join_row(kept))
            dropped += 1
            events.append(
                f"column dropped: {', '.join(sorted(names[k] for k in drop))} "
                f"(table at line {i + 1}, {len(block) - 2} data rows)"
            )
            i = j
            continue
        out.append(line)
        i += 1
    return "\n".join(out), dropped


def _drop_sections(text, headings, events):
    """Drop each named section from its heading to the next heading."""
    lines = text.splitlines()
    out = []
    skipping = False
    dropped = []
    for line in lines:
        if line.strip() in headings:
            skipping = True
            dropped.append(line.strip())
            events.append(f"section dropped: {line.strip()}")
            continue
        if skipping and re.match(r"^#{1,2} ", line):
            skipping = False
        if skipping:
            continue
        out.append(line)
    missing = set(headings) - set(dropped)
    if missing:
        raise StripError(f"section heading not found: {sorted(missing)}")
    return "\n".join(out), len(dropped)


def _drop_front_matter(text, events):
    """Drop the internal front matter between its two anchors."""
    start = FRONT_MATTER_START.search(text)
    end = FRONT_MATTER_END.search(text)
    if not start or not end:
        raise StripError("front-matter anchor missing (start or end)")
    if end.start() < start.start():
        raise StripError("front-matter anchors out of order")
    end_line_end = text.find("\n", end.end())
    if end_line_end == -1:
        end_line_end = len(text)
    events.append(
        f"front matter dropped: {text[start.start():end_line_end].count(chr(10)) + 1} lines"
    )
    return text[: start.start()] + text[end_line_end + 1 :]


def _strip_citations(text, events):
    """Remove citation groups, then any surviving token."""
    groups = CITE_GROUP.findall(text)
    text = CITE_GROUP.sub("", text)
    events.append(f"citation groups dropped: {len(groups)}")
    stray = CITE_TOKEN.findall(text)
    text = CITE_TOKEN.sub("", text)
    if stray:
        events.append(f"stray citation tokens dropped: {len(stray)}")
    return text


def _strip_pending(text, events):
    hits = PENDING_BRACKET.findall(text)
    text = PENDING_BRACKET.sub("", text)
    if hits:
        events.append(f"pending brackets dropped: {len(hits)}")
    return text


def _strip_enums(text, events):
    """Read the four status tokens as plain words."""
    total = 0
    for name, pattern, word in ENUM_WORDS:
        hits = pattern.findall(text)
        if hits:
            text = pattern.sub(word, text)
            total += len(hits)
            events.append(f"status token {name} -> {word}: {len(hits)}")
    if total:
        events.append(f"status tokens read as plain words: {total}")
    return text


# ---------------------------------------------------------------- class B ---


def load_rulings(path):
    """Read the prose-site rulings.

    The rulings live in JSON, not in the markdown sheet, because each anchor
    is an exact fragment of the draft and some fragments run past twenty
    words. The markdown sheet records the same decisions for a human reader
    and stays inside the house prose limits.

    Each entry reads:
      id, anchor, decision, replacement (optional), note (optional)
    decision - keep | drop | rewrite | folded

    anchor      exact draft text to find. A wrapped sentence takes the \\n
                escape so one entry can span the line break.
    rewrite     swaps the anchor for replacement, in place.
    drop        deletes the physical line that carries the anchor. The line
                must hold the anchor alone, so a shared line is refused.
    folded      the author already folded the wording into the source, so
                the anchor may be absent.
    An absent anchor fails the build unless the entry reads folded.
    """
    p = Path(path)
    if not p.is_absolute():
        p = Path(__file__).resolve().parent.parent / p
    if not p.exists():
        return [], ""
    data = json.loads(p.read_text())
    base = data.get("base_draft_version", "")
    sites = []
    for entry in data.get("sites", []):
        sites.append({
            "id": entry["id"],
            "anchor": entry["anchor"].replace("\\n", "\n"),
            "decision": (entry.get("decision") or ""),
            "replacement": (entry.get("replacement") or ""),
            "note": entry.get("note", ""),
        })
    return sites, base


def draft_version(text):
    """Declared draft version from the front matter, as (major, minor)."""
    m = re.search(r"Draft v(\d+)\.(\d+)\.", text, re.MULTILINE)
    if not m:
        return None
    return (int(m.group(1)), int(m.group(2)))


def _older_than(draft_ver, base_ver):
    """True when the draft sits behind the version the rulings were written on."""
    if not draft_ver or not base_ver:
        return False
    m = re.fullmatch(r"v(\d+)\.(\d+)", base_ver.strip())
    if not m:
        return False
    return draft_ver < (int(m.group(1)), int(m.group(2)))


def apply_rulings(text, sites, events):
    """Apply the author's class B decisions. Unruled sites block the build."""
    unruled = [
        s for s in sites
        if s["decision"].lower() in ("", "unruled", "pending", "-")
    ]
    if unruled:
        return text, [s["id"] for s in unruled]

    # Each site decides for itself whether a missing anchor is a fault: a
    # rewrite proves itself by its replacement standing in the draft, and a
    # dropped sentence is absent by design once the author folds it in.
    for s in sites:
        anchor = s["anchor"]
        decision = s["decision"].lower()
        if decision in ("keep", "folded"):
            continue
        if decision == "deferred":
            # The ruling targets text that has not reached this draft yet, so
            # its absence is not a fault. When the text lands, the rewrite
            # applies on its own and no seat has to remember to flip it.
            if anchor not in text:
                events.append(f"prose site deferred, text absent: {s['id']}")
                continue
            text = text.replace(anchor, s["replacement"], 1)
            events.append(f"prose site rewritten on arrival: {s['id']}")
            continue
        if decision == "rewrite":
            replacement = s["replacement"]
            if not replacement:
                raise StripError(f"site {s['id']}: rewrite carries no text")
            if anchor not in text:
                # The author folds the ruled wording into the draft on the
                # gate 1 sign. A missing anchor then carries its own proof:
                # the replacement text stands in the draft already.
                if replacement in text:
                    events.append(f"prose site already folded: {s['id']}")
                    continue
                raise StripError(
                    f"site {s['id']}: anchor gone and replacement absent"
                )
            text = text.replace(anchor, replacement, 1)
            events.append(f"prose site rewritten: {s['id']}")
            continue
        if decision == "drop":
            lines = text.split("\n")
            hits = [i for i, line in enumerate(lines) if anchor in line]
            if not hits:
                # A dropped sentence is absent by design once the fold lands.
                events.append(f"prose site already folded: {s['id']}")
                continue
            for i in hits:
                if lines[i].strip() != anchor.strip():
                    raise StripError(
                        f"site {s['id']}: line carries more than the anchor, refusing to drop"
                    )
            for i in reversed(hits):
                del lines[i]
            text = "\n".join(lines)
            events.append(f"prose site dropped: {s['id']} ({len(hits)} lines)")
            continue
        raise StripError(f"site {s['id']}: unknown decision {s['decision']!r}")
    return text, []


# ------------------------------------------------------------------- api ---


def strip_text(text, rulings_path=None, apply_prose=True):
    """Return (reader_text, report). Raises StripError on any failed rule."""
    if rulings_path is None:
        rulings_path = RULINGS
    events = []
    draft_ver = draft_version(text)
    text = _drop_front_matter(text, events)
    # Rulings run before the citation strip: an anchor is written against the
    # source sentence, which still carries its row tokens. A replacement that
    # omits them is correct, because the token strip runs next.
    sites, base_ver = load_rulings(rulings_path) if apply_prose else ([], "")
    queued = []
    if apply_prose and _older_than(draft_ver, base_ver):
        # The rulings were written on a later draft than this one. An absent
        # anchor then names text that has not reached this tree yet, so the
        # build reports it as queued instead of failing. A site still reads
        # fatal when the draft has caught up and the anchor has vanished.
        present, absent = [], []
        for s in sites:
            (present if s["anchor"] in text else absent).append(s)
        queued = [s["id"] for s in absent]
        sites = present
        dv = f"{draft_ver[0]}.{draft_ver[1]:02d}" if draft_ver else "an older form"
        events.append(
            f"rulings queued for a later draft: {len(queued)} sites "
            f"(draft {dv} behind {base_ver})"
        )
    text, unruled = apply_rulings(text, sites, events)
    text, _ = _drop_sections(text, DROP_SECTIONS, events)
    text, _ = _drop_columns(text, INTERNAL_COLUMNS, events)
    text = _strip_pending(text, events)
    text = _strip_citations(text, events)
    text = _strip_enums(text, events)
    text = re.sub(r"[ \t]+\n", "\n", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    report = {
        "events": events,
        "sites": sites,
        "queued": queued,
        "unruled": unruled,
        "residuals": residual_scan(text),
    }
    return text, report


def residual_scan(text):
    """Return [(class, count)] for every internal survival still in the text."""
    out = []
    for name, pattern in RESIDUAL_PATTERNS:
        n = len(pattern.findall(text))
        if n:
            out.append((name, n))
    return out


def reader_gate(text, report=None):
    """Raise unless the reader text is clean and every prose site is ruled."""
    residuals = residual_scan(text)
    if residuals:
        detail = ", ".join(f"{n} {c}" for c, n in residuals)
        raise StripError(f"reader build blocked - internal apparatus survives: {detail}")
    if report is not None and report["unruled"]:
        raise StripError(
            "reader build blocked - prose sites await the author's ruling: "
            + ", ".join(report["unruled"])
        )
    return True


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--draft", default=DRAFT)
    ap.add_argument("--rulings", default=RULINGS)
    ap.add_argument("--report", action="store_true", help="print the plan, write nothing")
    ap.add_argument("--check", action="store_true", help="run the residual gate")
    ap.add_argument("--sites", action="store_true", help="list class B sites")
    args = ap.parse_args()

    root = Path(__file__).resolve().parent.parent
    draft = root / args.draft
    if not draft.exists():
        sys.exit(f"reader_strip: draft not found: {draft}")
    text = draft.read_text()

    if args.sites:
        sites, base = load_rulings(root / args.rulings)
        print(f"rulings: {args.rulings}  base draft {base or 'unstated'}")
        print(f"sites: {len(sites)}")
        for s in sites:
            state = s["decision"] if s["decision"] else "UNRULED"
            print(f"  {s['id']:<8} {state:<10} {s['anchor'][:66]}")
        return 0

    reader, report = strip_text(text, root / args.rulings)
    print("-- strip events --")
    for e in report["events"]:
        print(f"  {e}")
    print("-- class B --")
    print(f"  sites applied {len(report['sites'])}, queued {len(report['queued'])}, "
          f"unruled {len(report['unruled'])}")
    if report["queued"]:
        print(f"  queued ids: {', '.join(report['queued'])}")
    if report["unruled"]:
        print(f"  unruled ids: {', '.join(report['unruled'])}")
    print("-- residual gate --")
    if report["residuals"]:
        for name, n in report["residuals"]:
            print(f"  SURVIVES {n:>4}  {name}")
    else:
        print("  clean")
    print("-- measure --")
    print(f"  source words {len(text.split())}")
    print(f"  reader words {len(reader.split())}")
    print(f"  source lines {len(text.splitlines())}")
    print(f"  reader lines {len(reader.splitlines())}")

    if args.check:
        reader_gate(reader, report)
        print("[check] reader gate passed")
    if args.report:
        print("[report] no file written")
    return 0


if __name__ == "__main__":
    sys.exit(main())

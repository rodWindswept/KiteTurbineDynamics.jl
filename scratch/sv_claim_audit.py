#!/usr/bin/env python3
"""Claim-by-claim audit check (science-validator seat).

Independent pass over the report draft:
  For every digit-bearing unit (paragraph, bullet, or table row):
    1. cites  = NR-### refs in the unit, with "NR-a to NR-b" ranges expanded;
    2. tokens = printed numbers, minus dates, commit pins, hex hashes, version
       strings, section/figure refs, script/doc paths, class labels
       (5 kW-class, 50-kilowatt), and letter+digit identifiers (S1, R6, slot 2,
       island 3, phase 1, post-95c385d_wind-authority, ...);
    3. every value token must equal a number in its unit's cited row(s) at the
       token's printed precision (decimal round-match, no float fuzz);
    4. units with digits but no cites are classed: heading / date / pin / ref /
       path / placeholder / class-label / exempt-stripped / OTHER.

Output: a per-unit audit trail plus the review lists (unmatched tokens;
no-cite units). Exit 0 always (this is a report, not a gate).

Usage: python3 sv_claim_audit.py <draft.md> <register.md>
"""
import hashlib
import re
import sys
from decimal import Decimal
from pathlib import Path

NR_RANGE = re.compile(r"NR-(\d+)\s+to\s+NR-(\d+)")
NR_REF = re.compile(r"NR-\d+")
DATE = re.compile(r"\d{4}-\d{2}-\d{2}")
HASH = re.compile(r"\b[0-9a-f]{7,40}\b")
VERSION = re.compile(r"\bv\d+(?:\.\d+)+\b")
CLASS = re.compile(r"\d+\s*kW-class|\d+-kilowatt")
PRD = re.compile(r"PRD\s+\d+(?::\d+)?")
EKFT = re.compile(r"\bEK_FT_\d+\b")
SHA = re.compile(r"SHA-\d+")
PATH = re.compile(r"[\w./-]*\b(?:scripts|docs|scratch|src|handovers)/[\w./-]+")
SEC = re.compile(r"§\d+(?:\.\d+)*")
SECT = re.compile(r"Sections?\s+\d+(?:\.\d+)?(?:\s+to\s+\d+(?:\.\d+)?)?")
FIGREF = re.compile(r"(?:figure-map\s+)?rows?\s+\d+(?:\s+and\s+\d+)?", re.IGNORECASE)
FIG = re.compile(r"Figure\s+\d+")
SLOT = re.compile(r"[Ss]lot\s+\d+")
ISLAND = re.compile(r"[Ii]slands?-?\s*\d+(?:\s+and\s+\d+)?")
PHASE = re.compile(r"[Pp]hases?\s+\d+(?:\s+to\s+\d+)?")
IDENT = re.compile(r"\b\w*[a-z]\d\w*\b", re.IGNORECASE)          # S1, R6, F3, bankderate2, post-95c385d
NUM = re.compile(r"\d+(?:\.\d+)?")
PLACEHOLDER = re.compile(r"\[[^\]]*(?:PENDING|need rows|requested|holds a register)[^\]]*\]", re.IGNORECASE)


def strip_spans(text):
    return re.sub(r"`[^`]*`", " ", text)


def units_of(lines):
    """Group draft lines into audit units: headings, paragraphs, bullets, table rows."""
    units, cur = [], []

    def flush():
        if cur:
            units.append(list(cur))
            cur.clear()

    for i, raw in enumerate(lines, 1):
        line = raw.rstrip("\n")
        if not line.strip():
            flush()
            continue
        if line.lstrip().startswith("|") or line.lstrip().startswith("#"):
            flush()
            units.append([(i, line)])
            continue
        if re.match(r"^\s*-\s", line):
            flush()
            cur.append((i, line))
            continue
        cur.append((i, line))
    flush()
    return units


def row_map(reg_lines):
    rows = {}
    for line in reg_lines:
        m = re.match(r"\|\s*(NR-\d+)(?:\s+ext)?\s*\|", line)
        if m:
            rows.setdefault(m.group(1), []).append(line)
    return rows


def row_numbers(row_text):
    t = strip_spans(row_text)
    t = NR_REF.sub(" ", t)
    return NUM.findall(t)


def is_signed(row_lines):
    joined = "\n".join(row_lines)
    return bool(re.search(r"(?<!un)signed", joined, re.IGNORECASE))


def match_token(tok, row_texts):
    dp = len(tok.split(".")[1]) if "." in tok else 0
    quant = Decimal(1).scaleb(-dp)
    val = Decimal(tok)
    for rt in row_texts:
        for num in row_numbers(rt):
            try:
                if Decimal(num).quantize(quant) == val:
                    return True
            except Exception:
                continue
    return False


def tokens_of(clean):
    t = clean
    for pat in (NR_RANGE, NR_REF, DATE, HASH, PATH, VERSION, CLASS, PRD, EKFT, SHA,
                SEC, SECT, FIGREF, FIG, SLOT, ISLAND, PHASE, IDENT):
        t = pat.sub(" ", t)
    return NUM.findall(t)


def main():
    draft = Path(sys.argv[1])
    register = Path(sys.argv[2])
    text = draft.read_text()
    lines = text.splitlines()
    reg_text = register.read_text()
    reg_lines = reg_text.splitlines()
    rows = row_map(reg_lines)

    print(f"draft   : {draft} md5 {hashlib.md5(text.encode()).hexdigest()}")
    print(f"register: {register} md5 {hashlib.md5(reg_text.encode()).hexdigest()}")
    print()

    signed = {r for r, ls in rows.items() if is_signed(ls)}
    cited_all = sorted(set(NR_REF.findall(text)), key=lambda r: int(r.split("-")[1]))
    missing = [r for r in cited_all if r not in signed]
    print(f"== cited rows: {len(cited_all)}; all signed: {not missing}")
    if missing:
        print("!! cited but missing/unsigned: " + ", ".join(missing))
    print()

    n_units = n_digit = 0
    with_cites = []
    nocite = []
    exempt = []
    unmatched = []

    for unit in units_of(lines):
        n_units += 1
        raw = " ".join(t for _, t in unit).strip()
        if not re.search(r"\d", raw):
            continue
        n_digit += 1
        first, last = unit[0][0], unit[-1][0]
        heading = all(t.lstrip().startswith("#") for _, t in unit)
        clean = strip_spans(raw)
        if heading:
            clean = re.sub(r"#+\s*\d+(?:\.\d+)*", "#", clean)

        cites = []
        for a, b in NR_RANGE.findall(clean):
            cites += [f"NR-{x:03d}" for x in range(int(a), int(b) + 1)]
        cites += [c for c in NR_REF.findall(clean) if c not in cites]
        cites = sorted(set(cites), key=lambda r: int(r.split("-")[1]))

        toks = tokens_of(clean)
        for ph in PLACEHOLDER.findall(clean):
            for tok in NUM.findall(ph):
                if tok in toks:
                    toks.remove(tok)

        if cites:
            row_texts = [ln for c in cites for ln in rows.get(c, [])]
            un = [tok for tok in toks if not match_token(tok, row_texts)]
            with_cites.append((first, last, raw, cites, toks, un))
            if un:
                unmatched.append((first, last, raw, cites, un))
            continue

        reasons = []
        if heading:
            reasons.append("heading")
        if PLACEHOLDER.search(clean) or "PENDING" in raw:
            reasons.append("placeholder")
        if DATE.search(clean):
            reasons.append("date")
        if HASH.search(clean):
            reasons.append("pin")
        if SEC.search(clean) or SECT.search(clean) or FIGREF.search(clean) or FIG.search(clean):
            reasons.append("ref")
        if PATH.search(clean):
            reasons.append("path")
        if CLASS.search(clean):
            reasons.append("class-label")
        if toks:
            reasons.append("OTHER" if not reasons else "token-remains")
        if not reasons:
            reasons.append("exempt-stripped")
        for r in reasons:
            if r in ("OTHER", "token-remains"):
                nocite.append((first, last, raw, toks, [x for x in reasons if True]))
                break
        else:
            exempt.append((first, last, raw, reasons))

    print(f"== units: {n_units}; digit-bearing: {n_digit}")
    print(f"== cited units: {len(with_cites)}; no-cite units: {len(nocite)} + exempt {len(exempt)}")
    tot = sum(len(u[4]) for u in with_cites)
    unm = sum(len(u[5]) for u in with_cites)
    print(f"== value tokens on cited units: {tot}; matched: {tot - unm}; unmatched: {unm}")
    print()

    print("== UNMATCHED TOKENS (review list) ==")
    for first, last, raw, cites, un in unmatched:
        print(f"L{first}-{last} | cites {','.join(cites)} | tokens {','.join(un)}")
        print(f"   {raw[:260]}")
    print()

    print("== NO-CITE UNITS WITH REMAINING TOKENS (review list) ==")
    for first, last, raw, toks, reasons in nocite:
        print(f"L{first}-{last} | {','.join(reasons)} | tokens {','.join(toks)}")
        print(f"   {raw[:260]}")
    print()

    print("== NO-CITE UNITS, EXEMPT CLASSES (listing) ==")
    for first, last, raw, reasons in exempt:
        print(f"L{first}-{last} | {','.join(reasons)} | {raw[:180]}")
    print()
    print("== AUDIT TRAIL (all cited units) ==")
    for first, last, raw, cites, toks, un in with_cites:
        flag = "UNMATCHED:" + ",".join(un) if un else "ok"
        print(f"L{first}-{last} | {','.join(cites)} | {len(toks)} tok | {flag}")


if __name__ == "__main__":
    main()

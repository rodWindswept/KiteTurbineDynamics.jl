#!/usr/bin/env python3
"""Per-sentence attribution probe: which sentences drive the STE offenders,
base vs candidate.  Imports ste-lint.py (dashed filename) by path."""
import importlib.util
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("stelint", ROOT / "ste-lint.py")
ste = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ste)


def report(path):
    raw = pathlib.Path(path).read_text()
    text = ste.strip_code(raw)
    sents = ste.sentences(text)
    longs = [s for s in sents if ste.wc(s) > 20]
    contr = re.findall(r"\b\w+['’](?:t|re|ve|ll|d|s|m)\b", text)
    passive = [m.group(0) for m in re.finditer(rf"\b{ste.BE}\s+(?:\w+ed|{ste.PP_IRREG})\b", text, re.I)]
    paras = [p for p in re.split(r"\n\s*\n", raw) if p.strip()]
    longs_par = [p.splitlines()[0][:70] for p in paras if len(ste.sentences(ste.strip_code(p))) > 6]
    r = ste.lint(raw)
    print(f"--- {pathlib.Path(path).name}: total={r['total']} per100w={r['total_per100w']} words={r['words']}")
    for k, v in r["violations"].items():
        if v:
            print(f"      {k}: {v}")
    print(f"      long sentences ({len(longs)}):")
    for s in longs:
        print(f"        [{ste.wc(s)}w] {s[:110]}")
    print(f"      contractions ({len(contr)}): {contr}")
    print(f"      passive ({len(passive)}): {passive}")
    print(f"      long paragraphs ({len(longs_par)}): {longs_par}")


for p in sys.argv[1:]:
    report(p)

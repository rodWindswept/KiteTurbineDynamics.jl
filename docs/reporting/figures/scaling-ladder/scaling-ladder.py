#!/usr/bin/python3
# -*- coding: utf-8 -*-
"""scaling-ladder: generating script for the close plate (the value track rungs).

Plate: docs/reporting/figures/scaling-ladder/SPEC.md (GENERATE stage, R2).
Draws the scaling ladder from the value-claims ledger section 4: the
validated rung (solid) and the six programme rungs above it (open plus
label), at equal spacing on a ladder frame.

The rung set comes from const RUNGS in scripts/compute_seeds.jl and the
class split from the ledger. Every drawn element resolves to its ledger
row. No register row binds this plate. No measured value prints and no
screen value prints. The plate is not a value axis.

Run:
  /usr/bin/python3 docs/reporting/figures/scaling-ladder/scaling-ladder.py \
      --script-commit <hex>

Toolchain pin: /usr/bin/python3 (CPython 3.12.x), matplotlib 3.10.x,
numpy 2.x. F-REPRO: svg.hashsalt set, SVG dc:date normalised, PDF
CreationDate pinned, no timestamps anywhere.

Outputs (in this directory): scaling-ladder.svg / .pdf / .png,
label-ledger.txt, manifest.json.
"""
from __future__ import annotations

import argparse
import html
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D
from matplotlib.patches import Rectangle

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[3]
LEDGER_MD = REPO / "docs" / "reporting" / "value-claims-ledger.md"
RUNGS_SRC = REPO / "scripts" / "compute_seeds.jl"
SLUG = "scaling-ladder"

DATA_COMMIT = "aa76367"          # the value-claims ledger v1 seed commit

INK = "#1a1a1a"
GREY = "#555555"
FAINT = "#777777"
RULE = "#333333"
BORDER = "#c9ced3"

RDASH = "\u2014"

TITLE = "The scaling ladder"
SUB = ("the rungs above the validated machine are programme targets, "
       "not results")

K1A = f"filled {RDASH} the validated rung: landed"
K1B = "the campaign dataset and the register back it"
K2A = f"open {RDASH} programme targets: forward-looking"
K2B = f"the plain label: programme target {RDASH} no repo artifact"
K3A = "Rungs sit at equal spacing. The plate is not a value scale."
K3B = "No screen value prints."

PLAIN_LABEL = f"programme target {RDASH} no repo artifact"

LEDGER: list[str] = []


def keep(s: str) -> str:
    LEDGER.append(s)
    return s


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def blob_eq(path: Path) -> bool:
    rel = path.relative_to(REPO).as_posix()
    head = subprocess.run(["git", "-C", str(REPO), "rev-parse",
                           f"HEAD:{rel}"], capture_output=True,
                          text=True).stdout.strip()
    work = subprocess.run(["git", "-C", str(REPO), "hash-object",
                           str(path)], capture_output=True,
                          text=True).stdout.strip()
    return bool(head) and head == work


def section_sha256(number: str) -> str:
    """Hash one ``## <number>.`` section of the ledger, not the whole file.

    Sliced from the heading line to the next ``## `` heading — the convention
    ``scripts/check_plate_bytes.py`` reads — so this plate is not reported
    stale every time an unrelated section of the ledger is edited. The plate
    binds section 4 only, and this is the hash that says so.
    """
    text = LEDGER_MD.read_text(encoding="utf-8")
    heads = list(re.finditer(r"^## (.+)$", text, re.M))
    for i, h in enumerate(heads):
        if h.group(1).split(".")[0].strip() == str(number):
            end = heads[i + 1].start() if i + 1 < len(heads) else len(text)
            return hashlib.sha256(text[h.start():end].encode("utf-8")).hexdigest()
    raise SystemExit(f"scaling-ladder: no section {number} in {LEDGER_MD}")


def parse_ledger(text: str):
    sec4 = text.split("## 4. The rungs, element by element")[1]
    sec4 = sec4.split("## 5.")[0]
    rows = []
    for ln in sec4.splitlines():
        m = re.match(
            r"\|\s*(\d+(?:\.\d+)?)\s*kW\s*\|\s*`([a-z]+)`\s*\|"
            r"(.*)\|\s*([a-z ]+?)\s*\|\s*$", ln)
        if m:
            rows.append({"kw": float(m.group(1)), "cls": m.group(2),
                         "ptr": m.group(3), "ink": m.group(4).strip()})
    pm = re.search(r"The code set reads ([0-9.,\s]+?)\s*kW", sec4)
    prose = [float(x) for x in pm.group(1).replace(" ", "").split(",")]
    return rows, prose


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--script-commit", default="uncommitted")
    ap.add_argument("--outdir", default=str(HERE))
    args = ap.parse_args()
    outdir = Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)

    # ---------------------------------------------------------------- inputs
    led_text = LEDGER_MD.read_text(encoding="utf-8")
    led_rows, led_prose = parse_ledger(led_text)

    fsrc = RUNGS_SRC.read_text(encoding="utf-8")
    fm = re.search(r"const RUNGS = \[([0-9.,\s]+?)\]", fsrc)
    rungs_f = [float(x) for x in fm.group(1).split(",")]
    rungs = [int(v) for v in rungs_f]

    # ------------------------------------------------- planned drawn strings
    val_labels = [f"{v} kW" for v in rungs]
    cls_labels = [("the validated rung" if r["cls"] == "capability"
                   else "programme target") for r in led_rows]
    st1 = ("source: the value-claims ledger, section 4 (v1 seed commit "
           f"{DATA_COMMIT}) \u00b7 the code set: scripts/compute_seeds.jl, "
           "const RUNGS")
    st2 = ("no register row binds this plate \u00b7 every drawn element "
           "resolves to the value-claims ledger \u00b7 script commit "
           f"{args.script_commit}")
    planned = [TITLE, SUB, *val_labels, *cls_labels,
               K1A, K1B, K2A, K2B, K3A, K3B, st1, st2]

    # ---------------------------------------------------------------- checks
    checks = []

    def chk(name, got, want):
        ok = got == want
        checks.append((name, got, want, ok))

    chk("the rung set (const RUNGS)", rungs_f,
        [5.0, 7.0, 10.0, 15.0, 25.0, 35.0, 50.0])
    chk("the ledger rung rows", len(led_rows), 7)
    chk("ledger values == the code set",
        [int(r["kw"]) for r in led_rows], rungs)
    chk("ledger classes", [r["cls"] for r in led_rows],
        ["capability"] + ["target"] * 6)
    chk("ledger ink classes", [r["ink"] for r in led_rows],
        ["solid"] + ["open plus label"] * 6)
    chk("plain label on every target row",
        all(PLAIN_LABEL in r["ptr"] for r in led_rows
            if r["cls"] == "target"), True)
    chk("the prose set line matches the table", led_prose, rungs_f)
    chk("drawn rung labels (integer kW forms)", val_labels,
        ["5 kW", "7 kW", "10 kW", "15 kW", "25 kW", "35 kW", "50 kW"])
    forms = {int(x) for x in re.findall(r"(\d+)\s*kW", " ".join(planned))}
    chk("no other kW form in the drawn set", sorted(forms), rungs)
    chk("no register-row token drawn",
        re.search(r"NR-\d", " ".join(planned)) is None, True)
    chk("no held-set token drawn (cost, carbon)",
        re.search(r"p/kWh|\u00a3|gCO2|MWh", " ".join(planned)) is None,
        True)
    chk("no proof-claim token drawn",
        re.search(r"proven|viable", " ".join(planned), re.I) is None,
        True)
    chk("blob check: the ledger matches HEAD", blob_eq(LEDGER_MD), True)
    chk("blob check: compute_seeds matches HEAD", blob_eq(RUNGS_SRC), True)

    n_fail = 0
    for name, got, want, ok in checks:
        if not ok:
            n_fail += 1
        print(f"check: {name}: {got}  "
              f"({'OK' if ok else 'OFF vs ' + str(want)})")
    if n_fail:
        print(f"in-script checks FAILED: {n_fail}", file=sys.stderr)
        return 1

    # ---------------------------------------------------------------- figure
    plt.rcParams.update({
        "font.size": 8,
        "svg.hashsalt": "ktd-fig-pin-2026-10-16",
        "svg.fonttype": "none",
        "pdf.fonttype": 42,
        "ps.fonttype": 42,
        "figure.facecolor": "white",
        "savefig.facecolor": "white",
    })

    fig = plt.figure(figsize=(7.6, 4.9))
    fig.text(0.012, 0.952, keep(TITLE), size=11, weight="bold", color=INK)
    fig.text(0.012, 0.912, keep(SUB), size=7.5, color=GREY)

    # the ladder: two rails, seven rungs, bottom to top
    XL, XR = 0.175, 0.335
    Y0, DY = 0.145, 0.108
    RH = 0.024
    ry = [Y0 + i * DY for i in range(7)]

    for x in (XL, XR):
        fig.add_artist(Line2D([x, x], [Y0 - 0.045, ry[-1] + 0.045],
                              transform=fig.transFigure, color=RULE,
                              lw=1.3, solid_capstyle="round"))

    for i, y in enumerate(ry):
        solid = i == 0
        fig.add_artist(Rectangle((XL - 0.008, y - RH / 2),
                                 (XR - XL) + 0.016, RH,
                                 transform=fig.transFigure,
                                 facecolor=INK if solid else "white",
                                 edgecolor=INK if solid else GREY,
                                 linewidth=0.8 if solid else 1.0,
                                 zorder=3))

    for i, y in enumerate(ry):
        fig.text(0.365, y, keep(val_labels[i]), size=8, color=INK,
                 va="center", ha="left")
        fig.text(0.425, y, keep(cls_labels[i]), size=8, color=GREY,
                 va="center", ha="left")

    # the key box: the ink rule
    boxx, boxy, boxw, boxh = 0.60, 0.475, 0.377, 0.36
    fig.add_artist(Rectangle((boxx, boxy), boxw, boxh,
                             transform=fig.transFigure, facecolor="white",
                             edgecolor=BORDER, linewidth=0.7))
    SW, SH = 0.018, 0.027
    fig.add_artist(Rectangle((boxx + 0.014, 0.775 - SH / 2), SW, SH,
                             transform=fig.transFigure, facecolor=INK,
                             edgecolor=INK, linewidth=0.7))
    fig.text(boxx + 0.040, 0.775, keep(K1A), size=7.2, color=INK,
             va="center")
    fig.text(boxx + 0.040, 0.732, keep(K1B), size=6.8, color=GREY,
             va="center")
    fig.add_artist(Rectangle((boxx + 0.014, 0.648 - SH / 2), SW, SH,
                             transform=fig.transFigure, facecolor="white",
                             edgecolor=GREY, linewidth=1.0))
    fig.text(boxx + 0.040, 0.648, keep(K2A), size=7.2, color=INK,
             va="center")
    fig.text(boxx + 0.040, 0.605, keep(K2B), size=6.8, color=GREY,
             va="center")
    fig.text(boxx + 0.014, 0.540, keep(K3A), size=6.5, color=FAINT,
             style="italic", va="center")
    fig.text(boxx + 0.014, 0.503, keep(K3B), size=6.5, color=FAINT,
             style="italic", va="center")

    fig.text(0.012, 0.050, keep(st1), size=6.5, color=FAINT)
    fig.text(0.012, 0.030, keep(st2), size=6.5, color=FAINT)

    # ---------------------------------------------------------------- save
    svg = outdir / f"{SLUG}.svg"
    pdf = outdir / f"{SLUG}.pdf"
    png = outdir / f"{SLUG}.png"
    fig.savefig(svg)
    fig.savefig(pdf, metadata={"Creator": f"{SLUG} \u00b7 KTD figures",
                               "CreationDate": None})
    fig.savefig(png, dpi=300)
    plt.close(fig)

    raw = svg.read_bytes()
    raw = re.sub(rb"<dc:date>[^<]*</dc:date>",
                 rb"<dc:date>1970-01-01T00:00:00</dc:date>", raw)
    svg.write_bytes(raw)

    ledger = sorted(set(LEDGER))
    (outdir / "label-ledger.txt").write_text("\n".join(ledger) + "\n",
                                             encoding="utf-8")

    found = {
        html.unescape(re.sub(r"<[^>]+>", "", m)).strip()
        for m in re.findall(r"<text[^>]*>(.*?)</text>", svg.read_text(),
                            flags=re.S)
    }
    missing = sorted(found - set(ledger))
    extra = sorted(set(ledger) - found)
    if missing or extra:
        print("F-LABEL self-check FAILED", file=sys.stderr)
        for s in missing:
            print(f"  in vector, not in ledger: {s!r}", file=sys.stderr)
        for s in extra:
            print(f"  in ledger, not in vector: {s!r}", file=sys.stderr)
        return 1

    manifest = {
        "slug": SLUG,
        "script": {"path": f"docs/reporting/figures/{SLUG}/{SLUG}.py",
                   "sha256": sha256(Path(__file__).resolve())},
        "toolchain": {
            "python": ".".join(str(v) for v in sys.version_info[:3]),
            "matplotlib": matplotlib.__version__,
            "numpy": __import__("numpy").__version__},
        "inputs": {
            "ledger": {"path": "docs/reporting/value-claims-ledger.md",
                       "sha256": sha256(LEDGER_MD), "section": "4",
                       "section_sha256": section_sha256("4")},
            "rung_set": {"path": "scripts/compute_seeds.jl",
                         "sha256": sha256(RUNGS_SRC), "const": "RUNGS"},
            "register_rows": [],
        },
        "binding": ("every drawn element resolves to the value-claims "
                    "ledger section 4; no register row binds this plate"),
        "data_commit": DATA_COMMIT,
        "script_commit": args.script_commit,
        "command": (f"/usr/bin/python3 docs/reporting/figures/{SLUG}/"
                    f"{SLUG}.py --script-commit {args.script_commit}"),
        "precision": ("the rung labels print integer kW forms from the "
                      "code set; no other number prints"),
        "outputs": {f"{SLUG}.svg": sha256(svg),
                    f"{SLUG}.pdf": sha256(pdf),
                    f"{SLUG}.png": sha256(png),
                    "label-ledger.txt": sha256(outdir / "label-ledger.txt")},
    }
    (outdir / "manifest.json").write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n",
        encoding="utf-8")
    print(f"written: {SLUG}.svg / .pdf / .png, label-ledger.txt "
          f"({len(ledger)} strings), manifest.json")
    print("F-LABEL self-check: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())

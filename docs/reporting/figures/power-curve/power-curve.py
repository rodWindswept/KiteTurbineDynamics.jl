#!/usr/bin/python3
# -*- coding: utf-8 -*-
"""power-curve: one fixed machine across a wind sweep.

Plate: docs/reporting/figures/power-curve/SPEC.md (SPEC v3, wind basis signed).
The sweep re-evaluates one genome at sixteen hub winds. The machine is held
fixed by cfg.v_rated = 11.0 (the rating is part of the machine, not the wind),
so the mass must print identical on every row. Below the 5 kW floor the
evaluator rejects the design and keeps the measured power: those points draw
as open markers and take no score.

Run:
  /usr/bin/python3 docs/reporting/figures/power-curve/\\
      power-curve.py --csv <sweep.csv> --script-commit <hex>

F-REPRO: svg.hashsalt set, SVG dc:date normalised, PDF CreationDate pinned,
no timestamps anywhere.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import html
import json
import re
import sys
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[3]
SLUG = "power-curve"

INK = "#1a1a1a"
GREY = "#555555"
FAINT = "#777777"
MUTED = "#98a0a8"
AMBER = "#c08a1e"

FLOOR = 5.0

TITLE = "The floor decides which winds this machine can score at"
SUB1 = ("one fixed machine at sixteen hub winds \u00b7 gain 2.24 \u00b7 "
        "hub 9.41 m \u00b7 identity point 11.0097 m/s")
SUB2 = ("open markers are measured below the 5 kW floor and take no score \u00b7 "
        "the machine does not move across the sweep")

LEDGER: list[str] = []


def keep(s: str) -> str:
    LEDGER.append(s)
    return s


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load(path: Path) -> tuple[list[dict], list[str]]:
    header_lines: list[str] = []
    body: list[str] = []
    with path.open(newline="", encoding="utf-8") as fh:
        for ln in fh:
            if ln.startswith("#"):
                header_lines.append(ln.rstrip("\n"))
            else:
                body.append(ln)
    return list(csv.DictReader(body)), header_lines


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--csv", required=True)
    ap.add_argument("--script-commit", default="uncommitted")
    ap.add_argument("--rows", default="pending")
    ap.add_argument("--outdir", default=str(HERE))
    args = ap.parse_args()

    outdir = Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)
    src = Path(args.csv)
    rows, header_lines = load(src)

    for r in rows:
        r["w"] = float(r["wind_mps"])
        r["pe"] = float(r["P_end_kW"])
        r["pm"] = float(r["P_mean_kW"])
        r["mass"] = float(r["mass_kg"])
    rows.sort(key=lambda r: r["w"])
    ok = [r for r in rows if r["status"] == "ok"]
    bad = [r for r in rows if r["status"] != "ok"]

    checks: list[tuple[str, object, object, bool]] = []

    def chk(name, got, want) -> None:
        if isinstance(got, float) and isinstance(want, float):
            good = abs(got - want) <= 1e-9
        elif isinstance(got, list) and isinstance(want, list):
            good = (len(got) == len(want)
                    and all(abs(float(a) - float(b)) <= 6e-4
                            for a, b in zip(got, want)))
        else:
            good = got == want
        checks.append((name, got, want, good))

    chk("rows in the sweep", len(rows), 16)
    chk("distinct hub winds", len({round(r["w"], 6) for r in rows}), 16)
    chk("status split (ok, rejected)", [len(ok), len(bad)], [7, 9])
    chk("mass constant across the sweep (kg, 6 dp)",
        [round(r["mass"], 6) for r in rows], [25.698468] * len(rows))
    chk("no ok row below the floor", min(r["pe"] for r in ok) >= FLOOR, True)
    chk("every rejected row sits below the floor",
        max(r["pe"] for r in bad) < FLOOR, True)
    # The identity row must reproduce the campaign's recorded score.
    ident = [r for r in rows if abs(r["w"] - 11.00969423693896) < 1e-6]
    chk("identity row present", len(ident), 1)
    if ident:
        chk("identity fitness == recorded 27.363541266349",
            float(ident[0]["fitness_kg_eq"]), 27.363541266349)
    # Unclamped evidence: P_end / v^3 constant across the ok rows.
    ratios = [r["pe"] / r["w"] ** 3 for r in ok]
    spread = (max(ratios) - min(ratios)) / max(ratios)
    chk("P_end / v^3 spread across ok rows < 0.5 %", spread < 0.005, True)
    # Fields that close the record chain, when the CSV carries them.
    for col, want in (("v_rated", "11.0"), ("h_ref_m", "9.411699"),
                      ("k_mppt", "2.24")):
        if rows and col in rows[0]:
            chk(f"{col} constant ({want})", sorted({r[col] for r in rows}),
                [want])
    if rows and "gene_sha256" in rows[0]:
        chk("genome hash constant", len({r["gene_sha256"] for r in rows}), 1)
    if rows and "rep" in rows[0]:
        reps = {}
        for r in rows:
            if r["rep"] not in ("", "1"):
                reps.setdefault(round(r["w"], 6), []).append(r["pe"])
        chk("repeat spreads (kW)", sorted(
            round(max(v) - min(v), 9) for v in reps.values()), [0.0] * len(reps))

    n_fail = sum(1 for *_, good in checks if not good)
    for name, got, want, good in checks:
        print(f"check: {name}: {got} vs {want}  ({'OK' if good else 'FAIL'})")
    if n_fail:
        print(f"in-script checks FAILED: {n_fail}", file=sys.stderr)
        return 1

    # ------------------------------------------------------------------ draw
    plt.rcParams.update({
        "svg.hashsalt": "ktd-fig-pin-2026-10-20",
        "svg.fonttype": "none",
        "pdf.fonttype": 42,
        "ps.fonttype": 42,
    })
    fig = plt.figure(figsize=(7.6, 4.7))
    ax = fig.add_axes([0.088, 0.285, 0.895, 0.515])

    fig.text(0.012, 0.955, keep(TITLE), size=11.5, color=INK, weight="medium")
    fig.text(0.012, 0.905, keep(SUB1), size=7.6, color=GREY)
    fig.text(0.012, 0.872, keep(SUB2), size=7.6, color=FAINT)

    ax.axhline(FLOOR, color=AMBER, lw=1.0, zorder=1)
    ax.text(13.62, FLOOR - 0.42, keep("5 kW floor: a gate, not a target"),
            ha="right", va="top", size=7, color=AMBER)

    xs = [r["w"] for r in rows]
    ys = [r["pe"] for r in rows]
    ax.plot(xs, ys, color=INK, lw=0.9, zorder=2)

    ok_x = [r["w"] for r in ok]
    ok_y = [r["pe"] for r in ok]
    bad_x = [r["w"] for r in bad]
    bad_y = [r["pe"] for r in bad]
    ax.plot(bad_x, bad_y, "o", ms=4.0, mfc="white", mec=INK, mew=0.9, zorder=3)
    ax.plot(ok_x, ok_y, "o", ms=4.0, mfc=INK, mec=INK, mew=0.9, zorder=3)

    # Every marker prints its power, except the pair at 11.0 and 11.0097,
    # which carry one two-line block because they sit two pixels apart.
    for r in rows:
        if abs(r["w"] - 11.0) < 1e-9 or abs(r["w"] - 11.00969423693896) < 1e-6:
            continue
        ax.annotate(keep(f"{r['pe']:.2f}"), (r["w"], r["pe"]),
                    textcoords="offset points", xytext=(0, 4.5),
                    ha="center", va="bottom", size=6.4, color=GREY)

    pair_y = max(r["pe"] for r in rows
                 if abs(r["w"] - 11.0) < 1e-9
                 or abs(r["w"] - 11.00969423693896) < 1e-6)
    ax.annotate(keep("11.0 m/s: 5.30\n11.0097 m/s: 5.31"),
                (11.0048, pair_y), textcoords="offset points",
                xytext=(-18, 26), ha="right", va="bottom", size=6.4,
                color=GREY,
                arrowprops=dict(arrowstyle="-", color=MUTED, lw=0.6,
                                shrinkA=1, shrinkB=2))

    ax.set_xlim(6.15, 13.75)
    ax.set_ylim(0.0, 10.8)
    ax.set_xticks([7, 8, 9, 10, 11, 12, 13])
    for t in ax.get_xticklabels() + ax.get_yticklabels():
        keep(t.get_text())
    ax.set_xlabel(keep("hub wind (m/s) at 9.41 m \u00b7 one evaluation per wind"),
                  size=8, color=GREY, labelpad=6)
    ax.set_ylabel(keep("window-end power (kW)"),
                  size=8, color=GREY, labelpad=6)
    for sp in ("top", "right"):
        ax.spines[sp].set_visible(False)
    for sp in ("left", "bottom"):
        ax.spines[sp].set_color(MUTED)
        ax.spines[sp].set_linewidth(0.8)
    ax.tick_params(labelsize=7.5, colors=GREY, length=2.5)
    ax.set_axisbelow(True)
    ax.yaxis.grid(True, color="#e8e8e8", lw=0.6)

    fig.text(0.012, 0.170,
             keep("one polyline, no fit, no extrapolation \u00b7 the ends of the "
                  "sweep are chosen, not machine limits"),
             size=7, color=FAINT, style="italic")
    commit = args.script_commit
    cache = hashlib.sha256(src.read_bytes()).hexdigest()
    fig.text(0.012, 0.112,
             keep(f"sources: the winner genome, bankderate2 island 3 gen 26 "
                  f"\u00b7 sweep CSV sha256 {cache[:12]}\u2026 \u00b7 "
                  f"script commit {commit}"),
             size=6.8, color=FAINT)
    fig.text(0.012, 0.068,
             keep(f"rows {args.rows} \u00b7 rated wind held at 11.0 across the "
                  "sweep \u00b7 open markers are the honest floor reject"),
             size=6.8, color=FAINT)

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
    # Multiline annotations arrive as separate <text> spans; compare on lines.
    found = {ln.strip() for t in found for ln in t.split("\n") if ln.strip()}
    ledger_set = {ln.strip() for t in ledger for ln in t.split("\n") if ln.strip()}
    missing = sorted(ledger_set - found)
    extra = sorted(found - ledger_set)
    if missing or extra:
        print("F-LABEL self-check FAILED", file=sys.stderr)
        for s in missing:
            print(f"  in ledger, not in vector: {s!r}", file=sys.stderr)
        for s in extra:
            print(f"  in vector, not in ledger: {s!r}", file=sys.stderr)
        return 1

    print(f"ledger strings: {len(ledger)}")
    print(f"outputs sha256: png {sha256(png)}")
    print(f"                svg {sha256(svg)}")
    print(f"                pdf {sha256(pdf)}")
    print("F-LABEL self-check: OK")
    print(f"written: {outdir}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

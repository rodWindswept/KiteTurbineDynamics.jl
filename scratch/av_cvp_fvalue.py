#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""av_cvp_fvalue.py — F-VALUE counter-read for the convergence kit (figure-map row 16).

The figures seat's handoff: "F-VALUE at the sign-off commit when you take it;
the ledger carries every drawn string (34)."  SPEC v1: "@aero-validator owns
this check, at the sign-off commit.  No tolerance widening."

Fast census (this mode):
  P  pins      — recompute every manifest pin; kit blob identity; stamp objects
  L  F-LABEL   — independent census of the SVG text layer against the ledger
  V  F-VALUE   — every drawn value against its signed row at the stated precision,
                 recomputed from the committed telemetry with the stdlib only
  G  geometry  — the drawn marks inverted through the tick transforms
  S  sweep     — status strings and stale tokens across the delivered bytes

Repro mode (--repro): two fresh out-of-tree generator runs, byte-compared to the
committed set (the F-REPRO counter-read).  Logs: av_cvp_fvalue.log, av_cvp_repro.log.

Read tip: set by the caller's shell (log header).  Kit bytes pinned at 2361771.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import html
import json
import re
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
KIT = REPO / "docs/reporting/figures/convergence"
SCRATCH = REPO / "scratch"
EXTRACT = SCRATCH / "av_conv_series.csv"
RUN_DIR = (REPO / "scripts" / "results"
           / "v13_5kw_masslift_len18.8_rotorcount_bankderate2")
REGISTER = REPO / "docs/reporting/numbers-register.md"

PIN_COMMIT = "2361771"     # the kit's landing (bytes pinned)
SCRIPT_COMMIT = "0db99ac"
DATA_COMMIT = "dd3cc6a"
RUN_COMMIT = "a76c5e9"
ERA = "post-95c385d_wind-authority"

KIT_FILES = ["SPEC.md", "convergence.py", "convergence.svg", "convergence.pdf",
             "convergence.png", "label-ledger.txt", "manifest.json",
             "checks.log", "captions-draft.md", "register-status.md"]

FILLS = [("#3a7d44", "feasible"), ("#b32222", "clearance"), ("#c65f1c", "twist"),
         ("#dfa72f", "floor"), ("#7a5ba6", "fos"), ("#9aa0a6", "unlogged")]
ISL_COLORS = {1: "#4a7fb5", 2: "#2e8b57", 3: "#c1441e"}

CHECKS: list[tuple[str, bool, str]] = []


def chk(name: str, ok: bool, detail: str = "") -> None:
    CHECKS.append((name, bool(ok), detail))
    print(f"check: {name}: {detail}  ({'OK' if ok else 'OFF'})")


def git(*args: str) -> str:
    out = subprocess.run(["git", *args], cwd=REPO, capture_output=True,
                         text=True, check=False)
    if out.returncode != 0:
        raise RuntimeError(f"git {' '.join(args)}: {out.stderr.strip()}")
    return out.stdout.strip()


def git_ok(*args: str) -> str:
    out = subprocess.run(["git", *args], cwd=REPO, capture_output=True,
                         text=True, check=False)
    return out.stdout.strip()


def sha256(p: Path) -> str:
    return hashlib.sha256(p.read_bytes()).hexdigest()


def md5(p: Path) -> str:
    return hashlib.md5(p.read_bytes()).hexdigest()


def load_csv(path: Path) -> list[dict]:
    with path.open(newline="", encoding="utf-8") as fh:
        lines = [ln for ln in fh if not ln.startswith("#")]
    return list(csv.DictReader(lines))


def classify(r: dict) -> str:
    s = r["status"]
    if s == "ok":
        return "feasible"
    if s == "clearance_reject":
        return "clearance"
    if s == "reject_twist":
        return "twist"
    if s == "reject":
        p = float(r["P_mean"])
        fos = float(r["FoS"])
        if p == 0.0 and fos == float("inf"):
            return "unlogged"
        if 0.0 < p < 5.0:
            return "floor"
        if p >= 5.0 and fos < 2.5:
            return "fos"
    raise ValueError(f"unclassified row: {r}")


def best_so_far(rows: list[dict]) -> dict[int, tuple[float, int, int]]:
    ok = [(int(r["gen"]), int(r["idx"]), float(r["fitness"]))
          for r in rows if r["status"] == "ok"]
    out = {}
    for g in range(31):
        cand = [(f, gg, i) for (gg, i, f) in ok if gg <= g]
        out[g] = min(cand)
    return out


def register_row(rid: str) -> str:
    text = REGISTER.read_text(encoding="utf-8")
    m = re.search(r"^\| " + re.escape(rid) + r" \|.*$", text, re.M)
    return m.group(0) if m else ""


def pooled_counts(tele: dict) -> tuple[dict, dict, dict, list]:
    pooled, per_isl, per_gen = {}, {}, {g: {} for g in range(31)}
    bunk = []
    for i in (1, 2, 3):
        cnt = {}
        for r in tele[i]:
            g, k = int(r["gen"]), classify(r)
            cnt[k] = cnt.get(k, 0) + 1
            per_gen[g][k] = per_gen[g].get(k, 0) + 1
            pooled[k] = pooled.get(k, 0) + 1
            if k == "fos":
                bunk.append((i, int(r["gen"]), int(r["idx"]),
                             float(r["P_mean"]), float(r["FoS"])))
        per_isl[i] = cnt
    return pooled, per_isl, per_gen, bunk


# ----------------------------------------------------------------- fast census

def pins() -> None:
    # P1 kit blob identity
    branch = git("rev-parse", "--abbrev-ref", "HEAD")
    same = 0
    for f in KIT_FILES:
        rel = f"docs/reporting/figures/convergence/{f}"
        w = git("hash-object", rel)
        h = git("rev-parse", f"HEAD:{rel}")
        o = git("rev-parse", f"origin/{branch}:{rel}")
        if w == h == o:
            same += 1
    chk("P1 kit blob identity (worktree == HEAD == origin)",
        same == len(KIT_FILES), f"{same} of {len(KIT_FILES)}")

    # P2 no kit or map drift since the landing
    drift = git_ok("log", "--format=%h", f"{PIN_COMMIT}..HEAD", "--",
                   "docs/reporting/figures/convergence/",
                   "docs/reporting/figures/figure-map.md")
    chk("P2 no kit or map drift since 2361771", drift == "",
        f"{len(drift.split())} commits" if drift else "0 commits")

    man = json.loads((KIT / "manifest.json").read_text(encoding="utf-8"))

    # P3 script pin and source commit
    s_pin = man["script"]["sha256"] == sha256(KIT / "convergence.py")
    s_commit = git("log", "-1", "--format=%h", "--",
                   "docs/reporting/figures/convergence/convergence.py")
    chk("P3 script pin (sha256 + source commit)",
        s_pin and s_commit == SCRIPT_COMMIT,
        f"sha256 {'equal' if s_pin else 'OFF'}, source commit {s_commit}")

    # P4 input pins
    ins = {e["path"]: e["sha256"] for e in man["inputs"]["extracts"]}
    inp_ok = sum(1 for p, want in ins.items() if sha256(REPO / p) == want)
    chk("P4 input pins (4 records)", inp_ok == 4, f"{inp_ok} of 4")

    # P5 output pins
    out_ok = sum(1 for name, want in man["outputs"].items()
                 if sha256(KIT / name) == want)
    chk("P5 output pins (4 artifacts)", out_ok == 4, f"{out_ok} of 4")

    # P6 md5 block on the register-status note
    note = (KIT / "register-status.md").read_text(encoding="utf-8")
    md5_pins = re.findall(r"^\| ([\w.\-]+) \| ([0-9a-f]{32}) \|$", note, re.M)
    md_ok = sum(1 for f, want in md5_pins if md5(KIT / f) == want)
    chk("P6 register-status md5 block", md_ok == len(md5_pins) == 5,
        f"{md_ok} of {len(md5_pins)}")

    # P7 toolchain pins
    import matplotlib
    import numpy
    tc = man["toolchain"]
    ok = (tc["python"] == ".".join(str(v) for v in sys.version_info[:3])
          and tc["matplotlib"] == matplotlib.__version__
          and tc["numpy"] == numpy.__version__)
    chk("P7 toolchain pins", ok,
        f"python {sys.version_info[0]}.{sys.version_info[1]}.{sys.version_info[2]}, "
        f"mpl {matplotlib.__version__}, numpy {numpy.__version__}")

    # P8 stamp objects resolve, and the span carries no src drift
    d_subj = git("log", "-1", "--format=%s", DATA_COMMIT)
    r_subj = git("log", "-1", "--format=%s", RUN_COMMIT)
    src_drift = git_ok("log", "--format=%h", f"{RUN_COMMIT}..{DATA_COMMIT}", "--", "src/")
    ok = ("bankderate2" in d_subj and "masslift results" in d_subj
          and "post-95c385d_wind-authority" in r_subj
          and src_drift == "")
    chk("P8 stamp objects resolve (data, run, src-still span)",
        ok, f"data '{d_subj[:40]}...', run era match, src drift 0")

    # P9 cite surfaces on the delivered bytes
    ledger = (KIT / "label-ledger.txt").read_text(encoding="utf-8")
    stamp1 = ("sources: the campaign telemetry, islands 1 to 3 \u00b7 the "
              "convergence series extract \u00b7 data commit dd3cc6a \u00b7 run a76c5e9")
    stamp2 = ("rows NR-002 \u00b7 NR-003 \u00b7 NR-004 \u00b7 NR-005 \u00b7 NR-006 "
              "\u00b7 NR-036 \u00b7 NR-054 \u00b7 NR-055 \u00b7 script commit 0db99ac")
    era_line = ("the campaign across generations 0 to 30 \u00b7 era "
                "post-95c385d_wind-authority")
    ok = stamp1 in ledger and stamp2 in ledger and era_line in ledger
    chk("P9 cite surfaces (stamps, rows, era)", ok,
        "both stamps present" if ok else "OFF")

    # P9b the drawn era equals the raw telemetry header era
    tele_head = "".join(l for l in (RUN_DIR / "island_1" / "telemetry.csv")
                        .read_text(encoding="utf-8").splitlines(True)
                        if l.startswith("#"))
    m = re.search(r"era=(\S+)\s+git=([0-9a-f]{40})", tele_head)
    ok = bool(m) and m.group(1) == ERA and m.group(2).startswith(RUN_COMMIT)
    chk("P9b drawn era == telemetry header era", ok,
        f"era={m.group(1) if m else '?'} git={m.group(2)[:7] if m else '?'}")

    # P10 NR-054 blob cross-refs
    b1 = git("hash-object", "scratch/av_conv_series.csv")
    b2 = git("hash-object", "scratch/av_conv_series.py")
    b3 = git("hash-object", "scratch/av_conv_series.log")
    ok = (b1.startswith("9666b1ad") and b2.startswith("b8c52694")
          and b3.startswith("98103246"))
    chk("P10 NR-054 blob cross-refs", ok, f"{b1[:8]} / {b2[:8]} / {b3[:8]}")


def label_census(svg_text: str) -> None:
    nodes = re.findall(r"<text([^>]*)>(.*?)</text>", svg_text, re.S)
    strings = [html.unescape(re.sub(r"<[^>]+>", "", inner)).strip()
               for _, inner in nodes]
    ledger = [s for s in (KIT / "label-ledger.txt").read_text(
        encoding="utf-8").split("\n") if s]
    dsvg, dled = set(strings), set(ledger)
    chk("L1 text layer set-equal to the ledger",
        len(nodes) == 39 and len(ledger) == 34 and dsvg == dled,
        f"{len(nodes)} nodes, {len(dsvg)} distinct, both ways")
    from collections import Counter
    dupes = {k: v for k, v in Counter(strings).items() if v > 1}
    chk("L2 duplicate census (shared tick numerals)",
        dupes == {"0": 2, "10": 2, "20": 2, "30": 3}, str(dupes))
    chk("L3 ledger is the sorted unique set", ledger == sorted(set(ledger)),
        f"{len(ledger)} strings")


def value_checks() -> None:
    tele = {i: load_csv(RUN_DIR / f"island_{i}" / "telemetry.csv")
            for i in (1, 2, 3)}
    extract = load_csv(EXTRACT)
    ex = {i: {int(r["gen"]): (float(r["best_fitness"]),
                              int(r["best_source_gen"]),
                              int(r["best_source_idx"])) for r in extract
              if int(r["island"]) == i} for i in (1, 2, 3)}

    pooled, per_isl, per_gen, bunk = pooled_counts(tele)

    mix = [pooled.get("feasible", 0),
           pooled.get("floor", 0) + pooled.get("fos", 0) + pooled.get("unlogged", 0),
           pooled.get("clearance", 0), pooled.get("twist", 0)]
    row2 = register_row("NR-002")
    chk("V1 status mix vs NR-002", mix == [508, 301, 110, 11]
        and "508 ok / 301 reject / 110 clearance_reject / 11 reject_twist" in row2,
        str(mix))

    split = [pooled.get("floor", 0), len(bunk), pooled.get("unlogged", 0)]
    row55 = register_row("NR-055")
    ok = (split == [96, 4, 201] and "reads 301" in row55
          and "5 kW floor: 96" in row55 and "below 2.5: 4" in row55
          and "not logged: 201" in row55)
    chk("V2 reject split vs NR-055", ok, str(split))

    fos_in_floor = sum(1 for r in tele[1] + tele[2] + tele[3]
                       if classify(r) == "floor" and float(r["FoS"]) < 2.5)
    chk("V3 floor-first overlap (NR-055 basis: 34 of 96)",
        fos_in_floor == 34, f"{fos_in_floor} of 96")

    ok_i = [per_isl[i].get("feasible", 0) for i in (1, 2, 3)]
    rej_i = [per_isl[i].get("floor", 0) + per_isl[i].get("fos", 0)
             + per_isl[i].get("unlogged", 0) for i in (1, 2, 3)]
    clr_i = [per_isl[i].get("clearance", 0) for i in (1, 2, 3)]
    tw_i = [per_isl[i].get("twist", 0) for i in (1, 2, 3)]
    chk("V4 per-island ok [152, 162, 194]",
        ok_i == [152, 162, 194] and sum(ok_i) == 508, str(ok_i))
    chk("V5 per-island reject / clearance / twist",
        rej_i == [108, 111, 82] and clr_i == [47, 35, 28] and tw_i == [3, 2, 6],
        f"{rej_i} / {clr_i} / {tw_i}")

    got = sorted((i, g, x) for (i, g, x, _, _) in bunk)
    reads = [round(v, 2) for (_, _, _, p, f) in sorted(bunk) for v in (p, f)]
    chk("V6 subgroup-B rows and reads",
        got == [(1, 6, 7), (3, 5, 8), (3, 14, 8), (3, 22, 2)]
        and reads == [5.47, 2.27, 5.15, 1.61, 5.72, 1.25, 5.68, 0.42],
        f"{got}")

    tot_ok = (len(per_gen) == 31 and all(sum(per_gen[g].values()) == 30
                                         for g in per_gen))
    chk("V7 per-generation totals (31 x 30)",
        tot_ok and sum(pooled.values()) == 930, "930 designs")

    bands = [sum(per_gen[g].get("feasible", 0) for g in [0]),
             sum(per_gen[g].get("feasible", 0) for g in range(1, 11)),
             sum(per_gen[g].get("feasible", 0) for g in range(11, 21)),
             sum(per_gen[g].get("feasible", 0) for g in range(21, 31))]
    chk("V8 feasible by band [3, 26, 196, 283]", bands == [3, 26, 196, 283],
        str(bands))

    # V9 the extract reproduces from raw telemetry on the strip rule
    mism, maxdev, round_bad = 0, 0.0, 0
    for i in (1, 2, 3):
        rec = best_so_far(tele[i])
        for g in range(31):
            val, sg, si = ex[i][g]
            rv, rg, ri = rec[g]
            dev = abs(val - rv)
            maxdev = max(maxdev, dev)
            if not (dev <= 6e-4 and sg == rg and si == ri):
                mism += 1
            if round(rv, 3) != val:
                round_bad += 1
    chk("V9 series parity (93 rows, rule recompute)",
        mism == 0 and round_bad == 0,
        f"0 mismatches, 0 rounding gaps, max |dev| {maxdev:.2e}")

    seed = [ex[i][0][0] for i in (1, 2, 3)]
    finals = [ex[1][30][0], ex[2][30][0], ex[3][26][0]]
    holds = set(ex[3][g][0] for g in range(26, 31)) == {27.364}
    row3, row4 = register_row("NR-003"), register_row("NR-004")
    row5, row6 = register_row("NR-005"), register_row("NR-006")
    ok = (seed == [36.109, 36.109, 36.109]
          and finals == [30.578, 30.637, 27.364]
          and holds
          and "30.578" in row3 and "30.637" in row4
          and "27.364 (found gen 26)" in row5
          and "36.109 (gen 1, common seed)" in row6)
    chk("V10 seed / finals / hold vs NR-003 to NR-006", ok, f"{finals}")

    last1 = [ex[1][29][0], ex[1][30][0]]
    last2 = [ex[2][29][0], ex[2][30][0]]
    chk("V11 island last steps", last1 == [31.018, 30.578]
        and last2 == [31.085, 30.637], f"{last1} / {last2}")

    miles = [ex[3][g][0] for g in (0, 6, 10, 18, 22, 25, 26)]
    row36 = register_row("NR-036")
    ok = (miles == [36.109, 32.293, 31.661, 30.929, 29.854, 28.315, 27.364]
          and "32.293 (gen 6)" in row36 and "28.315 (gen 25)" in row36)
    chk("V12 NR-036 milestones 7 of 7", ok, str(miles))

    # V13 legend strings to rows, both directions
    led = (KIT / "label-ledger.txt").read_text(encoding="utf-8")
    ok = ("feasible (508)" in led
          and "rejected: rotor below 1.5 m clearance (110)" in led
          and "rejected: twist past the crossing limit (11)" in led
          and "rejected: power below the 5 kW floor (96)" in led
          and "rejected: FoS below 2.5 (4)" in led
          and "rejected: cause not logged (201)" in led
          and 96 + 4 + 201 == 301)
    chk("V13 legend counts to rows (direction; sum 301)", ok, "6 labels")

    # V14 seed and winner strings, right row each
    ok = ("the common seed \u00b7 36.109" in led
          and "the campaign winner \u00b7 27.364" in led)
    chk("V14 seed and winner label forms", ok, "no inversion")

    # V15 caption tier
    cap = (KIT / "captions-draft.md").read_text(encoding="utf-8")
    ok = ("30.578" in cap and "30.637" in cap and "27.364" in cap
          and "36.109" in cap and "(NR-003,\nNR-004)" in cap
          and "to 30.578 and 30.637" in cap)
    chk("V15 caption tier finals (NR-003, NR-004)", ok, "both print")

    # V16 checks.log census
    clog = (KIT / "checks.log").read_text(encoding="utf-8")
    n_chk = clog.count("\ncheck: ") + clog.startswith("check: ")
    ok = (n_chk == 22 and "OFF" not in clog and "FAILED" not in clog
          and clog.rstrip().endswith("F-LABEL self-check: OK"))
    chk("V16 checks.log census (22 checks, 0 fail)", ok, f"{n_chk} checks")


def geometry_checks(svg_text: str) -> None:
    def uses():
        out = []
        for m in re.finditer(r"<use[^>]*x=\"([\d.]+)\"[^>]*y=\"([\d.]+)\"[^>]*"
                             r"style=\"([^\"]*)\"", svg_text):
            out.append((float(m.group(1)), float(m.group(2)), m.group(3)))
        return out

    def texts():
        out = []
        for attrs, inner in re.findall(r"<text([^>]*)>(.*?)</text>", svg_text, re.S):
            s = html.unescape(re.sub(r"<[^>]+>", "", inner)).strip()
            x = re.search(r"x=\"([\d.]+)\"", attrs)
            y = re.search(r"y=\"([\d.]+)\"", attrs)
            st = re.search(r"style=\"([^\"]*)\"", attrs)
            out.append((float(x.group(1)) if x else None,
                        float(y.group(1)) if y else None, s,
                        st.group(1) if st else ""))
        return out

    U, T = uses(), texts()

    def tick_map_x(uy):
        return sorted(x for x, y, _ in U if abs(y - uy) < 0.01 and x > 60)

    x1s = tick_map_x(273.024)          # panel-1 x ticks, values 0..30 step 5
    x2s = tick_map_x(489.168)          # panel-2 x ticks, values 0..30 step 5
    y1u = sorted((y for x, y, _ in U if abs(x - 57.456) < 0.01 and 60 < y < 280),
                 reverse=True)         # panel-1 y ticks, values 0,10,20,30
    y2u = sorted((y for x, y, _ in U if abs(x - 57.456) < 0.01 and 360 < y < 490),
                 reverse=True)         # panel-2 y ticks, values 26..36
    ok = (len(U) == 25 and len(x1s) == 7 and len(x2s) == 7
          and len(y1u) == 4 and len(y2u) == 6)
    sx1 = (x1s[-1] - x1s[0]) / 30.0
    sx2 = (x2s[-1] - x2s[0]) / 30.0
    sy1 = (y1u[0] - y1u[-1]) / 30.0
    sy2 = (y2u[0] - y2u[-1]) / 10.0

    pairs_ok = 0
    want1 = [0, 5, 10, 15, 20, 25, 30]
    want2 = [26, 28, 30, 32, 34, 36]
    for x, v in zip(x2s, want1):
        cand = [s for tx, ty, s, _ in T if abs(tx - x) < 0.01
                and abs(ty - 500.49) < 4]
        pairs_ok += bool(cand and cand[0] == str(v))
    for y, v in zip(y1u, [0, 10, 20, 30]):
        cand = [s for tx, ty, s, _ in T if abs(tx - 51.456) < 0.01
                and abs(ty - y) < 4]
        pairs_ok += bool(cand and cand[0] == str(v))
    for y, v in zip(y2u, want2):
        cand = [s for tx, ty, s, _ in T if abs(tx - 51.456) < 0.01
                and abs(ty - y) < 4]
        pairs_ok += bool(cand and cand[0] == str(v))
    no_label = not any(276 < ty < 293 for _, ty, _, _ in T)
    chk("G1 tick numerals match their sources",
        ok and pairs_ok == 17 and no_label,
        f"{pairs_ok} of 17 pairings; panel-1 x carries no labels")

    def inv_x(x, x0, sx):
        return (x - x0) / sx

    def inv_y2(y):
        return 26.0 + (y2u[0] - y) / sy2

    # G2 star exactly at (gen 26, 27.364)
    star = [(x, y) for x, y, st in U if "#c1441e" in st]
    ok = len(star) == 1
    gx, gy = star[0]
    dg = abs(inv_x(gx, x2s[0], sx2) - 26)
    dv = abs(inv_y2(gy) - 27.364)
    chk("G2 star inverts to (26, 27.364)", ok and dg < 0.01 and dv < 0.01,
        f"|dgen| {dg:.2e}, |dvalue| {dv:.2e}")

    # G3 label x anchors invert to their data slots
    seed = [t for t in T if t[2] == "the common seed \u00b7 36.109"][0]
    win = [t for t in T if t[2] == "the campaign winner \u00b7 27.364"][0]
    isl = {t[2]: t for t in T if t[2] in ("island 1", "island 2", "island 3")}
    devs = [
        abs(seed[0] - (x2s[0] + 0.2 * sx2)),
        abs(win[0] - (x2s[0] + 25.4 * sx2)),
        abs(isl["island 1"][0] - (x2s[0] + 9.0 * sx2)),
        abs(isl["island 2"][0] - (x2s[0] + 3.9 * sx2)),
        abs(isl["island 3"][0] - (x2s[0] + 14.0 * sx2)),
    ]
    chk("G3 label x anchors invert to their data slots", max(devs) < 0.01,
        f"max |dev| {max(devs):.2e} px")

    # G3b baseline offsets fit the anchor modes
    def map_y2(v):
        return y2u[0] - (v - 26.0) * sy2
    d_seed = map_y2(36.42) - seed[1]          # va=bottom: baseline above the slot
    d_win = win[1] - map_y2(26.95)            # va=center: baseline below the centre
    d_i1 = isl["island 1"][1] - map_y2(34.4)
    d_i2 = isl["island 2"][1] - map_y2(33.6)
    d_i3 = isl["island 3"][1] - map_y2(32.25)
    ok = (0.5 < d_seed < 3.5 and 0.5 < d_win < 3.5
          and all(0.5 < d < 3.5 for d in (d_i1, d_i2, d_i3)))
    chk("G3b baseline offsets fit the anchor modes", ok,
        f"seed {d_seed:.2f}, winner {d_win:.2f}, islands "
        f"{d_i1:.2f}/{d_i2:.2f}/{d_i3:.2f} px")

    # G4 bars: 186 segments, counts == recompute
    tele = {i: load_csv(RUN_DIR / f"island_{i}" / "telemetry.csv")
            for i in (1, 2, 3)}
    _, _, per_gen, _ = pooled_counts(tele)
    bars: dict[str, list] = {name: [] for _, name in FILLS}
    for m in re.finditer(r"<path\b[^>]*>", svg_text, re.S):
        tag = m.group(0)
        if "clip-path" not in tag:
            continue
        st = re.search(r"style=\"([^\"]*)\"", tag)
        d = re.search(r"d=\"([^\"]*)\"", tag)
        if not st or not d or "stroke: #ffffff" not in st.group(1):
            continue
        for c, name in FILLS:
            if f"fill: {c}" in st.group(1):
                pts = re.findall(r"[ML]\s*([\d.]+)\s+([\d.]+)", d.group(1))
                if len(pts) == 4:
                    xs = [float(p[0]) for p in pts]
                    ys = [float(p[1]) for p in pts]
                    bars[name].append(((min(xs) + max(xs)) / 2,
                                       max(ys), min(ys)))
    n_seg = sum(len(v) for v in bars.values())
    counts_ok, max_res, total = 0, 0.0, 0
    for name, segs in bars.items():
        for cx, yb, yt in segs:
            g = round((cx - x1s[0]) / sx1)
            h = (yb - yt) / sy1
            res = abs(h - round(h))
            max_res = max(max_res, res)
            if res < 1e-3 and round(h) == per_gen[g].get(name, 0):
                counts_ok += 1
            total += round(h)
    chk("G4 bar census (186 segments == recompute)",
        n_seg == 186 and counts_ok == 186 and total == 930,
        f"{counts_ok} of 186 segments, max residual {max_res:.1e}")

    # G5 curves: 93 vertices invert to the extract values
    ex = {i: {int(r["gen"]): float(r["best_fitness"]) for r in extract_rows()
              if int(r["island"]) == i} for i in (1, 2, 3)}
    dev_v, dev_g, n_pts = 0.0, 0.0, 0
    ok3 = True
    for i in (1, 2, 3):
        path = None
        for m in re.finditer(r"<path\b[^>]*>", svg_text, re.S):
            seg = m.group(0)
            if (f"stroke: {ISL_COLORS[i]}" in seg and "fill: none" in seg
                    and seg.count("L") >= 30):
                path = re.search(r"d=\"([^\"]*)\"", seg).group(1)
                break
        pts = re.findall(r"[ML]\s*([\d.]+)\s+([\d.]+)", path or "")
        if len(pts) != 31:
            ok3 = False
            continue
        for g, (px, py) in enumerate(pts):
            n_pts += 1
            dev_g = max(dev_g, abs(inv_x(float(px), x2s[0], sx2) - g))
            dev_v = max(dev_v, abs(inv_y2(float(py)) - ex[i][g]))
    chk("G5 curve census (93 vertices, extract values)",
        ok3 and n_pts == 93 and dev_v < 0.02 and dev_g < 0.02,
        f"{n_pts} pts, max |dvalue| {dev_v:.2e}, max |dgen| {dev_g:.2e}")

    # G6 three island curves present
    chk("G6 three island curves present",
        all(any(f"stroke: {ISL_COLORS[i]}" in m.group(0)
                and "fill: none" in m.group(0) and m.group(0).count("L") >= 30
                for m in re.finditer(r"<path\b[^>]*>", svg_text, re.S))
            for i in (1, 2, 3)), "3 polyline paths")


def extract_rows():
    return load_csv(EXTRACT)


def sweep_checks(svg_text: str) -> None:
    nodes = re.findall(r"<text[^>]*>(.*?)</text>", svg_text, re.S)
    layer = " ".join(html.unescape(re.sub(r"<[^>]+>", "", n)) for n in nodes)
    ledger = (KIT / "label-ledger.txt").read_text(encoding="utf-8")
    hay = (layer + "\n" + ledger).lower()
    banned = ["tbd", "todo", "fixme", "pending"]
    codes = [":reject", "reject_twist", "clearance_reject", "track a", "track b",
             "\u27e8", "\u27e9"]
    hit = [t for t in banned + codes if t in hay]
    chk("S1 no stale tokens or status codes on the drawn layer",
        not hit, "clean" if not hit else str(hit))

    hit = []
    for f in ("SPEC.md", "captions-draft.md", "register-status.md"):
        t = (KIT / f).read_text(encoding="utf-8").lower()
        hit += [f"{f}:{w}" for w in banned if w in t]
    for f in ("captions-draft.md", "register-status.md"):
        t = (KIT / f).read_text(encoding="utf-8")
        hit += [f"{f}:bracket" for b in ("\u27e8", "\u27e9") if b in t]
    chk("S2 no stale tokens in the kit notes", not hit,
        "clean" if not hit else str(hit))
    print("note: SPEC.md carries the \u27e8\u27e9 slot convention (caption plan); "
          "the captions draft and the register note are resolved.")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--repro", action="store_true")
    args = ap.parse_args()
    if args.repro:
        return repro_main()

    svg_text = (KIT / "convergence.svg").read_text(encoding="utf-8")
    pins()
    label_census(svg_text)
    value_checks()
    geometry_checks(svg_text)
    sweep_checks(svg_text)

    n_fail = sum(1 for _, ok, _ in CHECKS if not ok)
    print()
    print(f"census: {len(CHECKS)} checks, {n_fail} fail")
    return 1 if n_fail else 0


def repro_main() -> int:
    out = SCRATCH / "av_cvp_repro"
    logs = {}
    for run in ("r1", "r2"):
        d = out / run
        cmd = ["/usr/bin/python3",
               "docs/reporting/figures/convergence/convergence.py",
               "--script-commit", SCRIPT_COMMIT, "--outdir", str(d)]
        p = subprocess.run(cmd, cwd=REPO, capture_output=True, text=True)
        logs[run] = p.stdout
        if p.returncode != 0:
            print(f"run {run} FAILED rc={p.returncode}")
            print(p.stderr[-2000:])
            return 1
    files = ["convergence.svg", "convergence.pdf", "convergence.png",
             "label-ledger.txt", "manifest.json"]
    lines = ["# av_cvp_repro.md5 — the F-REPRO counter-read, two fresh runs vs "
             "the committed set", f"# script commit {SCRIPT_COMMIT}",
             "# file | committed | run1 | run2"]
    same = 0
    for f in files:
        a = md5(KIT / f)
        b = md5(out / "r1" / f)
        c = md5(out / "r2" / f)
        same += (a == b == c)
        lines.append(f"{f} | {a} | {b} | {c}")
    lines.append(f"# verdict: {same} of {len(files)} byte-identical across the "
                 "three locations")
    (SCRATCH / "av_cvp_repro.md5").write_text("\n".join(lines) + "\n",
                                              encoding="utf-8")
    committed_log = (KIT / "checks.log").read_text(encoding="utf-8")
    log_match = (logs["r1"] == committed_log == logs["r2"])
    print(f"check: R1 F-REPRO byte identity: {same} of {len(files)}  "
          f"({'OK' if same == len(files) else 'OFF'})")
    print(f"check: R2 run stdout == committed checks.log: "
          f"{'OK' if log_match else 'OFF'}")
    print("# table written: scratch/av_cvp_repro.md5")
    return 0 if (same == len(files) and log_match) else 1


if __name__ == "__main__":
    sys.exit(main())

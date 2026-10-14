#!/usr/bin/python3
# -*- coding: utf-8 -*-
"""lever-statistics-extract: the item-5 lever-statistics extract builder.

Feedback item 5 (docs/reporting/feedback/Feedback-message-1791925681590.md):
"Extract lever statistics from telemetry: objective versus gene, gate
failures by gene, and penalty contributions across ok designs."

Sources: the three island telemetry files of campaign
`v13_5kw_masslift_len18.8_rotorcount_bankderate2` (data commit dd3cc6a,
run a76c5e9, era post-95c385d_wind-authority).  930 rows, 508 ok.

Rules.  Recorded columns only; every computed quantity states its recipe.
The telemetry carries no P_range and no mass, so the stationarity charge
is not reconstructable from the columns and the remainder column reads
mass plus stationarity.  Integer genes take the decoder form
(round(clamp(x))), so n_lines and rotor_count group by their decoded
value.  Stdlib only.  Deterministic; two runs stay byte-identical.

Outputs (in this directory): extract-*.csv, checks.log.

Run:
  /usr/bin/python3 docs/reporting/figures/lever-statistics-extract/build-extract.py \
      --script-commit <hex>
"""
from __future__ import annotations

import argparse
import csv
import sys
from bisect import bisect_left
from collections import Counter
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[3]
RD = REPO / "scripts" / "results" / "v13_5kw_masslift_len18.8_rotorcount_bankderate2"
ISLANDS = (1, 2, 3)

DATA_COMMIT = "dd3cc6a"
RUN = "a76c5e9"
ERA = "post-95c385d_wind-authority"
GEN_REL = "docs/reporting/figures/lever-statistics-extract/build-extract.py"

# Canonical 10-slot genome: (column, name, kind, unit).
# Names follow the pca kit gene list (docs/reporting/figures/pca-landscape,
# GENES) and the genome glossary (docs/agents/genome-glossary.md).
GENES = [
    ("x1", "r_hub", "continuous", "m"),
    ("x2", "r_bottom", "continuous", "m"),
    ("x3", "target_Lr", "continuous", ""),
    ("x4", "n_lines", "integer", ""),
    ("x5", "density_profile", "continuous", ""),
    ("x6", "rotor_count", "integer", ""),
    ("x7", "bank_top", "continuous", "deg"),
    ("x8", "bank_bottom", "continuous", "deg"),
    ("x9", "blade_scale_top", "continuous", ""),
    ("x10", "blade_scale_bottom", "continuous", ""),
]

STATUSES = ("ok", "reject", "clearance_reject", "reject_twist")

# NR-039 full-precision penalty charges (winner), read from the register row.
NR039 = {
    "overpower": 0.49333696413175443,
    "utilisation": 0.5576509889014662,
    "twist": 0.6140850570787014,
}
W_OVERPOWER = 5.0     # kg per kW^2    (NR-046)
W_UTILISATION = 20.0  # kg per ratio^2 (NR-046)
W_TWIST = 1.0         # kg per ratio^2 (NR-046)
P_CEIL = 5.0          # kW (NR-046)
FOS_HARD = 2.5        # -  (NR-046)

CHECKS: list[tuple[str, bool, str]] = []


def check(name: str, good: bool, detail: str = "") -> None:
    CHECKS.append((name, bool(good), detail))


def fmt(v: float) -> str:
    return repr(float(v))


def dec_n_lines(x: float) -> int:
    # canonical decoder form: round(clamp(x, 3, 16))
    return int(round(min(max(x, 3.0), 16.0)))


def dec_rotor(x: float) -> int:
    # canonical decoder form: round(clamp(x, 1, 3))
    return int(round(min(max(x, 1.0), 3.0)))


def gene_value(row: dict, col: str, kind: str) -> float:
    x = float(row[col])
    if kind == "integer":
        return float(dec_n_lines(x) if col == "x4" else dec_rotor(x))
    return x


def load_rows() -> list[dict]:
    rows: list[dict] = []
    for isl in ISLANDS:
        p = RD / f"island_{isl}" / "telemetry.csv"
        lines = [ln for ln in p.read_text().splitlines()
                 if not ln.startswith("#") and ln.strip()]
        got = list(csv.DictReader(lines))
        assert got, p
        rows.extend(got)
    return rows


def ranks(vals: list[float]) -> list[float]:
    order = sorted(range(len(vals)), key=lambda i: vals[i])
    out = [0.0] * len(vals)
    i = 0
    while i < len(order):
        j = i
        while j + 1 < len(order) and vals[order[j + 1]] == vals[order[i]]:
            j += 1
        r = (i + j) / 2.0 + 1.0
        for k in range(i, j + 1):
            out[order[k]] = r
        i = j + 1
    return out


def spearman(x: list[float], y: list[float]) -> float:
    rx, ry = ranks(x), ranks(y)
    n = len(x)
    mx = sum(rx) / n
    my = sum(ry) / n
    sx = sum((a - mx) ** 2 for a in rx)
    sy = sum((b - my) ** 2 for b in ry)
    if sx == 0.0 or sy == 0.0:
        return float("nan")
    cov = sum((a - mx) * (b - my) for a, b in zip(rx, ry))
    return cov / (sx * sy) ** 0.5


def auc(pos: list[float], neg: list[float]) -> float:
    # P(pos > neg) + 0.5 * P(tie); rank-sum form.
    n1, n2 = len(pos), len(neg)
    if n1 == 0 or n2 == 0:
        return float("nan")
    r = ranks(list(pos) + list(neg))
    u = sum(r[:n1]) - n1 * (n1 + 1) / 2.0
    return u / (n1 * n2)


def pctl(sv: list[float], q: float) -> float:
    # linear interpolation on a sorted list (q in 0..1)
    if len(sv) == 1:
        return sv[0]
    pos = q * (len(sv) - 1)
    lo = int(pos)
    frac = pos - lo
    hi = min(lo + 1, len(sv) - 1)
    return sv[lo] + (sv[hi] - sv[lo]) * frac


# Recorded precision: P_end and FoS print as round(x, 2) strings (decimals
# seen: {1, 2}); half-ulp 0.005.  fitness prints at three decimals (0.0005).
# twist_ratio prints full precision.
REC_D_PEND = 0.005
REC_D_FOS = 0.005


def charge_overpower(p_end: float) -> float:
    return W_OVERPOWER * max(p_end - P_CEIL, 0.0) ** 2


def charge_utilisation(fos: float) -> float:
    return W_UTILISATION * (FOS_HARD / fos) ** 2


def charge_twist(tr: float) -> float:
    if tr <= 0.0:
        return 0.0
    r = min(tr, 1.0)
    return W_TWIST * (r / max(1.0 - r, 1e-6)) ** 2


def prov_line(recipe: str, script_commit: str) -> str:
    return (
        "# lever-statistics-extract | dataset scripts/results/"
        "v13_5kw_masslift_len18.8_rotorcount_bankderate2 | data commit "
        f"{DATA_COMMIT} | run {RUN} | era {ERA} | generator {GEN_REL} | "
        f"script commit {script_commit} | recipe: {recipe}"
    )


def write_csv(path: Path, header: list[str], rows: list[list], prov: str) -> None:
    with open(path, "w", newline="") as f:
        f.write(prov + "\n")
        w = csv.writer(f, lineterminator="\n")
        w.writerow(header)
        w.writerows(rows)


def bin_gene(col: str, kind: str, ok: list[dict]) -> list[tuple[str, str, str, list[float]]]:
    """Return non-empty bins: (label, lo_raw, hi_raw, fitness list)."""
    pairs = [(gene_value(r, col, kind), float(r["fitness"])) for r in ok]
    if kind == "integer":
        vals = sorted({v for v, _ in pairs})
        return [(str(int(v)), str(int(v)), str(int(v)),
                 [f for v_, f in pairs if v_ == v]) for v in vals]
    sv = sorted(v for v, _ in pairs)
    edges = [pctl(sv, q) for q in (0.2, 0.4, 0.6, 0.8)]
    buckets: dict[int, list[tuple[float, float]]] = {}
    for v, f in pairs:
        buckets.setdefault(bisect_left(edges, v), []).append((v, f))
    out = []
    for i, b in enumerate(sorted(buckets)):
        vs = [v for v, _ in buckets[b]]
        fs = [f for _, f in buckets[b]]
        out.append((f"q{i + 1}", fmt(min(vs)), fmt(max(vs)), fs))
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--script-commit", default="uncommitted")
    ap.add_argument("--outdir", default=str(HERE))
    args = ap.parse_args()
    outdir = Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)
    sc = args.script_commit

    # ------------------------------------------------------------- inputs
    for isl in ISLANDS:
        head = (RD / f"island_{isl}" / "telemetry.csv").read_text().splitlines()[0]
        check(f"header pins island {isl}",
              f"era={ERA}" in head and f"git={RUN}" in head, head[:120])

    rows = load_rows()
    check("row totals read 930", len(rows) == 930, str(len(rows)))
    per_isl = Counter(r["island"] for r in rows)
    check("island counts read 310 each",
          all(per_isl[str(i)] == 310 for i in ISLANDS), str(dict(per_isl)))
    mix = Counter(r["status"] for r in rows)
    check("status mix reads 508 / 301 / 110 / 11 (NR-002)",
          mix["ok"] == 508 and mix["reject"] == 301
          and mix["clearance_reject"] == 110 and mix["reject_twist"] == 11,
          str(dict(mix)))

    ok = [r for r in rows if r["status"] == "ok"]
    check("ok set reads 508 finite scores",
          len(ok) == 508 and all(float(r["fitness"]) < 1e6 for r in ok))

    p_min = min(float(r["P_end"]) for r in ok)
    f_min = min(float(r["FoS"]) for r in ok)
    tr_max = max(float(r["twist_ratio"]) for r in ok)
    fit_lo = min(float(r["fitness"]) for r in ok)
    fit_hi = max(float(r["fitness"]) for r in ok)
    check("ok P_end at or above the 5.0 kW floor", p_min >= P_CEIL - 1e-9, f"min {p_min}")
    check("ok FoS at or above the 2.5 hard floor", f_min >= FOS_HARD - 1e-9, f"min {f_min}")
    check("ok twist_ratio inside [0, 1)", 0.0 <= tr_max < 1.0, f"max {tr_max}")

    mism_nl = [r for r in rows if dec_n_lines(float(r["x4"])) != int(r["n_lines"])]
    check("decoded n_lines equals the n_lines column on all rows",
          not mism_nl, f"{len(mism_nl)} mismatches")
    xtab = Counter((dec_rotor(float(r["x6"])), int(r["n_active"])) for r in rows)
    ok_rot = Counter(dec_rotor(float(r["x6"])) for r in ok)

    # ------------------------------------------------- winner checks (NR-039)
    wrow = [r for r in rows if r["island"] == "3" and r["gen"] == "26" and r["idx"] == "9"]
    check("winner row unique (island 3, gen 26, idx 9)", len(wrow) == 1, str(len(wrow)))
    w = wrow[0]
    check("winner fitness string reads 27.364", w["fitness"] == "27.364", w["fitness"])
    w_p = float(w["P_end"])
    w_f = float(w["FoS"])
    w_tr = float(w["twist_ratio"])
    w_ov = charge_overpower(w_p)
    w_ut = charge_utilisation(w_f)
    w_tw = charge_twist(w_tr)
    d_ov = abs(w_ov - NR039["overpower"])
    d_ut = abs(w_ut - NR039["utilisation"])
    d_tw = abs(w_tw - NR039["twist"])
    b_ov = (charge_overpower(w_p + REC_D_PEND)
            - charge_overpower(w_p - REC_D_PEND))
    b_ut = (W_UTILISATION * FOS_HARD ** 2
            * (1.0 / (w_f - REC_D_FOS) ** 2
               - 1.0 / (w_f + REC_D_FOS) ** 2))
    check("winner over-power recompute inside the CSV rounding bound",
          d_ov <= b_ov + 1e-12, f"delta {d_ov} bound {b_ov}")
    check("winner utilisation recompute inside the CSV rounding bound",
          d_ut <= b_ut + 1e-12, f"delta {d_ut} bound {b_ut}")
    check("winner twist recompute at full precision (twist_ratio printed full)",
          d_tw <= 1e-12, f"delta {d_tw}")

    reg = (REPO / "docs/reporting/numbers-register.md").read_text()
    check("register carries the NR-039 penalty strings",
          all(s in reg for s in ("0.49333696413175443", "0.5576509889014662",
                                 "0.6140850570787014")))

    def _dec(s: str) -> int:
        return len(s.split(".")[1]) if "." in s and not s.endswith(".") else 0

    check("P_end and FoS record at two decimals or fewer",
          max(_dec(r["P_end"]) for r in ok) <= 2 and max(_dec(r["FoS"]) for r in ok) <= 2,
          f"P_end {max(_dec(r['P_end']) for r in ok)}, "
          f"FoS {max(_dec(r['FoS']) for r in ok)}")
    worst_ov = max(charge_overpower(float(r["P_end"]) + REC_D_PEND)
                   - charge_overpower(float(r["P_end"]) - REC_D_PEND) for r in ok)
    worst_ut = max(W_UTILISATION * FOS_HARD ** 2
                   * (1.0 / (float(r["FoS"]) - REC_D_FOS) ** 2
                      - 1.0 / (float(r["FoS"]) + REC_D_FOS) ** 2) for r in ok)

    # ------------------------------------------------- table 1+2: objective vs gene
    stats = []  # (name, col, kind, rho, bins)
    for col, name, kind, _unit in GENES:
        gv = [gene_value(r, col, kind) for r in ok]
        fit = [float(r["fitness"]) for r in ok]
        stats.append((name, col, kind, spearman(gv, fit), bin_gene(col, kind, ok)))
    order = sorted(range(len(stats)), key=lambda i: -abs(stats[i][3]))
    rank_of = {i: pos for pos, i in enumerate(order, start=1)}

    t1_rows = []
    for i, (name, col, kind, rho, bins) in enumerate(stats):
        bottom = pctl(sorted(bins[0][3]), 0.5)
        top = pctl(sorted(bins[-1][3]), 0.5)
        t1_rows.append((name, col, kind, len(ok), fmt(rho), str(rank_of[i]),
                        bins[0][0], bins[-1][0], fmt(top - bottom)))
    write_csv(outdir / "extract-objective-vs-gene.csv",
              ["gene", "slot", "kind", "n", "spearman_rho", "rho_rank",
               "bottom_bin", "top_bin", "delta_med_kg"], t1_rows,
              prov_line("spearman(fitness, gene) over the 508 ok rows; integer genes "
                        "take the decoder value; delta_med reads median(top bin) - "
                        "median(bottom bin)", sc))

    t2_rows = []
    for name, col, kind, _rho, bins in stats:
        for lab, lo, hi, fs in bins:
            sf = sorted(fs)
            t2_rows.append((name, col, kind, lab, lo, hi, len(sf),
                            fmt(pctl(sf, 0.5)), fmt(sum(sf) / len(sf)),
                            fmt(pctl(sf, 0.25)), fmt(pctl(sf, 0.75))))
    write_csv(outdir / "extract-objective-by-gene-bins.csv",
              ["gene", "slot", "kind", "bin", "lo", "hi", "n",
               "median_fitness", "mean_fitness", "p25_fitness", "p75_fitness"],
              t2_rows,
              prov_line("conditioned objective on the 508 ok rows; integer genes group "
                        "at the decoder value, continuous genes in five quantile bins; "
                        "fitness recorded at 3 dp", sc))

    # ------------------------------------------------- table 3: gate failures
    t3_rows = []
    for col, name, kind, _unit in GENES:
        for st in STATUSES:
            vs = sorted(gene_value(r, col, kind) for r in rows if r["status"] == st)
            if not vs:
                continue
            t3_rows.append((name, col, st, len(vs), fmt(pctl(vs, 0.5)),
                            fmt(pctl(vs, 0.25)), fmt(pctl(vs, 0.75)),
                            fmt(vs[0]), fmt(vs[-1])))
    write_csv(outdir / "extract-gate-failures-by-gene.csv",
              ["gene", "slot", "status", "n", "median", "p25", "p75", "min", "max"],
              t3_rows,
              prov_line("gene distributions per status class over all 930 rows; "
                        "integer genes take the decoder value", sc))

    # ------------------------------------------------- table 4: discrimination
    t4_rows = []
    for col, name, kind, _unit in GENES:
        ov_ = [gene_value(r, col, kind) for r in ok]
        row = [name, col, len(ov_), fmt(pctl(sorted(ov_), 0.5))]
        for st in ("reject", "clearance_reject", "reject_twist"):
            fv = [gene_value(r, col, kind) for r in rows if r["status"] == st]
            row += [len(fv), fmt(pctl(sorted(fv), 0.5)),
                    fmt(auc(ov_, fv))]
        t4_rows.append(tuple(row))
    write_csv(outdir / "extract-failure-discrimination.csv",
              ["gene", "slot", "n_ok", "med_ok", "n_reject", "med_reject", "auc_reject",
               "n_clearance", "med_clearance", "auc_clearance",
               "n_twist", "med_twist", "auc_twist"], t4_rows,
              prov_line("rank separation of ok vs each failure class; auc reads "
                        "P(ok value above failure value) + 0.5 ties; 0.5 = no "
                        "separation", sc))

    # ------------------------------------------------- table 5: failure rates by value
    t5_rows = []
    sections = [("n_lines", lambda r: dec_n_lines(float(r["x4"]))),
                ("rotor_count", lambda r: dec_rotor(float(r["x6"]))),
                ("n_active", lambda r: int(r["n_active"]))]
    for cname, fn in sections:
        for v in sorted({fn(r) for r in rows}):
            grp = [r for r in rows if fn(r) == v]
            c = Counter(r["status"] for r in grp)
            t5_rows.append((cname, str(v), len(grp), c["ok"], c["reject"],
                            c["clearance_reject"], c["reject_twist"],
                            f"{100.0 * c['ok'] / len(grp):.1f}"))
    write_csv(outdir / "extract-failure-rates-by-value.csv",
              ["column", "value", "n_total", "ok", "reject", "clearance_reject",
               "reject_twist", "ok_share_pct"], t5_rows,
              prov_line("status counts per discrete value; n_lines and rotor_count "
                        "take the decoder value; n_active reads the recorded decode "
                        "column", sc))

    # ------------------------------------------------- table 6: penalty contributions
    ok_sorted = sorted(ok, key=lambda r: (int(r["island"]), int(r["gen"]), int(r["idx"])))
    t6_rows = []
    for r in ok_sorted:
        pen = (charge_overpower(float(r["P_end"]))
               + charge_utilisation(float(r["FoS"]))
               + charge_twist(float(r["twist_ratio"])))
        fit = float(r["fitness"])
        t6_rows.append((r["island"], r["gen"], r["idx"], r["fitness"], r["P_end"],
                        r["FoS"], r["twist_ratio"],
                        fmt(charge_overpower(float(r["P_end"]))),
                        fmt(charge_utilisation(float(r["FoS"]))),
                        fmt(charge_twist(float(r["twist_ratio"]))),
                        fmt(pen), fmt(fit - pen), fmt(100.0 * pen / fit)))
    write_csv(outdir / "extract-penalty-contributions.csv",
              ["island", "gen", "idx", "fitness", "P_end", "FoS", "twist_ratio",
               "charge_overpower", "charge_utilisation", "charge_twist",
               "penalty_total", "remainder_kg", "penalty_share_pct"], t6_rows,
              prov_line("charges recompute from the recorded columns at recorded "
                        "precision via the NR-046 forms; remainder reads fitness - the "
                        "three charges (mass + stationarity); penalty_share in per "
                        "cent of the recorded fitness", sc))

    # ------------------------------------------------- table 7: penalty summary
    trips = [(charge_overpower(float(r["P_end"])),
              charge_utilisation(float(r["FoS"])),
              charge_twist(float(r["twist_ratio"]))) for r in ok]
    total_sum = sum(sum(t) for t in trips)
    dom = [0, 0, 0]
    for t in trips:
        mx = max(t)
        if t.count(mx) == 1:
            dom[t.index(mx)] += 1
    t7_rows = []
    names = ("overpower", "utilisation", "twist")
    for ci in range(3):
        vals = [t[ci] for t in trips]
        sv = sorted(vals)
        t7_rows.append((names[ci], len(vals), sum(1 for v in vals if v > 0.0),
                        fmt(sv[0]), fmt(pctl(sv, 0.5)), fmt(pctl(sv, 0.75)),
                        fmt(sv[-1]), fmt(sum(vals)),
                        fmt(100.0 * sum(vals) / total_sum), str(dom[ci])))
    st = sorted(sum(t) for t in trips)
    t7_rows.append(("total", len(st), sum(1 for v in st if v > 0.0), fmt(st[0]),
                    fmt(pctl(st, 0.5)), fmt(pctl(st, 0.75)), fmt(st[-1]),
                    fmt(sum(st)), "100.0", "-"))
    write_csv(outdir / "extract-penalty-summary.csv",
              ["channel", "n_rows", "n_fired", "min", "median", "p75", "max", "sum",
               "share_pct", "n_dominant"], t7_rows,
              prov_line("per-channel statistics over the 508 ok rows; n_fired counts "
                        "charge > 0; n_dominant counts rows where the channel is the "
                        "largest of the three charges", sc))

    # ------------------------------------------------- checks log
    log_lines = []
    for name, good, detail in CHECKS:
        tail = "" if good else f"  [{detail}]"
        log_lines.append(("OK  " if good else "FAIL") + "  " + name + tail)
    log_lines.append(
        f"note  winner charges from CSV columns: over-power {w_ov} "
        f"(record {NR039['overpower']}), utilisation {w_ut} "
        f"(record {NR039['utilisation']}), twist {w_tw} (record {NR039['twist']})")
    log_lines.append(
        f"note  worst-case single-row charge rounding bounds over ok rows: "
        f"over-power {worst_ov}, utilisation {worst_ut}")
    log_lines.append(
        f"note  decoded rotor_count among ok: {dict(ok_rot)}; rotor_count >= 2 ok rows: "
        f"{sum(v for k, v in ok_rot.items() if k >= 2)}; "
        f"decoded rotor_count x n_active cross-tab (all rows): {dict(xtab)}")
    log_lines.append(
        f"note  ok fitness range {fit_lo} to {fit_hi}; P_end min {p_min}; "
        f"FoS min {f_min}; twist_ratio max {tr_max}")
    failed = [c for c in CHECKS if not c[1]]
    log_lines.append(f"checks: {len(CHECKS) - len(failed)} ok / {len(failed)} fail")
    log_lines.append("FIG_LEVER_EXTRACT_FAIL" if failed else "FIG_LEVER_EXTRACT_DONE")
    text = "\n".join(log_lines) + "\n"
    (outdir / "checks.log").write_text(text)
    print(text)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())

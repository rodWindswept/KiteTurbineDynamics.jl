#!/usr/bin/env python3
"""scripts/generate_phase1_delta.py
Idempotent CSV→doc generator for PRD 0006 Phase 1 delta analysis.
Reads the authoritative Gate 1 CSVs and the tier-X pre-fix CSVs,
produces tables, loss-model fits, and FoS audit.

Usage:
  python3 scripts/generate_phase1_delta.py [--markdown] [--json]
  python3 scripts/generate_phase1_delta.py --output docs/prd/0006-phase1-delta-analysis.md

All numbers are read from CSV at generation time — hand-transcription is eliminated.
"""

import csv, math, os, sys, json
from datetime import datetime

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CMAPS = os.path.join(REPO, "scripts", "results", "control_maps")

# ── Authoritative CSVs (post-fix Gate 1) ──────────────────────────
GATE1 = {
    "V10 Tight λ=1.0": os.path.join(CMAPS, "gate1_v10_tight_maxpower_summary.csv"),
    "V10 Reinforced":   os.path.join(CMAPS, "gate1_v10_reinforced_maxpower_summary.csv"),
    "λ=0.69":           os.path.join(CMAPS, "gate1_blade_scaled_069_maxpower_summary.csv"),
}

# ── Pre-fix (biased geometry) CSVs ─────────────────────────────────
PREFIX = {
    "V10 Tight λ=1.0": os.path.join(CMAPS, "v10_tight_control_map.csv"),
    "V10 Reinforced":   os.path.join(CMAPS, "v10_reinforced_summary.csv"),
    # λ=0.69 has no pre-fix data
}

# ── CSV readers ────────────────────────────────────────────────────

def read_gate1(path):
    """Read a Gate 1 summary CSV with # comment header."""
    with open(path) as f:
        lines = f.readlines()
    header_idx = 0
    for i, line in enumerate(lines):
        if not line.startswith("#"):
            header_idx = i
            break
    reader = csv.DictReader(lines[header_idx:])
    rows = {}
    for row in reader:
        wind = float(row["v_wind"])
        d = {}
        for k, v in row.items():
            try:
                d[k] = float(v) if v else None
            except (ValueError, TypeError):
                d[k] = v
        d["status"] = row.get("status", "")
        d["reached_rated"] = row.get("reached_rated", "")
        d["converged"] = row.get("converged", "")
        rows[wind] = d
    return rows

def read_prefix(path):
    """Read a pre-fix CSV (no comment header, fewer columns)."""
    with open(path) as f:
        reader = csv.DictReader(f)
        rows = {}
        for row in reader:
            wind = float(row["v_wind"])
            d = {}
            for k, v in row.items():
                try:
                    d[k] = float(v) if v else None
                except (ValueError, TypeError):
                    d[k] = v
            d["status"] = row.get("status", "")
            d["reached_rated"] = row.get("reached_rated", "")
            rows[wind] = d
        return rows

def pct(old, new):
    """Percentage change, handling edge cases."""
    if old is None or new is None or abs(old) < 0.01:
        return None
    return (new - old) / old * 100

def fmt_pct(v):
    if v is None:
        return "    —"
    return f"{v:+6.1f}%"

# ── Analysis functions ─────────────────────────────────────────────

def delta_table(name, old_data, new_data):
    """Generate delta table rows."""
    lines = []
    all_winds = sorted(set(old_data.keys()) | set(new_data.keys()))
    for w in all_winds:
        o = old_data.get(w, {})
        n = new_data.get(w, {})
        if not o or not n:
            continue
        pk_o = o.get("P_kw")
        pk_n = n.get("P_kw")
        wo = o.get("omega_rpm", o.get("ω_rpm"))
        wn = n.get("ω_rpm")
        ko = o.get("k_mppt")
        kn = n.get("k_mppt")
        fo = o.get("min_fos")
        fn = n.get("min_fos")
        so = o.get("status", "?")
        sn = n.get("status", "?")
        dp = pct(pk_o, pk_n)
        dw = pct(wo, wn)
        lines.append({
            "wind": w,
            "P_pre": pk_o, "P_post": pk_n, "dP": dp,
            "ω_pre": wo, "ω_post": wn, "dω": dw,
            "k_pre": ko, "k_post": kn,
            "FoS_pre": fo, "FoS_post": fn,
            "status_pre": so, "status_post": sn,
        })
    return lines

def loss_fit(data, label):
    """Fit P_loss = c * ω³ and return stats."""
    xs, ys = [], []
    for w in sorted(data.keys()):
        n = data[w]
        wr = n["ω_rpm"] * 2 * math.pi / 60
        pl = n.get("P_loss_kw", 0)
        if pl is None:
            pl = 0
        xs.append(wr**3)
        ys.append(pl)

    if sum(xs) < 1e-6:
        return {"c": 0, "r2": 0, "rows": []}

    sxy = sum(x*y for x, y in zip(xs, ys))
    sxx = sum(x*x for x in xs)
    c = sxy / sxx if sxx > 1e-6 else 0
    y_mean = sum(ys) / len(ys)
    ss_res = sum((y - c*x)**2 for x, y in zip(xs, ys))
    ss_tot = sum((y - y_mean)**2 for y in ys) + 1e-12
    r2 = 1 - ss_res / ss_tot

    rows = []
    for w, x, y in zip(sorted(data.keys()), xs, ys):
        y_pred = c * x
        rows.append({"wind": w, "ω_rad": (x**(1/3)), "ω³": x, "P_loss": y,
                      "P_loss_pred": y_pred, "residual": y - y_pred})

    return {"c": c, "r2": r2, "rows": rows}

def fos_audit(old_data, new_data, name):
    """Audit FoS claims."""
    issues = []
    for w in sorted(set(old_data.keys()) | set(new_data.keys())):
        o = old_data.get(w, {})
        n = new_data.get(w, {})
        if not o or not n:
            continue
        fo = o.get("min_fos")
        fn = n.get("min_fos")
        if fo is None or fn is None:
            continue
        d = pct(fo, fn)
        flag = ""
        if fo is not None and fo >= 1.5 and fn < 1.5:
            flag = "🔴 CLAIM BROKEN (was safe ≥1.5, now marginal)"
        if fo is not None and fo >= 1.0 and fn < 1.0:
            flag = "🔴 CLAIM BROKEN (was ok ≥1.0, now fail)"
        issues.append({"wind": w, "FoS_pre": fo, "FoS_post": fn, "delta": d,
                        "flag": flag})
    return issues

def static_dynamic_gap(data, label):
    rows = []
    for w in sorted(data.keys()):
        n = data[w]
        pd = n.get("P_kw", 0)
        pa = n.get("P_aero_kw", 0)
        ps = n.get("P_static_kw", 0)
        if ps and ps > 0.1:
            rows.append({"wind": w, "P_ground": pd, "P_aero": pa, "P_static": ps,
                          "gap_ground": pd/ps, "gap_aero": pa/ps})
    return rows

def markdown_output():
    """Produce full markdown delta analysis."""
    out = []
    out.append(f"# PRD 0006 Phase 1 — Delta Analysis\n")
    out.append(f"**Status:** COMPLETE")
    out.append(f"**Generated:** {datetime.now().isoformat()}")
    out.append(f"**Parent:** [PRD 0006 — Blade Geometry Audit & Recovery](0006-blade-geometry-audit.md)")
    out.append(f"**Generator:** `scripts/generate_phase1_delta.py` (idempotent, CSV→doc)")
    out.append("")

    # Load data
    gate1 = {name: read_gate1(path) for name, path in GATE1.items()}
    prefix = {}
    for name, path in PREFIX.items():
        if os.path.exists(path):
            prefix[name] = read_prefix(path)

    # P0 ANSWER: which CSV was used
    for name, path in GATE1.items():
        with open(path) as f:
            hdr = f.readline().strip()
        out.append(f"**{name}:** `{os.path.basename(path)}` — `{hdr}`\n")

    out.append("---\n")

    # §1 Delta tables
    out.append("## 1. Gate 1 Delta Tables\n")
    for name in gate1:
        new_data = gate1[name]
        old_data = prefix.get(name, {})
        if not old_data:
            out.append(f"### 1.x {name}\n")
            out.append("No pre-fix data available for this builder.\n")
            out.append(f"| Wind | P (kW) | ω (rpm) | k | FoS | Status |")
            out.append(f"|------|--------|---------|----|-----|--------|")
            for w in sorted(new_data.keys()):
                n = new_data[w]
                out.append(f"| {w:.0f} | {n['P_kw']:.1f} | {n['ω_rpm']:.1f} | {n['k_mppt']:.1f} | {n['min_fos']:.2f} | {n['status']} |")
            out.append("")
            continue

        rows = delta_table(name, old_data, new_data)
        out.append(f"### 1.x {name}\n")
        out.append(f"| Wind | P_pre | P_post | ΔP% | ω_pre | ω_post | Δω% | k_pre | k_post | FoS_pre | FoS_post | Status_pre → Status_post |")
        out.append(f"|------|-------|--------|-----|-------|--------|-----|-------|--------|---------|----------|--------------------------|")
        for r in rows:
            out.append(f"| {r['wind']:.0f} | {r['P_pre']:.1f} | {r['P_post']:.1f} | {fmt_pct(r['dP'])} | {r['ω_pre']:.1f} | {r['ω_post']:.1f} | {fmt_pct(r['dω'])} | {r['k_pre']:.1f} | {r['k_post']:.1f} | {r['FoS_pre']:.2f} | {r['FoS_post']:.2f} | {r['status_pre']} → {r['status_post']} |")
        out.append("")

    # §2 Loss model
    out.append("## 2. Loss Model Re-fit (P_loss = c × ω³)\n")
    out.append("| Builder | c (kW/(rad/s)³) | R² |")
    out.append("|---------|-----------------|-----|")
    for name, data in gate1.items():
        fit = loss_fit(data, name)
        out.append(f"| {name} | {fit['c']:.6f} | {fit['r2']:.4f} |")
    out.append("")

    # §3 Static-dynamic gap
    out.append("## 3. Static–Dynamic Gap\n")
    out.append("**Basis:** P_ground(dynamic) / P_static(aero) — see §P3 for basis discussion.\n")
    out.append(f"| Wind | " + " | ".join(f"{name} (×)" for name in gate1.keys()) + " |")
    out.append(f"|------|" + "|".join("--------" for _ in gate1) + "|")
    gaps = {}
    for name, data in gate1.items():
        for w, n in sorted(data.items()):
            if w not in gaps:
                gaps[w] = {}
            pd = n.get("P_kw", 0)
            ps = n.get("P_static_kw", 0)
            gaps[w][name] = pd / ps if ps and ps > 0.1 else float('inf')
    for w in sorted(gaps.keys()):
        cells = " | ".join(f"{gaps[w].get(name, float('inf')):.2f}×" for name in gate1.keys())
        out.append(f"| {w:.0f} | {cells} |")
    out.append("")

    # §4 FoS audit
    out.append("## 4. FoS Claim Audit\n")
    for name in prefix:
        old_data = prefix[name]
        new_data = gate1[name]
        issues = fos_audit(old_data, new_data, name)
        broken = [i for i in issues if i["flag"]]
        out.append(f"### {name}\n")
        if broken:
            out.append("**Claims BROKEN by the 70/30 fix:**\n")
            for i in broken:
                out.append(f"- {i['wind']:.0f} m/s: FoS {i['FoS_pre']:.2f} → {i['FoS_post']:.2f} ({i['delta']:+.0f}%) — {i['flag']}")
        else:
            out.append("No claims broken.\n")
        out.append("")

    # §5 Envelope summary
    out.append("## 5. Envelope Summary (post-fix)\n")
    out.append("| Builder | Rated | FoS≥1.5 all winds? | Max power (15 m/s) | Min FoS |")
    out.append("|---------|-------|---------------------|--------------------|---------|")
    for name, data in gate1.items():
        crossing = None
        for w in sorted(data.keys()):
            if data[w].get("P_kw", 0) >= 50.0:
                crossing = w
                break
        min_fos = min(data[w].get("min_fos", 0) for w in data)
        max_p = max(data[w].get("P_kw", 0) for w in data)
        safe = "✅ YES" if all(data[w].get("min_fos", 0) >= 1.5 for w in data) else "❌ NO"
        out.append(f"| {name} | ≤{crossing:.0f} m/s | {safe} | {max_p:.0f} kW | {min_fos:.2f} |")
    out.append("")

    # Footer
    out.append("---\n")
    out.append(f"**Generated:** `scripts/generate_phase1_delta.py` at {datetime.now().isoformat()}")
    out.append("**Rule:** All numbers read from CSVs at generation time. No hand-transcription.\n")

    return "\n".join(out)

# ── CLI ────────────────────────────────────────────────────────────

if __name__ == "__main__":
    import argparse
    ap = argparse.ArgumentParser(description="Generate PRD 0006 Phase 1 delta analysis from CSVs")
    ap.add_argument("--output", "-o", help="Write to file instead of stdout")
    ap.add_argument("--json", action="store_true", help="JSON output (machine-readable)")
    ap.add_argument("--markdown", action="store_true", help="Markdown output (default)")
    args = ap.parse_args()

    if args.json:
        gate1 = {name: read_gate1(path) for name, path in GATE1.items()}
        print(json.dumps(gate1, indent=2, default=str))
    else:
        md = markdown_output()
        if args.output:
            with open(args.output, "w") as f:
                f.write(md)
            print(f"Wrote {args.output} ({len(md)} bytes)")
        else:
            print(md)

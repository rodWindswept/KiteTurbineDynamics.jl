"""
v2 vs v3 Optimisation Comparison
=================================
Reads all 60 best_design.json files from trpt_opt_v2 and trpt_opt_v3,
produces comparison figures and prints a summary table.

Usage:
  python3 scripts/produce_v3_comparison_report.py [--v3-dir PATH]

Figures saved to scripts/results/trpt_opt_v3/cartography/:
  fig_v2_vs_v3_mass_comparison.png
  fig_v3_geometry_shift.png
"""

from __future__ import annotations
import json, argparse
from pathlib import Path
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches

ROOT   = Path(__file__).parent.parent
V2_DIR = ROOT / "scripts" / "results" / "trpt_opt_v2"
V3_DIR = ROOT / "scripts" / "results" / "trpt_opt_v3"

BEAM_LABELS   = {"airfoil": "Airfoil", "circular": "Circular", "elliptical": "Elliptical"}
AXIAL_LABELS  = {
    "elliptic":      "Elliptic",
    "linear":        "Linear",
    "parabolic":     "Parabolic",
    "straight_taper":"Str. Taper",
    "trumpet":       "Trumpet",
}
BEAMS  = ["airfoil", "circular", "elliptical"]
AXIALS = ["elliptic", "linear", "parabolic", "straight_taper", "trumpet"]
SEEDS  = ["s1", "s2"]
SIZES  = ["10kw", "50kw"]

GREY   = "#9EA8B3"
TEAL   = "#007A87"
NAVY   = "#0D1B2A"
AMBER  = "#E07B00"


def parse_tag(name: str) -> tuple[str, str, str, str]:
    """'10kw_circular_straight_taper_s1' → (size, beam, axial, seed)"""
    parts = name.split("_")
    size = parts[0]
    seed = parts[-1]
    beam = parts[1]
    axial_parts = parts[2:-1]
    axial = "_".join(axial_parts)
    return size, beam, axial, seed


def load_all(v3_dir: Path) -> dict:
    """Load all 60 v2 and v3 best_design.json files.
    Returns dict keyed by (size, beam, axial, seed)."""
    data = {}
    for version, base in [("v2", V2_DIR), ("v3", v3_dir)]:
        for p in sorted(base.glob("*/best_design.json")):
            tag = p.parent.name
            try:
                size, beam, axial, seed = parse_tag(tag)
            except Exception:
                continue
            if size not in SIZES or beam not in BEAMS or axial not in AXIALS:
                continue
            d = json.loads(p.read_text())
            data[(version, size, beam, axial, seed)] = d
    return data


def combo_label(beam: str, axial: str) -> str:
    return f"{BEAM_LABELS[beam]}\n{AXIAL_LABELS[axial]}"


def build_comparison_table(data: dict) -> list[dict]:
    rows = []
    for size in SIZES:
        for beam in BEAMS:
            for axial in AXIALS:
                for seed in SEEDS:
                    v2 = data.get(("v2", size, beam, axial, seed))
                    v3 = data.get(("v3", size, beam, axial, seed))
                    if v2 is None or v3 is None:
                        continue
                    m2 = v2["best_mass_kg"]
                    m3 = v3["best_mass_kg"]
                    pct = 100.0 * (m3 - m2) / m2
                    tors_v3 = v3["evaluation"].get("torsional_fos_min",
                               v3.get("torsional_fos_min", float("nan")))
                    rows.append({
                        "size": size, "beam": beam, "axial": axial, "seed": seed,
                        "v2_mass": m2, "v3_mass": m3, "mass_pct_change": pct,
                        "v2_taper": v2["design"]["taper_ratio"],
                        "v3_taper": v3["design"]["taper_ratio"],
                        "v2_r_hub": v2["design"]["r_hub_m"],
                        "v3_r_hub": v3["design"]["r_hub_m"],
                        "v2_n_rings": v2["design"]["n_rings"],
                        "v3_n_rings": v3["design"]["n_rings"],
                        "v3_torsional_fos": tors_v3,
                    })
    return rows


def print_summary(rows: list[dict]):
    print("\n=== v2 vs v3 Comparison Summary ===\n")
    header = f"{'Config':<42} {'v2 mass':>9} {'v3 mass':>9} {'Δ%':>7}  {'v2 taper':>9} {'v3 taper':>9}  {'v2 rhub':>8} {'v3 rhub':>8}  {'v3 tor FOS':>10}"
    print(header)
    print("─" * len(header))
    for r in rows:
        tag = f"{r['size']}  {r['beam']:<12} {r['axial']:<16} {r['seed']}"
        print(f"{tag:<42} {r['v2_mass']:>9.2f} {r['v3_mass']:>9.2f} {r['mass_pct_change']:>+7.1f}%"
              f"  {r['v2_taper']:>9.4f} {r['v3_taper']:>9.4f}"
              f"  {r['v2_r_hub']:>8.3f} {r['v3_r_hub']:>8.3f}"
              f"  {r['v3_torsional_fos']:>10.4f}")

    # Summary stats
    pct_all = [r["mass_pct_change"] for r in rows]
    v2_tapers = [r["v2_taper"] for r in rows]
    v3_tapers = [r["v3_taper"] for r in rows]
    print(f"\nMass increase: mean {np.mean(pct_all):+.1f}%  min {np.min(pct_all):+.1f}%  max {np.max(pct_all):+.1f}%")
    print(f"v2 taper_ratio: mean {np.mean(v2_tapers):.3f}  range [{np.min(v2_tapers):.3f}, {np.max(v2_tapers):.3f}]")
    print(f"v3 taper_ratio: mean {np.mean(v3_tapers):.4f}  range [{np.min(v3_tapers):.4f}, {np.max(v3_tapers):.4f}]")
    tors_all = [r["v3_torsional_fos"] for r in rows if not np.isnan(r["v3_torsional_fos"])]
    if tors_all:
        print(f"v3 torsional FOS: mean {np.mean(tors_all):.4f}  min {np.min(tors_all):.4f}  max {np.max(tors_all):.4f}")

    # How many v2 designs had taper < 0.9 (non-cylindrical)?
    non_cyl = sum(1 for r in rows if r["v2_taper"] < 0.9)
    print(f"\nv2 designs with taper < 0.9 (conical): {non_cyl}/{len(rows)}")
    v3_cyl = sum(1 for r in rows if r["v3_taper"] > 0.99)
    print(f"v3 designs with taper ≥ 0.99 (cylindrical): {v3_cyl}/{len(rows)}")


def fig_mass_comparison(rows: list[dict], out_path: Path):
    """Grouped bar chart — 10kW and 50kW panels, one group per beam×axial combo."""
    combos = [(b, a) for b in BEAMS for a in AXIALS]
    n = len(combos)
    x = np.arange(n)
    w = 0.35

    fig, axes = plt.subplots(2, 1, figsize=(18, 10), sharex=True,
                              facecolor="white")
    fig.suptitle("Mass impact of enforcing Tulloch torsional collapse constraint",
                 fontsize=14, fontweight="bold", color=NAVY, y=0.98)

    for ax_idx, size in enumerate(SIZES):
        ax = axes[ax_idx]
        v2_means, v3_means = [], []
        v2_stds, v3_stds   = [], []
        for beam, axial in combos:
            vals2 = [r["v2_mass"] for r in rows if r["size"] == size and r["beam"] == beam and r["axial"] == axial]
            vals3 = [r["v3_mass"] for r in rows if r["size"] == size and r["beam"] == beam and r["axial"] == axial]
            v2_means.append(np.mean(vals2) if vals2 else 0)
            v2_stds.append(np.std(vals2) if len(vals2) > 1 else 0)
            v3_means.append(np.mean(vals3) if vals3 else 0)
            v3_stds.append(np.std(vals3) if len(vals3) > 1 else 0)

        bars2 = ax.bar(x - w/2, v2_means, w, yerr=v2_stds, capsize=3,
                       color=GREY, label="v2 (no torsional constraint)",
                       edgecolor="white", linewidth=0.5)
        bars3 = ax.bar(x + w/2, v3_means, w, yerr=v3_stds, capsize=3,
                       color=TEAL, label="v3 (torsional FOS ≥ 1.5)",
                       edgecolor="white", linewidth=0.5)

        # Mass ratio annotation above each group
        for i, (m2, m3) in enumerate(zip(v2_means, v3_means)):
            if m2 > 0:
                pct = 100 * (m3 - m2) / m2
                ax.text(x[i], max(m2, m3) + 0.5, f"+{pct:.0f}%",
                        ha="center", va="bottom", fontsize=7, color=AMBER)

        ax.set_ylabel("Mass (kg)", fontsize=10, color=NAVY)
        label_kw = f"{'10' if size == '10kw' else '50'} kW"
        ax.set_title(label_kw, fontsize=12, color=NAVY, loc="left", pad=4)
        ax.legend(loc="upper left", fontsize=9)
        ax.set_facecolor("#F8FAFC")
        ax.spines["top"].set_visible(False)
        ax.spines["right"].set_visible(False)
        ax.yaxis.grid(True, alpha=0.4)
        ax.set_axisbelow(True)

    xtick_labels = [combo_label(b, a) for b, a in combos]
    axes[-1].set_xticks(x)
    axes[-1].set_xticklabels(xtick_labels, fontsize=8, rotation=30, ha="right")

    # Beam-section separators
    for ax in axes:
        for sep in [5, 10]:
            ax.axvline(sep - 0.5, color="grey", linewidth=0.5, linestyle="--", alpha=0.5)

    plt.tight_layout(rect=[0, 0, 1, 0.97])
    plt.savefig(out_path, dpi=180, bbox_inches="tight")
    plt.close()
    print(f"Saved {out_path}")


def fig_geometry_shift(rows: list[dict], out_path: Path):
    """Scatter: v2 taper vs v3 taper  +  v2 r_hub vs v3 r_hub."""
    fig, axes = plt.subplots(1, 2, figsize=(13, 5.5), facecolor="white")
    fig.suptitle("Geometry change driven by torsional constraint",
                 fontsize=13, fontweight="bold", color=NAVY)

    colours = {("10kw", "airfoil"): "#E07B00",
               ("10kw", "circular"): "#007A87",
               ("10kw", "elliptical"): "#2B8A3E",
               ("50kw", "airfoil"): "#C44D34",
               ("50kw", "circular"): "#3B69CC",
               ("50kw", "elliptical"): "#7B4DB5"}

    # taper scatter
    ax = axes[0]
    for size in SIZES:
        for beam in BEAMS:
            subset = [r for r in rows if r["size"] == size and r["beam"] == beam]
            if not subset:
                continue
            v2t = [r["v2_taper"] for r in subset]
            v3t = [r["v3_taper"] for r in subset]
            col = colours.get((size, beam), "grey")
            label = f"{size.upper()} {BEAM_LABELS[beam]}"
            ax.scatter(v2t, v3t, c=col, label=label, s=60, alpha=0.8,
                       edgecolors="white", linewidth=0.5)

    diag = np.linspace(0.2, 1.1, 50)
    ax.plot(diag, diag, "k--", linewidth=0.8, alpha=0.4, label="no change")
    ax.axhline(1.0, color="red", linewidth=0.8, linestyle=":", alpha=0.6,
               label="taper = 1.0 (cylindrical)")
    ax.set_xlabel("v2 taper_ratio", fontsize=10)
    ax.set_ylabel("v3 taper_ratio", fontsize=10)
    ax.set_title("Taper ratio shift", fontsize=11, color=NAVY)
    ax.legend(fontsize=7, loc="lower right")
    ax.set_facecolor("#F8FAFC")
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)

    # r_hub scatter
    ax = axes[1]
    for size in SIZES:
        for beam in BEAMS:
            subset = [r for r in rows if r["size"] == size and r["beam"] == beam]
            if not subset:
                continue
            v2r = [r["v2_r_hub"] for r in subset]
            v3r = [r["v3_r_hub"] for r in subset]
            col = colours.get((size, beam), "grey")
            label = f"{size.upper()} {BEAM_LABELS[beam]}"
            ax.scatter(v2r, v3r, c=col, label=label, s=60, alpha=0.8,
                       edgecolors="white", linewidth=0.5)

    diag_r = np.linspace(1.0, 8.0, 50)
    ax.plot(diag_r, diag_r, "k--", linewidth=0.8, alpha=0.4, label="no change")
    ax.set_xlabel("v2 r_hub (m)", fontsize=10)
    ax.set_ylabel("v3 r_hub (m)", fontsize=10)
    ax.set_title("Hub radius shift", fontsize=11, color=NAVY)
    ax.legend(fontsize=7, loc="upper left")
    ax.set_facecolor("#F8FAFC")
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)

    plt.tight_layout()
    plt.savefig(out_path, dpi=180, bbox_inches="tight")
    plt.close()
    print(f"Saved {out_path}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--v3-dir", type=Path, default=V3_DIR,
                        help="Path to trpt_opt_v3 results directory")
    args = parser.parse_args()
    v3_dir = args.v3_dir

    cart_dir = v3_dir / "cartography"
    cart_dir.mkdir(parents=True, exist_ok=True)

    print(f"Loading v2 from: {V2_DIR}")
    print(f"Loading v3 from: {v3_dir}")

    data = load_all(v3_dir)
    rows = build_comparison_table(data)
    print(f"Loaded {len(rows)} matched pairs")

    print_summary(rows)

    fig_mass_comparison(rows, cart_dir / "fig_v2_vs_v3_mass_comparison.png")
    fig_geometry_shift(rows, cart_dir / "fig_v3_geometry_shift.png")

    print(f"\nAll figures saved to {cart_dir}")


if __name__ == "__main__":
    main()

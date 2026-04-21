#!/usr/bin/env python3
"""scripts/plot_phase_f_sensitivity.py
Phase F — knuckle mass and line-count sensitivity study.
Consumes the LHS CSVs and the per-island elite archives to answer:

  1. How does optimum mass depend on n_lines (3..8)?
  2. How does optimum mass depend on knuckle_mass_kg?
  3. Does the best knuckle/line choice depend on config (10 vs 50 kW)
     or beam profile (circular / elliptical / airfoil)?

Outputs to scripts/results/trpt_opt_v2/cartography/:
  fig_phase_f_nlines_envelope.png     (min mass vs n_lines, faceted by config)
  fig_phase_f_knuckle_mass.png        (min mass vs knuckle_mass)
  fig_phase_f_combined_surface.png    (2-D heatmap n_lines × knuckle_mass)
"""
from pathlib import Path
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

REPO = Path(__file__).resolve().parent.parent
LHS  = REPO / "scripts" / "results" / "trpt_opt_v2" / "lhs"
OUT  = REPO / "scripts" / "results" / "trpt_opt_v2" / "cartography"
OUT.mkdir(parents=True, exist_ok=True)
plt.style.use("dark_background")


def load_all():
    frames = []
    for csv in LHS.glob("*.csv"):
        df = pd.read_csv(csv)
        parts = csv.stem.split("_")
        df["config"] = parts[0]; df["beam"] = parts[1]
        frames.append(df)
    # Also gather elite archives from completed DE islands
    arc_dir = REPO / "scripts" / "results" / "trpt_opt_v2"
    for arc in arc_dir.glob("*/elite_archive.csv"):
        try:
            df = pd.read_csv(arc)
        except Exception:
            continue
        if len(df) == 0: continue
        stem = arc.parent.name
        parts = stem.split("_")
        df["config"] = parts[0]; df["beam"] = parts[1]
        df["feasible"] = df["feasible"].astype(bool) if "feasible" in df else True
        df.rename(columns={"mass_kg": "mass_kg",
                            "min_fos": "min_fos"}, inplace=True)
        df["source"] = "DE-archive"
        frames.append(df)
    return pd.concat(frames, ignore_index=True)


def fig_nlines_envelope(df, out_path):
    d = df[df.feasible].copy()
    fig, axes = plt.subplots(1, 2, figsize=(12, 5), dpi=130, sharey=False)
    for ax, cfg in zip(axes, ["10kw", "50kw"]):
        sub = d[d.config == cfg]
        for beam, color in zip(["circular", "elliptical", "airfoil"],
                                ["#3DCFFF", "#FFB840", "#FF6464"]):
            s2 = sub[sub.beam == beam]
            env = s2.groupby("n_lines").mass_kg.min()
            ax.plot(env.index, env.values, "o-", lw=2.0, color=color, label=beam)
        ax.set_xlabel("n_lines (= n_polygon_sides = n_blades)")
        ax.set_ylabel("min feasible mass (kg)")
        ax.set_yscale("log")
        ax.set_title(f"{cfg} — min mass envelope vs n_lines",
                     color="white", pad=8)
        ax.grid(alpha=0.3, which="both")
        ax.legend(fontsize=9)
        ax.set_xticks(range(3, 9))
    fig.tight_layout(); fig.savefig(out_path, facecolor=fig.get_facecolor())
    plt.close(fig); print(f"wrote {out_path}")


def fig_knuckle_mass(df, out_path):
    d = df[df.feasible].copy()
    fig, axes = plt.subplots(1, 2, figsize=(12, 5), dpi=130, sharey=False)
    for ax, cfg in zip(axes, ["10kw", "50kw"]):
        sub = d[d.config == cfg]
        bins = np.linspace(sub.knuckle_mass_kg.min(),
                           sub.knuckle_mass_kg.max(), 25)
        for beam, color in zip(["circular", "elliptical", "airfoil"],
                                ["#3DCFFF", "#FFB840", "#FF6464"]):
            s2 = sub[sub.beam == beam]
            idx = np.digitize(s2.knuckle_mass_kg, bins) - 1
            idx = np.clip(idx, 0, len(bins)-2)
            env = pd.Series(s2.mass_kg.values).groupby(idx).min()
            x = 0.5 * (bins[:-1] + bins[1:])
            y = np.full(len(x), np.nan)
            y[env.index.values.astype(int)] = env.values
            ax.plot(x*1000, y, "o-", lw=1.8, color=color, label=beam, alpha=0.9)
        ax.set_xlabel("knuckle mass (g)")
        ax.set_ylabel("min feasible mass (kg)")
        ax.set_yscale("log")
        ax.set_title(f"{cfg} — min mass envelope vs knuckle mass",
                     color="white", pad=8)
        ax.grid(alpha=0.3, which="both"); ax.legend(fontsize=9)
    fig.tight_layout(); fig.savefig(out_path, facecolor=fig.get_facecolor())
    plt.close(fig); print(f"wrote {out_path}")


def fig_combined_surface(df, out_path):
    d = df[df.feasible & (df.config == "10kw") & (df.beam == "circular")]
    if len(d) == 0: return
    nlines = np.arange(3, 9)
    kbins  = np.linspace(d.knuckle_mass_kg.min(), d.knuckle_mass_kg.max(), 20)
    Z = np.full((len(kbins)-1, len(nlines)), np.nan)
    for i, nl in enumerate(nlines):
        sub = d[d.n_lines == nl]
        if len(sub) == 0: continue
        idx = np.digitize(sub.knuckle_mass_kg, kbins) - 1
        idx = np.clip(idx, 0, len(kbins)-2)
        for j in range(len(kbins)-1):
            m = sub[idx == j]
            if len(m) > 0:
                Z[j, i] = m.mass_kg.min()
    X, Y = np.meshgrid(nlines, 0.5*(kbins[:-1]+kbins[1:]))
    fig, ax = plt.subplots(figsize=(9, 5.6), dpi=130)
    pcm = ax.pcolormesh(X, Y*1000, Z, cmap="viridis_r", shading="auto")
    cb = fig.colorbar(pcm, ax=ax, label="min feasible mass (kg)")
    ax.set_xlabel("n_lines"); ax.set_ylabel("knuckle mass (g)")
    ax.set_title("10 kW circular — min feasible mass surface\n"
                 "(n_lines × knuckle_mass, LHS data)",
                 color="white", pad=10)
    ax.grid(alpha=0.2, color="white")
    fig.tight_layout(); fig.savefig(out_path, facecolor=fig.get_facecolor())
    plt.close(fig); print(f"wrote {out_path}")


def fig_feasibility_by_nlines(df, out_path):
    g = df.groupby(["config", "n_lines"]).agg(
        feasible_frac=("feasible", "mean"),
        n=("feasible", "size"),
    ).reset_index()
    fig, ax = plt.subplots(figsize=(8.5, 4.8), dpi=130)
    for cfg, color in zip(["10kw", "50kw"], ["#3DCFFF", "#FFB840"]):
        s = g[g.config == cfg]
        ax.plot(s.n_lines, 100*s.feasible_frac, "o-", color=color,
                lw=2.0, label=cfg)
    ax.set_xlabel("n_lines"); ax.set_ylabel("feasibility rate (%)")
    ax.set_title("Phase F — feasibility vs n_lines (LHS, all beams pooled)",
                 color="white", pad=10)
    ax.grid(alpha=0.3); ax.legend(fontsize=10)
    ax.set_xticks(range(3, 9))
    fig.tight_layout(); fig.savefig(out_path, facecolor=fig.get_facecolor())
    plt.close(fig); print(f"wrote {out_path}")


if __name__ == "__main__":
    df = load_all()
    fig_nlines_envelope(df, OUT / "fig_phase_f_nlines_envelope.png")
    fig_knuckle_mass(df, OUT / "fig_phase_f_knuckle_mass.png")
    fig_combined_surface(df, OUT / "fig_phase_f_combined_surface.png")
    fig_feasibility_by_nlines(df, OUT / "fig_phase_f_feasibility_by_nlines.png")

    # Print the best (cfg, n_lines, knuckle) triples
    feas = df[df.feasible].copy()
    if len(feas) > 0:
        idx = feas.groupby(["config", "beam", "n_lines"]).mass_kg.idxmin()
        tbl = feas.loc[idx, ["config", "beam", "n_lines",
                              "knuckle_mass_kg", "mass_kg", "r_hub_m",
                              "n_rings", "axial_idx"]]
        tbl.to_csv(OUT / "phase_f_best_per_nlines.csv", index=False)
        print(f"wrote {OUT/'phase_f_best_per_nlines.csv'}")
        print(tbl.round(3).to_string(index=False))

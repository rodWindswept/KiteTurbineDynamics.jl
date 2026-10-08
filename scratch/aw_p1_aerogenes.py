#!/usr/bin/env python3
"""Phase 1 aero-gene half: binned conditioning + reject-rate profiles +
effect-size ranking + priority questions + charts.
Genes: n_active (rotor count), bank_top, bank_bot, blade_scale_top,
blade_scale_bottom. Metrics: P_mean, T_lift, FoS, fitness, clearance.
Dataset: signed bankderate2 results (master 894fc11). Bins on EVALUATED values
(decoded columns; x4/x6 trap noted by science-validator does not apply to the
decoded columns used here)."""
import pandas as pd
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import os

BASE = "/home/rod/Documents/GitHub/ktd-aw-fire/scripts/results/v13_5kw_masslift_len18.8_rotorcount_bankderate2"
OUT = "/home/rod/Documents/GitHub/ktd-aw-fire/scratch/aw_p1_aerogenes"
os.makedirs(OUT, exist_ok=True)

frames = [pd.read_csv(f"{BASE}/island_{i}/telemetry.csv", comment="#", skip_blank_lines=True) for i in (1, 2, 3)]
d = pd.concat(frames, ignore_index=True)
d = d[d["status"].isin(["ok", "reject", "clearance_reject", "reject_twist"])].copy()
ok = d[d.status == "ok"].copy()
N_OK = len(ok)
print(f"rows {len(d)} ok {N_OK} base ok rate {N_OK/len(d):.3f}")

METRICS = ["P_mean", "T_lift", "FoS", "fitness", "clearance"]
GENES = {
    "n_active":           {"bins": [0.5, 1.5, 2.5, 3.5], "labels": ["1", "2", "3"]},
    "bank_top":           {"bins": [0, 4, 8, 12, 16, 20, 25.01], "labels": ["[0,4)", "[4,8)", "[8,12)", "[12,16)", "[16,20)", "[20,25]"]},
    "bank_bot":           {"bins": [0, 4, 8, 12, 16, 20, 25.01], "labels": ["[0,4)", "[4,8)", "[8,12)", "[12,16)", "[16,20)", "[20,25]"]},
    "blade_scale_top":    {"bins": [0.2, 0.7, 0.8, 0.9, 0.95, 1.0001], "labels": ["[0.2,0.7)", "[0.7,0.8)", "[0.8,0.9)", "[0.9,0.95)", "[0.95,1.0]"]},
    "blade_scale_bottom": {"bins": [0.2, 0.4, 0.6, 0.8, 0.9, 1.0001], "labels": ["[0.2,0.4)", "[0.4,0.6)", "[0.6,0.8)", "[0.8,0.9)", "[0.9,1.0]"]},
}

def bin_column(series, edges):
    return pd.cut(series, bins=edges, right=False, labels=range(len(edges) - 1))

report = []
# ---------------- effect size + conditioned table ----------------
effect = []
for gene, spec in GENES.items():
    edges = spec["bins"]; labels = spec["labels"]
    d["_bin"] = pd.cut(d[gene], bins=edges, right=False, labels=labels)
    ok["_bin"] = pd.cut(ok[gene], bins=edges, right=False, labels=labels)
    rows = []
    # draws per bin, ok rate per bin
    counts = d.groupby("_bin", observed=True).size()
    okr = d.groupby("_bin", observed=True)["status"].apply(lambda s: (s == "ok").mean())
    sts = pd.crosstab(d["_bin"], d["status"])
    for lb in labels:
        n_bin = counts.get(lb, 0)
        ok_f = okr.get(lb, np.nan)
        sub = ok[ok["_bin"] == lb]
        r = {"gene": gene, "bin": lb, "n_draws": int(n_bin), "n_ok": len(sub),
             "ok_frac": round(ok_f, 3) if n_bin else None,
             "reject_frac": round(sts.loc[lb, "reject"] / n_bin, 3) if (lb in sts.index and n_bin) else None,
             "clr_frac": round(sts.loc[lb, "clearance_reject"] / n_bin, 3) if (lb in sts.index and n_bin) else None,
             "twist_frac": round(sts.loc[lb, "reject_twist"] / n_bin, 3) if (lb in sts.index and n_bin) else None}
        for m in METRICS:
            if len(sub):
                r[f"{m}_mean"] = round(sub[m].mean(), 3)
                r[f"{m}_std"] = round(sub[m].std(), 3)
            else:
                r[f"{m}_mean"] = None; r[f"{m}_std"] = None
        rows.append(r)
        report.append(r)
    # effect size: bin-mean range / pooled std, and ok-rate range
    for m in METRICS:
        ms = [r[f"{m}_mean"] for r in rows if r[f"{m}_mean"] is not None]
        if len(ms) >= 2:
            pooled = ok[m].std()
            effect.append((gene, m, (max(ms) - min(ms)) / pooled))
    ofs = [r["ok_frac"] for r in rows if r["ok_frac"] is not None]
    effect.append((gene, "ok_rate", max(ofs) - min(ofs)))
    # spread of P_mean within ok set (dead-gene check)
    pm = [r["P_mean_mean"] for r in rows if r["P_mean_mean"] is not None]
    print(f"{gene:>20}: P_mean bin-range {max(pm)-min(pm):.3f} kW  ok_rate range {max(ofs)-min(ofs):.3f}  draws per bin {[r['n_draws'] for r in rows]}")

tbl = pd.DataFrame(report)
tbl.to_csv(f"{OUT}/aerogene_conditioned_table.csv", index=False)
ef = pd.DataFrame(effect, columns=["gene", "metric", "eff"])
ef_pivot = ef.pivot_table(index="gene", columns="metric", values="eff")
ef_pivot["mean_abs_eff"] = ef_pivot[METRICS].abs().mean(axis=1)
ef_pivot = ef_pivot.sort_values("mean_abs_eff", ascending=False)
ef_pivot.to_csv(f"{OUT}/aerogene_effect_size.csv")
print("\nEFFECT SIZE (bin-mean range / pooled std):")
print(ef_pivot.round(3).to_string())

# ---------------- priority Q1: rotor count survival ----------------
print("\nPRIORITY Q1 rotor_count {1,2,3} survival")
ct = pd.crosstab(d.n_active, d.status)
print(ct.to_string())
for r in [1, 2, 3]:
    sub = d[d.n_active == r]
    so = sub[sub.status == "ok"]
    print(f"n_active={r}: draws {len(sub)}, ok {len(so)} ({len(so)/len(sub):.1%}), "
          f"P_mean ok {so.P_mean.mean():.2f} kW, T_lift ok {so.T_lift.mean():.0f} N, "
          f"FoS ok {so.FoS.mean():.2f}")
# what kills count=2 and 3 (excluding clearance): reject status breakdown by bank draw
for r in [2, 3]:
    sub = d[d.n_active == r]
    print(f"  n_active={r} status mix: {dict(sub.status.value_counts())}")
# the two n=2 survivors
n2 = ok[ok.n_active == 2]
print("\nTwo n=2 survivors:")
print(n2[["island", "gen", "fitness", "P_mean", "T_lift", "FoS", "clearance", "n_lines", "rings", "bank_top", "bank_bot", "blade_scale_top", "blade_scale_bottom"]].to_string())

# ---------------- priority Q2: bank saturation ----------------
print("\nPRIORITY Q2 bank saturation at 22 deg bound")
bb_top = d[d.bank_top >= 21.9]
bb_bot = d[d.bank_bot >= 21.9]
print(f"bank_top at ceiling (>=21.9): draws {len(bb_top)}, ok {sum(bb_top.status=='ok')} ({sum(bb_top.status=='ok')/len(bb_top):.1%})")
print(f"bank_bot at ceiling (>=21.9): draws {len(bb_bot)}, ok {sum(bb_bot.status=='ok')} ({sum(bb_bot.status=='ok')/len(bb_bot):.1%})")
import math
derate = math.cos(math.radians(22)) ** 2.65
print(f"cos(22)^2.65 = {derate:.4f}  -> 22 deg bank costs {100*(1-derate):.1f}% of that rotor's power")
# correlation of bank with clearance and T_lift on ok rows
for g in ["bank_top", "bank_bot"]:
    for m in ["clearance", "T_lift", "FoS", "P_mean"]:
        print(f"  spearman({g}, {m}) = {ok[g].corr(ok[m], method='spearman'):+.3f}")

# ---------------- island-2 bank_top sub-10.26 rows ----------------
print("\nIsland-2 bank_top < 10.26 rows (13 draws per audit):")
i2 = d[(d.island == 2) & (d.bank_top < 10.26)]
print(i2[["gen", "idx", "fitness", "status", "P_mean", "T_lift", "FoS", "clearance", "bank_top", "bank_bot"]].to_string())
print("status mix:", dict(i2.status.value_counts()))

# ---------------- twist rejects: gene profile ----------------
tw = d[d.status == "reject_twist"]
print("\nTwist-reject rows (11): gene values")
print(tw[["island", "bank_top", "bank_bot", "blade_scale_top", "blade_scale_bottom", "n_active", "twist_ratio", "fitness"]].to_string())

# ---------------- charts ----------------
plt.rcParams.update({"figure.dpi": 110, "font.size": 9})
metric_labels = {"P_mean": "P_mean (kW)", "T_lift": "T_lift (N)", "FoS": "FoS",
                 "fitness": "fitness", "clearance": "clearance (m)"}
fig, axes = plt.subplots(3, 2, figsize=(12, 15))
for ax, (gene, spec) in zip(axes.flat, GENES.items()):
    edges = spec["bins"]; labels = spec["labels"]
    xs = np.arange(len(labels))
    sub = ok[ok[gene].notna()]
    binned = pd.cut(sub[gene], bins=edges, right=False, labels=labels)
    means = sub.groupby(binned, observed=True)["P_mean"].mean()
    stds = sub.groupby(binned, observed=True)["P_mean"].std()
    counts = pd.cut(d[gene], bins=edges, right=False, labels=labels).value_counts().reindex(labels)
    okr = pd.cut(d[gene], bins=edges, right=False, labels=labels)
    ok_rate = d.assign(b=okr).groupby("b", observed=True)["status"].apply(lambda s: (s == "ok").mean()).reindex(labels)
    ax2 = ax.twinx()
    ax.errorbar(xs, means.reindex(labels), yerr=stds.reindex(labels), fmt="o-", color="#1f6fb2", capsize=3, label="P_mean (ok rows)")
    ax2.plot(xs, ok_rate * 100, "s--", color="#c26a1f", label="ok-rate (%)")
    ax.set_xticks(xs); ax.set_xticklabels(labels, rotation=45, ha="right")
    ax.set_ylabel("P_mean (kW)"); ax2.set_ylabel("survival (%)")
    ax.set_title(f"{gene} (n_ok per bin: {list(means.reindex(labels).fillna(0).astype(int))})")
    ax.grid(alpha=0.3)
    lines = ax.get_lines() + ax2.get_lines()
    ax.legend(lines, [l.get_label() for l in lines], loc="best", fontsize=7)
axes.flat[-1].axis("off")
fig.suptitle("bankderate2 508-ok landscape: aero-gene conditioning (Phase 1, aero half)", y=0.995)
fig.tight_layout()
fig.savefig(f"{OUT}/aerogene_conditioning.png", bbox_inches="tight")
print(f"\ncharts written to {OUT}")

#!/usr/bin/env python3
"""fig-cg extract: the machine-corner-grid render extract (figure map row 23).

Mints `docs/reporting/figures/machine-corner-grid/extract-corner-grid.csv`
from the signed corner picks (NR-051). The projection replicates the
certified pca-landscape kit exactly; every NR-044 anchor re-verifies
before any row writes. The genome tokens copy byte-exact from the
source telemetry rows.

Run: /usr/bin/python3 scratch/fig_cg_extract.py    (repo root)
"""
import csv
import hashlib
import subprocess
from datetime import datetime
from pathlib import Path

import numpy as np

REPO = Path(".")
RD = REPO / "scripts" / "results" / "v13_5kw_masslift_len18.8_rotorcount_bankderate2"
ISLANDS = (1, 2, 3)
OUT = REPO / "docs" / "reporting" / "figures" / "machine-corner-grid"
CSV_OUT = OUT / "extract-corner-grid.csv"
LOG_OUT = OUT / "extract-corner-grid.log"

RECORDED = [
    ("low PC1 / low PC2", "i1-g13-i1"),
    ("low PC1 / high PC2", "i1-g7-i7"),
    ("high PC1 / low PC2", "i2-g21-i4"),
    ("high PC1 / high PC2", "i3-g26-i8"),
]
BLOCK = ["island", "gen", "idx", "fitness", "status", "P_mean", "P_end",
         "T_lift", "FoS", "twist_crossed", "twist_ratio", "clearance",
         "n_lines", "rings", "n_active", "r_hub", "r_bot", "bank_top",
         "bank_bot", "blade_scale_top", "blade_scale_bottom", "tether",
         "x1", "x2", "x3", "x4", "x5", "x6", "x7", "x8", "x9", "x10"]
EXPECT_FIT = {"low PC1 / low PC2": "60.646", "low PC1 / high PC2": "58.864",
              "high PC1 / low PC2": "33.704", "high PC1 / high PC2": "33.812"}


def sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def load():
    rows, raw = [], []
    for isl in ISLANDS:
        p = RD / f"island_{isl}" / "telemetry.csv"
        lines = [ln for ln in p.read_text().splitlines()
                 if not ln.startswith("#") and ln.strip()]
        rows.extend(list(csv.DictReader(lines)))
        raw.extend(lines[1:])
    return rows, raw


def main():
    lines = []

    def say(s=""):
        lines.append(s)
        print(s)

    rows, raw = load()
    head = (RD / "island_1" / "telemetry.csv").read_text().splitlines()[0]
    era = [t for t in head.split() if t.startswith("era=")][0][4:]
    git = [t for t in head.split() if t.startswith("git=")][0][4:]

    X = np.array([[float(r[f"x{i}"]) for i in range(1, 11)] for r in rows])
    fit = np.array([float(r["fitness"]) for r in rows])
    st = np.array([r["status"] for r in rows])
    feas = (st == "ok") & (fit < 1e6)
    isl = np.array([int(r["island"]) for r in rows])
    gen = np.array([int(r["gen"]) for r in rows])
    idx = np.array([int(r["idx"]) for r in rows])

    mu = X.mean(axis=0)
    sd = X.std(axis=0, ddof=1)
    Xc = (X - mu) / sd
    _, S, Vt = np.linalg.svd(Xc, full_matrices=False)
    var = S ** 2 / (S ** 2).sum()
    V = Vt.T
    pc1 = Xc @ V[:, 0]
    pc2 = Xc @ V[:, 1]

    seed_i = int(np.where((isl == 1) & (gen == 0))[0][0])
    win_i = int(np.argmin(np.where(feas, fit, np.inf)))
    checks = []

    def chk(name, got, want):
        checks.append((name, got == want, got, want))

    chk("rows", len(rows), 930)
    chk("feasible rows", int(feas.sum()), 508)
    chk("PC1 share x1e6", int(round(var[0] * 1e6)), int(round(0.22434667 * 1e6)))
    chk("PC2 share x1e6", int(round(var[1] * 1e6)), int(round(0.17263044 * 1e6)))
    chk("seed pc1 3dp", round(float(pc1[seed_i]), 3), 0.531)
    chk("seed pc2 3dp", round(float(pc2[seed_i]), 3), -1.297)
    chk("winner pc1 3dp", round(float(pc1[win_i]), 3), 0.885)
    chk("winner pc2 3dp", round(float(pc2[win_i]), 3), 2.869)
    chk("seed fit", round(float(fit[seed_i]), 3), 36.109)
    chk("winner fit", round(float(fit[win_i]), 3), 27.364)
    chk("winner island", int(isl[win_i]), 3)
    share_ok = (abs(var[0] * 100 - 22.4346665772) < 5e-10
                and abs(var[1] * 100 - 17.2630436556) < 5e-10)
    checks.append(("shares 10dp basis", share_ok, f"{var[0]*100:.10f}/{var[1]*100:.10f}",
                   "22.4346665772/17.2630436556"))

    ok = all(c[1] for c in checks)
    say("machine-corner-grid / extract-corner-grid")
    say("generated: " + datetime.now().isoformat(timespec="milliseconds"))
    say("run-id: corner-grid-extract-2026-10-15-picks")
    say("dataset: v13_5kw_masslift_len18.8_rotorcount_bankderate2 | "
        "data commit dd3cc6a | launch a76c5e9")
    say("physics era: " + era)
    script_commit = subprocess.run(
        ["git", "log", "-1", "--format=%H", "--", "scratch/fig_cg_extract.py"],
        capture_output=True, text=True).stdout.strip() or "(uncommitted)"
    say("script commit: " + script_commit)
    say("worktree: dirty (other seats' files present; this mint reads only committed data)")
    say("inputs:")
    for isl_n in ISLANDS:
        p = RD / f"island_{isl_n}" / "telemetry.csv"
        say(f"  island_{isl_n}/telemetry.csv sha256 {sha256(p)}")
    say("")
    say("ANCHORS (NR-044, re-verified before any row writes)")
    for name, good, got, want in checks:
        say(f"  {name}: {got}  ({'OK' if good else 'FAIL want ' + str(want)})")
    if not ok:
        say("RESULT: FAIL - no row writes")
        LOG_OUT.write_text("\n".join(lines) + "\n")
        raise SystemExit(1)

    x1w, x2w = np.percentile(pc1, [1, 99])
    y1w, y2w = np.percentile(pc2, [1, 99])
    say(f"window: pc1 [{x1w:.3f}, {x2w:.3f}]  pc2 [{y1w:.3f}, {y2w:.3f}]")
    corners = {
        "low PC1 / low PC2": (x1w, y1w),
        "low PC1 / high PC2": (x1w, y2w),
        "high PC1 / low PC2": (x2w, y1w),
        "high PC1 / high PC2": (x2w, y2w),
    }

    say("")
    say("PICKS (the signed set, NR-051)")
    out_rows = []
    pick_ok = True
    for cname, tag in RECORDED:
        cx, cy = corners[cname]
        d = np.hypot(pc1 - cx, pc2 - cy)
        i = int(np.argmin(np.where(feas, d, np.inf)))
        got = f"i{isl[i]}-g{gen[i]}-i{idx[i]}"
        good = got == tag
        pick_ok = pick_ok and good
        say(f"  {cname}: {got}  pc ({pc1[i]:.6f}, {pc2[i]:.6f})  "
            f"dist {d[i]:.6f}  fit {fit[i]:.6f}"
            + ("" if good else f"  FAIL want {tag}"))
        row = rows[i]
        out_rows.append([cname, tag] + [row[c] for c in BLOCK]
                        + [repr(float(pc1[i])), repr(float(pc2[i]))])
    if not pick_ok:
        say("RESULT: FAIL - the picks do not match the signed set; no row writes")
        LOG_OUT.write_text("\n".join(lines) + "\n")
        raise SystemExit(1)

    OUT.mkdir(parents=True, exist_ok=True)
    hdr = [
        "# machine-corner-grid / extract-corner-grid.csv",
        "# run-id: corner-grid-extract-2026-10-15-picks",
        "# dataset: v13_5kw_masslift_len18.8_rotorcount_bankderate2 | "
        "data commit dd3cc6a | launch a76c5e9",
        f"# provenance: era={era}  telemetry git={git}",
        "# source: the island telemetry rows named by the tag column; "
        "picks per NR-051; projection per NR-044",
        "# selection: for each [1,99] percentile window corner of the "
        "certified PC1-PC2 projection, the feasible (ok) design of least "
        "Euclidean distance; one pick per corner; no interpolation",
        "# display: the objective prints at 3 dp (NR-051); the identity "
        "prints as the island-gen-idx tag",
        "# gene slots: x1 r_hub | x2 r_bot | x3 target_Lr | x4 n_lines | "
        "x5 density_profile | x6 rotor-mask proxy | x7 bank_top | "
        "x8 bank_bot | x9 blade_scale_top | x10 blade_scale_bottom",
        f"# computing commit: {script_commit}",
    ]
    col = ["corner", "tag"] + BLOCK + ["pc1", "pc2"]
    with CSV_OUT.open("w", newline="") as f:
        for h in hdr:
            f.write(h + "\n")
        w = csv.writer(f, lineterminator="\n")
        w.writerow(col)
        for out in out_rows:
            w.writerow(out)

    # the extract re-reads: tokens byte-check against the source rows
    reread = [ln for ln in CSV_OUT.read_text().splitlines() if not ln.startswith("#")]
    rrows = list(csv.DictReader(reread))
    byte_ok = len(rrows) == 4
    byte_n = 0
    pc_ok = True
    for r in rrows:
        pt = r["tag"].split("-")
        islv, g, j = pt[0][1:], pt[1][1:], pt[2][1:]
        cand = [ln for ln in raw if ln.startswith(f"{islv},{g},{j},")]
        if len(cand) != 1:
            byte_ok = False
            continue
        parts = cand[0].split(",")
        for k, c in enumerate(BLOCK):
            byte_n += 1
            if parts[k] != r[c]:
                byte_ok = False
        if repr(float(r["pc1"])) != r["pc1"] or repr(float(r["pc2"])) != r["pc2"]:
            pc_ok = False

    say("")
    say("CERTIFICATE")
    say(f"  [1] NR-044 anchors: {sum(1 for c in checks if c[1])} of {len(checks)} gate passed")
    say(f"  [2] the picks equal the signed set (NR-051): {'PASS' if pick_ok else 'FAIL'}")
    say(f"  [3] the tokens byte-read from the source rows, {byte_n} fields: {'PASS' if byte_ok else 'FAIL'}")
    fit_ok = all(r["fitness"] == EXPECT_FIT[r["corner"]] for r in rrows)
    say(f"  [4] the objective forms read the NR-051 display set (60.646 / 58.864 / 33.704 / 33.812): "
        f"{'PASS' if fit_ok else 'FAIL'}")
    feas_ok = all(r["status"] == "ok" and float(r["fitness"]) < 1e6
                  and float(r["fitness"]) > 27.364 for r in rrows)
    say(f"  [5] feasibility and the objective bound above the winner: {'PASS' if feas_ok else 'FAIL'}")
    say(f"  [6] the pc columns re-read as written: {'PASS' if pc_ok else 'FAIL'}")
    say("")
    say("BOUNDARIES (travel with this extract)")
    say("  - the projection reads the raw draw columns x1..x10 (NR-044 boundary 1)")
    say("  - the picks are typical machines, not optima (NR-051 boundary 2)")
    say("  - the recorded diagonal cross-check note holds (NR-051 boundary 3)")
    say("")
    say("RENDER-SET USE")
    say("  - the family-grid mode of the machine-renderer SPEC (corner variant):")
    say("    four panels, one per corner, one fixed scale at GENERATE")
    say("")
    say("OUTPUTS")
    say("  extract-corner-grid.csv sha256 " + sha256(CSV_OUT))

    LOG_OUT.write_text("\n".join(lines) + "\n")
    ok_all = ok and pick_ok and byte_ok and fit_ok and feas_ok and pc_ok
    print("RESULT:", "PASS" if ok_all else "FAIL")
    raise SystemExit(0 if ok_all else 1)


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""aero-validator counter-read: F-VALUE + kit pins for the two section 2.3 plates.

Kits: eval-timeline (figure-map row 4), k-basis (row 5).

Checks, per kit:
  S1  pins — every manifest sha256 recomputes from the committed bytes.
  S2  F-VALUE — every drawn value recomputes from the committed inputs and
      equals its signed register form at the stated precision.
  S3  F-REPRO counter-run — two fresh runs per kit, byte-compared to the
      committed outputs, the manifest and the checks log.

Reads committed bytes only. Writes only under the scratch outdir.
"""
import csv, hashlib, html, json, re, subprocess, sys
from pathlib import Path

REPO = Path("/home/rod/Documents/GitHub/KiteTurbineDynamics.jl")
OUT = Path("/home/rod/.hermes/profiles/aero-validator/cache/scratch/fvalue")
ETK = REPO / "docs/reporting/figures/eval-timeline"
KBK = REPO / "docs/reporting/figures/k-basis"
ETX = REPO / "docs/reporting/figures/eval-timeline-extract"
WTX = REPO / "docs/reporting/figures/window-trace-extract"

RESULTS = []


def ok(name, cond, detail=""):
    RESULTS.append(bool(cond))
    print(f"[{'PASS' if cond else 'FAIL'}] {name}" + (f"  [{detail}]" if detail else ""))
    return cond


def sha(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest()


def load_csv(p):
    with open(p, newline="", encoding="utf-8") as fh:
        lines = [ln for ln in fh if not ln.startswith("#")]
    return list(csv.DictReader(lines))


def textset(svg_path):
    raw = Path(svg_path).read_text()
    return {html.unescape(re.sub(r"<[^>]+>", "", m)).strip()
            for m in re.findall(r"<text[^>]*>(.*?)</text>", raw, flags=re.S)}


def has(ledger, *tokens):
    return any(all(t in ln for t in tokens) for ln in ledger)


print("== aero-validator figure-gate counter-read: eval-timeline (row 4) + k-basis (row 5) ==")
print("input: committed bytes at HEAD. runs and outputs under:", OUT)
print()

print("== S1. kit pins vs manifests ==")
for name, kit, script_name in (("eval-timeline", ETK, "eval-timeline.py"),
                               ("k-basis", KBK, "k-basis.py")):
    man = json.loads((kit / "manifest.json").read_text())
    for fname, pin in man["outputs"].items():
        got = sha(kit / fname)
        ok(f"{name} output pin {fname}", got == pin, f"pin {pin[:12]} got {got[:12]}")
    got = sha(REPO / man["script"]["path"])
    ok(f"{name} script pin {script_name}", got == man["script"]["sha256"],
       f"pin {man['script']['sha256'][:12]} got {got[:12]}")
    extracts = man["inputs"].get("extracts", [])
    if "extract" in man["inputs"]:
        extracts = [man["inputs"]["extract"]]
    for item in extracts:
        p = REPO / item["path"]
        got = sha(p)
        ok(f"{name} input pin {p.name}", got == item["sha256"],
           f"pin {item['sha256'][:12]} got {got[:12]}")

print()
print("== S2a. F-VALUE: eval-timeline recompute from committed extracts ==")
cold = load_csv(ETX / "extract-eval-timeline-cold.csv")
warm = load_csv(ETX / "extract-eval-timeline-warm.csv")
rule = load_csv(ETX / "extract-eval-timeline-warm-rulingmode.csv")
taps = load_csv(WTX / "extract-winner-window-taps.csv")
ok("ET row counts (5000/98/1823/52)",
   [len(cold), len(warm), len(rule), len(taps)] == [5000, 98, 1823, 52],
   f"{len(cold)}/{len(warm)}/{len(rule)}/{len(taps)}")
relax = sum(1 for r in taps if r["phase"] == "relax")
win = sum(1 for r in taps if r["phase"] == "window")
ok("ET tap phases (11 relax / 41 window)", (relax, win) == (11, 41), f"{relax}/{win}")
tw = [float(r["omega_gnd"]) for r in taps if r["phase"] == "window"]
tm = sum(tw) / len(tw)
ok("ET NR-029 window mean, full precision", abs(tm - 13.380259861740395) <= 1e-12, repr(tm))
ok("ET NR-029 drawn form 13.38", f"{tm:.2f}" == "13.38", f"{tm:.2f}")
ok("ET NR-016 drawn form 10.17", f"{10.169820334285198:.2f}" == "10.17")
ct = [float(r["t"]) for r in cold]
cP = [float(r["P_gen_kw"]) for r in cold]
winP = [p for t, p in zip(ct, cP) if t > 10.0]
Pbar = sum(winP) / len(winP)
ok("ET cold 100 Hz window mean P (not drawn)", abs(Pbar - 5.309770249764809) <= 1e-9,
   f"{Pbar!r}")
last5 = sum(cP[-5:]) / 5
tail45 = [p for t, p in zip(ct, cP) if t >= 45.0]
m45 = sum(tail45) / len(tail45)
print(f"  P_end bases: evaluator tail-5 (row) {5.314113662272673!r}; "
      f"100 Hz last-5-samples {last5!r}; 100 Hz t>=45 s mean {m45!r}")
ok("ET NR-008 drawn forms 5.309 / 5.314 (row basis)",
   f"{5.3087794439367935:.3f}" == "5.309" and f"{5.314113662272673:.3f}" == "5.314")
src = (REPO / "src/objective_evaluator.jl").read_text()
launch_src = subprocess.run(
    ["git", "show", "a76c5e9:src/objective_evaluator.jl"], cwd=str(REPO),
    capture_output=True, text=True).stdout
ok("ET 'last five' basis: evaluator tail-5 code present at HEAD and launch",
   "P_end = mean(P_finite[max(1, end - 4):end])" in src
   and "mean of the last 5 samples of the window" in src
   and "P_end = mean(P_finite[max(1, end - 4):end])" in launch_src)
ok("ET 100 Hz tail reads 5.314 at drawn precision", f"{last5:.3f}" == "5.314", repr(last5))
ok("ET cold latch count 0", sum(int(r["any_broken"]) for r in cold) == 0)
ok("ET ruling latch count 0", sum(int(r["any_broken"]) for r in rule) == 0)
wl = warm[-1]
wt = float(wl["t"])
wsl = float(wl["strain_max_over_break"])
ok("ET warm end t = 2.841 ms", abs(wt - 0.002841) <= 5e-7 and f"{wt * 1e3:.3f}" == "2.841", repr(wt))
ok("ET warm end strain 1.00081012", abs(wsl - 1.00081012) <= 5e-7, repr(wsl))
cross = next((i for i, r in enumerate(warm, 1) if float(r["strain_max_over_break"]) > 1.0), None)
ok("ET warm first crossing at step 97", cross == 97,
   f"step {cross}, strain {float(warm[96]['strain_max_over_break'])}")
gmaxr = max(rule, key=lambda r: float(r["strain_max_over_break"]))
gm = float(gmaxr["strain_max_over_break"])
gt = float(gmaxr["t"])
ok("ET ruling grid max 1.447982844", abs(gm - 1.447982844) <= 1e-9, repr(gm))
ok("ET ruling max at t = 5.798 ms", abs(gt - 0.005798) <= 5e-7 and f"{gt * 1e3:.3f}" == "5.798", repr(gt))
m60 = max(float(r["strain_max_over_break"]) for r in rule if float(r["t"]) > 0.060)
ok("ET post-60 ms max 0.677081", abs(m60 - 0.677080915) <= 1e-8, repr(m60))
ok("ET 100 Hz claim (5000 rows / 50 s)", abs(len(cold) / ct[-1] - 100.0) < 0.01,
   f"{len(cold) / ct[-1]:.4f} Hz")
led = (ETK / "label-ledger.txt").read_text().splitlines()
ok("ET ledger NR-016 form", has(led, "10.17", "NR-016"))
ok("ET ledger NR-029 form", has(led, "13.38", "NR-029"))
ok("ET ledger NR-008 pair", has(led, "5.309 kW", "5.314 kW", "NR-008"))
ok("ET ledger floor string", has(led, "5 kW floor", "P_end"))
ok("ET ledger warm annotation", has(led, "2.841 ms", "breaks"))
ok("ET ledger condition peak", has(led, "1.448", "5.798 ms"))
ok("ET ledger sources stamp", has(led, "data commit dd3cc6a", "trees 980de02 / 8d01394"))
ok("ET ledger rows stamp", has(led, "rows NR-008", "NR-013 ext", "script commit bb39aec"))
svgtxt = textset(ETK / "eval-timeline.svg")
ok("ET SVG text set == ledger set", svgtxt == set(led), f"{len(svgtxt)} strings")
print("  ET digit-bearing ledger strings:")
for ln in led:
    if any(c.isdigit() for c in ln):
        print("   |", ln)

print()
print("== S2b. F-VALUE: k-basis recompute from the committed sweep record ==")
kb = load_csv(REPO / "scripts/results/k_sweep_daisy_5kw.csv")
ok("KB rows 10", len(kb) == 10, f"{len(kb)}")
ks = [round(float(r["k"]), 2) for r in kb]
ok("KB k settings at 2 dp", ks == [0.5, 1.0, 1.5, 1.94, 2.24, 3.0, 4.0, 5.39, 7.0, 9.0], f"{ks}")
pms = [round(float(r["P_mean"]), 2) for r in kb]
ok("KB P_mean at 2 dp", pms == [3.49, 5.45, 6.78, 7.56, 8.0, 8.89, 8.95, 8.95, 8.95, 8.95], f"{pms}")
ok("KB reject row k=0.5 full", repr(float(kb[0]["P_mean"])) == "3.485236347784519",
   repr(float(kb[0]["P_mean"])))
ok("KB reject + ok statuses", kb[0]["status"] == "reject" and all(r["status"] == "ok" for r in kb[1:]))
plat = [float(r["P_mean"]) for r in kb if float(r["k"]) in (4.0, 5.39, 7.0, 9.0)]
ok("KB plateau band at 4 dp", (round(min(plat), 4), round(max(plat), 4)) == (8.9475, 8.9511),
   f"{round(min(plat), 4)} .. {round(max(plat), 4)}")
ok("KB omega_eq sum 0.0 (nothing draws from it)", sum(float(r["omega_eq"]) for r in kb) == 0.0)
ok("KB 2.24 in the sweep list", 2.24 in ks)
ledk = (KBK / "label-ledger.txt").read_text().splitlines()
ok("KB ledger reject form", has(ledk, "3.49", "reject"))
ok("KB ledger pick label", has(ledk, "k = 2.24", "NR-015"))
ok("KB ledger floor string", has(ledk, "5.0 kW"))
ok("KB ledger bracket", has(ledk, "k \u2265 4"))
ok("KB ledger source stamp", has(ledk, "blob d17d1377", "adea1a3"))
ok("KB ledger rows stamp", has(ledk, "rows NR-015", "NR-041", "script commit 83e1f1e"))
svgk = textset(KBK / "k-basis.svg")
ok("KB SVG text set == ledger set", svgk == set(ledk), f"{len(svgk)} strings")
print("  KB digit-bearing ledger strings:")
for ln in ledk:
    if any(c.isdigit() for c in ln):
        print("   |", ln)

print()
print("== S3. F-REPRO counter-runs: two per kit, byte-compared ==")
for name, script, commit, slug in (
        ("eval-timeline", ETK / "eval-timeline.py", "bb39aec", "eval-timeline"),
        ("k-basis", KBK / "k-basis.py", "83e1f1e", "k-basis")):
    files = [f"{slug}.svg", f"{slug}.pdf", f"{slug}.png", "label-ledger.txt", "manifest.json"]
    outs = []
    for i in (1, 2):
        d = OUT / f"{slug}-run{i}"
        d.mkdir(parents=True, exist_ok=True)
        cp = subprocess.run(["/usr/bin/python3", str(script), "--script-commit", commit,
                             "--outdir", str(d)], capture_output=True, text=True, cwd=str(REPO))
        (d / "stdout.log").write_text(cp.stdout)
        outs.append(d)
        ok(f"{name} counter-run {i} rc=0", cp.returncode == 0, f"rc {cp.returncode}")
        if cp.returncode != 0:
            print(cp.stderr[-800:])
    for f in files:
        c = sha(script.parent / f)
        a = sha(outs[0] / f)
        b = sha(outs[1] / f)
        ok(f"{name} {f} run1==committed==run2", a == c and b == a, f"sha {a[:12]}")
    ok(f"{name} run1 stdout == checks.log",
       (outs[0] / "stdout.log").read_text() == (script.parent / "checks.log").read_text())
    ok(f"{name} run2 stdout == checks.log",
       (outs[1] / "stdout.log").read_text() == (script.parent / "checks.log").read_text())

print()
npass = sum(RESULTS)
print(f"SUMMARY: {npass}/{len(RESULTS)} checks pass")
sys.exit(0 if npass == len(RESULTS) else 1)
